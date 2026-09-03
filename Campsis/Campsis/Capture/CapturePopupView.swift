import SwiftUI

struct CapturePopupView: View {
    let payload: CapturePayload
    let repository: SourceRepository
    let processingQueue: ProcessingQueue?
    let dismiss: () -> Void

    @State private var userNote: String = ""
    @FocusState private var noteFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                Text("기억하기")
                    .font(.headline)
                Spacer()
            }

            previewSection

            contextLine

            TextField("메모 (선택)", text: $userNote, axis: .vertical)
                .lineLimit(3...5)
                .focused($noteFieldFocused)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("⌘↩ 저장 · esc 취소")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("기억하기") { save() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { noteFieldFocused = true }
    }

    @ViewBuilder
    private var previewSection: some View {
        switch payload {
        case .text(let captured):
            ScrollView {
                Text(captured.content)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(8)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 6))

        case .screenshot(let captured):
            Image(nsImage: captured.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, minHeight: 220, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private var contextLine: some View {
        HStack(spacing: 4) {
            switch payload {
            case .text(let t):
                if let app = t.application { Text(app).foregroundStyle(.secondary) }
                if let title = t.windowTitle { Text("·").foregroundStyle(.tertiary); Text(title).foregroundStyle(.secondary).lineLimit(1) }
            case .screenshot(let s):
                if let app = s.application { Text(app).foregroundStyle(.secondary) }
                if let title = s.windowTitle { Text("·").foregroundStyle(.tertiary); Text(title).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer()
        }
        .font(.caption)
    }

    private func save() {
        var source: Source
        switch payload {
        case .text(let captured):
            source = Source(
                type: .selectedText,
                content: captured.content,
                userNote: userNote.isEmpty ? nil : userNote,
                application: captured.application,
                windowTitle: captured.windowTitle,
                url: captured.url
            )
        case .screenshot(let captured):
            source = Source(
                type: .screenshot,
                screenshotPath: captured.savedPath,
                userNote: userNote.isEmpty ? nil : userNote,
                application: captured.application,
                windowTitle: captured.windowTitle,
                url: captured.url
            )
        }

        do {
            try repository.save(&source)
            if let queue = processingQueue {
                Task { await queue.enqueue(source) }
            }
            NotificationCenter.default.post(name: .captureSaved, object: nil)
        } catch {
            NSLog("Failed to save source: \(error)")
        }
        dismiss()
    }
}
