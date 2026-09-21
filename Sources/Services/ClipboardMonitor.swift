import AppKit
import Combine

/// 剪贴板监听器：检测系统剪贴板变化并保护敏感内容
public final class ClipboardMonitor: ObservableObject {
    public static let shared = ClipboardMonitor()
    
    @Published public private(set) var latestText: String = ""
    @Published public private(set) var lastChangeTime: Date = Date()
    
    private var lastChangeCount: Int = -1
    private var timer: Timer?
    private let pasteboard = NSPasteboard.general
    
    public var onClipboardChanged: ((String) -> Void)?
    
    private init() {
        self.lastChangeCount = pasteboard.changeCount
    }
    
    /// 启动监听循环
    public func start() {
        guard timer == nil else { return }
        checkClipboard()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    /// 停止监听
    public func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    /// 手动读取当前剪贴板
    @discardableResult
    public func readCurrent() -> String? {
        guard let string = pasteboard.string(forType: .string) else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed.count <= 12000 {
            // 排除用户存储的 API Key
            if let apiKey = KeychainHelper.shared.getApiKey(), !apiKey.isEmpty && trimmed.contains(apiKey) {
                return nil
            }
            return trimmed
        }
        return nil
    }
    
    private func checkClipboard() {
        let currentCount = pasteboard.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount
        
        guard let text = readCurrent(), text != latestText else { return }
        self.latestText = text
        self.lastChangeTime = Date()
        
        // 自动录入历史剪贴板池
        Task { @MainActor in
            ClipboardHistoryManager.shared.addText(text)
        }
        
        self.onClipboardChanged?(text)
    }
}
