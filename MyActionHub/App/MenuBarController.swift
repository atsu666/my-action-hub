import AppKit
import Combine

/// メニューバーの常駐アイコンとプルダウンメニューを管理する。
///
/// `PermissionWatcher` を監視して、権限喪失時はアイコンを警告表示に切り替える。
/// `ConfigStore` を監視して IME Switcher の ON/OFF をメニューチェック状態に反映する。
@MainActor
final class MenuBarController {
    private let statusItem: NSStatusItem
    private var subscriptions = Set<AnyCancellable>()

    init() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        rebuildMenu()
        observePermissions()
        observeConfig()
        updateButton(hasIssue: PermissionWatcher.shared.hasIssue)
    }

    // MARK: - Button

    private func updateButton(hasIssue: Bool) {
        guard let button = statusItem.button else { return }
        let symbol = hasIssue ? "exclamationmark.triangle.fill" : "command"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "MyActionHub")
        // 警告アイコンは色付き、通常時は template
        image?.isTemplate = !hasIssue
        button.image = image
        // SF Symbol が万一読めなかった場合のテキストフォールバック
        button.title = image == nil ? (hasIssue ? "MAH⚠" : "MAH") : ""
    }

    // MARK: - Observation

    private func observePermissions() {
        PermissionWatcher.shared.$hasIssue
            .sink { [weak self] hasIssue in
                self?.updateButton(hasIssue: hasIssue)
            }
            .store(in: &subscriptions)
    }

    private func observeConfig() {
        ConfigStore.shared.$config
            .map(\.imeSwitcher.isEnabled)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &subscriptions)
    }

    // MARK: - Menu

    private func rebuildMenu() {
        let menu = NSMenu()

        menu.addItem(makeItem(
            title: "設定を開く…",
            keyEquivalent: ",",
            action: #selector(openSettings)
        ))
        menu.addItem(makeItem(
            title: "権限を確認…",
            action: #selector(openPermissions)
        ))

        menu.addItem(.separator())

        let imeItem = makeItem(
            title: "IME Switcher",
            action: #selector(toggleIMESwitcher)
        )
        imeItem.state = ConfigStore.shared.config.imeSwitcher.isEnabled ? .on : .off
        menu.addItem(imeItem)

        menu.addItem(.separator())

        menu.addItem(makeItem(
            title: "MyActionHub について",
            action: #selector(showAbout)
        ))
        menu.addItem(makeItem(
            title: "終了",
            keyEquivalent: "q",
            action: #selector(quit)
        ))

        statusItem.menu = menu
    }

    private func makeItem(title: String, keyEquivalent: String = "", action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    // MARK: - Actions

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func openPermissions() {
        // SwiftUI TabView の特定タブ選択 API は公式に無いので、設定ウィンドウを開いて
        // ユーザーが Permissions タブをクリックする流れに留める。
        SettingsWindowController.shared.show()
    }

    @objc private func toggleIMESwitcher() {
        ConfigStore.shared.config.imeSwitcher.isEnabled.toggle()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
