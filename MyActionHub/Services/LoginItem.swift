import Foundation
import ServiceManagement
import os.log

/// `SMAppService` を使ったログイン時自動起動の登録/解除。
///
/// macOS 13+ で確定済みの `SMAppService.mainApp` を使う(旧 `SMLoginItemSetEnabled`
/// は deprecated でハマりやすいので避ける)。
enum LoginItem {
    private static let log = Logger(subsystem: "com.appleple.myactionhub", category: "LoginItem")

    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static var isRegistered: Bool {
        status == .enabled
    }

    @discardableResult
    static func register() -> Bool {
        do {
            try SMAppService.mainApp.register()
            log.info("ログイン時起動を登録")
            return true
        } catch {
            log.error("ログイン時起動の登録に失敗: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    @discardableResult
    static func unregister() -> Bool {
        do {
            try SMAppService.mainApp.unregister()
            log.info("ログイン時起動を解除")
            return true
        } catch {
            log.error("ログイン時起動の解除に失敗: \(String(describing: error), privacy: .public)")
            return false
        }
    }
}
