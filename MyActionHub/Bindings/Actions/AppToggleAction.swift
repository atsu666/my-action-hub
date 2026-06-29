import Cocoa
import os.log

/// 指定アプリの「表示/非表示トグル」を Dock アイコンクリックと同等の挙動で実行。
///
/// 状態分岐:
/// - 起動していない → 起動 → 前面表示
/// - 起動しているが前面ではない → 前面に出す(隠れていれば表示)
/// - 前面で active → `hide()` で全ウィンドウを隠す
enum AppToggleAction {
    private static let log = Logger(subsystem: "com.appleple.myactionhub", category: "AppToggle")

    static func toggle(bundleID: String) {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)

        if let app = running.first {
            if app.isActive {
                app.hide()
            } else {
                // unhide + activate(activate のみだと隠れたままの場合がある)
                app.unhide()
                app.activate(options: [.activateAllWindows])
            }
            return
        }

        // 未起動 → 起動
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            log.warning("アプリが見つかりません: \(bundleID, privacy: .public)")
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
            if let error {
                Self.log.error("起動失敗: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
