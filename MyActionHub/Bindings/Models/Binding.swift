import Foundation

/// 1 Trigger と 1 Action のユーザー定義ペア。
/// 同じ Trigger を 2 つ以上の ActionBinding に割り当てることはできない(設定UIで弾く)。
///
/// ドメイン用語上は CONTEXT.md の通り「Binding」だが、Swift では SwiftUI の
/// `Binding<T>` と名前衝突するため、コード上は `ActionBinding` とする。
struct ActionBinding: Codable, Identifiable, Hashable {
    let id: UUID
    var trigger: Trigger
    var action: Action
    var isEnabled: Bool

    init(id: UUID = UUID(), trigger: Trigger, action: Action, isEnabled: Bool = true) {
        self.id = id
        self.trigger = trigger
        self.action = action
        self.isEnabled = isEnabled
    }
}
