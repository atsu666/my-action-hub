import Cocoa
import ApplicationServices
import os.log

/// Finder の表示/非表示トグル。
///
/// 素の `NSWorkspace.open(home)` は、ホーム以外を表示しているウィンドウしか無いときに
/// **新しいウィンドウを増やしてしまう**ため、トグルの実装には使わない。
/// 「ウィンドウの枚数を変えない」ことを優先し、次の方針で動く:
///
/// - ウィンドウ 0 枚 → ホームを 1 枚だけ開く
/// - 1 枚以上あるが全部最小化 → 1 枚だけ元に戻す(新規は開かない)
/// - 1 枚以上見えていて Finder が前面 → `hide()`
/// - 1 枚以上見えていて Finder が背面 → `unhide()` + `activate()`
///
/// **重要な制約**: `hide()` されているアプリの `kAXWindows` は **0 件** で返る
/// (最小化とは違い、AX 上ウィンドウが存在しない扱いになる)。そのため
/// 「隠れている状態で枚数を数えて 0 枚なら開く」と書くと、トグルで表に戻すたびに
/// 新規ウィンドウが増える。枚数の判定は必ず **表示状態に戻してから** 行う。
///
/// ウィンドウの数え方: Accessibility API の `kAXWindows` のうち subrole が
/// `AXStandardWindow` のものだけを数える。`CGWindowListCopyWindowInfo` だと
/// デスクトップやツールバー等 Finder 所有の補助ウィンドウが多数混ざるうえ、
/// ウィンドウ名の取得に画面収録権限が要るため使えない。
///
/// 設計判断: AppleScript / Automation 権限は引き続き使わない(CONTEXT.md 参照)。
/// アクセシビリティ権限はウィンドウ系 Action で既に必須なので追加負担はない。
enum FinderAction {
    private static let log = Logger(subsystem: "com.appleple.myactionhub", category: "FinderAction")
    private static let bundleID = "com.apple.finder"

    /// unhide の反映待ちのポーリング間隔と上限回数(最大 0.5 秒)。
    private static let unhidePollInterval: TimeInterval = 0.05
    private static let unhidePollLimit = 10

    static func toggle() {
        guard let finder = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID).first
        else {
            // Finder は通常常駐しているのでここは想定外。念のためホームを開く。
            log.warning("Finder のプロセスが見つかりません")
            openHome()
            return
        }

        log.debug("""
            Finder: isActive=\(finder.isActive, privacy: .public) \
            isHidden=\(finder.isHidden, privacy: .public)
            """)

        // 前面にいるときだけは AX の枚数が信用できるので、その場で判断する。
        if finder.isActive {
            hideOrShowContent(finder)
            return
        }

        // 背面 or 隠れている → まず表に出す。枚数の判定はそのあと。
        finder.unhide()
        finder.activate(options: [.activateAllWindows])
        ensureWindowVisible(finder)
    }

    /// Finder が前面にいるときの分岐。
    private static func hideOrShowContent(_ finder: NSRunningApplication) {
        let windows = standardWindows(pid: finder.processIdentifier)
        let minimized = windows.filter(isMinimized).count
        log.debug("""
            前面時のウィンドウ: \(windows.count, privacy: .public) 枚 \
            (最小化 \(minimized, privacy: .public) 枚)
            """)

        if windows.isEmpty {
            // 前面だが見せるものが無い(デスクトップをクリックした状態など)。
            openHome()
        } else if minimized == windows.count {
            // 全部最小化。枚数を増やさずに 1 枚だけ戻す。
            deminimize(windows[0])
        } else {
            finder.hide()
        }
    }

    /// `unhide()` の反映を待ってから枚数を数え、必要なら 1 枚だけ用意する。
    ///
    /// 隠れている間は `kAXWindows` が 0 件で返るため、`isHidden` が下りるまで待つ。
    private static func ensureWindowVisible(_ finder: NSRunningApplication, attempt: Int = 0) {
        if finder.isHidden && attempt < unhidePollLimit {
            DispatchQueue.main.asyncAfter(deadline: .now() + unhidePollInterval) {
                ensureWindowVisible(finder, attempt: attempt + 1)
            }
            return
        }

        let windows = standardWindows(pid: finder.processIdentifier)
        let minimized = windows.filter(isMinimized).count
        log.debug("""
            表示後のウィンドウ: \(windows.count, privacy: .public) 枚 \
            (最小化 \(minimized, privacy: .public) 枚, 待機 \(attempt, privacy: .public) 回)
            """)

        if windows.isEmpty {
            openHome()
        } else if minimized == windows.count {
            deminimize(windows[0])
        }
    }

    /// ウィンドウが 1 枚も無いときだけ呼ぶ。ホームディレクトリを 1 枚開く。
    private static func openHome() {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        NSWorkspace.shared.open(home)
    }

    // MARK: - AX helpers

    /// Finder の「普通のウィンドウ」だけを返す。
    /// デスクトップやパネル類は subrole が `AXStandardWindow` ではないので落ちる。
    ///
    /// 注意: 対象アプリが `hide()` されていると、ウィンドウが存在しても 0 件が返る。
    private static func standardWindows(pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        var value: AnyObject?
        let status = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
        guard status == .success, let windows = value as? [AXUIElement] else {
            // 主因はアクセシビリティ権限未付与。
            log.warning("Finder のウィンドウ一覧を取得できません: status=\(status.rawValue, privacy: .public)")
            return []
        }
        return windows.filter { subrole(of: $0) == (kAXStandardWindowSubrole as String) }
    }

    private static func subrole(of window: AXUIElement) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXSubroleAttribute as CFString, &value) == .success
        else { return nil }
        return value as? String
    }

    private static func isMinimized(_ window: AXUIElement) -> Bool {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &value) == .success
        else { return false }
        return (value as? Bool) ?? false
    }

    private static func deminimize(_ window: AXUIElement) {
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
    }
}
