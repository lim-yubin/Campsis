import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("기억에게 무엇이든 물어보세요...", text: $text, axis: .vertical)
                .font(.body)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                .onSubmit {
                    if !NSEvent.modifierFlags.contains(.shift) {
                        sendIfReady()
                    }
                }

            Button {
                if isLoading { onStop() } else { sendIfReady() }
            } label: {
                Image(systemName: isLoading ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.title)
            }
            .buttonStyle(.plain)
            .foregroundStyle(isLoading ? Color.red : (canSend ? Color.chatAccent : Color.secondary))
            .disabled(!isLoading && !canSend)
            .accessibilityLabel(isLoading ? "생성 중지" : "보내기")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    private func sendIfReady() {
        guard canSend else { return }
        onSend()
    }
}
