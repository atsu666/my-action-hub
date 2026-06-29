import SwiftUI

struct PermissionsTab: View {
    @State private var accessibilityGranted = PermissionChecker.isAccessibilityGranted()
    @State private var inputMonitoringGranted = PermissionChecker.isInputMonitoringGranted()

    /// 3秒ごとにポーリングして UI を更新
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                permissionRow(
                    title: "アクセシビリティ",
                    description: "ウィンドウ操作とキーボードイベント監視に必須",
                    granted: accessibilityGranted,
                    action: { PermissionChecker.openAccessibilitySettings() }
                )

                permissionRow(
                    title: "入力監視",
                    description: "Modifier Tap 検出に必要",
                    granted: inputMonitoringGranted,
                    action: {
                        _ = PermissionChecker.requestInputMonitoring()
                        PermissionChecker.openInputMonitoringSettings()
                    }
                )
            }

            Section {
                Text("MultitouchSupport(非公開API)はシステムの正規権限項目がなく、別途の付与は不要です。詳細は docs/adr/0001 を参照。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onReceive(timer) { _ in
            accessibilityGranted = PermissionChecker.isAccessibilityGranted()
            inputMonitoringGranted = PermissionChecker.isInputMonitoringGranted()
        }
    }

    @ViewBuilder
    private func permissionRow(title: String, description: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(alignment: .center) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? .green : .orange)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(granted ? "システム設定を開く" : "付与する", action: action)
        }
        .padding(.vertical, 4)
    }
}
