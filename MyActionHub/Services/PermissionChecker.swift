import AppKit
import ApplicationServices
import IOKit.hid
import os.log

/// アクセシビリティ / 入力監視 の付与状態を判定し、設定パネルへの導線を提供する。
enum PermissionChecker {
    private static let log = Logger(subsystem: "com.appleple.myactionhub", category: "PermissionChecker")

    // MARK: - Accessibility

    /// アクセシビリティ権限が付与されているか。
    /// `prompt: true` を渡すとシステム側のプロンプトが出る(初回案内に使用)。
    @discardableResult
    static func isAccessibilityGranted(prompt: Bool = false) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as CFString
        let options: CFDictionary = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Input Monitoring

    static func isInputMonitoringGranted() -> Bool {
        let status = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        return status == kIOHIDAccessTypeGranted
    }

    /// 入力監視のプロンプトを出す。一度しか出ないため、オンボーディングで明示的に呼ぶ。
    @discardableResult
    static func requestInputMonitoring() -> Bool {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    static func openInputMonitoringSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
