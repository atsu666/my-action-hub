import Foundation
import Combine

/// アクセシビリティ / 入力監視 の付与状態を 5 秒間隔でポーリングし、
/// メニューバーアイコンや設定UIへ反映するための監視オブジェクト。
@MainActor
final class PermissionWatcher: ObservableObject {
    static let shared = PermissionWatcher()

    @Published private(set) var accessibilityGranted: Bool = false
    @Published private(set) var inputMonitoringGranted: Bool = false

    /// いずれかの権限が未付与なら true(MenuBar アイコンの警告バッジ表示用)。
    @Published private(set) var hasIssue: Bool = false

    private var timer: Timer?

    private init() {
        evaluate()
    }

    func start() {
        guard timer == nil else { return }
        evaluate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluate()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func evaluate() {
        let acc = PermissionChecker.isAccessibilityGranted()
        let im  = PermissionChecker.isInputMonitoringGranted()
        if acc != accessibilityGranted   { accessibilityGranted = acc }
        if im  != inputMonitoringGranted { inputMonitoringGranted = im }
        let newIssue = !acc || !im
        if newIssue != hasIssue { hasIssue = newIssue }
    }
}
