import Foundation
import os.log

/// `Action` を実際の処理に振り分けるディスパッチャ。
@MainActor
final class ActionExecutor {
    private let log = Logger(subsystem: "com.appleple.myactionhub", category: "ActionExecutor")

    func execute(_ action: Action) {
        log.debug("execute: \(action.displayName, privacy: .public)")
        switch action {
        case .maximizeWindow:
            WindowActions.maximize()
        case .snapWindowLeft(let pct):
            WindowActions.snapLeft(widthPercent: pct)
        case .snapWindowRight(let pct):
            WindowActions.snapRight(widthPercent: pct)
        case .openFinder:
            FinderAction.openHome()
        case .toggleApp(let bundleID):
            AppToggleAction.toggle(bundleID: bundleID)
        case .selectInputSource(let target):
            InputSource.select(target)
        }
    }
}
