import AppKit
import Carbon

/// 负责将选定字段内容模拟注入到前台活跃应用
public final class PasteSimulator {
    public static let shared = PasteSimulator()
    public static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    
    private init() {}
    
    public func snapshotPasteboard(from pasteboard: NSPasteboard = .general) -> [[(NSPasteboard.PasteboardType, Data)]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        }
    }
    
    public func restorePasteboard(_ snapshot: [[(NSPasteboard.PasteboardType, Data)]], to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        let restored = snapshot.compactMap { entries -> NSPasteboardItem? in
            guard !entries.isEmpty else { return nil }
            let item = NSPasteboardItem()
            entries.forEach { item.setData($0.1, forType: $0.0) }
            return item
        }
        if !restored.isEmpty { pasteboard.writeObjects(restored) }
    }
    
    /// 将文本写入剪贴板并附加 TransientType 标记
    public func writeTransientText(_ text: String, to pasteboard: NSPasteboard = .general) {
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        item.setData(Data(), forType: Self.transientType)
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }
    
    /// 将内容写入系统剪贴板并模拟 ⌘A 全选 + ⌘V 粘贴到目标前台应用，彻底覆盖替换原有旧字
    public func paste(text: String, to targetApp: NSRunningApplication? = nil, replaceExisting: Bool = true, restoreClipboardAfterMs: Int? = 80, pasteboard: NSPasteboard = .general) {
        let snapshot = snapshotPasteboard(from: pasteboard)
        
        Task { @MainActor in
            SmartPasteCoordinator.shared.isSimulatingPaste = true
        }
        
        // 1. 设置新内容并标记为 TransientType
        writeTransientText(text, to: pasteboard)
        
        // 2. 激活目标应用
        if let app = targetApp {
            app.activate()
        }
        
        // 3. 稍作微秒级让位确保应用获得输入态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            if replaceExisting {
                // 先执行 ⌘A 全选目标输入框的原本旧字，以便彻底覆盖替换
                self.sendCmdA()
                
                // 稍作延迟等待全选生效后再发送 ⌘V 粘贴
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    self.sendCmdV()
                }
            } else {
                self.sendCmdV()
            }
            
            // 4. 延迟快速恢复原来的剪贴板完整内容
            if let restoreMs = restoreClipboardAfterMs {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(restoreMs) / 1000.0) {
                    if pasteboard.string(forType: .string) == text {
                        self.restorePasteboard(snapshot, to: pasteboard)
                    }
                    Task { @MainActor in
                        SmartPasteCoordinator.shared.isSimulatingPaste = false
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    Task { @MainActor in
                        SmartPasteCoordinator.shared.isSimulatingPaste = false
                    }
                }
            }
        }
    }
    
    /// 连续分步粘贴：将多个字段依次填入，字段间发送 Tab 键跳转下一个表单输入框
    public func pasteSequence(fields: [String], to targetApp: NSRunningApplication? = nil) {
        guard !fields.isEmpty else { return }
        
        if let app = targetApp {
            app.activate()
        }
        
        var delay = 0.2
        for (index, fieldText) in fields.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.writeTransientText(fieldText, to: .general)
                self.sendCmdV()
            }
            delay += 0.25
            
            // 如果不是最后一个字段，发送 Tab 键跳到下一个输入框
            if index < fields.count - 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.sendTab()
                }
                delay += 0.15
            }
        }
    }
    
    /// 模拟按键：Command + A（全选现有文字以便覆盖替换）
    private func sendCmdA() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let aKeyCode: CGKeyCode = 0x00 // 'a'
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: aKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: aKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    /// 模拟按键：Command + V
    private func sendCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 0x09 // 'v'
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
    
    /// 模拟按键：Tab
    private func sendTab() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let tabKeyCode: CGKeyCode = 0x30 // Tab
        
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: tabKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: tabKeyCode, keyDown: false)
        
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
