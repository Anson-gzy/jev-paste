import AppKit
import SwiftUI

/// 管理浮动 HUD 窗口的控制器
@MainActor
public final class HUDWindowController: NSObject, NSWindowDelegate {
    public static let shared = HUDWindowController()
    
    private var panel: NSPanel?
    private var settingsWindow: NSWindow?
    private let viewModel = HUDViewModel()
    private var targetApplication: NSRunningApplication?
    
    private override init() {
        super.init()
    }
    
    /// 切换显示/隐藏 HUD
    public func toggle() {
        if let p = panel, p.isVisible {
            hide()
        } else {
            show()
        }
    }
    
    /// 显示 HUD 面板
    public func show() {
        // 记录唤起前的活动应用程序
        let frontApp = NSWorkspace.shared.frontmostApplication
        if frontApp?.bundleIdentifier != Bundle.main.bundleIdentifier {
            self.targetApplication = frontApp
        }
        
        let text = ClipboardMonitor.shared.readCurrent() ?? ""
        viewModel.loadAndAnalyze(text: text, targetApp: targetApplication)
        
        if panel == nil {
            setupPanel()
        }
        
        guard let p = panel else { return }
        
        // 居中靠上展示（Spotlight 风格）
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.origin.x + (screenRect.width - p.frame.width) / 2
            let y = screenRect.origin.y + (screenRect.height - p.frame.height) * 0.65
            p.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// 隐藏 HUD 面板
    public func hide() {
        panel?.orderOut(nil)
    }
    
    /// 打开独立设置窗口
    public func openSettings() {
        hide()
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Smart Paste Settings"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView())
            self.settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func setupPanel() {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 360),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.isMovableByWindowBackground = true
        p.delegate = self
        
        let hudView = SmartPasteHUDView(
            viewModel: viewModel,
            onClose: { [weak self] in
                self?.hide()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            }
        )
        
        let hostingView = NSHostingView(rootView: hudView)
        p.contentView = hostingView
        
        self.panel = p
    }
    
    public func windowDidResignKey(_ notification: Notification) {
        // 如果失焦，自动隐藏
        hide()
    }
}
