import AppKit
import ApplicationServices

/// 描述当前获得焦点的输入框信息
public struct FocusedInputContext: Sendable {
    public let role: String
    public let label: String
    public let placeholder: String
    public let windowTitle: String
    public let screenFrame: NSRect
    public let currentValue: String
    public let surroundingText: String
    
    public init(role: String, label: String, placeholder: String, windowTitle: String, screenFrame: NSRect, currentValue: String, surroundingText: String = "") {
        self.role = role
        self.label = label
        self.placeholder = placeholder
        self.windowTitle = windowTitle
        self.screenFrame = screenFrame
        self.currentValue = currentValue
        self.surroundingText = surroundingText
    }
}

/// 通过 macOS Accessibility API (AXUIElement) 监听全局获得焦点的输入框
@MainActor
public final class AXFocusMonitor: ObservableObject {
    public static let shared = AXFocusMonitor()
    
    @Published public private(set) var currentFocusedInput: FocusedInputContext?
    public var onFocusChanged: ((FocusedInputContext?) -> Void)?
    
    private var timer: Timer?
    private var lastElementHash: Int = 0
    private var isAccessibilityEnabled: Bool = false
    
    private init() {}
    
    /// 检查并请求辅助功能权限
    public func checkAccessibilityPermission(prompt: Bool = false) -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        isAccessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        return isAccessibilityEnabled
    }
    
    /// 主动向系统发起授权请求（弹出 macOS 官方弹窗并自动录入系统设置列表）
    @discardableResult
    public func requestAccessibilityPermission() -> Bool {
        return checkAccessibilityPermission(prompt: true)
    }
    
    /// 开启焦点轮询监听（每 0.2 秒检查一次当前聚焦元素）
    public func start() {
        guard timer == nil else { return }
        checkFocusedElement()
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.checkFocusedElement()
            }
        }
    }
    
    public func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    /// 检查当前获得焦点的 UI 元素
    public func checkFocusedElement() {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedAppValue: AnyObject?
        let appStatus = AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedAppValue)
        
        guard appStatus == .success, let focusedApp = focusedAppValue else {
            notifyFocusChanged(nil)
            return
        }
        
        var focusedElemValue: AnyObject?
        let elemStatus = AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElemValue)
        
        guard elemStatus == .success, let focusedElem = focusedElemValue else {
            notifyFocusChanged(nil)
            return
        }
        
        let element = focusedElem as! AXUIElement
        
        // 检查 Role 是否是可输入框
        var roleValue: AnyObject?
        _ = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        let role = (roleValue as? String) ?? ""
        
        // 1. 严格黑名单：明确拦截所有非文本输入控件（按钮、滑块、复选框、列表、表格、菜单、滑块等）
        let disallowedRoles: Set<String> = [
            "AXWebArea", "AXScrollArea", "AXWindow", "AXApplication", "AXScrollBar",
            "AXButton", "AXPopUpButton", "AXMenuButton", "AXRadioButton", "AXCheckBox",
            "AXSlider", "AXIncrementor", "AXColorWell", "AXProgressIndicator", "AXActivityIndicator",
            "AXTable", "AXOutline", "AXRow", "AXColumn", "AXList", "AXBrowser",
            "AXSplitter", "AXTabGroup", "AXToolbar", "AXMenuBar", "AXMenuItem", "AXMenu",
            "AXImage", "AXHeading", "AXLink", "AXStaticText", "AXDrawer", "AXSheet", "AXHelpTag", "AXLevelIndicator"
        ]
        if disallowedRoles.contains(role) {
            notifyFocusChanged(nil)
            return
        }
        
        // 2. 检查 Subrole：排除密码输入框（安全第一，绝不在密码框显示任何候选或遮罩）
        var subroleVal: AnyObject?
        _ = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleVal)
        let subrole = (subroleVal as? String) ?? ""
        if subrole == "AXSecureTextField" || subrole == "AXPassword" {
            notifyFocusChanged(nil)
            return
        }
        
        // 3. 严格文本输入判定：仅允许 AXTextField、AXTextArea，或者支持选区的 WebKit contenteditable
        let isStandardText = (role == (kAXTextFieldRole as String) || role == (kAXTextAreaRole as String) || role == "AXSearchField")
        
        var isRichEditable = false
        if !isStandardText && (role == "AXGroup" || role == "AXGenericElement") {
            // 对于网页 contenteditable，必须同时满足：kAXValueAttribute 可写 且 支持选区 (kAXSelectedTextRangeAttribute)
            var isSettable: DarwinBoolean = false
            if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &isSettable) == .success, isSettable.boolValue {
                var rangeVal: AnyObject?
                if AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeVal) == .success {
                    isRichEditable = true
                }
            }
        }
        
        guard isStandardText || isRichEditable else {
            notifyFocusChanged(nil)
            return
        }
        
        // 4. 确保控件的 Value 属性是可写的（排除只读文本框）
        var isSettable: DarwinBoolean = false
        if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &isSettable) == .success && !isSettable.boolValue {
            // 如果明确标注为只读不可写，立刻排除
            notifyFocusChanged(nil)
            return
        }
        
        // 获取控件位置与大小
        var posValue: AnyObject?
        var sizeValue: AnyObject?
        _ = AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posValue)
        _ = AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
        
        var point = CGPoint.zero
        var size = CGSize.zero
        if let pv = posValue, CFGetTypeID(pv) == AXValueGetTypeID() {
            AXValueGetValue(pv as! AXValue, .cgPoint, &point)
        }
        if let sv = sizeValue, CFGetTypeID(sv) == AXValueGetTypeID() {
            AXValueGetValue(sv as! AXValue, .cgSize, &size)
        }
        
        // 输入框尺寸合理性保护：过滤掉整屏、微小元素或超大非输入区域（杜绝网页中间白色线 Bug）
        guard size.width >= 30 && size.width <= 1400 && size.height >= 14 && size.height <= 300 else {
            notifyFocusChanged(nil)
            return
        }
        
        // 转换 Carbon 屏幕坐标系 (左上角原点) 到 Cocoa 屏幕坐标系 (左下角原点)
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 1080
        let cocoaRect = NSRect(x: point.x, y: primaryScreenHeight - point.y - size.height, width: size.width, height: size.height)
        
        // 读取元数据（Label, Placeholder, Value, Window Title）
        var labelValue: AnyObject?
        _ = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &labelValue)
        if labelValue == nil {
            _ = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &labelValue)
        }
        
        var detectedLabel = (labelValue as? String) ?? ""
        
        // 深入策略 1：检查是否有官方关联合并的 AXTitleUIElement
        if detectedLabel.isEmpty {
            var titleUIVal: AnyObject?
            if AXUIElementCopyAttributeValue(element, "AXTitleUIElement" as CFString, &titleUIVal) == .success,
               let titleElem = titleUIVal {
                var textVal: AnyObject?
                _ = AXUIElementCopyAttributeValue(titleElem as! AXUIElement, kAXValueAttribute as CFString, &textVal)
                if textVal == nil {
                    _ = AXUIElementCopyAttributeValue(titleElem as! AXUIElement, kAXTitleAttribute as CFString, &textVal)
                }
                if let t = textVal as? String, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    detectedLabel = t
                }
            }
        }
        
        // 深入策略 2：向上探测父容器兄弟组件中最近的 AXStaticText 标签及上下文描述
        var surroundingTexts: [String] = []
        var candidateLabels: [String] = []
        
        var searchElement = element
        for _ in 0..<3 {
            var parentVal: AnyObject?
            if AXUIElementCopyAttributeValue(searchElement, kAXParentAttribute as CFString, &parentVal) == .success,
               let parent = parentVal {
                let parentElem = parent as! AXUIElement
                var parentRoleVal: AnyObject?
                _ = AXUIElementCopyAttributeValue(parentElem, kAXRoleAttribute as CFString, &parentRoleVal)
                let parentRole = (parentRoleVal as? String) ?? ""
                if parentRole == "AXWindow" || parentRole == "AXApplication" {
                    break
                }
                
                var childrenVal: AnyObject?
                if AXUIElementCopyAttributeValue(parentElem, kAXChildrenAttribute as CFString, &childrenVal) == .success,
                   let children = childrenVal as? [AXUIElement] {
                    if let curIdx = children.firstIndex(of: searchElement) {
                        for prev in children[0..<curIdx].reversed() {
                            var prevRoleVal: AnyObject?
                            _ = AXUIElementCopyAttributeValue(prev, kAXRoleAttribute as CFString, &prevRoleVal)
                            let prevRole = (prevRoleVal as? String) ?? ""
                            // 遇到上一个输入控件或操作按钮停止，防止跨卡片污染
                            if prevRole == (kAXTextFieldRole as String) || prevRole == (kAXTextAreaRole as String) || prevRole == "AXButton" {
                                break
                            }
                            if prevRole == "AXGroup" && nodeContainsEditableField(prev) {
                                break
                            }
                            
                            let texts = extractStaticTexts(from: prev)
                            for str in texts {
                                surroundingTexts.append(str)
                                let isDigits = str.allSatisfy { $0.isNumber || $0.isPunctuation }
                                if !isDigits && !str.contains("MATCHED") && !str.contains("●") {
                                    candidateLabels.append(str)
                                }
                            }
                        }
                    }
                }
                if !candidateLabels.isEmpty {
                    break
                }
                searchElement = parentElem
            } else {
                break
            }
        }
        
        if detectedLabel.isEmpty {
            // 优先挑选包含核心表单语义词的主标题 (如 "Event Location", "Conference Dates", "Keynote Speaker & Topic", "Registration Deadline")
            let semanticKeywords = ["location", "date", "speaker", "topic", "deadline", "name", "email", "phone", "address", "title", "description", "event", "conference", "keynote", "cutoff"]
            
            // 1. 优先寻找既包含语义词、又非问句、非占位符的标题
            if let bestSemantic = candidateLabels.first(where: { text in
                let lower = text.lowercased()
                let isQuestion = text.contains("?") || lower.hasPrefix("what") || lower.hasPrefix("who") || lower.hasPrefix("when") || lower.hasPrefix("where") || lower.hasPrefix("how")
                let isPlaceholder = lower.hasPrefix("e.g.")
                return !isQuestion && !isPlaceholder && semanticKeywords.contains(where: { lower.contains($0) })
            }) {
                detectedLabel = bestSemantic
            } else {
                // 2. 备选：词数 >= 2 的非问句文本
                let multiWordCandidates = candidateLabels.filter { text in
                    let lower = text.lowercased()
                    let isQuestion = text.contains("?") || lower.hasPrefix("what") || lower.hasPrefix("who") || lower.hasPrefix("when")
                    return !isQuestion && !lower.hasPrefix("e.g.") && text.split(separator: " ").count >= 2
                }
                if let bestMulti = multiWordCandidates.first {
                    detectedLabel = bestMulti
                } else if let fallback = candidateLabels.first(where: { !$0.contains("?") && !$0.lowercased().hasPrefix("what") }) {
                    detectedLabel = fallback
                }
            }
        }
        
        var placeholderValue: AnyObject?
        _ = AXUIElementCopyAttributeValue(element, kAXPlaceholderValueAttribute as CFString, &placeholderValue)
        if placeholderValue == nil {
            _ = AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &placeholderValue)
        }
        if placeholderValue == nil {
            _ = AXUIElementCopyAttributeValue(element, "AXHelp" as CFString, &placeholderValue)
        }
        let placeholder = (placeholderValue as? String) ?? ""
        let label = detectedLabel
        let surrounding = surroundingTexts.reversed().joined(separator: " ")
        
        var textValue: AnyObject?
        _ = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &textValue)
        let currentValue = (textValue as? String) ?? ""
        
        // 读取所属窗口标题
        var windowValue: AnyObject?
        var windowTitle = ""
        if AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &windowValue) == .success, let win = windowValue {
            var winTitleVal: AnyObject?
            _ = AXUIElementCopyAttributeValue(win as! AXUIElement, kAXTitleAttribute as CFString, &winTitleVal)
            windowTitle = (winTitleVal as? String) ?? ""
        }
        
        let newHash = point.x.hashValue ^ point.y.hashValue ^ size.width.hashValue ^ currentValue.hashValue
        self.currentElement = element
        if newHash != lastElementHash || currentFocusedInput == nil {
            self.lastElementHash = newHash
            let context = FocusedInputContext(
                role: role,
                label: label,
                placeholder: placeholder,
                windowTitle: windowTitle,
                screenFrame: cocoaRect,
                currentValue: currentValue,
                surroundingText: surrounding
            )
            notifyFocusChanged(context)
        }
    }
    
    private func notifyFocusChanged(_ context: FocusedInputContext?) {
        if context == nil {
            if self.currentFocusedInput != nil {
                self.lastElementHash = 0
                self.currentElement = nil
                self.currentFocusedInput = nil
                self.onFocusChanged?(nil)
            }
        } else if let c = context {
            let isChanged = self.currentFocusedInput == nil || c.screenFrame != self.currentFocusedInput?.screenFrame || c.currentValue != self.currentFocusedInput?.currentValue
            self.currentFocusedInput = c
            if isChanged {
                self.onFocusChanged?(c)
            }
        }
    }
    
    private var currentElement: AXUIElement?
    
    /// 直接通过 Accessibility 属性向当前获得焦点的输入框写入文本（零按键模拟，最高可靠性）
    @discardableResult
    public func insertTextIntoFocusedElement(_ text: String) -> Bool {
        if let elem = currentElement, tryInsertText(elem: elem, text: text) {
            return true
        }
        
        // 尝试重新即时捕获全局前台输入框
        let systemWide = AXUIElementCreateSystemWide()
        var appVal: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &appVal) == .success,
              let app = appVal else { return false }
        var elemVal: AnyObject?
        guard AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &elemVal) == .success,
              let elem = elemVal else { return false }
        return tryInsertText(elem: elem as! AXUIElement, text: text)
    }
    
    private func tryInsertText(elem: AXUIElement, text: String) -> Bool {
        // 策略 1：直接赋值给 Value（彻底清空原有全部文字并替换为新建议，杜绝旧字残留与重叠）
        if AXUIElementSetAttributeValue(elem, kAXValueAttribute as CFString, text as CFTypeRef) == .success {
            var range = CFRange(location: (text as NSString).length, length: 0)
            if let axRange = AXValueCreate(.cfRange, &range) {
                _ = AXUIElementSetAttributeValue(elem, kAXSelectedTextRangeAttribute as CFString, axRange)
            }
            return true
        }
        
        // 策略 2：全选当前输入框已有文本（覆盖原有旧文字），然后设置 SelectedText 进行覆盖替换
        var textLength: CFIndex = 0
        var charCountVal: AnyObject?
        if AXUIElementCopyAttributeValue(elem, "AXNumberOfCharacters" as CFString, &charCountVal) == .success,
           let count = charCountVal as? Int {
            textLength = CFIndex(count)
        } else {
            var val: AnyObject?
            if AXUIElementCopyAttributeValue(elem, kAXValueAttribute as CFString, &val) == .success,
               let str = val as? String {
                textLength = CFIndex((str as NSString).length)
            }
        }
        
        // 将选区设为覆盖全部已有字符（位置 0 到 textLength），相当于全选
        var selectAllRange = CFRange(location: 0, length: textLength)
        if let axRange = AXValueCreate(.cfRange, &selectAllRange) {
            _ = AXUIElementSetAttributeValue(elem, kAXSelectedTextRangeAttribute as CFString, axRange)
        }
        
        if AXUIElementSetAttributeValue(elem, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success {
            return true
        }
        
        return false
    }
    
    private func nodeContainsEditableField(_ node: AXUIElement) -> Bool {
        var roleVal: AnyObject?
        _ = AXUIElementCopyAttributeValue(node, kAXRoleAttribute as CFString, &roleVal)
        let role = (roleVal as? String) ?? ""
        if role == (kAXTextFieldRole as String) || role == (kAXTextAreaRole as String) {
            return true
        }
        var childrenVal: AnyObject?
        if AXUIElementCopyAttributeValue(node, kAXChildrenAttribute as CFString, &childrenVal) == .success,
           let children = childrenVal as? [AXUIElement] {
            for c in children {
                if nodeContainsEditableField(c) {
                    return true
                }
            }
        }
        return false
    }

    private func extractStaticTexts(from node: AXUIElement) -> [String] {
        var results: [String] = []
        var roleVal: AnyObject?
        _ = AXUIElementCopyAttributeValue(node, kAXRoleAttribute as CFString, &roleVal)
        let role = (roleVal as? String) ?? ""
        if role == (kAXStaticTextRole as String) || role == "AXStaticText" {
            var val: AnyObject?
            _ = AXUIElementCopyAttributeValue(node, kAXValueAttribute as CFString, &val)
            if val == nil {
                _ = AXUIElementCopyAttributeValue(node, kAXTitleAttribute as CFString, &val)
            }
            if let str = (val as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                results.append(str)
            }
        } else {
            var childrenVal: AnyObject?
            if AXUIElementCopyAttributeValue(node, kAXChildrenAttribute as CFString, &childrenVal) == .success,
               let children = childrenVal as? [AXUIElement] {
                for c in children {
                    results.append(contentsOf: extractStaticTexts(from: c))
                }
            }
        }
        return results
    }
}
