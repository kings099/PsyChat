//
//  PersistenceService.swift
//  PsyChat
//
//  Created by Henry King on 2025/4/11.
//

// Services/PersistenceService.swift
import Foundation

class PersistenceService {
    // 使用字典来存储不同人格的聊天记录
    private let chatHistoriesKey = "chatHistoriesDictionary"
    private let userDefaults = UserDefaults.standard

    // 根据人格生成存储键 (虽然现在用字典了，但这个思路可以保留或用于其他场景)
    // private func key(for personality: Personality) -> String {
    //     return "chatHistory_\(personality.rawValue)"
    // }

    // 加载特定人格的聊天记录
    func loadChatHistory(for personality: Personality) -> [ChatMessage] {
        guard let historiesData = userDefaults.data(forKey: chatHistoriesKey),
              let histories = try? JSONDecoder().decode([String: Data].self, from: historiesData),
              let personalityData = histories[personality.rawValue],
              let messages = try? JSONDecoder().decode([ChatMessage].self, from: personalityData)
        else {
            print("No chat history found for \(personality.displayName) or error decoding.")
            return []
        }
        print("Chat history loaded for \(personality.displayName).")
        return messages
    }

    // 保存特定人格的聊天记录
    func saveChatHistory(_ messages: [ChatMessage], for personality: Personality) {
        // 1. 先加载现有的所有历史记录字典
        var histories: [String: Data] = [:]
        if let historiesData = userDefaults.data(forKey: chatHistoriesKey),
           let decodedHistories = try? JSONDecoder().decode([String: Data].self, from: historiesData) {
            histories = decodedHistories
        }

        // 2. 对当前人格的消息进行编码
        do {
            let personalityData = try JSONEncoder().encode(messages)
            // 3. 更新字典中对应人格的数据
            histories[personality.rawValue] = personalityData

            // 4. 将更新后的整个字典存回 UserDefaults
            let historiesData = try JSONEncoder().encode(histories)
            userDefaults.set(historiesData, forKey: chatHistoriesKey)
            print("Chat history saved for \(personality.displayName).")

        } catch {
            print("Error saving chat history for \(personality.displayName): \(error)")
        }
    }

    // 清除特定人格的聊天记录
    func clearHistory(for personality: Personality) {
        // 1. 加载字典
        var histories: [String: Data] = [:]
        if let historiesData = userDefaults.data(forKey: chatHistoriesKey),
           let decodedHistories = try? JSONDecoder().decode([String: Data].self, from: historiesData) {
            histories = decodedHistories
        }

        // 2. 移除对应人格的条目
        histories.removeValue(forKey: personality.rawValue)

        // 3. 保存更新后的字典
        do {
            let historiesData = try JSONEncoder().encode(histories)
            userDefaults.set(historiesData, forKey: chatHistoriesKey)
            print("Chat history cleared for \(personality.displayName).")
        } catch {
             print("Error clearing chat history for \(personality.displayName): \(error)")
        }
    }

    // 可选：清除所有聊天记录
    func clearAllHistory() {
        userDefaults.removeObject(forKey: chatHistoriesKey)
        print("All chat histories cleared.")
    }
}
