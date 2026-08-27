import SwiftUI
import UniformTypeIdentifiers

enum SidebarSection: Hashable {
    case chat(String)
    case memories
}

struct MainContentView: View {
    @Environment(AppState.self) var appState
    @State private var conversations: [Conversation] = []
    @State private var selection: SidebarSection? = nil
    @State private var isDragOver = false
    @State private var importMessage: String?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            detailView
        }
        .overlay {
            if isDragOver { dropOverlay }
        }
        .overlay(alignment: .bottom) {
            if let message = importMessage { importBanner(message) }
        }
        .onDrop(of: supportedTypes, isTargeted: $isDragOver) { providers in
            handleDrop(providers)
            return true
        }
        .task { loadConversations() }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            Button(action: createNewChat) {
                Label("New Chat", systemImage: "plus.bubble")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            Divider().padding(.vertical, 4)

            List(selection: $selection) {
                Section("Chats") {
                    ForEach(conversations) { conv in
                        conversationRow(conv)
                            .tag(SidebarSection.chat(conv.id))
                        .contextMenu {
                            Button("Clear Messages") {
                                clearMessages(conv)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                deleteConversation(conv)
                            }
                        }
                    }
                }

                Section {
                    Label("Memories", systemImage: "brain")
                        .tag(SidebarSection.memories)
                }
            }
            .listStyle(.sidebar)
        }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.title)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(relativeDate(conversation.updatedAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if appState.pendingConversations.contains(conversation.id) {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .chat(let id):
            ChatView(conversationId: id)
                .id(id)
        case .memories:
            MemoriesView()
        case nil:
            VStack(spacing: 14) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 56))
                    .foregroundStyle(.tertiary)
                Text("New Chat을 시작하거나\n기존 대화를 선택하세요")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("New Chat") { createNewChat() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
    }

    // MARK: - Actions

    private func loadConversations() {
        do {
            conversations = try appState.conversationRepository.fetchAll()
        } catch {
            NSLog("[Campsis] Failed to load conversations: \(error)")
        }
    }

    private func createNewChat() {
        if let empty = conversations.first(where: { conv in
            (try? appState.messageRepository.count(conversationId: conv.id)) == 0
        }) {
            selection = .chat(empty.id)
            return
        }

        var conv = Conversation()
        do {
            try appState.conversationRepository.save(&conv)
            conversations.insert(conv, at: 0)
            selection = .chat(conv.id)
        } catch {
            NSLog("[Campsis] Failed to create conversation: \(error)")
        }
    }

    private func clearMessages(_ conv: Conversation) {
        do {
            try appState.messageRepository.deleteAll(conversationId: conv.id)
            var updated = conv
            updated.title = "New Chat"
            try appState.conversationRepository.update(&updated)
            if let idx = conversations.firstIndex(where: { $0.id == conv.id }) {
                conversations[idx] = updated
            }
        } catch {
            NSLog("[Campsis] Failed to clear messages: \(error)")
        }
    }

    private func deleteConversation(_ conv: Conversation) {
        do {
            try appState.conversationRepository.delete(conv)
            conversations.removeAll { $0.id == conv.id }
            if case .chat(let id) = selection, id == conv.id {
                selection = nil
            }
        } catch {
            NSLog("[Campsis] Failed to delete conversation: \(error)")
        }
    }

    // MARK: - Drag & Drop

    private var supportedTypes: [UTType] {
        [.pdf, .plainText, .png, .jpeg, .fileURL]
    }

    private var dropOverlay: some View {
        ZStack {
            Color.accentColor.opacity(0.1)
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 40))
                Text("Drop to import")
                    .font(.title3)
            }
            .foregroundStyle(.tint)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    private func importBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.bottom, 12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { importMessage = nil }
                }
            }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        let repository = appState.sourceRepository
        let processingQueue = appState.processingQueueRef as? ProcessingQueue

        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }

                let importer = FileImporter(
                    repository: repository,
                    processingQueue: processingQueue
                )

                Task {
                    do {
                        let _ = try await importer.importFile(at: url)
                        await MainActor.run {
                            withAnimation {
                                importMessage = "\(url.lastPathComponent) imported"
                            }
                        }
                    } catch {
                        await MainActor.run {
                            withAnimation {
                                importMessage = "Import failed: \(error.localizedDescription)"
                            }
                        }
                    }
                }
            }
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
