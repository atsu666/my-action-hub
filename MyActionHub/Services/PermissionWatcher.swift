import Foundation
import Combine
import os.log

/// アクセシビリティ / 入力監視 の付与状態を 5 秒間隔でポーリングし、
/// メニューバーアイコンや設定UIへ反映するための監視オブジェクト。
@MainActor
final class PermissionWatcher: ObservableObject {
    static let shared = PermissionWatcher()

    @Published private(set) var accessibilityGranted: Bool = false
    @Published private(set) var inputMonitoringGranted: Bool = false

    /// いずれかの権限が未付与なら true(MenuBar アイコンの警告バッジ表示用)。
    @Published private(set) var hasIssue: Bool = false

    private let log = Logger(subsystem: "com.appleple.myactionhub", category: "PermissionWatcher")
    private var timer: Timer?
    /// 初回 evaluate() は「変化」ではないのでログを出さないための番兵。
    private var hasEvaluatedOnce = false

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
        // 権限は OS アップデートや System Settings の操作で実行中に失効しうる。
        // 「いつ落ちたか」が後から追えないと原因切り分けができないので遷移を残す。
        if acc != accessibilityGranted {
            if hasEvaluatedOnce {
                log.error("アクセシビリティの付与状態が変化: \(acc, privacy: .public)")
            }
            accessibilityGranted = acc
        }
        if im != inputMonitoringGranted {
            if hasEvaluatedOnce {
                log.error("入力監視の付与状態が変化: \(im, privacy: .public)")
            }
            inputMonitoringGranted = im
        }
        hasEvaluatedOnce = true
        let newIssue = !acc || !im
        if newIssue != hasIssue { hasIssue = newIssue }
    }
}
