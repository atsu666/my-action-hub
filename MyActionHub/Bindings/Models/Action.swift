import Foundation

/// Binding が発火した時に実行される操作。
///
/// 各 case が自分自身のパラメータを内包する(Binding ごとに固有の値)。
/// IME Switcher が内部的に呼ぶ `.selectInputSource` も Action 層では
/// 同じ実装を共有するが、Binding テーブルには露出させない
/// (詳細は docs/adr/0002 を参照)。
enum Action: Codable, Hashable {
    case maximizeWindow
    case snapWindowLeft(widthPercent: Int)
    case snapWindowRight(widthPercent: Int)
    case toggleFinder
    case toggleApp(bundleID: String)

    /// IME Switcher 内部用。Binding テーブルには出さない。
    case selectInputSource(InputSourceTarget)

    /// JSON のキー名。`toggleFinder` は当初 `openFinder` という名前で
    /// 「Finder を開く」だけの Action だった。既存の config.json を
    /// 読めなくしない(= 全 Binding が消えない)ため、キー名は据え置く。
    enum CodingKeys: String, CodingKey {
        case maximizeWindow
        case snapWindowLeft
        case snapWindowRight
        case toggleFinder = "openFinder"
        case toggleApp
        case selectInputSource
    }

    enum InputSourceTarget: String, Codable, Hashable {
        case ascii    // ABC 系
        case hiragana // Hiragana 系
    }

    var displayName: String {
        switch self {
        case .maximizeWindow:
            return "ウィンドウを最大化"
        case .snapWindowLeft(let pct):
            return "ウィンドウを左に寄せる (\(pct)%)"
        case .snapWindowRight(let pct):
            return "ウィンドウを右に寄せる (\(pct)%)"
        case .toggleFinder:
            return "Finder の表示/非表示トグル"
        case .toggleApp(let bundleID):
            return "アプリトグル (\(bundleID))"
        case .selectInputSource(let target):
            return "Input Source: \(target.rawValue)"
        }
    }

    /// 設定UIの種別ドロップダウンで使う種別判定。
    var kind: Kind {
        switch self {
        case .maximizeWindow:    return .maximizeWindow
        case .snapWindowLeft:    return .snapWindowLeft
        case .snapWindowRight:   return .snapWindowRight
        case .toggleFinder:      return .toggleFinder
        case .toggleApp:         return .toggleApp
        case .selectInputSource: return .selectInputSource
        }
    }

    enum Kind: String, CaseIterable {
        case maximizeWindow
        case snapWindowLeft
        case snapWindowRight
        case toggleFinder
        case toggleApp
        case selectInputSource

        var displayName: String {
            switch self {
            case .maximizeWindow:    return "ウィンドウを最大化"
            case .snapWindowLeft:    return "ウィンドウを左に寄せる"
            case .snapWindowRight:   return "ウィンドウを右に寄せる"
            case .toggleFinder:      return "Finder の表示/非表示トグル"
            case .toggleApp:         return "アプリの表示/非表示トグル"
            case .selectInputSource: return "Input Source を選択"
            }
        }

        /// Binding 編集UIで選択可能な種別(`.selectInputSource` は除外)。
        static var userSelectable: [Kind] {
            [.maximizeWindow, .snapWindowLeft, .snapWindowRight, .toggleFinder, .toggleApp]
        }
    }
}
