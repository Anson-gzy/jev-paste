import Foundation

/// 候选文本切片，严格保留原文本中的字符偏移 (start, end)
public struct CandidateSpan: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let start: Int
    public let end: Int
    public let text: String
    public let destination: String?
    public let label: String?
    
    public init(id: String, start: Int, end: Int, text: String, destination: String? = nil, label: String? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
        self.destination = destination
        self.label = label
    }
}

/// 支持的字段类型
public enum FieldKind: String, Codable, Sendable, CaseIterable {
    case title = "title"
    case description = "description"
    case text = "text"
    case email = "email"
    case tel = "tel"
    case url = "url"
    case date = "date"
    case address = "address"
    case name = "name"
    case company = "company"
    
    public var iconName: String {
        switch self {
        case .title: return "character.cursor.ibeam"
        case .description: return "text.alignleft"
        case .text: return "text.bubble"
        case .email: return "envelope"
        case .tel: return "phone"
        case .url: return "link"
        case .date: return "calendar"
        case .address: return "mappin.and.ellipse"
        case .name: return "person"
        case .company: return "building.2"
        }
    }
    
    public var displayName: String {
        switch self {
        case .title: return "Title / 标题"
        case .description: return "Description / 详情"
        case .text: return "Text / 文本"
        case .email: return "Email / 邮箱"
        case .tel: return "Phone / 电话"
        case .url: return "URL / 链接"
        case .date: return "Date / 时间"
        case .address: return "Address / 地址"
        case .name: return "Name / 姓名"
        case .company: return "Company / 公司"
        }
    }
}

/// 目标表单单个字段
public struct FormField: Identifiable, Codable, Sendable {
    public let id: String
    public let kind: FieldKind
    public let label: String
    public var focused: Bool
    public var occupied: Bool
    
    public init(id: String, kind: FieldKind, label: String, focused: Bool = false, occupied: Bool = false) {
        self.id = id
        self.kind = kind
        self.label = label
        self.focused = focused
        self.occupied = occupied
    }
}

/// 目标表单整体上下文
public struct FormContext: Codable, Sendable {
    public let heading: String
    public let fields: [FormField]
    
    public init(heading: String, fields: [FormField]) {
        self.heading = heading
        self.fields = fields
    }
}

/// 最终匹配/提取确认的字段
public struct VerifiedField: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let fieldId: String
    public let kind: FieldKind
    public let label: String
    public var text: String
    public let confidence: Double
    public let sourceStart: Int
    public let sourceEnd: Int
    public let isAiVerified: Bool
    
    public init(id: String = UUID().uuidString,
                fieldId: String,
                kind: FieldKind,
                label: String,
                text: String,
                confidence: Double,
                sourceStart: Int = 0,
                sourceEnd: Int = 0,
                isAiVerified: Bool = false) {
        self.id = id
        self.fieldId = fieldId
        self.kind = kind
        self.label = label
        self.text = text
        self.confidence = confidence
        self.sourceStart = sourceStart
        self.sourceEnd = sourceEnd
        self.isAiVerified = isAiVerified
    }
}

/// 常见应用预设模板
public enum FormPreset: String, CaseIterable, Identifiable, Sendable {
    case smartDetect = "Auto / 智能探测"
    case issueTracker = "Issue / 任务工单"
    case calendarEvent = "Calendar / 日历日程"
    case contact = "Contact / 联系人"
    case socialPost = "Social / 社交动态"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .smartDetect: return "sparkles"
        case .issueTracker: return "checklist"
        case .calendarEvent: return "calendar.badge.clock"
        case .contact: return "person.crop.circle"
        case .socialPost: return "bubble.left.and.bubble.right"
        }
    }
    
    public var context: FormContext {
        switch self {
        case .smartDetect:
            return FormContext(heading: "Smart Form", fields: [
                FormField(id: "f0", kind: .title, label: "Title"),
                FormField(id: "f1", kind: .description, label: "Description"),
                FormField(id: "f2", kind: .email, label: "Email"),
                FormField(id: "f3", kind: .tel, label: "Phone"),
                FormField(id: "f4", kind: .url, label: "URL"),
                FormField(id: "f5", kind: .address, label: "Address")
            ])
        case .issueTracker:
            return FormContext(heading: "Linear / GitHub Issue", fields: [
                FormField(id: "f0", kind: .title, label: "Issue Title", focused: true),
                FormField(id: "f1", kind: .description, label: "Description")
            ])
        case .calendarEvent:
            return FormContext(heading: "Calendar Event", fields: [
                FormField(id: "f0", kind: .title, label: "Event Title", focused: true),
                FormField(id: "f1", kind: .date, label: "Date & Time"),
                FormField(id: "f2", kind: .address, label: "Location"),
                FormField(id: "f3", kind: .description, label: "Notes")
            ])
        case .contact:
            return FormContext(heading: "Contact Form", fields: [
                FormField(id: "f0", kind: .name, label: "Full Name", focused: true),
                FormField(id: "f1", kind: .company, label: "Company"),
                FormField(id: "f2", kind: .email, label: "Email"),
                FormField(id: "f3", kind: .tel, label: "Phone"),
                FormField(id: "f4", kind: .address, label: "Address")
            ])
        case .socialPost:
            return FormContext(heading: "Tweet / Post", fields: [
                FormField(id: "f0", kind: .text, label: "Post Content", focused: true)
            ])
        }
    }
}

/// 历史剪贴板保留期限配置
public enum HistoryRetentionPeriod: String, CaseIterable, Identifiable, Codable, Sendable {
    case hour1 = "1hour"
    case hour12 = "12hours"
    case day1 = "1day"       // 默认保留 1 天
    case day3 = "3days"
    case day7 = "7days"
    case day30 = "30days"
    case forever = "forever"
    
    public var id: String { rawValue }
    
    /// 过期秒数（nil 表示永久保留）
    public var expirationSeconds: TimeInterval? {
        switch self {
        case .hour1: return 3600
        case .hour12: return 43200
        case .day1: return 86400
        case .day3: return 86400 * 3
        case .day7: return 86400 * 7
        case .day30: return 86400 * 30
        case .forever: return nil
        }
    }
    
    @MainActor
    public var displayName: String {
        switch self {
        case .hour1: return L("set.history.1hour")
        case .hour12: return L("set.history.12hours")
        case .day1: return L("set.history.1day")
        case .day3: return L("set.history.3days")
        case .day7: return L("set.history.7days")
        case .day30: return L("set.history.30days")
        case .forever: return L("set.history.forever")
        }
    }
}

/// 单条历史剪贴板记录
public struct ClipboardHistoryItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let text: String
    public var timestamp: Date
    public let charCount: Int
    
    public init(id: String = UUID().uuidString, text: String, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.charCount = text.count
    }
}

/// 经过时间衰减加权计算的建议打分对象
public struct ScoredSuggestion: Identifiable, Sendable {
    public var id: String { text }
    public let text: String
    public let kind: FieldKind
    public let sourceTimestamp: Date
    public let baseConfidence: Double
    public let timeWeight: Double
    public let finalScore: Double
    
    public init(text: String, kind: FieldKind, sourceTimestamp: Date, baseConfidence: Double, timeWeight: Double, finalScore: Double) {
        self.text = text
        self.kind = kind
        self.sourceTimestamp = sourceTimestamp
        self.baseConfidence = baseConfidence
        self.timeWeight = timeWeight
        self.finalScore = finalScore
    }
}
