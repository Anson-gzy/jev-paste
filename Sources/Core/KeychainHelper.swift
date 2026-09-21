import Foundation

/// 负责安全存储和读取 TypeSafe API Key（零密码弹窗方案）
/// 优先使用用户受保护私有存储 (~/Library/Application Support/SmartPaste/.api_key, 0600 权限) 与环境变量，
/// 彻底规避 macOS 系统未签名应用访问系统钥匙串时强制弹出的登录密码验证窗口。
public final class KeychainHelper {
    public static let shared = KeychainHelper()
    
    private var keyFilePath: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("SmartPaste")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(".api_key")
    }
    
    private init() {}
    
    /// 保存 API Key（写入用户私有受保护文件，权限 0600，绝不触发系统密码提示）
    @discardableResult
    public func saveApiKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        do {
            try trimmed.write(to: keyFilePath, atomically: true, encoding: .utf8)
            // 严格赋予 0600 权限（仅当前用户账户可读可写，系统级文件防护）
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyFilePath.path)
            return true
        } catch {
            NSLog("[KeychainHelper] Failed to save key securely: %@", error.localizedDescription)
            return false
        }
    }
    
    /// 读取 API Key（零密码弹窗，秒级直读）
    public func getApiKey() -> String? {
        // 1. 优先读取用户受保护的本地私有文件
        if let data = try? Data(contentsOf: keyFilePath),
           let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !str.isEmpty {
            return str
        }
        
        // 2. 其次读取系统环境变量
        if let envKey = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"],
           !envKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return envKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    /// 删除已存储的 API Key
    @discardableResult
    public func deleteApiKey() -> Bool {
        if FileManager.default.fileExists(atPath: keyFilePath.path) {
            try? FileManager.default.removeItem(at: keyFilePath)
        }
        return true
    }
}
