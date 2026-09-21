import AppKit

/// 协调剪贴板监听、输入框焦点检测、智能推断与灰色幽灵悬浮显示
@MainActor
public final class SmartPasteCoordinator {
    public static let shared = SmartPasteCoordinator()
    
    private var bridge: SmartPasteBridge?
    private var typeSafeClient: TypeSafeClient?
    
    // 内存预计算缓存：[FieldKind: String] 映射当前剪贴板中推断出的各个字段内容
    private var precomputedCache: [FieldKind: String] = [:]
    private var lastPrecomputedClipboard: String = ""
    
    // 标记当前是否正在执行模拟粘贴（防止自发剪贴板事件冲刷 Master Clipboard）
    public var isSimulatingPaste: Bool = false
    
    // 主剪贴板纯文本（用户显式复制的源文本）
    public private(set) var masterClipboardText: String = ""
    
    private init() {
        do {
            let b = try SmartPasteBridge()
            self.bridge = b
            self.typeSafeClient = TypeSafeClient(bridge: b)
        } catch {
            NSLog("[SmartPasteCoordinator] Bridge init error: %@", error.localizedDescription)
        }
    }
    
    /// 启动全套智能联动监听
    public func start() {
        ClipboardMonitor.shared.start()
        AXFocusMonitor.shared.start()
        TabKeyInterceptor.shared.start()
        
        // 1. 剪贴板变化时：立即执行预计算 (Precompute)，使后续点击输入框 0ms 闪电显示
        ClipboardMonitor.shared.onClipboardChanged = { [weak self] newText in
            guard let self = self, !self.isSimulatingPaste else { return }
            self.precomputeClipboard(newText)
        }
        
        // 初始读取当前剪贴板并立即预计算
        if let initialClip = ClipboardMonitor.shared.readCurrent() {
            precomputeClipboard(initialClip)
        }
        
        // 2. 焦点输入框变化时：0ms 优先命中缓存呈现，无感无等待
        AXFocusMonitor.shared.onFocusChanged = { [weak self] context in
            self?.handleFocusChanged(context)
        }
    }
    
    /// 预计算剪贴板内容（双轨：本地 0.5ms 极速解析 + 后台 Jev AI 异步深度校准）
    public func precomputeClipboard(_ text: String) {
        if isSimulatingPaste { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != lastPrecomputedClipboard else { return }
        lastPrecomputedClipboard = trimmed
        masterClipboardText = trimmed
        
        // 1. 本地启发式全量极速预解析 (< 0.5ms)，立即把各字段填满缓存！
        let spans = (try? self.bridge?.extractCandidates(from: trimmed)) ?? []
        let allKinds: [FieldKind] = [.title, .description, .address, .date, .email, .tel, .url, .name]
        let dummyFields = allKinds.map { FormField(id: $0.rawValue, kind: $0, label: $0.displayName) }
        let fullContext = FormContext(heading: "Form", fields: dummyFields)
        let localMatches = LocalHeuristicEngine.shared.match(text: trimmed, context: fullContext, spans: spans)
        
        for match in localMatches {
            if !match.text.isEmpty {
                self.precomputedCache[match.kind] = match.text
            }
        }
        
        // 如果当前已有正在聚焦的输入框，立即刷新展示
        if let currentFocus = AXFocusMonitor.shared.currentFocusedInput {
            self.renderGhost(for: currentFocus)
        }
        
        // 2. 后台并发发起 TypeSafe AI 深度推断以进一步强化校准
        let apiKey = KeychainHelper.shared.getApiKey()
        guard let client = self.typeSafeClient, let key = apiKey, !key.isEmpty else { return }
        
        Task {
            let aiMatches = await client.parse(text: trimmed, context: fullContext, apiKey: key)
            await MainActor.run {
                guard self.lastPrecomputedClipboard == trimmed else { return }
                for match in aiMatches {
                    if !match.text.isEmpty && match.confidence >= 0.6 {
                        self.precomputedCache[match.kind] = match.text
                    }
                }
                if let currentFocus = AXFocusMonitor.shared.currentFocusedInput {
                    self.renderGhost(for: currentFocus)
                }
            }
        }
    }
    
    /// 处理焦点输入框事件
    public func triggerPredict(for context: FocusedInputContext?) {
        handleFocusChanged(context)
    }
    
    private func handleFocusChanged(_ context: FocusedInputContext?) {
        guard let ctx = context else {
            GhostOverlayController.shared.hide()
            return
        }
        let kind = inferFieldKind(from: ctx)
        NSLog("[SmartPasteCoordinator] handleFocusChanged: label='%@', placeholder='%@', kind=%@, val='%@'", ctx.label, ctx.placeholder, kind?.rawValue ?? "none", ctx.currentValue)
        renderGhost(for: ctx)
    }
    
    private func renderGhost(for ctx: FocusedInputContext) {
        let fieldKind = inferFieldKind(from: ctx)
        // 智能门禁检测：若不应推荐，立即彻底隐藏，绝不打扰用户
        guard shouldRecommend(for: ctx, inferredKind: fieldKind) else {
            GhostOverlayController.shared.hide()
            return
        }
        
        guard let suggestion = quickSuggestion(for: ctx) else {
            GhostOverlayController.shared.hide()
            return
        }
        
        let targetKind = fieldKind ?? .title
        let fieldLabel = ctx.label.isEmpty ? (ctx.placeholder.isEmpty ? targetKind.displayName : ctx.placeholder) : ctx.label
        
        GhostOverlayController.shared.show(
            suggestion: suggestion,
            label: fieldLabel,
            at: ctx.screenFrame
        )
    }
    
    /// 智能识别是否应当主动弹出推荐提示（克制、精准、不打扰）
    public func shouldRecommend(for ctx: FocusedInputContext, inferredKind: FieldKind?) -> Bool {
        // 1. 输入框若已有任何文字输入，坚决不推荐
        if !ctx.currentValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        
        let label = ctx.label.lowercased()
        let placeholder = ctx.placeholder.lowercased()
        let role = ctx.role
        
        // 2. 搜索框 / 过滤框：用户旨在主动检索输入，绝不弹出整段剪贴板推荐
        if role == "AXSearchField" ||
           label.contains("search") || label.contains("搜索") || label.contains("filter") || label.contains("过滤") ||
           placeholder.contains("search") || placeholder.contains("搜索") || placeholder.contains("find") {
            return false
        }
        
        // 3. 密码 / PIN / Token / 验证码等敏感输入框：绝不推荐
        let sensitiveKeywords = ["password", "passwd", "密码", "pin", "token", "cvv", "secret", "验证码", "captcha"]
        if sensitiveKeywords.contains(where: { label.contains($0) || placeholder.contains($0) }) {
            return false
        }
        
        // 4. 无明确语义的普通空白输入框：保持静默，绝不盲目打扰
        guard inferredKind != nil else {
            return false
        }
        
        return true
    }
    
    /// 快速获取针对指定输入框上下文的最佳匹配建议（遍历历史剪贴板并应用时间衰减加权）
    public func quickSuggestion(for ctx: FocusedInputContext) -> String? {
        let fieldKind = inferFieldKind(from: ctx)
        guard shouldRecommend(for: ctx, inferredKind: fieldKind), let kind = fieldKind else {
            return nil
        }
        
        let fieldLabel = ctx.label.isEmpty ? (ctx.placeholder.isEmpty ? kind.displayName : ctx.placeholder) : ctx.label
        
        // 1. 获取全量历史剪贴板（如果历史池为空，自动补齐当前剪贴板）
        var history = ClipboardHistoryManager.shared.historyItems
        let currentClip = !self.masterClipboardText.isEmpty ? self.masterClipboardText : (ClipboardMonitor.shared.readCurrent() ?? "")
        if history.isEmpty && !currentClip.isEmpty {
            history = [ClipboardHistoryItem(text: currentClip, timestamp: Date())]
        }
        
        // 2. 在全量历史剪贴板中执行时间衰减加权打分匹配
        let ranked = rankSuggestions(
            for: kind,
            label: fieldLabel,
            history: history,
            referenceDate: Date(),
            latestText: currentClip
        )
        
        // 3. 高置信度门槛：必须满足综合得分 >= 0.55，宁缺毋滥
        if let top = ranked.first, top.finalScore >= 0.55, top.text != ctx.currentValue {
            return top.text
        }
        
        return nil
    }
    
    /// 对所有历史剪贴板记录针对指定字段进行提取与时间衰减加权打分，返回降序排列的候选列表
    public func rankSuggestions(
        for kind: FieldKind,
        label: String,
        history: [ClipboardHistoryItem],
        referenceDate: Date = Date(),
        latestText: String = ""
    ) -> [ScoredSuggestion] {
        var scoredMap: [String: ScoredSuggestion] = [:]
        
        let targetField = FormField(id: "f0", kind: kind, label: label, focused: true)
        let targetContext = FormContext(heading: "Form", fields: [targetField])
        
        for item in history {
            let spans = (try? self.bridge?.extractCandidates(from: item.text)) ?? []
            let matches = LocalHeuristicEngine.shared.match(text: item.text, context: targetContext, spans: spans)
            
            for match in matches where match.kind == kind && !match.text.isEmpty {
                let candidateText = match.text
                let baseConf = match.confidence
                let timeWeight = ClipboardHistoryManager.shared.computeTimeWeight(for: item.timestamp, referenceDate: referenceDate)
                let isLatest = (!latestText.isEmpty && item.text == latestText)
                
                // 时间衰减综合得分公式：
                // 基础语义分占 35%，时间新鲜度占 65%，最新活跃剪贴板享有 +0.2 新鲜度加成
                let itemScore = (baseConf * (0.35 + 0.65 * timeWeight)) + (isLatest ? 0.2 : 0.0)
                
                if let existing = scoredMap[candidateText] {
                    // 同一候选值在多条历史记录中出现，给予累加强化
                    let boostedScore = existing.finalScore + (itemScore * 0.4)
                    let newestTimestamp = max(existing.sourceTimestamp, item.timestamp)
                    scoredMap[candidateText] = ScoredSuggestion(
                        text: candidateText,
                        kind: kind,
                        sourceTimestamp: newestTimestamp,
                        baseConfidence: max(existing.baseConfidence, baseConf),
                        timeWeight: max(existing.timeWeight, timeWeight),
                        finalScore: boostedScore
                    )
                } else {
                    scoredMap[candidateText] = ScoredSuggestion(
                        text: candidateText,
                        kind: kind,
                        sourceTimestamp: item.timestamp,
                        baseConfidence: baseConf,
                        timeWeight: timeWeight,
                        finalScore: itemScore
                    )
                }
            }
        }
        
        return scoredMap.values.sorted { $0.finalScore > $1.finalScore }
    }
    
    /// 从控件上下文精准推断字段类型（采用主标题 -> 占位符 -> 上下文的层级漏斗，无明确语义返回 nil）
    public func inferFieldKind(from context: FocusedInputContext) -> FieldKind? {
        let label = context.label.lowercased()
        let placeholder = context.placeholder.lowercased()
        let direct = "\(label) \(placeholder)"
        
        // --- 漏斗第 1 层：直接根据控件自身标签（label）与占位符（placeholder）精准推断 ---
        // 1. 姓名/主讲人/嘉宾/议题 (如 "Keynote Speaker & Topic", "Symposium Speaker", "Program", "Dr. William Zhang", "Prof.")
        if direct.contains("speaker") || direct.contains("keynote") || direct.contains("guest") || direct.contains("主讲") || direct.contains("讲者") || direct.contains("嘉宾") || direct.contains("name") || direct.contains("姓名") || direct.contains("contact") || direct.contains("联系人") || direct.contains("symposium") || (direct.contains("topic") && !direct.contains("sub-topic")) || direct.contains("program") {
            return .name
        }
        // 2. 邮箱
        if direct.contains("email") || direct.contains("e-mail") || direct.contains("邮箱") || direct.range(of: "\\bmail\\b", options: .regularExpression) != nil {
            return .email
        }
        // 3. 电话
        if direct.contains("phone") || direct.contains("telephone") || direct.contains("mobile") || direct.contains("电话") || direct.contains("手机") || direct.range(of: "\\btel\\b", options: .regularExpression) != nil {
            return .tel
        }
        // 4. 地点/地址/场馆/设施 (如 "Event Location", "Base Hotel & Venue", "Facility", "Accommodation")
        if direct.contains("location") || direct.contains("地点") || direct.contains("address") || direct.contains("地址") || direct.contains("place") || direct.contains("venue") || direct.contains("会场") || direct.contains("center") || direct.contains("convention") || direct.contains("ballroom") || direct.contains("hotel") || direct.contains("facility") || direct.contains("accommodation") {
            return .address
        }
        // 5. 日期/时间/截止期限/日程 (如 "Conference Dates", "Tour Dates", "Schedule", "Deadline", "Cutoff", "Duration")
        if direct.contains("date") || direct.contains("time") || direct.contains("when") || direct.contains("日期") || direct.contains("时间") || direct.contains("deadline") || direct.contains("cutoff") || direct.contains("截止") || direct.contains("compliance") || direct.contains("duration") || direct.contains("schedule") {
            return .date
        }
        // 6. 描述/正文
        if direct.contains("description") || direct.contains("详细描述") || direct.contains("描述") || direct.contains("详情") || direct.contains("detail") || direct.contains("content") || direct.contains("note") || direct.contains("正文") || direct.contains("desc") {
            return .description
        }
        // 7. 标题/主题/议题
        if direct.contains("title") || direct.contains("标题") || direct.contains("subject") || direct.contains("主题") || direct.contains("summary") || direct.contains("headline") || direct.contains("theme") || direct.contains("session") || direct.contains("议题") {
            return .title
        }
        // 8. URL/链接
        if direct.contains("url") || direct.contains("link") || direct.contains("website") || direct.contains("链接") || direct.contains("网址") {
            return .url
        }
        
        // --- 漏斗第 2 层：结合周围上下文辅助判断 ---
        let surrounding = context.surroundingText.lowercased()
        if surrounding.contains("location") || surrounding.contains("venue") || surrounding.contains("address") || surrounding.contains("facility") || surrounding.contains("hotel") {
            return .address
        }
        if surrounding.contains("speaker") || surrounding.contains("keynote") || surrounding.contains("symposium") || surrounding.contains("program") {
            return .name
        }
        if surrounding.contains("deadline") || surrounding.contains("cutoff") || surrounding.contains("date") || surrounding.contains("compliance") || surrounding.contains("schedule") {
            return .date
        }
        if surrounding.contains("title") || surrounding.contains("标题") || surrounding.contains("subject") {
            return .title
        }
        if surrounding.contains("description") || surrounding.contains("描述") {
            return .description
        }
        
        // 若无任何明确字段语义，严谨返回 nil，杜绝盲目兜底
        return nil
    }
}
