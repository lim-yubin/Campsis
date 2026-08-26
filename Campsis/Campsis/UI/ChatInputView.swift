import SwiftUI

struct ChatInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Ask your memory...", text: $text, axis: .vertical)
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

            Button(action: sendIfReady) {
                Group {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                    }
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(canSend ? .blue : .secondary)
            .disabled(!canSend)
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
