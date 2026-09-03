import Foundation
import AppKit

/// 외부 앱(미리보기 등)에서 원본 파일을 편집한 뒤 앱으로 복귀했을 때
/// 파일 수정 시각(mtime)을 비교해 정리본 재생성을 유도한다.
///
/// 미리보기는 저장 시 임시파일→교체(atomic rename) 방식이라 파일 자체를 감시하는
/// vnode 워처가 쉽게 끊긴다. 그래서 앱 복귀 시점에 mtime을 비교하는 방식이 더 안정적이다.
@Observable
@MainActor
final class EditWatcher {
    private struct Tracked {
        let url: URL
        var mtimeBaseline: Date
    }

    /// key: sourceId
    private var tracked: [String: Tracked] = [:]

    /// 수정이 감지되어 사용자 확인을 기다리는 소스 id들 (선입선출).
    private(set) var changedSourceIds: [String] = []

    private var observer: NSObjectProtocol?

    /// 앱 활성화 알림 관찰 시작 (앱 시작 시 1회 호출).
    func startObserving() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.checkForChanges() }
        }
    }

    /// 원본을 외부 앱으로 열기 직전 호출해 현재 mtime을 기준선으로 기록한다.
    func track(sourceId: String, url: URL) {
        tracked[sourceId] = Tracked(url: url, mtimeBaseline: Self.mtime(url) ?? .distantPast)
    }

    /// 추적 중인 파일들의 mtime을 확인해 변경된 소스를 changedSourceIds에 반영한다.
    private func checkForChanges() {
        for (id, entry) in tracked {
            guard let current = Self.mtime(entry.url) else { continue }
            if current > entry.mtimeBaseline {
                if !changedSourceIds.contains(id) {
                    changedSourceIds.append(id)
                }
                // 같은 편집으로 반복 프롬프트되지 않도록 기준선을 갱신.
                tracked[id]?.mtimeBaseline = current
            }
        }
    }

    /// 사용자가 확인/무시를 마친 소스를 대기열에서 제거한다.
    func resolve(_ id: String) {
        changedSourceIds.removeAll { $0 == id }
    }

    private static func mtime(_ url: URL) -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))
        return attrs?[.modificationDate] as? Date
    }
}
