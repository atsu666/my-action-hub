import Cocoa

/// Finder Action のみを担う。
///
/// 設計判断: AppleScript / Automation 権限を避けるため、Finder 純正設定の
/// 「新規 Finder ウィンドウで表示」の場所には従わず、**ホームディレクトリを開く**
/// 方針で合意済み(CONTEXT.md 参照)。既に同じ場所のウィンドウがあれば
/// `NSWorkspace.open(URL)` がそれを前面に持ってくる。
enum FinderAction {
    static func openHome() {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        NSWorkspace.shared.open(home)
    }
}
