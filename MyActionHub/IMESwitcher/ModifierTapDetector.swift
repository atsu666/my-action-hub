import Cocoa
import Carbon.HIToolbox
import os.log

/// 左右⌘の「Modifier Tap」を検出する CGEventTap ベースの検出器。
///
/// Karabiner / ⌘英かな と同じセマンティクス:
/// - ⌘ 単独押下 → 押下時刻と「pollute」フラグ false を記録
/// - ⌘ 押下中に他のキー(修飾含む)が押されたら pollute = true
/// - ⌘ を離した瞬間、pollute = false かつ 押下→離鍵が threshold 秒以内なら **発火**
/// - ⌘ 自体のイベントは常に素通し(他アプリの ⌘ 検出を壊さない)
///
/// スレッドモデル: `start()` をメインスレッドから呼ぶ前提。
/// CGEventTap のコールバックは `start()` を呼んだスレッドのランループから
/// 同期的に発火するので、内部状態の排他は不要。
final class ModifierTapDetector {
    typealias Handler = () -> Void

    var onLeftCommandTap: Handler?
    var onRightCommandTap: Handler?
    /// 押下→離鍵が threshold 秒を超えたら発火しない。
    var tapThresholdSeconds: TimeInterval = 0.5

    private let log = Logger(subsystem: "com.appleple.myactionhub", category: "ModifierTapDetector")
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private struct ModState {
        var pressedAt: CFAbsoluteTime?
        var polluted: Bool = false
    }

    private var leftCmd  = ModState()
    private var rightCmd = ModState()

    // ⌘以外で現在押されている修飾キー keyCode セット
    // (⌘押下中に別の修飾が押されたら pollute するため)
    private var otherModifierKeyCodes: Set<Int> = []

    // MARK: - Lifecycle

    func start() {
        guard eventTap == nil else { return }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: userInfo
        ) else {
            log.error("CGEvent.tapCreate に失敗(アクセシビリティ/入力監視 権限未付与の可能性)")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log.info("ModifierTapDetector 開始")
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        eventTap = nil
        runLoopSource = nil
        leftCmd = ModState()
        rightCmd = ModState()
        otherModifierKeyCodes.removeAll()
        log.info("ModifierTapDetector 停止")
    }

    // MARK: - Event handling

    fileprivate func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .keyDown:
            handleKeyDown()
        case .flagsChanged:
            let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
            handleFlagsChanged(keyCode: keyCode)
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // システムがタップを一時的に無効化することがある(高負荷時 / 長時間アイドル後など)。
            // ハンドラを軽量化してもゼロにはならないため、再有効化のみ静かに行う。
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                log.debug("Tap re-enabled")
            }
        default:
            break
        }
    }

    private func handleKeyDown() {
        // ⌘押下中に通常キーが押されたら、両⌘の「単独タップ候補」は無効化
        leftCmd.polluted = true
        rightCmd.polluted = true
    }

    private func handleFlagsChanged(keyCode: Int) {
        let now = CFAbsoluteTimeGetCurrent()

        switch keyCode {
        case kVK_Command:
            updateCommandState(now: now, isLeft: true)
        case kVK_RightCommand:
            updateCommandState(now: now, isLeft: false)
        case kVK_Shift, kVK_RightShift,
             kVK_Option, kVK_RightOption,
             kVK_Control, kVK_RightControl,
             kVK_Function, kVK_CapsLock:
            if otherModifierKeyCodes.contains(keyCode) {
                otherModifierKeyCodes.remove(keyCode)
            } else {
                otherModifierKeyCodes.insert(keyCode)
                if leftCmd.pressedAt  != nil { leftCmd.polluted  = true }
                if rightCmd.pressedAt != nil { rightCmd.polluted = true }
            }
        default:
            break
        }
    }

    private func updateCommandState(now: CFAbsoluteTime, isLeft: Bool) {
        if isLeft {
            updateOne(state: &leftCmd, now: now, fire: onLeftCommandTap, other: &rightCmd)
        } else {
            updateOne(state: &rightCmd, now: now, fire: onRightCommandTap, other: &leftCmd)
        }
    }

    private func updateOne(
        state: inout ModState,
        now: CFAbsoluteTime,
        fire: Handler?,
        other: inout ModState
    ) {
        if state.pressedAt == nil {
            // 押下
            state.pressedAt = now
            state.polluted = false
            if other.pressedAt != nil {
                other.polluted = true
            }
        } else {
            // 離鍵 → 単独タップ判定
            let pressedAt = state.pressedAt!
            let elapsed = now - pressedAt
            state.pressedAt = nil
            if !state.polluted && elapsed <= tapThresholdSeconds {
                fire?()
            }
            state.polluted = false
        }
    }
}

// MARK: - C callback bridge

private let tapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let detector = Unmanaged<ModifierTapDetector>.fromOpaque(userInfo).takeUnretainedValue()
    detector.handle(type: type, event: event)
    return Unmanaged.passUnretained(event)
}
