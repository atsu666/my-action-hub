import AppKit
import os.log

/// MyActionHub の NSApplicationDelegate。
///
/// `LSUIElement = YES` でメニューバー常駐(Dockアイコン非表示)モードとして起動する。
/// エントリポイントは `main.swift`(NSApplication.shared.delegate を明示的にセット)。
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "com.appleple.myactionhub", category: "App")
    private var menuBarController: MenuBarController?
    private var imeSwitcher: IMESwitcher?
    private var bindingEngine: BindingEngine?

    func applicationDidFinishLaunching(_ notification: Notification) {
        log.info("起動シーケンス開始")

        // ConfigStore.shared を早期に触って初期化(JSON 読込 / デフォルト生成)。
        _ = ConfigStore.shared

        // 入力監視権限を起動時にリクエスト。
        // これを呼ばないと macOS の「入力監視」リストに本アプリが追加されない。
        _ = PermissionChecker.requestInputMonitoring()

        // 権限監視の開始。MenuBarController がここを購読してアイコンを更新する。
        PermissionWatcher.shared.start()

        menuBarController = MenuBarController()
        imeSwitcher = IMESwitcher()
        bindingEngine = BindingEngine()
        log.info("全モジュール起動完了")

        // 初回起動なら、オンボーディングを自動表示。
        OnboardingWindowController.shared.showIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        bindingEngine?.stop()
        PermissionWatcher.shared.stop()
        ConfigStore.shared.saveNow()
        log.info("MyActionHub 終了")
    }
}
