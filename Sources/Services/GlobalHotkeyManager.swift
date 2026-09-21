import AppKit
import Carbon

/// 系统全局快捷键管理器（使用原生 Carbon EventHotKey 实现免权限超快响应）
public final class GlobalHotkeyManager {
    public static let shared = GlobalHotkeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    public var onHotKeyTriggered: (() -> Void)?
    
    private init() {
        installEventHandler()
    }
    
    /// 注册默认热键：Option + V (kVK_ANSI_V = 0x09, optionKey = 0x0800)
    public func registerDefaultHotkey(keyCode: UInt32 = 0x09, modifiers: UInt32 = UInt32(optionKey)) {
        unregisterHotkey()
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x534D5254) // 'SMRT'
        hotKeyID.id = 1
        
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        
        if status != noErr {
            NSLog("[GlobalHotkeyManager] Failed to register hotkey with status: %d", status)
        }
    }
    
    public func unregisterHotkey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
    
    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, event, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if status == noErr && hotKeyID.signature == OSType(0x534D5254) {
                    DispatchQueue.main.async {
                        GlobalHotkeyManager.shared.onHotKeyTriggered?()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
    }
}
