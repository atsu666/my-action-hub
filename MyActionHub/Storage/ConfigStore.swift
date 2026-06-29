import Foundation
import Combine
import os.log

/// `~/Library/Application Support/MyActionHub/config.json` の読み書きと
/// アプリ内設定の状態保持を担う。
///
/// - 起動時: ファイルがなければデフォルト、あれば読み込み、パース失敗時はバックアップを取ってデフォルト
/// - 書き込み: `config` への変更を検知して 200ms debounce で書き込み
/// - スレッド: `@MainActor` で全アクセスを直列化
@MainActor
final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    @Published var config: AppConfig

    private let log = Logger(subsystem: "com.appleple.myactionhub", category: "ConfigStore")
    private let fileURL: URL
    private var saveTask: Task<Void, Never>?
    private var subscriptions = Set<AnyCancellable>()

    private init() {
        self.fileURL = ConfigStore.makeConfigFileURL()
        self.config = ConfigStore.loadInitial(from: fileURL)
        startAutoSave()
    }

    // MARK: - Public API

    /// 設定をディスクへ即時保存(テストや終了時用)。通常は自動保存に任せて良い。
    func saveNow() {
        do {
            try writeToDisk(config)
        } catch {
            log.error("即時保存に失敗: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - File location

    private static func makeConfigFileURL() -> URL {
        let fm = FileManager.default
        let support = try! fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = support.appendingPathComponent("MyActionHub", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("config.json")
    }

    // MARK: - Initial load

    private static func loadInitial(from url: URL) -> AppConfig {
        let log = Logger(subsystem: "com.appleple.myactionhub", category: "ConfigStore")

        guard FileManager.default.fileExists(atPath: url.path) else {
            log.info("config.json が存在しないためデフォルトで初期化")
            return .default
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let config = try decoder.decode(AppConfig.self, from: data)
            return config
        } catch {
            log.error("config.json のパースに失敗: \(String(describing: error), privacy: .public)")
            backupBrokenFile(at: url)
            return .default
        }
    }

    private static func backupBrokenFile(at url: URL) {
        let log = Logger(subsystem: "com.appleple.myactionhub", category: "ConfigStore")
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent("config.json.broken-\(timestamp)")
        do {
            try FileManager.default.moveItem(at: url, to: backupURL)
            log.info("壊れた config.json を \(backupURL.lastPathComponent, privacy: .public) として退避")
        } catch {
            log.error("バックアップ作成に失敗: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Auto-save

    private func startAutoSave() {
        $config
            .dropFirst() // 初期値は保存不要
            .removeDuplicates(by: { lhs, rhs in
                // Equatable を持たないので JSON で比較(コスト低、頻度も低い)
                guard let l = try? JSONEncoder().encode(lhs),
                      let r = try? JSONEncoder().encode(rhs) else { return false }
                return l == r
            })
            .sink { [weak self] newConfig in
                self?.scheduleSave(newConfig)
            }
            .store(in: &subscriptions)
    }

    private func scheduleSave(_ snapshot: AppConfig) {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
            guard !Task.isCancelled, let self else { return }
            do {
                try self.writeToDisk(snapshot)
                self.log.debug("config.json を保存")
            } catch {
                self.log.error("自動保存に失敗: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func writeToDisk(_ snapshot: AppConfig) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }
}
