import SwiftUI

struct IMESwitcherTab: View {
    @ObservedObject private var store = ConfigStore.shared

    var body: some View {
        Form {
            Section {
                Toggle("IME Switcher を有効化", isOn: $store.config.imeSwitcher.isEnabled)
            }

            Section("⌘ キーの役割") {
                Picker("左⌘", selection: $store.config.imeSwitcher.leftCommandTarget) {
                    Text("ABC(英数)").tag(Action.InputSourceTarget.ascii)
                    Text("Hiragana(かな)").tag(Action.InputSourceTarget.hiragana)
                }
                Picker("右⌘", selection: $store.config.imeSwitcher.rightCommandTarget) {
                    Text("ABC(英数)").tag(Action.InputSourceTarget.ascii)
                    Text("Hiragana(かな)").tag(Action.InputSourceTarget.hiragana)
                }
            }
            .disabled(!store.config.imeSwitcher.isEnabled)

            Section("タップ判定") {
                VStack(alignment: .leading) {
                    HStack {
                        Text("閾値:")
                        Slider(
                            value: $store.config.imeSwitcher.tapThresholdSeconds,
                            in: 0.1...1.5,
                            step: 0.05
                        )
                        Text("\(store.config.imeSwitcher.tapThresholdSeconds, specifier: "%.2f") 秒")
                            .monospacedDigit()
                            .frame(width: 60, alignment: .trailing)
                    }
                    Text("⌘を押してから離すまでがこの時間以内のとき、IMEを切替。⌘+他キー の組み合わせでは発火しない。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!store.config.imeSwitcher.isEnabled)
        }
        .formStyle(.grouped)
    }
}
