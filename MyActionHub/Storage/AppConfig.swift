import Foundation

/// JSON 永続化の最上位スキーマ。
/// 互換性のため version フィールドを必ず付ける(将来のマイグレーション対応)。
struct AppConfig: Codable {
    var version: Int
    var imeSwitcher: IMESwitcherConfig
    var bindings: [ActionBinding]
    var general: GeneralConfig

    static let currentVersion = 1

    static var `default`: AppConfig {
        AppConfig(
            version: currentVersion,
            imeSwitcher: .default,
            bindings: [],
            general: .default
        )
    }
}

struct IMESwitcherConfig: Codable {
    var isEnabled: Bool
    /// 左⌘で選択する Input Source。デフォルトは ASCII。
    var leftCommandTarget: Action.InputSourceTarget
    /// 右⌘で選択する Input Source。デフォルトは Hiragana。
    var rightCommandTarget: Action.InputSourceTarget
    /// Modifier Tap として認識する押下→離鍵の最大秒数。
    var tapThresholdSeconds: Double

    static var `default`: IMESwitcherConfig {
        IMESwitcherConfig(
            isEnabled: true,
            leftCommandTarget: .ascii,
            rightCommandTarget: .hiragana,
            tapThresholdSeconds: 0.5
        )
    }
}

struct GeneralConfig: Codable {
    var launchAtLogin: Bool
    /// 初回オンボーディングが完了したか
    var hasCompletedOnboarding: Bool

    static var `default`: GeneralConfig {
        GeneralConfig(
            launchAtLogin: false,
            hasCompletedOnboarding: false
        )
    }
}
