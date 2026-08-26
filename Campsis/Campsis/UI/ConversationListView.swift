import SwiftUI

struct ConversationListView: View {
    let conversations: [Conversation]
    @Binding var selectedId: String?
    let onNewChat: () -> Void
    let onDelete: (Conversation) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onNewChat) {
                Label("New Chat", systemImage: "plus.bubble")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            Divider()
                .padding(.vertical, 4)

            List(selection: $selectedId) {
                ForEach(conversations) { conv in
                    conversationRow(conv)
                        .tag(conv.id)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                onDelete(conv)
                            }
                        }
                }
            }
            .listStyle(.sidebar)
        }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(conversation.title)
                .font(.subheadline)
                .lineLimit(1)
            Text(relativeDate(conversation.updatedAt))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
