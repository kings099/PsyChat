// Models/Personality.swift
import SwiftUI

// 在这里添加 Codable
enum Personality: String, CaseIterable, Identifiable, Codable {
    case rational = "理性分析"
    case humorous = "幽默风趣"
    case gentle = "哲思温柔"

    var id: String { self.rawValue }

    var displayName: String {
        return self.rawValue
    }

    // 核心：不同人格的系统提示
    var systemPrompt: String {
        switch self {
        case .rational:
            return "你是一个理性人格的心理咨询师。请逻辑清晰、基于事实地给用户提供情感支持"
        case .humorous:
            return "以幽默风趣的人格提供情感支持"
        case .gentle:
            return "以哲思温柔的人格提供情感支持"
        }
    }

    // 为不同人格添加气泡颜色区分
    var color: Color {
        switch self {
        case .rational: return .blue
        case .humorous: return .orange
        case .gentle: return .purple
        }
    }
    // 为不同人格添加不同的背景颜色
    var backgroundColor: Color {
            switch self {
            case .rational:   return Color.purple.opacity(0.1)          // 理性：默认浅紫
            case .humorous:   return Color.yellow.opacity(0.15)   // 幽默：淡黄
            case .gentle: return Color.blue.opacity(0.08)     // 哲思：淡蓝
            }
        }
}
