import Foundation
import Combine
import os.log

/// IME Switcher モジュールのコントローラ。
///
/// `ConfigStore` の `imeSwitcher` 設定を監視し、設定の変化に応じて
/// `ModifierTapDetector` を起動/停止/閾値更新する。
/// タップ検出時は `InputSource.select(_:)` で実際の IME 切替を行う。
@MainActor
final class IMESwitcher {
    private let log = Logger(subsystem: "com.appleple.myactionhub", category: "IMESwitcher")
    private let detector: ModifierTapDetector
    private var subscriptions = Set<AnyCancellable>()
    private weak var configStore: ConfigStore?

    init() {
        let store = ConfigStore.shared
        self.configStore = store
        self.detector = ModifierTapDetector()
        wireDetector()
        observeConfig(store)
        apply(store.config.imeSwitcher)
    }

    // MARK: - Wiring

    private func wireDetector() {
        // 注: CGEventTap のコールバック中で TIS を同期呼び出しすると、
        // たまにシステム側のタイムアウト判定で tap が無効化される。
        // async dispatch でコールバックを即座に返して回避する。
        detector.onLeftCommandTap = { [weak self] in
            guard let self, let cfg = self.configStore?.config.imeSwitcher, cfg.isEnabled else { return }
            let target = cfg.leftCommandTarget
            self.log.debug("左⌘ tap")
            DispatchQueue.main.async {
                InputSource.select(target)
            }
        }
        detector.onRightCommandTap = { [weak self] in
            guard let self, let cfg = self.configStore?.config.imeSwitcher, cfg.isEnabled else { return }
            let target = cfg.rightCommandTarget
            self.log.debug("右⌘ tap")
            DispatchQueue.main.async {
                InputSource.select(target)
            }
        }
    }

    private func observeConfig(_ store: ConfigStore) {
        store.$config
            .map(\.imeSwitcher)
            .removeDuplicates(by: Self.imeConfigEqual)
            .sink { [weak self] cfg in
                self?.apply(cfg)
            }
            .store(in: &subscriptions)
    }

    private static func imeConfigEqual(_ lhs: IMESwitcherConfig, _ rhs: IMESwitcherConfig) -> Bool {
        lhs.isEnabled == rhs.isEnabled &&
        lhs.tapThresholdSeconds == rhs.tapThresholdSeconds
    }

    private func apply(_ cfg: IMESwitcherConfig) {
        detector.tapThresholdSeconds = cfg.tapThresholdSeconds
        if cfg.isEnabled {
            detector.start()
        } else {
            detector.stop()
        }
    }
}
