import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) var appState
    @State private var queryText = ""
    @State private var searchResults: [SearchResult] = []
    @State private var answer: String = ""
    @State private var isSearching = false
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var selectedSource: Source?

    var body: some View {
        VStack(spacing: 0) {
            searchHeader

            Divider()

            if let error = errorMessage {
                errorBanner(error)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !answer.isEmpty {
                        answerSection
                    }

                    if !searchResults.isEmpty {
                        sourcesSection
                    }

                    if searchResults.isEmpty && !isSearching && queryText.isEmpty {
                        placeholderView
                    }
                }
                .padding()
            }
        }
        .sheet(item: $selectedSource) { source in
            SourceDetailView(source: source)
        }
    }

    private var searchHeader: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Ask your memory...", text: $queryText)
                .textFieldStyle(.plain)
                .font(.title3)
                .onSubmit { performSearch() }

            if isSearching || isGenerating {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding()
    }

    private var answerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Answer", systemImage: "text.bubble")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(answer)
                .textSelection(.enabled)
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sources (\(searchResults.count))", systemImage: "doc.text")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(searchResults, id: \.source.id) { result in
                SourceCardView(result: result)
                    .onTapGesture { selectedSource = result.source }
            }
        }
    }

    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("저장된 기억에서 무엇이든 물어보세요")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
            Text(message)
            Spacer()
            Button("Dismiss") { errorMessage = nil }
                .buttonStyle(.borderless)
        }
        .padding(8)
        .background(.red.opacity(0.1))
    }

    private func performSearch() {
        let query = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        searchResults = []
        answer = ""
        errorMessage = nil
        isSearching = true

        Task {
            do {
                let engine = VectorSearchEngine(
                    embeddingService: appState.embeddingService,
                    embeddingRepository: appState.embeddingRepository,
                    sourceRepository: appState.sourceRepository
                )
                let results = try await engine.search(query: query)
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }

                if !results.isEmpty {
                    await generateAnswer(query: query, sources: results)
                } else {
                    await MainActor.run {
                        answer = "저장된 Memory에서 충분한 근거를 찾지 못했습니다."
                    }
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func generateAnswer(query: String, sources: [SearchResult]) async {
        guard #available(macOS 26.0, *) else { return }
        await MainActor.run { isGenerating = true }

        do {
            let generator = AnswerGenerator()
            let result = try await generator.generate(query: query, sources: sources)
            await MainActor.run {
                answer = result
                isGenerating = false
            }
        } catch {
            await MainActor.run {
                isGenerating = false
                if answer.isEmpty {
                    answer = "답변 생성에 실패했습니다."
                }
            }
        }
    }
}
