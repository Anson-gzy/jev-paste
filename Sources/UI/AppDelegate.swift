import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. 设置菜单栏图标
        setupStatusItem()
        
        // 2. 检查辅助功能权限：若尚未授予，主动触发 macOS 官方系统级授权提醒，并自动将应用加入系统列表
        if !AXFocusMonitor.shared.checkAccessibilityPermission() {
            AXFocusMonitor.shared.requestAccessibilityPermission()
        }
        
        // 3. 注册全局热键 Option + V：对当前光标输入框主动触发一次半透明候选推断
        GlobalHotkeyManager.shared.onHotKeyTriggered = {
            if let current = AXFocusMonitor.shared.currentFocusedInput {
                SmartPasteCoordinator.shared.triggerPredict(for: current)
            } else {
                AXFocusMonitor.shared.checkFocusedElement()
            }
        }
        GlobalHotkeyManager.shared.registerDefaultHotkey()
        
        // 4. 启动智能剪贴板与焦点监控联动
        SmartPasteCoordinator.shared.start()
        
        // 4. 显示图形化主控制台
        MainWindowController.shared.showWindow()
        
        NSLog("[SmartPaste] App launched successfully. GUI Console opened.")
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        GlobalHotkeyManager.shared.unregisterHotkey()
        ClipboardMonitor.shared.stop()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        // 使用 SF Symbols 作为菜单栏图标
        if let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Smart Paste") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "SP"
        }
        
        let menu = NSMenu()
        
        let openConsoleItem = NSMenuItem(title: L("menu.open"), action: #selector(openConsole), keyEquivalent: "o")
        openConsoleItem.keyEquivalentModifierMask = [.command]
        openConsoleItem.target = self
        menu.addItem(openConsoleItem)
        
        let statusNotice = NSMenuItem(title: "Mode: Inline Tab paste active", action: nil, keyEquivalent: "")
        statusNotice.isEnabled = false
        menu.addItem(statusNotice)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: L("menu.settings"), action: #selector(openPreferences), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: L("menu.quit"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func openConsole() {
        MainWindowController.shared.showWindow()
    }
    
    @objc private func openPreferences() {
        HUDWindowController.shared.openSettings()
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
