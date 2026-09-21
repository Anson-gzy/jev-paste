import Foundation
import AppKit

/// 检查更新状态
public enum UpdateStatus: Equatable, Sendable {
    case idle
    case checking
    case upToDate
    case updateAvailable(version: String, url: URL)
    case failed(String)
}

/// 负责检测 GitHub 仓库更新的后台服务
@MainActor
public final class UpdateChecker: ObservableObject {
    public static let shared = UpdateChecker()
    
    public static let currentVersion = "1.0.0"
    public static let repoURL = URL(string: "https://github.com/Anson-gzy/jev-paste")!
    public static let releasesURL = URL(string: "https://github.com/Anson-gzy/jev-paste/releases")!
    
    @Published public private(set) var status: UpdateStatus = .idle
    @Published public private(set) var lastCheckedTime: Date?
    
    private init() {}
    
    /// 触发检查更新
    public func checkForUpdates() {
        guard status != .checking else { return }
        self.status = .checking
        
        Task {
            do {
                // 1. 尝试从 GitHub Releases 检查最新 tag
                let releaseApi = URL(string: "https://api.github.com/repos/Anson-gzy/jev-paste/releases/latest")!
                var req = URLRequest(url: releaseApi)
                req.timeoutInterval = 6.0
                req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
                req.setValue("jev-paste-mac-app", forHTTPHeaderField: "User-Agent")
                
                let (data, response) = try await URLSession.shared.data(for: req)
                if let httpResp = response as? HTTPURLResponse {
                    if httpResp.statusCode == 200 {
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let tagName = json["tag_name"] as? String {
                            let cleanTag = tagName.replacingOccurrences(of: "^v", with: "", options: .regularExpression)
                            let htmlUrlStr = (json["html_url"] as? String) ?? Self.releasesURL.absoluteString
                            let releaseUrl = URL(string: htmlUrlStr) ?? Self.releasesURL
                            
                            await MainActor.run {
                                self.lastCheckedTime = Date()
                                if cleanTag.compare(Self.currentVersion, options: .numeric) == .orderedDescending {
                                    self.status = .updateAvailable(version: tagName, url: releaseUrl)
                                } else {
                                    self.status = .upToDate
                                }
                            }
                            return
                        }
                    } else if httpResp.statusCode == 404 {
                        // 2. 如果 releases 尚未发布，通过 commits api 检查是否有新的提交记录
                        try await checkLatestCommits()
                        return
                    }
                }
                
                await MainActor.run {
                    self.lastCheckedTime = Date()
                    self.status = .upToDate
                }
            } catch {
                await MainActor.run {
                    self.lastCheckedTime = Date()
                    // 网络波动或离线时不阻碍用户，标记为 upToDate 或保留状态
                    self.status = .upToDate
                }
            }
        }
    }
    
    private func checkLatestCommits() async throws {
        let commitApi = URL(string: "https://api.github.com/repos/Anson-gzy/jev-paste/commits?per_page=1")!
        var req = URLRequest(url: commitApi)
        req.timeoutInterval = 6.0
        req.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        req.setValue("jev-paste-mac-app", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: req)
        if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
            if let jsonList = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let latest = jsonList.first,
               let commitObj = latest["commit"] as? [String: Any],
               let committer = commitObj["committer"] as? [String: Any],
               let dateStr = committer["date"] as? String {
                // 如果发现有较新的提交
                let isoFormatter = ISO8601DateFormatter()
                if let commitDate = isoFormatter.date(from: dateStr),
                   commitDate > Date().addingTimeInterval(-86400 * 3) {
                    await MainActor.run {
                        self.lastCheckedTime = Date()
                        self.status = .updateAvailable(version: "Latest", url: Self.repoURL)
                    }
                    return
                }
            }
        }
        await MainActor.run {
            self.lastCheckedTime = Date()
            self.status = .upToDate
        }
    }
    
    /// 打开更新网页
    public func openUpdateURL(_ url: URL? = nil) {
        let target = url ?? Self.repoURL
        NSWorkspace.shared.open(target)
    }
}
