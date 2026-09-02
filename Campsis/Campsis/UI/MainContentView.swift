import SwiftUI
import UniformTypeIdentifiers
import AppKit

enum SidebarSection: Hashable {
    case chat(String)
    case library(LibraryItem)
    case wiki
}

private extension NSResponder {
    /// 응답자 체인을 따라 올라가며 NSSplitViewController를 찾는다.
    var enclosingSplitViewController: NSSplitViewController? {
        sequence(first: self) { $0.nextResponder }
            .compactMap { $0 as? NSSplitViewController }
            .first
    }
}

/// NavigationSplitView의 사이드바 컬럼 최소/최대 너비를 하부 AppKit으로 실제 강제한다.
/// navigationSplitViewColumnWidth의 min/max가 macOS에서 강제되지 않는 문제를 우회.
/// minWidth == maxWidth로 주면 고정(드래그 불가), 다르게 주면 그 범위 내 리사이즈 가능.
private struct SidebarWidthLimits: NSViewRepresentable {
    let minWidth: CGFloat
    let maxWidth: CGFloat
    /// columnVisibility 등 상태가 바뀔 때 updateNSView가 다시 호출되도록 하는 토큰.
    var reapplyToken: Bool = false

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        // 즉시 + 지연 재적용. 접었다 펼칠 때 NSSplitView가 max 두께를 리셋하는 것을 보정.
        apply(from: nsView)
        for delay in [0.05, 0.35, 0.6] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                apply(from: nsView)
            }
        }
    }

    private func apply(from nsView: NSView) {
        guard let splitVC = nsView.enclosingSplitViewController,
              let sidebarItem = splitVC.splitViewItems.first else { return }
        sidebarItem.minimumThickness = minWidth
        sidebarItem.maximumThickness = maxWidth
    }
}

/// 툴바용 아이콘 버튼. 호버 시 둥근 배경이 나타난다.
private struct ToolbarIconButton: View {
    let systemName: String
    let help: String
    var yOffset: CGFloat = 0
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .imageScale(.large)
                .offset(y: yOffset) // 심볼 여백 시각 보정(그림만)
                .frame(width: 26, height: 24)
                .contentShape(RoundedRectangle(cornerRadius: 6))
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(hovering ? 0.12 : 0))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

struct MainContentView: View {
    @Environment(AppState.self) var appState
    @State private var conversations: [Conversation] = []
    @State private var selection: SidebarSection? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var librarySearch = ""
    @State private var isDragOver = false
    @State private var importMessage: String?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    var body: some View {
        @Bindable var appState = appState

        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340) // 초기 폭 힌트(실제 강제는 SidebarWidthLimits)
                // 시스템 토글을 숨기고 [작성][토글]을 직접 배치해 순서·간격을 제어한다.
                .toolbar(removing: .sidebarToggle)
                .toolbar {
                    // 펼쳤을 때: 사이드바 우상단에 [작성][토글].
                    if columnVisibility != .detailOnly {
                        ToolbarItem(placement: .primaryAction) {
                            topIconCluster
                        }
                    }
                }
        } detail: {
            // 메인 영역 안에서 좌우로 나누는 커스텀 분할. OS 인스펙터 컬럼과 달리
            // 열어도 창이 커지지 않고, 분할선으로 메인을 최소 폭(320)까지 확실히 줄일 수 있다.
            InspectorSplit {
                detailView
            }
            // 메인 영역 최소 너비. 사이드바를 넓혀도 이 아래로는 줄지 않는다.
            .frame(minWidth: 520, maxWidth: .infinity)
            .toolbar {
                // 접었을 때: 창 좌상단에 동일하게 [작성][토글] 유지.
                if columnVisibility == .detailOnly {
                    ToolbarItem(placement: .navigation) {
                        topIconCluster
                            .padding(.horizontal, 8) // 감싸는 배경 좌우 여백(대칭)
                    }
                }
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
        .onReceive(NotificationCenter.default.publisher(for: .openWiki)) { _ in
            // 채팅 위키 배지 클릭 → 나의 위키로 전환(WikiListView가 pendingWikiId로 상세 push).
            selection = .wiki
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
        }
    }

    // MARK: - Sidebar

    // [작성][토글] 두 아이콘 묶음. 펼침/접힘 상태 모두 동일한 순서로 재사용.
    private var topIconCluster: some View {
        HStack(spacing: 4) {
            ToolbarIconButton(systemName: "sidebar.left", help: "사이드바 토글") {
                withAnimation { toggleSidebar() }
            }
            ToolbarIconButton(systemName: "square.and.pencil", help: "새 채팅", yOffset: -1.5, action: createNewChat)
        }
    }

    private func toggleSidebar() {
        columnVisibility = (columnVisibility == .detailOnly) ? .all : .detailOnly
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            searchField

            List(selection: $selection) {
                Section("라이브러리") {
                    ForEach(LibraryItem.allCases) { item in
                        Label(item.label, systemImage: item.systemImage)
                            .tag(SidebarSection.library(item))
                    }
                    Label("나의 위키", systemImage: "books.vertical")
                        .tag(SidebarSection.wiki)
                }

                Section {
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
                } header: {
                    Text("대화")
                }
            }
            .listStyle(.sidebar)

            sidebarFooter
        }
        // navigationSplitViewColumnWidth는 macOS에서 강제되지 않으므로,
        // 하부 NSSplitViewItem의 min/max 두께로 240~340 범위를 실제 강제한다.
        .background(SidebarWidthLimits(minWidth: 240, maxWidth: 240,
                                       reapplyToken: columnVisibility == .detailOnly))
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("기억 검색...", text: $librarySearch)
                .textFieldStyle(.plain)
            if !librarySearch.isEmpty {
                Button {
                    librarySearch = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("검색어 지우기")
            }
        }
        .padding(8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .onChange(of: librarySearch) { _, newValue in
            // 검색어를 입력하면 결과를 볼 수 있도록 전체 기억으로 전환.
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            switch selection {
            case .library:
                break
            default:
                selection = .library(.all)
            }
        }
    }

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()
            // 상태·설정을 좌측에 고정 간격으로 묶고, 남는 폭은 오른쪽 빈 공간으로 흘려보낸다.
            // → 사이드바를 넓혀도 요소 사이 간격이 벌어지지 않는다.
            HStack(spacing: 10) {
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("설정")

                statusIndicator
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
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
        case .library(let item):
            MemoriesView(filter: item, searchText: $librarySearch)
                .id(item)
        case .wiki:
            WikiListView()
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
