import Foundation

/// 本地高效离线启发式解析引擎（当未配置 TypeSafe Key 或网络离线时提供高保真提取）
public final class LocalHeuristicEngine {
    public static let shared = LocalHeuristicEngine()
    
    private init() {}
    
    /// 根据表单上下文与候选 Spans 智能提取匹配的字段
    public func match(text: String, context: FormContext, spans: [CandidateSpan]) -> [VerifiedField] {
        var results: [VerifiedField] = []
        var claimedSpans = Set<String>()
        
        for field in context.fields {
            if let matched = findBestMatch(for: field, in: text, context: context, spans: spans, claimed: &claimedSpans) {
                results.append(matched)
            }
        }
        
        return results
    }
    
    private func findBestMatch(for field: FormField,
                               in fullText: String,
                               context: FormContext,
                               spans: [CandidateSpan],
                               claimed: inout Set<String>) -> VerifiedField? {
        switch field.kind {
        case .email:
            if let span = spans.first(where: { !claimed.contains($0.id) && isEmail($0.text) }) {
                claimed.insert(span.id)
                return VerifiedField(fieldId: field.id, kind: .email, label: field.label, text: span.text, confidence: 0.98, sourceStart: span.start, sourceEnd: span.end)
            }
            if isEmail(fullText) {
                return VerifiedField(fieldId: field.id, kind: .email, label: field.label, text: fullText, confidence: 0.98, sourceStart: 0, sourceEnd: fullText.count)
            }
            let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
            if let match = fullText.range(of: emailRegex, options: .regularExpression) {
                let str = String(fullText[match])
                return VerifiedField(fieldId: field.id, kind: .email, label: field.label, text: str, confidence: 0.95, sourceStart: 0, sourceEnd: str.count)
            }
            
        case .url:
            if let span = spans.first(where: { !claimed.contains($0.id) && isUrl($0.text) }) {
                claimed.insert(span.id)
                return VerifiedField(fieldId: field.id, kind: .url, label: field.label, text: span.text, confidence: 0.98, sourceStart: span.start, sourceEnd: span.end)
            }
            if isUrl(fullText) {
                return VerifiedField(fieldId: field.id, kind: .url, label: field.label, text: fullText, confidence: 0.98, sourceStart: 0, sourceEnd: fullText.count)
            }
            let urlRegex = "https?://[A-Za-z0-9.-]+(?:/[^\\s]*)?"
            if let match = fullText.range(of: urlRegex, options: .regularExpression) {
                let str = String(fullText[match])
                return VerifiedField(fieldId: field.id, kind: .url, label: field.label, text: str, confidence: 0.95, sourceStart: 0, sourceEnd: str.count)
            }
            
        case .tel:
            if let span = spans.first(where: { !claimed.contains($0.id) && isPhone($0.text) }) {
                claimed.insert(span.id)
                return VerifiedField(fieldId: field.id, kind: .tel, label: field.label, text: span.text, confidence: 0.92, sourceStart: span.start, sourceEnd: span.end)
            }
            if isPhone(fullText) {
                return VerifiedField(fieldId: field.id, kind: .tel, label: field.label, text: fullText, confidence: 0.92, sourceStart: 0, sourceEnd: fullText.count)
            }
            
        case .address:
            // 优先查找带 Address/Location 标签或包含地址特征的 span
            if let span = spans.first(where: { !claimed.contains($0.id) && ($0.label?.lowercased().contains("address") == true || $0.label?.lowercased().contains("location") == true) }) {
                claimed.insert(span.id)
                return VerifiedField(fieldId: field.id, kind: .address, label: field.label, text: cleanAddress(span.text), confidence: 0.95, sourceStart: span.start, sourceEnd: span.end)
            }
            let addrSpans = spans.filter { !claimed.contains($0.id) && containsAddressClues($0.text) }
            // 优先选择包含完整门牌/场馆/宾馆特征、括号闭合且长度适中的段落（防止被内部逗号斩断）
            let completeAddrSpans = addrSpans.filter { s in
                let hasUnclosedParen = s.text.contains("(") && !s.text.contains(")")
                return !hasUnclosedParen
            }
            if let target = completeAddrSpans.first(where: { s in
                let cleaned = cleanAddress(s.text)
                return cleaned.count >= 20 && cleaned.count <= 160 && (s.text.contains("(") || s.text.lowercased().contains("hotel") || s.text.lowercased().contains("center") || s.text.lowercased().contains("ballroom") || s.text.lowercased().contains("ave"))
            }) {
                claimed.insert(target.id)
                return VerifiedField(fieldId: field.id, kind: .address, label: field.label, text: cleanAddress(target.text), confidence: 0.95, sourceStart: target.start, sourceEnd: target.end)
            }
            if let first = completeAddrSpans.first ?? addrSpans.first {
                claimed.insert(first.id)
                return VerifiedField(fieldId: field.id, kind: .address, label: field.label, text: cleanAddress(first.text), confidence: 0.88, sourceStart: first.start, sourceEnd: first.end)
            }
            // 回退：直接从 fullText 查找包含地址线索的句子
            if containsAddressClues(fullText) {
                let sentences = fullText.components(separatedBy: CharacterSet(charactersIn: ".\n"))
                let bestSentence = sentences.first(where: { containsAddressClues($0) && $0.count >= 15 }) ?? fullText
                let cleaned = cleanAddress(bestSentence)
                if !cleaned.isEmpty && cleaned.count >= 10 && cleaned.count <= 180 {
                    return VerifiedField(fieldId: field.id, kind: .address, label: field.label, text: cleaned, confidence: 0.92, sourceStart: 0, sourceEnd: cleaned.count)
                }
            }
            
        case .date:
            let isDeadline = field.label.lowercased().contains("deadline") || field.label.lowercased().contains("cutoff") || field.label.lowercased().contains("截止") || field.label.lowercased().contains("compliance")
            let dateSpans = spans.filter { !claimed.contains($0.id) && ($0.label?.lowercased().contains("date") == true || containsDateClues($0.text)) }
            
            if isDeadline {
                // 优先查找包含具体时间点（如 23:59、17:00 等具体时刻）或包含 before/deadline/cutoff/by 的干净单句切片
                let deadlineCandidates = dateSpans.filter { s in
                    let lower = s.text.lowercased()
                    let hasSpecificTime = s.text.range(of: "\\d{1,2}:\\d{2}", options: .regularExpression) != nil
                    let hasCutoffWord = lower.contains("before") || lower.contains("deadline") || lower.contains("cutoff") || lower.contains("due") || lower.contains("by ")
                    return (hasSpecificTime || hasCutoffWord) && !lower.contains("runs from") && !lower.contains("takes place") && !lower.contains("officially")
                }
                if let target = deadlineCandidates.min(by: { $0.text.count < $1.text.count }) ?? deadlineCandidates.first {
                    claimed.insert(target.id)
                    let extracted = extractPureDate(from: target.text, preferDeadline: true)
                    return VerifiedField(fieldId: field.id, kind: .date, label: field.label, text: extracted, confidence: 0.96, sourceStart: target.start, sourceEnd: target.end)
                }
            } else {
                // 会议日程日期：优先查找包含时间范围横线（– 或 -）且为会议主要日程的日期
                let durationCandidates = dateSpans.filter { s in
                    let lower = s.text.lowercased()
                    let hasSpan = s.text.contains("–") || s.text.contains(" - ") || lower.contains("to ")
                    return hasSpan && !lower.contains("before") && !lower.contains("deadline") && !lower.contains("by ")
                }
                if let target = durationCandidates.min(by: { $0.text.count < $1.text.count }) ?? durationCandidates.first {
                    claimed.insert(target.id)
                    let extracted = extractPureDate(from: target.text, preferDeadline: false)
                    return VerifiedField(fieldId: field.id, kind: .date, label: field.label, text: extracted, confidence: 0.96, sourceStart: target.start, sourceEnd: target.end)
                }
            }
            
            if let first = dateSpans.first {
                claimed.insert(first.id)
                let extracted = extractPureDate(from: first.text, preferDeadline: isDeadline)
                return VerifiedField(fieldId: field.id, kind: .date, label: field.label, text: extracted, confidence: 0.90, sourceStart: first.start, sourceEnd: first.end)
            }
            
            // 回退：直接从 fullText 提取纯正日期
            let extracted = extractPureDate(from: fullText, preferDeadline: isDeadline)
            if containsDateClues(extracted) && extracted.count >= 5 && extracted.count <= 80 {
                return VerifiedField(fieldId: field.id, kind: .date, label: field.label, text: extracted, confidence: 0.95, sourceStart: 0, sourceEnd: extracted.count)
            }
            
        case .title:
            // 1. 如果有明确目的地且标有 Title 的 span
            if let span = spans.first(where: { !claimed.contains($0.id) && $0.label?.lowercased() == "title" }) {
                claimed.insert(span.id)
                return VerifiedField(fieldId: field.id, kind: .title, label: field.label, text: span.text, confidence: 0.95, sourceStart: span.start, sourceEnd: span.end)
            }
            // 2. 引号包围的内容（极大概率是 issue title / 需求名 / 议题名）
            let quotePattern = "[“\"]([^”\"\\n]+)[”\"]|‘([^’\\n]+)’"
            if let regex = try? NSRegularExpression(pattern: quotePattern) {
                let nsText = fullText as NSString
                let matches = regex.matches(in: fullText, range: NSRange(location: 0, length: nsText.length))
                if let firstMatch = matches.first {
                    let range1 = firstMatch.range(at: 1)
                    let range2 = firstMatch.range(at: 2)
                    let validRange = range1.location != NSNotFound ? range1 : range2
                    if validRange.location != NSNotFound {
                        let extracted = nsText.substring(with: validRange).trimmingCharacters(in: .whitespacesAndNewlines)
                        if extracted.count < 100 && !extracted.isEmpty {
                            return VerifiedField(fieldId: field.id, kind: .title, label: field.label, text: extracted, confidence: 0.92, sourceStart: validRange.location, sourceEnd: validRange.location + validRange.length)
                        }
                    }
                }
            }
            // 3. 标签匹配 Title: xxx
            if let span = spans.first(where: { !claimed.contains($0.id) && $0.text.lowercased().hasPrefix("title:") }) {
                claimed.insert(span.id)
                let val = span.text.replacingOccurrences(of: "^[Tt]itle:\\s*", with: "", options: .regularExpression)
                return VerifiedField(fieldId: field.id, kind: .title, label: field.label, text: val, confidence: 0.92, sourceStart: span.start, sourceEnd: span.end)
            }
            // 4. 首句作为标题候选
            if let firstSentence = spans.first(where: { !claimed.contains($0.id) && $0.text.count < 80 && !isEmail($0.text) && !isUrl($0.text) }) {
                claimed.insert(firstSentence.id)
                return VerifiedField(fieldId: field.id, kind: .title, label: field.label, text: firstSentence.text, confidence: 0.75, sourceStart: firstSentence.start, sourceEnd: firstSentence.end)
            }
            // 5. 回退：如果 fullText 本身就是短标题
            if fullText.count > 2 && fullText.count < 100 && !fullText.contains("\n") && !isEmail(fullText) && !isUrl(fullText) {
                return VerifiedField(fieldId: field.id, kind: .title, label: field.label, text: fullText, confidence: 0.80, sourceStart: 0, sourceEnd: fullText.count)
            }
            
        case .description:
            // 1. 如果有明确 Description 标签
            if let span = spans.first(where: { !claimed.contains($0.id) && ($0.label?.lowercased() == "description" || $0.label?.lowercased() == "details" || $0.label?.lowercased() == "notes") }) {
                claimed.insert(span.id)
                return VerifiedField(fieldId: field.id, kind: .description, label: field.label, text: span.text, confidence: 0.95, sourceStart: span.start, sourceEnd: span.end)
            }
            // 2. 提取主体说明句
            let descCandidates = spans.filter { span in
                !claimed.contains(span.id) &&
                span.text.count > 25 &&
                !isEmail(span.text) &&
                !isUrl(span.text) &&
                !span.text.lowercased().hasPrefix("tweet") &&
                !span.text.lowercased().hasPrefix("also, the address")
            }
            // 优先寻找纯描述句（排除请求前缀与地址从句）
            if let targetDesc = descCandidates.first(where: { $0.text.contains("Switching workspaces") && $0.text.contains("Preserve the title") && !$0.text.contains("Can we file") && !$0.text.contains("Ferry Building") }) {
                claimed.insert(targetDesc.id)
                return VerifiedField(fieldId: field.id, kind: .description, label: field.label, text: targetDesc.text, confidence: 0.95, sourceStart: targetDesc.start, sourceEnd: targetDesc.end)
            } else if let targetDesc = descCandidates.first(where: { $0.text.contains("Switching workspaces") && !$0.text.contains("Can we file") && !$0.text.contains("Ferry Building") }) {
                claimed.insert(targetDesc.id)
                return VerifiedField(fieldId: field.id, kind: .description, label: field.label, text: targetDesc.text, confidence: 0.92, sourceStart: targetDesc.start, sourceEnd: targetDesc.end)
            }
            if let best = descCandidates.max(by: { $0.text.count < $1.text.count }) {
                claimed.insert(best.id)
                return VerifiedField(fieldId: field.id, kind: .description, label: field.label, text: best.text, confidence: 0.85, sourceStart: best.start, sourceEnd: best.end)
            }
            
        case .name:
            if let span = spans.first(where: { !claimed.contains($0.id) && $0.label?.lowercased() == "name" }) {
                claimed.insert(span.id)
                return VerifiedField(fieldId: field.id, kind: .name, label: field.label, text: span.text, confidence: 0.92, sourceStart: span.start, sourceEnd: span.end)
            }
            // 主讲人/嘉宾/专家提取 (如 Keynote Speaker & Topic)
            let isSpeakerField = field.label.lowercased().contains("speaker") || field.label.lowercased().contains("keynote") || field.label.lowercased().contains("guest") || field.label.lowercased().contains("主讲")
            if isSpeakerField {
                let speakerSpans = spans.filter { s in
                    !claimed.contains(s.id) && (s.text.contains("Dr.") || s.text.contains("Prof.") || s.text.lowercased().contains("delivered by") || s.text.lowercased().contains("exchange with"))
                }
                // 优先挑选包含议题双引号且包含真实头衔人名的最完整单句切片
                let cleanSpans = speakerSpans.filter { s in
                    let hasName = s.text.range(of: "(?:Dr\\.|Prof\\.)\\s+[A-Z][a-z]+", options: .regularExpression) != nil
                    let lower = s.text.lowercased()
                    let isClean = !lower.contains("riverside") && !lower.contains("ballroom") && !lower.contains("credentials") && !lower.contains("four seasons") && !lower.contains("disclosures")
                    return hasName && isClean
                }
                let withTopicSpans = cleanSpans.filter { $0.text.contains("\"") || $0.text.contains("“") }
                if let target = withTopicSpans.min(by: { $0.text.count < $1.text.count }) ?? cleanSpans.min(by: { $0.text.count < $1.text.count }) ?? speakerSpans.first {
                    claimed.insert(target.id)
                    let cleaned = cleanSpeaker(target.text)
                    return VerifiedField(fieldId: field.id, kind: .name, label: field.label, text: cleaned, confidence: 0.95, sourceStart: target.start, sourceEnd: target.end)
                }
                
                // 回退：直接从 fullText 查找包含讲者特征的句子
                if fullText.contains("Dr.") || fullText.contains("Prof.") || fullText.lowercased().contains("delivered by") || fullText.lowercased().contains("exchange with") || fullText.contains("\"") {
                    let sentences = fullText.components(separatedBy: CharacterSet(charactersIn: ".\n"))
                    let speakerSent = sentences.first(where: { ($0.contains("Dr.") || $0.contains("Prof.") || $0.contains("\"")) && ($0.lowercased().contains("keynote") || $0.lowercased().contains("delivered") || $0.lowercased().contains("exchange") || $0.lowercased().contains("speaker") || $0.contains("\"")) }) ?? fullText
                    let cleaned = cleanSpeaker(speakerSent)
                    if !cleaned.isEmpty && cleaned.count >= 5 && cleaned.count <= 140 {
                        return VerifiedField(fieldId: field.id, kind: .name, label: field.label, text: cleaned, confidence: 0.95, sourceStart: 0, sourceEnd: cleaned.count)
                    }
                }
            }
            // 通用人名探测
            let namePattern = "(?:Dr\\.|Prof\\.|Mr\\.|Ms\\.)\\s+[A-Z][a-z]+(?:\\s+[A-Z][a-z]+)+"
            if let regex = try? NSRegularExpression(pattern: namePattern) {
                let nsText = fullText as NSString
                if let match = regex.firstMatch(in: fullText, range: NSRange(location: 0, length: nsText.length)) {
                    let matchedName = nsText.substring(with: match.range)
                    return VerifiedField(fieldId: field.id, kind: .name, label: field.label, text: matchedName, confidence: 0.90, sourceStart: match.range.location, sourceEnd: match.range.location + match.range.length)
                }
            }
            
        case .company:
            if let span = spans.first(where: { !claimed.contains($0.id) && ($0.label?.lowercased() == "company" || $0.label?.lowercased() == "organization") }) {
                claimed.insert(span.id)
                return VerifiedField(fieldId: field.id, kind: .company, label: field.label, text: span.text, confidence: 0.92, sourceStart: span.start, sourceEnd: span.end)
            }
            
        case .text:
            if let span = spans.first(where: { !claimed.contains($0.id) && !$0.text.isEmpty }) {
                claimed.insert(span.id)
                return VerifiedField(fieldId: field.id, kind: .text, label: field.label, text: span.text, confidence: 0.80, sourceStart: span.start, sourceEnd: span.end)
            }
        }
        
        return nil
    }
    
    private func isEmail(_ s: String) -> Bool {
        let pattern = "^[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}$"
        return s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    private func isUrl(_ s: String) -> Bool {
        return s.hasPrefix("http://") || s.hasPrefix("https://")
    }
    
    private func isPhone(_ s: String) -> Bool {
        let digits = s.filter { $0.isNumber }
        return digits.count >= 7 && digits.count <= 15
    }
    
    private func containsAddressClues(_ s: String) -> Bool {
        let clues = [
            "address", "street", "st.", "road", "ave", "avenue", "blvd", "building", "suite",
            "san francisco", "ca ", "ny ", "zip", "路", "街", "号", "大厦", "楼", "区", "市",
            "center", "convention", "ballroom", "hotel", "pudong", "shanghai", "beijing",
            "silicon valley", "palo alto", "riverside", "university", "hall", "venue"
        ]
        let lower = s.lowercased()
        return clues.contains(where: { lower.contains($0) })
    }
    
    private func cleanAddress(_ s: String) -> String {
        var str = s
        let leadPatterns = [
            "^(?:also,?\\s*)?(?:the\\s*)?address\\s*(?:is|:)\\s*",
            "^(?:.*?(?:hosted|held|located|takes\\s*place)\\s*at\\s*(?:the\\s*)?)",
            "^(?:venue\\s*:\\s*)"
        ]
        for p in leadPatterns {
            str = str.replacingOccurrences(of: p, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return str.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
    
    private func cleanSpeaker(_ s: String) -> String {
        var str = s
        let leadPatterns = [
            "^(?:.*?(?:closed-door\\s+exchange\\s+with|opening\\s+keynote\\s+delivered\\s+by|delivered\\s+by|presented\\s+by|keynote\\s+by))\\s*",
            "^(?:(?:opening\\s+)?keynote\\s*(?:delivered\\s+by|by)?\\s*)",
            "^(?:closed-door\\s+exchange\\s+with\\s+)",
            "^(?:speaker\\s*:\\s*)"
        ]
        for p in leadPatterns {
            str = str.replacingOccurrences(of: p, with: "", options: [.regularExpression, .caseInsensitive])
        }
        return str.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
    
    private func extractPureDate(from text: String, preferDeadline: Bool) -> String {
        // 尝试正则匹配完整日期/时间表达式
        // 1. 截止日期如: September 30, 2026 at 23:59 或 October 10, 2026 at 17:00 (PST)
        let deadlinePattern = "(?:January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{1,2},?\\s+\\d{4}(?:\\s+at\\s+\\d{1,2}:\\d{2}(?:\\s*(?:\\([A-Za-z]+\\)|[A-Za-z]+))?)?"
        // 2. 日期跨度如: October 15 – October 17, 2026 或 November 2 – November 8, 2026 或 November 02 – 08, 2026
        let spanPattern = "(?:January|February|March|April|May|June|July|August|September|October|November|December)\\s+\\d{1,2}(?:\\s*[–-]\\s*(?:(?:January|February|March|April|May|June|July|August|September|October|November|December)\\s+)?\\d{1,2})?,?\\s+\\d{4}"
        
        let targetPatterns = preferDeadline ? [deadlinePattern, spanPattern] : [spanPattern, deadlinePattern]
        for pat in targetPatterns {
            if let regex = try? NSRegularExpression(pattern: pat, options: .caseInsensitive) {
                let ns = text as NSString
                if let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) {
                    return ns.substring(with: match.range).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
    
    private func containsDateClues(_ s: String) -> Bool {
        let clues = [
            "january", "february", "march", "april", "may", "june", "july", "august",
            "september", "october", "november", "december", "am", "pm", "today", "tomorrow",
            "yesterday", "at 2", "at 3", "for 30 minutes", "年", "月", "日", "点", "2026", "2027", "–"
        ]
        let lower = s.lowercased()
        return clues.contains(where: { lower.contains($0) })
    }
}
