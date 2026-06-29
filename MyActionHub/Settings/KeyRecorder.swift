import AppKit
import SwiftUI

/// キーボードショートカット入力フィールド。
/// クリックすると記録モードに入り、修飾キー必須(⌘/⌥/⌃)のキー組み合わせを記録する。
struct KeyRecorder: NSViewRepresentable {
    @Binding var hotkey: Trigger.HotkeySpec?

    func makeNSView(context: Context) -> KeyRecorderNSView {
        let view = KeyRecorderNSView()
        view.onChange = { newValue in
            DispatchQueue.main.async { self.hotkey = newValue }
        }
        view.currentHotkey = hotkey
        return view
    }

    func updateNSView(_ nsView: KeyRecorderNSView, context: Context) {
        nsView.currentHotkey = hotkey
        nsView.needsDisplay = true
    }
}

final class KeyRecorderNSView: NSView {
    var currentHotkey: Trigger.HotkeySpec?
    var onChange: ((Trigger.HotkeySpec?) -> Void)?

    private var isRecording = false {
        didSet { needsDisplay = true }
    }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let bg = isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.2)
                              : NSColor.controlBackgroundColor
        bg.setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        path.fill()

        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        let text: String
        if isRecording {
            text = "キーを押してください…(⌘/⌥/⌃ + 任意キー)"
        } else if let h = currentHotkey {
            text = h.displayName
        } else {
            text = "クリックして記録"
        }

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: style
        ]
        let attr = NSAttributedString(string: text, attributes: attrs)
        let textSize = attr.size()
        let rect = NSRect(
            x: 0,
            y: (bounds.height - textSize.height) / 2,
            width: bounds.width,
            height: textSize.height
        )
        attr.draw(in: rect)
    }

    override func mouseDown(with event: NSEvent) {
        isRecording.toggle()
        if isRecording {
            window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        let modifiers = modifiersFromNSEvent(event)
        guard modifiers.hasRequiredModifier else {
            NSSound.beep()
            return
        }
        let spec = Trigger.HotkeySpec(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        currentHotkey = spec
        isRecording = false
        onChange?(spec)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    private func modifiersFromNSEvent(_ event: NSEvent) -> Trigger.HotkeySpec.Modifiers {
        var result: Trigger.HotkeySpec.Modifiers = []
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.option)  { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.shift)   { result.insert(.shift) }
        return result
    }
}
