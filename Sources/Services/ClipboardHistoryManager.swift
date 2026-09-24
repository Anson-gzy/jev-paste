import Foundation
import Combine

/// 剪贴板全量历史管理器：持久化记录、自动过期淘汰与时间衰减权重计算
@MainActor
public final class ClipboardHistoryManager: ObservableObject {
    public static let shared = ClipboardHistoryManager()
    
    private let storageKeyRetention = "jev_history_retention_period"
    private let maxHistoryCount = 500
    
    @Published public private(set) var historyItems: [ClipboardHistoryItem] = []
    
    @Published public var retentionPeriod: HistoryRetentionPeriod {
        didSet {
            UserDefaults.standard.set(retentionPeriod.rawValue, forKey: storageKeyRetention)
            pruneExpiredItems()
            saveToDisk()
        }
    }
    
    private let fileManager = FileManager.default
    private var historyFileURL: URL {
        let dir: URL
        if let customDir = ProcessInfo.processInfo.environment["JEV_PASTE_DATA_DIR"], !customDir.isEmpty {
            dir = URL(fileURLWithPath: customDir, isDirectory: true)
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            dir = appSupport.appendingPathComponent("ai.typesafe.jev-paste", isDirectory: true)
        }
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("clipboard_history.json")
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: storageKeyRetention),
           let period = HistoryRetentionPeriod(rawValue: saved) {
            self.retentionPeriod = period
        } else {
            // 默认历史剪贴板保留期为 1 天
            self.retentionPeriod = .day1
        }
        
        loadFromDisk()
        pruneExpiredItems()
    }
    
    /// 新增或刷新剪贴板记录
    @discardableResult
    public func addText(_ text: String, timestamp: Date = Date()) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && trimmed.count <= 25000 else { return false }
        
        // 排除用户存储的敏感 API Key
        if let apiKey = KeychainHelper.shared.getApiKey(), !apiKey.isEmpty && trimmed.contains(apiKey) {
            return false
        }
        
        // 查重：若已存在相同内容，更新时间戳并置顶
        if let existingIdx = historyItems.firstIndex(where: { $0.text == trimmed }) {
            var item = historyItems.remove(at: existingIdx)
            item.timestamp = timestamp
            historyItems.insert(item, at: 0)
        } else {
            let newItem = ClipboardHistoryItem(text: trimmed, timestamp: timestamp)
            historyItems.insert(newItem, at: 0)
        }
        
        pruneExpiredItems()
        
        if historyItems.count > maxHistoryCount {
            historyItems = Array(historyItems.prefix(maxHistoryCount))
        }
        
        saveToDisk()
        return true
    }
    
    /// 清理已超期的历史记录
    public func pruneExpiredItems(referenceDate: Date = Date()) {
        guard let maxAge = retentionPeriod.expirationSeconds else { return }
        let cutoff = referenceDate.addingTimeInterval(-maxAge)
        let beforeCount = historyItems.count
        historyItems.removeAll { $0.timestamp < cutoff }
        if historyItems.count != beforeCount {
            saveToDisk()
        }
    }
    
    /// 清空所有历史剪贴板
    public func clearHistory() {
        historyItems.removeAll()
        saveToDisk()
    }
    
    /// 计算指定时间戳条目的时间衰减因子 (半衰期指数模型，6 小时半衰期，返回 0.05 ~ 1.0)
    public func computeTimeWeight(for timestamp: Date, referenceDate: Date = Date()) -> Double {
        let delta = max(0, referenceDate.timeIntervalSince(timestamp))
        let halfLife: Double = 6.0 * 3600.0 // 6 小时半衰期
        let decay = exp(-log(2.0) * (delta / halfLife))
        return max(0.05, min(1.0, decay))
    }
    
    // MARK: - 磁盘持久化
    private func saveToDisk() {
        let items = self.historyItems
        let url = self.historyFileURL
        DispatchQueue.global(qos: .utility).async {
            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(items)
                try data.write(to: url, options: .atomic)
            } catch {
                NSLog("[ClipboardHistoryManager] Failed to save history: %@", error.localizedDescription)
            }
        }
    }
    
    private func loadFromDisk() {
        let url = self.historyFileURL
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode([ClipboardHistoryItem].self, from: data)
            self.historyItems = loaded
        } catch {
            NSLog("[ClipboardHistoryManager] Failed to load history: %@", error.localizedDescription)
        }
    }
}
