//
//  LLMservice.swift
//  PsyChat
//
//  Created by Henry King on 2025/4/11.
//
// Services/LLMService.swift
import Foundation

// --- 阿里云 DashScope API 服务 ---

class LLMService {

    // --- Helper Function to Read API Key from Info.plist ---
    // !!! 警告: 从 Info.plist 读取 API Key 仅适用于本地开发/测试 !!!
    // !!! 不要在生产环境中使用此方法，密钥容易反编译泄露 !!!
    private func getDashScopeAPIKey() -> String? {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "DashScopeAPIKey") as? String, !apiKey.isEmpty else {
            print("错误：未能在 Info.plist 中找到有效的 'DashScopeAPIKey'。请确保已添加并设置了正确的 Key。")
            return nil
        }

        return apiKey
    }
    
    // 使用baseurl 调用api
    private func getBaseURL() -> String {
           if let customURL = Bundle.main.object(forInfoDictionaryKey: "CustomLLMBaseURL") as? String, !customURL.isEmpty {
               print("使用 Info.plist 中的自定义 Base URL: \(customURL)")
               // 简单验证一下 URL 格式（可选）
               if URL(string: customURL) == nil {
                   print("警告：Info.plist 中的 'CustomLLMBaseURL' (\(customURL)) 似乎不是一个有效的 URL。")
                   // 可以选择在这里抛出错误或回退到默认值
               }
               // 确保 URL 末尾没有斜杠，以便拼接 endpoint
               return customURL.last == "/" ? String(customURL.dropLast()) : customURL
           } else {
               // 如果 Info.plist 中未配置，可以回退到默认值或抛出错误
               let defaultURL = "https://dashscope.aliyuncs.com/compatible-mode/v1" // 之前的默认值
               print("警告：未在 Info.plist 中找到 'CustomLLMBaseURL'，将使用默认值: \(defaultURL)")
               return defaultURL
           }
       }

    // --- API Request/Response Structures ---
    struct RequestBody: Encodable {
        let model: String
        let messages: [RequestMessage]
        // 可以添加其他参数，如 temperature, top_p 等
        // let temperature: Double? = 0.85 // 示例
    }

    struct RequestMessage: Encodable {
        let role: String // "system", "user", "assistant"
        let content: String
    }

    struct CompletionResponse: Decodable {
        let choices: [Choice]? // 改为可选，以防 API 不返回 choices
        let usage: Usage?      // 可选地解析 token 使用情况
        let error: APIError?   // 尝试解析可能的错误结构
    }

    struct Choice: Decodable {
        let message: ResponseMessage? // 改为可选
        let finish_reason: String?    // 结束原因
    }

    struct ResponseMessage: Decodable {
        let role: String?     // 改为可选
        let content: String?  // 改为可选
    }

    struct Usage: Decodable {
        let total_tokens: Int?
        let input_tokens: Int?
        let output_tokens: Int?
    }

    // DashScope 可能的错误返回结构 (根据需要调整)
    struct APIError: Decodable {
        let code: String?
        let message: String?
    }

    // --- Error Enum ---
    enum LLMError: Error, LocalizedError {
        case missingAPIKey
        case invalidURL
        case requestEncodingFailed(Error)
        case networkError(Error)
        case invalidResponse(URLResponse?)
        case decodingError(Error)
        case apiError(code: String?, message: String?)
        case noContentReceived

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "API Key 未找到或无效。"
            case .invalidURL: return "API 的 URL 无效。"
            case .requestEncodingFailed(let error): return "无法编码请求体: \(error.localizedDescription)"
            case .networkError(let error): return "网络请求失败: \(error.localizedDescription)"
            case .invalidResponse(let response): return "收到了无效的服务器响应: \(response?.description ?? "未知响应")"
            case .decodingError(let error): return "无法解码服务器响应: \(error.localizedDescription)"
            case .apiError(let code, let message): return "API 返回错误: \(code ?? "未知代码") - \(message ?? "无详细信息")"
            case .noContentReceived: return "API 未返回有效的回复内容。"
            }
        }
    }


    // --- 主异步请求方法 ---
    func fetchResponseAsync(messages: [ChatMessage], systemPrompt: String, personality: Personality) async throws -> String {

        // 1. 获取 API Key
        guard let apiKey = getDashScopeAPIKey() else {
            throw LLMError.missingAPIKey
        }

        // 2. 准备 URL 和 Request
        let baseURL = getBaseURL()
        let endpoint = "/v1/chat/completions"
        guard let url = URL(string: baseURL + endpoint) else {
            throw LLMError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // 3. 构建 Request Body
        //    - 添加 System Prompt
        //    - 转换 ChatMessage 历史记录
        var requestMessages: [RequestMessage] = []
        requestMessages.append(RequestMessage(role: "system", content: systemPrompt))

        for message in messages {
            let role: String
            switch message.sender {
            case .user:
                role = "user"
            case .bot:
                role = "assistant" // LLM 的回复对应 assistant 角色
            }
            requestMessages.append(RequestMessage(role: role, content: message.text))
        }

        // 选择模型 (qwen-plus 或其他阿里云支持的模型)
        let modelName = "qwen" // 或者 "qwen-turbo", "qwen-max" 等
        let requestBody = RequestBody(model: modelName, messages: requestMessages)

        // 4. 编码 Request Body
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
            if let bodyData = request.httpBody, let jsonString = String(data: bodyData, encoding: .utf8) {
                 print("--- Sending to DashScope ---")
                 print("URL: \(url.absoluteString)")
                 print("Headers: \(request.allHTTPHeaderFields ?? [:])")
                 print("Body:\n\(jsonString)")
                 print("---------------------------")
            }
        } catch {
            throw LLMError.requestEncodingFailed(error)
        }

        // 5. 发送网络请求
        let data: Data
        let response: URLResponse
        do {
            // 设置超时时间 (可选)
            let sessionConfig = URLSessionConfiguration.default
            sessionConfig.timeoutIntervalForRequest = 60.0 // 60 秒超时
            let session = URLSession(configuration: sessionConfig)

            (data, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, let responseString = String(data: data, encoding: .utf8) {
                 print("--- Received from DashScope ---")
                 print("Status Code: \(httpResponse.statusCode)")
                 print("Response Body:\n\(responseString)")
                 print("-----------------------------")
            }

        } catch {
            throw LLMError.networkError(error)
        }

        // 6. 检查响应状态码
                guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                    // 在这个 else 块中，httpResponse 不可用。我们需要处理错误情况。

                    // 尝试解析已知的 API 错误结构
                    if let decodedError = try? JSONDecoder().decode(CompletionResponse.self, from: data), let apiErr = decodedError.error {
                        print("API returned specific error: \(apiErr.code ?? "N/A") - \(apiErr.message ?? "N/A")")
                        throw LLMError.apiError(code: apiErr.code, message: apiErr.message)
                    }
                    // 如果无法解析为已知错误结构，尝试获取原始响应字符串和状态码
                    else if let errorString = String(data: data, encoding: .utf8) {
                         // 再次尝试从原始 response 获取 statusCode
                        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0 // 如果转换失败，用 0 表示
                        print("API returned non-2xx status code: \(statusCode). Response: \(errorString)")
                        throw LLMError.apiError(code: "\(statusCode)", message: "错误响应: \(errorString)")
                    }
                    // 如果连字符串都无法获取，则抛出通用无效响应错误
                    else {
                        print("API returned invalid/unreadable response.")
                        throw LLMError.invalidResponse(response)
                    }
                }
                // 只有 guard 语句成功通过，httpResponse 才在此处及之后可用
                print("API request successful with status code: \(httpResponse.statusCode)")

        // 7. 解码响应 Body
        do {
            let decodedResponse = try JSONDecoder().decode(CompletionResponse.self, from: data)

            // 8. 提取回复内容
            //    注意：这里做了多重可选链检查，确保安全
            guard let firstChoice = decodedResponse.choices?.first,
                  let message = firstChoice.message,
                  let content = message.content,
                  !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                // 处理 API 可能返回 choices 为空或 content 为空的情况
                print("警告: API 响应中未找到有效的 choices[0].message.content")
                if let finishReason = decodedResponse.choices?.first?.finish_reason {
                     print("Finish Reason: \(finishReason)")
                     if finishReason == "stop" {
                         // 有时模型会因为内容安全或其他原因返回 stop 但没有内容
                         throw LLMError.apiError(code: "Content Filtered?", message: "模型可能因内容安全或其他原因停止，未返回内容。")
                     }
                }
                throw LLMError.noContentReceived
            }

            return content

        } catch {
            // 捕获 JSON 解码错误
            throw LLMError.decodingError(error)
        }
    }

    // 保留旧的 completion handler 版本的 fetchResponse 方法，内部调用 async 版本
    // 如果你的 ViewModel 仍然使用 completion handler，可以保留这个
    func fetchResponse(messages: [ChatMessage], systemPrompt: String, personality: Personality, completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                let result = try await fetchResponseAsync(messages: messages, systemPrompt: systemPrompt, personality: personality)
                completion(.success(result))
            } catch {
                // 将自定义的 LLMError 转换为通用的 Error
                completion(.failure(error))
            }
        }
    }
}

extension LLMService {

    /// 每收到一段新内容就回调一次 `onDelta`
    /// 最终正常结束时 onComplete(nil)，出错时 onComplete(error)
    func streamResponse(
        messages: [ChatMessage],
        systemPrompt: String,
        personality: Personality,
        onDelta: @escaping (String) -> Void,
        onComplete: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                // 限制最近 10 条消息（5轮）
                let limitedMessages = Array(messages.suffix(9))

                // ① 组装请求
                guard let apiKey = getDashScopeAPIKey() else {
                    throw LLMError.missingAPIKey
                }
                let baseURL = getBaseURL()
                let url = URL(string: baseURL + "/v1/chat/completions")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

                // ② 构建 body，包含 stream: true
                var reqMsgs = [RequestMessage(role: "system", content: systemPrompt)]
                for m in limitedMessages {
                    reqMsgs.append(
                        RequestMessage(
                            role: m.sender == .user ? "user" : "assistant",
                            content: m.text
                        )
                    )
                }

                struct Body: Encodable {
                    let model: String
                    let messages: [RequestMessage]
                    let stream: Bool
                }

                let body = Body(model: "qwen", messages: reqMsgs, stream: true)
                request.httpBody = try JSONEncoder().encode(body)

                // Debug 打印请求
                print("[DEBUG] will send request to", request.url!.absoluteString)
                for (k, v) in request.allHTTPHeaderFields ?? [:] {
                    print("  \(k): \(v)")
                }
                if let body = request.httpBody,
                   let s = String(data: body, encoding: .utf8) {
                    print("  body:", s)
                }

                // ③ 发送请求并读取 SSE 流
                let (bytes, _) = try await URLSession.shared.bytes(for: request)

                for try await line in bytes.lines {
                    guard line.hasPrefix("data:") else { continue }

                    let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    if payload == "[DONE]" {
                        break // 流式结束标记
                    }

                    struct Chunk: Decodable {
                        struct Choice: Decodable {
                            struct Delta: Decodable { let content: String? }
                            let delta: Delta
                            let finish_reason: String?
                        }
                        let choices: [Choice]
                    }

                    if let data = payload.data(using: .utf8),
                       let chunk = try? JSONDecoder().decode(Chunk.self, from: data),
                       let piece = chunk.choices.first?.delta.content {
                        onDelta(piece)
                    }
                }

                onComplete(nil) // 成功完成
            } catch {
                onComplete(error) // 出错
            }
        }
    }
}
