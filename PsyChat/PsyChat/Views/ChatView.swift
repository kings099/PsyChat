//
//  ChatView.swift
//  PsyChat
//
//  Created by Henry King on 2025/4/11.
//
// Views/ChatView.swift
import SwiftUI

struct ChatView: View {
    @StateObject var viewModel: ChatViewModel // 使用 @StateObject
    @Environment(\.dismiss) var dismiss // 用于返回主菜单
    @State private var showingPersonalitySheet = false // 控制切换人格菜单的显示
    @FocusState private var isInputFieldFocused: Bool // 添加 FocusState
    

    var body: some View {
        VStack(spacing: 0) { // 移除 VStack 间距
            // 聊天消息区域
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 5) { // 消息间的间距
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                        }
                    }
                    .padding(.top) // 顶部留出一些空间
                }
                .onChange(of: viewModel.messages.count) {
                    // 当消息数量变化时，滚动到底部
                    scrollToBottom(proxy: proxy)
                }
                .onAppear {
                    // 视图出现时滚动到底部
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }

            // 显示错误信息
            if let errorMessage = viewModel.errorMessage {
                 Text(errorMessage)
                     .foregroundColor(.red)
                     .padding(.vertical, 5)
                     .font(.caption)
            }

            // 输入区域
            HStack(spacing: 10) {
                TextField("输入消息...", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(18)
                    .lineLimit(1...5)
                    .focused($isInputFieldFocused) // 绑定 FocusState

                if viewModel.isLoading {
                    ProgressView()
                        .padding(.horizontal, 5)
                } else {
                    Button {
                        // 发送前隐藏键盘
                        isInputFieldFocused = false
                        viewModel.sendMessageStreaming()
                        // 发送后稍微延迟滚动到底部，给键盘收起动画一点时间，
                        // onChange 也会触发，但这里可以更即时
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // scrollToBottom(...) // onChange 应该会处理，观察是否需要手动调用
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .resizable()
                            .frame(width: 30, height: 30)
                            .foregroundColor(viewModel.inputText.isEmpty ? .gray : .blue)
                    }
                    .disabled(viewModel.inputText.isEmpty || viewModel.isLoading) // 正在加载时也禁用发送
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.thinMaterial)
        }
        .navigationTitle(viewModel.currentPersonality.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .background(viewModel.currentPersonality.backgroundColor.ignoresSafeArea())
        .background(viewModel.currentPersonality
                       .backgroundColor
                       .opacity(0.7))   // 保持一点磨砂效果
        .toolbar {
            // 清空记录按钮 (放到左边)
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    isInputFieldFocused = false // 关闭键盘
                    viewModel.requestClearChatHistory()
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.red) // 给清除按钮一个警示色
            }

            // 切换人格按钮 (保持在右边)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isInputFieldFocused = false // 关闭键盘
                    showingPersonalitySheet = true
                } label: {
                    Image(systemName: "person.3.sequence.fill")
                        .foregroundColor(viewModel.currentPersonality.color)
                }
            }
        }
        // 添加清除确认弹窗
        .alert("确认清除", isPresented: $viewModel.showingClearConfirm) {
            Button("清除", role: .destructive) {
                viewModel.confirmClearChatHistory()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要清除与“\(viewModel.currentPersonality.displayName)”的所有聊天记录吗？此操作无法撤销。")
        }
        .sheet(isPresented: $showingPersonalitySheet) {
                     PersonalitySelectionSheet(selectedPersonality: $viewModel.currentPersonality) { newPersonality in
                         isInputFieldFocused = false // 切换人格前也收起键盘
                         viewModel.switchPersonality(to: newPersonality)
                     }
                     .presentationDetents([.height(250)])
                }
        .animation(.easeInOut, value: viewModel.messages)
        .animation(.easeInOut, value: viewModel.isLoading)
        .onTapGesture { // 点击聊天区域空白处收起键盘
             isInputFieldFocused = false
        }
    }
    
    // 滚动到底部的方法
    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool = true) {
        guard let lastMessageId = viewModel.messages.last?.id else { return }
        if animated {
            withAnimation(.smooth(duration: 0.3)) {
                 proxy.scrollTo(lastMessageId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastMessageId, anchor: .bottom)
        }

    }
}

// 用于 Sheet 的人格选择视图
struct PersonalitySelectionSheet: View {
    @Binding var selectedPersonality: Personality
    let onSelect: (Personality) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView { // 使用 NavigationView 添加标题和关闭按钮
             VStack(alignment: .leading) {
                 Text("切换人格").font(.headline).padding(.bottom)
                 ForEach(Personality.allCases) { personality in
                     Button {
                         if personality != selectedPersonality {
                             onSelect(personality)
                         }
                         dismiss()
                     } label: {
                         HStack {
                             Image(systemName: selectedPersonality == personality ? "checkmark.circle.fill" : "circle")
                                 .foregroundColor(personality.color)
                             Text(personality.displayName)
                             Spacer()
                             Circle()
                                 .fill(personality.color)
                                 .frame(width: 15, height: 15)
                         }
                         .padding(.vertical, 8)
                         .contentShape(Rectangle()) // 让整个 HStack 可点击
                     }
                     .buttonStyle(.plain) // 移除默认按钮样式
                 }
                 Spacer()
             }
             .padding()
             .navigationTitle("选择模式")
             .navigationBarTitleDisplayMode(.inline)
             .toolbar {
                 ToolbarItem(placement: .navigationBarTrailing) {
                     Button("完成") { dismiss() }
                 }
             }
        }
    }
}

struct LogoView_Previews: PreviewProvider {
    static var previews: some View {
        MainMenuView()
    }
}
