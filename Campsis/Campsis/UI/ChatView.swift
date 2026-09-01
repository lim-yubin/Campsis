import SwiftUI
import Combine

struct ChatView: View {
    @Environment(AppState.self) var appState
    let conversationId: String

    @State private var messages: [Message] = []
    @State private var inputText = ""
    @State private var sourceCache: [String: [Source]] = [:]

    private var isGenerating: Bool { appState.pendingConversations.contains(conversationId) }
    private var streamingText: String { appState.streamingText[conversationId] ?? "" }
    private var showNewChatSuggestion: Bool {
        !isGenerating && messages.last?.role == .assistant
            && (messages.last?.content.hasPrefix(AppState.contextErrorPrefix) ?? false)
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList

            if showNewChatSuggestion {
                HStack(spacing: 8) {
                    Button("새 채팅 시작") {
                        NotificationCenter.default.post(name: .requestNewChat, object: nil)
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            Divider()

            ChatInputView(text: $inputText, isLoading: isGenerating) {
                sendMessage()
            } onStop: {
                appState.stopGeneration(conversationId: conversationId)
            }
        }
        .onAppear { loadMessages() }
        .onReceive(NotificationCenter.default.publisher(for: .chatResponseCompleted)) { notification in
            guard let convId = notification.userInfo?["conversationId"] as? String,
                  convId == conversationId else { return }
            loadMessages()
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty && !isGenerating {
                    emptyState
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            MessageBubbleView(
                                message: message,
                                sources: sourceCache[message.id] ?? []
                            )
                            .id(message.id)
                        }

                        if isGenerating {
                            streamingBubble
                                .id("streaming")
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .onChange(of: messages.count) { scrollToBottom(proxy) }
            .onChange(of: streamingText) { scrollToBottom(proxy) }
            .onAppear {
                // 채팅방 진입 시 가장 최근 대화가 보이도록 최하단으로 이동 (C2)
                DispatchQueue.main.async { scrollToBottom(proxy, animated: false) }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        let action = {
            if isGenerating {
                proxy.scrollTo("streaming", anchor: .bottom)
            } else if let lastId = messages.last?.id {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
        if animated {
            withAnimation { action() }
        } else {
            action()
        }
    }

    private var streamingBubble: some View {
        Group {
            if streamingText.isEmpty {
                ThinkingIndicator()
                    .padding(14)
                    .background(Color.assistantBubbleBackground, in: RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(streamingText)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.assistantBubbleBackground, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("저장된 기억에서 무엇이든 물어보세요")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("캡처한 텍스트, 스크린샷, 메모, 파일을 기반으로 답변합니다")
                .font(.body)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    private func loadMessages() {
        do {
            messages = try appState.messageRepository.fetchAll(conversationId: conversationId)
            for msg in messages where msg.role == .assistant {
                loadSources(for: msg)
            }
        } catch {
            NSLog("[Campsis] Failed to load messages: \(error)")
        }
    }

    private func loadSources(for message: Message) {
        let ids = message.referencedSourceIds()
        guard !ids.isEmpty else { return }
        let sources = ids.compactMap { try? appState.sourceRepository.fetch(id: $0) }
        sourceCache[message.id] = sources
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        var userMessage = Message(conversationId: conversationId, role: .user, content: text)
        do {
            try appState.messageRepository.save(&userMessage)
        } catch {
            NSLog("[Campsis] Failed to save user message: \(error)")
            return
        }
        messages.append(userMessage)
        inputText = ""

        appState.generateResponse(for: text, conversationId: conversationId)
    }
}

struct ThinkingIndicator: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .frame(width: 7, height: 7)
                    .opacity(phase == index ? 1.0 : 0.3)
            }
        }
        .foregroundStyle(.secondary)
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
        .accessibilityLabel("답변 생성 중")
    }
}
