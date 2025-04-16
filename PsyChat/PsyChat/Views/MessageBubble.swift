//
//  MessageBubble.swift
//  PsyChat
//
//  Created by Henry King on 2025/4/11.
//

// Views/MessageBubble.swift
import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.sender == .user {
                Spacer() // 用户消息推到右边
            }

            VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .padding(10)
                    .background(bubbleBackground)
                    .foregroundColor(message.sender == .user ? .white : .primary)
                    .cornerRadius(15)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 1, y: 1) // 细微阴影

                // 显示时间戳和人格（如果是 Bot）
                HStack(spacing: 4) {
                    if message.sender == .bot, let personality = message.personality {
                        Text(personality.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 5)
                    }
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.trailing, message.sender == .user ? 5 : 0)
                        .padding(.leading, message.sender == .bot ? 5 : 0)

                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: message.sender == .user ? .trailing : .leading) // 限制气泡最大宽度

            if message.sender == .bot {
                Spacer() // Bot 消息推到左边
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4) // 气泡间的垂直间距
        .id(message.id) // 重要：用于 ScrollViewReader
    }

    private var bubbleBackground: Color {
        if message.sender == .user {
            return .blue // 用户气泡颜色
        } else {
            // Bot 气泡颜色可以根据人格变化
            return message.personality?.color.opacity(0.2) ?? Color(.systemGray5) // 柔和的背景色
        }
    }
}

