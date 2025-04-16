//
//  MainMenuView.swift
//  PsyChat
//
//  Created by Henry King on 2025/4/11.
//

// Views/MainMenuView.swift
import SwiftUI

struct MainMenuView: View {
    @Namespace private var animation

    var body: some View {
        NavigationView {
            ZStack {
                // 背景渐变 & 磨砂
                LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.4), Color.cyan.opacity(0.4),Color.pink.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                                    .ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer(minLength: 40)

                    
                    VStack(spacing: 12) {
                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 180, height: 140)
                            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
                            .scaleEffect(1.0)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: UUID()) // 初始动画

                        
                        Text("情感支持小助手")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)

                        Text("选择一个伙伴，开始温暖对话")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 20)

                    // ✅ 个性按钮区域
                    VStack(spacing: 20) {
                        ForEach(Personality.allCases) { personality in
                            NavigationLink {
                                ChatView(viewModel: ChatViewModel(initialPersonality: personality))
                            } label: {
                                PersonalityButtonLabel(personality: personality)
                            }
                        }
                    }
                    .padding(.horizontal, 30)

                    Spacer(minLength: 40)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
    }
}

struct PersonalityButtonLabel: View {
    let personality: Personality
    @State private var isPressed = false

    var iconName: String {
        switch personality {
        case .rational: return "brain.head.profile"
        case .humorous: return "face.smiling"
        case .gentle: return "heart.text.square"
        }
    }

    var subtitle: String {
        switch personality {
        case .rational: return "理性体贴的陪伴"
        case .humorous: return "轻松幽默的视角"
        case .gentle: return "哲思柔和的回应"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 15) {
                Image(systemName: iconName)
                    .font(.title2)
                    .frame(width: 30)
                    .foregroundColor(personality.color)

                Text(personality.displayName)
                    .font(.title3.bold())

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray.opacity(0.4))
            }

            Text(subtitle)
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.leading, 45)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(personality.color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .gray.opacity(0.1), radius: 6, x: 0, y: 4)
        .scaleEffect(isPressed ? 0.98 : 1.0)

    }
}


