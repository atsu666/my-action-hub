import Foundation
import Combine
import os.log

/// Binding 機構(機能B)のトップレベルコントローラ。
///
/// `ConfigStore` の `bindings` を監視し、変化に応じて `HotkeyMonitor` /
/// `GestureMonitor` を登録・解除する。Trigger 発火時には `ActionExecutor`
/// に Action を渡して実行する。
///
/// 同期戦略: 設定が変わったら一旦すべて登録解除して、有効な Binding を
/// 全部再登録する(差分計算より単純で、Binding 数が小さい想定なので安全)。
@MainActor
final class BindingEngine {
    private let log = Logger(subsystem: "com.appleple.myactionhub", category: "Engine")
    private let hotkeyMonitor = HotkeyMonitor()
    private let gestureMonitor = GestureMonitor()
    private let executor = ActionExecutor()

    /// 現在有効な Binding の Trigger をキーに、実行するアクションを保持。
    /// GestureMonitor は1コールバックなので、ここでルーティングする。
    private var gestureRoutes: [String: Action] = [:]

    private var subscriptions = Set<AnyCancellable>()

    init() {
        let store = ConfigStore.shared
        wireGestureMonitor()
        observeConfig(store)
        sync(with: store.config.bindings)
        gestureMonitor.start()
    }

    deinit {
        // GestureMonitor の停止は意図的にスキップ(deinit は nonisolated)。
        // アプリ終了時のクリーンアップは AppDelegate.applicationWillTerminate で。
    }

    func stop() {
        hotkeyMonitor.unregisterAll()
        gestureMonitor.stop()
        gestureRoutes.removeAll()
    }

    // MARK: - Wiring

    private func wireGestureMonitor() {
        gestureMonitor.onSwipe = { [weak self] fingers, direction in
            guard let self else { return }
            let key = Trigger.gesture(fingers: fingers, motion: .swipe(direction)).canonicalKey
            self.log.debug("Swipe: \(fingers.rawValue, privacy: .public)-finger \(direction.rawValue, privacy: .public)")
            if let action = self.gestureRoutes[key] {
                self.executor.execute(action)
            }
        }
        gestureMonitor.onForceClick = { [weak self] fingers in
            guard let self else { return }
            let key = Trigger.gesture(fingers: fingers, motion: .forceClick).canonicalKey
            self.log.debug("ForceClick: \(fingers.rawValue, privacy: .public)-finger")
            if let action = self.gestureRoutes[key] {
                self.executor.execute(action)
            }
        }
    }

    // MARK: - Observation

    private func observeConfig(_ store: ConfigStore) {
        store.$config
            .map(\.bindings)
            .removeDuplicates(by: Self.bindingsEqual)
            .sink { [weak self] bindings in
                self?.sync(with: bindings)
            }
            .store(in: &subscriptions)
    }

    /// 同一性チェック用の比較関数。`removeDuplicates(by:)` のインライン closure に
    /// 入れると SwiftUI/Combine の型推論が爆発するため外出しする。
    private static func bindingsEqual(_ lhs: [ActionBinding], _ rhs: [ActionBinding]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (l, r) in zip(lhs, rhs) {
            if l.id != r.id { return false }
            if l.isEnabled != r.isEnabled { return false }
            if l.trigger.canonicalKey != r.trigger.canonicalKey { return false }
        }
        return true
    }

    // MARK: - Sync

    private func sync(with bindings: [ActionBinding]) {
        log.debug("Binding 同期: \(bindings.count, privacy: .public) 件")
        hotkeyMonitor.unregisterAll()
        gestureRoutes.removeAll()

        for binding in bindings where binding.isEnabled {
            register(binding)
        }
    }

    private func register(_ binding: ActionBinding) {
        switch binding.trigger {
        case .hotkey(let spec):
            let success = hotkeyMonitor.register(spec: spec, id: binding.id) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.executor.execute(binding.action)
                }
            }
            if !success {
                log.warning("Hotkey 登録失敗: \(spec.displayName, privacy: .public)")
            }

        case .gesture:
            gestureRoutes[binding.trigger.canonicalKey] = binding.action
        }
    }
}
