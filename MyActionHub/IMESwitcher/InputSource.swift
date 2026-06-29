import Foundation
import Carbon
import os.log

/// `TISSelectInputSource` で macOS の入力ソースを切り替えるラッパー。
///
/// IME Switcher が呼ぶ「ABC 系」「Hiragana 系」の代表的な ID を
/// 候補リストとして持ち、有効化済みの中から最初に見つかったものを選ぶ。
enum InputSource {
    private static let log = Logger(subsystem: "com.appleple.myactionhub", category: "InputSource")

    /// ABC 系(英数入力)。macOS で「ABC」キーボードレイアウトに切替。
    static let asciiCandidates = [
        "com.apple.keylayout.ABC",
        "com.apple.keylayout.US",
        "com.apple.keylayout.USInternational-PC",
    ]

    /// Hiragana 系(ことえり / Kotoeri 日本語入力モード)。
    /// macOS バージョンによって ID が変わるため候補を複数用意。
    static let hiraganaCandidates = [
        "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese",
        "com.apple.inputmethod.Kotoeri.Japanese",
        "com.apple.inputmethod.Kotoeri.Japanese.Hiragana",
        "com.apple.inputmethod.Kotoeri.Roman", // fallback
        "jp.sourceforge.inputmethod.aquaskk",  // AquaSKK
        "com.google.inputmethod.Japanese.base",// Google IME
    ]

    static func select(_ target: Action.InputSourceTarget) {
        let candidates: [String]
        switch target {
        case .ascii:    candidates = asciiCandidates
        case .hiragana: candidates = hiraganaCandidates
        }

        guard let source = findEnabled(matching: candidates) else {
            log.error("対象の Input Source が見つかりませんでした: \(target.rawValue, privacy: .public)")
            return
        }

        let status = TISSelectInputSource(source)
        if status != noErr {
            log.error("TISSelectInputSource 失敗: status=\(status, privacy: .public)")
        }
    }

    private static func findEnabled(matching candidateIDs: [String]) -> TISInputSource? {
        guard let cfList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }

        // 候補リストの順に検索して、最初にマッチした有効ソースを返す
        for candidateID in candidateIDs {
            for source in cfList where isASCIICapableOrSelectable(source) {
                if let id = sourceID(source), id == candidateID {
                    return source
                }
            }
        }
        return nil
    }

    private static func sourceID(_ source: TISInputSource) -> String? {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    /// 「選択可能(Selectable)」または「ASCII Capable」なソースだけを対象にする。
    /// 内部用の隠しソースを除外する。
    private static func isASCIICapableOrSelectable(_ source: TISInputSource) -> Bool {
        guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable) else {
            return false
        }
        return Unmanaged<CFBoolean>.fromOpaque(ptr).takeUnretainedValue() == kCFBooleanTrue
    }
}
