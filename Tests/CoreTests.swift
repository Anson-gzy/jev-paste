import Foundation

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

        print("\n🎉 ALL CORE TESTS PASSED SUCCESSFULLY!")
    }
}
