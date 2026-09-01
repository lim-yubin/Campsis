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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            // 메인 영역 안에서 좌우로 나누는 커스텀 분할. OS 인스펙터 컬럼과 달리
            // 열어도 창이 커지지 않고, 분할선으로 메인을 최소 폭(320)까지 확실히 줄일 수 있다.
            InspectorSplit {
                detailView
            }
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
        .task {
            loadConversations()
            if !hasCompletedOnboarding { showOnboarding = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .chatResponseCompleted)) { _ in
            loadConversations()
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestNewChat)) { _ in
            createNewChat()
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            Button(action: createNewChat) {
                Label("새 채팅", systemImage: "plus.bubble")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            Divider().padding(.vertical, 4)

            List(selection: $selection) {
                Section("메모리") {
                    Label("모든 메모리", systemImage: "brain")
                        .tag(SidebarSection.memories)
                }

                Section("채팅") {
                    if conversations.isEmpty {
                        Text("아직 대화가 없습니다")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    ForEach(conversations) { conv in
                        conversationRow(conv)
                            .tag(SidebarSection.chat(conv.id))
                        .contextMenu {
                            Button("대화 비우기") {
                                clearMessages(conv)
                            }
                            Divider()
                            Button("삭제", role: .destructive) {
                                deleteConversation(conv)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            sidebarFooter
        }
    }

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                statusIndicator
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("설정")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch appState.modelStatus {
        case .downloading(let fraction):
            HStack(spacing: 6) {
                ProgressView(value: fraction)
                    .controlSize(.small)
                    .frame(width: 54)
                Text("\(Int(fraction * 100))%")
            }
        case .loading:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("모델 로딩 중…")
            }
        case .idle:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("AI 준비 중…")
            }
        case .ready:
            HStack(spacing: 6) {
                Circle().fill(.green).frame(width: 7, height: 7)
                Text("AI 준비됨")
            }
        case .failed:
            HStack(spacing: 6) {
                Circle().fill(.red).frame(width: 7, height: 7)
                Text("AI 사용 불가")
            }
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
                .navigationTitle(conversations.first(where: { $0.id == id })?.title ?? "채팅")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        InspectorToggleButton()
                    }
                }
        case .memories:
            MemoriesView()
        case nil:
            VStack(spacing: 14) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 56))
                    .foregroundStyle(.tertiary)
                Text("새 채팅을 시작하거나\n기존 대화를 선택하세요")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("새 채팅") { createNewChat() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .navigationTitle("Campsis")
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
            updated.title = "새 채팅"
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
                Text("여기에 놓아 가져오기")
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
                                importMessage = "\(url.lastPathComponent) 가져옴"
                            }
                        }
                    } catch {
                        await MainActor.run {
                            withAnimation {
                                importMessage = "가져오기 실패: \(error.localizedDescription)"
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

/// 메인 콘텐츠 오른쪽에 인스펙터를 붙이는 커스텀 좌우 분할 컨테이너.
/// - 열어도 창 폭이 늘어나지 않는다(메인이 줄어 공간을 내준다).
/// - 분할선을 끌어 인스펙터 폭을 조절하며, 메인은 최소 폭까지 줄어든다.
private struct InspectorSplit<Content: View>: View {
    @Environment(AppState.self) private var appState
    @AppStorage("inspectorWidth") private var storedWidth: Double = 320
    // 드래그 중 계산된 목표 폭(콘텐츠는 리사이즈하지 않고 가이드 라인만 표시).
    @State private var dragProposed: Double?
    @State private var dividerHovered = false

    private let mainMinWidth: CGFloat = 320
    private let inspectorMinWidth: CGFloat = 280
    private let inspectorMaxWidth: CGFloat = 700
    private let dividerW: CGFloat = 1

    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let total = geo.size.width
            let maxForMain = max(inspectorMinWidth, total - mainMinWidth - dividerW)
            let committed = min(min(CGFloat(storedWidth), inspectorMaxWidth), maxForMain)
            let inspectorW = max(committed, inspectorMinWidth)

            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if appState.showInspector {
                        resizeDivider(total: total, maxForMain: maxForMain)
                        InspectorPanelView()
                            .frame(width: inspectorW)
                            .transition(.move(edge: .trailing))
                    }
                }
                .frame(width: total, height: geo.size.height, alignment: .leading)

                // 드래그 중 표시되는 얇은 가이드 라인(콘텐츠 재배치 없이 커서만 추종)
                if appState.showInspector, let proposed = dragProposed {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .offset(x: total - CGFloat(proposed) - dividerW)
                }
            }
        }
    }

    private func resizeDivider(total: CGFloat, maxForMain: CGFloat) -> some View {
        let active = dividerHovered || dragProposed != nil
        return ZStack {
            Rectangle()
                .fill(active ? Color.accentColor : Color(nsColor: .separatorColor))
                .frame(width: active ? 2 : 1)
            Rectangle().fill(.clear).frame(width: 8).contentShape(Rectangle())  // 잡기 쉬운 히트 영역
        }
        .frame(width: 8)
        .animation(.easeInOut(duration: 0.12), value: active)
        .onHover { inside in
            dividerHovered = inside
            if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    // 분할선을 왼쪽으로 끌면(translation.width < 0) 인스펙터가 넓어진다.
                    let upper = min(Double(inspectorMaxWidth), Double(maxForMain))
                    let proposed = storedWidth - Double(value.translation.width)
                    dragProposed = min(max(proposed, Double(inspectorMinWidth)), upper)
                }
                .onEnded { _ in
                    if let p = dragProposed { storedWidth = p }   // 손 뗄 때 한 번만 실제 적용
                    dragProposed = nil
                }
        )
    }
}
