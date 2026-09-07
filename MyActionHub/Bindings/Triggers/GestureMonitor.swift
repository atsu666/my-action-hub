import Cocoa
import os.log

/// 3/4本指のトラックパッドジェスチャーを検出する。
///
/// - **スワイプ検出**: 非公開 `MultitouchSupport.framework` のフレームコールバックで
///   接触点の正規化座標を取得し、移動量で4方向に量子化(設計の経緯は docs/adr/0001)
/// - **Force Click 検出**: `NSEvent.addGlobalMonitorForEvents(matching: .pressure)` で
///   `stage == 2`(2段階目の強押し込み)を検出し、その時の接触数で 3/4本指を判定
/// - **先勝ちルール**: スワイプ閾値と圧力ステージのどちらかが先に成立した方が勝つ。
///   発火後は全指が離れるまで再発火しない。
///
/// - **スリープ復帰時の再接続**: スリープ/ハイバネートを跨ぐと `MTDeviceRef` が無効化され、
///   エラーも出さずにフレームコールバックが永久に来なくなる。wake 通知でデバイスを
///   作り直す(詳細は下の `restartMultitouch`)。
///
/// スレッドモデル: `start()` / `stop()` はメインスレッドから呼ぶ前提。
/// MT のコールバックはフレームワーク側のスレッドから呼ばれるが、
/// `DispatchQueue.main.async` で状態更新は全てメイン上で行うため
/// 内部状態の排他は不要。
final class GestureMonitor {
    typealias SwipeHandler = (Trigger.FingerCount, Trigger.SwipeDirection) -> Void
    typealias ForceClickHandler = (Trigger.FingerCount) -> Void

    var onSwipe: SwipeHandler?
    var onForceClick: ForceClickHandler?

    /// 正規化座標(0〜1)での移動量しきい値。0.15 ≒ 中型トラックパッドで約 3cm。
    private let swipeDistanceThreshold: CGFloat = 0.15

    /// C コールバックから参照するためのシングルトン用 weak 参照。
    /// 排他のため start()/stop() は @MainActor。
    static weak var shared: GestureMonitor?

    private let log = Logger(subsystem: "com.appleple.myactionhub", category: "GestureMonitor")
    private var devices: [MTDeviceRef] = []
    /// `MTDeviceCreateList` フォールバック時の配列。要素の所有者なので保持が必要。
    private var deviceList: CFArray?
    /// `devices` が `MTDeviceCreateDefault` 由来か(= 自前で release すべきか)。
    private var devicesAreOwned = false
    private var pressureMonitor: Any?
    private var isRunning = false

    /// wake 系の NSWorkspace 通知の購読トークン。
    private var workspaceObservers: [NSObjectProtocol] = []
    /// 短時間に複数の wake 通知が来たときに再接続を1回にまとめるためのデバウンス。
    private var restartWorkItem: DispatchWorkItem?
    /// MTDeviceIsRunning が false に落ちたケースを拾う保険。
    private var watchdogTimer: Timer?

    private enum State {
        case idle
        case armed(count: Int, startPositions: [Int32: CGPoint])
        case fired
    }

    private var state: State = .idle
    /// MT コールバックから書き込み、pressure ハンドラから読み込み。main queue 上のみ。
    private var currentFingerCount: Int = 0

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true
        GestureMonitor.shared = self
        startMultitouch()
        startPressureMonitor()
        startWakeObservers()
        startWatchdog()
        log.info("GestureMonitor 開始 (devices=\(self.devices.count, privacy: .public))")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        stopWatchdog()
        stopWakeObservers()
        restartWorkItem?.cancel()
        restartWorkItem = nil
        stopMultitouch()
        stopPressureMonitor()
        state = .idle
        currentFingerCount = 0
        if GestureMonitor.shared === self {
            GestureMonitor.shared = nil
        }
        log.info("GestureMonitor 停止")
    }

    // MARK: - Wake recovery

    /// スリープ復帰後、MT デバイスを張り直すきっかけとなる通知を購読する。
    ///
    /// `didWakeNotification` だけだと、ふたを開けずに画面だけ復帰したケースや
    /// ファストユーザスイッチからの復帰を取りこぼすため 3 種類を購読し、
    /// 実際の再接続はデバウンスで1回にまとめる。
    private func startWakeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [NSNotification.Name] = [
            NSWorkspace.didWakeNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
        ]
        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.scheduleMultitouchRestart(reason: name.rawValue)
            }
            workspaceObservers.append(token)
        }
    }

    private func stopWakeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        for token in workspaceObservers {
            center.removeObserver(token)
        }
        workspaceObservers.removeAll()
    }

    /// 復帰直後は HID スタックがまだ整っておらず `MTDeviceCreateDefault` が
    /// 使えないデバイスを返すことがあるため、少し待ってから張り直す。
    private func scheduleMultitouchRestart(reason: String, delay: TimeInterval = 2.0) {
        restartWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.restartMultitouch(reason: reason)
        }
        restartWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func restartMultitouch(reason: String) {
        guard isRunning else { return }
        stopMultitouch()
        startMultitouch()
        state = .idle
        currentFingerCount = 0
        log.info("""
            Multitouch 再接続 (reason=\(reason, privacy: .public), \
            devices=\(self.devices.count, privacy: .public))
            """)
    }

    // MARK: - Watchdog

    /// wake 通知が飛ばない経路(外付け Magic Trackpad の抜き差しなど)で
    /// デバイスが止まった場合に拾う保険。フレーム受信の有無では判定できない
    /// (指を触れていない間は 0 フレームが正常)ため `MTDeviceIsRunning` を見る。
    private func startWatchdog() {
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkDevicesAlive()
        }
    }

    private func stopWatchdog() {
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    private func checkDevicesAlive() {
        guard isRunning else { return }
        let dead = devices.isEmpty || devices.contains { !MTDeviceIsRunning($0) }
        guard dead else { return }
        log.warning("Multitouch デバイスが停止状態。再接続します")
        restartMultitouch(reason: "watchdog")
    }

    // MARK: - Multitouch

    private func startMultitouch() {
        // 注: macOS Sequoia/Tahoe では MTDeviceCreateList が「familyID invalid /
        // deviceID 0x0」の壊れたデバイスを返すことがあるため、MTDeviceCreateDefault
        // を優先で使う。
        if let dev = MTDeviceCreateDefault() {
            devices.append(dev)
            devicesAreOwned = true
        }

        // Default で取れなかったときだけ list にフォールバック
        if devices.isEmpty, let unmanaged = MTDeviceCreateList() {
            // 配列の要素はこの CFArray が所有しているので、デバイスを使い終わるまで
            // 配列自体を保持しておく(ローカルのまま解放するとポインタが宙に浮く)。
            let cfArray = unmanaged.takeRetainedValue()
            deviceList = cfArray
            devicesAreOwned = false
            if let array = cfArray as? [AnyObject] {
                for obj in array {
                    let opaque = Unmanaged.passUnretained(obj).toOpaque()
                    devices.append(OpaquePointer(opaque))
                }
            }
        }

        if devices.isEmpty {
            log.warning("Multitouch デバイスが見つかりません")
            return
        }

        for device in devices {
            _ = MTRegisterContactFrameCallback(device, multitouchFrameCallback)
            _ = MTDeviceStart(device, 0)
        }
    }

    private func stopMultitouch() {
        for device in devices {
            _ = MTDeviceStop(device)
            _ = MTUnregisterContactFrameCallback(device, multitouchFrameCallback)
            if devicesAreOwned {
                MTDeviceRelease(device)
            }
        }
        devices.removeAll()
        deviceList = nil
        devicesAreOwned = false
    }

    fileprivate func handleFrame(touches: [MTTouch]) {
        // state == 3 (making touch) or 4 (touching) を「アクティブ接触」とみなす
        let active = touches.filter { $0.state == 3 || $0.state == 4 }
        let count = active.count
        currentFingerCount = count

        if count == 0 {
            state = .idle
            return
        }

        switch state {
        case .idle:
            if count == 3 || count == 4 {
                state = .armed(count: count, startPositions: makePositionMap(active))
            }

        case .armed(let armedCount, let starts):
            if count != armedCount {
                // 指の本数が変わった
                if count == 3 || count == 4 {
                    state = .armed(count: count, startPositions: makePositionMap(active))
                } else {
                    state = .idle
                }
                return
            }
            // 各指の開始位置からの移動量を集計(全指の delta 平均で方向判定)
            var sumDx: CGFloat = 0
            var sumDy: CGFloat = 0
            var matchedCount = 0
            for t in active {
                guard let start = starts[t.identifier] else { continue }
                sumDx += CGFloat(t.normalized.position.x) - start.x
                sumDy += CGFloat(t.normalized.position.y) - start.y
                matchedCount += 1
            }
            guard matchedCount > 0 else { return }
            let avgDx = sumDx / CGFloat(matchedCount)
            let avgDy = sumDy / CGFloat(matchedCount)

            if max(abs(avgDx), abs(avgDy)) >= swipeDistanceThreshold {
                let direction: Trigger.SwipeDirection
                if abs(avgDx) > abs(avgDy) {
                    direction = avgDx > 0 ? .right : .left
                } else {
                    // MultitouchSupport の normalized Y は **下端=0、上端=1**(数学的)。
                    // すなわち Y が増える方向 = トラックパッド上で奥向き = 「上スワイプ」。
                    direction = avgDy > 0 ? .up : .down
                }
                guard let fc = Trigger.FingerCount(rawValue: armedCount) else { return }
                state = .fired
                onSwipe?(fc, direction)
            }

        case .fired:
            break
        }
    }

    private func makePositionMap(_ touches: [MTTouch]) -> [Int32: CGPoint] {
        var map: [Int32: CGPoint] = [:]
        for t in touches {
            map[t.identifier] = CGPoint(
                x: CGFloat(t.normalized.position.x),
                y: CGFloat(t.normalized.position.y)
            )
        }
        return map
    }

    // MARK: - Pressure (Force Click)

    private func startPressureMonitor() {
        // NSEvent.addGlobalMonitorForEvents のハンドラはメインスレッドで呼ばれる。
        pressureMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.pressure]) { [weak self] event in
            self?.handlePressure(event: event)
        }
    }

    private func stopPressureMonitor() {
        if let monitor = pressureMonitor {
            NSEvent.removeMonitor(monitor)
            pressureMonitor = nil
        }
    }

    private func handlePressure(event: NSEvent) {
        guard event.stage == 2 else { return }
        let count = currentFingerCount
        guard count == 3 || count == 4 else { return }
        if case .fired = state { return }
        guard let fc = Trigger.FingerCount(rawValue: count) else { return }
        state = .fired
        onForceClick?(fc)
    }
}

// MARK: - C callback bridge

// canonical シグネチャに合わせて第1引数を Int32 に変更。
private func multitouchFrameCallback(
    deviceID: Int32,
    touches: UnsafeMutablePointer<MTTouch>?,
    numTouches: Int32,
    timestamp: Double,
    frame: Int32
) -> Int32 {
    guard let touches else { return 0 }
    let count = Int(numTouches)
    var array: [MTTouch] = []
    array.reserveCapacity(count)
    for i in 0..<count {
        array.append(touches[i])
    }
    DispatchQueue.main.async {
        GestureMonitor.shared?.handleFrame(touches: array)
    }
    return 0
}
