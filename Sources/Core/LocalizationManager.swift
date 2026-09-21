import Foundation
import SwiftUI

/// 支持的界面显示语言
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case en = "en"
    case zhHans = "zh-Hans"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .en:
            return "English"
        case .zhHans:
            return "简体中文"
        }
    }
}

/// 集中管理应用多语言本地化（主语言为英语，支持中英即时切换）
@MainActor
public final class LocalizationManager: ObservableObject {
    public static let shared = LocalizationManager()
    
    private let storageKey = "app_preferred_language"
    
    @Published public var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: storageKey)
        }
    }
    
    private init() {
        if let saved = UserDefaults.standard.string(forKey: storageKey),
           let lang = AppLanguage(rawValue: saved) {
            self.currentLanguage = lang
        } else {
            // 默认主语言为英语
            self.currentLanguage = .en
        }
    }
    
    public func setLanguage(_ lang: AppLanguage) {
        self.currentLanguage = lang
    }
    
    /// 获取对应当前语言的本地化文本
    public func t(_ key: String) -> String {
        let table = (currentLanguage == .zhHans) ? stringsZhHans : stringsEn
        return table[key] ?? stringsEn[key] ?? key
    }
    
    // MARK: - 英文词表 (Primary)
    private let stringsEn: [String: String] = [
        // Navigation & Titles
        "nav.dashboard": "Dashboard",
        "nav.playground": "Web Demo",
        "nav.settings": "Settings",
        
        // Dashboard
        "dash.title": "Jev Paste Monitor",
        "dash.subtitle": "Decomposes clipboard content with JEF and provides inline ghost text on Tab.",
        "dash.status.running": "Service Active",
        "dash.status.paused": "Service Paused",
        "dash.status.activeDesc": "Listening for focused text inputs. Press Tab to paste ghost suggestions.",
        "dash.status.pausedDesc": "Service is paused. Tab interception and ghost overlays are disabled.",
        "dash.btn.pause": "Pause Service",
        "dash.btn.resume": "Resume Service",
        "dash.perm.title": "Accessibility Status",
        "dash.perm.granted": "Granted",
        "dash.perm.missing": "Action Required",
        "dash.perm.desc": "Required to detect input fields and write inline suggestions.",
        "dash.perm.btn": "Open System Settings",
        "dash.clip.title": "Live Clipboard Preview",
        "dash.clip.empty": "Clipboard is currently empty.",
        "dash.clip.spans": "Identified Spans",
        "dash.clip.cached": "Cached in Memory (0ms Ready)",
        "dash.stat.spansCount": "Spans Extracted",
        "dash.stat.charsCaptured": "Chars In Memory",
        "dash.stat.tabAccepted": "Tab Accepted",
        
        // Web Demo
        "play.title": "Schedule Q&A Web Demo",
        "play.subtitle": "Test intelligent entity extraction and Tab-paste in a real browser environment.",
        "play.sample.title": "Demo Workbench",
        "play.sample.copyBtn": "Open Demo in Browser",
        "play.sample.copied": "Opened in Default Browser",
        
        // Settings
        "set.title": "Preferences",
        "set.lang.section": "Language",
        "set.lang.desc": "Select the application display language. English is primary.",
        "set.history.section": "Clipboard History & Time-Decay",
        "set.history.desc": "Reads all clipboard items to offer context-aware suggestions, ranked by recency.",
        "set.history.retentionLabel": "History Retention Period",
        "set.history.1hour": "1 Hour",
        "set.history.12hours": "12 Hours",
        "set.history.1day": "1 Day (Default)",
        "set.history.3days": "3 Days",
        "set.history.7days": "7 Days",
        "set.history.30days": "30 Days",
        "set.history.forever": "Keep Forever",
        "set.history.itemsCount": "items in memory",
        "set.history.clearBtn": "Clear History",
        "set.history.cleared": "History Cleared",
        "set.api.section": "TypeSafe JEF API",
        "set.api.keyLabel": "API Key",
        "set.api.keyPh": "Enter TypeSafe API Key...",
        "set.api.hint": "Securely saved in macOS Keychain. Never stored in plain text.",
        "set.api.testBtn": "Test Connection",
        "set.api.testing": "Testing...",
        "set.api.saveBtn": "Save Key",
        "set.api.saved": "Key Saved",
        "set.api.success": "Connection Valid (HTTP 200)",
        "set.api.failed": "Connection Failed",
        "set.gen.section": "General",
        "set.gen.launchAtLogin": "Launch Jev Paste at login",
        "set.gen.menuBarStay": "Keep running in menu bar when window is closed",
        "set.engine.section": "Engine Calibration",
        "set.engine.jefAi": "Enable JEF AI cloud calibration (Dual Engine)",
        "set.engine.jefAiDesc": "Uses local heuristics by default (<0.5ms) and calibrates with JEF in background.",
        "set.keys.title": "Key Actions & Integration",
        "set.keys.tab": "Paste ghost hint into focused field (replaces existing text completely)",
        "set.keys.type": "Dismiss ghost hint instantly and type normally",
        "set.keys.cmdv": "Native system paste (100% untouched)",
        "set.keys.optv": "Re-trigger JEF recognition for the current focused input",
        
        // Menu Bar & App
        "menu.open": "Open Dashboard",
        "menu.settings": "Preferences...",
        "menu.quit": "Quit Jev Paste"
    ]
    
    // MARK: - 简体中文词表
    private let stringsZhHans: [String: String] = [
        // Navigation & Titles
        "nav.dashboard": "控制面板",
        "nav.playground": "演示 Demo",
        "nav.settings": "偏好设置",
        
        // Dashboard
        "dash.title": "Jev Paste 运行看板",
        "dash.subtitle": "通过 JEF 自动识别与拆分剪贴板内容，输入框浅色提示，按 Tab 键即可填入。",
        "dash.status.running": "服务运行中",
        "dash.status.paused": "服务已暂停",
        "dash.status.activeDesc": "正在监听输入框焦点。检测到匹配内容时将以内联半透明呈现，按 Tab 键填入。",
        "dash.status.pausedDesc": "服务已挂起，已停止按键拦截与悬浮提示。",
        "dash.btn.pause": "暂停服务",
        "dash.btn.resume": "恢复服务",
        "dash.perm.title": "辅助功能权限",
        "dash.perm.granted": "已授权",
        "dash.perm.missing": "待授权",
        "dash.perm.desc": "用于感知输入框位置以及通过 Tab 键进行内联填入。",
        "dash.perm.btn": "前往系统设置授权",
        "dash.clip.title": "系统剪贴板实时预览",
        "dash.clip.empty": "剪贴板当前为空",
        "dash.clip.spans": "已拆分字段候选",
        "dash.clip.cached": "内存已预计算（0ms 就绪）",
        "dash.stat.spansCount": "已拆分候选数",
        "dash.stat.charsCaptured": "内存缓存字符",
        "dash.stat.tabAccepted": "Tab 粘贴采纳数",
        
        // Web Demo
        "play.title": "Schedule Q&A 演示工作台",
        "play.subtitle": "在真实浏览器环境中测试长文本日程实体提取与 Tab 快速粘贴。",
        "play.sample.title": "演示工作台",
        "play.sample.copyBtn": "在浏览器中打开演示网页",
        "play.sample.copied": "已在默认浏览器中打开",
        
        // Settings
        "set.title": "偏好设置",
        "set.lang.section": "界面语言",
        "set.lang.desc": "选择应用程序的显示语言，主语言为英语，切换即时生效。",
        "set.history.section": "历史剪贴板与时间加权",
        "set.history.desc": "读取所有历史剪贴板记录提供候选建议，越新复制的内容权重越高。",
        "set.history.retentionLabel": "历史剪贴板保留时长",
        "set.history.1hour": "1 小时",
        "set.history.12hours": "12 小时",
        "set.history.1day": "1 天 (默认)",
        "set.history.3days": "3 天",
        "set.history.7days": "7 天",
        "set.history.30days": "30 天",
        "set.history.forever": "永久保留",
        "set.history.itemsCount": "条记录在内存中",
        "set.history.clearBtn": "清空历史",
        "set.history.cleared": "历史记录已清空",
        "set.api.section": "TypeSafe JEF API",
        "set.api.keyLabel": "API 密钥",
        "set.api.keyPh": "输入 TypeSafe API Key...",
        "set.api.hint": "安全保存在 macOS 系统钥匙串中，绝不明文落盘。",
        "set.api.testBtn": "测试网络连通性",
        "set.api.testing": "正在测试...",
        "set.api.saveBtn": "保存密钥",
        "set.api.saved": "密钥已保存",
        "set.api.success": "连接成功 (HTTP 200)",
        "set.api.failed": "连接失败",
        "set.gen.section": "通用设置",
        "set.gen.launchAtLogin": "开机自动启动 Jev Paste",
        "set.gen.menuBarStay": "关闭主窗口后保持在菜单栏常驻运行",
        "set.engine.section": "引擎调校",
        "set.engine.jefAi": "启用 JEF AI 云端校准（双引擎模式）",
        "set.engine.jefAiDesc": "本地启发式引擎即时响应（<0.5ms），JEF AI 在后台并发精细微调。",
        "set.keys.title": "按键行为与集成说明",
        "set.keys.tab": "将浅色提示内容粘贴填入，并彻底清空覆盖框内原有文字",
        "set.keys.type": "立即隐藏浅色提示，不影响正常手动打字",
        "set.keys.cmdv": "系统原生粘贴，完全放行，不受任何干扰",
        "set.keys.optv": "主动对当前获得焦点的输入框重新触发一次 JEF 浅色提示",
        
        // Menu Bar & App
        "menu.open": "打开控制台",
        "menu.settings": "偏好设置...",
        "menu.quit": "退出 Jev Paste"
    ]
}

/// 便捷全局翻译函数
@MainActor
public func L(_ key: String) -> String {
    LocalizationManager.shared.t(key)
}
