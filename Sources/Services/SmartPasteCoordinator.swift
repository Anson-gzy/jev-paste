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
    
    // JavaScriptCore span 提取缓存，避免多次 ranking 重复调用 JS 引擎
    private var spanCache: [String: [CandidateSpan]] = [:]
    public var spanCacheCount: Int { spanCache.count }
    
    public func cachedSpans(for text: String) -> [CandidateSpan] {
        if let cached = spanCache[text] { return cached }
        let spans = (try? self.bridge?.extractCandidates(from: text)) ?? []
        spanCache[text] = spans
        if spanCache.count > 600 { spanCache.removeAll() }
        return spans
    }
    
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
        let spans = cachedSpans(for: trimmed)
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
        guard let suggestion = quickSuggestion(for: ctx) else {
            GhostOverlayController.shared.hide()
            return
        }
        
        let targetKind = inferFieldKind(from: ctx) ?? .title
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
        let direct = "\(label) \(placeholder)"
        
        // 2. 搜索框 / 过滤框：用户旨在主动检索输入，绝不弹出整段剪贴板推荐
        if ctx.role == "AXSearchField" || matchSemantic(direct, en: "\\b(?:search|filter|find)s?\\b", zh: ["搜索", "过滤"]) {
            return false
        }
        
        // 3. 密码 / PIN / Token / 验证码等敏感输入框：绝不推荐
        if matchSemantic(direct, en: "\\b(?:password|passwd|pin|token|cvv|secret|captcha)s?\\b", zh: ["密码", "验证码"]) {
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
        guard shouldRecommend(for: ctx, inferredKind: .title) else { return nil }
        
        // 1. 获取全量历史剪贴板（如果历史池为空，自动补齐当前剪贴板）
        var history = ClipboardHistoryManager.shared.historyItems
        let currentClip = !self.masterClipboardText.isEmpty ? self.masterClipboardText : (ClipboardMonitor.shared.readCurrent() ?? "")
        if !currentClip.isEmpty && !history.contains(where: { $0.text == currentClip }) {
            history.insert(ClipboardHistoryItem(text: currentClip, timestamp: Date()), at: 0)
        }
        
        // 2. 优先尝试标签键值对匹配 (无需 FieldKind，支持各类结构化表单)
        if let labelled = rankLabelled(for: ctx, history: history, latestText: currentClip) {
            return labelled
        }
        
        // 3. 兜底回退：基于推断字段类型的语义提取匹配
        guard let kind = inferFieldKind(from: ctx) else { return nil }
        let fieldLabel = ctx.label.isEmpty ? (ctx.placeholder.isEmpty ? kind.displayName : ctx.placeholder) : ctx.label
        let ranked = rankSuggestions(for: kind, label: fieldLabel, history: history, referenceDate: Date(), latestText: currentClip)
        if let top = ranked.first, top.finalScore >= 0.55, top.text != ctx.currentValue {
            return top.text
        }
        return nil
    }

    private func rankLabelled(for ctx: FocusedInputContext, history: [ClipboardHistoryItem], latestText: String) -> String? {
        let labels = [ctx.label, ctx.placeholder].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !labels.isEmpty else { return nil }
        var scored: [String: (score: Double, ts: Date)] = [:]
        let now = Date()
        for item in history {
            for pair in LabeledValueMatcher.parsePairs(from: item.text) where !pair.value.isEmpty {
                let sim = labels.map { LabeledValueMatcher.similarity($0, pair.key) }.max() ?? 0.0
                guard sim >= 0.6 else { continue }
                let tw = ClipboardHistoryManager.shared.computeTimeWeight(for: item.timestamp, referenceDate: now)
                let isLatest = (!latestText.isEmpty && item.text == latestText)
                let s = (sim * (0.35 + 0.65 * tw)) + (isLatest ? 0.2 : 0.0)
                scored[pair.value] = (scored[pair.value].map { $0.score + s * 0.4 } ?? s, max(scored[pair.value]?.ts ?? item.timestamp, item.timestamp))
            }
        }
        if let top = scored.sorted(by: { $0.value.score > $1.value.score }).first, top.value.score >= 0.55, top.key != ctx.currentValue {
            return top.key
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
            let spans = cachedSpans(for: item.text)
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
    
    private func matchSemantic(_ text: String, en: String, zh: [String] = []) -> Bool {
        if text.range(of: en, options: [.regularExpression, .caseInsensitive]) != nil { return true }
        return zh.contains(where: { text.contains($0) })
    }
    
    /// 从控件上下文精准推断字段类型（采用主标题 -> 占位符 -> 上下文的层级漏斗，无明确语义返回 nil）
    public func inferFieldKind(from context: FocusedInputContext) -> FieldKind? {
        let label = context.label.lowercased()
        let placeholder = context.placeholder.lowercased()
        let direct = "\(label) \(placeholder)"
        
        // --- 漏斗第 1 层：英文全词匹配（允许复数 s/es），中文子串匹配 ---
        if matchSemantic(direct, en: "\\b(?:speaker|keynote|guest|name|contact|symposium)s?\\b", zh: ["主讲", "讲者", "嘉宾", "姓名", "联系人"]) {
            return .name
        }
        if matchSemantic(direct, en: "\\b(?:email|e-mail|mail)s?\\b", zh: ["邮箱"]) {
            return .email
        }
        if matchSemantic(direct, en: "\\b(?:phone|telephone|mobile|tel)s?\\b", zh: ["电话", "手机"]) {
            return .tel
        }
        if matchSemantic(direct, en: "\\b(?:location|place|venue|center|convention|ballroom|hotel|facility|accommodation|shipping)s?\\b|\\baddress(?:es)?\\b", zh: ["地点", "地址", "会场"]) {
            return .address
        }
        if matchSemantic(direct, en: "\\b(?:date|time|when|deadline|cutoff|duration|schedule)s?\\b", zh: ["日期", "时间", "截止"]) {
            return .date
        }
        if matchSemantic(direct, en: "\\b(?:description|detail|content|note|desc)s?\\b", zh: ["描述", "详细描述", "详情", "正文"]) {
            return .description
        }
        if matchSemantic(direct, en: "\\b(?:title|subject|summary|headline|theme|session|topic)s?\\b", zh: ["标题", "主题", "议题"]) {
            return .title
        }
        if matchSemantic(direct, en: "\\b(?:url|link|website)s?\\b", zh: ["链接", "网址"]) {
            return .url
        }
        
        // --- 漏斗第 2 层：结合周围上下文辅助判断 ---
        let surrounding = context.surroundingText.lowercased()
        if matchSemantic(surrounding, en: "\\b(?:location|venue|facility|hotel)s?\\b|\\baddress(?:es)?\\b", zh: ["地点", "地址", "会场"]) {
            return .address
        }
        if matchSemantic(surrounding, en: "\\b(?:speaker|keynote|symposium)s?\\b", zh: ["主讲", "讲者", "嘉宾", "姓名"]) {
            return .name
        }
        if matchSemantic(surrounding, en: "\\b(?:deadline|cutoff|date|schedule)s?\\b", zh: ["日期", "时间", "截止"]) {
            return .date
        }
        if matchSemantic(surrounding, en: "\\b(?:title|subject|topic)s?\\b", zh: ["标题", "主题", "议题"]) {
            return .title
        }
        if matchSemantic(surrounding, en: "\\b(?:description|detail)s?\\b", zh: ["描述", "详情"]) {
            return .description
        }
        
        // 若无任何明确字段语义，严谨返回 nil，杜绝盲目兜底
        return nil
    }
}
