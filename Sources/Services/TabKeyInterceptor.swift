import AppKit
import Carbon

/// 监听系统 Tab 键并实现一键填入 Ghost 候选，不影响系统 Command+V
public final class TabKeyInterceptor {
    public static let shared = TabKeyInterceptor()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    private init() {}
    
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
                if type.rawValue == 0xFFFFFFFE /* kCGEventTapDisabledByTimeout */ {
                    if let tap = TabKeyInterceptor.shared.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passRetained(event)
                }
                
                if type == .keyDown {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    let flags = event.flags
                    
                    // 检查是否是单独按下 Tab 键 (keyCode 48 = 0x30)
                    let isTab = (keyCode == 48)
                    let noModifiers = flags.intersection([.maskCommand, .maskAlternate, .maskControl]).isEmpty
                    
                    if isTab && noModifiers {
                        var handled = false
                        let checkAndPaste = {
                            MainActor.assumeIsolated {
                                var targetSuggestion: String? = nil
                                
                                if GhostOverlayController.shared.isShowing,
                                   let suggestion = GhostOverlayController.shared.currentSuggestion {
                                    targetSuggestion = suggestion
                                } else {
                                    if AXFocusMonitor.shared.currentFocusedInput == nil {
                                        AXFocusMonitor.shared.checkFocusedElement()
                                    }
                                    if let currentFocus = AXFocusMonitor.shared.currentFocusedInput {
                                        // 容错兜底：即使 GhostOverlay 未显式激活，只要处于输入框且有预测建议，Tab 键依然执行填入！
                                        targetSuggestion = SmartPasteCoordinator.shared.quickSuggestion(for: currentFocus)
                                    }
                                }
                                NSLog("[TabKeyInterceptor] Tab pressed, targetSuggestion: %@", targetSuggestion ?? "nil")
                                if let suggestion = targetSuggestion {
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
                    } else if !flags.contains(.maskCommand) {
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
                return Unmanaged.passRetained(event)
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
