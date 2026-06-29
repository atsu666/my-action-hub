import SwiftUI

struct GeneralTab: View {
    @ObservedObject private var store = ConfigStore.shared

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { store.config.general.launchAtLogin },
            set: { newValue in
                store.config.general.launchAtLogin = newValue
                if newValue { LoginItem.register() } else { LoginItem.unregister() }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle("ログイン時に自動起動", isOn: launchAtLoginBinding)
            }

            Section {
                LabeledContent("バージョン", value: appVersion)
                LabeledContent("Bundle ID", value: Bundle.main.bundleIdentifier ?? "-")
            }

            Section {
                Text("OS のジェスチャー設定との衝突回避は「システム設定 > トラックパッド > その他のジェスチャ」で個別 OFF してください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var appVersion: String {
        let dict = Bundle.main.infoDictionary
        let short = dict?["CFBundleShortVersionString"] as? String ?? "?"
        let build = dict?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
