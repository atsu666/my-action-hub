import AppKit
import SwiftUI

/// オンボーディングウィンドウのライフサイクル管理。
@MainActor
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?

    private init() {}

    func showIfNeeded() {
        if ConfigStore.shared.config.general.hasCompletedOnboarding {
            return
        }
        show()
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(
                rootView: OnboardingView(onComplete: { [weak self] in
                    self?.close()
                })
            )
            let win = NSWindow(contentViewController: hosting)
            win.title = "MyActionHub のセットアップ"
            win.styleMask = [.titled, .closable]
            win.setContentSize(NSSize(width: 620, height: 440))
            win.center()
            win.isReleasedWhenClosed = false
            window = win
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }
}
