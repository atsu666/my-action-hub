import Foundation
import Carbon.HIToolbox

/// Binding の発火条件。
///
/// Modifier Tap(機能A の IME Switcher で使う左右⌘単独タップ)は
/// Trigger 種別に **含めない**。設計理由は docs/adr/0002 を参照。
enum Trigger: Codable, Hashable {
    case gesture(fingers: FingerCount, motion: GestureMotion)
    case hotkey(HotkeySpec)

    enum FingerCount: Int, Codable, Hashable, CaseIterable {
        case three = 3
        case four  = 4

        var displayName: String { "\(rawValue)本指" }
    }

    enum SwipeDirection: String, Codable, Hashable, CaseIterable {
        case up, down, left, right

        var displayName: String {
            switch self {
            case .up:    return "上"
            case .down:  return "下"
            case .left:  return "左"
            case .right: return "右"
            }
        }
    }

    enum GestureMotion: Codable, Hashable {
        case swipe(SwipeDirection)
        case forceClick

        var displayName: String {
            switch self {
            case .swipe(let dir): return "\(dir.displayName)スワイプ"
            case .forceClick:     return "Force Click"
            }
        }
    }

    /// グローバルホットキーの仕様。
    /// 修飾キー(⌘/⌥/⌃)のいずれかが最低1つ必須。Shift 単体は不可。
    struct HotkeySpec: Codable, Hashable {
        let keyCode: UInt32        // Carbon キーコード(kVK_ANSI_F 等)
        let modifiers: Modifiers   // ビットフラグ

        struct Modifiers: OptionSet, Codable, Hashable {
            let rawValue: UInt32
            static let command = Modifiers(rawValue: 1 << 0)
            static let option  = Modifiers(rawValue: 1 << 1)
            static let control = Modifiers(rawValue: 1 << 2)
            static let shift   = Modifiers(rawValue: 1 << 3)

            /// Carbon の cmdKey / optionKey / controlKey / shiftKey フラグへ変換。
            var carbonFlags: UInt32 {
                var result: UInt32 = 0
                if contains(.command) { result |= UInt32(cmdKey) }
                if contains(.option)  { result |= UInt32(optionKey) }
                if contains(.control) { result |= UInt32(controlKey) }
                if contains(.shift)   { result |= UInt32(shiftKey) }
                return result
            }

            /// 修飾キー必須(⌘/⌥/⌃ のいずれか)、かつ Shift 単体は不可。
            var hasRequiredModifier: Bool {
                contains(.command) || contains(.option) || contains(.control)
            }
        }

        var displayName: String {
            var parts: [String] = []
            if modifiers.contains(.control) { parts.append("⌃") }
            if modifiers.contains(.option)  { parts.append("⌥") }
            if modifiers.contains(.shift)   { parts.append("⇧") }
            if modifiers.contains(.command) { parts.append("⌘") }
            parts.append(KeyCodeNames.name(for: keyCode))
            return parts.joined()
        }
    }

    var displayName: String {
        switch self {
        case .gesture(let fingers, let motion):
            return "\(fingers.displayName) \(motion.displayName)"
        case .hotkey(let spec):
            return spec.displayName
        }
    }
}

/// 衝突チェック用に Trigger を一意な文字列にしたい場合に使う。
extension Trigger {
    var canonicalKey: String {
        switch self {
        case .gesture(let fingers, .swipe(let dir)):
            return "gesture.\(fingers.rawValue).swipe.\(dir.rawValue)"
        case .gesture(let fingers, .forceClick):
            return "gesture.\(fingers.rawValue).forceClick"
        case .hotkey(let spec):
            return "hotkey.\(spec.modifiers.rawValue).\(spec.keyCode)"
        }
    }
}

/// Carbon キーコード → 表示文字列。
/// 主要キーのみカバー。網羅性より見やすさ優先。
enum KeyCodeNames {
    static func name(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space:        return "Space"
        case kVK_Return:       return "Return"
        case kVK_Tab:          return "Tab"
        case kVK_Escape:       return "Esc"
        case kVK_Delete:       return "⌫"
        case kVK_ForwardDelete:return "⌦"
        case kVK_LeftArrow:    return "←"
        case kVK_RightArrow:   return "→"
        case kVK_UpArrow:      return "↑"
        case kVK_DownArrow:    return "↓"
        case kVK_F1:  return "F1"
        case kVK_F2:  return "F2"
        case kVK_F3:  return "F3"
        case kVK_F4:  return "F4"
        case kVK_F5:  return "F5"
        case kVK_F6:  return "F6"
        case kVK_F7:  return "F7"
        case kVK_F8:  return "F8"
        case kVK_F9:  return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        default: return "Key(\(keyCode))"
        }
    }
}
