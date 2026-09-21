import AppKit
import SwiftUI

/// 管理主窗口生命周期的控制器
@MainActor
public final class MainWindowController: NSObject, NSWindowDelegate {
    public static let shared = MainWindowController()
    
    private var window: NSWindow?
    
    private override init() {
        super.init()
    }
    
    /// 显示主窗口
    public func showWindow() {
        if window == nil {
            setupWindow()
        }
        
        guard let w = window else { return }
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    /// 隐藏主窗口
    public func hideWindow() {
        window?.orderOut(nil)
    }
    
    /// 切换主窗口可见性
    public func toggleWindow() {
        if let w = window, w.isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }
    
    private func setupWindow() {
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 850, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Smart Paste Console"
        w.minSize = NSSize(width: 720, height: 460)
        w.center()
        w.isReleasedWhenClosed = false
        w.titlebarAppearsTransparent = true
        w.delegate = self
        
        let hostingView = NSHostingView(rootView: MainWindowView())
        w.contentView = hostingView
        
        self.window = w
    }
    
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 关闭窗口时不退出应用，转入后台静默常驻
        sender.orderOut(nil)
        return false
    }
}
