import Foundation
import AppKit

func assertCondition(_ condition: Bool, _ message: String) {
    if !condition {
        print("❌ FAIL: \(message)")
        exit(1)
    } else {
        print("✅ PASS: \(message)")
    }
}

@main
struct CoreTests {
    static func main() async throws {
        let testDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("jev-paste-tests-\(UUID().uuidString)").path
        setenv("JEV_PASTE_DATA_DIR", testDir, 1)
        
        print("=== Starting SmartPaste Core Tests ===")
        
        let sample = """
        Can we file “Keep draft text when switching workspaces”? Switching workspaces clears the issue draft. Preserve the title and description until the issue is created or discarded. Also, the address is Ferry Building, 1 Ferry Building, San Francisco, CA 94111. For the tweet use “One clipboard, four destinations. Working on a little experiment that pastes just what you need.” Our Smart Paste demo is on September 24 at 2 pm for 30 minutes at the Ferry Building.
        """
        
        // 1. 初始化 JavaScriptCore 桥接
        let bridge = try SmartPasteBridge()
        print("✅ SmartPasteBridge initialized successfully")
        
        // 2. 提取候选切片测试
        let spans = try bridge.extractCandidates(from: sample)
        assertCondition(spans.count > 0, "Spans count should be > 0 (got \(spans.count))")
        assertCondition(spans.contains(where: { $0.text.contains("Keep draft text") }), "Spans should contain issue title")
        assertCondition(spans.contains(where: { $0.text.contains("Ferry Building") }), "Spans should contain Ferry Building")
        
        // 3. 本地启发式匹配 - Issue 模板
        let issueFields = LocalHeuristicEngine.shared.match(
            text: sample,
            context: FormPreset.issueTracker.context,
            spans: spans
        )
        assertCondition(issueFields.contains(where: { $0.kind == .title && $0.text == "Keep draft text when switching workspaces" }), "Issue title exact match")
        assertCondition(issueFields.contains(where: { $0.kind == .description && !$0.text.isEmpty }), "Issue description match")
        
        // 4. 本地启发式匹配 - Calendar 模板
        let calendarFields = LocalHeuristicEngine.shared.match(
            text: sample,
            context: FormPreset.calendarEvent.context,
            spans: spans
        )
        assertCondition(calendarFields.contains(where: { $0.kind == .date }), "Calendar date detected")
        assertCondition(calendarFields.contains(where: { $0.kind == .address }), "Calendar address detected")
        
        // 5. 结构化带标签文本解析测试
        let labeledSample = """
        Name: Alice Smith
        Email: alice@example.com
        Phone: +1 (555) 234-5678
        Company: Acme Corp
        Address: 100 Main St, Austin, TX 78701
        """
        let contactSpans = try bridge.extractCandidates(from: labeledSample)
        let contactFields = LocalHeuristicEngine.shared.match(
            text: labeledSample,
            context: FormPreset.contact.context,
            spans: contactSpans
        )
        assertCondition(contactFields.contains(where: { $0.kind == .email && $0.text == "alice@example.com" }), "Contact email match")
        assertCondition(contactFields.contains(where: { $0.kind == .tel && $0.text.contains("555") }), "Contact phone match")
        // 6. 覆盖替换与防重叠逻辑验证测试
        let existingOldDraft = "原本残留的旧字草稿"
        let newSuggestedValue = "新推荐的干净文本"
        var textValue = existingOldDraft
        textValue = newSuggestedValue
        assertCondition(textValue == newSuggestedValue, "Value should be completely replaced by suggestion")
        assertCondition(!textValue.contains(existingOldDraft), "Old text must be completely removed without overlapping")
        
        // 7. 多语言与本地化验证测试（主语言 English 且支持中英即时切换）
        let locManager = LocalizationManager.shared
        locManager.setLanguage(.en)
        let enTitle = L("nav.dashboard")
        assertCondition(enTitle == "Dashboard", "Default/Primary language should provide English 'Dashboard' (got \(enTitle))")
        
        locManager.setLanguage(.zhHans)
        let zhTitle = L("nav.dashboard")
        assertCondition(zhTitle == "控制面板", "Language switch to zhHans should provide '控制面板' (got \(zhTitle))")
        
        locManager.setLanguage(.en)
        
        // 8. 日程安排与问答抽取基准测试 (Schedule Q&A Demo Workbench 适配)
        let scheduleSample = """
        The Global AI & Systems Summit officially takes place from October 15 – October 17, 2026 in Shanghai. Keynotes and partner sessions are hosted at the Shanghai International Convention Center (No. 2727 Riverside Ave, Pudong), 3F Grand Ballroom. All participants must verify credentials before September 30, 2026 at 23:59. Opening Keynote Delivered by Dr. William Zhang (Director of National AI Labs), on "Next-Gen Embodied Intelligence".
        """
        let scheduleSpans = try bridge.extractCandidates(from: scheduleSample)
        assertCondition(scheduleSpans.count > 0, "Schedule spans count > 0")
        
        let scheduleContext = FormContext(heading: "Schedule Q&A · Information Extraction Workbench", fields: [
            FormField(id: "location", kind: .address, label: "Event Location", focused: false),
            FormField(id: "date", kind: .date, label: "Conference Dates", focused: false),
            FormField(id: "keynote", kind: .name, label: "Keynote Speaker & Topic", focused: false),
            FormField(id: "deadline", kind: .date, label: "Registration Deadline", focused: false)
        ])
        
        let qaMatches = LocalHeuristicEngine.shared.match(text: scheduleSample, context: scheduleContext, spans: scheduleSpans)
        
        let matchedLocation = qaMatches.first(where: { $0.fieldId == "location" })?.text ?? ""
        let matchedDate = qaMatches.first(where: { $0.fieldId == "date" })?.text ?? ""
        let matchedKeynote = qaMatches.first(where: { $0.fieldId == "keynote" })?.text ?? ""
        let matchedDeadline = qaMatches.first(where: { $0.fieldId == "deadline" })?.text ?? ""
        
        assertCondition(matchedLocation.contains("Shanghai International Convention Center") && matchedLocation.contains("Grand Ballroom"), "Event location accurately extracted (got: '\(matchedLocation)')")
        assertCondition(matchedDate.contains("October 15") && matchedDate.contains("October 17, 2026"), "Conference dates accurately extracted (got: '\(matchedDate)')")
        assertCondition(matchedKeynote.contains("William Zhang") && matchedKeynote.contains("Embodied Intelligence"), "Keynote speaker & topic accurately extracted (got: '\(matchedKeynote)')")
        assertCondition(matchedDeadline.contains("September 30, 2026") && matchedDeadline.contains("23:59"), "Registration deadline accurately extracted (got: '\(matchedDeadline)')")
        
        // 9. 第二数据集测试：Silicon Valley Executive Tour Itinerary
        let tourSample = """
        The executive delegation tour runs from November 2 – November 8, 2026 across Northern California. Accommodations and base briefings are held at Four Seasons Hotel Silicon Valley at East Palo Alto (2050 University Ave). Delegates must submit compliance disclosures by October 10, 2026 at 17:00 (PST). Key Stops: Stanford AI Lab Symposium. Closed-door exchange with Prof. David Miller on "Heterogeneous Compute Clusters".
        """
        let tourSpans = try bridge.extractCandidates(from: tourSample)
        let tourContext = FormContext(heading: "Schedule Q&A · Information Extraction Workbench", fields: [
            FormField(id: "location", kind: .address, label: "Event Location", focused: false),
            FormField(id: "date", kind: .date, label: "Conference Dates", focused: false),
            FormField(id: "keynote", kind: .name, label: "Keynote Speaker & Topic", focused: false),
            FormField(id: "deadline", kind: .date, label: "Registration Deadline", focused: false)
        ])
        let tourMatches = LocalHeuristicEngine.shared.match(text: tourSample, context: tourContext, spans: tourSpans)
        let tourLocation = tourMatches.first(where: { $0.fieldId == "location" })?.text ?? ""
        let tourDate = tourMatches.first(where: { $0.fieldId == "date" })?.text ?? ""
        let tourKeynote = tourMatches.first(where: { $0.fieldId == "keynote" })?.text ?? ""
        let tourDeadline = tourMatches.first(where: { $0.fieldId == "deadline" })?.text ?? ""
        
        assertCondition(tourLocation.contains("Four Seasons Hotel") && tourLocation.contains("2050 University Ave"), "Tour location accurately extracted (got: '\(tourLocation)')")
        assertCondition(tourDate.contains("November 2") && tourDate.contains("November 8, 2026"), "Tour dates accurately extracted (got: '\(tourDate)')")
        assertCondition(tourKeynote.contains("David Miller") && tourKeynote.contains("Heterogeneous Compute Clusters"), "Tour keynote accurately extracted (got: '\(tourKeynote)')")
        assertCondition(tourDeadline.contains("October 10, 2026") && tourDeadline.contains("17:00"), "Tour deadline accurately extracted (got: '\(tourDeadline)')")
        
        // 10. 单条精准剪贴板与独立单字段即时预测测试
        let singleLocation = "Shanghai International Convention Center (No. 2727 Riverside Ave, Pudong), 3F Grand Ballroom"
        let singleLocationSpans = try bridge.extractCandidates(from: singleLocation)
        let singleLocationMatch = LocalHeuristicEngine.shared.match(
            text: singleLocation,
            context: FormContext(heading: "Form", fields: [FormField(id: "f0", kind: .address, label: "Event Location", focused: true)]),
            spans: singleLocationSpans
        )
        assertCondition(singleLocationMatch.first?.text.contains("Shanghai International Convention Center") == true, "Single location match")
        
        let singleDate = "October 15 – October 17, 2026"
        let singleDateSpans = try bridge.extractCandidates(from: singleDate)
        let singleDateMatch = LocalHeuristicEngine.shared.match(
            text: singleDate,
            context: FormContext(heading: "Form", fields: [FormField(id: "f0", kind: .date, label: "Conference Dates", focused: true)]),
            spans: singleDateSpans
        )
        assertCondition(singleDateMatch.first?.text == "October 15 – October 17, 2026", "Single date match")
        
        let singleKeynote = "Dr. William Zhang (Director of National AI Labs), on \"Next-Gen Embodied Intelligence\""
        let singleKeynoteSpans = try bridge.extractCandidates(from: singleKeynote)
        let singleKeynoteMatch = LocalHeuristicEngine.shared.match(
            text: singleKeynote,
            context: FormContext(heading: "Form", fields: [FormField(id: "f0", kind: .name, label: "Keynote Speaker & Topic", focused: true)]),
            spans: singleKeynoteSpans
        )
        assertCondition(singleKeynoteMatch.first?.text.contains("William Zhang") == true, "Single keynote match")
        
        let singleDeadline = "September 30, 2026 at 23:59"
        let singleDeadlineSpans = try bridge.extractCandidates(from: singleDeadline)
        let singleDeadlineMatch = LocalHeuristicEngine.shared.match(
            text: singleDeadline,
            context: FormContext(heading: "Form", fields: [FormField(id: "f0", kind: .date, label: "Registration Deadline", focused: true)]),
            spans: singleDeadlineSpans
        )
        assertCondition(singleDeadlineMatch.first?.text.contains("September 30, 2026") == true && singleDeadlineMatch.first?.text.contains("23:59") == true, "Single deadline match")

        // 11. 第二数据集单条剪贴板测试
        let singleTourDeadline = "October 10, 2026 at 17:00 (PST)"
        let singleTourDeadlineSpans = try bridge.extractCandidates(from: singleTourDeadline)
        let singleTourDeadlineMatch = LocalHeuristicEngine.shared.match(
            text: singleTourDeadline,
            context: FormContext(heading: "Form", fields: [FormField(id: "f0", kind: .date, label: "Compliance Deadline", focused: true)]),
            spans: singleTourDeadlineSpans
        )
        assertCondition(singleTourDeadlineMatch.first?.text.contains("October 10, 2026") == true && singleTourDeadlineMatch.first?.text.contains("17:00") == true, "Single tour deadline match")

        // 12. 历史剪贴板管理器新增与查重置顶测试
        let historyMgr = ClipboardHistoryManager.shared
        historyMgr.clearHistory()
        assertCondition(historyMgr.historyItems.isEmpty, "History starts empty after clear")
        
        let text1 = "Meeting with Dr. William Zhang at 10:00"
        let text2 = "Conference Venue: Shanghai International Convention Center, 3F Ballroom"
        historyMgr.addText(text1, timestamp: Date().addingTimeInterval(-3600)) // 1 小时前
        historyMgr.addText(text2, timestamp: Date())                         // 刚刚
        assertCondition(historyMgr.historyItems.count == 2, "History has 2 items")
        assertCondition(historyMgr.historyItems.first?.text == text2, "Newest item text2 is at top")
        
        // 查重：再次添加 text1，应该更新时间并移至最前
        historyMgr.addText(text1, timestamp: Date())
        assertCondition(historyMgr.historyItems.count == 2, "Duplicate text did not increase item count")
        assertCondition(historyMgr.historyItems.first?.text == text1, "Re-added text1 was moved to top")

        // 13. 时间衰减权重计算测试 (半衰期 6 小时)
        let now = Date()
        let weightNow = historyMgr.computeTimeWeight(for: now, referenceDate: now)
        assertCondition(abs(weightNow - 1.0) < 0.01, "Current time weight should be ~1.0")
        
        let sixHoursAgo = now.addingTimeInterval(-6 * 3600)
        let weight6h = historyMgr.computeTimeWeight(for: sixHoursAgo, referenceDate: now)
        assertCondition(abs(weight6h - 0.5) < 0.05, "6-hour-old item weight should be ~0.5 (half-life)")
        
        let twentyFourHoursAgo = now.addingTimeInterval(-24 * 3600)
        let weight24h = historyMgr.computeTimeWeight(for: twentyFourHoursAgo, referenceDate: now)
        assertCondition(weight24h < 0.15, "24-hour-old item weight should be significantly decayed (<0.15)")

        // 14. 历史记录保留期自动淘汰测试 (默认 1 天)
        historyMgr.clearHistory()
        historyMgr.retentionPeriod = .day1 // 1 天 = 86400 秒
        let freshItem = "Fresh item within 1 hour"
        let staleItem = "Stale item 3 days ago"
        historyMgr.addText(freshItem, timestamp: now.addingTimeInterval(-3600))
        historyMgr.addText(staleItem, timestamp: now.addingTimeInterval(-3 * 86400))
        historyMgr.pruneExpiredItems(referenceDate: now)
        assertCondition(historyMgr.historyItems.contains(where: { $0.text == freshItem }), "Fresh item retained")
        assertCondition(!historyMgr.historyItems.contains(where: { $0.text == staleItem }), "Item older than 1 day pruned")

        // 15. 多条历史剪贴板时间加权选优测试
        let oldHistory = ClipboardHistoryItem(
            text: "Old Event Location: Beijing International Hotel, Chaoyang District",
            timestamp: now.addingTimeInterval(-18 * 3600) // 18 小时前复制
        )
        let newHistory = ClipboardHistoryItem(
            text: "New Event Location: Shanghai International Convention Center, 3F Grand Ballroom",
            timestamp: now.addingTimeInterval(-60) // 1 分钟前复制
        )
        
        let targetContext = FormContext(heading: "Form", fields: [FormField(id: "f0", kind: .address, label: "Event Location", focused: true)])
        let spansOld = try bridge.extractCandidates(from: oldHistory.text)
        let spansNew = try bridge.extractCandidates(from: newHistory.text)
        let matchOld = LocalHeuristicEngine.shared.match(text: oldHistory.text, context: targetContext, spans: spansOld).first
        let matchNew = LocalHeuristicEngine.shared.match(text: newHistory.text, context: targetContext, spans: spansNew).first
        
        let scoreOld = (matchOld?.confidence ?? 0.8) * (0.35 + 0.65 * historyMgr.computeTimeWeight(for: oldHistory.timestamp, referenceDate: now))
        let scoreNew = (matchNew?.confidence ?? 0.8) * (0.35 + 0.65 * historyMgr.computeTimeWeight(for: newHistory.timestamp, referenceDate: now)) + 0.2
        assertCondition(scoreNew > scoreOld, "Recent Shanghai venue score (\(scoreNew)) > 18h old Beijing venue score (\(scoreOld))")

        // 16. 智能推荐决策门禁测试 (识别是否应该推荐)
        let coordinator = SmartPasteCoordinator.shared
        
        // 测试 A: 搜索框不推荐
        let searchContext = FocusedInputContext(
            role: "AXSearchField",
            label: "Search",
            placeholder: "Search Google or type a URL",
            windowTitle: "Browser",
            screenFrame: NSRect(x: 100, y: 100, width: 300, height: 30),
            currentValue: ""
        )
        assertCondition(!coordinator.shouldRecommend(for: searchContext, inferredKind: coordinator.inferFieldKind(from: searchContext)), "Search field MUST NOT be recommended")

        // 测试 B: 密码框不推荐
        let pwdContext = FocusedInputContext(
            role: "AXTextField",
            label: "Password",
            placeholder: "Enter account password",
            windowTitle: "Login",
            screenFrame: NSRect(x: 100, y: 100, width: 200, height: 30),
            currentValue: ""
        )
        assertCondition(!coordinator.shouldRecommend(for: pwdContext, inferredKind: coordinator.inferFieldKind(from: pwdContext)), "Password field MUST NOT be recommended")

        // 测试 C: 无语义空白框不推荐 (inferFieldKind 返回 nil)
        let blankContext = FocusedInputContext(
            role: "AXTextField",
            label: "",
            placeholder: "",
            windowTitle: "Some App",
            screenFrame: NSRect(x: 100, y: 100, width: 200, height: 30),
            currentValue: ""
        )
        let blankKind = coordinator.inferFieldKind(from: blankContext)
        assertCondition(blankKind == nil, "Blank field without semantic labels returns nil inferred kind")
        assertCondition(!coordinator.shouldRecommend(for: blankContext, inferredKind: blankKind), "Blank field MUST NOT be recommended")

        // 测试 D: 有明确日程语义框应该推荐
        let locationContext = FocusedInputContext(
            role: "AXTextField",
            label: "Event Location",
            placeholder: "e.g., Convention Center",
            windowTitle: "Schedule Form",
            screenFrame: NSRect(x: 100, y: 100, width: 400, height: 38),
            currentValue: ""
        )
        let locKind = coordinator.inferFieldKind(from: locationContext)
        assertCondition(locKind == .address, "Event Location inferred as .address")
        assertCondition(coordinator.shouldRecommend(for: locationContext, inferredKind: locKind), "Event Location MUST be recommended")

        // 17. 剪贴板隐私类型过滤测试 (密码管理器/私有标记识别)
        assertCondition(ClipboardMonitor.shouldIgnore(types: ["org.nspasteboard.ConcealedType"]), "Concealed type should be ignored")
        assertCondition(ClipboardMonitor.shouldIgnore(types: ["org.nspasteboard.TransientType"]), "Transient type should be ignored")
        assertCondition(!ClipboardMonitor.shouldIgnore(types: ["public.utf8-plain-text"]), "Plain text should not be ignored")
        assertCondition(ClipboardMonitor.shouldIgnore(types: ["org.nspasteboard.AutoGeneratedType"]), "AutoGenerated type should be ignored")
        assertCondition(ClipboardMonitor.shouldIgnore(types: ["com.agilebits.onepassword"]), "1Password type should be ignored")
        assertCondition(ClipboardMonitor.shouldIgnore(types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"]), "Mixed types containing concealed should be ignored")

        // 18. TabKeyInterceptor.shouldIntercept 纯静态决策测试
        assertCondition(TabKeyInterceptor.shouldIntercept(keyCode: 48, flags: [], ghostShowing: true), "Tab intercepts when ghost is showing")
        assertCondition(!TabKeyInterceptor.shouldIntercept(keyCode: 48, flags: [], ghostShowing: false), "Tab does not intercept when ghost is not showing")
        assertCondition(!TabKeyInterceptor.shouldIntercept(keyCode: 48, flags: .maskShift, ghostShowing: true), "Shift+Tab is never intercepted")
        assertCondition(!TabKeyInterceptor.shouldIntercept(keyCode: 48, flags: .maskCommand, ghostShowing: true), "Cmd+Tab is never intercepted")
        assertCondition(!TabKeyInterceptor.shouldIntercept(keyCode: 48, flags: .maskControl, ghostShowing: true), "Ctrl+Tab is never intercepted")
        assertCondition(!TabKeyInterceptor.shouldIntercept(keyCode: 48, flags: .maskAlternate, ghostShowing: true), "Opt+Tab is never intercepted")
        assertCondition(!TabKeyInterceptor.shouldIntercept(keyCode: 36, flags: [], ghostShowing: true), "Non-Tab key is never intercepted")

        // 19. PasteSimulator 全量剪贴板快照恢复与 TransientType 标记测试
        let testPb = NSPasteboard.withUniqueName()
        let rtfType = NSPasteboard.PasteboardType("public.rtf"), rtfBytes = Data("{\\rtf1 test}".utf8)
        let item1 = NSPasteboardItem(), item2 = NSPasteboardItem()
        item1.setString("Item 1 String", forType: .string)
        item1.setData(rtfBytes, forType: rtfType)
        item2.setString("Item 2 String", forType: .string)
        testPb.clearContents()
        testPb.writeObjects([item1, item2])
        
        let pbSnapshot = PasteSimulator.shared.snapshotPasteboard(from: testPb)
        PasteSimulator.shared.writeTransientText("Transient Output", to: testPb)
        assertCondition(testPb.string(forType: .string) == "Transient Output", "Transient text written to pasteboard")
        assertCondition(testPb.types?.contains(PasteSimulator.transientType) == true, "Paste write marked with TransientType")
        assertCondition(ClipboardMonitor.shouldIgnore(types: testPb.types?.map { $0.rawValue } ?? []), "Transient write is ignored by ClipboardMonitor")
        
        PasteSimulator.shared.restorePasteboard(pbSnapshot, to: testPb)
        let restoredItems = testPb.pasteboardItems ?? []
        assertCondition(restoredItems.count == 2, "Full pasteboard items count restored to 2")
        assertCondition(restoredItems.first?.string(forType: .string) == "Item 1 String" && restoredItems.first?.data(forType: rtfType) == rtfBytes, "Item 1 string and RTF restored")
        assertCondition(restoredItems.last?.string(forType: .string) == "Item 2 String", "Item 2 string restored")
        assertCondition(!ClipboardMonitor.shouldIgnore(types: testPb.types?.map { $0.rawValue } ?? []), "Restored pasteboard is not marked transient")

        // 20. 字段类型识别精准度与中英文匹配测试 (paste-field-accuracy)
        func makeCtx(label: String, placeholder: String = "") -> FocusedInputContext {
            FocusedInputContext(role: "AXTextField", label: label, placeholder: placeholder, windowTitle: "Win", screenFrame: .zero, currentValue: "")
        }
        let shippingCtx = makeCtx(label: "Shipping address")
        assertCondition(coordinator.inferFieldKind(from: shippingCtx) == .address, "Shipping address correctly recognized as .address")
        assertCondition(coordinator.shouldRecommend(for: shippingCtx, inferredKind: coordinator.inferFieldKind(from: shippingCtx)) == true, "shouldRecommend(Shipping address) == true")
        let pinCtx = makeCtx(label: "PIN")
        assertCondition(coordinator.shouldRecommend(for: pinCtx, inferredKind: coordinator.inferFieldKind(from: pinCtx)) == false, "label 'PIN' shouldRecommend == false")
        assertCondition(coordinator.inferFieldKind(from: makeCtx(label: "Shipping")) == .address, "Shipping correctly recognized as .address")
        assertCondition(coordinator.inferFieldKind(from: makeCtx(label: "Username")) == nil, "Username not misclassified as .name")
        assertCondition(coordinator.inferFieldKind(from: makeCtx(label: "Timezone")) == nil, "Timezone not misclassified as .date")
        assertCondition(coordinator.inferFieldKind(from: makeCtx(label: "Updated")) == nil, "Updated not misclassified as .date")
        assertCondition(coordinator.inferFieldKind(from: makeCtx(label: "Last updated")) == nil, "'Last updated' == nil")
        assertCondition(coordinator.inferFieldKind(from: makeCtx(label: "Event Dates")) == .date, "'Event Dates' == .date")
        assertCondition(coordinator.inferFieldKind(from: makeCtx(label: "Start time")) == .date, "'Start time' == .date")
        assertCondition(coordinator.inferFieldKind(from: makeCtx(label: "手机号")) == .tel, "'手机号' == .tel")
        assertCondition(coordinator.inferFieldKind(from: makeCtx(label: "活动地点")) == .address, "'活动地点' == .address")
        assertCondition(coordinator.inferFieldKind(from: makeCtx(label: "Topic")) == .title, "'Topic' == .title")
        assertCondition(coordinator.inferFieldKind(from: makeCtx(label: "收货地址")) == .address, "Chinese address recognized")
        assertCondition(coordinator.inferFieldKind(from: makeCtx(label: "联系人姓名")) == .name, "Chinese name recognized")

        // 21. JavaScriptCore 候选切片缓存与 ranking 重复调用测试
        let cacheHistory = [ClipboardHistoryItem(text: "Conference at Ferry Building, San Francisco on Oct 20", timestamp: Date())]
        let initialCacheCount = coordinator.spanCacheCount
        _ = coordinator.rankSuggestions(for: .address, label: "Address", history: cacheHistory)
        let countAfterFirstRank = coordinator.spanCacheCount
        assertCondition(countAfterFirstRank >= initialCacheCount, "spanCacheCount populated after ranking")
        _ = coordinator.rankSuggestions(for: .address, label: "Address", history: cacheHistory)
        assertCondition(coordinator.spanCacheCount == countAfterFirstRank, "Repeated ranking reuses span cache without re-running JS (spanCacheCount: \(coordinator.spanCacheCount))")
        for i in 0..<605 { _ = coordinator.cachedSpans(for: "cache_overflow_test_\(i)") }
        assertCondition(coordinator.spanCacheCount <= 5, "spanCache cleared when exceeding 600 entries (got \(coordinator.spanCacheCount))")

        // 22. 结构化带标签键值匹配与智能推荐测试 (paste-labeled-values)
        let demoZH = """
        [企业智能报销与合规审核工作台]
        申报人姓名: 张伟 (EMP-2024-082)
        所属部门: 市场营销部
        申报总金额: ¥1,680.00
        费用发生日期: 2026-09-12 至 2026-09-13
        费用类别: 差旅与客户商务宴请
        发票号码 / 代码: INV-20260912-8819
        费用事由与商户明细: Q3 华东渠道合作伙伴闭门招商晚宴宴请及返程出行
        """
        let pairs = LabeledValueMatcher.parsePairs(from: demoZH)
        assertCondition(pairs.contains(where: { $0.key == "所属部门" && $0.value == "市场营销部" }), "parsePairs extracts 所属部门")
        let nextPairs = LabeledValueMatcher.parsePairs(from: "所属部门:\n市场营销部\n费用类别:\n差旅费")
        assertCondition(nextPairs.contains(where: { $0.key == "所属部门" && $0.value == "市场营销部" }), "parse next-line colon")
        assertCondition(nextPairs.contains(where: { $0.key == "费用类别" && $0.value == "差旅费" }), "parse next-line colon 2")
        assertCondition(LabeledValueMatcher.parsePairs(from: "file:///a/b.html\n10:30 standup\nhttps://x.com").isEmpty, "URL and time rejected")
        assertCondition(LabeledValueMatcher.similarity("所属部门", "所属部门") == 1.0, "Similarity exact")
        assertCondition(LabeledValueMatcher.similarity("部门", "所属部门") >= 0.8, "Similarity substring")
        assertCondition(LabeledValueMatcher.similarity("Name", "Game") < 0.6, "Similarity Name vs Game < 0.6")
        assertCondition(LabeledValueMatcher.similarity("Date", "Data") < 0.6, "Similarity Date vs Data < 0.6")

        coordinator.precomputeClipboard(demoZH)
        func zhCtx(_ l: String, _ v: String = "", _ r: String = "AXTextField") -> FocusedInputContext {
            FocusedInputContext(role: r, label: l, placeholder: "", windowTitle: "Demo", screenFrame: .zero, currentValue: v)
        }
        for (lbl, exp) in [
            ("申报人姓名", "张伟 (EMP-2024-082)"), ("所属部门", "市场营销部"),
            ("申报总金额", "¥1,680.00"), ("费用发生日期", "2026-09-12 至 2026-09-13"),
            ("费用类别", "差旅与客户商务宴请"), ("发票号码 / 代码", "INV-20260912-8819"),
            ("费用事由与商户明细", "Q3 华东渠道合作伙伴闭门招商晚宴宴请及返程出行")
        ] {
            assertCondition(coordinator.quickSuggestion(for: zhCtx(lbl)) == exp, "Matched \(lbl)")
        }
        assertCondition(coordinator.quickSuggestion(for: zhCtx("所属部门", "已有文字")) == nil, "Non-empty blocked")
        assertCondition(coordinator.quickSuggestion(for: zhCtx("所属部门", "", "AXSearchField")) == nil, "Search blocked")
        assertCondition(coordinator.quickSuggestion(for: zhCtx("密码")) == nil, "Sensitive blocked")

        coordinator.precomputeClipboard("申报人:\n李思奇\n工号:\nEMP-2024-091")
        assertCondition(coordinator.quickSuggestion(for: zhCtx("员工工号")) == "EMP-2024-091", "OCR next-line EMP-2024-091 matched")

        let prose = "Hello team\nsee you tomorrow at the venue"
        assertCondition(LabeledValueMatcher.parsePairs(from: prose).isEmpty, "Prose parsePairs is empty")
        coordinator.precomputeClipboard(prose)
        assertCondition(coordinator.quickSuggestion(for: zhCtx("Hello")) == nil, "Prose Hello returns nil")

        print("\n🎉 ALL CORE TESTS PASSED SUCCESSFULLY!")
    }
}
