import SwiftUI

/// 初回起動オンボーディングウィザード(3ステップ)。
struct OnboardingView: View {
    @ObservedObject private var store = ConfigStore.shared
    @ObservedObject private var watcher = PermissionWatcher.shared
    let onComplete: () -> Void

    @State private var step: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HeaderView(step: step)
            Divider()
            stepContent
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider()
            FooterBar(
                step: $step,
                canProceedFromStep0: watcher.accessibilityGranted && watcher.inputMonitoringGranted,
                onComplete: completeOnboarding
            )
        }
        .frame(width: 620, height: 440)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: PermissionsStep(watcher: watcher)
        case 1: LaunchAtLoginStep(store: store)
        case 2: GestureConflictStep()
        default: EmptyView()
        }
    }

    private func completeOnboarding() {
        store.config.general.hasCompletedOnboarding = true
        onComplete()
    }
}

// MARK: - Header

private struct HeaderView: View {
    let step: Int

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(.tint)
            VStack(alignment: .leading) {
                Text("MyActionHub へようこそ").font(.title2.bold())
                Text("ステップ \(step + 1) / 3").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(20)
    }
}

// MARK: - Footer

private struct FooterBar: View {
    @Binding var step: Int
    let canProceedFromStep0: Bool
    let onComplete: () -> Void

    var body: some View {
        HStack {
            if step > 0 {
                Button("戻る") { step -= 1 }
            }
            Spacer()
            primaryButton
        }
        .padding(16)
    }

    @ViewBuilder
    private var primaryButton: some View {
        if step < 2 {
            Button("次へ") { step += 1 }
                .keyboardShortcut(.defaultAction)
                .disabled(step == 0 && !canProceedFromStep0)
        } else {
            Button("完了", action: onComplete)
                .keyboardShortcut(.defaultAction)
        }
    }
}

// MARK: - Step 0: Permissions

private struct PermissionsStep: View {
    @ObservedObject var watcher: PermissionWatcher

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("必要な権限を付与してください")
                .font(.headline)
            Text("以下の権限はアプリの動作に必須です。「システム設定を開く」を押して MyActionHub にチェックを入れた後、このウィンドウに戻ってください。")
                .font(.callout)
                .foregroundStyle(.secondary)

            PermissionRow(
                title: "アクセシビリティ",
                description: "ウィンドウ操作と IME Switcher のキー検出に必須",
                granted: watcher.accessibilityGranted,
                openAction: PermissionChecker.openAccessibilitySettings
            )
            PermissionRow(
                title: "入力監視",
                description: "Modifier Tap 検出に必須",
                granted: watcher.inputMonitoringGranted,
                openAction: {
                    // リストへの追加を強制してから設定パネルを開く
                    _ = PermissionChecker.requestInputMonitoring()
                    PermissionChecker.openInputMonitoringSettings()
                }
            )

            Spacer()
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let description: String
    let granted: Bool
    let openAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: granted ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(granted ? .green : .orange)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("システム設定を開く", action: openAction)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }
}

// MARK: - Step 1: Launch at Login

private struct LaunchAtLoginStep: View {
    @ObservedObject var store: ConfigStore

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { store.config.general.launchAtLogin },
            set: { newValue in
                store.config.general.launchAtLogin = newValue
                if newValue { LoginItem.register() } else { LoginItem.unregister() }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ログイン時の自動起動")
                .font(.headline)
            Text("ON にすると、Mac を起動するたびに MyActionHub がバックグラウンドで自動的に立ち上がります。")
                .font(.callout)
                .foregroundStyle(.secondary)

            Toggle(isOn: launchBinding) {
                Text("ログイン時に自動起動する(推奨)")
            }
            .toggleStyle(.switch)
            .padding(.top, 4)

            Spacer()
        }
    }
}

// MARK: - Step 2: Gesture conflict

private struct GestureConflictStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("OS 標準ジェスチャーとの衝突")
                .font(.headline)
            Text("3本指/4本指のスワイプは macOS 標準のジェスチャー(Mission Control 等)と衝突します。MyActionHub に割り当てたジェスチャーが OS 側にも反応してしまう場合は、以下を OFF にしてください。")
                .font(.callout)
                .foregroundStyle(.secondary)

            conflictList

            Button("システム設定 > トラックパッドを開く", action: openTrackpadSettings)

            Spacer()
        }
    }

    @ViewBuilder
    private var conflictList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("システム設定 > トラックパッド > その他のジェスチャ")
                .font(.subheadline.monospaced())
            BulletRow(text: "Mission Control(3/4本指で上スワイプ)")
            BulletRow(text: "アプリケーション Exposé(3/4本指で下スワイプ)")
            BulletRow(text: "フルスクリーンアプリケーション間のスワイプ(左右)")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }

    private func openTrackpadSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.trackpad") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct BulletRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
            Text(text)
        }
        .font(.callout)
    }
}
