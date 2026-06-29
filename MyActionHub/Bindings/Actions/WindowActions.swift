import Cocoa
import ApplicationServices
import os.log

/// Accessibility API を使ったウィンドウ操作。
///
/// 対象は常に**フロントアプリのフロントウィンドウ**、対象スクリーンは
/// **そのウィンドウの中心が乗っているスクリーン**。
///
/// 座標系の注意:
/// - AX(`kAXPositionAttribute`)は **CG / Quartz 座標**(プライマリスクリーン左上原点、Y下向き)
/// - NSScreen.frame は **Cocoa 座標**(プライマリスクリーン左下原点、Y上向き)
/// - 両者の変換は `convertToAXCoordinates(_:)` で行う
enum WindowActions {
    private static let log = Logger(subsystem: "com.appleple.myactionhub", category: "WindowActions")

    static func maximize() {
        guard let window = focusedWindow() else {
            log.warning("フロントウィンドウが取得できない")
            return
        }
        guard let visibleAX = visibleFrameAXContainingCenterOf(window) else { return }
        set(window: window, frame: visibleAX)
    }

    static func snapLeft(widthPercent: Int) {
        guard let window = focusedWindow() else { return }
        guard let visibleAX = visibleFrameAXContainingCenterOf(window) else { return }
        let clamped = max(10, min(100, widthPercent))
        let target = CGRect(
            x: visibleAX.origin.x,
            y: visibleAX.origin.y,
            width: visibleAX.width * CGFloat(clamped) / 100.0,
            height: visibleAX.height
        )
        set(window: window, frame: target)
    }

    static func snapRight(widthPercent: Int) {
        guard let window = focusedWindow() else { return }
        guard let visibleAX = visibleFrameAXContainingCenterOf(window) else { return }
        let clamped = max(10, min(100, widthPercent))
        let width = visibleAX.width * CGFloat(clamped) / 100.0
        let target = CGRect(
            x: visibleAX.origin.x + (visibleAX.width - width),
            y: visibleAX.origin.y,
            width: width,
            height: visibleAX.height
        )
        set(window: window, frame: target)
    }

    // MARK: - AX helpers

    private static func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: AnyObject?
        let status = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &value
        )
        guard status == .success, let window = value else { return nil }
        return (window as! AXUIElement)
    }

    private static func axFrame(of window: AXUIElement) -> CGRect? {
        var positionValue: AnyObject?
        var sizeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success
        else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }

    private static func set(window: AXUIElement, frame: CGRect) {
        var position = frame.origin
        var size = frame.size
        guard let posValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else { return }
        // サイズが先のことが多いが、両方順に投げる
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        // 念のため位置をもう一度(sizeを設定した結果クランプされる場合がある)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
    }

    /// ウィンドウの中心が乗っているスクリーンの visibleFrame を **AX 座標** で返す。
    private static func visibleFrameAXContainingCenterOf(_ window: AXUIElement) -> CGRect? {
        guard let winAX = axFrame(of: window) else { return nil }
        let centerAX = CGPoint(x: winAX.midX, y: winAX.midY)
        guard let screen = screenContaining(axPoint: centerAX) else { return nil }
        return convertToAXCoordinates(screen.visibleFrame)
    }

    /// AX 座標で与えられた点を含む NSScreen を返す。なければプライマリ。
    private static func screenContaining(axPoint: CGPoint) -> NSScreen? {
        guard let primary = NSScreen.screens.first else { return nil }
        let primaryMaxY = primary.frame.maxY

        for screen in NSScreen.screens {
            // NSScreen.frame は Cocoa 座標 → AX 座標へ変換して当たり判定
            let ns = screen.frame
            let axFrame = CGRect(
                x: ns.origin.x,
                y: primaryMaxY - ns.origin.y - ns.height,
                width: ns.width,
                height: ns.height
            )
            if axFrame.contains(axPoint) {
                return screen
            }
        }
        return NSScreen.main ?? primary
    }

    /// NSScreen の Cocoa 座標矩形を AX 座標(Quartz)へ変換。
    private static func convertToAXCoordinates(_ cocoaRect: CGRect) -> CGRect {
        guard let primary = NSScreen.screens.first else { return cocoaRect }
        let primaryMaxY = primary.frame.maxY
        return CGRect(
            x: cocoaRect.origin.x,
            y: primaryMaxY - cocoaRect.origin.y - cocoaRect.height,
            width: cocoaRect.width,
            height: cocoaRect.height
        )
    }
}
