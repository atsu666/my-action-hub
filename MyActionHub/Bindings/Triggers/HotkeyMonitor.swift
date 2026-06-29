import Carbon
import Carbon.HIToolbox
import Foundation
import os.log

/// Carbon の `RegisterEventHotKey` を Swift から扱うラッパー。
///
/// グローバルホットキーを登録し、押下時に登録時の closure を呼ぶ。
/// Trigger.HotkeySpec に基づいて Binding ごとに登録・解除する。
///
/// スレッドモデル: メインスレッド限定。Carbon の Event Handler は
/// メインスレッドのイベントループから直接 dispatch される。
final class HotkeyMonitor {
    typealias Handler = () -> Void

    private let log = Logger(subsystem: "com.appleple.myactionhub", category: "HotkeyMonitor")

    /// 本アプリ固有の FourCharCode("MAHB" = MyActionHub)。
    /// 他アプリと衝突しないようユニークな値を採用。
    /// 0x4D=M / 0x41=A / 0x48=H / 0x42=B
    private static let signature: OSType = 0x4D414842

    private var nextSequence: UInt32 = 1
    private var refs: [UUID: EventHotKeyRef] = [:]
    private var handlers: [UInt32: Handler] = [:]
    private var eventHandlerInstalled = false

    /// `spec` で指定されたホットキーを登録。失敗時は false。
    /// (他アプリが同じキー組み合わせを既に登録している等で失敗しうる)
    @discardableResult
    func register(spec: Trigger.HotkeySpec, id: UUID, handler: @escaping Handler) -> Bool {
        installHandlerIfNeeded()

        let sequence = nextSequence
        nextSequence += 1

        let hotKeyID = EventHotKeyID(signature: HotkeyMonitor.signature, id: sequence)
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            spec.keyCode,
            spec.modifiers.carbonFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let ref = hotKeyRef else {
            log.error("RegisterEventHotKey 失敗: status=\(status, privacy: .public) spec=\(spec.displayName, privacy: .public)")
            return false
        }

        refs[id] = ref
        handlers[sequence] = handler
        log.debug("Hotkey 登録: \(spec.displayName, privacy: .public)")
        return true
    }

    func unregister(id: UUID) {
        guard let ref = refs.removeValue(forKey: id) else { return }
        UnregisterEventHotKey(ref)
        // sequence → handler のクリーンアップは sequence が分からないのでスキップ
        // (Engine 側で unregisterAll → register でフルリセットする運用)
    }

    func unregisterAll() {
        for ref in refs.values {
            UnregisterEventHotKey(ref)
        }
        refs.removeAll()
        handlers.removeAll()
    }

    // MARK: - Internal

    fileprivate func dispatch(sequence: UInt32) {
        handlers[sequence]?()
    }

    private func installHandlerIfNeeded() {
        guard !eventHandlerInstalled else { return }
        eventHandlerInstalled = true

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &eventType,
            userInfo,
            nil
        )
    }
}

// MARK: - C callback bridge

private let hotkeyEventHandler: EventHandlerUPP = { _, eventRef, userInfo in
    guard let userInfo, let eventRef else { return OSStatus(eventNotHandledErr) }
    let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        eventRef,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    if status == noErr {
        monitor.dispatch(sequence: hotKeyID.id)
    }
    return noErr
}

