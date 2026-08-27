import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) var appState
    let conversationId: String

    @State private var messages: [Message] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var sourceCache: [String: [Source]] = [:]

    var body: some View {
        VStack(spacing: 0) {
            messageList

            Divider()

            ChatInputView(text: $inputText, isLoading: isLoading) {
                sendMessage()
            }
        }
        .onAppear { refreshState() }
        .onReceive(NotificationCenter.default.publisher(for: .chatResponseCompleted)) { notification in
            guard let convId = notification.userInfo?["conversationId"] as? String,
                  convId == conversationId else { return }
            loadMessages()
            isLoading = false
        }
    }

    private func refreshState() {
        loadMessages()
        isLoading = appState.pendingConversations.contains(conversationId)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if messages.isEmpty {
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
                    }
                    .padding(.vertical, 16)
                }
            }
            .onChange(of: messages.count) {
                if let lastId = messages.last?.id {
                    withAnimation {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
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
        isLoading = true

        appState.generateResponse(for: text, conversationId: conversationId)
    }
}
