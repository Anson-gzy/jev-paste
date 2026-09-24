import AppKit
import Carbon

/// 监听系统 Tab 键并实现一键填入 Ghost 候选，不影响系统 Command+V
public final class TabKeyInterceptor {
    public static let shared = TabKeyInterceptor()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    private init() {}
    
    /// 判断是否应该拦截按键：仅在幽灵候选处于展示中、按下 Tab 键且未按下 Shift/Cmd/Alt/Ctrl 时拦截
    public static func shouldIntercept<T: BinaryInteger>(keyCode: T, flags: CGEventFlags, ghostShowing: Bool) -> Bool {
        guard ghostShowing, keyCode == 48 else { return false }
        let disallowed: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        return flags.intersection(disallowed).isEmpty
    }
    
    /// 开启全局按键监听
    public func start() {
        guard eventTap == nil else { return }
        
        let mask = (1 << CGEventType.keyDown.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { (_, type, event, _) -> Unmanaged<CGEvent>? in
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = TabKeyInterceptor.shared.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passUnretained(event)
                }
                
                if type == .keyDown {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    let flags = event.flags
                    
                    var isShowing = false
                    if Thread.isMainThread {
                        isShowing = MainActor.assumeIsolated { GhostOverlayController.shared.isShowing }
                    } else {
                        isShowing = DispatchQueue.main.sync { MainActor.assumeIsolated { GhostOverlayController.shared.isShowing } }
                    }
                    
                    if TabKeyInterceptor.shouldIntercept(keyCode: keyCode, flags: flags, ghostShowing: isShowing) {
                        var handled = false
                        let checkAndPaste = {
                            MainActor.assumeIsolated {
                                if let suggestion = GhostOverlayController.shared.currentSuggestion {
                                    GhostOverlayController.shared.hide()
                                    let frontName = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
                                    let isBrowser = ["Safari", "Google Chrome", "Chromium", "Arc", "Brave Browser", "Microsoft Edge", "Firefox"].contains(frontName)
                                    if isBrowser {
                                        PasteSimulator.shared.paste(text: suggestion)
                                    } else {
                                        let success = AXFocusMonitor.shared.insertTextIntoFocusedElement(suggestion)
                                        if !success {
                                            PasteSimulator.shared.paste(text: suggestion)
                                        }
                                    }
                                    handled = true
                                }
                            }
                        }
                        
                        // 避免在主线程上执行 DispatchQueue.main.sync 造成死锁崩溃
                        if Thread.isMainThread {
                            checkAndPaste()
                        } else {
                            DispatchQueue.main.sync {
                                checkAndPaste()
                            }
                        }
                        
                        if handled {
                            // 拦截本次 Tab，不让输入框跳转或插入制表符
                            return nil
                        }
                    } else if isShowing && !flags.contains(.maskCommand) {
                        // 用户输入了普通字符、退格、空格或按了 Esc，立即彻底隐藏，绝不遮挡用户打字
                        let dismissGhost = {
                            MainActor.assumeIsolated {
                                GhostOverlayController.shared.hide()
                            }
                        }
                        if Thread.isMainThread {
                            dismissGhost()
                        } else {
                            DispatchQueue.main.async {
                                dismissGhost()
                            }
                        }
                    }
                    // 系统的 Command+V 或其他任何按键完全放行，不受任何影响
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: nil
        ) else {
            NSLog("[TabKeyInterceptor] Failed to create CGEventTap (requires Accessibility permission)")
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    public func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
                runLoopSource = nil
            }
            eventTap = nil
        }
    }
}
