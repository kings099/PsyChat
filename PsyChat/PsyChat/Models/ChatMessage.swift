//
//  ChatMessage.swift
//  PsyChat
//
//  Created by Henry King on 2025/4/11.
//
// Models/ChatMessage.swift
import Foundation

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let sender: Sender
    var text: String
    let timestamp: Date
    let personality: Personality? // 记录是哪个人格回复的，用户消息则为 nil

    enum Sender: String, Codable {
        case user
        case bot
    }

    init(id: UUID = UUID(), sender: Sender, text: String, timestamp: Date = Date(), personality: Personality? = nil) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
        self.personality = personality
    }
}
