//
//  ChatViewModels.swift
//  PsyChat
//
//  Created by Henry King on 2025/4/11.
//
// ViewModels/ChatViewModel.swift
import Foundation
import Combine // For ObservableObject

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var currentPersonality: Personality
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published private var activeStreamTask: Task<Void, Never>? = nil
    
    
    private let llmService = LLMService()
    private let persistenceService = PersistenceService()
    private var cancellables = Set<AnyCancellable>()
    
    init(initialPersonality: Personality) {
        self.currentPersonality = initialPersonality
        // 加载指定人格的聊天记录
        self.messages = persistenceService.loadChatHistory(for: initialPersonality)
        print("Initialized ViewModel for \(initialPersonality.displayName). Loaded \(self.messages.count) messages.")
        // addWelcomeMessageIfNeeded() // 如果需要欢迎语
    }
    
    
    func sendMessage() {
        let textToSend = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToSend.isEmpty else { return }
        
        let userMessage = ChatMessage(sender: .user, text: textToSend)
        messages.append(userMessage)
        // **重要：发送消息后立即保存一次用户消息，即使 API 调用失败也能保留用户输入**
        saveHistory()
        inputText = ""
        isLoading = true
        errorMessage = nil
        
        let historyToSend = Array(messages.suffix(10))
        
        // --- 使用 async/await 方式 ---
        Task {
            do {
                let botText = try await llmService.fetchResponseAsync(messages: historyToSend, systemPrompt: currentPersonality.systemPrompt, personality: currentPersonality)
                // 确保回调仍在当前人格下
                if self.currentPersonality == historyToSend.last?.personality ?? self.currentPersonality {
                    let botMessage = ChatMessage(sender: .bot, text: botText, personality: self.currentPersonality)
                    self.messages.append(botMessage)
                    self.saveHistory() // 保存包含 Bot 回复的完整记录
                } else {
                    print("Personality switched before response arrived. Discarding response.")
                }
                
            } catch {
                print("Error fetching response (async): \(error)")
                // 确保回调仍在当前人格下
                if self.currentPersonality == historyToSend.last?.personality ?? self.currentPersonality {
                    self.errorMessage = "抱歉，发生错误了: \(error.localizedDescription)"
                    let errorBotMessage = ChatMessage(sender: .bot, text: "抱歉，我暂时无法回复，请稍后再试。", personality: self.currentPersonality)
                    self.messages.append(errorBotMessage)
                    // 即使出错，也保存包含错误提示的消息记录
                    self.saveHistory()
                } else {
                    print("Personality switched before error arrived. Discarding error message.")
                }
            }
            self.isLoading = false
        }
        // --- async/await 结束 ---
    }
    
    @Published var showingClearConfirm = false
    
    // 清除当前人格的历史记录 (由按钮触发)
    func requestClearChatHistory() {
        showingClearConfirm = true // 触发确认弹窗
    }
    
    // 实际执行清除操作 (由确认弹窗调用)
    func confirmClearChatHistory() {
        print("Confirmed clearing history for \(currentPersonality.displayName)")
        messages.removeAll() // 清空内存中的消息
        persistenceService.clearHistory(for: currentPersonality) // 清空磁盘上的消息
        // 关闭确认弹窗 (虽然 .alert 会自动关闭，但以防万一)
        showingClearConfirm = false
    }
    
    // 切换人格
    func switchPersonality(to newPersonality: Personality) {
        guard newPersonality != currentPersonality else { return }
        print("Switching personality from \(currentPersonality.displayName) to \(newPersonality.displayName)")
        
        // 1. 保存当前人格的聊天记录
        saveHistory()
        
        // 2. 更新当前人格
        currentPersonality = newPersonality
        
        // 3. 加载新人格的聊天记录
        messages = persistenceService.loadChatHistory(for: newPersonality)
        print("Loaded \(messages.count) messages for \(newPersonality.displayName)")
        
        
        // 5. 清空可能残留的错误信息
        errorMessage = nil
        isLoading = false // 重置加载状态
    }
    
    // 保存当前人格的历史记录
    private func saveHistory() {
        print("Saving history for \(currentPersonality.displayName)... (\(messages.count) messages)")
        persistenceService.saveChatHistory(messages, for: currentPersonality)
    }
    
    // 清除当前人格的历史记录
    func clearChatHistory() {
        print("Clearing history for \(currentPersonality.displayName)")
        messages.removeAll() // 清空内存中的消息
        persistenceService.clearHistory(for: currentPersonality) // 清空磁盘上的消息
    }
    
}

// MARK: - ChatViewModel (streaming)

@MainActor
extension ChatViewModel {

    func sendMessageStreaming() {
            let textToSend = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !textToSend.isEmpty else { return }

            // 0️⃣ 取消旧流
            activeStreamTask?.cancel()
            activeStreamTask = nil

            // ① 用户消息
            let userMsg = ChatMessage(sender: .user, text: textToSend)
            messages.append(userMsg)
            saveHistory()
            inputText = ""
            isLoading = true
            errorMessage = nil

            // ② 占位 bot
            let botMsg = ChatMessage(sender: .bot, text: "", personality: currentPersonality)
            messages.append(botMsg)
            let botIndex = messages.count - 1

            // ③ 历史（≤10 条 & 过滤空 bot）
            let history = messages
                .filter { !($0.sender == .bot && $0.text.isEmpty) }
                .suffix(10)

            // ④ 固定人格快照
            let personaSnapshot = currentPersonality

            // ⑤ 启动流任务
            activeStreamTask = Task { [weak self] in
                guard let self else { return }

                llmService.streamResponse(
                    messages: Array(history),
                    systemPrompt: personaSnapshot.systemPrompt,
                    personality: personaSnapshot,
                    onDelta: { [weak self] delta in
                        guard let self else { return }
                        Task { @MainActor in
                            guard self.currentPersonality == personaSnapshot else { return }
                            self.messages[botIndex].text += delta
                        }
                    },
                    onComplete: { [weak self] error in
                        guard let self else { return }
                        Task { @MainActor in
                            defer {
                                self.isLoading = false
                                self.saveHistory()
                            }

                            // ❗️若人格已切换，直接丢弃
                            guard self.currentPersonality == personaSnapshot else { return }

                            // 统一失败判定：①显式 error ②消息仍为空
                            if let err = error, !(err is CancellationError) {
                                self.handleStreamFailure(
                                    at: botIndex,
                                    reason: err.localizedDescription.isEmpty ? nil : err.localizedDescription
                                )
                            } else if self.messages[botIndex].text.isEmpty {
                                self.handleStreamFailure(at: botIndex, reason: nil)
                            }
                        }
                    }
                )
            }
        }

        private func handleStreamFailure(at index: Int, reason: String?) {
            let friendly = "抱歉，我暂时无法回复，请稍后再试。"
            self.messages[index].text = friendly
            if let reason {
                self.errorMessage = "抱歉，发生错误了: \(reason)"
            } else {
                self.errorMessage = "抱歉，发生错误了: 网络连接错误"
            }
        }
}
