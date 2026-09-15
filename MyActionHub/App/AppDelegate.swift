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

        // 権限は OS のアップデートを跨ぐと片方だけ失効することがある
        // (実例: macOS 26.7 で入力監視は残りアクセシビリティだけ Denied になった)。
        // アクセシビリティが落ちるとウィンドウ系 Action と Finder トグルだけが
        // 静かに死ぬため、起動時に必ず状態をログへ残し、未付与ならプロンプトを出す。
        logPermissionState()

        // 権限監視の開始。MenuBarController がここを購読してアイコンを更新する。
        PermissionWatcher.shared.start()

        menuBarController = MenuBarController()
        imeSwitcher = IMESwitcher()
        bindingEngine = BindingEngine()
        log.info("全モジュール起動完了")

        // 初回起動なら、オンボーディングを自動表示。
        OnboardingWindowController.shared.showIfNeeded()
    }

    /// 起動時の権限状態をログに残す。未付与のアクセシビリティはプロンプトも出す。
    ///
    /// `isAccessibilityGranted(prompt:)` は prompt を付けた時点でダイアログが出るため、
    /// まず prompt なしで判定し、落ちている時だけ prompt 付きで呼び直す。
    private func logPermissionState() {
        let accessibility = PermissionChecker.isAccessibilityGranted()
        let inputMonitoring = PermissionChecker.isInputMonitoringGranted()
        log.info("""
            権限: アクセシビリティ=\(accessibility, privacy: .public) \
            入力監視=\(inputMonitoring, privacy: .public)
            """)

        if !accessibility {
            log.error("アクセシビリティ未付与。ウィンドウ系 Action と Finder トグルは動作しません")
            PermissionChecker.isAccessibilityGranted(prompt: true)
        }
        if !inputMonitoring {
            log.error("入力監視未付与。IME Switcher とジェスチャーは動作しません")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        bindingEngine?.stop()
        PermissionWatcher.shared.stop()
        ConfigStore.shared.saveNow()
        log.info("MyActionHub 終了")
    }
}
