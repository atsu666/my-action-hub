import SwiftUI
import Carbon.HIToolbox

/// Binding 1件の追加・編集モーダル(シート)。
///
/// 種別ドロップダウンに応じてパラメータUIが動的に切り替わる。
/// 保存時に Trigger 衝突をチェックし、衝突があればインラインエラー表示。
struct BindingEditor: View {
    enum Mode: Equatable {
        case add
        case edit(originalID: UUID)
    }

    let mode: Mode
    @Binding var draft: BindingDraft
    let existingBindings: [ActionBinding]
    let onSave: (ActionBinding) -> Void
    let onCancel: () -> Void

    @State private var validationError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            Divider()
            TriggerSection(draft: $draft)
            Divider()
            ActionSection(draft: $draft)
            errorRow
            Spacer(minLength: 0)
            footerBar
        }
        .padding(20)
        .frame(width: 520, height: 460)
    }

    @ViewBuilder
    private var header: some View {
        Text(mode == .add ? "Binding を追加" : "Binding を編集")
            .font(.headline)
    }

    @ViewBuilder
    private var errorRow: some View {
        if let validationError {
            Text(validationError)
                .font(.callout)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var footerBar: some View {
        HStack {
            Spacer()
            Button("キャンセル", role: .cancel, action: onCancel)
                .keyboardShortcut(.cancelAction)
            Button("保存", action: save)
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.isComplete)
        }
    }

    private func save() {
        guard let binding = draft.toBinding(existingID: existingID()) else {
            validationError = "入力に不備があります"
            return
        }
        let conflict = existingBindings.first { other in
            other.id != binding.id && other.trigger.canonicalKey == binding.trigger.canonicalKey
        }
        if let conflict {
            validationError = "Trigger「\(binding.trigger.displayName)」は既に〈\(conflict.action.displayName)〉に使われています"
            return
        }
        validationError = nil
        onSave(binding)
    }

    private func existingID() -> UUID? {
        if case .edit(let id) = mode { return id }
        return nil
    }
}

// MARK: - Trigger Section

private struct TriggerSection: View {
    @Binding var draft: BindingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trigger").font(.subheadline).foregroundStyle(.secondary)
            kindPicker
            detailView
        }
    }

    @ViewBuilder
    private var kindPicker: some View {
        Picker("種別", selection: $draft.triggerKind) {
            Text("ジェスチャー").tag(BindingDraft.TriggerKind.gesture)
            Text("キーボードショートカット").tag(BindingDraft.TriggerKind.hotkey)
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private var detailView: some View {
        switch draft.triggerKind {
        case .gesture:
            GestureTriggerDetail(draft: $draft)
        case .hotkey:
            KeyRecorder(hotkey: $draft.hotkey).frame(height: 36)
        }
    }
}

private struct GestureTriggerDetail: View {
    @Binding var draft: BindingDraft

    var body: some View {
        HStack {
            fingerCountPicker
            motionPicker
            if draft.gestureMotionKind == .swipe {
                directionPicker
            }
        }
    }

    @ViewBuilder
    private var fingerCountPicker: some View {
        Picker("指本数", selection: $draft.gestureFingers) {
            ForEach(Trigger.FingerCount.allCases, id: \.self) { f in
                Text(f.displayName).tag(f)
            }
        }
        .frame(maxWidth: 160)
    }

    @ViewBuilder
    private var motionPicker: some View {
        Picker("動作", selection: $draft.gestureMotionKind) {
            Text("スワイプ").tag(BindingDraft.GestureMotionKind.swipe)
            Text("Force Click").tag(BindingDraft.GestureMotionKind.forceClick)
        }
        .frame(maxWidth: 160)
    }

    @ViewBuilder
    private var directionPicker: some View {
        Picker("方向", selection: $draft.swipeDirection) {
            ForEach(Trigger.SwipeDirection.allCases, id: \.self) { d in
                Text(d.displayName).tag(d)
            }
        }
        .frame(maxWidth: 100)
    }
}

// MARK: - Action Section

private struct ActionSection: View {
    @Binding var draft: BindingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Action").font(.subheadline).foregroundStyle(.secondary)
            kindPicker
            detailView
        }
    }

    @ViewBuilder
    private var kindPicker: some View {
        Picker("種別", selection: $draft.actionKind) {
            ForEach(Action.Kind.userSelectable, id: \.self) { k in
                Text(k.displayName).tag(k)
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch draft.actionKind {
        case .snapWindowLeft, .snapWindowRight:
            SnapWidthRow(draft: $draft)
        case .toggleApp:
            AppPickerRow(draft: $draft)
        case .maximizeWindow, .toggleFinder, .selectInputSource:
            Text("(パラメータなし)").foregroundStyle(.secondary)
        }
    }
}

private struct SnapWidthRow: View {
    @Binding var draft: BindingDraft

    private var widthBinding: Binding<Double> {
        Binding(
            get: { Double(draft.snapWidthPercent) },
            set: { draft.snapWidthPercent = Int($0) }
        )
    }

    var body: some View {
        HStack {
            Text("横幅:")
            Slider(value: widthBinding, in: 10...90, step: 5)
            Text("\(draft.snapWidthPercent) %")
                .monospacedDigit()
                .frame(width: 50, alignment: .trailing)
        }
    }
}

private struct AppPickerRow: View {
    @Binding var draft: BindingDraft

    /// 直接入力で指定したい場合のための既知のシステムアプリプリセット。
    private let presets: [(label: String, bundleID: String)] = [
        ("Finder",   "com.apple.finder"),
        ("Safari",   "com.apple.Safari"),
        ("Mail",     "com.apple.mail"),
        ("Messages", "com.apple.MobileSMS"),
        ("Music",    "com.apple.Music"),
        ("Calendar", "com.apple.iCal"),
        ("Notes",    "com.apple.Notes"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("対象 bundle ID:")
                TextField("com.example.app", text: $draft.appBundleID)
                    .textFieldStyle(.roundedBorder)
                Button("選択…", action: selectApp)
            }
            HStack {
                Text("プリセット:").font(.caption).foregroundStyle(.secondary)
                Menu("システムアプリから選ぶ") {
                    ForEach(presets, id: \.bundleID) { preset in
                        Button(preset.label) {
                            draft.appBundleID = preset.bundleID
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .controlSize(.small)
                Spacer()
            }
        }
    }

    private func selectApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.showsHiddenFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let bundle = Bundle(url: url), let id = bundle.bundleIdentifier {
            draft.appBundleID = id
        }
    }
}

// MARK: - Draft

/// BindingEditor の編集中状態。draft → ActionBinding 変換は `toBinding()` で行う。
struct BindingDraft: Equatable {
    enum TriggerKind: Equatable { case gesture, hotkey }
    enum GestureMotionKind: Equatable { case swipe, forceClick }

    var triggerKind: TriggerKind = .gesture
    var gestureFingers: Trigger.FingerCount = .three
    var gestureMotionKind: GestureMotionKind = .swipe
    var swipeDirection: Trigger.SwipeDirection = .up
    var hotkey: Trigger.HotkeySpec?

    var actionKind: Action.Kind = .maximizeWindow
    var snapWidthPercent: Int = 50
    var appBundleID: String = ""

    static func from(_ binding: ActionBinding) -> BindingDraft {
        var d = BindingDraft()
        switch binding.trigger {
        case .gesture(let fingers, let motion):
            d.triggerKind = .gesture
            d.gestureFingers = fingers
            switch motion {
            case .swipe(let dir):
                d.gestureMotionKind = .swipe
                d.swipeDirection = dir
            case .forceClick:
                d.gestureMotionKind = .forceClick
            }
        case .hotkey(let spec):
            d.triggerKind = .hotkey
            d.hotkey = spec
        }
        switch binding.action {
        case .maximizeWindow:
            d.actionKind = .maximizeWindow
        case .snapWindowLeft(let pct):
            d.actionKind = .snapWindowLeft
            d.snapWidthPercent = pct
        case .snapWindowRight(let pct):
            d.actionKind = .snapWindowRight
            d.snapWidthPercent = pct
        case .toggleFinder:
            d.actionKind = .toggleFinder
        case .toggleApp(let id):
            d.actionKind = .toggleApp
            d.appBundleID = id
        case .selectInputSource:
            d.actionKind = .selectInputSource
        }
        return d
    }

    var isComplete: Bool {
        switch triggerKind {
        case .gesture: break
        case .hotkey:
            guard let hk = hotkey, hk.modifiers.hasRequiredModifier else { return false }
        }
        switch actionKind {
        case .toggleApp:
            return !appBundleID.isEmpty
        default:
            return true
        }
    }

    func toBinding(existingID: UUID?) -> ActionBinding? {
        let trigger: Trigger
        switch triggerKind {
        case .gesture:
            let motion: Trigger.GestureMotion
            switch gestureMotionKind {
            case .swipe:      motion = .swipe(swipeDirection)
            case .forceClick: motion = .forceClick
            }
            trigger = .gesture(fingers: gestureFingers, motion: motion)
        case .hotkey:
            guard let hk = hotkey, hk.modifiers.hasRequiredModifier else { return nil }
            trigger = .hotkey(hk)
        }

        let action: Action
        switch actionKind {
        case .maximizeWindow:
            action = .maximizeWindow
        case .snapWindowLeft:
            action = .snapWindowLeft(widthPercent: snapWidthPercent)
        case .snapWindowRight:
            action = .snapWindowRight(widthPercent: snapWidthPercent)
        case .toggleFinder:
            action = .toggleFinder
        case .toggleApp:
            guard !appBundleID.isEmpty else { return nil }
            action = .toggleApp(bundleID: appBundleID)
        case .selectInputSource:
            return nil
        }

        return ActionBinding(id: existingID ?? UUID(), trigger: trigger, action: action)
    }
}
