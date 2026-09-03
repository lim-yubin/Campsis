import SwiftUI

struct QuickNotePopupView: View {
    let repository: SourceRepository
    let processingQueue: ProcessingQueue?
    let dismiss: () -> Void

    @State private var noteText: String = ""
    @FocusState private var textFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "note.text")
                Text("빠른 메모")
                    .font(.headline)
                Spacer()
            }

            TextEditor(text: $noteText)
                .font(.body)
                .focused($textFocused)
                .frame(minHeight: 120, maxHeight: .infinity)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Text("\(noteText.count)자")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("⌘↩ 저장 · esc 취소")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("기억하기") { save() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { textFocused = true }
    }

    private func save() {
        let text = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        var source = Source(type: .note, content: text)
        do {
            try repository.save(&source)
            if let queue = processingQueue {
                Task { await queue.enqueue(source) }
            }
            NotificationCenter.default.post(name: .captureSaved, object: nil)
        } catch {
            NSLog("[Campsis] Failed to save quick note: \(error)")
        }
        dismiss()
    }
}
