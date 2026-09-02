import SwiftUI

/// "위키에 정리" 승격 시트.
///
/// Phase 8.3에서는 선택한 메모를 확인하는 컨테이너까지 구현한다.
/// 다음 단계(8.4 라우팅 미리보기 → 8.5 승격 실행 → 8.6 재합성)에서
/// 목적지 위키 매칭·수정 UI와 실제 승격/재합성 파이프라인이 이 화면에 채워진다.
struct WikiPromotionSheet: View {
    let sources: [Source]
    /// 닫힘 콜백. 승격이 실제로 수행됐으면 `true`(호출부가 목록을 새로고침).
    let onClose: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            memoList
            Divider()
            footer
        }
        .frame(width: 460, height: 520)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(Color.chatAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text("위키에 정리")
                    .font(.title3.weight(.semibold))
                Text("선택한 메모 \(sources.count)개를 관련 위키로 정리합니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }

    private var memoList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(sources) { source in
                    HStack(spacing: 10) {
                        Image(systemName: iconName(for: source))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.displayTitle)
                                .font(.body)
                                .lineLimit(1)
                            Text(source.capturedAt.formatted(.dateTime.month().day().hour().minute()))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(12)
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            // 8.4에서 라우팅 미리보기로 대체 예정.
            Label("다음 단계에서 각 메모에 어울리는 위키를 추천하고, 위치를 직접 고를 수 있습니다.",
                  systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("취소") { onClose(false) }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    // TODO(8.4): 라우팅 미리보기 화면으로 진행.
                } label: {
                    Text("위치 정하기")
                }
                .buttonStyle(.borderedProminent)
                .disabled(true)
                .help("라우팅 미리보기(8.4)에서 연결됩니다")
            }
        }
        .padding(16)
    }

    private func iconName(for source: Source) -> String {
        switch source.type {
        case .selectedText: return "text.quote"
        case .screenshot: return "camera"
        case .note: return "note.text"
        case .voice: return "waveform"
        case .file: return "doc"
        }
    }
}
