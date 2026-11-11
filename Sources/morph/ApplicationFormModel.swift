import Cocoa
import SwiftUI
import Combine

// MARK: - Field Category
public enum FormFieldCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case personal = "Personal"
    case contact = "Contact"
    case experience = "Experience"
    case question = "Questions"
    case custom = "Custom"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .personal: return "person.fill"
        case .contact: return "envelope.fill"
        case .experience: return "briefcase.fill"
        case .question: return "questionmark.bubble.fill"
        case .custom: return "text.alignleft"
        }
    }
}

// MARK: - Question Format
public enum QuestionFormat: String, Codable, CaseIterable, Sendable {
    case shortAnswer = "shortAnswer"
    case paragraph = "paragraph"
    case multipleChoice = "multipleChoice"
    case checkboxes = "checkboxes"
    case dropdown = "dropdown"
    case linearScale = "linearScale"
    case date = "date"
    case time = "time"
    case fileUpload = "fileUpload"
    case grid = "grid"
    case info = "info"
    case section = "section"
    case unknown = "unknown"
    
    public init(fromString string: String) {
        let s = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch s {
        case "shortanswer", "short_answer", "short", "text", "short question":
            self = .shortAnswer
        case "paragraph", "textarea", "long", "long_answer", "long question":
            self = .paragraph
        case "multiplechoice", "multiple_choice", "radio", "choice", "multiple choice":
            self = .multipleChoice
        case "checkboxes", "checkbox", "check":
            self = .checkboxes
        case "dropdown", "select", "listbox", "combobox":
            self = .dropdown
        case "linearscale", "scale", "rating", "range":
            self = .linearScale
        case "date":
            self = .date
        case "time":
            self = .time
        case "fileupload", "file_upload", "file":
            self = .fileUpload
        case "grid":
            self = .grid
        case "info", "header", "title":
            self = .info
        case "section", "pagebreak":
            self = .section
        default:
            if let direct = QuestionFormat(rawValue: string) {
                self = direct
            } else {
                self = .unknown
            }
        }
    }
    
    public init(fromRawType rawType: Int) {
        switch rawType {
        case 0: self = .shortAnswer
        case 1: self = .paragraph
        case 2: self = .multipleChoice
        case 3: self = .dropdown
        case 4: self = .checkboxes
        case 5: self = .linearScale
        case 6, 11: self = .info
        case 7: self = .grid
        case 8: self = .section
        case 9: self = .date
        case 10: self = .time
        case 13: self = .fileUpload
        default: self = .shortAnswer
        }
    }
    
    public var displayName: String {
        switch self {
        case .shortAnswer: return "Short Question"
        case .paragraph: return "Paragraph"
        case .multipleChoice: return "Multiple Choice"
        case .checkboxes: return "Checkboxes"
        case .dropdown: return "Dropdown"
        case .linearScale: return "Linear Scale"
        case .date: return "Date"
        case .time: return "Time"
        case .fileUpload: return "File Upload"
        case .grid: return "Grid"
        case .info: return "Description"
        case .section: return "Section"
        case .unknown: return "General Question"
        }
    }
    
    public var badgeText: String {
        switch self {
        case .shortAnswer: return "SHORT"
        case .paragraph: return "PARA"
        case .multipleChoice: return "CHOICE"
        case .checkboxes: return "CHECK"
        case .dropdown: return "DROP"
        case .linearScale: return "SCALE"
        case .date: return "DATE"
        case .time: return "TIME"
        case .fileUpload: return "FILE"
        case .grid: return "GRID"
        case .info, .section: return "INFO"
        case .unknown: return "SHORT"
        }
    }
    
    public var iconName: String {
        switch self {
        case .shortAnswer: return "text.cursor"
        case .paragraph: return "text.alignleft"
        case .multipleChoice: return "smallcircle.filled.circle"
        case .checkboxes: return "checkmark.square"
        case .dropdown: return "chevron.down.circle"
        case .linearScale: return "slider.horizontal.3"
        case .date: return "calendar"
        case .time: return "clock"
        case .fileUpload: return "arrow.up.doc"
        case .grid: return "circle.grid.2x2"
        case .info, .section: return "info.circle"
        case .unknown: return "text.cursor"
        }
    }
    
    public var isShortQuestion: Bool { self == .shortAnswer }
    public var isMultipleChoice: Bool { self == .multipleChoice }
    public var isParagraph: Bool { self == .paragraph }
    public var isCheckboxes: Bool { self == .checkboxes }
    public var isDropdown: Bool { self == .dropdown }
    public var isSelection: Bool { self == .multipleChoice || self == .checkboxes || self == .dropdown || self == .linearScale }
    public var isTextEntry: Bool { !isSelection && self != .info && self != .section && self != .grid && self != .fileUpload }
}

// MARK: - Extracted Input Item Snapshot
public struct ExtractedInputItem: Sendable, Equatable {
    public var label: String
    public var value: String
    public var questionType: String?
    public var options: [String]
    public var isRequired: Bool
    
    public init(label: String, value: String, questionType: String? = nil, options: [String] = [], isRequired: Bool = false) {
        self.label = label
        self.value = value
        self.questionType = questionType
        self.options = options
        self.isRequired = isRequired
    }
    
    public var format: QuestionFormat {
        QuestionFormat(fromString: questionType ?? "")
    }
}

// MARK: - Input Field
public struct FormInputField: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var label: String
    public var value: String
    public var category: FormFieldCategory
    public var timestamp: Date
    public var questionDescription: String
    public var options: [String]
    public var questionType: String
    public var isRequired: Bool
    public var entryKey: String?
    
    public var format: QuestionFormat {
        QuestionFormat(fromString: questionType)
    }
    
    public var isShortQuestion: Bool { format.isShortQuestion }
    public var isMultipleChoice: Bool { format.isMultipleChoice }
    public var isParagraph: Bool { format.isParagraph }
    public var isCheckboxes: Bool { format.isCheckboxes }
    public var isDropdown: Bool { format.isDropdown }
    public var isSelection: Bool { format.isSelection }
    
    public init(
        id: UUID = UUID(),
        label: String,
        value: String,
        category: FormFieldCategory = .custom,
        timestamp: Date = Date(),
        questionDescription: String = "",
        options: [String] = [],
        questionType: String = "shortAnswer",
        isRequired: Bool = false,
        entryKey: String? = nil
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.category = category
        self.timestamp = timestamp
        self.questionDescription = questionDescription
        self.options = options
        self.questionType = questionType
        self.isRequired = isRequired
        self.entryKey = entryKey
    }
    
    public var isAnswered: Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public var isActionableQuestion: Bool {
        if questionType == "info" || questionType == "section" || questionType == "pageBreak" || questionType == "header" || questionType == "title" {
            return false
        }
        if entryKey == nil && (questionType == "text" || questionType == "info" || questionType == "section") {
            return false
        }
        return true
    }
    
    public var wordCount: Int {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        return trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
}

// MARK: - Email Delivery Status
public enum EmailDeliveryStatus: Equatable, Sendable, Codable {
    case idle
    case sending
    case sent(Date)
    case failed(String)
    
    public var isSent: Bool {
        if case .sent = self { return true }
        return false
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, date, message
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "idle": self = .idle
        case "sending": self = .sending
        case "sent":
            let date = try container.decode(Date.self, forKey: .date)
            self = .sent(date)
        case "failed":
            let msg = try container.decode(String.self, forKey: .message)
            self = .failed(msg)
        default:
            self = .idle
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .idle:
            try container.encode("idle", forKey: .type)
        case .sending:
            try container.encode("sending", forKey: .type)
        case .sent(let date):
            try container.encode("sent", forKey: .type)
            try container.encode(date, forKey: .date)
        case .failed(let msg):
            try container.encode("failed", forKey: .type)
            try container.encode(msg, forKey: .message)
        }
    }
}

// MARK: - Application Form Session
public struct ApplicationFormSession: Identifiable, Equatable, Sendable, Codable {
    public var id: UUID
    public var formTitle: String
    public var sourceAppName: String
    public var sourceURL: String?
    public var recipientEmail: String
    public var startedAt: Date
    public var completedAt: Date?
    public var fields: [FormInputField]
    public var isSubmitted: Bool
    public var emailDeliveryStatus: EmailDeliveryStatus
    public var lastDispatchedAt: Date?
    public var formDescription: String
    public var activeFieldIndex: Int
    public var isClosedOrExpired: Bool
    public var closedReason: String?
    
    public init(
        id: UUID = UUID(),
        formTitle: String,
        sourceAppName: String,
        sourceURL: String? = nil,
        recipientEmail: String,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        fields: [FormInputField] = [],
        isSubmitted: Bool = false,
        emailDeliveryStatus: EmailDeliveryStatus = .idle,
        lastDispatchedAt: Date? = nil,
        formDescription: String = "",
        activeFieldIndex: Int = 0,
        isClosedOrExpired: Bool = false,
        closedReason: String? = nil
    ) {
        self.id = id
        self.formTitle = formTitle
        self.sourceAppName = sourceAppName
        self.sourceURL = sourceURL
        self.recipientEmail = recipientEmail
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.fields = fields
        self.isSubmitted = isSubmitted
        self.emailDeliveryStatus = emailDeliveryStatus
        self.lastDispatchedAt = lastDispatchedAt
        self.formDescription = formDescription
        self.activeFieldIndex = activeFieldIndex
        self.isClosedOrExpired = isClosedOrExpired
        self.closedReason = closedReason
    }
    
    enum CodingKeys: String, CodingKey {
        case id, formTitle, sourceAppName, sourceURL, recipientEmail, startedAt, completedAt
        case fields, isSubmitted, emailDeliveryStatus, lastDispatchedAt, formDescription
        case activeFieldIndex, isClosedOrExpired, closedReason
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.formTitle = try container.decodeIfPresent(String.self, forKey: .formTitle) ?? "Application Form"
        self.sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName) ?? "Web Browser"
        self.sourceURL = try container.decodeIfPresent(String.self, forKey: .sourceURL)
        self.recipientEmail = try container.decodeIfPresent(String.self, forKey: .recipientEmail) ?? ""
        self.startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        self.completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        self.fields = try container.decodeIfPresent([FormInputField].self, forKey: .fields) ?? []
        self.isSubmitted = try container.decodeIfPresent(Bool.self, forKey: .isSubmitted) ?? false
        self.emailDeliveryStatus = try container.decodeIfPresent(EmailDeliveryStatus.self, forKey: .emailDeliveryStatus) ?? .idle
        self.lastDispatchedAt = try container.decodeIfPresent(Date.self, forKey: .lastDispatchedAt)
        self.formDescription = try container.decodeIfPresent(String.self, forKey: .formDescription) ?? ""
        self.activeFieldIndex = try container.decodeIfPresent(Int.self, forKey: .activeFieldIndex) ?? 0
        self.isClosedOrExpired = try container.decodeIfPresent(Bool.self, forKey: .isClosedOrExpired) ?? false
        self.closedReason = try container.decodeIfPresent(String.self, forKey: .closedReason)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(formTitle, forKey: .formTitle)
        try container.encode(sourceAppName, forKey: .sourceAppName)
        try container.encodeIfPresent(sourceURL, forKey: .sourceURL)
        try container.encode(recipientEmail, forKey: .recipientEmail)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(fields, forKey: .fields)
        try container.encode(isSubmitted, forKey: .isSubmitted)
        try container.encode(emailDeliveryStatus, forKey: .emailDeliveryStatus)
        try container.encodeIfPresent(lastDispatchedAt, forKey: .lastDispatchedAt)
        try container.encode(formDescription, forKey: .formDescription)
        try container.encode(activeFieldIndex, forKey: .activeFieldIndex)
        try container.encode(isClosedOrExpired, forKey: .isClosedOrExpired)
        try container.encodeIfPresent(closedReason, forKey: .closedReason)
    }
    
    public var answeredCount: Int {
        fields.filter { $0.isAnswered && $0.isActionableQuestion }.count
    }
    
    public var totalQuestions: Int {
        let actionable = fields.filter { $0.isActionableQuestion }.count
        return actionable > 0 ? actionable : fields.count
    }
    
    public var requiredFields: [FormInputField] {
        fields.filter { $0.isRequired && $0.isActionableQuestion }
    }
    
    public var requiredCount: Int {
        requiredFields.count
    }
    
    public var answeredRequiredCount: Int {
        requiredFields.filter { $0.isAnswered }.count
    }
    
    public var hasRequiredFields: Bool {
        requiredCount > 0
    }
    
    public var completionPercentage: Double {
        guard totalQuestions > 0 else { return 0.0 }
        return (Double(answeredCount) / Double(totalQuestions)) * 100.0
    }
    
    public var formattedSummary: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let dateStr = formatter.string(from: startedAt)
        
        var lines: [String] = []
        lines.append("# Application Response: \(formTitle)")
        lines.append("**Source:** \(sourceAppName)")
        if let url = sourceURL, !url.isEmpty {
            lines.append("**URL:** \(url)")
        }
        lines.append("**Captured:** \(dateStr)")
        lines.append("**Recipient Copy:** \(recipientEmail)")
        if !formDescription.isEmpty {
            lines.append("")
            lines.append("> \(formDescription)")
        }
        lines.append("")
        lines.append("---")
        lines.append("## Captured Input Fields (\(answeredCount)/\(totalQuestions) Answered)")
        lines.append("")
        
        let actionable = fields.filter { $0.isActionableQuestion }
        let questionsToRender = actionable.isEmpty ? fields : actionable
        
        if questionsToRender.isEmpty {
            lines.append("*(No fields captured)*")
        } else {
            for (idx, field) in questionsToRender.enumerated() {
                let reqBadge = field.isRequired ? " *(Required)*" : ""
                lines.append("### \(idx + 1). \(field.label)\(reqBadge)")
                if !field.questionDescription.isEmpty {
                    lines.append("*\(field.questionDescription)*")
                }
                if !field.value.isEmpty {
                    if field.value.contains("\n") || field.wordCount >= 10 {
                        lines.append(field.value)
                        lines.append("*(Word count: \(field.wordCount))*")
                    } else {
                        lines.append("> \(field.value)")
                    }
                } else {
                    lines.append("*(Not answered yet)*")
                }
                lines.append("")
            }
        }
        lines.append("---")
        lines.append("*Captured automatically by Morph Context Engine • Form Copilot*")
        return lines.joined(separator: "\n")
    }
    
    public var professionalHTMLSummary: String {
        let cleanTitle = formTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Application Form"
            : formTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let escapedTitle = cleanTitle
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        
        let actionable = fields.filter { $0.isActionableQuestion }
        let questionsToRender = actionable.isEmpty ? fields : actionable
        
        var rowsHTML = ""
        for field in questionsToRender {
            let reqHTML = field.isRequired ? "<span style=\"color:#ef4444;\"> *</span>" : ""
            let escapedLabel = field.label
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            let descHTML = field.questionDescription.isEmpty ? "" : "<div style=\"font-size:13px;color:#6b7280;margin-top:2px;font-style:italic;\">\(field.questionDescription.replacingOccurrences(of: "<", with: "&lt;"))</div>"
            
            let valHTML: String
            if !field.value.isEmpty {
                let escapedVal = field.value
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                    .replacingOccurrences(of: "\n", with: "<br/>")
                valHTML = "<div style=\"font-size:15px;color:#111827;margin-top:4px;white-space:pre-wrap;line-height:1.5;\">\(escapedVal)</div>"
            } else {
                valHTML = "<div style=\"font-size:14px;color:#9ca3af;margin-top:4px;font-style:italic;\">— (Not answered)</div>"
            }
            
            rowsHTML += """
            <div style=\"margin-bottom:20px;\">
                <div style=\"font-size:14px;font-weight:600;color:#374151;\">\(escapedLabel)\(reqHTML)</div>
                \(descHTML)
                \(valHTML)
            </div>
            """
        }
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset=\"utf-8\"/>
        <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\"/>
        <title>\(escapedTitle)</title>
        </head>
        <body style=\"margin:0;padding:24px 16px;background-color:#ffffff;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;-webkit-font-smoothing:antialiased;color:#1f2937;\">
            <div style=\"max-width:600px;margin:0 auto;\">
                <h2 style=\"margin:0 0 16px 0;font-size:22px;font-weight:700;color:#111827;line-height:1.3;\">\(escapedTitle)</h2>
                
                <p style=\"margin:0 0 24px 0;font-size:15px;color:#4b5563;line-height:1.5;\">
                    Here is a copy of your responses:
                </p>
                
                <div style=\"margin-bottom:32px;\">
                    \(rowsHTML)
                </div>
                
                <div style=\"margin-top:40px;padding-top:16px;border-top:1px solid #e5e7eb;font-size:12px;color:#9ca3af;\">
                    Powered by Morph
                </div>
            </div>
        </body>
        </html>
        """
    }
}

// MARK: - Saved Form Copy Record (Glass Island Copies)
public struct SavedFormCopyRecord: Identifiable, Equatable, Sendable, Codable {
    public var id: String
    public var sessionId: String?
    public var formTitle: String
    public var savedAt: Date
    public var answers: [String: String]
    public var sourceURL: String?
    public var sourceAppName: String
    
    public init(
        id: String = UUID().uuidString,
        sessionId: String? = nil,
        formTitle: String,
        savedAt: Date = Date(),
        answers: [String: String] = [:],
        sourceURL: String? = nil,
        sourceAppName: String = "Web Browser"
    ) {
        self.id = id
        self.sessionId = sessionId
        self.formTitle = formTitle
        self.savedAt = savedAt
        self.answers = answers
        self.sourceURL = sourceURL
        self.sourceAppName = sourceAppName
    }
    
    public var previewSummary: String {
        let nonEmpty = answers.filter { !$0.value.isEmpty && $0.value != "—" }
        if nonEmpty.isEmpty { return "Empty" }
        return nonEmpty.prefix(2).map { "\($0.value)" }.joined(separator: " · ")
    }
    
    public var formattedClipboardText: String {
        var lines: [String] = []
        lines.append("\(formTitle)")
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        lines.append("Saved \(formatter.string(from: savedAt))")
        lines.append("---")
        for (q, a) in answers.sorted(by: { $0.key < $1.key }) {
            lines.append("\(q): \(a)")
        }
        return lines.joined(separator: "\n")
    }
    
    public var answersJSONString: String {
        if let data = try? JSONSerialization.data(withJSONObject: answers),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
}

// MARK: - Adaptive Profile Entry (Learned Across Saved Copies & User Edits)
public struct AdaptiveProfileEntry: Identifiable, Equatable, Codable, Sendable {
    public var id: String
    public var canonicalKey: String
    public var question: String
    public var answer: String
    public var frequency: Int
    public var aliases: [String]
    public var lastSeenAt: Date
    public var isUserEdited: Bool
    public var isCustom: Bool
    
    public init(
        id: String,
        canonicalKey: String,
        question: String,
        answer: String,
        frequency: Int,
        aliases: [String] = [],
        lastSeenAt: Date = Date(),
        isUserEdited: Bool = false,
        isCustom: Bool = false
    ) {
        self.id = id
        self.canonicalKey = canonicalKey
        self.question = question
        self.answer = answer
        self.frequency = frequency
        self.aliases = aliases
        self.lastSeenAt = lastSeenAt
        self.isUserEdited = isUserEdited
        self.isCustom = isCustom
    }
}

// MARK: - Browser Engine & User Browser Profile Personalization
public enum BrowserEngineFamily: String, CaseIterable, Codable, Sendable {
    case polar = "Polar"
    case safari = "Safari"
    case chromium = "Chromium" // Chrome, Brave, Edge, Arc, Opera, Vivaldi
    case gecko = "Gecko" // Firefox, Zen
    case webkit = "WebKit" // Orion, WebKit shells
    case unknown = "Browser"
}

public struct UserBrowserProfile: Equatable, Codable, Sendable {
    public let displayName: String
    public let bundleIdentifier: String
    public let appURL: URL?
    public let family: BrowserEngineFamily
    public let isSystemDefault: Bool
    
    public init(
        displayName: String,
        bundleIdentifier: String,
        appURL: URL? = nil,
        family: BrowserEngineFamily,
        isSystemDefault: Bool = false
    ) {
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.appURL = appURL
        self.family = family
        self.isSystemDefault = isSystemDefault
    }
    
    public static var defaultFallback: UserBrowserProfile {
        UserBrowserProfile(
            displayName: "Polar",
            bundleIdentifier: "com.polar.browser",
            appURL: nil,
            family: .polar,
            isSystemDefault: true
        )
    }
}

public final class PersonalizedBrowserDetector: @unchecked Sendable {
    public static let shared = PersonalizedBrowserDetector()
    
    public init() {}
    
    /// Detects the user's primary/default web browser via macOS LaunchServices
    public static func detectDefaultBrowser() -> UserBrowserProfile {
        if let url = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://")!) {
            let bundleID = Bundle(url: url)?.bundleIdentifier ?? ""
            let displayName = FileManager.default.displayName(atPath: url.path)
            let family = engineFamily(for: bundleID, name: displayName)
            return UserBrowserProfile(
                displayName: displayName,
                bundleIdentifier: bundleID,
                appURL: url,
                family: family,
                isSystemDefault: true
            )
        }
        return .defaultFallback
    }
    
    /// Maps a bundle identifier or application name to its corresponding browser engine family
    public static func engineFamily(for bundleID: String, name: String) -> BrowserEngineFamily {
        let b = bundleID.lowercased()
        let n = name.lowercased()
        if DefaultApplicationFormDetector.isNonFormApplication(bundleID: b, appName: n) {
            return .unknown
        }
        if b.contains("polar") || n.contains("polar") {
            return .polar
        } else if b.contains("safari") || n.contains("safari") {
            return .safari
        } else if b.contains("chrome") || b.contains("chromium") || b.contains("brave") || b.contains("edge") || b.contains("arc") || b.contains("opera") || b.contains("vivaldi") || b.contains("comet") || b.contains("sigmaos") || b.contains("wavebox") || n.contains("chrome") || n.contains("chromium") || n.contains("brave") || n.contains("edge") || n.contains("arc") || n.contains("opera") || n.contains("vivaldi") || n.contains("comet") || n.contains("sigmaos") {
            return .chromium
        } else if b.contains("firefox") || b.contains("zen") || b.contains("mozilla") || b.contains("floorp") || b.contains("waterfox") || b.contains("librewolf") || b.contains("tor") || n.contains("firefox") || n.contains("zen") || n.contains("floorp") || n.contains("waterfox") || n.contains("librewolf") || n.contains("tor") {
            return .gecko
        } else if b.contains("orion") || b.contains("kagi") || b.contains("duckduckgo") || b.contains("webkit") || n.contains("orion") || n.contains("duckduckgo") {
            return .webkit
        } else {
            return .unknown
        }
    }
    
    /// Returns all currently running browsers on the system, prioritizing the user's default browser first
    public static func rankedRunningBrowsers() -> [NSRunningApplication] {
        let running = NSWorkspace.shared.runningApplications.filter { app in
            !app.isTerminated &&
            kill(app.processIdentifier, 0) == 0 &&
            app.activationPolicy == .regular &&
            DefaultApplicationFormDetector.isBrowserApplication(app)
        }
        let defaultProfile = detectDefaultBrowser()
        return running.sorted { a, b in
            let aBundle = (a.bundleIdentifier ?? "").lowercased()
            let bBundle = (b.bundleIdentifier ?? "").lowercased()
            let aName = (a.localizedName ?? "").lowercased()
            let bName = (b.localizedName ?? "").lowercased()
            let aMatchesDefault = aBundle == defaultProfile.bundleIdentifier.lowercased() || aName == defaultProfile.displayName.lowercased()
            let bMatchesDefault = bBundle == defaultProfile.bundleIdentifier.lowercased() || bName == defaultProfile.displayName.lowercased()
            if aMatchesDefault && !bMatchesDefault { return true }
            if !aMatchesDefault && bMatchesDefault { return false }
            return a.isActive && !b.isActive
        }
    }
}

// MARK: - Detector Protocols
public struct FormDetectionResult: Sendable, Equatable {
    public var isDetected: Bool
    public var title: String?
    public var appName: String?
    public var url: String?
    public var browserFamily: BrowserEngineFamily?
    public var screenIndex: Int?
    public var screenName: String?
    
    public init(
        isDetected: Bool,
        title: String? = nil,
        appName: String? = nil,
        url: String? = nil,
        browserFamily: BrowserEngineFamily? = nil,
        screenIndex: Int? = nil,
        screenName: String? = nil
    ) {
        self.isDetected = isDetected
        self.title = title
        self.appName = appName
        self.url = url
        self.browserFamily = browserFamily
        self.screenIndex = screenIndex
        self.screenName = screenName
    }
}

public protocol ApplicationFormDetectorProtocol: Sendable {
    func detectActiveApplicationForm() -> FormDetectionResult
}

// MARK: - Form Platform Category & Definition
public enum FormPlatformType: String, CaseIterable, Sendable {
    case googleForms = "Google Forms"
    case microsoftForms = "Microsoft Forms"
    case typeform = "Typeform"
    case tally = "Tally"
    case jotform = "Jotform"
    case surveyMonkey = "SurveyMonkey"
    case formstack = "Formstack"
    case cognitoForms = "Cognito Forms"
    case fillout = "Fillout"
    case airtableForms = "Airtable Forms"
    case qualtrics = "Qualtrics"
    case formkeep = "Formkeep"
    case formAssembly = "FormAssembly"
    case wufoo = "Wufoo"
    case formBuilder123 = "123FormBuilder"
    case zohoForms = "Zoho Forms"
    case formsApp = "Forms.app"
    case paperform = "Paperform"
    case feathery = "Feathery"
    case opnform = "OpnForm"
    
    public static var surveymonkey: FormPlatformType { .surveyMonkey }
    
    // ATS / Job Portals
    case greenhouse = "Greenhouse"
    case lever = "Lever"
    case workday = "Workday"
    case ashby = "Ashby"
    case smartRecruiters = "SmartRecruiters"
    case jobvite = "Jobvite"
    case icims = "iCIMS"
    case bambooHR = "BambooHR"
    case workable = "Workable"
    case handshake = "Handshake"
    case submittable = "Submittable"
    
    // College & Admissions
    case commonApp = "Common Application"
    case coalitionApp = "Coalition Application (Scoir)"
    case slate = "Slate Admissions"
    
    // E-Signatures
    case docuSign = "DocuSign"
    case adobeSign = "Adobe Acrobat Sign"
    case pandaDoc = "PandaDoc"
}

public struct FormPlatformSignature: Sendable {
    public let type: FormPlatformType
    public let hostMatches: [String]
    public let pathPrefixes: [String]
    public let titleSuffixes: [String]
    public let defaultFormName: String
    
    public init(
        type: FormPlatformType,
        hostMatches: [String],
        pathPrefixes: [String] = [],
        titleSuffixes: [String] = [],
        defaultFormName: String
    ) {
        self.type = type
        self.hostMatches = hostMatches
        self.pathPrefixes = pathPrefixes
        self.titleSuffixes = titleSuffixes
        self.defaultFormName = defaultFormName
    }
}

public enum FormPlatformRegistry {
    public static let platforms: [FormPlatformSignature] = [
        // Form Builders & Surveys
        FormPlatformSignature(
            type: .googleForms,
            hostMatches: ["docs.google.com/forms", "forms.google.com", "forms.gle"],
            pathPrefixes: [],
            titleSuffixes: ["- Google Forms", "— Google Forms", "| Google Forms", "· Google Forms", "- Google Form", "Google Forms:", "Google Forms"],
            defaultFormName: "Google Form"
        ),
        FormPlatformSignature(
            type: .microsoftForms,
            hostMatches: ["forms.office.com", "forms.microsoft.com", "forms.office365.com"],
            pathPrefixes: ["/pages/", "/r/"],
            titleSuffixes: ["| Microsoft Forms", "- Microsoft Forms", "— Microsoft Forms", "Microsoft Forms"],
            defaultFormName: "Microsoft Form"
        ),
        FormPlatformSignature(
            type: .typeform,
            hostMatches: ["typeform.com"],
            pathPrefixes: ["/to/"],
            titleSuffixes: ["| Typeform", "- Typeform", "— Typeform"],
            defaultFormName: "Typeform"
        ),
        FormPlatformSignature(
            type: .tally,
            hostMatches: ["tally.so"],
            pathPrefixes: ["/r/"],
            titleSuffixes: ["- Tally", "— Tally", "| Tally"],
            defaultFormName: "Tally Form"
        ),
        FormPlatformSignature(
            type: .jotform,
            hostMatches: ["jotform.com", "myjotform.com", "jotformeu.com", "jotform.us", "jotformpro.com"],
            pathPrefixes: ["/form/", "/"],
            titleSuffixes: ["- Jotform", "— Jotform", "| Jotform", "· Jotform"],
            defaultFormName: "Jotform"
        ),
        FormPlatformSignature(
            type: .surveyMonkey,
            hostMatches: ["surveymonkey.com"],
            pathPrefixes: ["/r/", "/s/"],
            titleSuffixes: ["- SurveyMonkey", "— SurveyMonkey", "| SurveyMonkey", "Take Survey"],
            defaultFormName: "SurveyMonkey Survey"
        ),
        FormPlatformSignature(
            type: .formstack,
            hostMatches: ["formstack.com", "formstack.io"],
            pathPrefixes: ["/forms/"],
            titleSuffixes: ["- Formstack", "— Formstack", "| Formstack"],
            defaultFormName: "Formstack Form"
        ),
        FormPlatformSignature(
            type: .cognitoForms,
            hostMatches: ["cognitoforms.com"],
            pathPrefixes: ["/"],
            titleSuffixes: ["- Cognito Forms", "— Cognito Forms", "| Cognito Forms"],
            defaultFormName: "Cognito Form"
        ),
        FormPlatformSignature(
            type: .fillout,
            hostMatches: ["fillout.com"],
            pathPrefixes: ["/t/"],
            titleSuffixes: ["| Fillout", "- Fillout", "— Fillout"],
            defaultFormName: "Fillout Form"
        ),
        FormPlatformSignature(
            type: .airtableForms,
            hostMatches: ["airtable.com"],
            pathPrefixes: ["/shr", "/form/"],
            titleSuffixes: ["- Airtable", "— Airtable", "| Airtable"],
            defaultFormName: "Airtable Form"
        ),
        FormPlatformSignature(
            type: .qualtrics,
            hostMatches: ["qualtrics.com"],
            pathPrefixes: ["/jfe/form/", "/jfe/preview/", "/form/"],
            titleSuffixes: ["Qualtrics Survey", "- Qualtrics", "— Qualtrics", "| Qualtrics", "· Qualtrics", "Qualtrics"],
            defaultFormName: "Qualtrics Survey"
        ),
        FormPlatformSignature(
            type: .formkeep,
            hostMatches: ["formkeep.com"],
            pathPrefixes: ["/p/", "/f/"],
            titleSuffixes: ["- Formkeep", "— Formkeep"],
            defaultFormName: "Formkeep Form"
        ),
        FormPlatformSignature(
            type: .formAssembly,
            hostMatches: ["tfaforms.net", "formassembly.com", "tfaforms.com"],
            pathPrefixes: ["/"],
            titleSuffixes: ["- FormAssembly", "— FormAssembly", "- TFAForms"],
            defaultFormName: "FormAssembly Form"
        ),
        FormPlatformSignature(
            type: .wufoo,
            hostMatches: ["wufoo.com"],
            pathPrefixes: ["/forms/"],
            titleSuffixes: ["(Wufoo)", "- Wufoo", "— Wufoo"],
            defaultFormName: "Wufoo Form"
        ),
        FormPlatformSignature(
            type: .formBuilder123,
            hostMatches: ["123formbuilder.com"],
            pathPrefixes: ["/form-", "/sf.php"],
            titleSuffixes: ["- 123FormBuilder", "— 123FormBuilder", "| 123FormBuilder"],
            defaultFormName: "123FormBuilder"
        ),
        FormPlatformSignature(
            type: .zohoForms,
            hostMatches: ["forms.zohopublic.com", "forms.zohopublic.eu", "forms.zohopublic.in", "forms.zoho.com"],
            pathPrefixes: ["/form/", "/"],
            titleSuffixes: ["- Zoho Forms", "— Zoho Forms", "| Zoho Forms"],
            defaultFormName: "Zoho Form"
        ),
        FormPlatformSignature(
            type: .formsApp,
            hostMatches: ["forms.app"],
            pathPrefixes: ["/form/"],
            titleSuffixes: ["- forms.app", "— forms.app", "| forms.app"],
            defaultFormName: "forms.app Form"
        ),
        FormPlatformSignature(
            type: .paperform,
            hostMatches: ["paperform.co"],
            pathPrefixes: ["/"],
            titleSuffixes: ["- Paperform", "— Paperform", "| Paperform"],
            defaultFormName: "Paperform"
        ),
        FormPlatformSignature(
            type: .feathery,
            hostMatches: ["feathery.io"],
            pathPrefixes: ["/"],
            titleSuffixes: ["- Feathery", "— Feathery", "| Feathery"],
            defaultFormName: "Feathery Form"
        ),
        FormPlatformSignature(
            type: .opnform,
            hostMatches: ["opnform.com"],
            pathPrefixes: ["/"],
            titleSuffixes: ["- OpnForm", "— OpnForm", "| OpnForm"],
            defaultFormName: "OpnForm"
        ),
        
        // ATS / Jobs
        FormPlatformSignature(
            type: .greenhouse,
            hostMatches: ["boards.greenhouse.io", "job-boards.greenhouse.io", "boards.eu.greenhouse.io", "greenhouse.io"],
            pathPrefixes: ["/"],
            titleSuffixes: ["- Greenhouse", "— Greenhouse", "at Greenhouse"],
            defaultFormName: "Greenhouse Job Application"
        ),
        FormPlatformSignature(
            type: .lever,
            hostMatches: ["jobs.lever.co", "jobs.eu.lever.co", "lever.co"],
            pathPrefixes: ["/"],
            titleSuffixes: ["| Lever", "- Lever", "— Lever"],
            defaultFormName: "Lever Job Application"
        ),
        FormPlatformSignature(
            type: .workday,
            hostMatches: ["myworkdayjobs.com", "workday.com"],
            pathPrefixes: ["/job/", "/apply", "/careers/"],
            titleSuffixes: ["Workday", "Careers"],
            defaultFormName: "Workday Job Application"
        ),
        FormPlatformSignature(
            type: .ashby,
            hostMatches: ["jobs.ashbyhq.com", "ashbyhq.com"],
            pathPrefixes: ["/"],
            titleSuffixes: ["| Ashby", "- Ashby", "— Ashby"],
            defaultFormName: "Ashby Job Application"
        ),
        FormPlatformSignature(
            type: .smartRecruiters,
            hostMatches: ["jobs.smartrecruiters.com", "smartrecruiters.com"],
            pathPrefixes: ["/"],
            titleSuffixes: ["- SmartRecruiters", "— SmartRecruiters", "| SmartRecruiters"],
            defaultFormName: "SmartRecruiters Job Application"
        ),
        FormPlatformSignature(
            type: .jobvite,
            hostMatches: ["jobs.jobvite.com", "careers.jobvite.com", "jobvite.com"],
            pathPrefixes: ["/"],
            titleSuffixes: ["- Jobvite", "— Jobvite", "| Jobvite"],
            defaultFormName: "Jobvite Job Application"
        ),
        FormPlatformSignature(
            type: .icims,
            hostMatches: ["icims.com"],
            pathPrefixes: ["/jobs/"],
            titleSuffixes: ["- iCIMS", "— iCIMS", "| iCIMS"],
            defaultFormName: "iCIMS Job Application"
        ),
        FormPlatformSignature(
            type: .bambooHR,
            hostMatches: ["bamboohr.com"],
            pathPrefixes: ["/careers/", "/jobs/"],
            titleSuffixes: ["- BambooHR", "— BambooHR"],
            defaultFormName: "BambooHR Job Application"
        ),
        FormPlatformSignature(
            type: .workable,
            hostMatches: ["apply.workable.com", "workable.com"],
            pathPrefixes: ["/"],
            titleSuffixes: ["- Workable", "— Workable", "| Workable"],
            defaultFormName: "Workable Job Application"
        ),
        FormPlatformSignature(
            type: .handshake,
            hostMatches: ["joinhandshake.com"],
            pathPrefixes: ["/jobs/", "/students/jobs/"],
            titleSuffixes: ["| Handshake", "- Handshake"],
            defaultFormName: "Handshake Job Application"
        ),
        FormPlatformSignature(
            type: .submittable,
            hostMatches: ["submittable.com"],
            pathPrefixes: ["/submit/"],
            titleSuffixes: ["| Submittable", "- Submittable"],
            defaultFormName: "Submittable Application"
        ),
        
        // College / University Admissions
        FormPlatformSignature(
            type: .commonApp,
            hostMatches: ["commonapp.org"],
            pathPrefixes: ["/apply", "/createaccount", "/applicant-ux"],
            titleSuffixes: ["Common App", "- Common App", "| Common App"],
            defaultFormName: "Common Application"
        ),
        FormPlatformSignature(
            type: .coalitionApp,
            hostMatches: ["app.scoir.com", "scoir.com"],
            pathPrefixes: ["/app/", "/signup", "/signin"],
            titleSuffixes: ["| Scoir", "Coalition Application"],
            defaultFormName: "Coalition Application (Scoir)"
        ),
        FormPlatformSignature(
            type: .slate,
            hostMatches: ["technolutions.net"],
            pathPrefixes: ["/apply", "/register"],
            titleSuffixes: ["Technolutions", "Application Status"],
            defaultFormName: "University Application (Slate)"
        ),
        
        // E-Signatures & Agreements
        FormPlatformSignature(
            type: .docuSign,
            hostMatches: ["docusign.net", "docusign.com"],
            pathPrefixes: ["/member/", "/signing/", "/documents/"],
            titleSuffixes: ["DocuSign", "Please DocuSign"],
            defaultFormName: "DocuSign Agreement"
        ),
        FormPlatformSignature(
            type: .adobeSign,
            hostMatches: ["adobesign.com", "echosign.com", "documents.adobe.com"],
            pathPrefixes: ["/public/viewagreement", "/public/esignwidget", "/sign/"],
            titleSuffixes: ["Adobe Acrobat Sign", "Adobe Sign", "Please sign:"],
            defaultFormName: "Adobe Acrobat Sign Agreement"
        ),
        FormPlatformSignature(
            type: .pandaDoc,
            hostMatches: ["pandadoc.com"],
            pathPrefixes: ["/s/", "/document/"],
            titleSuffixes: ["- PandaDoc", "| PandaDoc", "PandaDoc"],
            defaultFormName: "PandaDoc Agreement"
        )
    ]
    
    public static func platform(forURL urlString: String, title: String = "") -> FormPlatformType? {
        let lowerURL = urlString.lowercased()
        let lowerTitle = title.lowercased()
        
        for p in platforms {
            for hostMatch in p.hostMatches {
                if lowerURL.contains(hostMatch) {
                    if p.pathPrefixes.isEmpty || p.pathPrefixes.contains(where: { lowerURL.contains($0) }) {
                        return p.type
                    }
                }
            }
            for s in p.titleSuffixes {
                if !lowerTitle.isEmpty && lowerTitle.contains(s.lowercased()) {
                    return p.type
                }
            }
        }
        return nil
    }
}

public struct FormSchema: Sendable, Equatable {
    public var title: String
    public var description: String
    public var fields: [FormInputField]
    public var isClosed: Bool
    public var closedMessage: String?
    
    public init(title: String, description: String = "", fields: [FormInputField], isClosed: Bool = false, closedMessage: String? = nil) {
        self.title = title
        self.description = description
        self.fields = fields
        self.isClosed = isClosed
        self.closedMessage = closedMessage
    }
}

// MARK: - Non-Form URL & Domain Suppression
public enum FormExclusionRegistry {
    public static let blacklistedDomains: [String] = [
        // LMS & Education Platforms
        "instructure.com", "blackboard.com", "classroom.google.com",
        "brightspace.com", "desire2learn.com", "moodle.org", "moodle.com",
        "schoology.com", "gradescope.com", "piazza.com", "quizlet.com",
        "coursera.org", "edx.org", "khanacademy.org", "udemy.com", "skillshare.com",
        
        // Encyclopedias & Research Repositories
        "wikipedia.org", "wikimedia.org", "wiktionary.org",
        "arxiv.org", "biorxiv.org", "medrxiv.org",
        "ncbi.nlm.nih.gov", "nih.gov", "europepmc.org", "openalex.org",
        "nature.com", "sciencedirect.com", "springer.com", "jstor.org",
        "ieee.org", "ieeexplore.ieee.org", "acm.org", "researchgate.net",
        "semanticscholar.org", "scholar.google.com",
        
        // Developer Repositories & Discussion
        "github.com", "gitlab.com", "bitbucket.org",
        "stackoverflow.com", "stackexchange.com",
        "developer.apple.com", "developer.android.com", "developer.mozilla.org", "w3schools.com", "geeksforgeeks.org",
        
        // News & Media
        "nytimes.com", "washingtonpost.com", "wsj.com", "reuters.com",
        "bloomberg.com", "cnn.com", "bbc.com", "bbc.co.uk", "theguardian.com",
        "theverge.com", "techcrunch.com", "arstechnica.com", "wired.com", "forbes.com", "economist.com",
        
        // Social Media & Video / Audio Content
        "medium.com", "substack.com", "dev.to", "hashnode.dev",
        "reddit.com", "youtube.com", "twitch.tv", "netflix.com", "spotify.com",
        "twitter.com", "x.com", "threads.net", "facebook.com", "instagram.com",
        
        // AI Chatbots, Academic Writing & Web Search
        "claude.ai", "anthropic.com", "chatgpt.com", "openai.com", "overleaf.com"
    ]
    
    public static func isBlacklistedURL(_ urlString: String) -> Bool {
        let lower = urlString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty else { return false }
        
        if lower.contains("google.com/search") || lower.contains("google.com/url") {
            return true
        }
        
        // Non-form Google Workspace applications (only docs.google.com/forms is allowed)
        if lower.contains("docs.google.com/document") ||
           lower.contains("docs.google.com/spreadsheets") ||
           lower.contains("docs.google.com/presentation") ||
           lower.contains("drive.google.com") ||
           lower.contains("mail.google.com") ||
           lower.contains("calendar.google.com") ||
           lower.contains("meet.google.com") {
            return true
        }
        
        // Clean URL host extraction
        let withScheme = (lower.hasPrefix("http://") || lower.hasPrefix("https://")) ? lower : "https://" + lower
        guard let url = URL(string: withScheme), let host = url.host?.lowercased() else {
            for bl in blacklistedDomains {
                if lower.contains(bl) { return true }
            }
            return false
        }
        
        for bl in blacklistedDomains {
            if host == bl || host.hasSuffix("." + bl) {
                return true
            }
        }
        
        // Subdomain patterns for self-hosted university LMS portals:
        // e.g. canvas.harvard.edu, blackboard.usc.edu, moodle.ucl.ac.uk, brightspace.purdue.edu
        if host.hasPrefix("canvas.") || host.contains(".canvas.") ||
           host.hasPrefix("blackboard.") || host.contains(".blackboard.") ||
           host.hasPrefix("moodle.") || host.contains(".moodle.") ||
           host.hasPrefix("brightspace.") || host.contains(".brightspace.") ||
           host.hasPrefix("gradescope.") || host.contains(".gradescope.") {
            return true
        }
        
        // Coursework / syllabus / LMS assignment paths:
        let path = url.path.lowercased()
        if path.contains("/courses/") && (path.contains("/assignments") || path.contains("/quizzes") || path.contains("/modules")) {
            return true
        }
        
        return false
    }
}

public struct DefaultApplicationFormDetector: ApplicationFormDetectorProtocol {
    public init() {}
    
    // MARK: - Keyword & Pattern Matchers
    public static func isFormTitle(_ rawTitle: String) -> Bool {
        let clean = cleanTitle(rawTitle).trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        let rawLower = rawTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty || !rawLower.isEmpty else { return false }
        
        // 0. Antigravity, AI agent tools, and coding IDE windows are strictly NEVER forms
        if lower.contains("antigravity") || lower.contains("gemini") || rawLower.contains("antigravity") || rawLower.contains("gemini") { return false }
        
        // 0b. Source code, test, project, configuration or script files are NEVER forms
        let codeExtensions = [
            ".swift", ".ts", ".tsx", ".js", ".jsx", ".py", ".json", ".md", ".rs", ".go",
            ".java", ".kt", ".cpp", ".c", ".h", ".hpp", ".rb", ".sh", ".yaml", ".yml",
            ".toml", ".css", ".scss", ".html", ".lock", ".pbxproj", ".xctest", ".xcodeproj"
        ]
        for ext in codeExtensions {
            if lower.contains(ext) || rawLower.contains(ext) {
                return false
            }
        }
        
        // 0c. Reject Negative Non-Form Site Titles (News, Wikis, Repos, LMS, Search, Chat)
        let negativeTitleIndicators = [
            " - wikipedia", " | wikipedia", " - youtube", " | youtube",
            " - github", " · pull request", " · issue #",
            " - canvas", " | instructure", " - blackboard", " | blackboard",
            " - google classroom", " | google classroom",
            " - medium", " | medium", " - substack", " | substack",
            " - stack overflow", " | stack overflow",
            " - google search", " | google search",
            "your first chat with claude", "chat with claude", " - claude",
            "chatgpt", "chat.openai.com",
            "the new york times", "the washington post", "the wall street journal",
            "the verge", "techcrunch", "bloomberg"
        ]
        for neg in negativeTitleIndicators {
            if (lower.contains(neg) || rawLower.contains(neg)) && !lower.contains("google forms") && !rawLower.contains("google forms") && !lower.contains("application form") {
                return false
            }
        }
        
        // Reject non-form reading papers and syllabus materials
        if (lower.contains("reading response") || lower.contains("syllabus") || lower.contains("lecture ")) && !lower.contains("google forms") && !rawLower.contains("google forms") {
            return false
        }
        
        // Reject common non-form review phrases
        if (lower.hasSuffix(" review") || lower.hasSuffix(" reviews") || rawLower.hasSuffix(" review") || rawLower.hasSuffix(" reviews")) && !lower.contains("peer review form") {
            return false
        }
        
        // 1. Known Platform Service Suffixes & Brand Markers
        for p in FormPlatformRegistry.platforms {
            for s in p.titleSuffixes {
                if lower.contains(s.lowercased()) || rawLower.contains(s.lowercased()) {
                    return true
                }
            }
        }
        
        // Direct Google Forms title identifiers
        if lower.contains("google forms") || rawLower.contains("google forms") ||
           lower.contains("google form") || rawLower.contains("google form") ||
           lower.contains("untitled form") || rawLower.contains("untitled form") {
            return true
        }
        
        // Specific qualified forms recognized across platforms
        if (lower.contains("laguna schools") || rawLower.contains("laguna schools")) && (lower.contains("ia/sa") || lower.contains("application")) {
            return true
        }
        
        // 2. High-Precision Qualified Compound Phrases (Forms, Applications, Surveys, Elections)
        let qualifiedPhrases = [
            "application form", "job application", "candidate application", "employment application",
            "internship application", "scholarship application", "college application",
            "university application", "undergraduate application", "graduate application",
            "admissions application", "rental application", "tenant application", "lease application",
            "housing application", "visa application", "passport application", "membership application",
            "grant application", "permit application", "volunteer application", "credit application",
            "loan application", "mortgage application", "online application", "applicant portal",
            "registration form", "event registration form", "attendee registration", "signup form",
            "sign-up form", "intake form", "feedback form", "evaluation form", "contact form", "contact us form",
            "order form", "submission form", "questionnaire", "feedback survey", "customer satisfaction survey",
            "inquiry form", "assessment form", "course evaluation form", "student evaluation form",
            "peer review form", "check-in form", "timesheet form", "onboarding form", "screening form",
            "attendance form", "preference form", "interview form", "sign-in form", "sign in form",
            "voting ballot", "student council election", "student government election",
            "midterm exam", "pop quiz", "cs 101 quiz", "club registration", "volunteer sign-up",
            "t-shirt order form", "event rsvp", "advisement worksheet", "academic advisement worksheet", "onboarding worksheet"
        ]
        for phrase in qualifiedPhrases {
            if lower.contains(phrase) || rawLower.contains(phrase) {
                return true
            }
        }
        
        // 3. Qualified Compound Suffixes
        if lower.hasSuffix(" application form") || lower.hasSuffix(" registration form") ||
           lower.hasSuffix(" feedback form") || lower.hasSuffix(" intake form") ||
           lower.hasSuffix(" inquiry form") || lower.hasSuffix(" survey form") ||
           rawLower.hasSuffix(" application form") || rawLower.hasSuffix(" registration form") {
            return true
        }
        
        // Suffix patterns for applications: e.g. "... Application", "... Questionnaire", "... Survey"
        if lower.hasSuffix(" application") || lower.hasSuffix(" questionnaire") ||
           lower.hasSuffix(" survey") || lower.hasSuffix(" registration") ||
           lower.hasSuffix(" sign-up") || lower.hasSuffix(" signup") ||
           lower.hasSuffix(" rsvp") || lower.hasSuffix(" form") {
            // Reject non-form phrases: "web application", "ios application", "literature survey"
            if !lower.contains("web application") && !lower.contains("ios application") &&
               !lower.contains("mac application") && !lower.contains("literature survey") {
                return true
            }
        }
        
        // 4. E-Signature Documents & Qualified PDF Forms
        if lower.hasPrefix("please docusign:") || lower.hasPrefix("please sign:") || rawLower.hasPrefix("please docusign:") {
            return true
        }
        if lower.hasSuffix(".pdf") || rawLower.hasSuffix(".pdf") {
            if lower.contains("form") || lower.contains("application") ||
               lower.contains("i-9") || lower.contains("w-4") || lower.contains("w-9") || lower.contains("1040") ||
               lower.contains("lease_agreement") || lower.contains("rental_agreement") {
                return true
            }
        }
        
        return false
    }
    
    /// Strict blacklist ensuring Antigravity, code editors, developer shells, and system/chat tools are NEVER detected as forms
    public static func isNonFormApplication(bundleID: String, appName: String) -> Bool {
        let b = bundleID.lowercased()
        let n = appName.lowercased()
        
        // 1. Antigravity & AI Assistant tools
        if b.contains("antigravity") || n.contains("antigravity") || b.contains("gemini") || n.contains("gemini") {
            return true
        }
        
        // 2. Code Editors, IDEs & Developer Utilities
        let devKeywords = [
            "vscode", "cursor", "xcode", "sublime", "intellij", "pycharm",
            "clion", "webstorm", "rider", "goland", "datagrip", "fleet",
            "zed", "android.studio", "textedit", "coteditor", "bbedit", "nova",
            "postman", "insomnia", "docker", "gitkraken", "sourcetree",
            "terminal", "iterm", "warp", "alacritty", "kitty", "hyper", "wezterm"
        ]
        if devKeywords.contains(where: { b.contains($0) || n.contains($0) }) {
            return true
        }
        
        // 3. Communication, Meeting & System Apps
        let commKeywords = [
            "slack", "discord", "zoom", "teams", "telegram", "messages",
            "whatsapp", "signal", "finder", "morph", "notes", "notion", "linear"
        ]
        if commKeywords.contains(where: { b.contains($0) || n.contains($0) }) {
            return true
        }
        
        return false
    }
    
    public static func isFormURL(_ urlString: String) -> Bool {
        let lower = urlString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty else { return false }
        
        // 1. Immediately drop blacklisted domains (Canvas LMS, Blackboard, Wikipedia, ArXiv, Google Docs, etc.)
        if FormExclusionRegistry.isBlacklistedURL(lower) {
            return false
        }
        
        // 2. Canonical form platform domains & paths
        for p in FormPlatformRegistry.platforms {
            for hostMatch in p.hostMatches {
                if lower.contains(hostMatch) {
                    if p.pathPrefixes.isEmpty || p.pathPrefixes.contains(where: { lower.contains($0.lowercased()) }) {
                        return true
                    }
                }
            }
        }
        
        // 3. Google script form macro
        if lower.contains("script.google.com/macros/s/") {
            return true
        }
        
        // 4. Concrete application path patterns on custom domains (e.g. apply.harvard.edu, careers.company.com/apply)
        let withScheme = (lower.hasPrefix("http://") || lower.hasPrefix("https://")) ? lower : "https://" + lower
        guard let url = URL(string: withScheme) else { return false }
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()
        
        // Host has apply or admissions subdomain
        if host.hasPrefix("apply.") || host.hasPrefix("admissions.") {
            if path.isEmpty || path == "/" || path.hasPrefix("/apply") || path.hasPrefix("/register") || path.hasPrefix("/createaccount") {
                return true
            }
        }
        
        // Careers / hiring host with apply path
        let isHiringHost = host.contains("careers.") || host.contains("jobs.") || host.contains("careers-") || host.contains("recruit") || host.contains("workday")
        if isHiringHost {
            if path.contains("/apply") || path.contains("/job/") || path.contains("/careers/") {
                return true
            }
        }
        
        // Form response endings with strict boundary
        if path.hasSuffix("/viewform") || path.contains("/viewform?") ||
           path.hasSuffix("/formresponse") || path.contains("/formresponse?") ||
           path.hasSuffix("/closedform") || path.contains("/closedform?") ||
           path.hasSuffix("/preview") || path.contains("/preview?") ||
           path.hasSuffix("/job-application") || path.contains("/job-application/") {
            return true
        }
        
        return false
    }
    
    public static func cleanTitle(_ rawTitle: String) -> String {
        var title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            " - Google Chrome Canary",
            " - Google Chrome Beta",
            " - Google Chrome Dev",
            " - Google Chrome",
            " - Chromium",
            " - Safari Technology Preview",
            " - Safari",
            " - Polar",
            " - Comet",
            " - Brave Browser Nightly",
            " - Brave Browser Beta",
            " - Brave Browser",
            " - Brave",
            " - Microsoft Edge Canary",
            " - Microsoft Edge Dev",
            " - Microsoft Edge Beta",
            " - Microsoft Edge",
            " - Arc",
            " — Mozilla Firefox Developer Edition",
            " — Mozilla Firefox Nightly",
            " — Mozilla Firefox",
            " - Mozilla Firefox",
            " — Firefox",
            " - Firefox",
            " — Zen Browser",
            " - Zen Browser",
            " — Zen",
            " - Zen",
            " - Vivaldi",
            " - Opera GX",
            " - Opera One",
            " - Opera Developer",
            " - Opera",
            " - Orion",
            " - DuckDuckGo",
            " - Tor Browser",
            " - Floorp",
            " - Waterfox",
            " - LibreWolf",
            " - SigmaOS",
            " - Wavebox"
        ]
        for p in patterns {
            if let r = title.range(of: p) {
                let candidate = String(title[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty {
                    title = candidate
                }
            }
        }
        // Strip trailing URL attachments (e.g. " - https://docs.google.com/forms/...")
        if let r = title.range(of: " - https://") ?? title.range(of: " - http://") ?? title.range(of: " — https://") ?? title.range(of: " — http://") {
            let candidate = String(title[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !candidate.isEmpty {
                title = candidate
            }
        }
        return title
    }
    
    public static func stripServiceSuffixes(_ rawTitle: String) -> String {
        var title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let serviceSuffixes = [
            " - Google Forms", " — Google Forms", ": Google Forms",
            " - Google Form", " — Google Form",
            " - Microsoft Forms", " — Microsoft Forms",
            " - Typeform", " — Typeform",
            " - Tally", " — Tally",
            " - Jotform", " — Jotform",
            " - FormAssembly", " — FormAssembly"
        ]
        for s in serviceSuffixes {
            if let r = title.range(of: s, options: .caseInsensitive) {
                let candidate = String(title[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty {
                    title = candidate
                }
            }
        }
        return title
    }
    
    public static func extractFormIdentifier(from urlString: String) -> String? {
        let clean = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let withScheme = clean.hasPrefix("http://") || clean.hasPrefix("https://") ? clean : "https://" + clean
        guard let url = URL(string: withScheme) else { return nil }
        
        let path = url.path
        let host = url.host?.lowercased() ?? ""
        
        if host.contains("google.com") || host.contains("forms.gle") {
            let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
            if let dIdx = components.firstIndex(of: "d") {
                if dIdx + 1 < components.count {
                    if components[dIdx + 1] == "e" && dIdx + 2 < components.count {
                        return components[dIdx + 2]
                    }
                    return components[dIdx + 1]
                }
            }
            if host.contains("forms.gle") && !components.isEmpty {
                return components.first
            }
        }
        
        if host.contains("office.com") || host.contains("microsoft.com") {
            if let comps = URLComponents(string: withScheme), let idItem = comps.queryItems?.first(where: { $0.name.lowercased() == "id" })?.value {
                return host + ":" + idItem
            }
        }
        
        var normPath = path
        for suffix in ["/viewform", "/formResponse", "/edit", "/preview"] {
            if normPath.hasSuffix(suffix) {
                normPath = String(normPath.dropLast(suffix.count))
            }
        }
        return host + normPath
    }
    
    public static func isSameForm(
        titleA: String, urlA: String?,
        titleB: String, urlB: String?
    ) -> Bool {
        let idA = urlA.flatMap { extractFormIdentifier(from: $0) }
        let idB = urlB.flatMap { extractFormIdentifier(from: $0) }
        
        // 1. If both have form IDs, that is the canonical ground truth
        if let a = idA, let b = idB, !a.isEmpty && !b.isEmpty {
            return a == b
        }
        
        // 2. If both have URLs, compare normalized URLs
        if let uA = urlA, let uB = urlB, !uA.isEmpty && !uB.isEmpty {
            let normA = FormContentRetriever.normalizeURLScheme(uA)
            let normB = FormContentRetriever.normalizeURLScheme(uB)
            return normA == normB
        }
        
        // 3. Fallback to clean titles
        let cleanA = stripServiceSuffixes(cleanTitle(titleA)).lowercased()
        let cleanB = stripServiceSuffixes(cleanTitle(titleB)).lowercased()
        
        let genericNames = ["", "application form", "google forms", "google form", "untitled form", "polar"]
        let isAGeneric = genericNames.contains(cleanA)
        let isBGeneric = genericNames.contains(cleanB)
        
        if isAGeneric && isBGeneric {
            return true
        }
        if isAGeneric || isBGeneric {
            return false
        }
        
        return cleanA == cleanB
    }
    
    // MARK: - Browser & AX Helpers
    public static func isBrowserApplication(_ app: NSRunningApplication) -> Bool {
        let bundle = app.bundleIdentifier?.lowercased() ?? ""
        let name = app.localizedName?.lowercased() ?? ""
        if isNonFormApplication(bundleID: bundle, appName: name) {
            return false
        }
        let keywords = [
            "chrome", "chromium", "safari", "polar", "comet", "brave", "edge", "arc",
            "firefox", "opera", "vivaldi", "orion", "zen", "browser",
            "duckduckgo", "floorp", "waterfox", "librewolf", "tor",
            "sigmaos", "wavebox", "webkit"
        ]
        return keywords.contains { bundle.contains($0) || name.contains($0) }
    }
    
    public static func isBrowserName(_ name: String) -> Bool {
        let n = name.lowercased()
        if isNonFormApplication(bundleID: "", appName: n) {
            return false
        }
        let keywords = [
            "chrome", "chromium", "safari", "polar", "comet", "brave", "edge", "arc",
            "firefox", "opera", "vivaldi", "orion", "zen", "browser",
            "duckduckgo", "floorp", "waterfox", "librewolf", "tor",
            "sigmaos", "wavebox", "webkit"
        ]
        return keywords.contains { n.contains($0) }
    }
    
    /// Returns all relevant content, focused, and main windows of an application element.
    /// Crucial discovery: modern Chromium & Electron shells (Polar, Arc, Comet) return an empty array []
    /// for kAXWindowsAttribute on the root app element, attaching actual windows exclusively to
    /// kAXFocusedWindowAttribute and kAXMainWindowAttribute.
    public static func getAllBrowserWindows(appElem: AXUIElement) -> [AXUIElement] {
        var results: [AXUIElement] = []
        
        var focusedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElem, kAXFocusedWindowAttribute as CFString, &focusedRef) == .success,
           let f = focusedRef as! AXUIElement? {
            results.append(f)
        }
        
        var mainRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElem, kAXMainWindowAttribute as CFString, &mainRef) == .success,
           let m = mainRef as! AXUIElement? {
            if !results.contains(where: { CFEqual($0, m) }) {
                results.append(m)
            }
        }
        
        var winsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElem, kAXWindowsAttribute as CFString, &winsRef) == .success,
           let wins = winsRef as? [AXUIElement], !wins.isEmpty {
            for w in wins {
                if !results.contains(where: { CFEqual($0, w) }) {
                    results.append(w)
                }
            }
        }
        
        return results
    }
    
    /// Retrieves the main, focused, or primary content AX window of an application.
    /// Crucial discovery: modern browsers (Polar, Arc, WebKit shells) often have invisible/overlay toolbar windows
    /// where kAXMainWindowAttribute points to an accessory window with an empty title.
    /// Retrieves the main, focused, or primary content AX window of an application across any display.
    /// Crucial discovery: modern browsers (Polar, Arc, Chrome, Safari, WebKit shells) often have accessory windows.
    /// Checking focused/main windows and all windows in kAXWindowsAttribute ensures we find the active content window.
    public static func getBrowserWindowElement(appElem: AXUIElement) -> AXUIElement? {
        // 1. Check focused window
        var focusedRef: CFTypeRef?
        var focusedWin: AXUIElement? = nil
        if AXUIElementCopyAttributeValue(appElem, kAXFocusedWindowAttribute as CFString, &focusedRef) == .success,
           let f = focusedRef as! AXUIElement? {
            focusedWin = f
            var tRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(f, kAXTitleAttribute as CFString, &tRef) == .success,
               let t = (tRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !t.isEmpty && t.lowercased() != "polar" {
                return f
            }
            var sizeRef: CFTypeRef?
            var size = CGSize.zero
            if AXUIElementCopyAttributeValue(f, kAXSizeAttribute as CFString, &sizeRef) == .success,
               let s = sizeRef as! AXValue? {
                AXValueGetValue(s, .cgSize, &size)
            }
            if size.width > 200 && size.height > 200 {
                return f
            }
        }
        
        // 2. Check main window
        var mainRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElem, kAXMainWindowAttribute as CFString, &mainRef) == .success,
           let m = mainRef as! AXUIElement? {
            var tRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(m, kAXTitleAttribute as CFString, &tRef) == .success,
               let t = (tRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !t.isEmpty && t.lowercased() != "polar" {
                return m
            }
        }
        
        // 3. Check all titled windows across any display (including external monitors)
        let windows = getAllBrowserWindows(appElem: appElem)
        for win in windows {
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef) == .success,
               let t = (titleRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !t.isEmpty && t.lowercased() != "polar" {
                return win
            }
        }
        return focusedWin ?? windows.first
    }
    
    // MARK: - Multi-Display Screen Resolvers
    public static func screenForWindow(_ win: AXUIElement) -> (index: Int?, name: String?) {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posRef)
        _ = AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeRef)
        
        var pos = CGPoint.zero
        var size = CGSize.zero
        if let p = posRef as! AXValue? { AXValueGetValue(p, .cgPoint, &pos) }
        if let s = sizeRef as! AXValue? { AXValueGetValue(s, .cgSize, &size) }
        guard size.width > 50 && size.height > 50 else { return (nil, nil) }
        
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return (nil, nil) }
        let primaryH = screens[0].frame.height
        let cocoaY = primaryH - pos.y - size.height
        let cocoaRect = NSRect(x: pos.x, y: cocoaY, width: size.width, height: size.height)
        
        for (idx, screen) in screens.enumerated() {
            if screen.frame.intersects(cocoaRect) {
                return (idx, screen.localizedName)
            }
        }
        return (nil, nil)
    }
    
    public static func screenForBounds(_ bounds: [String: Any]) -> (index: Int?, name: String?) {
        let x = bounds["X"] as? CGFloat ?? 0
        let y = bounds["Y"] as? CGFloat ?? 0
        let w = bounds["Width"] as? CGFloat ?? 0
        let h = bounds["Height"] as? CGFloat ?? 0
        guard w > 50 && h > 50 else { return (nil, nil) }
        
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return (nil, nil) }
        let primaryH = screens[0].frame.height
        let cocoaY = primaryH - y - h
        let cocoaRect = NSRect(x: x, y: cocoaY, width: w, height: h)
        
        for (idx, screen) in screens.enumerated() {
            if screen.frame.intersects(cocoaRect) {
                return (idx, screen.localizedName)
            }
        }
        return (nil, nil)
    }
    
    /// Scans static texts and tab buttons in a Polar window to detect open background form tabs
    public static func findOpenTabFormInPolarWindow(_ win: AXUIElement) -> (title: String, url: String?)? {
        var queue = [win]
        var head = 0
        while head < queue.count && head < 200 {
            let cur = queue[head]
            head += 1
            
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(cur, kAXRoleAttribute as CFString, &roleRef)
            let role = roleRef as? String ?? ""
            
            if role == "AXStaticText" || role == "AXRadioButton" || role == "AXButton" {
                var vRef: CFTypeRef?
                AXUIElementCopyAttributeValue(cur, kAXValueAttribute as CFString, &vRef)
                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(cur, kAXTitleAttribute as CFString, &titleRef)
                
                let text = ((vRef as? String) ?? (titleRef as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty && isFormTitle(text) {
                    var formURL: String? = nil
                    if let session = readPolarSessionForm(filterTitle: text) {
                        formURL = session.url
                    }
                    return (cleanTitle(text), formURL)
                }
            }
            
            var cRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(cur, kAXChildrenAttribute as CFString, &cRef) == .success,
               let children = cRef as? [AXUIElement] {
                queue.append(contentsOf: children)
            }
        }
        return nil
    }
    
    /// Fast sub-5ms BFS search to extract the live web page URL from Polar, Chrome, Safari, etc.
    public static func findAddressBarOrWebAreaURL(in element: AXUIElement) -> String? {
        // Fast O(1) Safari / Native document check
        var docRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXDocument" as CFString, &docRef) == .success,
           let doc = docRef as? String, !doc.isEmpty {
            return doc.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        var queue: [(elem: AXUIElement, depth: Int)] = [(element, 0)]
        var head = 0
        let maxVisited = 300
        
        while head < queue.count && head < maxVisited {
            let (current, depth) = queue[head]
            head += 1
            
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &roleRef)
            let role = (roleRef as? String) ?? ""
            
            // Case A: Standard Chromium / Safari WebKit (AXWebArea)
            if role == "AXWebArea" {
                var urlRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(current, "AXURL" as CFString, &urlRef) == .success,
                   let u = urlRef {
                    let str = "\(u)".trimmingCharacters(in: .whitespacesAndNewlines)
                    if !str.isEmpty && str != "about:blank" {
                        return str
                    }
                }
            }
            
            // Case B: Polar / Custom Web Shells / Chrome Omnibox / ComboBox (AXTextField / AXComboBox address bar)
            if role == "AXTextField" || role == "AXSearchField" || role == "AXComboBox" || role == "AXTextArea" {
                var descRef: CFTypeRef?
                AXUIElementCopyAttributeValue(current, kAXDescriptionAttribute as CFString, &descRef)
                let desc = (descRef as? String) ?? ""
                
                var valRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(current, kAXValueAttribute as CFString, &valRef) == .success,
                   let val = valRef as? String, !val.isEmpty {
                    let trimmed = val.trimmingCharacters(in: .whitespacesAndNewlines)
                    let isAddressDesc = desc == "Address and search bar" ||
                                        desc.localizedCaseInsensitiveContains("address") ||
                                        desc.localizedCaseInsensitiveContains("location") ||
                                        desc.localizedCaseInsensitiveContains("url") ||
                                        desc.localizedCaseInsensitiveContains("search")
                    let looksLikeURL = !trimmed.contains(" ") && (
                        trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") ||
                        trimmed.contains("://") ||
                        trimmed.contains("docs.google.com") ||
                        trimmed.contains("forms.google.com") ||
                        trimmed.contains("forms.gle") ||
                        trimmed.contains("typeform.com") ||
                        trimmed.contains("tally.so") ||
                        trimmed.contains("jotform.com") ||
                        trimmed.contains(".com/") || trimmed.contains(".org/") ||
                        trimmed.contains(".net/") || trimmed.contains(".io/") ||
                        trimmed.contains(".so/") || trimmed.contains(".edu/")
                    )
                    if (isAddressDesc || looksLikeURL) && !trimmed.isEmpty {
                        return trimmed
                    }
                }
            }
            
            // Speed optimization: limit depth to 14 and skip scroll areas
            if depth >= 14 { continue }
            if role == "AXScrollArea" && depth > 0 { continue }
            
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(current, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                for c in children {
                    queue.append((c, depth + 1))
                }
            }
        }
        return nil
    }
    
    // MARK: - Browser Tab Inspection
    private func fetchFrontmostBrowserTabInfo(bundleID: String) -> (url: String?, title: String?) {
        let scriptSource: String?
        if bundleID.contains("google.chrome") || bundleID.contains("brave") || bundleID.contains("edge") || bundleID.contains("arc") || bundleID.contains("vivaldi") || bundleID.contains("opera") {
            scriptSource = """
            tell application id "\(bundleID)"
                if (count of windows) > 0 then
                    set tabURL to URL of active tab of front window
                    set tabTitle to title of active tab of front window
                    return tabURL & " ||| " & tabTitle
                end if
            end tell
            """
        } else if bundleID.contains("safari") && !bundleID.contains("technology") {
            scriptSource = """
            tell application id "com.apple.Safari"
                if (count of documents) > 0 then
                    set docURL to URL of front document
                    set docTitle to name of front document
                    return docURL & " ||| " & docTitle
                end if
            end tell
            """
        } else {
            scriptSource = nil
        }
        
        guard let source = scriptSource, let output = Self.executeSimpleAppleScript(source) else {
            return (nil, nil)
        }
        
        let parts = output.components(separatedBy: " ||| ")
        let url = parts.first?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let title = parts.count > 1 ? parts[1].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) : nil
        return (url, title)
    }
    
    private static let scriptExecutionLock = NSLock()
    nonisolated(unsafe) private static var cachedPolarTitle: (title: String, time: Date)? = nil
    
    public static func executeSimpleAppleScript(_ source: String) -> String? {
        // Prevent concurrent osascript process pile-ups
        guard scriptExecutionLock.try() else { return nil }
        defer { scriptExecutionLock.unlock() }
        
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", source]
        let pipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = errPipe
        
        let semaphore = DispatchSemaphore(value: 0)
        proc.terminationHandler = { _ in
            semaphore.signal()
        }
        
        do {
            try proc.run()
        } catch {
            NSLog("[MORPH-SCRIPT] executeSimpleAppleScript failed to run: %@", error.localizedDescription)
            return nil
        }
        
        let waitResult = semaphore.wait(timeout: .now() + 1.5)
        if waitResult == .timedOut {
            proc.terminate()
            NSLog("[MORPH-SCRIPT] executeSimpleAppleScript timed out after 1.5s")
            return nil
        }
        
        if proc.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !str.isEmpty {
                return str
            }
        } else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
            NSLog("[MORPH-SCRIPT] executeSimpleAppleScript failed: code=%d, err='%@'", proc.terminationStatus, errStr)
        }
        return nil
    }
    
    private func fetchURLForRunningBrowser(ownerName: String) -> String? {
        let family = PersonalizedBrowserDetector.engineFamily(for: "", name: ownerName)
        switch family {
        case .polar:
            return Self.checkPolarBrowser()?.url
        case .safari:
            return checkSafariBrowser()?.url
        case .chromium:
            return checkChromiumBrowser(appName: ownerName)?.url
        case .gecko:
            return checkGeckoBrowser(appName: ownerName)?.url
        case .webkit:
            return checkWebKitBrowser(appName: ownerName)?.url
        case .unknown:
            return nil
        }
    }
    
    // MARK: - Specialized Browser Checks
    
    private struct CachedHistoryTitle {
        let title: String?
        let fetchedAt: Date
    }
    nonisolated(unsafe) private static var historyTitleCache: [String: CachedHistoryTitle] = [:]
    private static let historyCacheLock = NSLock()
    private static let negativeHistoryCacheTTL: TimeInterval = 30.0
    
    private struct CachedSessionScan {
        let mtime: TimeInterval
        let fileSize: UInt64
        let cachedAt: Date
        let entries: [(url: String, title: String)]
    }
    nonisolated(unsafe) private static var sessionScanCache: [String: CachedSessionScan] = [:]
    private static let sessionScanCacheLock = NSLock()
    private static let sessionScanCacheTTL: TimeInterval = 3.0
    
    private static func chromiumSupportBases(for browserAppName: String?) -> [String] {
        let allBases = [
            "~/Library/Application Support/com.polar.browser.host",
            "~/Library/Application Support/Google/Chrome",
            "~/Library/Application Support/Google/Chrome Canary",
            "~/Library/Application Support/Chromium",
            "~/Library/Application Support/Microsoft Edge",
            "~/Library/Application Support/BraveSoftware/Brave-Browser",
            "~/Library/Application Support/Arc/User Data",
            "~/Library/Application Support/Vivaldi"
        ].map { ($0 as NSString).expandingTildeInPath }
        
        guard let name = browserAppName?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return allBases
        }
        if name.contains("polar") {
            return [("~/Library/Application Support/com.polar.browser.host" as NSString).expandingTildeInPath]
        } else if name.contains("canary") {
            return [("~/Library/Application Support/Google/Chrome Canary" as NSString).expandingTildeInPath]
        } else if name.contains("chrome") {
            return [("~/Library/Application Support/Google/Chrome" as NSString).expandingTildeInPath]
        } else if name.contains("chromium") {
            return [("~/Library/Application Support/Chromium" as NSString).expandingTildeInPath]
        } else if name.contains("edge") {
            return [("~/Library/Application Support/Microsoft Edge" as NSString).expandingTildeInPath]
        } else if name.contains("brave") {
            return [("~/Library/Application Support/BraveSoftware/Brave-Browser" as NSString).expandingTildeInPath]
        } else if name.contains("arc") {
            return [("~/Library/Application Support/Arc/User Data" as NSString).expandingTildeInPath]
        } else if name.contains("vivaldi") {
            return [("~/Library/Application Support/Vivaldi" as NSString).expandingTildeInPath]
        }
        return allBases
    }

    /// Fast extraction of page title from Chromium/Polar SQLite History database
    public static func titleFromHistory(url: String, preferredBrowserName: String? = nil) -> String? {
        let cacheKey = "\(preferredBrowserName?.lowercased() ?? "*")::\(url)"
        historyCacheLock.lock()
        if let cached = historyTitleCache[cacheKey] {
            if let hit = cached.title {
                historyCacheLock.unlock()
                return hit
            }
            if Date().timeIntervalSince(cached.fetchedAt) < negativeHistoryCacheTTL {
                historyCacheLock.unlock()
                return nil
            }
        }
        historyCacheLock.unlock()

        let fm = FileManager.default
        let bases = chromiumSupportBases(for: preferredBrowserName)
        for base in bases {
            var profCandidates: [String] = ["Default", "."]
            if let subdirs = try? fm.contentsOfDirectory(atPath: base) {
                for sub in subdirs where sub == "Default" || sub.hasPrefix("Profile ") {
                    if !profCandidates.contains(sub) { profCandidates.append(sub) }
                }
            }
            for prof in profCandidates {
                let histPath = prof == "." ? "\(base)/History" : "\(base)/\(prof)/History"
                if fm.fileExists(atPath: histPath) {
                    let tempHist = "/tmp/morph_hist_\(UUID().uuidString).sqlite"
                    if (try? fm.copyItem(atPath: histPath, toPath: tempHist)) != nil {
                        defer { try? fm.removeItem(atPath: tempHist) }
                        let proc = Process()
                        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
                        let escapedLike = url
                            .replacingOccurrences(of: "\\", with: "\\\\")
                            .replacingOccurrences(of: "%", with: "\\%")
                            .replacingOccurrences(of: "_", with: "\\_")
                            .replacingOccurrences(of: "'", with: "''")
                        proc.arguments = [tempHist, "SELECT title FROM urls WHERE url LIKE '%\(escapedLike)%' ESCAPE '\\' AND title != '' ORDER BY last_visit_time DESC LIMIT 1;"]
                        let pipe = Pipe()
                        proc.standardOutput = pipe
                        let sem = DispatchSemaphore(value: 0)
                        proc.terminationHandler = { _ in sem.signal() }
                        if (try? proc.run()) != nil {
                            if sem.wait(timeout: .now() + 1.0) == .timedOut {
                                if proc.isRunning { proc.terminate() }
                                try? pipe.fileHandleForReading.close()
                                continue
                            }
                            let data = pipe.fileHandleForReading.readDataToEndOfFile()
                            if let t = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
                                historyCacheLock.lock()
                                historyTitleCache[cacheKey] = CachedHistoryTitle(title: t, fetchedAt: Date())
                                historyCacheLock.unlock()
                                return t
                            }
                        }
                    }
                }
            }
        }
        historyCacheLock.lock()
        historyTitleCache[cacheKey] = CachedHistoryTitle(title: nil, fetchedAt: Date())
        historyCacheLock.unlock()
        return nil
    }

    /// Specialized check for Polar Browser:
    /// High-performance native inspection inspecting exclusively the user's active, frontmost tab/window.
    /// Strictly returns nil if the user is on another tab (e.g. Claude, Google Search, Overleaf) or non-form content,
    /// so Morph immediately returns to the transparent resting state.
    public static func checkPolarBrowser() -> FormDetectionResult? {
        let polar = NSWorkspace.shared.runningApplications.first(where: { app in
            !app.isTerminated &&
            kill(app.processIdentifier, 0) == 0 &&
            app.activationPolicy == .regular &&
            (app.bundleIdentifier == "com.polar.browser" ||
             app.localizedName?.caseInsensitiveCompare("polar") == .orderedSame)
        }) ?? NSWorkspace.shared.runningApplications.first(where: { app in
            !app.isTerminated &&
            kill(app.processIdentifier, 0) == 0 &&
            (app.bundleIdentifier?.lowercased().contains("com.polar.browser") ?? false ||
             app.localizedName?.lowercased() == "polar")
        })
        guard let polar = polar else { return nil }
        
        let appElem = AXUIElementCreateApplication(polar.processIdentifier)
        _ = AXIsProcessTrusted()
        
        // 1. First and foremost, inspect the FOCUSED and MAIN AX window of Polar
        var targetWin: AXUIElement? = nil
        var frontTitle = ""
        
        var focusedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElem, kAXFocusedWindowAttribute as CFString, &focusedRef) == .success,
           let fWin = focusedRef as! AXUIElement? {
            targetWin = fWin
            var tRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(fWin, kAXTitleAttribute as CFString, &tRef) == .success,
               let t = (tRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !t.isEmpty && t.lowercased() != "polar" {
                frontTitle = t
            }
        }
        
        if targetWin == nil {
            var mainRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElem, kAXMainWindowAttribute as CFString, &mainRef) == .success,
               let mWin = mainRef as! AXUIElement? {
                targetWin = mWin
                var tRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(mWin, kAXTitleAttribute as CFString, &tRef) == .success,
                   let t = (tRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !t.isEmpty && t.lowercased() != "polar" {
                    frontTitle = t
                }
            }
        }
        
        // 2. Only fall back to kAXWindowsAttribute if neither focused nor main window was reported
        if targetWin == nil {
            var winsRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElem, kAXWindowsAttribute as CFString, &winsRef) == .success,
               let wins = winsRef as? [AXUIElement],
               let firstWin = wins.first {
                targetWin = firstWin
                var tRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(firstWin, kAXTitleAttribute as CFString, &tRef) == .success,
                   let t = (tRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !t.isEmpty && t.lowercased() != "polar" {
                    frontTitle = t
                }
            }
        }
        
        // 3. Fallback to WindowServer topmost ON-SCREEN layer 0 window only if AX had no title on the active window
        if frontTitle.isEmpty {
            let options: CGWindowListOption = [.excludeDesktopElements, .optionOnScreenOnly]
            if let winList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
                for win in winList {
                    let ownerPID = win[kCGWindowOwnerPID as String] as? pid_t ?? 0
                    let owner = (win[kCGWindowOwnerName as String] as? String ?? "").lowercased()
                    let layer = win[kCGWindowLayer as String] as? Int ?? -1
                    let bounds = win[kCGWindowBounds as String] as? [String: Any] ?? [:]
                    let h = bounds["Height"] as? CGFloat ?? 0
                    if (ownerPID == polar.processIdentifier || owner == "polar") && layer == 0 && h > 100 {
                        let t = (win[kCGWindowName as String] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !t.isEmpty && t.lowercased() != "polar" {
                            frontTitle = t
                        }
                        // Strictly inspect ONLY the frontmost on-screen Polar window in z-order; never scan deeper background windows
                        break
                    }
                }
            }
        }
        
        // 4. Retrieve the live URL from the active window
        let activeWin = targetWin ?? getBrowserWindowElement(appElem: appElem)
        let addressURL = activeWin.flatMap { findAddressBarOrWebAreaURL(in: $0) }
        
        // Strict Immediate Rejection: if address bar has a blacklisted non-form URL
        if let aURL = addressURL, FormExclusionRegistry.isBlacklistedURL(aURL) {
            return nil
        }
        
        let cleanedTitle = cleanTitle(frontTitle)
        let isURLForm = addressURL != nil && isFormURL(addressURL!)
        let isTitleForm = (!frontTitle.isEmpty && isFormTitle(frontTitle)) || (!cleanedTitle.isEmpty && isFormTitle(cleanedTitle))
        
        // STRICT ACTIVE TAB ENFORCEMENT:
        // If neither the active tab title nor the address bar URL is a form:
        // The user is NOT on a form! Return nil immediately so Morph collapses to transparent state.
        guard isURLForm || isTitleForm else {
            return nil
        }
        
        // Match session file ONLY to resolve the full form URL for this specific active form title
        let strippedTitle = stripServiceSuffixes(cleanedTitle)
        let sessionMatch = readPolarSessionForm(filterTitle: strippedTitle, filterURL: addressURL)
        let finalURL = addressURL ?? sessionMatch?.url
        let finalTitle = !strippedTitle.isEmpty && strippedTitle.lowercased() != "google forms" && strippedTitle.lowercased() != "untitled form"
            ? strippedTitle
            : (sessionMatch?.title ?? (finalURL.flatMap { formNameFromURL($0) } ?? cleanedTitle))
        
        let (screenIdx, screenName) = activeWin != nil ? screenForWindow(activeWin!) : (nil, nil)
        NSLog("[MORPH-FORM] checkPolarBrowser: ACTIVE tab matched form '%@' (url: %@)", finalTitle, finalURL ?? "nil")
        return FormDetectionResult(
            isDetected: true,
            title: cleanTitle(finalTitle),
            appName: "Polar",
            url: finalURL,
            browserFamily: .polar,
            screenIndex: screenIdx,
            screenName: screenName
        )
    }
    
    /// Reads the active form URL and page title directly from Chromium family host session binary data
    /// (Polar, Google Chrome, Brave, Arc, Edge, and user-data-dir profiles)
    public static func readChromiumSessionForm(filterTitle: String? = nil, filterURL: String? = nil, polarOnly: Bool = false, targetBrowserAppName: String? = nil) -> (url: String, title: String)? {
        var possibleDirs: [String] = []
        let bases: [String]
        if polarOnly {
            bases = [("~/Library/Application Support/com.polar.browser.host" as NSString).expandingTildeInPath]
        } else {
            bases = chromiumSupportBases(for: targetBrowserAppName)
        }
        for base in bases {
            possibleDirs.append((base as NSString).appendingPathComponent("Sessions"))
            possibleDirs.append((base as NSString).appendingPathComponent("Default/Sessions"))
            if let subdirs = try? FileManager.default.contentsOfDirectory(atPath: base) {
                for sub in subdirs where sub == "Default" || sub.hasPrefix("Profile ") {
                    let sessionDir = (base as NSString).appendingPathComponent("\(sub)/Sessions")
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: sessionDir, isDirectory: &isDir), isDir.boolValue {
                        if !possibleDirs.contains(sessionDir) {
                            possibleDirs.append(sessionDir)
                        }
                    }
                }
            }
        }
        
        var sessionFiles: [(path: String, mtime: Date, fileSize: UInt64)] = []
        for dir in possibleDirs {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                for file in files where file.hasPrefix("Session_") || file.hasPrefix("Tabs_") {
                    let fullPath = (dir as NSString).appendingPathComponent(file)
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                       let mtime = attrs[.modificationDate] as? Date {
                        // Consider sessions modified within the last 24 hours
                        if abs(mtime.timeIntervalSinceNow) < 86400 {
                            let fSize = (attrs[.size] as? NSNumber)?.uint64Value ?? 0
                            sessionFiles.append((fullPath, mtime, fSize))
                        }
                    }
                }
            }
        }
        sessionFiles.sort { $0.mtime > $1.mtime }
        
        let formPatterns = [
            "docs.google.com/forms", "forms.google.com", "forms.gle",
            "forms.office.com", "forms.microsoft.com", "typeform.com", "tally.so", "jotform.com",
            "tfaforms.net", "formassembly.com", "qualtrics.com", "fillout.com", "cognitoforms.com",
            "greenhouse.io", "lever.co", "myworkdayjobs.com", "ashbyhq.com", "smartrecruiters.com",
            "docusign.net", "adobesign.com", "pandadoc.com",
            "/viewform", "/formresponse"
        ]
        
        let browserHint = polarOnly ? "Polar" : targetBrowserAppName
        let now = Date()

        for (filePath, mtime, fSize) in sessionFiles.prefix(16) {
            let mtimeSec = mtime.timeIntervalSince1970
            sessionScanCacheLock.lock()
            let cached = sessionScanCache[filePath]
            sessionScanCacheLock.unlock()

            let extractedEntries: [(url: String, title: String)]
            if let hit = cached,
               abs(hit.mtime - mtimeSec) < 0.001,
               hit.fileSize == fSize,
               now.timeIntervalSince(hit.cachedAt) < sessionScanCacheTTL {
                extractedEntries = hit.entries
            } else {
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { continue }
                var parsed: [(url: String, title: String)] = []
                var seenURLs = Set<String>()
                
                for pattern in formPatterns {
                    guard let patternData = pattern.data(using: .utf8) else { continue }
                    var searchRange = data.startIndex..<data.endIndex
                    
                    while let range = data.range(of: patternData, options: [], in: searchRange) {
                        var urlStart = range.lowerBound
                        while urlStart > data.startIndex && data[urlStart - 1] >= 33 && data[urlStart - 1] <= 126 {
                            urlStart = data.index(before: urlStart)
                        }
                        var urlEnd = range.upperBound
                        while urlEnd < data.endIndex && data[urlEnd] >= 33 && data[urlEnd] <= 126 {
                            urlEnd = data.index(after: urlEnd)
                        }
                        
                        if let rawURL = String(data: data[urlStart..<urlEnd], encoding: .utf8) {
                            let trimmed = rawURL.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                            let cleanURL: String
                            if let httpIdx = trimmed.range(of: "http") {
                                cleanURL = String(trimmed[httpIdx.lowerBound...])
                            } else {
                                cleanURL = trimmed
                            }
                            
                            var foundTitle = ""
                            let limit = data.index(urlEnd, offsetBy: 300, limitedBy: data.endIndex) ?? data.endIndex
                            let postBytes = Array(data[urlEnd..<limit])
                            
                            // Chromium SNSS tab title starts within 16 bytes of the URL
                            if postBytes.count >= 8 {
                                for i in 0..<min(16, postBytes.count - 4) {
                                    if postBytes[i] >= 32 && postBytes[i] <= 126 && postBytes[i+1] == 0 {
                                        var titleBytes = [UInt8]()
                                        var j = i
                                        while j < postBytes.count - 1 && postBytes[j+1] == 0 && postBytes[j] >= 32 && postBytes[j] <= 126 {
                                            titleBytes.append(postBytes[j])
                                            titleBytes.append(postBytes[j+1])
                                            j += 2
                                        }
                                        if titleBytes.count >= 4, let tStr = String(data: Data(titleBytes), encoding: .utf16LittleEndian) {
                                            let tClean = tStr.trimmingCharacters(in: .whitespacesAndNewlines)
                                            if !tClean.contains("http") && !tClean.contains("://") && !tClean.contains(".com") && !tClean.contains(".org") && !tClean.contains("/forms") && !tClean.contains("uuid") && !tClean.contains("Blink") && tClean.count > 2 {
                                                foundTitle = tClean
                                                break
                                            }
                                        }
                                    }
                                }
                            }
                            
                            if foundTitle.localizedCaseInsensitiveContains("Page Not Found") {
                                searchRange = urlEnd..<data.endIndex
                                continue
                            }
                            
                            guard !FormExclusionRegistry.isBlacklistedURL(cleanURL) else {
                                searchRange = urlEnd..<data.endIndex
                                continue
                            }
                            
                            if !seenURLs.contains(cleanURL) {
                                seenURLs.insert(cleanURL)
                                let fallbackTitle = formNameFromURL(cleanURL) ?? "Google Form"
                                let resTitle = (foundTitle.isEmpty || foundTitle.contains("Page Not Found")) ? fallbackTitle : foundTitle
                                parsed.append((url: cleanURL, title: resTitle))
                            }
                        }
                        searchRange = urlEnd..<data.endIndex
                    }
                }
                
                sessionScanCacheLock.lock()
                sessionScanCache[filePath] = CachedSessionScan(
                    mtime: mtimeSec,
                    fileSize: fSize,
                    cachedAt: now,
                    entries: parsed
                )
                sessionScanCacheLock.unlock()
                extractedEntries = parsed
            }
            
            let hasURLFilter = (filterURL != nil && !filterURL!.isEmpty)
            let hasTitleFilter = (filterTitle != nil && !filterTitle!.isEmpty)
            
            for entry in extractedEntries {
                let cleanURL = entry.url
                let resTitle = entry.title
                
                if !hasURLFilter && !hasTitleFilter {
                    let finalTitle: String
                    if !resTitle.isEmpty && resTitle != "Google Form" {
                        finalTitle = resTitle
                    } else {
                        finalTitle = titleFromHistory(url: cleanURL, preferredBrowserName: browserHint) ?? resTitle
                    }
                    return (cleanURL, finalTitle)
                }
                
                if let fURL = filterURL, !fURL.isEmpty {
                    let cleanF = fURL.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
                    let cleanC = cleanURL.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
                    let idF = extractFormIdentifier(from: fURL)
                    let idC = extractFormIdentifier(from: cleanURL)
                    if (idF != nil && idC != nil && idF == idC) || cleanC.contains(cleanF) || cleanF.contains(cleanC) {
                        let finalTitle: String
                        if !resTitle.isEmpty && resTitle != "Google Form" {
                            finalTitle = resTitle
                        } else {
                            finalTitle = titleFromHistory(url: cleanURL, preferredBrowserName: browserHint) ?? resTitle
                        }
                        return (cleanURL, finalTitle)
                    }
                }
                
                if let filter = filterTitle, !filter.isEmpty {
                    let strippedFilter = stripServiceSuffixes(filter).trimmingCharacters(in: .whitespacesAndNewlines)
                    let strippedRes = stripServiceSuffixes(resTitle).trimmingCharacters(in: .whitespacesAndNewlines)
                    let genericNames = ["google forms", "google form", "untitled form", "application form", "polar", ""]
                    if !genericNames.contains(strippedFilter.lowercased()) {
                        let fLow = strippedFilter.lowercased()
                        let tLow = strippedRes.lowercased()
                        if tLow == fLow || (fLow.count >= 8 && tLow.count >= 8 && (tLow.hasPrefix(fLow) || fLow.hasPrefix(tLow))) {
                            let finalTitle: String
                            if !resTitle.isEmpty && resTitle != "Google Form" {
                                finalTitle = resTitle
                            } else {
                                finalTitle = titleFromHistory(url: cleanURL, preferredBrowserName: browserHint) ?? resTitle
                            }
                            return (cleanURL, finalTitle)
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Reads the active form URL and page title directly from Polar Chromium host session binary data
    public static func readPolarSessionForm(filterTitle: String? = nil, filterURL: String? = nil) -> (url: String, title: String)? {
        return readChromiumSessionForm(filterTitle: filterTitle, filterURL: filterURL, polarOnly: true)
    }
    
    /// Specialized check for Apple Safari: inspects the active tab of the front window only
    private func checkSafariBrowser() -> FormDetectionResult? {
        let safariApp = NSWorkspace.shared.runningApplications.first { app in
            !app.isTerminated && kill(app.processIdentifier, 0) == 0 &&
            app.activationPolicy == .regular &&
            (app.bundleIdentifier?.caseInsensitiveCompare("com.apple.safari") == .orderedSame ||
             app.localizedName?.caseInsensitiveCompare("safari") == .orderedSame)
        }
        guard let safariApp = safariApp else { return nil }
        
        var url = ""
        var rawTitle = ""
        
        let script = """
        tell application "Safari"
            if (count of windows) > 0 then
                try
                    set tabURL to (URL of current tab of front window)
                    set tabTitle to (name of current tab of front window)
                    return tabURL & " ||| " & tabTitle
                end try
            end if
            if (count of documents) > 0 then
                try
                    return (URL of front document) & " ||| " & (name of front document)
                end try
            end if
            return ""
        end tell
        """
        if let output = Self.executeSimpleAppleScript(script), !output.isEmpty {
            let parts = output.components(separatedBy: " ||| ")
            url = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            rawTitle = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        }
        
        // Native AXUIElement fallback if AppleScript was empty or failed (e.g. permission prompt)
        var safariWin: AXUIElement? = nil
        let appElem = AXUIElementCreateApplication(safariApp.processIdentifier)
        safariWin = Self.getBrowserWindowElement(appElem: appElem)
        if url.isEmpty || rawTitle.isEmpty {
            if let win = safariWin {
                if url.isEmpty {
                    url = Self.findAddressBarOrWebAreaURL(in: win) ?? ""
                }
                if rawTitle.isEmpty {
                    var tRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &tRef) == .success,
                       let t = tRef as? String {
                        rawTitle = t.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }
        
        // Strict Immediate Rejection: if address bar has a blacklisted non-form URL
        if !url.isEmpty && FormExclusionRegistry.isBlacklistedURL(url) {
            return nil
        }
        
        let isDetectedByURL = !url.isEmpty && Self.isFormURL(url)
        let cleaned = Self.cleanTitle(rawTitle)
        let isDetectedByTitle = (!rawTitle.isEmpty && Self.isFormTitle(rawTitle)) || (!cleaned.isEmpty && Self.isFormTitle(cleaned))
        
        // Strict suppression if active window content is known and not a form
        let hasActiveContent = (!cleaned.isEmpty && cleaned.lowercased() != "safari") || !url.isEmpty
        if hasActiveContent && !isDetectedByURL && !isDetectedByTitle {
            return nil
        }
        
        if isDetectedByURL || isDetectedByTitle {
            let finalTitle: String
            if cleaned.isEmpty || cleaned.localizedCaseInsensitiveContains("not found") || cleaned.localizedCaseInsensitiveContains("untitled") {
                finalTitle = Self.formNameFromURL(url) ?? "Google Form"
            } else {
                finalTitle = cleaned
            }
            let (screenIdx, screenName) = safariWin != nil ? Self.screenForWindow(safariWin!) : (nil, nil)
            return FormDetectionResult(
                isDetected: true,
                title: finalTitle,
                appName: "Safari",
                url: isDetectedByURL ? url : nil,
                browserFamily: .safari,
                screenIndex: screenIdx,
                screenName: screenName
            )
        }
        return nil
    }
    
    /// Specialized check for Chromium family (Chrome, Brave, Edge, Arc, Opera, Vivaldi): inspects the active tab of the front window only
    private func checkChromiumBrowser(appName: String, bundleID: String? = nil, app: NSRunningApplication? = nil) -> FormDetectionResult? {
        let runningApp = app ?? NSWorkspace.shared.runningApplications.first { a in
            !a.isTerminated && kill(a.processIdentifier, 0) == 0 &&
            (a.localizedName?.lowercased() == appName.lowercased() ||
             (bundleID != nil && a.bundleIdentifier?.lowercased() == bundleID!.lowercased()))
        }
        guard let runningApp = runningApp else { return nil }
        
        let appElem = AXUIElementCreateApplication(runningApp.processIdentifier)
        let activeWin = Self.getBrowserWindowElement(appElem: appElem)
        
        var axURL: String? = nil
        var axTitle: String? = nil
        if let win = activeWin {
            axURL = Self.findAddressBarOrWebAreaURL(in: win)
            var tRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &tRef) == .success,
               let t = tRef as? String {
                axTitle = t.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        let bID = bundleID ?? runningApp.bundleIdentifier ?? ""
        let appTarget = !bID.isEmpty ? "application id \"\(bID)\"" : "application \"\(appName)\""
        let script = """
        tell \(appTarget)
            if (count of windows) > 0 then
                try
                    set tabURL to (URL of active tab of front window)
                    set tabTitle to (title of active tab of front window)
                    return tabURL & " ||| " & tabTitle
                end try
            end if
            return ""
        end tell
        """
        let output = Self.executeSimpleAppleScript(script)
        var scriptURL = ""
        var scriptTitle = ""
        if let out = output, !out.isEmpty {
            let parts = out.components(separatedBy: " ||| ")
            scriptURL = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            scriptTitle = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        }
        
        let url = !scriptURL.isEmpty ? scriptURL : (axURL ?? "")
        let rawTitle = !scriptTitle.isEmpty ? scriptTitle : (axTitle ?? "")
        
        // Strict Immediate Rejection: if address bar has a blacklisted non-form URL
        if !url.isEmpty && FormExclusionRegistry.isBlacklistedURL(url) {
            return nil
        }
        
        let isDetectedByURL = !url.isEmpty && Self.isFormURL(url)
        let cleaned = Self.cleanTitle(rawTitle)
        let isDetectedByTitle = (!rawTitle.isEmpty && Self.isFormTitle(rawTitle)) || (!cleaned.isEmpty && Self.isFormTitle(cleaned))
        
        // Strict suppression if active window content is known and not a form
        let hasActiveContent = (!cleaned.isEmpty && cleaned.lowercased() != appName.lowercased()) || !url.isEmpty
        if hasActiveContent && !isDetectedByURL && !isDetectedByTitle {
            return nil
        }
        
        var sessionMatch: (url: String, title: String)? = nil
        let strippedTitle = Self.stripServiceSuffixes(cleaned)
        let genericTitles = ["", "google forms", "google form", "untitled form", "application form", appName.lowercased()]
        let isSpecificTitle = !genericTitles.contains(strippedTitle.lowercased())
        if (isDetectedByURL || isDetectedByTitle) && (url.isEmpty || !isSpecificTitle) {
            sessionMatch = Self.readChromiumSessionForm(
                filterTitle: isSpecificTitle ? strippedTitle : nil,
                filterURL: !url.isEmpty ? url : nil,
                polarOnly: false,
                targetBrowserAppName: appName
            )
        }
        
        if isDetectedByURL || isDetectedByTitle || sessionMatch != nil {
            let finalURL = !url.isEmpty ? url : sessionMatch?.url
            let baseTitle = isSpecificTitle ? cleaned : (sessionMatch?.title ?? (finalURL.flatMap { Self.formNameFromURL($0) } ?? (cleaned.isEmpty ? "Google Form" : cleaned)))
            let (screenIdx, screenName) = activeWin != nil ? Self.screenForWindow(activeWin!) : (nil, nil)
            return FormDetectionResult(
                isDetected: true,
                title: baseTitle,
                appName: appName,
                url: finalURL,
                browserFamily: .chromium,
                screenIndex: screenIdx,
                screenName: screenName
            )
        }
        return nil
    }
    
    /// Specialized check for Gecko family (Firefox, Zen Browser, Floorp, Waterfox, LibreWolf, Tor)
    private func checkGeckoBrowser(appName: String) -> FormDetectionResult? {
        guard AXIsProcessTrusted() else { return nil }
        
        // 1. Direct native AXUIElement check on Gecko process
        if let geckoApp = NSWorkspace.shared.runningApplications.first(where: {
            !$0.isTerminated &&
            ($0.localizedName?.caseInsensitiveCompare(appName) == .orderedSame ||
             ($0.bundleIdentifier?.lowercased().contains(appName.lowercased()) ?? false))
        }) {
            let appElem = AXUIElementCreateApplication(geckoApp.processIdentifier)
            if let win = Self.getBrowserWindowElement(appElem: appElem) {
                var tRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &tRef) == .success,
                   let t = (tRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !t.isEmpty {
                    let axURL = Self.findAddressBarOrWebAreaURL(in: win) ?? ""
                    let cleaned = Self.cleanTitle(t)
                    let isURLForm = !axURL.isEmpty && Self.isFormURL(axURL)
                    let isTitleForm = Self.isFormTitle(t) || Self.isFormTitle(cleaned)
                    
                    if !axURL.isEmpty && FormExclusionRegistry.isBlacklistedURL(axURL) {
                        return nil
                    }
                    
                    if isURLForm || isTitleForm {
                        let finalTitle = (!cleaned.isEmpty && !cleaned.localizedCaseInsensitiveContains("untitled")) ? cleaned : ((!axURL.isEmpty ? Self.formNameFromURL(axURL) : nil) ?? "Google Form")
                        let (sIdx, sName) = Self.screenForWindow(win)
                        return FormDetectionResult(
                            isDetected: true,
                            title: finalTitle,
                            appName: appName,
                            url: isURLForm ? axURL : nil,
                            browserFamily: .gecko,
                            screenIndex: sIdx,
                            screenName: sName
                        )
                    }
                }
            }
        }
        
        // 2. System Events AppleScript fallback
        let script = """
        tell application "System Events"
            if exists process "\(appName)" then
                tell process "\(appName)"
                    set fallbackVal to ""
                    set fallbackTitle to ""
                    repeat with w in windows
                        set winTitle to name of w
                        if winTitle is not "" then
                            set foundURL to ""
                            repeat with el in (text fields of w & combo boxes of w)
                                try
                                    set v to (value of el as string)
                                    if v is not "" then
                                        set foundURL to v
                                        exit repeat
                                    end if
                                end try
                            end repeat
                            if foundURL is "" then
                                repeat with g in groups of w
                                    repeat with el in (text fields of g & combo boxes of g)
                                        try
                                            set v to (value of el as string)
                                            if v is not "" then
                                                set foundURL to v
                                                exit repeat
                                            end if
                                        end try
                                    end repeat
                                    if foundURL is not "" then exit repeat
                                end repeat
                            end if
                            
                            if foundURL is not "" or winTitle is not "" then
                                if fallbackVal is "" then
                                    set fallbackVal to foundURL
                                    set fallbackTitle to winTitle
                                end if
                                if foundURL contains "forms" or foundURL contains "/viewform" or foundURL contains "formResponse" or foundURL contains "forms.gle" or foundURL contains "typeform" or foundURL contains "tally.so" or foundURL contains "quiz" or winTitle contains "Form" or winTitle contains "Quiz" or winTitle contains "Survey" or winTitle contains "Application" or winTitle contains "Registration" then
                                    return foundURL & " ||| " & winTitle
                                end if
                            end if
                        end if
                    end repeat
                    if fallbackVal is not "" or fallbackTitle is not "" then
                        return fallbackVal & " ||| " & fallbackTitle
                    end if
                end tell
            end if
            return ""
        end tell
        """
        guard let output = Self.executeSimpleAppleScript(script), !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: " ||| ")
        let url = parts.first?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        let rawTitle = parts.count > 1 ? parts[1].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) : ""
        
        let cleaned = Self.cleanTitle(rawTitle)
        let isDetectedByURL = !url.isEmpty && Self.isFormURL(url)
        let isDetectedByTitle = (!rawTitle.isEmpty && Self.isFormTitle(rawTitle)) || (!cleaned.isEmpty && Self.isFormTitle(cleaned))
        
        if isDetectedByURL || isDetectedByTitle {
            let finalTitle: String
            if cleaned.isEmpty || cleaned.localizedCaseInsensitiveContains("not found") || cleaned.localizedCaseInsensitiveContains("untitled") {
                finalTitle = Self.formNameFromURL(url) ?? "Google Form"
            } else {
                finalTitle = cleaned
            }
            return FormDetectionResult(
                isDetected: true,
                title: finalTitle,
                appName: appName,
                url: isDetectedByURL ? url : nil,
                browserFamily: .gecko
            )
        }
        return nil
    }

    /// Specialized check for WebKit shells (Orion, DuckDuckGo): inspects active tab of front window only
    private func checkWebKitBrowser(appName: String) -> FormDetectionResult? {
        // 1. Direct native AXUIElement check
        if let webkitApp = NSWorkspace.shared.runningApplications.first(where: {
            !$0.isTerminated &&
            ($0.localizedName?.caseInsensitiveCompare(appName) == .orderedSame ||
             ($0.bundleIdentifier?.lowercased().contains(appName.lowercased()) ?? false))
        }) {
            let appElem = AXUIElementCreateApplication(webkitApp.processIdentifier)
            if let win = Self.getBrowserWindowElement(appElem: appElem) {
                var tRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &tRef) == .success,
                   let t = (tRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !t.isEmpty {
                    let axURL = Self.findAddressBarOrWebAreaURL(in: win) ?? ""
                    let cleaned = Self.cleanTitle(t)
                    let isURLForm = !axURL.isEmpty && Self.isFormURL(axURL)
                    let isTitleForm = Self.isFormTitle(t) || Self.isFormTitle(cleaned)
                    
                    if !axURL.isEmpty && FormExclusionRegistry.isBlacklistedURL(axURL) {
                        return nil
                    }
                    
                    if isURLForm || isTitleForm {
                        let finalTitle = (!cleaned.isEmpty && !cleaned.localizedCaseInsensitiveContains("untitled")) ? cleaned : ((!axURL.isEmpty ? Self.formNameFromURL(axURL) : nil) ?? "Google Form")
                        let (sIdx, sName) = Self.screenForWindow(win)
                        return FormDetectionResult(
                            isDetected: true,
                            title: finalTitle,
                            appName: appName,
                            url: isURLForm ? axURL : nil,
                            browserFamily: .webkit,
                            screenIndex: sIdx,
                            screenName: sName
                        )
                    }
                }
            }
        }
        
        let lower = appName.lowercased()
        if lower.contains("orion") {
            let script = """
            tell application "Orion"
                if (count of windows) > 0 then
                    try
                        set curURL to (URL of current tab of front window)
                        set curTitle to (name of current tab of front window)
                        if curURL contains "forms" or curURL contains "form" or curURL contains "quiz" or curTitle contains "Form" or curTitle contains "Quiz" or curTitle contains "Survey" or curTitle contains "Application" then
                            return curURL & " ||| " & curTitle
                        end if
                    end try
                end if
                return ""
            end tell
            """
            if let output = Self.executeSimpleAppleScript(script), !output.isEmpty {
                let parts = output.components(separatedBy: " ||| ")
                let url = parts.first?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
                let rawTitle = parts.count > 1 ? parts[1].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) : ""
                let cleaned = Self.cleanTitle(rawTitle)
                let isDetectedByURL = !url.isEmpty && Self.isFormURL(url)
                let isDetectedByTitle = (!rawTitle.isEmpty && Self.isFormTitle(rawTitle)) || (!cleaned.isEmpty && Self.isFormTitle(cleaned))
                if isDetectedByURL || isDetectedByTitle {
                    let finalTitle = (cleaned.isEmpty || cleaned.localizedCaseInsensitiveContains("not found") || cleaned.localizedCaseInsensitiveContains("untitled")) ? (Self.formNameFromURL(url) ?? "Google Form") : cleaned
                    return FormDetectionResult(
                        isDetected: true,
                        title: finalTitle,
                        appName: appName,
                        url: isDetectedByURL ? url : nil,
                        browserFamily: .webkit
                    )
                }
            }
        }
        
        return checkGeckoBrowser(appName: appName)
    }

    /// Universal AXUIElement inspection for generic or custom browser applications
    private func checkGenericBrowser(app: NSRunningApplication) -> FormDetectionResult? {
        let pid = app.processIdentifier
        let appName = app.localizedName ?? "Browser"
        let appElem = AXUIElementCreateApplication(pid)
        guard let win = Self.getBrowserWindowElement(appElem: appElem) else { return nil }
        
        var titleRef: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
        let rawTitle = titleRef as? String ?? ""
        
        let url = Self.findAddressBarOrWebAreaURL(in: win)
        let cleaned = Self.cleanTitle(rawTitle)
        let isDetectedByURL = url != nil && Self.isFormURL(url!)
        let isDetectedByTitle = (!rawTitle.isEmpty && Self.isFormTitle(rawTitle)) || (!cleaned.isEmpty && Self.isFormTitle(cleaned))
        
        if isDetectedByURL || isDetectedByTitle {
            let finalTitle: String
            if cleaned.isEmpty || cleaned.localizedCaseInsensitiveContains("not found") || cleaned.localizedCaseInsensitiveContains("untitled") {
                finalTitle = (url != nil ? Self.formNameFromURL(url!) : nil) ?? "Google Form"
            } else {
                finalTitle = cleaned
            }
            let (screenIdx, screenName) = Self.screenForWindow(win)
            return FormDetectionResult(
                isDetected: true,
                title: finalTitle,
                appName: appName,
                url: url,
                browserFamily: .unknown,
                screenIndex: screenIdx,
                screenName: screenName
            )
        }
        return nil
    }

    /// Dispatches a specialized form check tailored to the browser engine family
    private func checkBrowserByFamily(family: BrowserEngineFamily, appName: String, bundleID: String, app: NSRunningApplication? = nil) -> FormDetectionResult? {
        var res: FormDetectionResult? = nil
        switch family {
        case .polar:
            res = Self.checkPolarBrowser()
        case .safari:
            res = checkSafariBrowser()
        case .chromium:
            res = checkChromiumBrowser(appName: appName, bundleID: bundleID, app: app)
        case .gecko:
            res = checkGeckoBrowser(appName: appName)
        case .webkit:
            res = checkWebKitBrowser(appName: appName)
        case .unknown:
            if let app = app {
                res = checkGenericBrowser(app: app)
            }
        }
        
        if let r = res, r.isDetected {
            return r
        }
        
        // Universal AXUIElement fallback for any browser if AppleScript returned nothing or failed
        if let app = app {
            if let axRes = checkGenericBrowser(app: app), axRes.isDetected {
                return axRes
            }
        }
        return nil
    }
    
    private func checkRunningBrowsersForFormURLs(windowList: [[String: Any]]? = nil) -> FormDetectionResult? {
        let rankedBrowsers = PersonalizedBrowserDetector.rankedRunningBrowsers()
        for browser in rankedBrowsers {
            let bID = (browser.bundleIdentifier ?? "").lowercased()
            let name = browser.localizedName ?? "Browser"
            let family = PersonalizedBrowserDetector.engineFamily(for: bID, name: name)
            if let result = checkBrowserByFamily(family: family, appName: name, bundleID: bID, app: browser) {
                return result
            }
        }
        return nil
    }
    
    // MARK: - Detect Active Form Across Frontmost Application Context
    public func detectActiveApplicationForm() -> FormDetectionResult {
        // 1. Inspect Frontmost Application context
        guard var frontApp = NSWorkspace.shared.frontmostApplication else {
            return FormDetectionResult(isDetected: false)
        }
        
        if !MorphEnvironment.isTestingEnvironment {
            let onScreenWindows = (CGWindowListCopyWindowInfo([.excludeDesktopElements, .optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
            let systemOwners: Set<String> = [
                "morph", "windowserver", "dock", "control center", "controlcenter",
                "notification center", "notificationcenter", "systemuiserver", "wallpaper",
                "spotlight", "universalcontrol", "loginwindow"
            ]
            
            let frontBundle = frontApp.bundleIdentifier?.lowercased() ?? ""
            let frontName = frontApp.localizedName?.lowercased() ?? ""
            let isMorphFront = frontBundle.contains("com.morph.") || frontBundle == "morph" || frontBundle.hasSuffix(".morph") || frontName == "morph"
            
            let frontAppHasOnScreenWindow = onScreenWindows.contains { win in
                let pid = win[kCGWindowOwnerPID as String] as? pid_t ?? 0
                let layer = win[kCGWindowLayer as String] as? Int ?? -1
                let bounds = win[kCGWindowBounds as String] as? [String: Any] ?? [:]
                let h = bounds["Height"] as? CGFloat ?? 0
                let w = bounds["Width"] as? CGFloat ?? 0
                return pid == frontApp.processIdentifier && layer == 0 && h > 100 && w > 100
            }
            
            if isMorphFront || !frontAppHasOnScreenWindow {
                var resolvedApp: NSRunningApplication? = nil
                for win in onScreenWindows {
                    let layer = win[kCGWindowLayer as String] as? Int ?? -1
                    guard layer == 0 else { continue }
                    let bounds = win[kCGWindowBounds as String] as? [String: Any] ?? [:]
                    let h = bounds["Height"] as? CGFloat ?? 0
                    let w = bounds["Width"] as? CGFloat ?? 0
                    let alpha = win[kCGWindowAlpha as String] as? CGFloat ?? 1.0
                    guard h > 100 && w > 100 && alpha > 0.01 else { continue }
                    let owner = (win[kCGWindowOwnerName as String] as? String ?? "").lowercased()
                    if systemOwners.contains(owner) || owner == "polar host" { continue }
                    if let pid = win[kCGWindowOwnerPID as String] as? pid_t,
                       let app = NSRunningApplication(processIdentifier: pid),
                       !app.isTerminated {
                        let bID = app.bundleIdentifier?.lowercased() ?? ""
                        if bID.contains("com.morph.") || bID == "morph" || bID.hasSuffix(".morph") { continue }
                        resolvedApp = app
                        break
                    }
                }
                if let resolved = resolvedApp {
                    frontApp = resolved
                } else {
                    return FormDetectionResult(isDetected: false)
                }
            }
        }
        
        let bundleID = frontApp.bundleIdentifier?.lowercased() ?? ""
        let frontAppName = frontApp.localizedName ?? "Application"
        let frontPID = frontApp.processIdentifier
        
        // If frontmost application is a browser:
        if Self.isBrowserApplication(frontApp) {
            let family = PersonalizedBrowserDetector.engineFamily(for: bundleID, name: frontAppName)
            if let result = checkBrowserByFamily(family: family, appName: frontAppName, bundleID: bundleID, app: frontApp), result.isDetected {
                NSLog("[MORPH-FORM] Frontmost browser %@ MATCHED active form: title=%@, url=%@", frontAppName, result.title ?? "nil", result.url ?? "nil")
                return result
            }
            
            // Frontmost browser active tab is NOT a form (user navigated away or switched tabs)
            // Strictly return not detected so Morph immediately collapses to the transparent resting state.
            return FormDetectionResult(isDetected: false)
        }
        
        // If frontmost application is a dedicated PDF viewer viewing an actual .pdf document
        let isPDFReader = bundleID.contains("preview") || bundleID.contains("adobe.reader") || bundleID.contains("adobe.acrobat") || bundleID.contains("pdf")
        if isPDFReader {
            let appElem = AXUIElementCreateApplication(frontPID)
            if let winElement = Self.getBrowserWindowElement(appElem: appElem) {
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(winElement, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let rawTitle = titleRef as? String {
                    let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    if title.lowercased().hasSuffix(".pdf") && Self.isFormTitle(title) {
                        let (sIdx, sName) = Self.screenForWindow(winElement)
                        return FormDetectionResult(
                            isDetected: true,
                            title: Self.cleanTitle(title),
                            appName: frontAppName,
                            url: nil,
                            browserFamily: nil,
                            screenIndex: sIdx,
                            screenName: sName
                        )
                    }
                }
            }
            return FormDetectionResult(isDetected: false)
        }
        
        // 2. Frontmost application is NOT a browser and NOT a form document:
        // The user is on a window where there isn't any browser and form open (Terminal, Finder, Notes, Code, etc.)
        // Strictly return not detected so Morph immediately collapses to the transparent resting state.
        return FormDetectionResult(isDetected: false)
    }
    
    public static func formNameFromURL(_ urlString: String) -> String? {
        let lower = urlString.lowercased()
        for p in FormPlatformRegistry.platforms {
            for hostMatch in p.hostMatches {
                if lower.contains(hostMatch) {
                    if p.pathPrefixes.isEmpty || p.pathPrefixes.contains(where: { lower.contains($0.lowercased()) }) {
                        return p.defaultFormName
                    }
                }
            }
        }
        if lower.contains("myworkdayjobs.com") || lower.contains("workday.com") {
            return "Workday Job Application"
        }
        if lower.contains("careers") || lower.contains("jobs") {
            return "Job Application"
        }
        if lower.contains(".edu") && (lower.contains("apply") || lower.contains("admissions")) {
            return "University Application"
        }
        return nil
    }
}

public struct MockApplicationFormDetector: ApplicationFormDetectorProtocol {
    public var detected: Bool
    public var title: String?
    public var appName: String?
    public var url: String?
    public var screenIndex: Int?
    public var screenName: String?
    
    public init(
        detected: Bool = false,
        title: String? = nil,
        appName: String? = nil,
        url: String? = nil,
        screenIndex: Int? = nil,
        screenName: String? = nil
    ) {
        self.detected = detected
        self.title = title
        self.appName = appName
        self.url = url
        self.screenIndex = screenIndex
        self.screenName = screenName
    }
    
    public func detectActiveApplicationForm() -> FormDetectionResult {
        return FormDetectionResult(
            isDetected: detected,
            title: title,
            appName: appName,
            url: url,
            screenIndex: screenIndex,
            screenName: screenName
        )
    }
}

// MARK: - Email Dispatcher Protocols
public struct EmailDispatchResult: Sendable, Equatable {
    public var success: Bool
    public var message: String
    public var messageId: String?
    public var dispatchedAt: Date
    
    public init(success: Bool, message: String, messageId: String? = nil, dispatchedAt: Date = Date()) {
        self.success = success
        self.message = message
        self.messageId = messageId
        self.dispatchedAt = dispatchedAt
    }
}

@MainActor
public protocol ApplicationEmailDispatcherProtocol: Sendable {
    func dispatchCopy(session: ApplicationFormSession) async throws -> EmailDispatchResult
}

public struct DefaultEmailDispatcher: ApplicationEmailDispatcherProtocol {
    public init() {}
    
    @MainActor
    public func dispatchCopy(session: ApplicationFormSession) async throws -> EmailDispatchResult {
        // Scrapped emailing receipt: archive session snapshot directly to Supabase Memory Storage
        let answers = session.fields.reduce(into: [String: String]()) { $0[$1.label] = $1.value }
        let meta = (try? String(data: JSONEncoder().encode(answers), encoding: .utf8)) ?? "{}"
        let memory = GlassMemoryItem(
            id: session.id.uuidString,
            kind: "form",
            title: session.formTitle.isEmpty ? "Application Form" : session.formTitle,
            body: session.formattedSummary,
            metaJSON: meta
        )
        await SupabaseService.shared.saveMemoryItem(memory)
        return EmailDispatchResult(success: true, message: "Archived to Supabase Memory Storage", messageId: session.id.uuidString)
    }
}

@MainActor
public final class MockEmailDispatcher: ApplicationEmailDispatcherProtocol, @unchecked Sendable {
    public private(set) var dispatchedSessions: [ApplicationFormSession] = []
    public var shouldSucceed: Bool = true
    public var failureMessage: String = "Simulated dispatch failure"
    
    public init(shouldSucceed: Bool = true) {
        self.shouldSucceed = shouldSucceed
    }
    
    public func dispatchCopy(session: ApplicationFormSession) async throws -> EmailDispatchResult {
        if shouldSucceed {
            dispatchedSessions.append(session)
            return EmailDispatchResult(success: true, message: "Mock sent to \(session.recipientEmail)")
        } else {
            return EmailDispatchResult(success: false, message: failureMessage)
        }
    }
    
    public func reset() {
        dispatchedSessions.removeAll()
    }
}

// MARK: - Autonomous Form Content Retriever
public struct FormContentRetriever: Sendable {
    public static let shared = FormContentRetriever()
    
    public init() {}
    
    public typealias RetrievedFormSchema = FormSchema
    
    /// Detects whether an HTML page represents a closed, expired, or deadline-passed form
    public static func detectFormClosedState(html: String) -> (isClosed: Bool, message: String?) {
        let lower = html.lowercased()
        let isSubmittedScreen = lower.contains("your response has been recorded") ||
                                lower.contains("submit another response")
        
        let isClosedGForm = (!isSubmittedScreen && lower.contains("freebirdformviewerviewresponseconfirmationmessage")) ||
                            lower.contains("this form is no longer accepting responses") ||
                            lower.contains("is no longer accepting responses") ||
                            lower.contains("no longer accepting responses") ||
                            lower.contains("deadline has passed") ||
                            lower.contains("deadline has expired") ||
                            lower.contains("submissions are closed") ||
                            lower.contains("submissions have closed") ||
                            lower.contains("this form is closed") ||
                            lower.contains("form is closed") ||
                            lower.contains("you've already responded") ||
                            lower.contains("you have already responded") ||
                            lower.contains("you need permission") ||
                            lower.contains("only be viewed by users in the owner's organization")
        
        guard isClosedGForm else { return (false, nil) }
        
        if lower.contains("no longer accepting responses") {
            return (true, "This form is no longer accepting responses.")
        } else if lower.contains("deadline has passed") || lower.contains("deadline has expired") {
            return (true, "The submission deadline for this form has passed.")
        } else if lower.contains("submissions are closed") || lower.contains("submissions have closed") || lower.contains("form is closed") {
            return (true, "Submissions for this form are currently closed.")
        } else if lower.contains("already responded") {
            return (true, "You've already responded to this form.")
        } else if lower.contains("need permission") || lower.contains("organization") {
            return (true, "You need permission to access this form.")
        } else {
            return (true, "This form is closed.")
        }
    }
    
    /// Parses Google Form FB_PUBLIC_LOAD_DATA_ from HTML or raw JSON
    public static func parseGoogleFormPublicLoadData(_ htmlOrJson: String) -> RetrievedFormSchema? {
        let closedCheck = detectFormClosedState(html: htmlOrJson)
        if closedCheck.isClosed {
            return RetrievedFormSchema(title: "Google Form", description: "", fields: [], isClosed: true, closedMessage: closedCheck.message)
        }
        
        let jsonString: String
        if let startRange = htmlOrJson.range(of: "FB_PUBLIC_LOAD_DATA_ = ") {
            let rest = htmlOrJson[startRange.upperBound...]
            if let endRange = rest.range(of: ";</script>") {
                jsonString = String(rest[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let endSemi = rest.range(of: ";") {
                jsonString = String(rest[..<endSemi.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                jsonString = String(rest).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            jsonString = htmlOrJson.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard let data = jsonString.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [Any],
              root.count > 1,
              let inner = root[1] as? [Any] else {
            return nil
        }
        
        let formTitle = inner.count > 8 ? (inner[8] as? String ?? "") : ""
        let formDesc = inner.count > 0 ? (inner[0] as? String ?? "") : ""
        let questions = inner.count > 1 ? (inner[1] as? [Any] ?? []) : []
        
        var fields: [FormInputField] = []
        for q in questions {
            guard let qArr = q as? [Any] else { continue }
            let prompt = qArr.count > 1 ? (qArr[1] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines) : ""
            guard !prompt.isEmpty else { continue }
            
            let subtext = qArr.count > 2 ? (qArr[2] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines) : ""
            let rawType = qArr.count > 3 ? (qArr[3] as? Int ?? 0) : 0
            
            let entries = qArr.count > 4 ? (qArr[4] as? [[Any?]] ?? []) : []
            let firstEntry = entries.first
            
            let entryId = firstEntry?.first as? Int
            let entryKey = entryId != nil ? "entry.\(entryId!)" : nil
            
            func extractOptions(from optList: [[Any?]]) -> [String] {
                var parsed: [String] = []
                for opt in optList {
                    if let str = opt.first as? String {
                        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty && trimmed != "__other_option__" {
                            if !parsed.contains(trimmed) { parsed.append(trimmed) }
                            continue
                        }
                    }
                    if opt.count > 4, let otherFlag = opt[4] as? Int, otherFlag == 1 {
                        if !parsed.contains("Other") { parsed.append("Other") }
                    }
                }
                return parsed
            }
            
            var options: [String] = []
            if let first = firstEntry, first.count > 1, let optList = first[1] as? [[Any?]] {
                options = extractOptions(from: optList)
            }
            if options.isEmpty {
                for entry in entries {
                    if entry.count > 1, let optList = entry[1] as? [[Any?]] {
                        let candidate = extractOptions(from: optList)
                        if !candidate.isEmpty {
                            options = candidate
                            break
                        }
                    }
                }
            }
            
            var isRequired = false
            for entry in entries {
                if entry.count > 2, let reqInt = entry[2] as? Int, reqInt == 1 {
                    isRequired = true
                    break
                }
            }
            if !isRequired, let first = firstEntry, first.count > 2, let reqInt = first[2] as? Int {
                isRequired = (reqInt == 1)
            }
            if !isRequired && (prompt.hasSuffix("*") || prompt.contains(" *") || subtext.localizedCaseInsensitiveContains("required")) {
                isRequired = true
            }
            
            let promptLines = prompt.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let titleLine = promptLines.first ?? prompt
            let cleanPrompt = titleLine.replacingOccurrences(of: "\\s*\\*+\\s*$", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanPrompt.isEmpty else { continue }
            
            let extraDesc = promptLines.dropFirst().joined(separator: "\n")
            var combinedDesc: String
            if !subtext.isEmpty {
                combinedDesc = extraDesc.isEmpty ? subtext : (extraDesc + "\n" + subtext)
            } else {
                combinedDesc = extraDesc
            }
            
            let qType: String
            let cat: FormFieldCategory
            switch rawType {
            case 0:
                qType = "shortAnswer"
                cat = inferCategory(from: cleanPrompt)
            case 1:
                qType = "paragraph"
                cat = .question
            case 2:
                qType = "multipleChoice"
                cat = .question
            case 3:
                qType = "dropdown"
                cat = .question
            case 4:
                qType = "checkboxes"
                cat = .question
            case 5:
                qType = "linearScale"
                cat = .question
                if let first = firstEntry, first.count > 3, let bounds = first[3] as? [Any] {
                    let labels = bounds.compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    if labels.count >= 2 && !combinedDesc.contains(labels[0]) {
                        let scaleHint = "Scale: \(labels[0]) to \(labels[1])"
                        combinedDesc = combinedDesc.isEmpty ? scaleHint : "\(combinedDesc)\n\(scaleHint)"
                    }
                }
            case 6:
                qType = "info"
                cat = .custom
            case 7:
                qType = "grid"
                cat = .question
            case 8:
                qType = "section"
                cat = .custom
            case 9:
                qType = "date"
                cat = .personal
            case 10:
                qType = "time"
                cat = .personal
            case 11:
                qType = "info"
                cat = .custom
            case 13:
                qType = "fileUpload"
                cat = .custom
            default:
                if entryKey == nil {
                    qType = "info"
                    cat = .custom
                } else {
                    qType = "shortAnswer"
                    cat = inferCategory(from: cleanPrompt)
                }
            }
            
            // Grid questions (rawType 7) contain one entry per grid row; expand rows when row labels exist.
            if rawType == 7 && !entries.isEmpty {
                var expandedRows: [FormInputField] = []
                for entry in entries {
                    let rowEntryId = entry.first as? Int
                    let rowEntryKey = rowEntryId != nil ? "entry.\(rowEntryId!)" : entryKey
                    let rowLabel: String? = {
                        if entry.count > 3, let arr = entry[3] as? [Any], let firstStr = arr.first as? String {
                            let t = firstStr.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !t.isEmpty { return t }
                        }
                        if entry.count > 3, let str = entry[3] as? String {
                            let t = str.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !t.isEmpty { return t }
                        }
                        return nil
                    }()
                    let rowOpts: [String] = {
                        if entry.count > 1, let optList = entry[1] as? [[Any?]] {
                            let parsed = extractOptions(from: optList)
                            if !parsed.isEmpty { return parsed }
                        }
                        return options
                    }()
                    let rowReq = (entry.count > 2 && (entry[2] as? Int) == 1) || isRequired
                    if let rLbl = rowLabel {
                        expandedRows.append(FormInputField(
                            label: "\(cleanPrompt) [\(rLbl)]",
                            value: "",
                            category: cat,
                            questionDescription: combinedDesc,
                            options: rowOpts,
                            questionType: "grid",
                            isRequired: rowReq,
                            entryKey: rowEntryKey
                        ))
                    }
                }
                if !expandedRows.isEmpty && (expandedRows.count == entries.count || entries.count > 1) {
                    fields.append(contentsOf: expandedRows)
                    continue
                }
            }
            
            let finalQType = (entryKey == nil && qType != "info" && qType != "section") ? "info" : qType
            let finalIsRequired = (finalQType == "info" || finalQType == "section") ? false : isRequired
            
            let field = FormInputField(
                label: cleanPrompt,
                value: "",
                category: cat,
                questionDescription: combinedDesc,
                options: options,
                questionType: finalQType,
                isRequired: finalIsRequired,
                entryKey: entryKey
            )
            fields.append(field)
        }
        
        return RetrievedFormSchema(title: formTitle, description: formDesc, fields: fields)
    }
    
    public static func inferCategory(from key: String) -> FormFieldCategory {
        let k = key.lowercased()
        if k.contains("name") || k.contains("pronoun") || k.contains("birth") || k.contains("citizenship") {
            return .personal
        } else if k.contains("email") || k.contains("phone") || k.contains("address") || k.contains("linkedin") || k.contains("github") || k.contains("portfolio") || k.contains("website") || k.contains("contact") {
            return .contact
        } else if k.contains("experience") || k.contains("salary") || k.contains("compensation") || k.contains("education") || k.contains("school") || k.contains("degree") || k.contains("company") || k.contains("title") || k.contains("skills") || k.contains("credential") || k.contains("institution") || k.contains("academy") {
            return .experience
        } else if k.contains("why") || k.contains("tell us") || k.contains("cover letter") || k.contains("statement") || k.contains("question") || k.contains("challenge") || k.contains("summary") || k.contains("project") || k.contains("role") {
            return .question
        }
        return .custom
    }
    
    // MARK: - Query Parameter Extraction
    public static func extractQueryParameters(from urlString: String) -> [String: String] {
        guard let comps = URLComponents(string: urlString), let items = comps.queryItems else {
            guard let qIdx = urlString.firstIndex(of: "?") else { return [:] }
            let qStr = String(urlString[urlString.index(after: qIdx)...])
            var res: [String: String] = [:]
            for pair in qStr.components(separatedBy: "&") {
                let parts = pair.components(separatedBy: "=")
                if parts.count >= 2 {
                    let k = parts[0].removingPercentEncoding?.lowercased() ?? parts[0].lowercased()
                    let v = parts[1...].joined(separator: "=").replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? parts[1]
                    if !k.isEmpty && !v.isEmpty {
                        res[k] = v
                    }
                }
            }
            return res
        }
        var res: [String: String] = [:]
        for item in items {
            if let val = item.value, !val.isEmpty {
                let cleanKey = item.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let cleanVal = val.replacingOccurrences(of: "+", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                res[cleanKey] = cleanVal
            }
        }
        return res
    }

    /// Strips HTML tags and unescapes common entities
    public static func cleanHTMLText(_ str: String) -> String {
        return str.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "[\\r\\n]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parses generic HTML forms by finding question blocks, labels, and pre-filled input values
    public static func parseGenericHTMLForm(_ html: String, url: String) -> RetrievedFormSchema? {
        let closedCheck = detectFormClosedState(html: html)
        if closedCheck.isClosed {
            return RetrievedFormSchema(title: "Application Form", description: "", fields: [], isClosed: true, closedMessage: closedCheck.message)
        }
        
        let lower = html.lowercased()
        guard lower.contains("<form") || lower.contains("<input") || lower.contains("<textarea") || lower.contains("role=\"listitem\"") || lower.contains("class=\"question\"") else {
            return nil
        }
        
        var fields: [FormInputField] = []
        let ns = html as NSString
        
        // 1. Try finding container blocks (.question, role="listitem", .form-group, fieldset)
        let blockPattern = "(<(?:div|fieldset)[^>]*(?:class=[\"'][^\"']*(?:question|form-group|Qr7Oae|field)[^\"']*[\"']|role=[\"']listitem[\"'])[^>]*>[\\s\\S]*?)(?=(?:<(?:div|fieldset)[^>]*(?:class=[\"'][^\"']*(?:question|form-group|Qr7Oae|field)[^\"']*[\"']|role=[\"']listitem[\"'])|</form>|</body>|$))"
        let blockRegex = try? NSRegularExpression(pattern: blockPattern, options: [.caseInsensitive])
        let matches = blockRegex?.matches(in: html, range: NSRange(location: 0, length: ns.length)) ?? []
        
        if !matches.isEmpty {
            for m in matches {
                guard m.numberOfRanges > 1 else { continue }
                let range = m.range(at: 1)
                guard range.location != NSNotFound else { continue }
                let blockHTML = ns.substring(with: range)
                let blockNS = blockHTML as NSString
                
                // Label extraction
                var label = ""
                let hRegex = try? NSRegularExpression(pattern: "<(?:div[^>]*role=[\"']heading[\"']|h[1-6]|label|legend|span[^>]*class=[\"'][^\"']*(?:M7eMe|label|title)[^\"']*[\"'])[^>]*>(.*?)</(?:div|h[1-6]|label|legend|span)>", options: [.dotMatchesLineSeparators, .caseInsensitive])
                if let hm = hRegex?.firstMatch(in: blockHTML, range: NSRange(location: 0, length: blockNS.length)) {
                    label = cleanHTMLText(blockNS.substring(with: hm.range(at: 1)))
                }
                
                // Fallback to aria-label
                if label.isEmpty {
                    let ariaRegex = try? NSRegularExpression(pattern: "aria-label=[\"']([^\"']+)[\"']", options: [.caseInsensitive])
                    if let am = ariaRegex?.firstMatch(in: blockHTML, range: NSRange(location: 0, length: blockNS.length)) {
                        label = cleanHTMLText(blockNS.substring(with: am.range(at: 1)))
                    }
                }
                
                guard !label.isEmpty && label.count < 140 else { continue }
                if fields.contains(where: { $0.label.lowercased() == label.lowercased() }) { continue }
                
                // Entry Key
                var entryKey: String?
                let nameRegex = try? NSRegularExpression(pattern: "name=[\"']([^\"']+)[\"']", options: [.caseInsensitive])
                if let nm = nameRegex?.firstMatch(in: blockHTML, range: NSRange(location: 0, length: blockNS.length)) {
                    let nStr = blockNS.substring(with: nm.range(at: 1))
                    if nStr.contains("entry.") {
                        entryKey = nStr
                    }
                }
                
                // Value extraction
                var val = ""
                // A. Textarea
                let taRegex = try? NSRegularExpression(pattern: "<textarea[^>]*>(.*?)</textarea>", options: [.dotMatchesLineSeparators, .caseInsensitive])
                if let tm = taRegex?.firstMatch(in: blockHTML, range: NSRange(location: 0, length: blockNS.length)) {
                    val = cleanHTMLText(blockNS.substring(with: tm.range(at: 1)))
                }
                
                // B. Radio / Checkbox (checked value)
                if val.isEmpty && (blockHTML.contains("type=\"radio\"") || blockHTML.contains("type=\"checkbox\"") || blockHTML.contains("role=\"radio\"") || blockHTML.contains("role=\"checkbox\"")) {
                    let checkedPattern = "<(?:input|div)[^>]*(?:checked|aria-checked=[\"']true[\"'])[^>]*value=[\"']([^\"']*)[\"']|<(?:input|div)[^>]*value=[\"']([^\"']*)[\"'][^>]*(?:checked|aria-checked=[\"']true[\"'])"
                    if let checkedRegex = try? NSRegularExpression(pattern: checkedPattern, options: [.caseInsensitive]),
                       let cm = checkedRegex.firstMatch(in: blockHTML, range: NSRange(location: 0, length: blockNS.length)) {
                        let cRange = cm.range(at: 1).location != NSNotFound ? cm.range(at: 1) : cm.range(at: 2)
                        val = blockNS.substring(with: cRange)
                    }
                }
                
                // B2. Select / Dropdown selected option value
                if val.isEmpty && (blockHTML.contains("<select") || blockHTML.contains("role=\"listbox\"")) {
                    let selOptPattern = "<option[^>]*selected[^>]*>(.*?)</option>"
                    if let selOptRegex = try? NSRegularExpression(pattern: selOptPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
                       let sm = selOptRegex.firstMatch(in: blockHTML, range: NSRange(location: 0, length: blockNS.length)) {
                        let innerText = cleanHTMLText(blockNS.substring(with: sm.range(at: 1)))
                        let optSub = blockNS.substring(with: sm.range)
                        let valAttrRegex = try? NSRegularExpression(pattern: "value=[\"']([^\"']*)[\"']", options: [.caseInsensitive])
                        if let vm = valAttrRegex?.firstMatch(in: optSub, range: NSRange(location: 0, length: (optSub as NSString).length)) {
                            let v = (optSub as NSString).substring(with: vm.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                            val = !v.isEmpty ? v : innerText
                        } else {
                            val = innerText
                        }
                    }
                    let dropPlaceholders = ["select", "choose", "select an option", "choose an option", "select location", "-- select --"]
                    if dropPlaceholders.contains(val.lowercased()) {
                        val = ""
                    }
                }
                
                // C. Regular input value
                if val.isEmpty {
                    let valRegex = try? NSRegularExpression(pattern: "<input[^>]*value=[\"']([^\"']*)[\"']", options: [.caseInsensitive])
                    if let vm = valRegex?.firstMatch(in: blockHTML, range: NSRange(location: 0, length: blockNS.length)) {
                        let candidateVal = blockNS.substring(with: vm.range(at: 1))
                        if !candidateVal.isEmpty {
                            val = candidateVal
                        }
                    }
                }
                
                // Options extraction
                var options: [String] = []
                let optRegex = try? NSRegularExpression(pattern: "<label[^>]*>(.*?)</label>|<option[^>]*>(.*?)</option>", options: [.caseInsensitive, .dotMatchesLineSeparators])
                if let oMatches = optRegex?.matches(in: blockHTML, range: NSRange(location: 0, length: blockNS.length)) {
                    for om in oMatches {
                        let oRange = om.range(at: 1).location != NSNotFound ? om.range(at: 1) : om.range(at: 2)
                        let cleanOpt = cleanHTMLText(blockNS.substring(with: oRange))
                        let isPlaceholder = ["select", "choose", "select an option", "choose an option", "select location", "-- select --"].contains(cleanOpt.lowercased())
                        if !cleanOpt.isEmpty && cleanOpt != label && !isPlaceholder && !options.contains(cleanOpt) {
                            options.append(cleanOpt)
                        }
                    }
                }
                
                // Also extract radio and checkbox inputs with sibling text or value attributes
                let inputChoiceRegex = try? NSRegularExpression(pattern: "<input[^>]*(?:type=[\"'](?:radio|checkbox)[\"'])[^>]*value=[\"']([^\"']+)[\"'][^>]*>(?:\\s*([^<\\n\\r]+))?", options: [.caseInsensitive])
                if let icMatches = inputChoiceRegex?.matches(in: blockHTML, range: NSRange(location: 0, length: blockNS.length)) {
                    for ic in icMatches {
                        var choiceText = ""
                        if ic.range(at: 2).location != NSNotFound {
                            choiceText = cleanHTMLText(blockNS.substring(with: ic.range(at: 2)))
                        }
                        if choiceText.isEmpty && ic.range(at: 1).location != NSNotFound {
                            choiceText = cleanHTMLText(blockNS.substring(with: ic.range(at: 1)))
                        }
                        if !choiceText.isEmpty && !options.contains(choiceText) {
                            options.append(choiceText)
                        }
                    }
                }
                
                // Question Type
                let qType: String
                if blockHTML.contains("<textarea") {
                    qType = "paragraph"
                } else if blockHTML.contains("type=\"radio\"") || blockHTML.contains("role=\"radio\"") {
                    qType = "multipleChoice"
                } else if blockHTML.contains("type=\"checkbox\"") || blockHTML.contains("role=\"checkbox\"") {
                    qType = "checkboxes"
                } else if blockHTML.contains("<select") || blockHTML.contains("role=\"listbox\"") || blockHTML.contains("role=\"combobox\"") {
                    qType = "dropdown"
                } else if blockHTML.contains("type=\"date\"") {
                    qType = "date"
                } else if blockHTML.contains("type=\"time\"") {
                    qType = "time"
                } else if blockHTML.contains("type=\"range\"") || blockHTML.contains("role=\"slider\"") {
                    qType = "linearScale"
                } else if blockHTML.contains("type=\"file\"") {
                    qType = "fileUpload"
                } else {
                    qType = label.lowercased().contains("why") || label.lowercased().contains("about") || label.lowercased().contains("statement") ? "paragraph" : "shortAnswer"
                }
                
                let isReq = blockHTML.contains("required") ||
                            blockHTML.contains("aria-required=\"true\"") ||
                            blockHTML.contains("freebirdFormviewerViewItemsItemRequiredAsterisk") ||
                            blockHTML.contains("aria-label=\"Required question\"") ||
                            blockHTML.contains("class=\"vVVJbe\"") ||
                            label.hasSuffix("*") ||
                            label.contains(" *")
                let cleanLabel = label.replacingOccurrences(of: "\\s*\\*+\\s*$", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                
                let lowerClean = cleanLabel.lowercased()
                let ignoredLabels = ["search", "sign in", "submit", "next", "back", "clear form", "report abuse", "terms of service", "privacy policy", "address and search bar"]
                guard !ignoredLabels.contains(lowerClean) else { continue }
                
                fields.append(FormInputField(
                    label: cleanLabel,
                    value: val,
                    category: inferCategory(from: cleanLabel),
                    options: options,
                    questionType: qType,
                    isRequired: isReq,
                    entryKey: entryKey
                ))
            }
        }
        
        // 2. Fallback: Parse individual label + input pairs if block parsing found nothing
        if fields.isEmpty {
            let labelRegex = try? NSRegularExpression(pattern: "<label[^>]*>(.*?)</label>", options: [.dotMatchesLineSeparators, .caseInsensitive])
            if let regex = labelRegex {
                let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
                for m in matches {
                    if m.numberOfRanges > 1 {
                        let clean = cleanHTMLText(ns.substring(with: m.range(at: 1)))
                        if !clean.isEmpty && clean.count < 120 && !fields.contains(where: { $0.label.lowercased() == clean.lowercased() }) {
                            fields.append(FormInputField(
                                label: clean,
                                value: "",
                                category: inferCategory(from: clean),
                                questionType: clean.lowercased().contains("why") || clean.lowercased().contains("about") ? "paragraph" : "shortAnswer"
                            ))
                        }
                    }
                }
            }
        }
        
        let titleMatch = html.range(of: "<title>(.*?)</title>", options: [.regularExpression, .caseInsensitive])
        let pageTitle = titleMatch != nil ? cleanHTMLText(String(html[titleMatch!])) : "Web Application Form"
        
        return RetrievedFormSchema(title: pageTitle, description: "", fields: fields)
    }
    
    /// Normalizes URLs by prepending https:// if scheme is missing (e.g. from Chromium/Polar address bars)
    public static func normalizeURLScheme(_ urlString: String) -> String {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("file://") {
            return trimmed
        }
        if !trimmed.contains("://") {
            return "https://" + trimmed
        }
        return trimmed
    }
    
    /// Autonomously retrieves form content and question schema from any URL or local file path
    public static func retrieveForm(from urlString: String) async -> RetrievedFormSchema? {
        let trimmedURL = normalizeURLScheme(urlString)
        guard !trimmedURL.isEmpty else { return nil }
        
        var htmlContent: String?
        
        // 1. Local file support (file:///path/to/file or /path/to/file)
        if trimmedURL.hasPrefix("/") || trimmedURL.hasPrefix("file://") {
            let path = trimmedURL.hasPrefix("file://") ? (URL(string: trimmedURL)?.path ?? trimmedURL.replacingOccurrences(of: "file://", with: "")) : trimmedURL
            let cleanFilePath: String
            if let qIdx = path.firstIndex(of: "?") {
                cleanFilePath = String(path[..<qIdx])
            } else {
                cleanFilePath = path
            }
            if FileManager.default.fileExists(atPath: cleanFilePath) {
                htmlContent = try? String(contentsOfFile: cleanFilePath, encoding: .utf8)
            }
        }
        
        // 2. Network HTTP/HTTPS fetch
        var redirectedToSignIn = false
        if htmlContent == nil, let url = URL(string: trimmedURL) {
            var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 4.0)
            req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, http.statusCode < 400 {
                    let finalHost = (response.url?.host ?? "").lowercased()
                    if finalHost.contains("accounts.google.") || finalHost.contains("login.microsoftonline.") {
                        redirectedToSignIn = true
                    } else {
                        htmlContent = String(data: data, encoding: .utf8)
                    }
                }
            } catch {
                // Ignore network error
            }
        }
        
        guard !redirectedToSignIn, let html = htmlContent else { return nil }
        
        let isGoogleFormTarget = trimmedURL.contains("docs.google.com/forms") || trimmedURL.contains("forms.gle")
        var schema: RetrievedFormSchema?
        if isGoogleFormTarget || html.contains("FB_PUBLIC_LOAD_DATA_") {
            schema = parseGoogleFormPublicLoadData(html)
        }
        if schema == nil {
            let lowerHTML = html.lowercased()
            let looksLikeGoogleLogin = isGoogleFormTarget &&
                (lowerHTML.contains("accounts.google.com/servicelogin") || lowerHTML.contains("identifierid")) &&
                !html.contains("Qr7Oae") && !html.contains("M7eMe")
            if !looksLikeGoogleLogin {
                schema = parseGenericHTMLForm(html, url: trimmedURL)
            }
        }
        
        guard var finalSchema = schema else { return nil }
        
        // 3. Hydrate prefilled parameters from URL query items (e.g. ?entry.1001=Minh+Nguyen)
        let queryParams = extractQueryParameters(from: trimmedURL)
        if !queryParams.isEmpty {
            for i in 0..<finalSchema.fields.count {
                if finalSchema.fields[i].value.isEmpty {
                    if let ek = finalSchema.fields[i].entryKey?.lowercased(), let val = queryParams[ek] {
                        finalSchema.fields[i].value = val
                        continue
                    }
                    let lbl = finalSchema.fields[i].label.lowercased()
                    for (k, v) in queryParams {
                        if lbl.contains(k) || k.contains(lbl) {
                            finalSchema.fields[i].value = v
                            break
                        }
                    }
                }
            }
        }
        
        return finalSchema
    }
}

// MARK: - Autonomous Form Input Auto Tracker
public final class FormInputAutoTracker: @unchecked Sendable {
    public weak var formModel: ApplicationFormModel?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalKeyMonitor: Any?
    private var axSyncTimer: AnyCancellable?
    private var fullScanTimer: AnyCancellable?
    private var debouncedAXSyncTask: Task<Void, Never>?
    public private(set) var isRunning: Bool = false
    
    // MARK: Focus confirmation
    // Typed characters are NEVER written to a guessed field. They go to the field whose browser focus has been
    // confirmed through Accessibility (focused element -> question label -> schema field). While focus is unknown
    // (after a click, Tab, Enter...) typing is held briefly in `pendingText` and flushed once focus is confirmed.
    // For browsers that render web pages in an out-of-process CAContext layer without exposing an AXWebArea tree
    // (such as Polar Browser), `isHeadlessBrowserActive` confirms focus onto the active actionable text-entry field
    // and advances synchronously on Tab, Shift+Tab, Enter, or vertical viewport clicks.
    public private(set) var confirmedFieldID: UUID?
    private var confirmedElement: AXUIElement?
    public private(set) var pendingText: String = ""
    private var pendingSince: Date?
    public static let pendingTTL: TimeInterval = 30.0
    public var isHeadlessWebLayerMode: Bool = false
    public private(set) var lastHeadlessFieldClickLocation: CGPoint? = nil
    public private(set) var isAllTextSelected: Bool = false
    private var lastValueBeforeDestructiveEdit: [UUID: String] = [:]
    private var fastLiveSyncTask: Task<Void, Never>?
    public var clipboardStringProvider: () -> String? = {
        NSPasteboard.general.string(forType: .string)
    }
    public static let syntheticEventUserDataTag: Int64 = 0x4D525048 // 'MRPH'
    
    /// Question types whose answer is produced by typing text (as opposed to picking an option).
    public static func isTextEntryType(_ questionType: String) -> Bool {
        return !["multipleChoice", "checkboxes", "dropdown", "linearScale", "grid", "fileUpload", "info", "section", "pageBreak", "header", "title"].contains(questionType)
    }
    
    @MainActor
    private func confirmedFieldIndex(in model: ApplicationFormModel) -> Int? {
        guard let id = confirmedFieldID, let fields = model.activeSession?.fields else { return nil }
        return fields.firstIndex(where: { $0.id == id })
    }
    
    /// Forget which field the browser has focused (focus moved or is unknown). Held typing is discarded.
    @MainActor
    public func invalidateFocus() {
        if confirmedFieldID != nil {
            formModel?.objectWillChange.send()
        }
        confirmedFieldID = nil
        confirmedElement = nil
        pendingText = ""
        pendingSince = nil
        lastHeadlessFieldClickLocation = nil
        isAllTextSelected = false
    }
    
    /// Records that the browser's focused input belongs to `fieldID`, aligns the active field and flushes any
    /// text typed while focus was unknown into that field.
    @MainActor
    public func confirmFocus(fieldID: UUID, element: AXUIElement? = nil) {
        guard let model = formModel,
              let idx = model.activeSession?.fields.firstIndex(where: { $0.id == fieldID }) else { return }
        let changedField = confirmedFieldID != fieldID
        confirmedFieldID = fieldID
        confirmedElement = element
        if changedField {
            isAllTextSelected = false
        }
        if changedField || model.activeFieldIndex != idx {
            model.objectWillChange.send()
            model.activeFieldIndex = idx
        }
        let fresh = pendingSince.map { Date().timeIntervalSince($0) < Self.pendingTTL } ?? true
        if fresh, !pendingText.isEmpty,
           let field = model.activeSession?.fields[idx], Self.isTextEntryType(field.questionType) {
            model.objectWillChange.send()
            model.activeSession?.fields[idx].value.append(pendingText)
            model.markBrowserCaptured(fieldID)
            model.lastAutoCapturedAt = Date()
            model.lastKeystrokeAt = Date()
            model.saveDrafts()
        }
        pendingText = ""
        pendingSince = nil
    }
    
    /// Returns true when the active browser renders web pages in a headless layer without exposing an AXWebArea
    /// tree (such as Polar Browser), or when `isHeadlessWebLayerMode` is explicitly enabled in tests.
    @MainActor
    public func isHeadlessBrowserActive(frontApp: NSRunningApplication?, model: ApplicationFormModel) -> Bool {
        if isHeadlessWebLayerMode { return true }
        guard !MorphEnvironment.isTestingEnvironment else { return false }
        if model.detectedBrowserFamily == .polar ||
           model.detectedAppName.lowercased() == "polar" ||
           model.activeSession?.sourceAppName.lowercased() == "polar" {
            return true
        }
        if let frontApp = frontApp {
            let bid = frontApp.bundleIdentifier?.lowercased() ?? ""
            let name = frontApp.localizedName?.lowercased() ?? ""
            if bid.contains("com.polar.browser") || name == "polar" {
                return true
            }
            if DefaultApplicationFormDetector.isBrowserApplication(frontApp) {
                let appElem = AXUIElementCreateApplication(frontApp.processIdentifier)
                if let win = DefaultApplicationFormDetector.getBrowserWindowElement(appElem: appElem),
                   Self.findWebAreaElement(in: win) == nil {
                    return true
                }
            }
        }
        return false
    }
    
    /// Returns true if the browser's native UI chrome (such as the address bar / search bar) currently holds AX focus.
    public static func isBrowserChromeInputFocused(for frontApp: NSRunningApplication?) -> Bool {
        guard let app = frontApp ?? NSWorkspace.shared.frontmostApplication else { return false }
        let appElem = AXUIElementCreateApplication(app.processIdentifier)
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElem, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focused = focusedRef else { return false }
        let elem = focused as! AXUIElement
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(elem, kAXRoleAttribute as CFString, &roleRef)
        let role = (roleRef as? String) ?? ""
        if role == "AXTextField" || role == "AXSearchField" || role == "AXComboBox" {
            if !isElementInsideWebArea(elem) {
                return true
            }
        }
        return false
    }
    
    /// Ensures focus is confirmed on an actionable text-entry field in headless web-layer mode (e.g. Polar).
    @MainActor
    @discardableResult
    public func ensureHeadlessTextEntryFocus(in model: ApplicationFormModel) -> Int? {
        guard let fields = model.activeSession?.fields, !fields.isEmpty else { return nil }
        if let cur = confirmedFieldIndex(in: model),
           fields[cur].isActionableQuestion,
           Self.isTextEntryType(fields[cur].questionType) {
            return cur
        }
        let start = max(0, min(model.activeFieldIndex, fields.count - 1))
        if fields[start].isActionableQuestion && Self.isTextEntryType(fields[start].questionType) {
            confirmFocus(fieldID: fields[start].id)
            return start
        }
        // Prefer the first unanswered text-entry field at or after activeFieldIndex
        if let idx = (start..<fields.count).first(where: {
            fields[$0].isActionableQuestion && Self.isTextEntryType(fields[$0].questionType) && !fields[$0].isAnswered
        }) ?? fields.indices.first(where: {
            fields[$0].isActionableQuestion && Self.isTextEntryType(fields[$0].questionType) && !fields[$0].isAnswered
        }) ?? (start..<fields.count).first(where: {
            fields[$0].isActionableQuestion && Self.isTextEntryType(fields[$0].questionType)
        }) ?? fields.indices.first(where: {
            fields[$0].isActionableQuestion && Self.isTextEntryType(fields[$0].questionType)
        }) {
            confirmFocus(fieldID: fields[idx].id)
            return idx
        }
        return nil
    }
    
    /// Advances or reverses focus to the next/previous actionable text-entry field in headless web-layer mode.
    @MainActor
    @discardableResult
    public func advanceHeadlessFocus(in model: ApplicationFormModel, backward: Bool = false) -> Int? {
        guard let fields = model.activeSession?.fields, !fields.isEmpty else { return nil }
        let cur = confirmedFieldIndex(in: model) ?? max(0, min(model.activeFieldIndex, fields.count - 1))
        if backward {
            if cur > 0, let prev = (0..<cur).reversed().first(where: {
                fields[$0].isActionableQuestion && Self.isTextEntryType(fields[$0].questionType)
            }) {
                lastHeadlessFieldClickLocation = nil
                confirmFocus(fieldID: fields[prev].id)
                return prev
            }
        } else {
            if cur + 1 < fields.count, let next = ((cur + 1)..<fields.count).first(where: {
                fields[$0].isActionableQuestion && Self.isTextEntryType(fields[$0].questionType)
            }) {
                lastHeadlessFieldClickLocation = nil
                confirmFocus(fieldID: fields[next].id)
                return next
            }
        }
        return confirmedFieldIndex(in: model)
    }
    
    /// Handles a mouse click inside the web content viewport of a headless web-layer browser (e.g. Polar).
    /// When the current text-entry field is still empty, keeps focus on it and records the click coordinate;
    /// when the current text-entry field has already been answered and the user clicks a vertically distinct
    /// question card (> 45pt away), advances focus to the next unanswered text-entry question.
    @MainActor
    public func handleHeadlessViewportClick(at location: CGPoint, in model: ApplicationFormModel) {
        guard let fields = model.activeSession?.fields, !fields.isEmpty else { return }
        if let curIdx = confirmedFieldIndex(in: model),
           fields[curIdx].isActionableQuestion,
           Self.isTextEntryType(fields[curIdx].questionType) {
            if !fields[curIdx].isAnswered {
                // Current field is still unanswered: keep focus here and record click position
                lastHeadlessFieldClickLocation = location
                return
            }
            // Current field is already answered: check if user clicked onto a different question card
            let movedToAnotherCard: Bool
            if let lastLoc = lastHeadlessFieldClickLocation {
                movedToAnotherCard = abs(location.y - lastLoc.y) > 45
            } else {
                movedToAnotherCard = true
            }
            if movedToAnotherCard {
                if let lastLoc = lastHeadlessFieldClickLocation, location.y < lastLoc.y - 45 {
                    if let prevIdx = (0..<curIdx).reversed().first(where: {
                        fields[$0].isActionableQuestion && Self.isTextEntryType(fields[$0].questionType)
                    }) {
                        confirmFocus(fieldID: fields[prevIdx].id)
                        lastHeadlessFieldClickLocation = location
                        return
                    }
                } else if curIdx + 1 < fields.count,
                   let nextIdx = ((curIdx + 1)..<fields.count).first(where: {
                       fields[$0].isActionableQuestion && Self.isTextEntryType(fields[$0].questionType) && !fields[$0].isAnswered
                   }) ?? ((curIdx + 1)..<fields.count).first(where: {
                       fields[$0].isActionableQuestion && Self.isTextEntryType(fields[$0].questionType)
                   }) {
                    confirmFocus(fieldID: fields[nextIdx].id)
                    lastHeadlessFieldClickLocation = location
                    return
                }
            }
            lastHeadlessFieldClickLocation = location
        } else {
            _ = ensureHeadlessTextEntryFocus(in: model)
            lastHeadlessFieldClickLocation = location
        }
    }
    
    public init(model: ApplicationFormModel) {
        self.formModel = model
    }
    
    deinit {
        stop()
    }
    
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        setupEventTap()
        setupAXSync()
    }
    
    public func stop() {
        isRunning = false
        debouncedAXSyncTask?.cancel()
        debouncedAXSyncTask = nil
        fastLiveSyncTask?.cancel()
        fastLiveSyncTask = nil
        
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
            }
            CFMachPortInvalidate(tap)
            eventTap = nil
            runLoopSource = nil
        }
        
        if let mon = globalKeyMonitor {
            NSEvent.removeMonitor(mon)
            globalKeyMonitor = nil
        }
        
        axSyncTimer?.cancel()
        axSyncTimer = nil
        fullScanTimer?.cancel()
        fullScanTimer = nil
    }
    
    private func setupEventTap() {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.leftMouseDown.rawValue)
        let trackerPointer = Unmanaged.passUnretained(self).toOpaque()
        
        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let tracker = Unmanaged<FormInputAutoTracker>.fromOpaque(refcon).takeUnretainedValue()
            return tracker.handleTapEvent(proxy: proxy, type: type, event: event)
        }
        
        // Prefer .cghidEventTap for universal HID-level event capture with Accessibility permission;
        // Fall back to .cgSessionEventTap if needed
        var tapPort = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: trackerPointer
        )
        if tapPort == nil {
            tapPort = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: CGEventMask(mask),
                callback: callback,
                userInfo: trackerPointer
            )
        }
        
        if let port = tapPort {
            self.eventTap = port
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
            self.runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: port, enable: true)
            NSLog("[MORPH-AUTOTRACKER] CGEvent tap successfully established on main run loop.")
        } else {
            NSLog("[MORPH-AUTOTRACKER] CGEvent tap creation failed. Falling back to NSEvent global monitor.")
            // Fallback for environments where CGEventTap cannot be attached
            globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { [weak self] event in
                guard let self = self, self.isRunning else { return }
                if event.cgEvent?.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventUserDataTag {
                    return
                }
                if event.type == .leftMouseDown {
                    let cocoaLoc = NSEvent.mouseLocation
                    let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
                    let cgLoc = CGPoint(
                        x: cocoaLoc.x,
                        y: primaryHeight > 0 ? primaryHeight - cocoaLoc.y : cocoaLoc.y
                    )
                    Task { @MainActor [weak self] in
                        self?.handleMouseDown(at: cgLoc)
                    }
                    return
                }
                let keyCode = Int(event.keyCode)
                let flags = event.modifierFlags
                let characters = event.characters
                var cgFlags = CGEventFlags()
                if flags.contains(.command) { cgFlags.insert(.maskCommand) }
                if flags.contains(.control) { cgFlags.insert(.maskControl) }
                if flags.contains(.shift) { cgFlags.insert(.maskShift) }
                if flags.contains(.option) { cgFlags.insert(.maskAlternate) }
                Task { @MainActor [weak self] in
                    self?.handleKeyStroke(keyCode: keyCode, flags: cgFlags, characters: characters)
                }
            }
        }
    }
    
    private func handleTapEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        
        guard isRunning else { return Unmanaged.passUnretained(event) }
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticEventUserDataTag {
            return Unmanaged.passUnretained(event)
        }
        
        if type == .keyDown {
            let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            
            // Extract typed characters: prefer NSEvent character decoding which incorporates keyboard layout & shift,
            // with fallback to keyboardGetUnicodeString
            let characters: String? = NSEvent(cgEvent: event)?.characters ?? {
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
                return length > 0 ? String(utf16CodeUnits: chars, count: length) : nil
            }()
            
            DispatchQueue.main.async { [weak self] in
                self?.handleKeyStroke(keyCode: keyCode, flags: flags, characters: characters)
            }
        } else if type == .leftMouseDown {
            let loc = event.location
            DispatchQueue.main.async { [weak self] in
                self?.handleMouseDown(at: loc)
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    private func setupAXSync() {
        // Fast 0.1s poll to sync focused element value and active field alignment
        axSyncTimer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, let model = self.formModel,
                          model.isFormDetected, model.isAutoCaptureEnabled else { return }
                    self.syncFocusedElement()
                }
            }
        
        // High-frequency 0.25s background scan of all browser window inputs & AppleScript fallback
        fullScanTimer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, let model = self.formModel,
                          model.isFormDetected, model.isAutoCaptureEnabled else { return }
                    self.formModel?.syncLiveFormInputValues(isBackground: true)
                }
            }
    }
    
    public static func isInteractiveInputRole(_ role: String) -> Bool {
        switch role {
        case "AXTextField", "AXTextArea", "AXSearchField", "AXComboBox",
             "AXRadioButton", "AXCheckBox", "AXPopUpButton", "AXMenuButton",
             "AXMenuItem", "AXButton":
            return true
        default:
            return false
        }
    }
    
    /// Resolves the currently focused interactive element across the system or frontmost application.
    public static func resolveFocusedElement(for frontApp: NSRunningApplication?) -> (element: AXUIElement, role: String)? {
        // 1. Try system-wide focused element first (most accurate across macOS browsers and web frames)
        let sys = AXUIElementCreateSystemWide()
        var sysFocusedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(sys, kAXFocusedUIElementAttribute as CFString, &sysFocusedRef) == .success,
           let sysFocused = sysFocusedRef {
            let elem = sysFocused as! AXUIElement
            var elemPid: pid_t = 0
            AXUIElementGetPid(elem, &elemPid)
            if elemPid == ProcessInfo.processInfo.processIdentifier { return nil }
            if let eApp = NSRunningApplication(processIdentifier: elemPid),
               let bid = eApp.bundleIdentifier?.lowercased(),
               bid.contains("com.morph.") || bid == "morph" { return nil }
            
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(elem, kAXRoleAttribute as CFString, &roleRef)
            let role = (roleRef as? String) ?? ""
            if isInteractiveInputRole(role) {
                return (elem, role)
            } else if role == "AXWebArea" || role == "AXScrollArea" || role == "AXWindow" || role == "AXGroup" {
                var innerRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(elem, kAXFocusedUIElementAttribute as CFString, &innerRef) == .success,
                   let inner = innerRef {
                    let innerElem = inner as! AXUIElement
                    var innerRoleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(innerElem, kAXRoleAttribute as CFString, &innerRoleRef)
                    let innerRole = (innerRoleRef as? String) ?? ""
                    if isInteractiveInputRole(innerRole) {
                        return (innerElem, innerRole)
                    }
                }
                // If direct focused element query failed on AXWindow/AXScrollArea (Chromium/Polar), locate AXWebArea
                if role != "AXWebArea", let webArea = findWebAreaElement(in: elem) {
                    var webFocusedRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(webArea, kAXFocusedUIElementAttribute as CFString, &webFocusedRef) == .success,
                       let webFocused = webFocusedRef {
                        let innerElem = webFocused as! AXUIElement
                        var innerRoleRef: CFTypeRef?
                        AXUIElementCopyAttributeValue(innerElem, kAXRoleAttribute as CFString, &innerRoleRef)
                        let innerRole = (innerRoleRef as? String) ?? ""
                        if isInteractiveInputRole(innerRole) {
                            return (innerElem, innerRole)
                        }
                    }
                }
            }
        }
        
        // 2. Fallback to frontmost application focused element
        guard let app = frontApp ?? NSWorkspace.shared.frontmostApplication else { return nil }
        let appElem = AXUIElementCreateApplication(app.processIdentifier)
        var appFocusedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElem, kAXFocusedUIElementAttribute as CFString, &appFocusedRef) == .success,
           let appFocused = appFocusedRef {
            let elem = appFocused as! AXUIElement
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(elem, kAXRoleAttribute as CFString, &roleRef)
            let role = (roleRef as? String) ?? ""
            if isInteractiveInputRole(role) {
                return (elem, role)
            }
            var innerRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(elem, kAXFocusedUIElementAttribute as CFString, &innerRef) == .success,
               let inner = innerRef {
                let innerElem = inner as! AXUIElement
                var innerRoleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(innerElem, kAXRoleAttribute as CFString, &innerRoleRef)
                let innerRole = (innerRoleRef as? String) ?? ""
                if isInteractiveInputRole(innerRole) {
                    return (innerElem, innerRole)
                }
            }
            // Locate AXWebArea if appFocused is window
            if let webArea = findWebAreaElement(in: elem) {
                var webFocusedRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(webArea, kAXFocusedUIElementAttribute as CFString, &webFocusedRef) == .success,
                   let webFocused = webFocusedRef {
                    let innerElem = webFocused as! AXUIElement
                    var innerRoleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(innerElem, kAXRoleAttribute as CFString, &innerRoleRef)
                    let innerRole = (innerRoleRef as? String) ?? ""
                    if isInteractiveInputRole(innerRole) {
                        return (innerElem, innerRole)
                    }
                }
            }
        }
        return nil
    }
    
    /// Detects whether an accessibility element is a page navigation button (Next, Submit, Back, Continue, etc.)
    public static func isPageNavigationElement(_ elem: AXUIElement) -> Bool {
        var cur = elem
        for _ in 0..<6 {
            var rRef: CFTypeRef?
            AXUIElementCopyAttributeValue(cur, kAXRoleAttribute as CFString, &rRef)
            let role = (rRef as? String) ?? ""
            
            var titleRef: CFTypeRef?, descRef: CFTypeRef?, valRef: CFTypeRef?
            AXUIElementCopyAttributeValue(cur, kAXTitleAttribute as CFString, &titleRef)
            AXUIElementCopyAttributeValue(cur, kAXDescriptionAttribute as CFString, &descRef)
            AXUIElementCopyAttributeValue(cur, kAXValueAttribute as CFString, &valRef)
            
            let label = ((titleRef as? String) ?? (descRef as? String) ?? (valRef as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            let navKeywords = ["next", "tiếp", "tiếp theo", "tiếp tục", "submit", "gửi", "back", "quay lại", "continue", "siguiente", "enviar", "atrás", "suivant", "soumettre", "retour", "weiter", "senden", "zurück"]
            if role == "AXButton" || role == "AXLink" || !label.isEmpty {
                for kw in navKeywords {
                    if label == kw || label.hasPrefix("\(kw) ") || label.hasSuffix(" \(kw)") {
                        return true
                    }
                }
            }
            
            var pRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(cur, kAXParentAttribute as CFString, &pRef) == .success,
                  let p = pRef else { break }
            cur = (p as! AXUIElement)
        }
        return false
    }
    
    @MainActor
    public func handleMouseDown(at location: CGPoint) {
        guard let model = formModel, model.isFormDetected, model.isAutoCaptureEnabled else { return }
        let frontApp = NSWorkspace.shared.frontmostApplication
        if !MorphEnvironment.isTestingEnvironment {
            guard let frontApp = frontApp,
                  DefaultApplicationFormDetector.isBrowserApplication(frontApp) else { return }
        }
        
        let headless = isHeadlessBrowserActive(frontApp: frontApp, model: model)
        if MorphEnvironment.isTestingEnvironment && headless {
            handleHeadlessViewportClick(at: location, in: model)
            return
        }
        
        // Check if user clicked 'Clear form', navigation button, or dialog confirm
        let sys = AXUIElementCreateSystemWide()
        var hitRef: AXUIElement?
        if AXUIElementCopyElementAtPosition(sys, Float(location.x), Float(location.y), &hitRef) == .success,
           let hit = hitRef {
            var hitPid: pid_t = 0
            AXUIElementGetPid(hit, &hitPid)
            if hitPid == ProcessInfo.processInfo.processIdentifier { return }
            if let hApp = NSRunningApplication(processIdentifier: hitPid),
               let bid = hApp.bundleIdentifier?.lowercased(),
               bid.contains("com.morph.") || bid == "morph" { return }
            
            let (isClear, isDialogConfirm) = Self.isClearFormElement(hit)
            if isDialogConfirm {
                // User confirmed clearing the form in dialog: clear all answers immediately!
                self.formModel?.clearAllFormAnswers()
                return
            } else if isClear {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    self?.formModel?.syncLiveFormInputValues()
                }
            } else if Self.isPageNavigationElement(hit) {
                // User is navigating to another page/section: instantly capture all inputs on current page
                // before the page unloads!
                self.formModel?.syncLiveFormInputValues(isBackground: false)
            }
            
            if headless {
                var rRef: CFTypeRef?
                AXUIElementCopyAttributeValue(hit, kAXRoleAttribute as CFString, &rRef)
                let hitRole = (rRef as? String) ?? ""
                if hitRole == "AXTextField" || hitRole == "AXSearchField" || hitRole == "AXComboBox" {
                    // Clicked native browser address bar / search bar
                    invalidateFocus()
                    return
                }
                if hitRole == "AXButton" || hitRole == "AXRadioButton" || hitRole == "AXMenuButton" {
                    // Clicked native browser toolbar / tab button
                    return
                }
                handleHeadlessViewportClick(at: location, in: model)
                return
            }
        } else if headless {
            handleHeadlessViewportClick(at: location, in: model)
            return
        }
        
        // 1. Immediately attempt hit test at click coordinate
        syncFocusedElement(at: location)
        
        // 2. Schedule follow-ups after 25ms and 75ms once browser settles internal focus, plus fast live sync for radios/checkboxes/dropdowns
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 25_000_000)
            self?.syncFocusedElement()
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 75_000_000)
            self?.syncFocusedElement()
        }
        if !headless {
            scheduleFastLiveSync(delayNanoseconds: 55_000_000)
        }
    }
    
    /// Returns true if a browser's reported AXWindow title is compatible with the detected form session
    /// (treating transient empty or shell-only titles such as "Polar" / "Google Chrome" / "Safari" as neutral).
    public static func isWindowTitleCompatible(winTitle: String?, detectedFormTitle: String, sourceURL: String?) -> Bool {
        guard let raw = winTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return true
        }
        let lower = raw.lowercased()
        let neutralShellTitles: Set<String> = [
            "polar", "google chrome", "chrome", "safari", "brave", "arc",
            "microsoft edge", "edge", "firefox", "application form",
            "google form", "google forms", "untitled"
        ]
        if neutralShellTitles.contains(lower) {
            return true
        }
        return DefaultApplicationFormDetector.isSameForm(
            titleA: raw, urlA: nil,
            titleB: detectedFormTitle, urlB: sourceURL
        )
    }
    
    /// Attempts to enable lazy web accessibility trees (Chromium / Safari) without affecting Polar.
    @discardableResult
    public static func ensureWebAccessibilityEnabledIfNeeded(for app: NSRunningApplication, appElem: AXUIElement, window: AXUIElement) -> AXUIElement? {
        if let existing = findWebAreaElement(in: window) {
            return existing
        }
        let bid = app.bundleIdentifier?.lowercased() ?? ""
        let name = app.localizedName?.lowercased() ?? ""
        guard !bid.contains("com.polar.browser"), name != "polar" else {
            return nil
        }
        _ = AXUIElementSetAttributeValue(appElem, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.06))
        return findWebAreaElement(in: window)
    }
    
    /// Activates the target browser application cleanly so AX focus and paste events land inside the form.
    @MainActor
    @discardableResult
    public static func activateBrowser(_ app: NSRunningApplication, timeout: TimeInterval = 0.35) -> Bool {
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
            return true
        }
        let appElem = AXUIElementCreateApplication(app.processIdentifier)
        if let win = DefaultApplicationFormDetector.getBrowserWindowElement(appElem: appElem) {
            AXUIElementPerformAction(win, kAXRaiseAction as CFString)
        }
        app.activate()
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.015))
        }
        return NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
    }
    
    @MainActor
    private func updateAutoDetectedEmailIfNeeded(from value: String, field: FormInputField?, in model: ApplicationFormModel) {
        let isContactField = (field?.category == .contact) || (field?.label.lowercased().contains("email") ?? false)
        guard value.contains("@") && value.contains(".") else { return }
        let tokens = value.components(separatedBy: .whitespacesAndNewlines)
        for tok in tokens {
            if tok.contains("@") && tok.contains(".") && tok.count >= 5 {
                if isContactField || model.recipientEmail.isEmpty || model.recipientEmail.contains("example.com") || model.recipientEmail.contains("@test.com") {
                    model.setRecipientEmail(tok)
                }
                break
            }
        }
    }
    
    @MainActor
    public func handleKeyStroke(keyCode: Int, flags: CGEventFlags, characters: String?) {
        guard let model = self.formModel else { return }
        guard model.isFormDetected && model.isAutoCaptureEnabled,
              let session = model.activeSession else { return }
        
        // Never capture keystrokes if the form is marked closed or expired
        if model.isClosedOrExpired || session.isClosedOrExpired {
            invalidateFocus()
            return
        }
        
        let frontApp = NSWorkspace.shared.frontmostApplication
        let headless = isHeadlessBrowserActive(frontApp: frontApp, model: model)
        
        // Only capture if frontmost application is the detected browser / form host (bypassed in unit tests)
        if !MorphEnvironment.isTestingEnvironment {
            guard let frontApp = frontApp else { return }
            let frontBundle = frontApp.bundleIdentifier?.lowercased() ?? ""
            let frontName = frontApp.localizedName?.lowercased() ?? ""
            
            // Do NOT intercept if typing inside Antigravity, Morph, code editors, or non-form apps
            if DefaultApplicationFormDetector.isNonFormApplication(bundleID: frontBundle, appName: frontName) {
                return
            }
            
            let isTargetApp = DefaultApplicationFormDetector.isBrowserApplication(frontApp) ||
                              frontName.contains(model.detectedAppName.lowercased()) ||
                              model.detectedAppName.lowercased().contains(frontName)
            guard isTargetApp else { return }
            
            // Never capture keystrokes typed into the browser's native address bar / search bar
            if Self.isBrowserChromeInputFocused(for: frontApp) {
                invalidateFocus()
                return
            }
            
            // Never capture keystrokes if the form is marked closed or expired
            if model.isClosedOrExpired {
                invalidateFocus()
                return
            }
            
            // Check that the primary browser window title still matches the detected form
            let appElem = AXUIElementCreateApplication(frontApp.processIdentifier)
            if let win = DefaultApplicationFormDetector.getBrowserWindowElement(appElem: appElem) {
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let winTitle = titleRef as? String,
                   !Self.isWindowTitleCompatible(winTitle: winTitle, detectedFormTitle: model.detectedFormTitle, sourceURL: model.activeSession?.sourceURL) {
                    invalidateFocus()
                    return
                }
            }
            
            // Check that the focused element is inside an AXWebArea ONLY for browsers that expose AXWebArea
            // (Headless browsers such as Polar report AXWindow as focusedElem with 0 AXWebArea nodes).
            if !headless {
                var focusedRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(appElem, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
                   let focused = focusedRef {
                    let focusedElem = focused as! AXUIElement
                    if !Self.isElementInsideWebArea(focusedElem) {
                        invalidateFocus()
                        return
                    }
                }
            }
        }
        
        var confirmedIdx = confirmedFieldIndex(in: model)
        
        // Shortcut keys (Cmd / Ctrl): Cmd+A (0), Cmd+C (8), Cmd+X (7), Cmd+V (9), Cmd+Z (6)
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            if keyCode == 0 && flags.contains(.maskCommand) {
                // Cmd+A: Select all inside active text field so next char/Backspace/Cmd+V replaces cleanly
                if confirmedIdx == nil && headless {
                    confirmedIdx = ensureHeadlessTextEntryFocus(in: model)
                }
                if let idx = confirmedIdx,
                   Self.isTextEntryType(model.activeSession?.fields[idx].questionType ?? "") {
                    isAllTextSelected = !(model.activeSession?.fields[idx].value.isEmpty ?? true)
                }
                return
            }
            if keyCode == 7 && flags.contains(.maskCommand) {
                // Cmd+X (Cut): if full selection active, clear immediately; always reconcile AX/DOM quickly
                if let idx = confirmedIdx,
                   let field = model.activeSession?.fields[idx],
                   Self.isTextEntryType(field.questionType),
                   isAllTextSelected {
                    lastValueBeforeDestructiveEdit[field.id] = field.value
                    model.objectWillChange.send()
                    model.activeSession?.fields[idx].value = ""
                    isAllTextSelected = false
                    model.markBrowserCaptured(field.id)
                    model.lastAutoCapturedAt = Date()
                    model.lastKeystrokeAt = Date()
                    model.saveDrafts()
                }
                if !headless {
                    scheduleDebouncedAXSync()
                    scheduleFastLiveSync(delayNanoseconds: 45_000_000)
                }
                return
            }
            if keyCode == 9 && flags.contains(.maskCommand) {
                // Cmd+V (Paste)
                if headless {
                    if let cur = confirmedIdx, !Self.isTextEntryType(model.activeSession?.fields[cur].questionType ?? "") {
                        confirmedIdx = ensureHeadlessTextEntryFocus(in: model)
                    } else if confirmedIdx == nil {
                        confirmedIdx = ensureHeadlessTextEntryFocus(in: model)
                    }
                    if let idx = confirmedIdx,
                       let field = model.activeSession?.fields[idx],
                       Self.isTextEntryType(field.questionType),
                       let rawClip = clipboardStringProvider(), !rawClip.isEmpty {
                        let pasteText = (field.questionType == "paragraph")
                            ? rawClip
                            : rawClip.replacingOccurrences(of: "\r\n", with: " ").replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
                        lastValueBeforeDestructiveEdit[field.id] = field.value
                        model.objectWillChange.send()
                        if isAllTextSelected {
                            model.activeSession?.fields[idx].value = pasteText
                            isAllTextSelected = false
                        } else {
                            model.activeSession?.fields[idx].value.append(pasteText)
                        }
                        model.markBrowserCaptured(field.id)
                        model.lastAutoCapturedAt = Date()
                        model.lastKeystrokeAt = Date()
                        let updatedField = (model.activeSession?.fields.indices.contains(idx) == true) ? model.activeSession?.fields[idx] : nil
                        updateAutoDetectedEmailIfNeeded(from: updatedField?.value ?? "", field: updatedField, in: model)
                        model.saveDrafts()
                    }
                    return
                }
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 25_000_000)
                    self?.syncFocusedElement()
                }
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 75_000_000)
                    self?.syncFocusedElement()
                }
                scheduleFastLiveSync(delayNanoseconds: 50_000_000)
                return
            }
            if keyCode == 6 && flags.contains(.maskCommand) {
                // Cmd+Z (Undo): restore last pre-clear/paste value in headless mode, fast sync in DOM/AX browsers
                if headless, let idx = confirmedIdx,
                   let fid = model.activeSession?.fields[idx].id,
                   let prevVal = lastValueBeforeDestructiveEdit.removeValue(forKey: fid) {
                    model.objectWillChange.send()
                    model.activeSession?.fields[idx].value = prevVal
                    isAllTextSelected = false
                    model.markBrowserCaptured(fid)
                    model.lastAutoCapturedAt = Date()
                    model.lastKeystrokeAt = Date()
                    model.saveDrafts()
                    return
                }
                if !headless {
                    scheduleDebouncedAXSync()
                    scheduleFastLiveSync(delayNanoseconds: 50_000_000)
                }
                return
            }
            if keyCode == 51 && flags.contains(.maskCommand) {
                // Cmd+Backspace (Delete to beginning of line / clear field synchronously)
                if confirmedIdx == nil && headless {
                    confirmedIdx = ensureHeadlessTextEntryFocus(in: model)
                }
                if let idx = confirmedIdx, let field = model.activeSession?.fields[idx],
                   Self.isTextEntryType(field.questionType) {
                    lastValueBeforeDestructiveEdit[field.id] = field.value
                    model.objectWillChange.send()
                    if isAllTextSelected || field.questionType != "paragraph" {
                        model.activeSession?.fields[idx].value = ""
                    } else {
                        var current = field.value
                        if current.hasSuffix("\n") {
                            current.removeLast()
                        } else if let nlIdx = current.lastIndex(of: "\n") {
                            current = String(current[...nlIdx])
                        } else {
                            current = ""
                        }
                        model.activeSession?.fields[idx].value = current
                    }
                    isAllTextSelected = false
                    model.markBrowserCaptured(field.id)
                    model.lastAutoCapturedAt = Date()
                    model.lastKeystrokeAt = Date()
                    model.saveDrafts()
                } else if !pendingText.isEmpty {
                    pendingText = ""
                }
                if !headless {
                    scheduleDebouncedAXSync()
                    scheduleFastLiveSync(delayNanoseconds: 45_000_000)
                }
                return
            }
            return
        }
        
        // If fields are empty, sync focused element to dynamically discover field first
        if session.fields.isEmpty {
            self.syncFocusedElement()
        }
        guard (model.activeSession?.fields.count ?? 0) > 0 else { return }
        
        confirmedIdx = confirmedFieldIndex(in: model)
        
        // 1. Backspace (51) / Forward Delete (117)
        if keyCode == 51 || keyCode == 117 {
            if confirmedIdx == nil && headless {
                confirmedIdx = ensureHeadlessTextEntryFocus(in: model)
            }
            if let idx = confirmedIdx, let field = model.activeSession?.fields[idx],
               Self.isTextEntryType(field.questionType) {
                if isAllTextSelected {
                    lastValueBeforeDestructiveEdit[field.id] = field.value
                    model.objectWillChange.send()
                    model.activeSession?.fields[idx].value = ""
                    isAllTextSelected = false
                    model.markBrowserCaptured(field.id)
                    model.lastAutoCapturedAt = Date()
                    model.lastKeystrokeAt = Date()
                    model.saveDrafts()
                } else if keyCode == 51, !(model.activeSession?.fields[idx].value.isEmpty ?? true) {
                    model.objectWillChange.send()
                    if flags.contains(.maskAlternate) {
                        // Option+Backspace: delete last word (and trailing horizontal whitespace)
                        lastValueBeforeDestructiveEdit[field.id] = field.value
                        var updated = model.activeSession?.fields[idx].value ?? ""
                        while let last = updated.last, last.isWhitespace && !last.isNewline {
                            updated.removeLast()
                        }
                        if let last = updated.last, last.isNewline {
                            updated.removeLast()
                        } else {
                            while let last = updated.last, !last.isWhitespace && !last.isNewline {
                                updated.removeLast()
                            }
                        }
                        model.activeSession?.fields[idx].value = updated
                    } else {
                        model.activeSession?.fields[idx].value.removeLast()
                    }
                    model.markBrowserCaptured(field.id)
                    model.lastAutoCapturedAt = Date()
                    model.lastKeystrokeAt = Date()
                    model.saveDrafts()
                }
            } else if !pendingText.isEmpty && keyCode == 51 {
                if flags.contains(.maskAlternate) {
                    while let last = pendingText.last, last.isWhitespace && !last.isNewline {
                        pendingText.removeLast()
                    }
                    while let last = pendingText.last, !last.isWhitespace && !last.isNewline {
                        pendingText.removeLast()
                    }
                } else {
                    pendingText.removeLast()
                }
            }
            if !headless {
                self.scheduleDebouncedAXSync()
                self.scheduleFastLiveSync(delayNanoseconds: 55_000_000)
            }
            return
        }
        
        // 2. Keys that move browser focus or cancel selection (Tab, Arrows, Escape)
        if keyCode == 53 {
            isAllTextSelected = false
            return
        }
        if keyCode == 48 {
            isAllTextSelected = false
            if headless {
                _ = advanceHeadlessFocus(in: model, backward: flags.contains(.maskShift))
                return
            }
            invalidateFocus()
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 25_000_000)
                self?.syncFocusedElement()
            }
            return
        }
        if (123...126).contains(keyCode) {
            isAllTextSelected = false
            if headless {
                return
            }
            invalidateFocus()
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 25_000_000)
                self?.syncFocusedElement()
            }
            return
        }
        
        // 3. Return / Enter (KeyCode 36, 76)
        if keyCode == 36 || keyCode == 76 {
            if confirmedIdx == nil && headless {
                confirmedIdx = ensureHeadlessTextEntryFocus(in: model)
            }
            if let idx = confirmedIdx, let field = model.activeSession?.fields[idx], field.questionType == "paragraph" {
                model.objectWillChange.send()
                if isAllTextSelected {
                    lastValueBeforeDestructiveEdit[field.id] = field.value
                    model.activeSession?.fields[idx].value = "\n"
                    isAllTextSelected = false
                } else {
                    model.activeSession?.fields[idx].value.append("\n")
                }
                model.lastAutoCapturedAt = Date()
                model.lastKeystrokeAt = Date()
                model.markBrowserCaptured(field.id)
                model.saveDrafts()
            } else if headless {
                isAllTextSelected = false
                if let idx = confirmedIdx, !(model.activeSession?.fields[idx].value.isEmpty ?? true) {
                    _ = advanceHeadlessFocus(in: model, backward: false)
                }
            } else {
                // Enter may submit, advance or toggle depending on the widget: re-resolve focus
                invalidateFocus()
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 35_000_000)
                    self?.syncFocusedElement()
                }
                scheduleFastLiveSync(delayNanoseconds: 60_000_000)
            }
            return
        }
        
        // 4. Printable Characters
        guard let chars = characters, !chars.isEmpty else { return }
        let printable = chars.filter { ch in
            guard let sc = ch.unicodeScalars.first else { return false }
            return sc.value >= 32 && sc.value != 127 && (sc.value < 0xF700 || sc.value > 0xF8FF)
        }
        guard !printable.isEmpty else { return }
        
        if headless {
            if let cur = confirmedIdx, !Self.isTextEntryType(model.activeSession?.fields[cur].questionType ?? "") {
                confirmedIdx = ensureHeadlessTextEntryFocus(in: model)
            } else if confirmedIdx == nil {
                confirmedIdx = ensureHeadlessTextEntryFocus(in: model)
            }
        }
        
        guard let idx = confirmedIdx else {
            // Focus not confirmed yet: hold the text; it is flushed to the right field on confirmation
            if pendingText.isEmpty { pendingSince = Date() }
            if pendingText.count < 500 { pendingText.append(printable) }
            
            // In live browser environment, attempt immediate synchronous focus resolution
            if !MorphEnvironment.isTestingEnvironment, let frontApp = frontApp,
               let resolved = Self.resolveFocusedElement(for: frontApp) {
                let candidates = FormInputAutoTracker.candidateQuestionTitles(for: resolved.element)
                for cand in candidates {
                    let c = ApplicationFormModel.cleanQuestionTitle(cand)
                    if let i = ApplicationFormModel.strictMatchingFieldIndex(for: c, in: session.fields) {
                        confirmFocus(fieldID: session.fields[i].id, element: resolved.element)
                        break
                    }
                }
            }
            
            if let nowConfirmedIdx = confirmedFieldIndex(in: model) {
                let updatedField = (model.activeSession?.fields.indices.contains(nowConfirmedIdx) == true) ? model.activeSession?.fields[nowConfirmedIdx] : nil
                updateAutoDetectedEmailIfNeeded(from: updatedField?.value ?? "", field: updatedField, in: model)
                self.scheduleDebouncedAXSync()
                if !headless {
                    self.scheduleFastLiveSync(delayNanoseconds: 65_000_000)
                }
                return
            }
            
            self.scheduleDebouncedAXSync()
            if !headless {
                self.scheduleFastLiveSync(delayNanoseconds: 45_000_000)
            }
            return
        }
        
        // Typing into radio/checkbox/dropdown controls does not type directly into an answer option,
        // EXCEPT when typing into an "Other" free-text sub-input under multipleChoice/checkboxes:
        // trigger fast DOM/AX reconciliation rather than dropping the sync completely.
        guard let targetField = model.activeSession?.fields[idx] else { return }
        if !Self.isTextEntryType(targetField.questionType) {
            if !headless && (targetField.questionType == "multipleChoice" || targetField.questionType == "checkboxes") {
                scheduleDebouncedAXSync()
                scheduleFastLiveSync(delayNanoseconds: 45_000_000)
            }
            return
        }
        
        let toAppend = pendingText.isEmpty ? printable : (pendingText + printable)
        pendingText = ""
        pendingSince = nil
        
        model.objectWillChange.send()
        if isAllTextSelected {
            lastValueBeforeDestructiveEdit[targetField.id] = targetField.value
            model.activeSession?.fields[idx].value = toAppend
            isAllTextSelected = false
        } else {
            model.activeSession?.fields[idx].value.append(toAppend)
        }
        model.markBrowserCaptured(targetField.id)
        model.lastAutoCapturedAt = Date()
        model.lastKeystrokeAt = Date()
        model.saveDrafts()
        
        updateAutoDetectedEmailIfNeeded(from: model.activeSession?.fields[idx].value ?? "", field: model.activeSession?.fields[idx], in: model)
        
        if !headless {
            // Reconcile exact text from browser via debounced AX + fast live DOM sync
            self.scheduleDebouncedAXSync()
            self.scheduleFastLiveSync(delayNanoseconds: 65_000_000)
        }
    }
    
    public func handleGlobalKeyEvent(_ event: NSEvent) {
        let keyCode = Int(event.keyCode)
        let flags = event.modifierFlags
        let characters = event.characters
        var cgFlags = CGEventFlags()
        if flags.contains(.command) { cgFlags.insert(.maskCommand) }
        if flags.contains(.control) { cgFlags.insert(.maskControl) }
        if flags.contains(.shift) { cgFlags.insert(.maskShift) }
        if flags.contains(.option) { cgFlags.insert(.maskAlternate) }
        Task { @MainActor [weak self] in
            self?.handleKeyStroke(keyCode: keyCode, flags: cgFlags, characters: characters)
        }
    }
    
    private func scheduleDebouncedAXSync() {
        debouncedAXSyncTask?.cancel()
        debouncedAXSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }
            self?.syncFocusedElement()
        }
    }
    
    private func scheduleFastLiveSync(delayNanoseconds: UInt64 = 55_000_000) {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        fastLiveSyncTask?.cancel()
        fastLiveSyncTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard !Task.isCancelled else { return }
            self?.formModel?.syncLiveFormInputValues(isBackground: true, urgent: true)
        }
    }
    
    @MainActor
    public func syncFocusedElement(at point: CGPoint? = nil) {
        guard let model = formModel, model.isFormDetected, model.isAutoCaptureEnabled,
              let session = model.activeSession else { return }
        
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              DefaultApplicationFormDetector.isBrowserApplication(frontApp) else { return }
        
        if isHeadlessBrowserActive(frontApp: frontApp, model: model) {
            if point == nil && Self.isBrowserChromeInputFocused(for: frontApp) {
                invalidateFocus()
            }
            return
        }
        
        var targetElem: AXUIElement? = nil
        var elemRole: String = ""
        
        if let pt = point {
            let sys = AXUIElementCreateSystemWide()
            var hitRef: AXUIElement?
            if AXUIElementCopyElementAtPosition(sys, Float(pt.x), Float(pt.y), &hitRef) == .success, let hit = hitRef {
                var hitPid: pid_t = 0
                AXUIElementGetPid(hit, &hitPid)
                if hitPid == ProcessInfo.processInfo.processIdentifier { return }
                if let hApp = NSRunningApplication(processIdentifier: hitPid),
                   let bid = hApp.bundleIdentifier?.lowercased(),
                   bid.contains("com.morph.") || bid == "morph" { return }
                
                var rRef: CFTypeRef?
                AXUIElementCopyAttributeValue(hit, kAXRoleAttribute as CFString, &rRef)
                let r = (rRef as? String) ?? ""
                if Self.isInteractiveInputRole(r) {
                    targetElem = hit
                    elemRole = r
                } else {
                    // Check up to 8 ancestors if clicked element was a label, text, or icon inside an input
                    var cur = hit
                    for _ in 0..<8 {
                        var pRef: CFTypeRef?
                        guard AXUIElementCopyAttributeValue(cur, kAXParentAttribute as CFString, &pRef) == .success,
                              let p = pRef else { break }
                        cur = p as! AXUIElement
                        var prRef: CFTypeRef?
                        AXUIElementCopyAttributeValue(cur, kAXRoleAttribute as CFString, &prRef)
                        let pr = (prRef as? String) ?? ""
                        if Self.isInteractiveInputRole(pr) {
                            targetElem = cur
                            elemRole = pr
                            break
                        }
                    }
                }
            }
        }
        
        if targetElem == nil {
            if let resolved = Self.resolveFocusedElement(for: frontApp) {
                targetElem = resolved.element
                elemRole = resolved.role
            } else {
                let appElem = AXUIElementCreateApplication(frontApp.processIdentifier)
                if let win = DefaultApplicationFormDetector.getBrowserWindowElement(appElem: appElem),
                   Self.findWebAreaElement(in: win) == nil {
                    _ = Self.ensureWebAccessibilityEnabledIfNeeded(for: frontApp, appElem: appElem, window: win)
                    if let resolvedAfter = Self.resolveFocusedElement(for: frontApp) {
                        targetElem = resolvedAfter.element
                        elemRole = resolvedAfter.role
                    }
                }
            }
        }
        
        guard let targetElem = targetElem else { return }
        
        // Guard against browser native chrome (tabs, address bar, bookmarks bar, sidebars):
        // Only elements residing inside web content (AXWebArea) represent actual form questions/inputs.
        if !MorphEnvironment.isTestingEnvironment && !Self.isElementInsideWebArea(targetElem) {
            invalidateFocus()
            return
        }
        
        var targetPid: pid_t = 0
        AXUIElementGetPid(targetElem, &targetPid)
        if targetPid == ProcessInfo.processInfo.processIdentifier { return }
        if let tApp = NSRunningApplication(processIdentifier: targetPid),
           let bid = tApp.bundleIdentifier?.lowercased(),
           bid.contains("com.morph.") || bid == "morph" { return }
        
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(targetElem, kAXTitleAttribute as CFString, &titleRef)
        var descRef: CFTypeRef?
        AXUIElementCopyAttributeValue(targetElem, kAXDescriptionAttribute as CFString, &descRef)
        var valRef: CFTypeRef?
        AXUIElementCopyAttributeValue(targetElem, kAXValueAttribute as CFString, &valRef)
        
        let elemTitle = Self.axString(targetElem, kAXTitleAttribute as String) ?? Self.axString(targetElem, kAXDescriptionAttribute as String) ?? ""
        let textVal = (valRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ignore browser address bar chrome exact labels (never reject "Email Address" inside AXWebArea)
        let lowerTitle = elemTitle.lowercased()
        if lowerTitle == "address and search bar" || lowerTitle == "address bar" || lowerTitle == "address" || lowerTitle == "search or enter website name" {
            invalidateFocus()
            return
        }
        
        // Resolve WHICH question this element belongs to. Candidate headings are tried nearest-first and the
        // first one that strictly matches an actionable schema field wins; nothing is ever written to a guessed field.
        var candidates = FormInputAutoTracker.candidateQuestionTitles(for: targetElem)
        if !elemTitle.isEmpty { candidates.append(elemTitle) }
        var matchedIdx: Int? = nil
        var cleanQuestion = ""
        for cand in candidates {
            let c = ApplicationFormModel.cleanQuestionTitle(cand)
            if c.isEmpty { continue }
            if cleanQuestion.isEmpty { cleanQuestion = c }
            if let i = ApplicationFormModel.strictMatchingFieldIndex(for: c, in: session.fields) {
                matchedIdx = i
                cleanQuestion = c
                break
            }
        }
        
        if matchedIdx == nil, session.fields.isEmpty, !cleanQuestion.isEmpty {
            // ONLY dynamically register fields if the session has NO pre-loaded schema
            let ignoredTitles: Set<String> = [
                "address", "address and search bar", "search", "search or enter website name",
                "back", "forward", "reload", "refresh", "home", "sidebar", "show sidebar", "hide sidebar",
                "extensions", "extension", "profiles", "profiles and menu", "profile", "bookmarks", "bookmark",
                "bookmark this page", "downloads", "history", "settings", "options", "menu", "close", "minimize",
                "zoom", "fullscreen", "new tab", "tab", "tab name", "all", "required", "ask polar", "polar", "morph",
                "edit", "view", "window", "help", "file", "tools", "share"
            ]
            let lowerQ = cleanQuestion.lowercased()
            if !ignoredTitles.contains(lowerQ) && !lowerQ.hasPrefix("all,") && !lowerQ.hasPrefix("required,") && cleanQuestion.count >= 3 && !cleanQuestion.contains(",") {
                let cat = FormContentRetriever.inferCategory(from: cleanQuestion)
                let qType: String
                if elemRole == "AXTextArea" {
                    qType = "paragraph"
                } else if elemRole == "AXRadioButton" {
                    qType = "multipleChoice"
                } else if elemRole == "AXCheckBox" {
                    qType = "checkboxes"
                } else if elemRole == "AXPopUpButton" || elemRole == "AXComboBox" {
                    qType = "dropdown"
                } else {
                    qType = "shortAnswer"
                }
                let isReq = FormInputAutoTracker.isElementRequired(targetElem)
                let newField = FormInputField(label: cleanQuestion, value: "", category: cat, questionType: qType, isRequired: isReq)
                model.objectWillChange.send()
                model.activeSession?.fields.append(newField)
                model.lastAutoCapturedAt = Date()
                matchedIdx = (model.activeSession?.fields.count ?? 1) - 1
            }
        }
        
        guard let activeIdx = matchedIdx, activeIdx < (model.activeSession?.fields.count ?? 0),
              let fieldID = model.activeSession?.fields[activeIdx].id else {
            // Focused element is not a recognised question (browser chrome, other page...): stop attributing typing
            invalidateFocus()
            return
        }
        confirmFocus(fieldID: fieldID, element: targetElem)
        
        // Refine question type based on live accessibility role if currently generic or unassigned
        let currentType = model.activeSession?.fields[activeIdx].questionType ?? "shortAnswer"
        let selectedPopupLower = (textVal ?? (titleRef as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isAmPmPopup = (selectedPopupLower == "am" || selectedPopupLower == "pm")
        if currentType == "shortAnswer" || currentType == "text" || currentType.isEmpty {
            if elemRole == "AXTextArea" {
                model.activeSession?.fields[activeIdx].questionType = "paragraph"
            } else if elemRole == "AXRadioButton" {
                model.activeSession?.fields[activeIdx].questionType = "multipleChoice"
            } else if elemRole == "AXCheckBox" {
                model.activeSession?.fields[activeIdx].questionType = "checkboxes"
            } else if (elemRole == "AXPopUpButton" || elemRole == "AXComboBox" || elemRole == "AXMenuButton") && !isAmPmPopup {
                model.activeSession?.fields[activeIdx].questionType = "dropdown"
            }
        }
        
        // 2. Text input sync (AXTextField, AXTextArea, AXSearchField, AXComboBox)
        if elemRole == "AXTextField" || elemRole == "AXTextArea" || elemRole == "AXSearchField" || elemRole == "AXComboBox" {
            let activeType = model.activeSession?.fields[activeIdx].questionType ?? ""
            let lowerElemTitle = elemTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let lowerTextVal = (textVal ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let isTimeAmPmControl = (activeType == "time") && (lowerElemTitle == "am" || lowerElemTitle == "pm" || lowerTextVal == "am" || lowerTextVal == "pm")
            let isCompositeDateTimeSegment = ((activeType == "date" || activeType == "time") && Self.subInputPartLabels.contains(lowerElemTitle)) || isTimeAmPmControl
            let isOtherTextSubInput = (activeType == "multipleChoice" || activeType == "checkboxes") &&
                (lowerElemTitle == "other" || lowerElemTitle.hasPrefix("other response") || lowerElemTitle.hasPrefix("other:"))
            if isCompositeDateTimeSegment {
                scheduleFastLiveSync(delayNanoseconds: 25_000_000)
            } else if isOtherTextSubInput {
                let tv = textVal ?? ""
                let current = model.activeSession?.fields[activeIdx].value ?? ""
                if !tv.isEmpty {
                    let isDirectReplace = (activeType == "multipleChoice") || current.isEmpty || Self.isOtherPlaceholderToken(current)
                    if isDirectReplace {
                        if current != tv {
                            model.objectWillChange.send()
                            model.activeSession?.fields[activeIdx].value = tv
                            model.lastAutoCapturedAt = Date()
                            model.markBrowserCaptured(fieldID)
                        }
                    } else if activeType == "checkboxes" {
                        let parts = current.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        if parts.contains(where: { Self.isOtherPlaceholderToken($0) }) {
                            let updated = parts.map { Self.isOtherPlaceholderToken($0) ? tv : $0 }.joined(separator: ", ")
                            if current != updated {
                                model.objectWillChange.send()
                                model.activeSession?.fields[activeIdx].value = updated
                                model.lastAutoCapturedAt = Date()
                                model.markBrowserCaptured(fieldID)
                            }
                        }
                    }
                    scheduleFastLiveSync(delayNanoseconds: 25_000_000)
                } else {
                    // Empty "Other response" text sub-input must never clear a selected choice
                    scheduleFastLiveSync(delayNanoseconds: 25_000_000)
                }
            } else {
                let tv = textVal ?? ""
                let current = model.activeSession?.fields[activeIdx].value ?? ""
                let isQuiet = model.lastKeystrokeAt.map { Date().timeIntervalSince($0) >= 0.30 } ?? true
                
                if current != tv {
                    if !tv.isEmpty {
                        // Do not revert real-time HID keystrokes back to a slightly lagging shorter AX readback while user is actively typing
                        let isLaggingShorterPrefix = !isQuiet && current.hasPrefix(tv) && tv.count < current.count
                        if !isLaggingShorterPrefix {
                            model.objectWillChange.send()
                            model.activeSession?.fields[activeIdx].value = tv
                            model.lastAutoCapturedAt = Date()
                            model.markBrowserCaptured(fieldID)
                        }
                    } else if isQuiet && !model.manuallyEditedFieldIDs.contains(fieldID) {
                        // Browser input is genuinely empty ("") and user is not actively typing a keystroke:
                        // Reconcile field to empty string so phantom or cleared answers reflect reality immediately.
                        model.objectWillChange.send()
                        model.activeSession?.fields[activeIdx].value = ""
                        model.markBrowserCaptured(fieldID)
                    }
                }
            }
        }
        
        // 3. Radio button selection sync (AXRadioButton)
        if elemRole == "AXRadioButton" {
            var checkedRef: CFTypeRef?
            AXUIElementCopyAttributeValue(targetElem, kAXValueAttribute as CFString, &checkedRef)
            let isChecked = (checkedRef as? Int == 1) || (checkedRef as? Bool == true)
            if isChecked {
                var optionName = Self.extractOptionTitle(from: targetElem)
                if optionName.isEmpty || optionName.lowercased() == cleanQuestion.lowercased() {
                    optionName = (!elemTitle.isEmpty && elemTitle.lowercased() != cleanQuestion.lowercased()) ? elemTitle : (textVal ?? "")
                }
                if !optionName.isEmpty {
                    let current = model.activeSession?.fields[activeIdx].value ?? ""
                    if current != optionName {
                        model.objectWillChange.send()
                        model.activeSession?.fields[activeIdx].value = optionName
                        model.lastAutoCapturedAt = Date()
                    }
                    model.markBrowserCaptured(fieldID)
                }
            }
        }
        
        // 4. Checkbox selection sync (AXCheckBox)
        if elemRole == "AXCheckBox" {
            var checkedRef: CFTypeRef?
            AXUIElementCopyAttributeValue(targetElem, kAXValueAttribute as CFString, &checkedRef)
            let isChecked = (checkedRef as? Int == 1) || (checkedRef as? Bool == true)
            var optionName = Self.extractOptionTitle(from: targetElem)
            if optionName.isEmpty || optionName.lowercased() == cleanQuestion.lowercased() {
                optionName = (!elemTitle.isEmpty && elemTitle.lowercased() != cleanQuestion.lowercased()) ? elemTitle : (textVal ?? "")
            }
            if !optionName.isEmpty {
                let current = model.activeSession?.fields[activeIdx].value ?? ""
                var selectedOptions = current.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                if isChecked {
                    if !selectedOptions.contains(optionName) {
                        selectedOptions.append(optionName)
                    }
                } else {
                    selectedOptions.removeAll { $0 == optionName }
                }
                let newVal = selectedOptions.joined(separator: ", ")
                if current != newVal {
                    model.objectWillChange.send()
                    model.activeSession?.fields[activeIdx].value = newVal
                    model.lastAutoCapturedAt = Date()
                }
                model.markBrowserCaptured(fieldID)
            }
        }
        
        // 5. Dropdown / PopUpButton / MenuButton selection sync
        if elemRole == "AXPopUpButton" || elemRole == "AXMenuButton" || (elemRole == "AXComboBox" && (model.activeSession?.fields[activeIdx].questionType == "dropdown")) {
            let rawDrop = textVal ?? (titleRef as? String) ?? ""
            let selectedVal = rawDrop.trimmingCharacters(in: .whitespacesAndNewlines)
            let activeType = model.activeSession?.fields[activeIdx].questionType ?? ""
            let isTimeAmPmSelector = (activeType == "time") && ["am", "pm"].contains(selectedVal.lowercased())
            if isTimeAmPmSelector {
                scheduleFastLiveSync(delayNanoseconds: 25_000_000)
            } else if !selectedVal.isEmpty,
               !["choose", "select", "select an option", "choose an option"].contains(selectedVal.lowercased()) {
                if model.activeSession?.fields[activeIdx].value != selectedVal {
                    model.objectWillChange.send()
                    model.activeSession?.fields[activeIdx].value = selectedVal
                    model.lastAutoCapturedAt = Date()
                }
                model.markBrowserCaptured(fieldID)
            }
        }
        
        model.saveDrafts()
    }
    
    // MARK: - Hierarchy Inspection Helpers
    private static let genericTitleNoise: Set<String> = [
        "your answer", "address and search bar", "search", "text", "edit", "input",
        "*", "required question", "clear selection", "other:", "other option", "required", "choose", "clear",
        "tab", "tab bar", "tabs", "new tab", "close tab", "active tab",
        "window", "main window", "browser window", "address bar",
        "search or enter website name", "url", "polar", "google chrome", "chrome",
        "safari", "brave", "arc", "edge", "firefox", "ask polar", "morph",
        "back", "forward", "reload", "refresh", "home", "sidebar", "show sidebar", "hide sidebar",
        "extensions", "extension", "profiles", "profile", "bookmarks", "bookmark", "downloads",
        "history", "settings", "options", "menu", "close", "minimize", "zoom", "fullscreen",
        "switch account", "your email will be recorded", "indicates required question", "basic information",
        "never submit passwords through google forms", "this content is neither created nor endorsed by google",
        "report abuse", "terms of service", "privacy policy"
    ]
    
    private static func axString(_ elem: AXUIElement, _ attr: String) -> String? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(elem, attr as CFString, &ref) == .success, let str = ref as? String else { return nil }
        let t = str.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
    
    private static func axRole(_ elem: AXUIElement) -> String { axString(elem, kAXRoleAttribute as String) ?? "" }
    
    private static let subInputPartLabels: Set<String> = [
        "month", "day", "year", "hour", "minute", "second", "other response", "other"
    ]
    
    private static func axChildren(_ elem: AXUIElement) -> [AXUIElement] {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(elem, kAXChildrenAttribute as CFString, &ref) == .success,
              let kids = ref as? [AXUIElement] else { return [] }
        return kids
    }
    
    private static func axText(_ elem: AXUIElement) -> String? {
        axString(elem, kAXValueAttribute as String) ?? axString(elem, kAXTitleAttribute as String) ?? axString(elem, kAXDescriptionAttribute as String)
    }
    
    /// Recursively collects text from an element and its shallow AXStaticText/AXHeading/AXGroup descendants
    /// (critical for Chrome/Safari where `AXHeading` stores its visible string inside a nested `AXStaticText`).
    private static func axCollectedText(_ elem: AXUIElement, depth: Int = 3) -> String? {
        if let direct = axText(elem) { return direct }
        guard depth > 0 else { return nil }
        var parts: [String] = []
        for ch in axChildren(elem).prefix(20) {
            let r = axRole(ch)
            if r == "AXStaticText" || r == "AXHeading" || r == "AXGroup" {
                if let sub = axCollectedText(ch, depth: depth - 1), !sub.isEmpty {
                    parts.append(sub)
                }
            }
        }
        let joined = parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? nil : joined
    }
    
    /// True when an element (or something beneath it) is an interactive input, i.e. it is another question's container.
    private static func containsInteractiveInput(_ elem: AXUIElement, depth: Int = 3) -> Bool {
        for ch in axChildren(elem).prefix(40) {
            let r = axRole(ch)
            if isInteractiveInputRole(r) && r != "AXButton" { return true }
            if depth > 1 && containsInteractiveInput(ch, depth: depth - 1) { return true }
        }
        return false
    }
    
    /// Ordered question-title candidates for an element, nearest/most specific first:
    /// its own labels, then headings/static text that PRECEDE it in each ancestor (never following siblings, never
    /// other questions' containers), stopping after the first level that yields a real heading. The caller picks the
    /// first candidate that matches a schema question, so a stray decoration can never claim the field.
    public static func candidateQuestionTitles(for elem: AXUIElement, limit: Int = 12) -> [String] {
        var out: [String] = []
        var deferredSubLabels: [String] = []
        func add(_ raw: String?, minLength: Int = 1, allowSubInputPriority: Bool = false) {
            guard out.count < limit, let raw = raw else { return }
            let trimmedRaw = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedRaw.isEmpty, !trimmedRaw.hasPrefix("http"), trimmedRaw != "*", !trimmedRaw.contains("@") else { return }
            var stripped = trimmedRaw.replacingOccurrences(
                of: #"\s*\*\s*(?:Indicates\s+)?Required\s+question\s*$"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            if stripped == trimmedRaw {
                stripped = trimmedRaw.replacingOccurrences(
                    of: #"\s+(?:Indicates\s+)?Required\s+question\s*$"#,
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
            }
            let c = ApplicationFormModel.cleanQuestionTitle(stripped)
            guard c.count >= minLength, !genericTitleNoise.contains(c.lowercased()), !genericTitleNoise.contains(trimmedRaw.lowercased()) else { return }
            if !allowSubInputPriority && subInputPartLabels.contains(c.lowercased()) {
                if !deferredSubLabels.contains(c) { deferredSubLabels.append(c) }
                return
            }
            if !out.contains(c) { out.append(c) }
        }
        
        add(axString(elem, kAXTitleAttribute as String))
        add(axString(elem, kAXDescriptionAttribute as String))
        add(axString(elem, kAXHelpAttribute as String))
        
        var titleElemRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(elem, kAXTitleUIElementAttribute as CFString, &titleElemRef) == .success, let te = titleElemRef {
            add(axCollectedText(te as! AXUIElement))
        }
        var linkedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(elem, "AXLinkedUIElements" as CFString, &linkedRef) == .success,
           let linkedList = linkedRef as? [AXUIElement] {
            for linked in linkedList { add(axCollectedText(linked)) }
        }
        
        func inspectPrecedingGroup(_ group: AXUIElement, depth: Int, foundHeading: inout Bool) {
            for ch in axChildren(group).prefix(30) {
                let r = axRole(ch)
                if r == "AXHeading" {
                    if let t = axCollectedText(ch, depth: 3) {
                        add(t, minLength: 2, allowSubInputPriority: true)
                        foundHeading = true
                    }
                } else if r == "AXGroup" && depth > 1 {
                    inspectPrecedingGroup(ch, depth: depth - 1, foundHeading: &foundHeading)
                }
                if foundHeading { return }
            }
            if !foundHeading {
                for ch in axChildren(group).prefix(30) where axRole(ch) == "AXStaticText" {
                    add(axCollectedText(ch, depth: 2), minLength: 2)
                }
            }
        }
        
        var child = elem
        for _ in 0..<10 {
            var parentRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXParentAttribute as CFString, &parentRef) == .success,
                  let p = parentRef else { break }
            let parent = p as! AXUIElement
            let role = axRole(parent)
            if role == "AXWebArea" || role == "AXWindow" { break }
            
            add(axString(parent, kAXTitleAttribute as String), minLength: 3)
            add(axString(parent, kAXDescriptionAttribute as String), minLength: 3)
            
            let siblings = axChildren(parent)
            var foundHeading = false
            if let idx = siblings.firstIndex(where: { CFEqual($0, child) }) {
                for sib in siblings[..<idx].reversed() {
                    let sr = axRole(sib)
                    if sr == "AXHeading" {
                        if let t = axCollectedText(sib, depth: 3) {
                            add(t, minLength: 2, allowSubInputPriority: true)
                            foundHeading = true
                        }
                    } else if sr == "AXStaticText" {
                        add(axCollectedText(sib, depth: 2), minLength: 3)
                    } else if sr == "AXGroup", !containsInteractiveInput(sib, depth: 4) {
                        inspectPrecedingGroup(sib, depth: 4, foundHeading: &foundHeading)
                    }
                    if foundHeading { break }
                }
            }
            if foundHeading || out.count >= limit { break }
            child = parent
        }
        for sub in deferredSubLabels where out.count < limit {
            if !out.contains(sub) { out.append(sub) }
        }
        return out
    }
    
    /// Resolves the best question title for a focused or scanned element (nearest candidate heading).
    public static func findQuestionTitleForElement(_ elem: AXUIElement) -> String? {
        return candidateQuestionTitles(for: elem).first
    }
    
    /// Determines whether an accessibility element or its parent container indicates a required answer.
    /// Extracts option title from an AX radio button, checkbox, or option element
    public static func extractOptionTitle(from elem: AXUIElement) -> String {
        var titleRef: CFTypeRef?, descRef: CFTypeRef?
        AXUIElementCopyAttributeValue(elem, kAXTitleAttribute as CFString, &titleRef)
        AXUIElementCopyAttributeValue(elem, kAXDescriptionAttribute as CFString, &descRef)
        let t = ((titleRef as? String) ?? (descRef as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty && t != "1" && t != "0" { return t }
        
        var titleElemRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(elem, kAXTitleUIElementAttribute as CFString, &titleElemRef) == .success,
           let te = titleElemRef {
            if let text = axCollectedText(te as! AXUIElement, depth: 3), !text.isEmpty { return text }
        }
        
        for ch in axChildren(elem) {
            let r = axRole(ch)
            if r == "AXStaticText" || r == "AXGroup" {
                if let text = axCollectedText(ch, depth: 3), !text.isEmpty && text != "1" && text != "0" { return text }
            }
        }
        
        var parentRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(elem, kAXParentAttribute as CFString, &parentRef) == .success,
           let p = parentRef {
            for sib in axChildren(p as! AXUIElement) {
                let r = axRole(sib)
                if r == "AXStaticText" || r == "AXGroup" {
                    if let text = axCollectedText(sib, depth: 2), !text.isEmpty && text != "1" && text != "0" { return text }
                }
            }
        }
        return ""
    }
    
    /// Detects whether an accessibility element corresponds to a 'Clear form' action or its confirmation dialog button.
    public static func isClearFormElement(_ elem: AXUIElement) -> (isClearButton: Bool, isConfirmedInDialog: Bool) {
        let keywords = ["clear form", "xóa câu trả lời", "effacer le formulaire", "borrar formulario", "formular leeren", "limpar formulário"]
        func matchesKeyword(_ text: String?) -> Bool {
            guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !t.isEmpty else { return false }
            return keywords.contains { t == $0 || t.hasPrefix($0) || t.contains($0) }
        }
        
        var isClear = false
        if matchesKeyword(axString(elem, kAXTitleAttribute as String)) ||
           matchesKeyword(axString(elem, kAXDescriptionAttribute as String)) ||
           matchesKeyword(axString(elem, kAXValueAttribute as String)) {
            isClear = true
        }
        
        if !isClear {
            for ch in axChildren(elem) {
                if matchesKeyword(axText(ch)) {
                    isClear = true
                    break
                }
            }
        }
        
        var isDialogConfirm = false
        if isClear {
            var cur = elem
            for _ in 0..<6 {
                var pRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(cur, kAXParentAttribute as CFString, &pRef) == .success,
                      let p = pRef else { break }
                let parent = p as! AXUIElement
                let role = axRole(parent)
                let title = (axString(parent, kAXTitleAttribute as String) ?? "").lowercased()
                let desc = (axString(parent, kAXDescriptionAttribute as String) ?? "").lowercased()
                if role == "AXDialog" || role == "AXSheet" || title.contains("clear form") || desc.contains("cannot be undone") || desc.contains("remove your answers") {
                    isDialogConfirm = true
                    break
                }
                cur = parent
            }
        }
        
        return (isClear, isDialogConfirm)
    }

    public static func isElementRequired(_ elem: AXUIElement) -> Bool {
        var reqRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(elem, "AXRequired" as CFString, &reqRef) == .success {
            if let b = reqRef as? Bool, b {
                return true
            }
            if let n = reqRef as? Int, n == 1 {
                return true
            }
        }
        
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(elem, kAXTitleAttribute as CFString, &titleRef)
        var descRef: CFTypeRef?
        AXUIElementCopyAttributeValue(elem, kAXDescriptionAttribute as CFString, &descRef)
        let t = ((titleRef as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let d = ((descRef as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasSuffix("*") || t.contains(" *") || d.hasSuffix("*") || d.contains(" *") || t.localizedCaseInsensitiveContains("required") || d.localizedCaseInsensitiveContains("required") {
            return true
        }
        
        var current = elem
        for _ in 0..<5 {
            var parentRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentRef) == .success,
                  let p = parentRef else { break }
            current = p as! AXUIElement
            
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(current, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                for ch in children {
                    var rRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(ch, kAXRoleAttribute as CFString, &rRef)
                    let role = (rRef as? String) ?? ""
                    if role == "AXStaticText" || role == "AXHeading" {
                        var vRef: CFTypeRef?, cTitleRef: CFTypeRef?
                        AXUIElementCopyAttributeValue(ch, kAXValueAttribute as CFString, &vRef)
                        AXUIElementCopyAttributeValue(ch, kAXTitleAttribute as CFString, &cTitleRef)
                        let text = ((vRef as? String) ?? (cTitleRef as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if text == "*" || text.hasSuffix("*") || text.localizedCaseInsensitiveContains("required") {
                            return true
                        }
                    }
                }
            }
        }
        return false
    }
    
    /// Searches for the AXWebArea element within a browser window to bypass window chrome and tabs.
    public static func findWebAreaElement(in root: AXUIElement) -> AXUIElement? {
        var queue: [AXUIElement] = [root]
        var head = 0
        let maxDepthCheck = 2500
        
        while head < queue.count && head < maxDepthCheck {
            let cur = queue[head]
            head += 1
            
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(cur, kAXRoleAttribute as CFString, &roleRef)
            let role = (roleRef as? String) ?? ""
            if role == "AXWebArea" {
                return cur
            }
            
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(cur, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                for c in children {
                    queue.append(c)
                }
            }
        }
        return nil
    }
    
    /// Verifies whether an accessibility element resides within an AXWebArea document tree
    /// (ruling out browser native tabs, address/search bars, bookmarks, and devtools).
    public static func isElementInsideWebArea(_ elem: AXUIElement) -> Bool {
        var cur = elem
        for _ in 0..<25 {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(cur, kAXRoleAttribute as CFString, &roleRef)
            let role = (roleRef as? String) ?? ""
            if role == "AXWebArea" { return true }
            if role == "AXWindow" || role == "AXApplication" { return false }
            var parentRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(cur, kAXParentAttribute as CFString, &parentRef) == .success,
                  let p = parentRef else { break }
            cur = (p as! AXUIElement)
        }
        return false
    }
    
    /// Resolves the question label for a scanned input: the nearest candidate heading that strictly matches a schema
    /// question (returned as the schema's own label), otherwise - only when no schema exists - the nearest heading.
    static func resolveQuestionLabel(for elem: AXUIElement, fields: [FormInputField], fallback: String = "") -> String {
        let candidates = candidateQuestionTitles(for: elem) + (fallback.isEmpty ? [] : [fallback])
        for cand in candidates {
            if let i = ApplicationFormModel.strictMatchingFieldIndex(for: cand, in: fields) { return fields[i].label }
        }
        return fields.contains(where: { $0.isActionableQuestion }) ? "" : (candidates.first ?? "")
    }
    
    /// Scans the browser content window to extract live input field values paired with their question labels, format, and choices.
    public static func scanBrowserWindowInputItems(appElem: AXUIElement, fields: [FormInputField] = []) -> [ExtractedInputItem]? {
        guard let win = DefaultApplicationFormDetector.getBrowserWindowElement(appElem: appElem) else {
            return nil
        }
        
        // Form inputs must reside within web document content (AXWebArea).
        // If no AXWebArea exists, never scan native window chrome (tabs, search bars, toolbars).
        guard let startElem = findWebAreaElement(in: win) else {
            return nil
        }
        
        var fieldValues: [String: (val: String, type: String, options: [String])] = [:]
        var otherTypedTextByLabel: [String: String] = [:]
        var queue: [AXUIElement] = [startElem]
        var head = 0
        let maxElements = 10000
        
        while head < queue.count && head < maxElements {
            let current = queue[head]
            head += 1
            
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &roleRef)
            let role = (roleRef as? String) ?? ""
            
            if role == "AXTextField" || role == "AXTextArea" || role == "AXSearchField" {
                var descRef: CFTypeRef?
                AXUIElementCopyAttributeValue(current, kAXDescriptionAttribute as CFString, &descRef)
                let desc = (descRef as? String) ?? ""
                let lowerDesc = desc.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let isChromeAddressBar = lowerDesc == "address and search bar" || lowerDesc == "address bar" || lowerDesc == "address" || lowerDesc == "search or enter website name"
                let isDateTimeSubInput = ["month", "day", "year", "hour", "minute", "second"].contains(lowerDesc)
                let isOtherTextSubInput = lowerDesc == "other" || lowerDesc.hasPrefix("other response") || lowerDesc.hasPrefix("other:")
                if !isChromeAddressBar && !isDateTimeSubInput {
                    var valRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(current, kAXValueAttribute as CFString, &valRef)
                    let textVal = (valRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if isOtherTextSubInput && textVal.isEmpty {
                        // Never let an empty "Other" text input wipe a selected choice or overwrite type
                    } else {
                        let label = resolveQuestionLabel(for: current, fields: fields, fallback: desc)
                        let cleanLbl = ApplicationFormModel.cleanQuestionTitle(label)
                        let schemaType = fields.first(where: { $0.label.caseInsensitiveCompare(cleanLbl) == .orderedSame })?.questionType
                        let qType = (isOtherTextSubInput ? (schemaType ?? fieldValues[cleanLbl]?.type ?? "shortAnswer") : nil) ?? ((role == "AXTextArea") ? "paragraph" : "shortAnswer")
                        if !cleanLbl.isEmpty {
                            if isOtherTextSubInput {
                                if !textVal.isEmpty {
                                    otherTypedTextByLabel[cleanLbl] = textVal
                                    if fieldValues[cleanLbl] == nil {
                                        fieldValues[cleanLbl] = (val: "", type: qType, options: [])
                                    }
                                }
                            } else if !textVal.isEmpty || fieldValues[cleanLbl] == nil {
                                fieldValues[cleanLbl] = (val: textVal, type: qType, options: [])
                            }
                        }
                    }
                }
            } else if role == "AXRadioButton" {
                var checkedRef: CFTypeRef?
                AXUIElementCopyAttributeValue(current, kAXValueAttribute as CFString, &checkedRef)
                let isChecked = (checkedRef as? Int == 1) || (checkedRef as? Bool == true)
                let qLabel = resolveQuestionLabel(for: current, fields: fields)
                let cleanLbl = ApplicationFormModel.cleanQuestionTitle(qLabel)
                if !cleanLbl.isEmpty {
                    let schemaType = fields.first(where: { $0.label.caseInsensitiveCompare(cleanLbl) == .orderedSame })?.questionType
                    let resolvedType = (schemaType == "linearScale" || schemaType == "grid") ? schemaType! : "multipleChoice"
                    let optionTitle = extractOptionTitle(from: current)
                    var existingOpts = fieldValues[cleanLbl]?.options ?? []
                    if !optionTitle.isEmpty && !existingOpts.contains(optionTitle) {
                        existingOpts.append(optionTitle)
                    }
                    if isChecked {
                        fieldValues[cleanLbl] = (val: optionTitle, type: resolvedType, options: existingOpts)
                    } else if fieldValues[cleanLbl] == nil {
                        fieldValues[cleanLbl] = (val: "", type: resolvedType, options: existingOpts)
                    } else {
                        fieldValues[cleanLbl]?.options = existingOpts
                    }
                }
            } else if role == "AXCheckBox" {
                var checkedRef: CFTypeRef?
                AXUIElementCopyAttributeValue(current, kAXValueAttribute as CFString, &checkedRef)
                let isChecked = (checkedRef as? Int == 1) || (checkedRef as? Bool == true)
                let qLabel = resolveQuestionLabel(for: current, fields: fields)
                let cleanLbl = ApplicationFormModel.cleanQuestionTitle(qLabel)
                if !cleanLbl.isEmpty {
                    let schemaType = fields.first(where: { $0.label.caseInsensitiveCompare(cleanLbl) == .orderedSame })?.questionType
                    let resolvedType = (schemaType == "grid") ? "grid" : "checkboxes"
                    let optionTitle = extractOptionTitle(from: current)
                    var existingOpts = fieldValues[cleanLbl]?.options ?? []
                    if !optionTitle.isEmpty && !existingOpts.contains(optionTitle) {
                        existingOpts.append(optionTitle)
                    }
                    if isChecked {
                        if !optionTitle.isEmpty {
                            if let existing = fieldValues[cleanLbl]?.val, !existing.isEmpty {
                                let parts = existing.components(separatedBy: ", ")
                                if !parts.contains(optionTitle) {
                                    fieldValues[cleanLbl] = (val: existing + ", " + optionTitle, type: resolvedType, options: existingOpts)
                                }
                            } else {
                                fieldValues[cleanLbl] = (val: optionTitle, type: resolvedType, options: existingOpts)
                            }
                        }
                    } else if fieldValues[cleanLbl] == nil {
                        fieldValues[cleanLbl] = (val: "", type: resolvedType, options: existingOpts)
                    } else {
                        fieldValues[cleanLbl]?.options = existingOpts
                    }
                }
            } else if role == "AXPopUpButton" || role == "AXComboBox" || role == "AXMenuButton" {
                var valRef: CFTypeRef?, titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(current, kAXValueAttribute as CFString, &valRef)
                AXUIElementCopyAttributeValue(current, kAXTitleAttribute as CFString, &titleRef)
                let popVal = ((valRef as? String) ?? (titleRef as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let ignoredDrop = ["choose", "select", "select an option", "choose an option"]
                let qLabel = resolveQuestionLabel(for: current, fields: fields)
                let cleanLbl = ApplicationFormModel.cleanQuestionTitle(qLabel)
                if !cleanLbl.isEmpty {
                    let schemaType = fields.first(where: { $0.label.caseInsensitiveCompare(cleanLbl) == .orderedSame })?.questionType
                    let lowerPop = popVal.lowercased()
                    if schemaType == "time" && (lowerPop == "am" || lowerPop == "pm") {
                        // Do not overwrite composite time field with standalone AM/PM selector
                    } else {
                        let chosen = (!popVal.isEmpty && !ignoredDrop.contains(lowerPop)) ? popVal : ""
                        if fieldValues[cleanLbl] == nil || !chosen.isEmpty {
                            fieldValues[cleanLbl] = (val: chosen, type: "dropdown", options: fieldValues[cleanLbl]?.options ?? [])
                        }
                    }
                }
            }
            
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(current, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                for c in children {
                    queue.append(c)
                }
            }
        }
        
        Self.reconcileOtherTypedText(fieldValues: &fieldValues, otherTypedTextByLabel: otherTypedTextByLabel)
        
        var results: [ExtractedInputItem] = []
        for (lbl, data) in fieldValues {
            results.append(ExtractedInputItem(label: lbl, value: data.val, questionType: data.type, options: data.options))
        }
        return results
    }
    
    static func isOtherPlaceholderToken(_ token: String) -> Bool {
        let lower = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return lower == "other" || lower == "other:" || lower == "__other_option__"
    }
    
    /// Reconciles typed "Other:" text sub-inputs post-BFS so node traversal order never clobbers
    /// co-selected checkboxes (e.g. `"AI, Other"`) or reverts to literal `"Other"`.
    static func reconcileOtherTypedText(
        fieldValues: inout [String: (val: String, type: String, options: [String])],
        otherTypedTextByLabel: [String: String]
    ) {
        for (lbl, typedOther) in otherTypedTextByLabel where !typedOther.isEmpty {
            guard var entry = fieldValues[lbl] else { continue }
            if entry.type == "checkboxes" {
                let parts = entry.val.components(separatedBy: ", ").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                var replaced = false
                let updatedParts = parts.map { part -> String in
                    if isOtherPlaceholderToken(part) {
                        replaced = true
                        return typedOther
                    }
                    return part
                }
                if replaced {
                    entry.val = updatedParts.joined(separator: ", ")
                } else if entry.val.isEmpty && entry.options.isEmpty {
                    entry.val = typedOther
                }
                fieldValues[lbl] = entry
            } else if (entry.val.isEmpty && entry.options.isEmpty) || isOtherPlaceholderToken(entry.val) {
                entry.val = typedOther
                fieldValues[lbl] = entry
            }
        }
    }
    
    /// Scans the browser content window to extract live input field values paired with their question labels.
    public static func scanBrowserWindowInputs(appElem: AXUIElement, fields: [FormInputField] = []) -> [(label: String, value: String)]? {
        return scanBrowserWindowInputItems(appElem: appElem, fields: fields)?.map { ($0.label, $0.value) }
    }
    
    /// JavaScript injected into the active browser tab to read the live answers of a Google Form
    /// (or generic web form). Returns `title:::value` pairs joined by `|||`; unanswered questions are
    /// reported with an empty value so that cleared answers can be detected.
    /// Contains zero single-line // comments so AppleScript flattening preserves the entire script.
    public static let domExtractionScript: String = #"""
    (function() {
        var bodyText = (document.body ? (document.body.innerText || document.body.textContent) : '').toLowerCase();
        var isSubmittedScreen = bodyText.indexOf('your response has been recorded') >= 0 ||
                                bodyText.indexOf('submit another response') >= 0;
        if (isSubmittedScreen) {
            return '__FORM_SUBMITTED__:::Your response has been recorded.:::submitted:::';
        }
        var isClosed = bodyText.indexOf('no longer accepting responses') >= 0 ||
                       bodyText.indexOf('deadline has passed') >= 0 ||
                       bodyText.indexOf('submissions are closed') >= 0 ||
                       bodyText.indexOf("you've already responded") >= 0 ||
                       bodyText.indexOf('you need permission') >= 0 ||
                       document.querySelector('.freebirdFormviewerViewResponseConfirmationMessage') !== null;
        if (isClosed) {
            var reason = 'This form is no longer accepting responses.';
            if (bodyText.indexOf('deadline has passed') >= 0) reason = 'The submission deadline for this form has passed.';
            else if (bodyText.indexOf('already responded') >= 0) reason = "You've already responded to this form.";
            else if (bodyText.indexOf('need permission') >= 0) reason = 'You need permission to access this form.';
            return '__FORM_CLOSED__:::' + reason + ':::closed:::';
        }
        var out = [];
        var seen = [];
        function clean(t) { return (t || '').replace(/\s+/g, ' ').trim(); }
        function text(e) { return e ? clean(e.innerText || e.textContent) : ''; }
        function attr(e, n) { var v = e.getAttribute(n); return v === null ? null : clean(v); }
        function isAlreadyInsideSeen(node) {
            for (var s = 0; s < seen.length; s++) {
                if (seen[s] === node || (seen[s].contains && seen[s].contains(node))) return true;
            }
            return false;
        }
        function closestLabelText(e) {
            if (!e) return '';
            if (e.closest) {
                var lbl = e.closest('label');
                if (lbl) return text(lbl);
            }
            if (e.id) {
                var forLbl = document.querySelector('label[for="' + e.id + '"]');
                if (forLbl) return text(forLbl);
            }
            return '';
        }
        function optionValue(e) {
            var v = attr(e, 'data-value');
            if (v === null || v === '') v = attr(e, 'data-answer-value');
            if (v === null || v === '') v = attr(e, 'aria-label');
            if ((v === null || v === '') && e.tagName && e.tagName.toUpperCase() === 'INPUT') {
                if (e.hasAttribute('value')) v = clean(e.value);
                else v = closestLabelText(e) || clean(e.value);
            }
            if (v === null || v === '') v = clean(e.value);
            if (v === null || v === '') v = text(e);
            if (v === '__other_option__') return 'Other';
            return v || '';
        }
        function isOtherControl(e) {
            return attr(e, 'data-value') === '__other_option__' || attr(e, 'data-answer-value') === '__other_option__';
        }
        function otherTypedValue(ctrl, itemRoot) {
            var rowWrap = ctrl.closest ? ctrl.closest('.nWQGrd, .eBFwI, .docssharedWizToggleLabeledContainer, label, li') : null;
            var scope = rowWrap || ctrl.parentElement || itemRoot;
            var inp = scope ? scope.querySelector('.Hvn9fb, input[type=text], input:not([type])') : null;
            if (!inp && itemRoot) inp = itemRoot.querySelector('.Hvn9fb, input[aria-label*="Other" i]');
            return inp ? clean(inp.value) : '';
        }
        function findUploadControl(it) {
            var fInp = it.querySelector('input[type=file]');
            if (fInp) return fInp;
            var btns = it.querySelectorAll('[role=button], button');
            for (var bi = 0; bi < btns.length; bi++) {
                var bTxt = clean(attr(btns[bi], 'aria-label') || text(btns[bi]));
                if (/^(add file|upload|choose file|browse)/i.test(bTxt)) return btns[bi];
            }
            return null;
        }
        function sanitizeTitle(rawT) {
            return rawT
                .replace(/\s*\*+\s*(?:Indicates\s+)?Required\s+question\s*$/i, '')
                .replace(/\s*(?:Indicates\s+)?Required\s+question\s*$/i, '')
                .replace(/\s*\*+\s*$/, '')
                .replace(/:::/g, ':')
                .replace(/\|\|\|/g, '|')
                .trim();
        }
        var placeholder = /^(choose|select|select an option|choose an option|-- ?select ?--)$/i;
        var items = document.querySelectorAll('div[role=listitem], .Qr7Oae, .geS5n, .question, .form-group');
        if (items.length > 0) {
            for (var i = 0; i < items.length; i++) {
                var item = items[i];
                if (isAlreadyInsideSeen(item)) continue;
                if (item.querySelector('div[role=listitem]')) continue;
                var uploadCtrl = findUploadControl(item);
                var hasAnyInput = !!item.querySelector('input:not([type=hidden]), textarea, select, [contenteditable=true], [role=radio], [role=checkbox], [role=listbox], [role=combobox], [role=slider]') || !!uploadCtrl;
                if (!hasAnyInput) continue;
                seen.push(item);
                var h = item.querySelector('[role=heading], .M7eMe, legend, h2, h3, h4, .question-title, .field-label');
                if (!h) {
                    var itemLabels = item.querySelectorAll('label');
                    for (var li = 0; li < itemLabels.length; li++) {
                        if (!itemLabels[li].querySelector('input[type=radio], input[type=checkbox]')) {
                            h = itemLabels[li];
                            break;
                        }
                    }
                }
                var rawHeading = text(h);
                var isReq = false;
                if (item.querySelector('[aria-label*="Required" i], [required], [aria-required="true"]') || /\*\s*$/.test(rawHeading)) {
                    isReq = true;
                }
                var title = sanitizeTitle(rawHeading);
                if (!title) continue;
                var reqSuffix = isReq ? ':::__REQ__' : '';
                
                var radioRowGroups = item.querySelectorAll('[role=radiogroup]');
                var allChkGroups = item.querySelectorAll('.EzyPc [role=group], [role=row] [role=group], [role=group]');
                var chkRowGroups = [];
                for (var cgi = 0; cgi < allChkGroups.length; cgi++) {
                    if (allChkGroups[cgi].querySelector('[role=checkbox], input[type=checkbox]')) {
                        chkRowGroups.push(allChkGroups[cgi]);
                    }
                }
                if (radioRowGroups.length >= 2 || chkRowGroups.length >= 2) {
                    var rowList = radioRowGroups.length >= 2 ? radioRowGroups : chkRowGroups;
                    for (var ri = 0; ri < rowList.length; ri++) {
                        var rg = rowList[ri];
                        var rTitle = clean(attr(rg, 'aria-label') || '');
                        if (rTitle && rTitle.toLowerCase().indexOf(title.toLowerCase()) === 0) {
                            rTitle = rTitle.slice(title.length).replace(/^[\s,:-]+/, '').trim();
                        }
                        if (!rTitle && rg.parentElement) {
                            var rowLabelEl = rg.parentElement.querySelector('.V4d7Ke, th, .M7eMe');
                            if (rowLabelEl) rTitle = clean(text(rowLabelEl));
                        }
                        if (!rTitle && rg.previousElementSibling && !rg.previousElementSibling.querySelector('[role=radio], [role=checkbox]')) {
                            rTitle = clean(text(rg.previousElementSibling));
                        }
                        rTitle = sanitizeTitle(rTitle);
                        if (!rTitle) rTitle = 'Row ' + (ri + 1);
                        var rowCtrls = rg.querySelectorAll('[role=radio], input[type=radio], [role=checkbox], input[type=checkbox]');
                        var rOpts = [];
                        var rVals = [];
                        for (var rci = 0; rci < rowCtrls.length; rci++) {
                            var rc = rowCtrls[rci];
                            var rcv = optionValue(rc);
                            if (rcv && rOpts.indexOf(rcv) < 0 && rcv !== rTitle && rcv !== title) rOpts.push(rcv);
                            var isOn = (attr(rc, 'aria-checked') === 'true') || !!rc.checked;
                            if (isOn && rcv && rVals.indexOf(rcv) < 0) rVals.push(rcv);
                        }
                        var rowOutTitle = (title + ' [' + rTitle + ']').replace(/:::/g, ':').replace(/\|\|\|/g, '|');
                        var rowValStr = rVals.join(', ').replace(/\|\|\|/g, '|').replace(/:::/g, ':');
                        var rowCleanOpts = rOpts.map(function(s) { return s.replace(/:::/g, ':').replace(/;;;/g, ';'); }).join(';;;');
                        out.push(rowOutTitle + ':::' + rowValStr + ':::grid:::' + rowCleanOpts + reqSuffix);
                    }
                    continue;
                }
                
                var qType = 'shortAnswer';
                var opts = [];
                var val = '';
                
                var ta = item.querySelector('textarea, [contenteditable=true]');
                var radEls = item.querySelectorAll('[role=radio], input[type=radio]');
                var chkEls = item.querySelectorAll('[role=checkbox], input[type=checkbox]');
                var selEl = item.querySelector('select, [role=listbox], [role=combobox]');
                var monthInp = item.querySelector('input[aria-label*="Month" i], input[aria-label*="month" i]');
                var dayInp = item.querySelector('input[aria-label*="Day" i], input[aria-label*="day" i]');
                var yearInp = item.querySelector('input[aria-label*="Year" i], input[aria-label*="year" i]');
                var hourInp = item.querySelector('input[aria-label*="Hour" i], input[aria-label*="hour" i]');
                var minInp = item.querySelector('input[aria-label*="Minute" i], input[aria-label*="minute" i]');
                
                if (radEls.length > 0 || item.querySelector('[role=radiogroup]')) {
                    for (var r = 0; r < radEls.length; r++) {
                        var rv = optionValue(radEls[r]);
                        if (rv && opts.indexOf(rv) < 0 && rv !== title) opts.push(rv);
                    }
                    var isScale = !!item.querySelector('.W2203e, .N9Qcwe, .O22jVe, .T5pZmf');
                    if (!isScale && opts.length >= 2 && opts.length <= 11) {
                        isScale = opts.every(function(o) { return /^\d{1,2}$/.test(o); });
                    }
                    qType = isScale ? 'linearScale' : 'multipleChoice';
                    var activeRad = item.querySelector('[role=radio][aria-checked=true], input[type=radio]:checked');
                    if (activeRad) {
                        if (isOtherControl(activeRad)) {
                            var typedOther = otherTypedValue(activeRad, item);
                            val = typedOther || optionValue(activeRad);
                        } else {
                            val = optionValue(activeRad);
                        }
                    }
                } else if (chkEls.length > 0 || item.querySelector('[role=group] [role=checkbox]')) {
                    qType = 'checkboxes';
                    for (var c = 0; c < chkEls.length; c++) {
                        var cv = optionValue(chkEls[c]);
                        if (cv && opts.indexOf(cv) < 0 && cv !== title) opts.push(cv);
                    }
                    var checkedChks = item.querySelectorAll('[role=checkbox][aria-checked=true], input[type=checkbox]:checked');
                    var cs = [];
                    for (var j = 0; j < checkedChks.length; j++) {
                        var chkNode = checkedChks[j];
                        var cVal = optionValue(chkNode);
                        if (isOtherControl(chkNode)) {
                            var typedOtherChk = otherTypedValue(chkNode, item);
                            if (typedOtherChk) cVal = typedOtherChk;
                        }
                        if (cVal && cs.indexOf(cVal) < 0) cs.push(cVal);
                    }
                    val = cs.join(', ');
                } else if (selEl && !(hourInp && minInp)) {
                    qType = 'dropdown';
                    var optTags = selEl.querySelectorAll('option, [role=option]');
                    for (var o = 0; o < optTags.length; o++) {
                        var ov = optionValue(optTags[o]);
                        if (ov && !placeholder.test(ov) && opts.indexOf(ov) < 0 && ov !== title) opts.push(ov);
                    }
                    if (selEl.tagName && selEl.tagName.toLowerCase() === 'select') {
                        if (selEl.selectedIndex >= 0) {
                            var so = selEl.options[selEl.selectedIndex];
                            var sv = so ? clean(so.value || so.text) : '';
                            if (sv && !placeholder.test(sv)) val = sv;
                        }
                    } else {
                        var selOpt = item.querySelector('[role=option][aria-selected=true], .MocG8c[aria-selected=true], .MocG8c.KKjvXb');
                        if (selOpt) {
                            var dv = optionValue(selOpt);
                            if (dv && !placeholder.test(dv)) val = dv;
                        }
                        if (!val) {
                            var hiddenSel = item.querySelector('input[type=hidden]');
                            if (hiddenSel && hiddenSel.value && !placeholder.test(clean(hiddenSel.value))) {
                                val = clean(hiddenSel.value);
                            }
                        }
                        if (!val) {
                            var dispSpan = selEl.querySelector('.KKjvXb .vRMGwf, .vRMGwf, .o3Dpx');
                            var spanTxt = text(dispSpan);
                            if (spanTxt && !placeholder.test(spanTxt)) val = spanTxt;
                        }
                    }
                } else if (item.querySelector('.W2203e, [role=slider], input[type=range]')) {
                    qType = 'linearScale';
                    var scaleInp = item.querySelector('input[type=range], input[type=number]');
                    if (scaleInp && scaleInp.value) val = clean(scaleInp.value);
                    else {
                        var slider = item.querySelector('[role=slider]');
                        if (slider) {
                            var svNow = attr(slider, 'aria-valuenow');
                            if (svNow) val = svNow;
                        }
                    }
                } else if (item.querySelector('input[type=date]') || (monthInp && dayInp)) {
                    qType = 'date';
                    var dtInp = item.querySelector('input[type=date]');
                    if (dtInp && dtInp.value) {
                        val = clean(dtInp.value);
                    } else if (monthInp && dayInp) {
                        var mo = clean(monthInp.value);
                        var dy = clean(dayInp.value);
                        var yr = yearInp ? clean(yearInp.value) : '';
                        if (mo && dy && yr) {
                            val = yr + '-' + (mo.length === 1 ? '0' + mo : mo) + '-' + (dy.length === 1 ? '0' + dy : dy);
                        } else if (mo && dy) {
                            val = mo + '/' + dy;
                        } else if (mo || dy || yr) {
                            var dParts = [];
                            if (mo) dParts.push(mo);
                            if (dy) dParts.push(dy);
                            if (yr) dParts.push(yr);
                            val = dParts.join('/');
                        }
                    }
                } else if (item.querySelector('input[type=time]') || (hourInp && minInp)) {
                    qType = 'time';
                    var tmInp = item.querySelector('input[type=time]');
                    if (tmInp && tmInp.value) {
                        val = clean(tmInp.value);
                    } else if (hourInp && minInp) {
                        var hr = clean(hourInp.value);
                        var mn = clean(minInp.value);
                        if (hr && mn) {
                            var baseT = (hr.length === 1 ? '0' + hr : hr) + ':' + (mn.length === 1 ? '0' + mn : mn);
                            var ampmTxt = '';
                            var ampmSel = item.querySelector('select');
                            if (ampmSel && ampmSel.selectedIndex >= 0 && ampmSel.options[ampmSel.selectedIndex]) {
                                ampmTxt = clean(ampmSel.options[ampmSel.selectedIndex].text || ampmSel.options[ampmSel.selectedIndex].value);
                            } else {
                                var ampmLb = item.querySelector('[role=listbox], [role=combobox]');
                                if (ampmLb) {
                                    var amSel = ampmLb.querySelector('[role=option][aria-selected="true"], .KKjvXb[aria-selected="true"], .MocG8c[aria-selected="true"]');
                                    if (amSel) {
                                        ampmTxt = clean(amSel.getAttribute('data-value') || amSel.innerText || amSel.textContent);
                                    } else {
                                        var amDisp = ampmLb.querySelector('.vRMGwf, .o3Dpx');
                                        if (amDisp) ampmTxt = clean(amDisp.innerText || amDisp.textContent);
                                    }
                                }
                            }
                            if (/^(AM|PM)$/i.test(ampmTxt)) {
                                val = baseT + ' ' + ampmTxt.toUpperCase();
                            } else {
                                val = baseT;
                            }
                        } else if (hr || mn) {
                            val = (hr ? (hr.length === 1 ? '0' + hr : hr) : '__') + ':' + (mn ? (mn.length === 1 ? '0' + mn : mn) : '__');
                        }
                    }
                } else if (ta) {
                    qType = 'paragraph';
                    if (ta.value) val = clean(ta.value);
                    else if (ta.isContentEditable || ta.getAttribute('contenteditable') === 'true') val = clean(ta.innerText || ta.textContent);
                } else {
                    var inp = item.querySelector('input[type=text], input[type=email], input[type=tel], input[type=url], input[type=number], input[type=search], input:not([type]):not([role])');
                    if (inp) {
                        qType = 'shortAnswer';
                        if (inp.value) val = clean(inp.value);
                    } else if (uploadCtrl) {
                        qType = 'fileUpload';
                        var fInput = item.querySelector('input[type=file]');
                        if (fInput && fInput.files && fInput.files.length > 0) {
                            val = clean(fInput.files[0].name);
                        } else {
                            var fileChip = item.querySelector('.M3pype, .y61f2e, [data-file-name]');
                            if (fileChip) val = clean(attr(fileChip, 'data-file-name') || text(fileChip));
                        }
                    }
                }
                
                val = val.replace(/\|\|\|/g, '|').replace(/:::/g, ':');
                var cleanOpts = opts.map(function(s) { return s.replace(/:::/g, ':').replace(/;;;/g, ';'); }).join(';;;');
                out.push(title + ':::' + val + ':::' + qType + ':::' + cleanOpts + reqSuffix);
            }
        } else {
            var inps = document.querySelectorAll('input:not([type=hidden]):not([type=submit]):not([type=button]), textarea, select');
            var bareOrder = [];
            var bareMap = {};
            for (var k = 0; k < inps.length; k++) {
                var el = inps[k];
                var tag = (el.tagName || '').toLowerCase();
                var t = (el.getAttribute('type') || '').toLowerCase();
                var l = clean(el.getAttribute('aria-label') || '');
                if ((t === 'radio' || t === 'checkbox') && !l) {
                    var fs = el.closest ? el.closest('fieldset') : null;
                    var lg = fs ? fs.querySelector('legend') : null;
                    if (lg) l = text(lg);
                    if (!l && el.name) {
                        var sameNameCount = 0;
                        for (var si = 0; si < inps.length; si++) {
                            if (inps[si].name === el.name && (inps[si].getAttribute('type') || '').toLowerCase() === t) sameNameCount++;
                        }
                        if (sameNameCount > 1) l = clean(el.name);
                    }
                }
                if (!l) l = clean(closestLabelText(el) || el.name || el.placeholder || '');
                if (!l) continue;
                var inForm = !!(el.closest && el.closest('form'));
                var q = (tag === 'textarea') ? 'paragraph' : (t === 'radio' ? 'multipleChoice' : (t === 'checkbox' ? 'checkboxes' : (tag === 'select' ? 'dropdown' : 'shortAnswer')));
                var v = '';
                if (t === 'radio' || t === 'checkbox') {
                    if (el.checked) {
                        var optAria = attr(el, 'aria-label');
                        var optValAttr = (el.hasAttribute('value') && !/^on$/i.test(clean(el.value)) && el.value !== '__other_option__') ? clean(el.value) : '';
                        var optLabel = closestLabelText(el);
                        var optText = attr(el, 'data-value') || attr(el, 'data-answer-value') || optValAttr || ((optAria && optAria !== l) ? optAria : '') || ((optLabel && optLabel !== l) ? optLabel : '');
                        if (!optText) optText = optLabel || optAria || 'Yes';
                        v = clean(optText);
                    }
                } else if (tag === 'select') {
                    if (el.selectedIndex >= 0 && el.options && el.options[el.selectedIndex]) {
                        var sOpt = el.options[el.selectedIndex];
                        var sTxt = clean(sOpt.text || sOpt.value || '');
                        if (sTxt && !placeholder.test(sTxt)) v = sTxt;
                    }
                } else {
                    v = clean(el.value || '');
                }
                v = v.replace(/\|\|\|/g, '|').replace(/:::/g, ':');
                var bKey = l.replace(/:::/g, ':') + ':::' + q;
                if (!bareMap[bKey]) {
                    bareMap[bKey] = { l: l.replace(/:::/g, ':'), q: q, v: v, inForm: inForm };
                    bareOrder.push(bKey);
                } else {
                    if (inForm) bareMap[bKey].inForm = true;
                    if (v) {
                        if (q === 'checkboxes' && bareMap[bKey].v) {
                            bareMap[bKey].v = bareMap[bKey].v + ', ' + v;
                        } else {
                            bareMap[bKey].v = v;
                        }
                    }
                }
            }
            for (var bk = 0; bk < bareOrder.length; bk++) {
                var rec = bareMap[bareOrder[bk]];
                if (rec && (rec.v || rec.inForm)) {
                    out.push(rec.l + ':::' + rec.v + ':::' + rec.q + ':::');
                }
            }
        }
        return out.join('|||');
    })()
    """#
    
    /// Escapes arbitrary text into the body of an AppleScript double-quoted string literal.
    public static func appleScriptStringLiteralBody(_ raw: String) -> String {
        return raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
    
    private static func appleScriptTabMatchFragment(from targetURL: String?) -> String? {
        guard let raw = targetURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if let formID = DefaultApplicationFormDetector.extractFormIdentifier(from: raw), !formID.isEmpty {
            return formID
        }
        var stripped = raw
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
        if let hashIdx = stripped.firstIndex(of: "#") { stripped = String(stripped[..<hashIdx]) }
        if let qIdx = stripped.firstIndex(of: "?") { stripped = String(stripped[..<qIdx]) }
        return stripped.isEmpty ? nil : stripped
    }
    
    private static func isChromiumBundleID(_ bundleID: String) -> Bool {
        let b = bundleID.lowercased()
        return b.contains("chrome") || b.contains("brave") || b.contains("edge") || b.contains("arc") || b.contains("vivaldi") || b.contains("opera") || b.contains("chromium") || b.contains("comet") || b.contains("sigmaos") || b.contains("wavebox")
    }
    
    /// Builds the AppleScript that runs `domExtractionScript` in the matching form tab (or active tab) of a scriptable browser.
    public static func buildDOMExtractionAppleScript(bundleID: String, targetURL: String? = nil) -> String? {
        let b = bundleID.lowercased()
        let isChrome = isChromiumBundleID(b)
        let isSafari = b.contains("safari") && !b.contains("technology")
        guard isChrome || isSafari else { return nil }
        
        let escapedJS = appleScriptStringLiteralBody(domExtractionScript)
        if let fragment = appleScriptTabMatchFragment(from: targetURL) {
            let escapedFrag = appleScriptStringLiteralBody(fragment)
            if isChrome {
                return """
                tell application id "\(bundleID)"
                    if (count of windows) > 0 then
                        set lastJSError to ""
                        try
                            tell front window to tell active tab
                                set activeURL to ""
                                try
                                    set activeURL to URL
                                end try
                                if activeURL contains "\(escapedFrag)" then
                                    try
                                        return execute javascript "\(escapedJS)"
                                    on error errMsg
                                        set lastJSError to "__JS_ERROR__:" & errMsg
                                    end try
                                end if
                            end tell
                        end try
                        repeat with w in windows
                            repeat with t in tabs of w
                                set tabURL to ""
                                try
                                    set tabURL to URL of t
                                end try
                                if tabURL contains "\(escapedFrag)" then
                                    try
                                        tell t
                                            return execute javascript "\(escapedJS)"
                                        end tell
                                    on error errMsg
                                        set lastJSError to "__JS_ERROR__:" & errMsg
                                    end try
                                end if
                            end repeat
                        end repeat
                        if lastJSError is not "" then return lastJSError
                        try
                            tell front window to tell active tab
                                return execute javascript "\(escapedJS)"
                            end tell
                        on error errMsg
                            return "__JS_ERROR__:" & errMsg
                        end try
                    end if
                end tell
                """
            }
            return """
            tell application id "com.apple.Safari"
                if (count of windows) > 0 then
                    set lastJSError to ""
                    try
                        set activeTab to current tab of front window
                        set activeURL to ""
                        try
                            set activeURL to URL of activeTab
                        end try
                        if activeURL contains "\(escapedFrag)" then
                            try
                                return do JavaScript "\(escapedJS)" in activeTab
                            on error errMsg
                                set lastJSError to "__JS_ERROR__:" & errMsg
                            end try
                        end if
                    end try
                    repeat with w in windows
                        repeat with t in tabs of w
                            set tabURL to ""
                            try
                                set tabURL to URL of t
                            end try
                            if tabURL contains "\(escapedFrag)" then
                                try
                                    return do JavaScript "\(escapedJS)" in t
                                on error errMsg
                                    set lastJSError to "__JS_ERROR__:" & errMsg
                                end try
                            end if
                        end repeat
                    end repeat
                    if lastJSError is not "" then return lastJSError
                    try
                        tell front window to tell current tab
                            return do JavaScript "\(escapedJS)"
                        end tell
                    on error errMsg
                        return "__JS_ERROR__:" & errMsg
                    end try
                end if
            end tell
            """
        }
        
        if isChrome {
            return """
            tell application id "\(bundleID)"
                if (count of windows) > 0 then
                    try
                        tell front window to tell active tab
                            return execute javascript "\(escapedJS)"
                        end tell
                    on error errMsg
                        return "__JS_ERROR__:" & errMsg
                    end try
                end if
            end tell
            """
        }
        return """
        tell application id "com.apple.Safari"
            if (count of windows) > 0 then
                try
                    tell front window to tell current tab
                        return do JavaScript "\(escapedJS)"
                    end tell
                on error errMsg
                    return "__JS_ERROR__:" & errMsg
                end try
            end if
        end tell
        """
    }
    
    /// Builds the AppleScript that executes DOM injection of question answers in the frontmost tab of a scriptable browser.
    public static func buildDOMInjectionAppleScript(bundleID: String, answers: [String: String]) -> String? {
        return buildDOMInjectionAppleScript(bundleID: bundleID, answers: answers, fields: [], targetURL: nil)
    }
    
    /// Builds the AppleScript that executes schema-aware DOM injection into the matching Google Form tab of a scriptable browser.
    public static func buildDOMInjectionAppleScript(
        bundleID: String,
        answers: [String: String],
        fields: [FormInputField] = [],
        targetURL: String? = nil
    ) -> String? {
        guard !answers.isEmpty else { return nil }
        let b = bundleID.lowercased()
        let isChrome = isChromiumBundleID(b)
        let isSafari = b.contains("safari") && !b.contains("technology")
        guard isChrome || isSafari else { return nil }
        
        var payloadEntries: [[String: String]] = []
        for (rawKey, rawVal) in answers {
            let trimmedVal = rawVal.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedVal.isEmpty else { continue }
            var matchedField: FormInputField? = nil
            if let exact = fields.first(where: { $0.label.caseInsensitiveCompare(rawKey) == .orderedSame }) {
                matchedField = exact
            } else if let idx = ApplicationFormModel.strictMatchingFieldIndex(for: rawKey, in: fields) {
                matchedField = fields[idx]
            }
            payloadEntries.append([
                "title": rawKey,
                "value": rawVal,
                "entryKey": matchedField?.entryKey ?? "",
                "questionType": matchedField?.questionType ?? ""
            ])
        }
        guard !payloadEntries.isEmpty else { return nil }
        
        let jsonData = (try? JSONSerialization.data(withJSONObject: payloadEntries, options: [])) ?? Data()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "[]"
        
        let jsSnippet = #"""
        (function(entries) {
            var count = 0;
            var pendingDropdowns = [];
            function clean(t) {
                return (t || '')
                    .replace(/\s+/g, ' ')
                    .replace(/\*+$/, '')
                    .replace(/\(required\)$/i, '')
                    .replace(/^(Q\d+[:.]?|\d+[.)])\s*/i, '')
                    .trim()
                    .toLowerCase();
            }
            function tokensOf(s) {
                return clean(s).replace(/[^a-z0-9\s]/g, ' ').split(/\s+/).filter(function(w) { return w.length >= 2; });
            }
            var qualifiers = {
                'parent':1, 'parents':1, 'guardian':1, 'guardians':1, 'emergency':1,
                'reference':1, 'references':1, 'referee':1, 'referees':1,
                'supervisor':1, 'supervisors':1, 'manager':1, 'managers':1,
                'advisor':1, 'advisors':1, 'mentor':1, 'mentors':1,
                'spouse':1, 'spouses':1, 'partner':1, 'partners':1,
                'mother':1, 'father':1, 'mom':1, 'dad':1,
                'first':1, 'last':1, 'middle':1, 'given':1, 'family':1, 'surname':1,
                'nick':1, 'nickname':1, 'nicknames':1, 'user':1, 'username':1, 'usernames':1,
                'handle':1, 'handles':1,
                'company':1, 'companies':1, 'organization':1, 'organizations':1, 'org':1, 'orgs':1,
                'school':1, 'schools':1, 'university':1, 'universities':1,
                'college':1, 'colleges':1, 'institution':1, 'institutions':1,
                'team':1, 'teams':1, 'project':1, 'projects':1, 'event':1, 'events':1,
                'product':1, 'products':1, 'course':1, 'courses':1,
                'child':1, 'children':1, 'sibling':1, 'siblings':1,
                'doctor':1, 'doctors':1, 'physician':1, 'physicians':1,
                'recommender':1, 'recommenders':1
            };
            function hasQualifierConflict(tA, tB) {
                var setA = {}, setB = {};
                for (var i = 0; i < tA.length; i++) { if (qualifiers[tA[i]]) setA[tA[i]] = 1; }
                for (var j = 0; j < tB.length; j++) { if (qualifiers[tB[j]]) setB[tB[j]] = 1; }
                for (var k in setA) { if (!setB[k]) return true; }
                for (var m in setB) { if (!setA[m]) return true; }
                return false;
            }
            function matchTitle(a, b) {
                var ca = clean(a), cb = clean(b);
                if (!ca || !cb) return false;
                if (ca === cb) return true;
                var sa = ca.replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();
                var sb = cb.replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();
                if (sa && sb && sa === sb) return true;
                var tA = tokensOf(a), tB = tokensOf(b);
                if (hasQualifierConflict(tA, tB)) return false;
                if (sa && sb && (sa.indexOf(sb) >= 0 || sb.indexOf(sa) >= 0)) {
                    var minLen = Math.min(sa.length, sb.length);
                    var maxLen = Math.max(sa.length, sb.length);
                    if (minLen >= 4 && (minLen / maxLen) >= 0.45) return true;
                }
                if (tA.length > 0 && tB.length > 0) {
                    var inter = 0;
                    var bMap = {};
                    for (var i = 0; i < tB.length; i++) bMap[tB[i]] = 1;
                    for (var j = 0; j < tA.length; j++) { if (bMap[tA[j]]) inter++; }
                    var minT = Math.min(tA.length, tB.length);
                    if (minT > 0 && (inter / minT) >= 0.7) return true;
                }
                if ((ca.indexOf('email') >= 0 && cb.indexOf('email') >= 0) ||
                    (ca.indexOf('phone') >= 0 && cb.indexOf('phone') >= 0) ||
                    ((ca === 'full name' || ca === 'your name' || ca === 'name') && (cb === 'full name' || cb === 'your name' || cb === 'name'))) {
                    return true;
                }
                return false;
            }
            function optionMatches(candidate, target, pass) {
                var c = clean(candidate), t = clean(target);
                if (!c || !t) return false;
                if (/^(choose|select|select an option|choose an option|-- ?select ?--)$/i.test(c)) return false;
                if (pass === 1) {
                    if (c === t) return true;
                    var sc = c.replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();
                    var st = t.replace(/[^a-z0-9\s]/g, ' ').replace(/\s+/g, ' ').trim();
                    return sc.length > 0 && sc === st;
                }
                var minL = Math.min(c.length, t.length);
                var maxL = Math.max(c.length, t.length);
                if (minL >= 3 && (minL / maxL) >= 0.55) {
                    if (c.indexOf(t) >= 0 || t.indexOf(c) >= 0) {
                        var esc = t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                        var re = new RegExp('(^|\\b)' + esc + '(\\b|$)', 'i');
                        if (re.test(c) || c.indexOf(t) === 0 || t.indexOf(c) === 0) return true;
                    }
                }
                return false;
            }
            function setNativeValue(el, val) {
                if (!el) return false;
                try { el.dispatchEvent(new FocusEvent('focusin', { bubbles: true })); } catch (e) {}
                try { el.dispatchEvent(new FocusEvent('focus', { bubbles: false })); } catch (e) {}
                try { el.focus(); } catch (e) {}
                if (el.isContentEditable || el.getAttribute('contenteditable') === 'true') {
                    el.textContent = val;
                    try {
                        el.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: val }));
                    } catch (e) {
                        el.dispatchEvent(new Event('input', { bubbles: true }));
                    }
                    el.dispatchEvent(new Event('change', { bubbles: true }));
                    try { el.dispatchEvent(new FocusEvent('focusout', { bubbles: true })); } catch (e) {}
                    try { el.blur(); } catch (e) {}
                    return true;
                }
                var proto = Object.getPrototypeOf(el);
                var desc = proto ? Object.getOwnPropertyDescriptor(proto, 'value') : null;
                if (!desc) {
                    var tag = (el.tagName || '').toLowerCase();
                    if (tag === 'textarea') desc = Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value');
                    else if (tag === 'input') desc = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value');
                }
                if (desc && typeof desc.set === 'function') {
                    desc.set.call(el, val);
                } else {
                    el.value = val;
                }
                el.setAttribute('data-initial-value', val);
                el.setAttribute('badinput', 'false');
                var wrap = el.closest ? el.closest('.rFrNMe, .Xb9hP') : null;
                if (wrap && wrap.classList) {
                    if (val) wrap.classList.add('CDELXb');
                    else wrap.classList.remove('CDELXb');
                }
                try {
                    el.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: val }));
                } catch (e) {
                    el.dispatchEvent(new Event('input', { bubbles: true }));
                }
                el.dispatchEvent(new Event('change', { bubbles: true }));
                el.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, key: ' ' }));
                el.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true, key: ' ' }));
                try { el.dispatchEvent(new FocusEvent('focusout', { bubbles: true })); } catch (e) {}
                try { el.blur(); } catch (e) {}
                return el.value === val || (el.type === 'date' || el.type === 'time');
            }
            function optionLabel(el) {
                return el.getAttribute('data-value') || el.getAttribute('data-answer-value') || el.getAttribute('aria-label') || el.value || (el.innerText || el.textContent || '').trim();
            }
            function triggerMouseClick(el) {
                if (!el) return;
                try { if (el.scrollIntoView) el.scrollIntoView({ block: 'nearest' }); } catch (e) {}
                try { el.focus(); } catch (e) {}
                var opts = { bubbles: true, cancelable: true, view: window };
                try { el.dispatchEvent(new MouseEvent('mousedown', opts)); } catch (e) {}
                try { el.dispatchEvent(new MouseEvent('mouseup', opts)); } catch (e) {}
                if (typeof el.click === 'function') el.click();
                else el.dispatchEvent(new MouseEvent('click', opts));
            }
            function normalizeDateStr(v) {
                var s = (v || '').trim();
                if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s;
                var m = /^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$/.exec(s);
                if (m) {
                    var n1 = parseInt(m[1], 10);
                    var n2 = parseInt(m[2], 10);
                    var moNum = n1;
                    var dyNum = n2;
                    if (n1 > 12 && n2 <= 12) {
                        dyNum = n1;
                        moNum = n2;
                    }
                    if (moNum >= 1 && moNum <= 12 && dyNum >= 1 && dyNum <= 31) {
                        var mo = moNum < 10 ? '0' + moNum : '' + moNum;
                        var dy = dyNum < 10 ? '0' + dyNum : '' + dyNum;
                        return m[3] + '-' + mo + '-' + dy;
                    }
                }
                if (/[a-zA-Z]/.test(s)) {
                    var parsed = new Date(s);
                    if (!isNaN(parsed.getTime())) {
                        var py = parsed.getFullYear();
                        var pm = parsed.getMonth() + 1;
                        var pd = parsed.getDate();
                        return py + '-' + (pm < 10 ? '0' + pm : '' + pm) + '-' + (pd < 10 ? '0' + pd : '' + pd);
                    }
                }
                return s;
            }
            function parseTimeParts(v) {
                var s = (v || '').trim();
                var m24 = /^(\d{1,2}):(\d{2})$/.exec(s);
                if (m24) {
                    var h24 = parseInt(m24[1], 10);
                    var ampm = h24 >= 12 ? 'PM' : 'AM';
                    var h12 = h24 % 12;
                    if (h12 === 0) h12 = 12;
                    return {
                        h24: (h24 < 10 ? '0' + h24 : '' + h24),
                        h12: (h12 < 10 ? '0' + h12 : '' + h12),
                        min: m24[2],
                        ampm: ampm
                    };
                }
                var m12 = /^(\d{1,2}):(\d{2})\s*(am|pm)$/i.exec(s);
                if (m12) {
                    var rawH = parseInt(m12[1], 10);
                    var isPM = m12[3].toLowerCase() === 'pm';
                    var calc24 = rawH;
                    if (isPM && calc24 < 12) calc24 += 12;
                    if (!isPM && calc24 === 12) calc24 = 0;
                    var calc12 = rawH % 12;
                    if (calc12 === 0) calc12 = 12;
                    return {
                        h24: (calc24 < 10 ? '0' + calc24 : '' + calc24),
                        h12: (calc12 < 10 ? '0' + calc12 : '' + calc12),
                        min: m12[2],
                        ampm: isPM ? 'PM' : 'AM'
                    };
                }
                return null;
            }
            function findBestOptInPool(pool, target) {
                for (var lpass = 1; lpass <= 2; lpass++) {
                    for (var o = 0; o < pool.length; o++) {
                        var opt = pool[o];
                        if (optionMatches(optionLabel(opt), target, lpass)) return opt;
                    }
                }
                return null;
            }
            function applyDropdownSelection(item, lb, optEl, val) {
                var inlineOpts = item.querySelectorAll('[role=option]');
                for (var i = 0; i < inlineOpts.length; i++) {
                    inlineOpts[i].setAttribute('aria-selected', 'false');
                }
                var labelText = optionLabel(optEl) || val;
                optEl.setAttribute('aria-selected', 'true');
                triggerMouseClick(optEl);
                var hidden = item.querySelector('input[type=hidden]');
                if (hidden) setNativeValue(hidden, labelText);
                var disp = lb ? lb.querySelector('.vRMGwf, .o3Dpx') : null;
                if (disp && disp.textContent !== undefined) disp.textContent = labelText;
            }
            function selectListboxValue(item, lb, targetVal, allowDefer) {
                triggerMouseClick(lb);
                var portals = document.querySelectorAll('.OA0qNb, .ncFHed');
                var chosenOpt = null;
                for (var pr = 0; pr < portals.length && !chosenOpt; pr++) {
                    chosenOpt = findBestOptInPool(portals[pr].querySelectorAll('[role=option]'), targetVal);
                }
                if (!chosenOpt) chosenOpt = findBestOptInPool(item.querySelectorAll('[role=option]'), targetVal);
                if (chosenOpt) {
                    applyDropdownSelection(item, lb, chosenOpt, targetVal);
                    return 'ok';
                }
                try { lb.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, key: 'Escape', keyCode: 27 })); } catch (e) {}
                if (allowDefer) {
                    pendingDropdowns.push({ item: item, lb: lb, targetVal: targetVal, title: '' });
                    return 'pending';
                }
                return false;
            }
            function injectIntoItem(item, targetVal) {
                var rads = item.querySelectorAll('[role=radio], input[type=radio]');
                if (rads.length > 0) {
                    for (var pass = 1; pass <= 2; pass++) {
                        for (var r = 0; r < rads.length; r++) {
                            var rad = rads[r];
                            var rv = optionLabel(rad);
                            if (optionMatches(rv, targetVal, pass)) {
                                if (typeof rad.click === 'function') rad.click();
                                if (rad.tagName === 'INPUT') {
                                    if (!rad.checked) {
                                        rad.checked = true;
                                        rad.dispatchEvent(new Event('change', { bubbles: true }));
                                    }
                                } else if (rad.getAttribute('aria-checked') !== 'true') {
                                    for (var sr = 0; sr < rads.length; sr++) {
                                        if (rads[sr].getAttribute) rads[sr].setAttribute('aria-checked', 'false');
                                    }
                                    rad.setAttribute('aria-checked', 'true');
                                    rad.dispatchEvent(new Event('change', { bubbles: true }));
                                }
                                return 'ok';
                            }
                        }
                    }
                    return false;
                }
                var chks = item.querySelectorAll('[role=checkbox], input[type=checkbox]');
                if (chks.length > 0) {
                    var parts = targetVal.split(',').map(function(s) { return s.trim(); }).filter(function(s) { return s.length > 0; });
                    if (parts.length === 0) parts = [targetVal];
                    var anyChecked = false;
                    for (var p = 0; p < parts.length; p++) {
                        var partMatched = false;
                        for (var cpass = 1; cpass <= 2 && !partMatched; cpass++) {
                            for (var c = 0; c < chks.length; c++) {
                                var chk = chks[c];
                                var cv = optionLabel(chk);
                                if (optionMatches(cv, parts[p], cpass)) {
                                    var wasOn = (chk.getAttribute('aria-checked') === 'true') || !!chk.checked;
                                    if (!wasOn) {
                                        if (typeof chk.click === 'function') chk.click();
                                        if (chk.tagName === 'INPUT') {
                                            if (!chk.checked) {
                                                chk.checked = true;
                                                chk.dispatchEvent(new Event('change', { bubbles: true }));
                                            }
                                        } else if (chk.getAttribute('aria-checked') !== 'true') {
                                            chk.setAttribute('aria-checked', 'true');
                                            chk.dispatchEvent(new Event('change', { bubbles: true }));
                                        }
                                    }
                                    partMatched = true;
                                    anyChecked = true;
                                    break;
                                }
                            }
                        }
                    }
                    return anyChecked ? 'ok' : false;
                }
                var sel = item.querySelector('select');
                if (sel) {
                    for (var spass = 1; spass <= 2; spass++) {
                        for (var s = 0; s < sel.options.length; s++) {
                            if (optionMatches(sel.options[s].text, targetVal, spass) || optionMatches(sel.options[s].value, targetVal, spass)) {
                                sel.selectedIndex = s;
                                sel.dispatchEvent(new Event('change', { bubbles: true }));
                                return 'ok';
                            }
                        }
                    }
                }
                var hourInp = item.querySelector('input[aria-label*="Hour" i]');
                var minInp = item.querySelector('input[aria-label*="Minute" i]');
                if (hourInp && minInp) {
                    var tp = parseTimeParts(targetVal);
                    if (tp) {
                        var ampmLb = item.querySelector('[role=listbox], [role=combobox]');
                        var ampmSel = item.querySelector('select');
                        var okH = false, okM = false;
                        if (ampmLb || ampmSel) {
                            okH = setNativeValue(hourInp, tp.h12);
                            okM = setNativeValue(minInp, tp.min);
                            if (ampmSel) {
                                for (var ai = 0; ai < ampmSel.options.length; ai++) {
                                    if (optionMatches(ampmSel.options[ai].text, tp.ampm, 1) || optionMatches(ampmSel.options[ai].value, tp.ampm, 1)) {
                                        ampmSel.selectedIndex = ai;
                                        ampmSel.dispatchEvent(new Event('change', { bubbles: true }));
                                        break;
                                    }
                                }
                            } else if (ampmLb) {
                                var rAm = selectListboxValue(item, ampmLb, tp.ampm, true);
                                if (rAm === 'pending') {
                                    if (okH && okM) {
                                        if (pendingDropdowns.length > 0) {
                                            pendingDropdowns[pendingDropdowns.length - 1].alreadyCounted = true;
                                        }
                                        return 'ok';
                                    }
                                    return 'pending';
                                }
                            }
                        } else {
                            okH = setNativeValue(hourInp, tp.h24);
                            okM = setNativeValue(minInp, tp.min);
                        }
                        return (okH && okM) ? 'ok' : false;
                    }
                }
                var lb = item.querySelector('[role=listbox], [role=combobox]');
                if (lb) {
                    return selectListboxValue(item, lb, targetVal, true);
                }
                var dtInp = item.querySelector('input[type=date]');
                if (dtInp) {
                    return setNativeValue(dtInp, normalizeDateStr(targetVal)) ? 'ok' : false;
                }
                var monthInp = item.querySelector('input[aria-label*="Month" i]');
                var dayInp = item.querySelector('input[aria-label*="Day" i]');
                var yearInp = item.querySelector('input[aria-label*="Year" i]');
                if (monthInp && dayInp) {
                    var normD = normalizeDateStr(targetVal);
                    var dParts = /^(\d{4})-(\d{2})-(\d{2})$/.exec(normD);
                    if (dParts) {
                        var okM2 = setNativeValue(monthInp, dParts[2]);
                        var okD2 = setNativeValue(dayInp, dParts[3]);
                        var okY2 = yearInp ? setNativeValue(yearInp, dParts[1]) : true;
                        return (okM2 && okD2 && okY2) ? 'ok' : false;
                    }
                }
                var tmInp = item.querySelector('input[type=time]');
                if (tmInp) {
                    var tp2 = parseTimeParts(targetVal);
                    var normT2 = tp2 ? (tp2.h24 + ':' + tp2.min) : targetVal;
                    return setNativeValue(tmInp, normT2) ? 'ok' : false;
                }
                var scaleInp = item.querySelector('input[type=range]');
                if (scaleInp) {
                    return setNativeValue(scaleInp, targetVal) ? 'ok' : false;
                }
                var textControl = item.querySelector('input:not([type=hidden]):not([type=radio]):not([type=checkbox]):not([type=file]), textarea, [contenteditable=true]');
                if (textControl) {
                    return setNativeValue(textControl, targetVal) ? 'ok' : false;
                }
                return false;
            }
            var rawItems = document.querySelectorAll('div[role=listitem], .Qr7Oae, .geS5n, .question, .form-group, fieldset');
            var items = [];
            for (var x = 0; x < rawItems.length; x++) {
                if (!rawItems[x].querySelector('div[role=listitem]')) items.push(rawItems[x]);
            }
            var filledTitles = [];
            function recordFilled(t) {
                if (t && filledTitles.indexOf(t) < 0) filledTitles.push(t);
            }
            var dpEls = document.querySelectorAll('[data-params]');
            for (var e = 0; e < entries.length; e++) {
                var spec = entries[e];
                var targetTitle = spec.title || '';
                var targetVal = spec.value || '';
                var entryKey = spec.entryKey || '';
                if (!targetVal) continue;
                var pendingBefore = pendingDropdowns.length;
                var matched = false;
                if (entryKey) {
                    var safeName = entryKey.replace(/([\\\]"])/g, '\\$1');
                    var keyInp = document.querySelector('[name="' + safeName + '"]');
                    var keyNum = entryKey.replace(/^entry\./, '');
                    var keyItem = keyInp && keyInp.closest ? keyInp.closest('div[role=listitem], .Qr7Oae, .geS5n, .question, .form-group, fieldset') : null;
                    if (!keyItem && /^\d+$/.test(keyNum)) {
                        var idRe = new RegExp('(?:^|[^0-9])' + keyNum + '(?:[^0-9]|$)');
                        for (var di = 0; di < dpEls.length; di++) {
                            var dpAttr = dpEls[di].getAttribute('data-params') || '';
                            if (idRe.test(dpAttr)) {
                                keyItem = dpEls[di].closest ? dpEls[di].closest('div[role=listitem], .Qr7Oae, .geS5n') : dpEls[di];
                                if (keyItem) break;
                            }
                        }
                    }
                    if (keyItem) {
                        var kRes = injectIntoItem(keyItem, targetVal);
                        if (kRes === 'ok') { count++; recordFilled(targetTitle); }
                        if (kRes === 'pending' && pendingDropdowns.length > pendingBefore) {
                            pendingDropdowns[pendingDropdowns.length - 1].title = targetTitle;
                        }
                        matched = true;
                    }
                }
                if (!matched) {
                    for (var i = 0; i < items.length; i++) {
                        var item = items[i];
                        var h = item.querySelector('[role=heading], .M7eMe, legend, label, h2, h3, h4');
                        var hText = h ? (h.innerText || h.textContent) : '';
                        if (matchTitle(hText, targetTitle)) {
                            var fRes = injectIntoItem(item, targetVal);
                            if (fRes === 'ok') { count++; recordFilled(targetTitle); }
                            if (fRes === 'pending' && pendingDropdowns.length > pendingBefore) {
                                pendingDropdowns[pendingDropdowns.length - 1].title = targetTitle;
                            }
                            if (fRes === 'ok' || fRes === 'pending') {
                                matched = true;
                                break;
                            }
                        }
                    }
                }
                if (!matched) {
                    var directInputs = document.querySelectorAll('input:not([type=hidden]):not([type=submit]):not([type=button]):not([type=file]), textarea, [contenteditable=true]');
                    for (var d = 0; d < directInputs.length; d++) {
                        var dInp = directInputs[d];
                        var dLbl = dInp.getAttribute('aria-label') || dInp.getAttribute('placeholder') || dInp.name || '';
                        if (matchTitle(dLbl, targetTitle)) {
                            if (setNativeValue(dInp, targetVal)) {
                                matched = true;
                                count++;
                                recordFilled(targetTitle);
                                break;
                            }
                        }
                    }
                }
            }
            if (pendingDropdowns.length === 0) {
                window.__morphAsyncState = { done: true, total: count, filled: filledTitles };
                return String(count);
            }
            window.__morphAsyncState = { done: false, total: count, filled: filledTitles };
            var asyncAdded = 0;
            function processPending(idx) {
                if (idx >= pendingDropdowns.length) {
                    window.__morphAsyncState = { done: true, total: count + asyncAdded, filled: filledTitles };
                    return;
                }
                var task = pendingDropdowns[idx];
                triggerMouseClick(task.lb);
                setTimeout(function() {
                    var pool = document.querySelectorAll('.OA0qNb [role=option], .ncFHed [role=option], [role=listbox] [role=option], body > div [role=option]');
                    var chosen = findBestOptInPool(pool, task.targetVal);
                    if (!chosen) chosen = findBestOptInPool(task.item.querySelectorAll('[role=option]'), task.targetVal);
                    if (chosen) {
                        applyDropdownSelection(task.item, task.lb, chosen, task.targetVal);
                        if (!task.alreadyCounted) {
                            asyncAdded++;
                        }
                        recordFilled(task.title);
                        window.__morphAsyncState = { done: false, total: count + asyncAdded, filled: filledTitles };
                    } else {
                        try { task.lb.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true, key: 'Escape', keyCode: 27 })); } catch (e) {}
                    }
                    setTimeout(function() { processPending(idx + 1); }, 35);
                }, 95);
            }
            processPending(0);
            return '__PENDING__:' + String(count);
        })(\#(jsonString))
        """#
        
        let escapedJS = appleScriptStringLiteralBody(jsSnippet)
        let pollJSChrome = appleScriptStringLiteralBody("(function(){ return (window.__morphAsyncState && window.__morphAsyncState.done) ? String(window.__morphAsyncState.total) : '__WAIT__'; })()")
        let finalJSChrome = appleScriptStringLiteralBody("(function(){ return window.__morphAsyncState ? String(window.__morphAsyncState.total) : '0'; })()")
        if let fragment = appleScriptTabMatchFragment(from: targetURL) {
            let escapedFrag = appleScriptStringLiteralBody(fragment)
            if isChrome {
                return """
                tell application id "\(bundleID)"
                    if (count of windows) > 0 then
                        set lastJSError to ""
                        try
                            tell front window to tell active tab
                                set activeURL to ""
                                try
                                    set activeURL to URL
                                end try
                                if activeURL contains "\(escapedFrag)" then
                                    try
                                        set injectOut to execute javascript "\(escapedJS)"
                                        if injectOut starts with "__PENDING__:" then
                                            repeat 10 times
                                                delay 0.12
                                                set asyncStatus to execute javascript "\(pollJSChrome)"
                                                if asyncStatus is not "__WAIT__" then return asyncStatus
                                            end repeat
                                            return execute javascript "\(finalJSChrome)"
                                        end if
                                        return injectOut
                                    on error errMsg
                                        set lastJSError to "__JS_ERROR__:" & errMsg
                                    end try
                                end if
                            end tell
                        end try
                        repeat with w in windows
                            repeat with t in tabs of w
                                set tabURL to ""
                                try
                                    set tabURL to URL of t
                                end try
                                if tabURL contains "\(escapedFrag)" then
                                    try
                                        tell t
                                            set injectOut to execute javascript "\(escapedJS)"
                                            if injectOut starts with "__PENDING__:" then
                                                repeat 10 times
                                                    delay 0.12
                                                    set asyncStatus to execute javascript "\(pollJSChrome)"
                                                    if asyncStatus is not "__WAIT__" then return asyncStatus
                                                end repeat
                                                return execute javascript "\(finalJSChrome)"
                                            end if
                                            return injectOut
                                        end tell
                                    on error errMsg
                                        set lastJSError to "__JS_ERROR__:" & errMsg
                                    end try
                                end if
                            end repeat
                        end repeat
                        if lastJSError is not "" then return lastJSError
                        try
                            tell front window to tell active tab
                                set injectOut to execute javascript "\(escapedJS)"
                                if injectOut starts with "__PENDING__:" then
                                    repeat 10 times
                                        delay 0.12
                                        set asyncStatus to execute javascript "\(pollJSChrome)"
                                        if asyncStatus is not "__WAIT__" then return asyncStatus
                                    end repeat
                                    return execute javascript "\(finalJSChrome)"
                                end if
                                return injectOut
                            end tell
                        on error errMsg
                            return "__JS_ERROR__:" & errMsg
                        end try
                    end if
                end tell
                """
            }
            return """
            tell application id "com.apple.Safari"
                if (count of windows) > 0 then
                    set lastJSError to ""
                    try
                        set activeTab to current tab of front window
                        set activeURL to ""
                        try
                            set activeURL to URL of activeTab
                        end try
                        if activeURL contains "\(escapedFrag)" then
                            try
                                set injectOut to do JavaScript "\(escapedJS)" in activeTab
                                if injectOut starts with "__PENDING__:" then
                                    repeat 10 times
                                        delay 0.12
                                        set asyncStatus to do JavaScript "\(pollJSChrome)" in activeTab
                                        if asyncStatus is not "__WAIT__" then return asyncStatus
                                    end repeat
                                    return do JavaScript "\(finalJSChrome)" in activeTab
                                end if
                                return injectOut
                            on error errMsg
                                set lastJSError to "__JS_ERROR__:" & errMsg
                            end try
                        end if
                    end try
                    repeat with w in windows
                        repeat with t in tabs of w
                            set tabURL to ""
                            try
                                set tabURL to URL of t
                            end try
                            if tabURL contains "\(escapedFrag)" then
                                try
                                    set injectOut to do JavaScript "\(escapedJS)" in t
                                    if injectOut starts with "__PENDING__:" then
                                        repeat 10 times
                                            delay 0.12
                                            set asyncStatus to do JavaScript "\(pollJSChrome)" in t
                                            if asyncStatus is not "__WAIT__" then return asyncStatus
                                        end repeat
                                        return do JavaScript "\(finalJSChrome)" in t
                                    end if
                                    return injectOut
                                on error errMsg
                                    set lastJSError to "__JS_ERROR__:" & errMsg
                                end try
                            end if
                        end repeat
                    end repeat
                    if lastJSError is not "" then return lastJSError
                    try
                        tell front window to tell current tab
                            set injectOut to do JavaScript "\(escapedJS)"
                            if injectOut starts with "__PENDING__:" then
                                repeat 14 times
                                    delay 0.12
                                    set asyncStatus to do JavaScript "\(pollJSChrome)"
                                    if asyncStatus is not "__WAIT__" then return asyncStatus
                                end repeat
                                return do JavaScript "\(finalJSChrome)"
                            end if
                            return injectOut
                        end tell
                    on error errMsg
                        return "__JS_ERROR__:" & errMsg
                    end try
                end if
            end tell
            """
        }
        
        if isChrome {
            return """
            tell application id "\(bundleID)"
                if (count of windows) > 0 then
                    try
                        tell front window to tell active tab
                            set injectOut to execute javascript "\(escapedJS)"
                            if injectOut starts with "__PENDING__:" then
                                repeat 10 times
                                    delay 0.12
                                    set asyncStatus to execute javascript "\(pollJSChrome)"
                                    if asyncStatus is not "__WAIT__" then return asyncStatus
                                end repeat
                                return execute javascript "\(finalJSChrome)"
                            end if
                            return injectOut
                        end tell
                    on error errMsg
                        return "__JS_ERROR__:" & errMsg
                    end try
                end if
            end tell
            """
        }
        return """
        tell application id "com.apple.Safari"
            if (count of windows) > 0 then
                try
                    tell front window to tell current tab
                        set injectOut to do JavaScript "\(escapedJS)"
                        if injectOut starts with "__PENDING__:" then
                            repeat 10 times
                                delay 0.12
                                set asyncStatus to do JavaScript "\(pollJSChrome)"
                                if asyncStatus is not "__WAIT__" then return asyncStatus
                            end repeat
                            return do JavaScript "\(finalJSChrome)"
                        end if
                        return injectOut
                    end tell
                on error errMsg
                    return "__JS_ERROR__:" & errMsg
                end try
            end if
        end tell
        """
    }
    
    /// Builds AppleScript that reads the array of field titles injected by the last `buildDOMInjectionAppleScript` call.
    public static func buildDOMFilledLabelsAppleScript(bundleID: String, targetURL: String? = nil) -> String? {
        let b = bundleID.lowercased()
        let isChrome = isChromiumBundleID(b)
        let isSafari = b.contains("safari") && !b.contains("technology")
        guard isChrome || isSafari else { return nil }
        let readJS = appleScriptStringLiteralBody("(function(){ return (window.__morphAsyncState && Array.isArray(window.__morphAsyncState.filled)) ? JSON.stringify(window.__morphAsyncState.filled) : '[]'; })()")
        if let fragment = appleScriptTabMatchFragment(from: targetURL) {
            let escapedFrag = appleScriptStringLiteralBody(fragment)
            if isChrome {
                return """
                tell application id "\(bundleID)"
                    if (count of windows) > 0 then
                        try
                            tell front window to tell active tab
                                set activeURL to ""
                                try
                                    set activeURL to URL
                                end try
                                if activeURL contains "\(escapedFrag)" then
                                    return execute javascript "\(readJS)"
                                end if
                            end tell
                        end try
                        repeat with w in windows
                            repeat with t in tabs of w
                                set tabURL to ""
                                try
                                    set tabURL to URL of t
                                end try
                                if tabURL contains "\(escapedFrag)" then
                                    try
                                        tell t to return execute javascript "\(readJS)"
                                    on error
                                    end try
                                end if
                            end repeat
                        end repeat
                        try
                            tell front window to tell active tab to return execute javascript "\(readJS)"
                        on error
                            return "[]"
                        end try
                    end if
                end tell
                """
            }
            return """
            tell application id "com.apple.Safari"
                if (count of windows) > 0 then
                    try
                        set activeTab to current tab of front window
                        set activeURL to ""
                        try
                            set activeURL to URL of activeTab
                        end try
                        if activeURL contains "\(escapedFrag)" then
                            return do JavaScript "\(readJS)" in activeTab
                        end if
                    end try
                    repeat with w in windows
                        repeat with t in tabs of w
                            set tabURL to ""
                            try
                                set tabURL to URL of t
                            end try
                            if tabURL contains "\(escapedFrag)" then
                                try
                                    return do JavaScript "\(readJS)" in t
                                on error
                                end try
                            end if
                        end repeat
                    end repeat
                    try
                        tell front window to tell current tab to return do JavaScript "\(readJS)"
                    on error
                        return "[]"
                    end try
                end if
            end tell
            """
        }
        if isChrome {
            return """
            tell application id "\(bundleID)"
                if (count of windows) > 0 then
                    try
                        tell front window to tell active tab to return execute javascript "\(readJS)"
                    on error
                        return "[]"
                    end try
                end if
            end tell
            """
        }
        return """
        tell application id "com.apple.Safari"
            if (count of windows) > 0 then
                try
                    tell front window to tell current tab to return do JavaScript "\(readJS)"
                on error
                    return "[]"
                end try
            end if
        end tell
        """
    }
    
    private static func snapshotPasteboard() -> [(NSPasteboard.PasteboardType, Data)] {
        guard let item = NSPasteboard.general.pasteboardItems?.first else { return [] }
        return item.types.compactMap { type in
            item.data(forType: type).map { (type, $0) }
        }
    }
    
    private static func restorePasteboard(_ snapshot: [(NSPasteboard.PasteboardType, Data)], expectedChangeCount: Int) {
        let pb = NSPasteboard.general
        guard pb.changeCount == expectedChangeCount else { return }
        pb.clearContents()
        guard !snapshot.isEmpty else { return }
        let newItem = NSPasteboardItem()
        for (t, d) in snapshot {
            newItem.setData(d, forType: t)
        }
        pb.writeObjects([newItem])
    }
    
    private static func postSyntheticKey(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        let src = CGEventSource(stateID: .combinedSessionState)
        if let kd = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true) {
            kd.flags = flags
            kd.setIntegerValueField(.eventSourceUserData, value: syntheticEventUserDataTag)
            kd.post(tap: .cghidEventTap)
        }
        if let ku = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false) {
            ku.flags = flags
            ku.setIntegerValueField(.eventSourceUserData, value: syntheticEventUserDataTag)
            ku.post(tap: .cghidEventTap)
        }
    }
    
    private static func splitSubfieldValueIfApplicable(desc: String, resolvedLabel: String, fullValue: String) -> String {
        let d = desc.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let l = resolvedLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !d.isEmpty && d != l else { return fullValue }
        if d == "month" || d == "day" || d == "year" {
            let trimmed = fullValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if let isoRange = trimmed.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) {
                let parts = String(trimmed[isoRange]).components(separatedBy: "-")
                if parts.count == 3 {
                    if d == "year" { return parts[0] }
                    if d == "month" { return parts[1] }
                    if d == "day" { return parts[2] }
                }
            }
            let slashParts = trimmed.components(separatedBy: CharacterSet(charactersIn: "/-"))
            if slashParts.count == 3, let n1 = Int(slashParts[0]), let n2 = Int(slashParts[1]), slashParts[2].count == 4 {
                let (mo, dy) = (n1 > 12 && n2 <= 12) ? (slashParts[1], slashParts[0]) : (slashParts[0], slashParts[1])
                if d == "month" { return mo }
                if d == "day" { return dy }
                if d == "year" { return slashParts[2] }
            }
        } else if d == "hour" || d == "minute" {
            let trimmed = fullValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = trimmed.uppercased()
            let clean = upper.replacingOccurrences(of: "AM", with: "").replacingOccurrences(of: "PM", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let timeParts = clean.components(separatedBy: ":")
            if timeParts.count == 2, let h = Int(timeParts[0]), let m = Int(timeParts[1]) {
                if d == "hour" {
                    if upper.contains("PM") && h < 12 { return String(format: "%02d", h + 12) }
                    if upper.contains("AM") && h == 12 { return "00" }
                    return String(format: "%02d", h)
                }
                if d == "minute" { return String(format: "%02d", m) }
            }
        }
        return fullValue
    }
    
    /// Injects answers into a browser window using macOS Accessibility API (with verified paste/value write & per-question reporting).
    @MainActor
    public static func injectAnswersViaAccessibilityWithReport(app: NSRunningApplication, answers: [String: String], fields: [FormInputField]) -> (count: Int, labels: Set<String>) {
        let appElem = AXUIElementCreateApplication(app.processIdentifier)
        guard let win = DefaultApplicationFormDetector.getBrowserWindowElement(appElem: appElem),
              let webArea = ensureWebAccessibilityEnabledIfNeeded(for: app, appElem: appElem, window: win) else {
            return (0, [])
        }
        
        var filledLabels = Set<String>()
        var didTouchClipboard = false
        let savedClipboard = snapshotPasteboard()
        var lastWrittenChangeCount = NSPasteboard.general.changeCount
        defer {
            if didTouchClipboard {
                RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.06))
                restorePasteboard(savedClipboard, expectedChangeCount: lastWrittenChangeCount)
            }
        }
        
        var didActivateBrowser = (NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier)
        func ensureActivated() {
            if !didActivateBrowser {
                didActivateBrowser = activateBrowser(app)
            }
        }
        
        var queue: [AXUIElement] = [webArea]
        var head = 0
        let maxElements = 10000
        
        func axOptionMatches(_ optionTitle: String, _ target: String) -> Bool {
            let opt = optionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let tgt = target.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !opt.isEmpty && !tgt.isEmpty else { return false }
            if opt.caseInsensitiveCompare(tgt) == .orderedSame { return true }
            let optNorm = opt.lowercased().replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            let tgtNorm = tgt.lowercased().replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            if optNorm == tgtNorm { return true }
            if min(optNorm.count, tgtNorm.count) >= 3 {
                let escaped = NSRegularExpression.escapedPattern(for: tgtNorm)
                if let re = try? NSRegularExpression(pattern: "(^|\\b)" + escaped + "(\\b|$)", options: [.caseInsensitive]),
                   re.firstMatch(in: optNorm, range: NSRange(location: 0, length: optNorm.utf16.count)) != nil {
                    return true
                }
            }
            return false
        }
        
        func findMatchedAnswer(for label: String) -> (key: String, value: String)? {
            let clean = ApplicationFormModel.cleanQuestionTitle(label)
            guard !clean.isEmpty else { return nil }
            if let exact = answers[clean], !exact.isEmpty { return (clean, exact) }
            if let exactRaw = answers[label], !exactRaw.isEmpty { return (label, exactRaw) }
            for (k, v) in answers where !v.isEmpty {
                let cleanK = ApplicationFormModel.cleanQuestionTitle(k)
                if cleanK.caseInsensitiveCompare(clean) == .orderedSame ||
                   (!clean.isEmpty && !cleanK.isEmpty &&
                    !ApplicationFormModel.hasQualifierConflict(cleanK, clean) &&
                    (cleanK.localizedCaseInsensitiveContains(clean) || clean.localizedCaseInsensitiveContains(cleanK))) {
                    return (k, v)
                }
            }
            return nil
        }
        
        func isTargetFocused(_ elem: AXUIElement) -> Bool {
            var focusedBoolRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(elem, kAXFocusedAttribute as CFString, &focusedBoolRef) == .success {
                if let b = focusedBoolRef as? Bool, b { return true }
                if let n = focusedBoolRef as? Int, n == 1 { return true }
            }
            var appFocusedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElem, kAXFocusedUIElementAttribute as CFString, &appFocusedRef) == .success,
               let focused = appFocusedRef {
                return CFEqual(focused, elem)
            }
            return false
        }
        
        func valuesMatchAfterWrite(_ readback: String?, expected: String) -> Bool {
            guard let rb = readback?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
            let exp = expected.trimmingCharacters(in: .whitespacesAndNewlines)
            if rb == exp { return true }
            if let rInt = Int(rb), let eInt = Int(exp), rInt == eInt { return true }
            return false
        }
        
        while head < queue.count && head < maxElements {
            let current = queue[head]
            head += 1
            
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &roleRef)
            let role = (roleRef as? String) ?? ""
            
            if role == "AXTextField" || role == "AXTextArea" || role == "AXSearchField" {
                var descRef: CFTypeRef?
                AXUIElementCopyAttributeValue(current, kAXDescriptionAttribute as CFString, &descRef)
                let desc = (descRef as? String) ?? ""
                let lowerDesc = desc.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let isChromeAddressBar = lowerDesc == "address and search bar" || lowerDesc == "address bar" || lowerDesc == "address" || lowerDesc == "search or enter website name"
                if !isChromeAddressBar {
                    let label = resolveQuestionLabel(for: current, fields: fields, fallback: desc)
                    if let matched = findMatchedAnswer(for: label) {
                        let writeVal = splitSubfieldValueIfApplicable(desc: desc, resolvedLabel: label, fullValue: matched.value)
                        ensureActivated()
                        _ = AXUIElementPerformAction(current, "AXScrollToVisible" as CFString)
                        _ = AXUIElementSetAttributeValue(current, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.025))
                        
                        var wrote = false
                        if didActivateBrowser && !isBrowserChromeInputFocused(for: app) && isTargetFocused(current) {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(writeVal, forType: .string)
                            lastWrittenChangeCount = pb.changeCount
                            didTouchClipboard = true
                            
                            postSyntheticKey(keyCode: 0, flags: .maskCommand) // Cmd+A
                            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
                            postSyntheticKey(keyCode: 9, flags: .maskCommand) // Cmd+V
                            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.055))
                            
                            var rbRef: CFTypeRef?
                            AXUIElementCopyAttributeValue(current, kAXValueAttribute as CFString, &rbRef)
                            if valuesMatchAfterWrite(rbRef as? String, expected: writeVal) {
                                wrote = true
                            }
                        }
                        if !wrote {
                            _ = AXUIElementSetAttributeValue(current, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                            let res = AXUIElementSetAttributeValue(current, kAXValueAttribute as CFString, writeVal as CFTypeRef)
                            if res == .success {
                                var rbRef: CFTypeRef?
                                AXUIElementCopyAttributeValue(current, kAXValueAttribute as CFString, &rbRef)
                                if rbRef == nil || valuesMatchAfterWrite(rbRef as? String, expected: writeVal) {
                                    wrote = true
                                }
                            }
                        }
                        if wrote {
                            filledLabels.insert(matched.key)
                        }
                    }
                }
            } else if role == "AXRadioButton" {
                let label = resolveQuestionLabel(for: current, fields: fields)
                if let matched = findMatchedAnswer(for: label) {
                    let optionTitle = extractOptionTitle(from: current)
                    if axOptionMatches(optionTitle, matched.value) {
                        ensureActivated()
                        _ = AXUIElementPerformAction(current, "AXScrollToVisible" as CFString)
                        let res = AXUIElementPerformAction(current, kAXPressAction as CFString)
                        if res == .success {
                            filledLabels.insert(matched.key)
                        }
                    }
                }
            } else if role == "AXCheckBox" {
                let label = resolveQuestionLabel(for: current, fields: fields)
                if let matched = findMatchedAnswer(for: label) {
                    let parts = matched.value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    let optionTitle = extractOptionTitle(from: current)
                    let matchesPart = parts.contains { part in axOptionMatches(optionTitle, part) }
                    if matchesPart {
                        var checkedRef: CFTypeRef?
                        AXUIElementCopyAttributeValue(current, kAXValueAttribute as CFString, &checkedRef)
                        let alreadyChecked = (checkedRef as? Int == 1) || (checkedRef as? Bool == true)
                        if !alreadyChecked {
                            ensureActivated()
                            _ = AXUIElementPerformAction(current, "AXScrollToVisible" as CFString)
                            let res = AXUIElementPerformAction(current, kAXPressAction as CFString)
                            if res == .success {
                                filledLabels.insert(matched.key)
                            }
                        } else {
                            filledLabels.insert(matched.key)
                        }
                    }
                }
            } else if role == "AXPopUpButton" || role == "AXComboBox" || role == "AXMenuButton" {
                let label = resolveQuestionLabel(for: current, fields: fields)
                if let matched = findMatchedAnswer(for: label) {
                    ensureActivated()
                    _ = AXUIElementPerformAction(current, "AXScrollToVisible" as CFString)
                    AXUIElementSetAttributeValue(current, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                    var selectedOption = false
                    if AXUIElementSetAttributeValue(current, kAXValueAttribute as CFString, matched.value as CFTypeRef) == .success {
                        var rbRef: CFTypeRef?
                        AXUIElementCopyAttributeValue(current, kAXValueAttribute as CFString, &rbRef)
                        if axOptionMatches((rbRef as? String) ?? "", matched.value) {
                            selectedOption = true
                        }
                    }
                    if !selectedOption && AXUIElementPerformAction(current, kAXPressAction as CFString) == .success {
                        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.085))
                        for child in axChildren(current) {
                            let title = axText(child) ?? ""
                            if !title.isEmpty && axOptionMatches(title, matched.value) {
                                if AXUIElementPerformAction(child, kAXPressAction as CFString) == .success {
                                    selectedOption = true
                                    break
                                }
                            }
                        }
                        if !selectedOption {
                            // Search mounted Wiz portal options under webArea (AXMenuItem / AXMenu / AXList children)
                            var pQueue: [AXUIElement] = [webArea]
                            var pHead = 0
                            while pHead < pQueue.count && pHead < 3000 && !selectedOption {
                                let node = pQueue[pHead]
                                pHead += 1
                                let nRole = axRole(node)
                                if nRole == "AXMenu" || nRole == "AXList" {
                                    for opt in axChildren(node) {
                                        let optText = axText(opt) ?? ""
                                        if !optText.isEmpty && axOptionMatches(optText, matched.value), !CFEqual(opt, current) {
                                            if AXUIElementPerformAction(opt, kAXPressAction as CFString) == .success {
                                                selectedOption = true
                                                break
                                            }
                                        }
                                    }
                                } else if nRole == "AXMenuItem" {
                                    let optText = axText(node) ?? ""
                                    if !optText.isEmpty && axOptionMatches(optText, matched.value), !CFEqual(node, current) {
                                        if AXUIElementPerformAction(node, kAXPressAction as CFString) == .success {
                                            selectedOption = true
                                            break
                                        }
                                    }
                                }
                                if !selectedOption {
                                    pQueue.append(contentsOf: axChildren(node))
                                }
                            }
                            if !selectedOption && didActivateBrowser {
                                postSyntheticKey(keyCode: 53) // Escape closes unmatching popup cleanly
                            }
                        }
                    }
                    if selectedOption {
                        filledLabels.insert(matched.key)
                    }
                }
            }
            
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(current, kAXChildrenAttribute as CFString, &childrenRef) == .success,
               let children = childrenRef as? [AXUIElement] {
                for c in children {
                    queue.append(c)
                }
            }
        }
        return (filledLabels.count, filledLabels)
    }
    
    /// Injects answers into a browser window using macOS Accessibility API.
    @MainActor
    public static func injectAnswersViaAccessibility(app: NSRunningApplication, answers: [String: String], fields: [FormInputField]) -> Int {
        return injectAnswersViaAccessibilityWithReport(app: app, answers: answers, fields: fields).count
    }
    
    /// Simulates pasting a text string into the currently focused window or application element,
    /// preserving the user's previous clipboard contents after delivery settles.
    @MainActor
    public static func simulatePasteText(_ text: String, targetApp: NSRunningApplication? = nil, selectAllFirst: Bool = false) {
        if let app = targetApp {
            _ = activateBrowser(app)
        }
        let savedSnapshot = snapshotPasteboard()
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        let wroteChangeCount = pb.changeCount
        
        if selectAllFirst {
            postSyntheticKey(keyCode: 0, flags: .maskCommand)
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        postSyntheticKey(keyCode: 9, flags: .maskCommand)
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            restorePasteboard(savedSnapshot, expectedChangeCount: wroteChangeCount)
        }
    }
    
    /// Parses the `title:::value:::type:::options` output of `domExtractionScript`.
    /// Preserves full question format awareness and available choices.
    public static func parseDOMExtractionItems(_ output: String) -> [ExtractedInputItem] {
        if output.contains("__FORM_SUBMITTED__") {
            for pair in output.components(separatedBy: "|||") {
                let parts = pair.components(separatedBy: ":::")
                if parts.count >= 2 && parts[0] == "__FORM_SUBMITTED__" {
                    let msg = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    return [ExtractedInputItem(label: "__FORM_SUBMITTED__", value: msg, questionType: "submitted", options: [])]
                }
            }
        }
        if output.contains("__FORM_CLOSED__") {
            for pair in output.components(separatedBy: "|||") {
                let parts = pair.components(separatedBy: ":::")
                if parts.count >= 2 && parts[0] == "__FORM_CLOSED__" {
                    let reason = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    return [ExtractedInputItem(label: "__FORM_CLOSED__", value: reason, questionType: "closed", options: [])]
                }
            }
        }
        let knownTypes: Set<String> = [
            "shortAnswer", "paragraph", "multipleChoice", "checkboxes",
            "dropdown", "fileUpload", "linearScale", "grid", "date", "time", "closed", "submitted", "info", "section"
        ]
        var results: [ExtractedInputItem] = []
        for pair in output.components(separatedBy: "|||") {
            var rawPair = pair
            var isReq = false
            if rawPair.hasSuffix(":::__REQ__") {
                isReq = true
                rawPair = String(rawPair.dropLast(":::__REQ__".count))
            }
            let parts = rawPair.components(separatedBy: ":::")
            guard parts.count >= 2 else { continue }
            let lbl = ApplicationFormModel.cleanQuestionTitle(parts[0])
            guard !lbl.isEmpty else { continue }
            
            let val: String
            let qType: String?
            let options: [String]
            
            if parts.count == 2 {
                val = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                qType = nil
                options = []
            } else if parts.count == 3 {
                let candidateType = parts[2].trimmingCharacters(in: .whitespacesAndNewlines)
                if knownTypes.contains(candidateType) {
                    val = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    qType = candidateType
                    options = []
                } else {
                    val = parts[1...].joined(separator: ":::").trimmingCharacters(in: .whitespacesAndNewlines)
                    qType = nil
                    options = []
                }
            } else {
                let candidateType = parts[parts.count - 2].trimmingCharacters(in: .whitespacesAndNewlines)
                if knownTypes.contains(candidateType) {
                    val = parts[1...(parts.count - 3)].joined(separator: ":::").trimmingCharacters(in: .whitespacesAndNewlines)
                    qType = candidateType
                    let rawOpts = parts[parts.count - 1]
                    options = rawOpts.components(separatedBy: ";;;")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                } else {
                    val = parts[1...].joined(separator: ":::").trimmingCharacters(in: .whitespacesAndNewlines)
                    qType = nil
                    options = []
                }
            }
            results.append(ExtractedInputItem(label: lbl, value: val, questionType: qType, options: options, isRequired: isReq))
        }
        return results
    }
    
    /// Parses the `title:::value|||title:::value` output of `domExtractionScript`.
    /// Pairs with an empty value are kept so callers can detect cleared answers.
    public static func parseDOMExtractionOutput(_ output: String) -> [(label: String, value: String)] {
        return parseDOMExtractionItems(output).map { ($0.label, $0.value) }
    }
    
    /// Reads every question, its format, options, and its current answer from the active or target form tab.
    public static func extractItemsSnapshotViaAppleScript(bundleID: String, targetURL: String? = nil) -> [ExtractedInputItem]? {
        guard let scriptSource = buildDOMExtractionAppleScript(bundleID: bundleID, targetURL: targetURL),
              let output = executeAppleScript(scriptSource),
              !output.isEmpty,
              !output.hasPrefix("__JS_ERROR__:") else { return nil }
        return parseDOMExtractionItems(output)
    }
    
    /// Reads every question and its current answer (empty string when unanswered) from the active tab of a
    /// scriptable browser (Safari, Chrome, Brave, Arc, Edge...) via AppleScript DOM extraction.
    public static func extractSnapshotViaAppleScript(bundleID: String) -> [(label: String, value: String)]? {
        return extractItemsSnapshotViaAppleScript(bundleID: bundleID)?.map { ($0.label, $0.value) }
    }
    
    /// Extracts answered questions (non-empty values only) from scriptable browsers via AppleScript.
    public static func extractInputsViaAppleScript(bundleID: String) -> [(label: String, value: String)]? {
        guard let snapshot = extractSnapshotViaAppleScript(bundleID: bundleID) else { return nil }
        return snapshot.filter { !$0.value.isEmpty }
    }
    
    private static func collectBlinkFormRecords(
        from sessionData: Data,
        formURL: String
    ) -> (signatureOrder: [String], latestStringsBySignature: [String: [String]]) {
        guard let targetFormID = DefaultApplicationFormDetector.extractFormIdentifier(from: formURL),
              !targetFormID.isEmpty,
              let needle = "Blink serialized form state".data(using: .utf16LittleEndian) else {
            return ([], [:])
        }
        let mojoStringHeader = Data([0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                     0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        
        var latestStringsBySignature: [String: [String]] = [:]
        var signatureOrder: [String] = []
        
        var searchStart = sessionData.startIndex
        while searchStart < sessionData.endIndex,
              let range = sessionData.range(of: needle, options: [], in: searchStart..<sessionData.endIndex) {
            let pos = range.lowerBound
            searchStart = range.upperBound
            
            let lookbackStart = max(sessionData.startIndex, pos - 64)
            let lookbackEnd = min(sessionData.endIndex, pos + 16)
            guard let headerRange = sessionData.range(of: mojoStringHeader, options: .backwards, in: lookbackStart..<lookbackEnd) else {
                continue
            }
            
            var strings: [String] = []
            var cur = headerRange.lowerBound
            while cur + 24 <= sessionData.endIndex {
                if sessionData.subdata(in: cur..<(cur + 16)) != mojoStringHeader {
                    break
                }
                let byteLen = sessionData.subdata(in: (cur + 16)..<(cur + 20)).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
                let charLen = sessionData.subdata(in: (cur + 20)..<(cur + 24)).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
                if charLen > 10_000 || byteLen != 8 + charLen * 2 {
                    break
                }
                let strEnd = cur + 24 + Int(charLen) * 2
                guard strEnd <= sessionData.endIndex else { break }
                let strBytes = sessionData.subdata(in: (cur + 24)..<strEnd)
                let str = String(data: strBytes, encoding: .utf16LittleEndian) ?? ""
                strings.append(str)
                let alignedArray = (8 + Int(charLen) * 2 + 7) & ~7
                cur += 16 + alignedArray
            }
            
            guard strings.count >= 3 else { continue }
            let formSig = strings[1]
            guard DefaultApplicationFormDetector.extractFormIdentifier(from: formSig) == targetFormID else { continue }
            if !signatureOrder.contains(formSig) {
                signatureOrder.append(formSig)
            }
            latestStringsBySignature[formSig] = strings
        }
        return (signatureOrder, latestStringsBySignature)
    }
    
    /// Computes a canonical fingerprint of the latest Blink serialized form state records for `formURL`,
    /// enabling stale pre-reopen/pre-clear session data in Polar's shared `Session_*` file to be ignored.
    public static func extractBlinkFormStateSignature(from sessionData: Data, formURL: String) -> String? {
        let collected = collectBlinkFormRecords(from: sessionData, formURL: formURL)
        guard !collected.signatureOrder.isEmpty else { return nil }
        var parts: [String] = []
        for sig in collected.signatureOrder {
            if let strs = collected.latestStringsBySignature[sig] {
                parts.append(sig + "::" + strs.dropFirst(2).joined(separator: "|"))
            }
        }
        return parts.joined(separator: "||")
    }
    
    /// Parses Mojo-serialized `Blink serialized form state version 10` records from Chromium/Polar SNSS session data
    /// and maps any non-empty values for the given `formURL` onto the matching schema `fields`.
    /// Only the LAST (most recent) record in the session data for each form page signature is used.
    public static func extractBlinkFormStatePairs(
        from sessionData: Data,
        formURL: String,
        fields: [FormInputField]
    ) -> [(label: String, value: String)] {
        guard !fields.isEmpty else { return [] }
        let collected = collectBlinkFormRecords(from: sessionData, formURL: formURL)
        let signatureOrder = collected.signatureOrder
        let latestStringsBySignature = collected.latestStringsBySignature
        
        var extracted: [(label: String, value: String)] = []
        for sig in signatureOrder {
            guard let strs = latestStringsBySignature[sig], strs.count >= 3,
                  let controlCount = Int(strs[2]), controlCount > 0 else { continue }
            
            var controls: [(name: String, type: String, value: String)] = []
            var idx = 3
            for _ in 0..<controlCount {
                guard idx + 2 < strs.count else { break }
                let cName = strs[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                let cType = strs[idx + 1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let valCount = Int(strs[idx + 2]) ?? 0
                idx += 3
                var val = ""
                if valCount > 0 && idx < strs.count {
                    val = strs[idx]
                }
                idx += max(0, valCount)
                controls.append((name: cName, type: cType, value: val))
            }
            
            // Determine page slice in `fields` from `[entry.XXXX ...]` in `sig` using the earliest matching token
            // walked backward to the beginning of its section (handles out-of-order entry tokens cleanly).
            var entryTokens: Set<String> = []
            if let bracketStart = sig.range(of: "[entry."),
               let bracketEnd = sig.range(of: "]", range: bracketStart.lowerBound..<sig.endIndex) {
                let inside = String(sig[bracketStart.lowerBound..<bracketEnd.lowerBound]).replacingOccurrences(of: "[", with: "")
                let tokens = inside.components(separatedBy: .whitespaces).filter { $0.hasPrefix("entry.") }
                entryTokens = Set(tokens.map { $0.lowercased() })
            }
            
            var pageStartIdx = 0
            if !entryTokens.isEmpty,
               let earliestIdx = fields.indices.first(where: { fields[$0].entryKey.map { entryTokens.contains($0.lowercased()) } ?? false }) {
                pageStartIdx = earliestIdx
                while pageStartIdx > 0 && fields[pageStartIdx - 1].questionType != "section" {
                    pageStartIdx -= 1
                }
            }
            var pageEndIdx = fields.count
            if pageStartIdx + 1 < fields.count {
                for j in (pageStartIdx + 1)..<fields.count {
                    if fields[j].questionType == "section" {
                        pageEndIdx = j
                        break
                    }
                }
            }
            let pageFields = Array(fields[pageStartIdx..<pageEndIdx])
            
            // 1. Named controls matching `entryKey` or `label`
            for ctrl in controls where !ctrl.name.isEmpty && !ctrl.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let match = pageFields.first(where: { $0.entryKey?.lowercased() == ctrl.name.lowercased() }) ??
                               fields.first(where: { $0.entryKey?.lowercased() == ctrl.name.lowercased() }) {
                    extracted.append((label: match.label, value: ctrl.value.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
            }
            
            // 2. Unnamed `<textarea>` controls on this page matching `paragraph` fields on this page
            let unnamedTextareas = controls.filter { $0.name.isEmpty && $0.type == "textarea" }
            let pageParagraphs = pageFields.filter { $0.questionType == "paragraph" }
            if !unnamedTextareas.isEmpty && unnamedTextareas.count == pageParagraphs.count {
                for k in 0..<unnamedTextareas.count {
                    let cleanVal = unnamedTextareas[k].value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanVal.isEmpty {
                        extracted.append((label: pageParagraphs[k].label, value: cleanVal))
                    }
                }
            }
            
            // 3. Unnamed `<input>` text controls on this page matching `shortAnswer` / `text` fields on this page
            let textInputTypes: Set<String> = ["text", "input", "email", "tel", "url", "number", "search"]
            let unnamedTexts = controls.filter { $0.name.isEmpty && textInputTypes.contains($0.type) }
            let pageShortAnswers = pageFields.filter { ["shortAnswer", "text"].contains($0.questionType) }
            if !unnamedTexts.isEmpty && unnamedTexts.count == pageShortAnswers.count {
                for k in 0..<unnamedTexts.count {
                    let cleanVal = unnamedTexts[k].value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleanVal.isEmpty {
                        extracted.append((label: pageShortAnswers[k].label, value: cleanVal))
                    }
                }
            }
        }
        return extracted
    }
    
    /// Reads the most recently modified Polar `Session_*` file data (only if modified during the active session window).
    private static func latestPolarSessionFileData(
        sessionStartedAt: Date,
        useLookback: Bool,
        maxModificationDate: Date? = nil,
        sessionDirectories: [String]? = nil
    ) -> Data? {
        var possibleDirs: [String] = []
        if let customDirs = sessionDirectories {
            possibleDirs = customDirs
        } else {
            let polarBase = ("~/Library/Application Support/com.polar.browser.host" as NSString).expandingTildeInPath
            possibleDirs = [
                (polarBase as NSString).appendingPathComponent("Sessions"),
                (polarBase as NSString).appendingPathComponent("Default/Sessions")
            ]
            if let subdirs = try? FileManager.default.contentsOfDirectory(atPath: polarBase) {
                for sub in subdirs {
                    let sessionDir = (polarBase as NSString).appendingPathComponent("\(sub)/Sessions")
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: sessionDir, isDirectory: &isDir), isDir.boolValue {
                        if !possibleDirs.contains(sessionDir) {
                            possibleDirs.append(sessionDir)
                        }
                    }
                }
            }
        }
        
        let minMtime = useLookback ? sessionStartedAt.addingTimeInterval(-15.0) : sessionStartedAt
        var candidates: [(path: String, mtime: Date)] = []
        for dir in possibleDirs {
            guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir) else { continue }
            for file in files where file.hasPrefix("Session_") {
                let fullPath = (dir as NSString).appendingPathComponent(file)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                   let mtime = attrs[.modificationDate] as? Date,
                   mtime >= minMtime,
                   maxModificationDate.map({ mtime <= $0 }) ?? true {
                    candidates.append((fullPath, mtime))
                }
            }
        }
        candidates.sort { $0.mtime > $1.mtime }
        guard let newest = candidates.first else { return nil }
        return try? Data(contentsOf: URL(fileURLWithPath: newest.path))
    }
    
    /// Reads the latest Polar Blink serialized form signature for suppression checks across reopened blank sessions.
    public static func extractLatestPolarBlinkSignature(
        formURL: String,
        sessionStartedAt: Date = Date().addingTimeInterval(-3600),
        maxModificationDate: Date? = nil,
        sessionDirectories: [String]? = nil
    ) -> String? {
        guard !formURL.isEmpty,
              let data = latestPolarSessionFileData(
                  sessionStartedAt: sessionStartedAt,
                  useLookback: true,
                  maxModificationDate: maxModificationDate,
                  sessionDirectories: sessionDirectories
              ) else {
            return nil
        }
        return extractBlinkFormStateSignature(from: data, formURL: formURL)
    }
    
    /// Reads the most recently modified Polar `Session_*` file (only if modified during the active session window)
    /// and extracts both any non-empty Blink form state values and the record signature.
    public static func extractLatestPolarBlinkState(
        formURL: String,
        fields: [FormInputField],
        sessionStartedAt: Date,
        useLookback: Bool = true,
        sessionDirectories: [String]? = nil
    ) -> (pairs: [(label: String, value: String)], signature: String?) {
        guard !fields.isEmpty, !formURL.isEmpty,
              let data = latestPolarSessionFileData(
                  sessionStartedAt: sessionStartedAt,
                  useLookback: useLookback,
                  sessionDirectories: sessionDirectories
              ) else {
            return ([], nil)
        }
        let sig = extractBlinkFormStateSignature(from: data, formURL: formURL)
        let pairs = extractBlinkFormStatePairs(from: data, formURL: formURL, fields: fields)
        return (pairs, sig)
    }
    
    /// Reads the most recently modified Polar `Session_*` file (only if modified during the active session window)
    /// and extracts any non-empty Blink form state values for `formURL`.
    public static func extractLatestPolarBlinkFormValues(
        formURL: String,
        fields: [FormInputField],
        sessionStartedAt: Date
    ) -> [(label: String, value: String)] {
        return extractLatestPolarBlinkState(formURL: formURL, fields: fields, sessionStartedAt: sessionStartedAt).pairs
    }
    
    public static func executeAppleScript(_ source: String) -> String? {
        return MorphAppleScriptRunner.run(source, timeout: 3.0)
    }
}

// MARK: - Form Field Filter Mode
public enum FormFieldFilterMode: String, CaseIterable, Equatable, Sendable {
    case requiredOnly = "Required"
    case all = "All"
}

// MARK: - Thread-Safe Browser AXObserver Box
private struct UncheckedSendableRunLoopSource: @unchecked Sendable {
    let source: CFRunLoopSource
}

private final class BrowserAXObserverBox: @unchecked Sendable {
    private let lock = NSLock()
    private var observer: AXObserver?
    private var observedPID: pid_t = 0
    private var observedElement: AXUIElement?
    private var observedNotifications: [CFString] = []
    private var onEvent: (@Sendable () -> Void)?
    
    deinit {
        detach()
    }
    
    func currentPID() -> pid_t {
        lock.lock()
        let pid = observedPID
        lock.unlock()
        return pid
    }
    
    func attach(pid: pid_t, onEvent: @escaping @Sendable () -> Void) {
        guard pid > 0, AXIsProcessTrusted() else { return }
        lock.lock()
        if observedPID == pid, observer != nil {
            self.onEvent = onEvent
            lock.unlock()
            return
        }
        lock.unlock()
        
        detach()
        
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon = refcon else { return }
            let box = Unmanaged<BrowserAXObserverBox>.fromOpaque(refcon).takeUnretainedValue()
            box.handleCallback()
        }
        
        var createdObserver: AXObserver?
        guard AXObserverCreate(pid, callback, &createdObserver) == .success,
              let obs = createdObserver else {
            return
        }
        
        let appElem = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let notifications: [CFString] = [
            kAXTitleChangedNotification as CFString,
            kAXFocusedWindowChangedNotification as CFString,
            kAXMainWindowChangedNotification as CFString,
            kAXFocusedUIElementChangedNotification as CFString
        ]
        
        var added: [CFString] = []
        for notif in notifications {
            if AXObserverAddNotification(obs, appElem, notif, refcon) == .success {
                added.append(notif)
            }
        }
        guard !added.isEmpty else { return }
        
        let wrappedSource = UncheckedSendableRunLoopSource(source: AXObserverGetRunLoopSource(obs))
        lock.lock()
        self.observer = obs
        self.observedPID = pid
        self.observedElement = appElem
        self.observedNotifications = added
        self.onEvent = onEvent
        lock.unlock()
        
        if Thread.isMainThread {
            CFRunLoopAddSource(CFRunLoopGetMain(), wrappedSource.source, .commonModes)
        } else {
            DispatchQueue.main.async {
                CFRunLoopAddSource(CFRunLoopGetMain(), wrappedSource.source, .commonModes)
            }
        }
    }
    
    func detach() {
        lock.lock()
        let obs = self.observer
        let elem = self.observedElement
        let notifs = self.observedNotifications
        self.observer = nil
        self.observedPID = 0
        self.observedElement = nil
        self.observedNotifications = []
        self.onEvent = nil
        lock.unlock()
        
        guard let obs = obs else { return }
        if let elem = elem {
            for notif in notifs {
                AXObserverRemoveNotification(obs, elem, notif)
            }
        }
        let wrappedSource = UncheckedSendableRunLoopSource(source: AXObserverGetRunLoopSource(obs))
        if Thread.isMainThread {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), wrappedSource.source, .commonModes)
        } else {
            DispatchQueue.main.async {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), wrappedSource.source, .commonModes)
            }
        }
    }
    
    private func handleCallback() {
        lock.lock()
        let handler = onEvent
        lock.unlock()
        handler?()
    }
}

// MARK: - Form Row Display State & Browser Injection Reporting
public enum FormRowRightDisplay: Equatable, Sendable {
    case userInput(String)
    case autofillSuggestion(String)
    case empty
}

public struct BrowserInjectionResult: Equatable, Sendable {
    public let injectedCount: Int
    public let injectedLabels: Set<String>
    public let errorMessage: String?

    public init(injectedCount: Int, injectedLabels: Set<String>, errorMessage: String? = nil) {
        self.injectedCount = injectedCount
        self.injectedLabels = injectedLabels
        self.errorMessage = errorMessage
    }
}

// MARK: - Main ApplicationFormModel
@MainActor
public final class ApplicationFormModel: ObservableObject {
    @Published public var activeSession: ApplicationFormSession?
    @Published public var suspendedSession: ApplicationFormSession?
    @Published public var isFormDetected: Bool = false
    @Published public var isJustDetected: Bool = false
    @Published public var detectedFormTitle: String = ""
    @Published public var detectedAppName: String = ""
    @Published public var detectedURL: String? = nil
    @Published public var detectedBrowserFamily: BrowserEngineFamily = .unknown
    @Published public var detectedScreenIndex: Int? = nil
    @Published public var detectedScreenName: String? = nil
    @Published public var userDefaultBrowser: UserBrowserProfile
    @Published public var isTracking: Bool = false
    @Published public var isAutoCaptureEnabled: Bool = true
    public var isFormFeatureEnabled: Bool = true
    public static let defaultRecipientEmail = "aaronn.nguyen.work@gmail.com"
    @Published public var recipientEmail: String = defaultRecipientEmail
    @Published public var deliveryToastMessage: String? = nil
    @Published public var historySessions: [ApplicationFormSession] = [] {
        didSet {
            guard !isBootstrapping else { return }
            rebuildAdaptiveProfile()
        }
    }
    @Published public var savedFormCopies: [SavedFormCopyRecord] = [] {
        didSet {
            guard !isBootstrapping else { return }
            rebuildAdaptiveProfile()
        }
    }
    @Published public var profileAnswers: [String: String] = [:] {
        didSet {
            guard !isBootstrapping else { return }
            rebuildAdaptiveProfile()
        }
    }
    @Published public var adaptiveProfileEntries: [AdaptiveProfileEntry] = []
    @Published public var adaptiveSourceCount: Int = 0
    @Published public var dismissedAdaptiveProfileKeys: Set<String> = [] {
        didSet {
            guard !isBootstrapping else { return }
            rebuildAdaptiveProfile()
        }
    }
    public private(set) var lastInjectionError: String? = nil
    public var testBrowserInjectionOverride: (([String: String]) -> BrowserInjectionResult)? = nil
    
    private static let savedFormCopiesStorageKey = "com.morph.form.saved_copies"
    private static let profileAnswersStorageKey = "com.morph.form.profile_answers"
    private static let dismissedAdaptiveProfileKeysStorageKey = "com.morph.form.dismissed_adaptive_keys"
    @Published public var activeFieldIndex: Int = 0
    @Published public var isAutoRetrievingSchema: Bool = false
    @Published public var lastAutoCapturedAt: Date? = nil
    @Published public var lastKeystrokeAt: Date? = nil
    @Published public var filterMode: FormFieldFilterMode = .requiredOnly
    @Published public var consecutiveMissedDetections: Int = 0
    @Published public var isClosedOrExpired: Bool = false
    @Published public var closedReason: String? = nil
    
    /// IDs of fields whose current value was read from the browser. Only these may be cleared
    /// automatically when the user empties the answer in the browser, so answers typed manually
    /// into Morph are never wiped by a background scan.
    public private(set) var browserCapturedFieldIDs: Set<UUID> = []
    public private(set) var manuallyEditedFieldIDs: Set<UUID> = []
    /// Minimum quiet period after a keystroke before an empty browser read may clear a field.
    public static let clearGuardInterval: TimeInterval = 0.35
    
    public var visibleFields: [FormInputField] {
        guard let session = activeSession else { return [] }
        let actionable = session.fields.filter { $0.isActionableQuestion }
        if filterMode == .requiredOnly && session.hasRequiredFields {
            return session.requiredFields
        }
        return actionable
    }
    
    public func setFilterMode(_ mode: FormFieldFilterMode) {
        self.filterMode = mode
        self.advanceToFirstUnansweredFieldIfNeeded()
    }
    
    public func toggleFilterMode() {
        self.filterMode = (self.filterMode == .requiredOnly) ? .all : .requiredOnly
        self.advanceToFirstUnansweredFieldIfNeeded()
    }
    
    public var detector: ApplicationFormDetectorProtocol
    public var dispatcher: ApplicationEmailDispatcherProtocol
    public var autoTracker: FormInputAutoTracker?
    public var onSessionExported: ((ApplicationFormSession) -> Void)?
    public var onFormClosed: (() -> Void)?
    
    private var isBootstrapping: Bool = true
    private var toastDismissTask: Task<Void, Never>?
    private var justDetectedResetTask: Task<Void, Never>?
    private var pollTimer: AnyCancellable?
    private var workspaceNotificationObserver: NSObjectProtocol?
    private var workspaceLaunchObserver: NSObjectProtocol?
    private var workspaceUnhideObserver: NSObjectProtocol?
    private var receiptsCancellable: AnyCancellable?
    private var isAppleScriptSyncRunning: Bool = false
    private var hasPendingUrgentLiveSync: Bool = false
    private var awaitingReopenSnapshotClear: Bool = false
    var ignoredBlinkSignatureByFormID: [String: String] = [:]
    var lastObservedBlinkSignatureByFormID: [String: String] = [:]
    var strictBlinkWindowByFormID: Set<String> = []
    var pendingBlinkBaselineCapture: Set<String> = []
    private let axObserverBox = BrowserAXObserverBox()
    private var axObserverDebounceTask: Task<Void, Never>?
    private var isBackgroundDetectionInFlight: Bool = false
    private var hasPendingBackgroundDetection: Bool = false
    private var retrievalGeneration: UInt64 = 0
    private var activeRetrievalTask: Task<Void, Never>?
    private var activeRetrievalURL: String? = nil
    
    nonisolated deinit {
        axObserverBox.detach()
    }
    
    public init(
        detector: ApplicationFormDetectorProtocol? = nil,
        dispatcher: ApplicationEmailDispatcherProtocol? = nil,
        userDefaultBrowser: UserBrowserProfile? = nil
    ) {
        self.detector = detector ?? DefaultApplicationFormDetector()
        self.dispatcher = dispatcher ?? DefaultEmailDispatcher()
        self.userDefaultBrowser = userDefaultBrowser ?? PersonalizedBrowserDetector.detectDefaultBrowser()
        
        loadSavedFormCopies()
        loadDismissedAdaptiveProfileKeys()
        loadProfileAnswers()
        
        if !MorphEnvironment.isTestingEnvironment {
            loadDrafts()
            self.autoTracker = FormInputAutoTracker(model: self)
            self.autoTracker?.start()
            startPolling()
        }
        self.isBootstrapping = false
        rebuildAdaptiveProfile()
        
        receiptsCancellable = SupabaseService.shared.$formReceipts
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.rebuildAdaptiveProfile()
                }
            }
    }
    
    // MARK: - Saved Copies, Deletion & Adaptive Profile Persistence
    public func loadSavedFormCopies() {
        if let data = UserDefaults.standard.data(forKey: Self.savedFormCopiesStorageKey),
           let list = try? JSONDecoder().decode([SavedFormCopyRecord].self, from: data) {
            self.savedFormCopies = list
        }
    }
    
    public func saveSavedFormCopies() {
        if let data = try? JSONEncoder().encode(savedFormCopies) {
            UserDefaults.standard.set(data, forKey: Self.savedFormCopiesStorageKey)
        }
    }
    
    public func loadProfileAnswers() {
        if let data = UserDefaults.standard.data(forKey: Self.profileAnswersStorageKey),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            let isLegacyDummySeed =
                dict["Full Name"] == "John Chen" &&
                dict["Email Address"] == "jchen.debate@tabroom.org" &&
                dict["Institutional Conflicts"] == "St. Marks School of Texas" &&
                dict.count <= 6
            if !isLegacyDummySeed {
                self.profileAnswers = dict
            }
        }
    }
    
    public func saveProfileAnswers() {
        if let data = try? JSONEncoder().encode(profileAnswers) {
            UserDefaults.standard.set(data, forKey: Self.profileAnswersStorageKey)
        }
    }
    
    public func loadDismissedAdaptiveProfileKeys() {
        if let arr = UserDefaults.standard.stringArray(forKey: Self.dismissedAdaptiveProfileKeysStorageKey) {
            self.dismissedAdaptiveProfileKeys = Set(arr)
        }
    }
    
    public func saveDismissedAdaptiveProfileKeys() {
        UserDefaults.standard.set(Array(dismissedAdaptiveProfileKeys).sorted(), forKey: Self.dismissedAdaptiveProfileKeysStorageKey)
    }
    
    public func saveProfileAnswer(key: String, value: String, canonicalKey: String? = nil) {
        let trimmedKey = Self.cleanQuestionTitle(key)
        let targetKey = trimmedKey.isEmpty ? key : trimmedKey
        guard !targetKey.isEmpty else { return }
        let concept = canonicalKey ?? Self.semanticConceptKey(for: targetKey).key
        let normTarget = Self.normalizeFieldLabel(targetKey)
        if dismissedAdaptiveProfileKeys.contains(concept) || dismissedAdaptiveProfileKeys.contains(normTarget) {
            dismissedAdaptiveProfileKeys.remove(concept)
            dismissedAdaptiveProfileKeys.remove(normTarget)
            saveDismissedAdaptiveProfileKeys()
        }
        let staleKeys = profileAnswers.keys.filter { existingKey in
            if existingKey == targetKey { return false }
            let cleanExisting = Self.cleanQuestionTitle(existingKey)
            if Self.normalizeFieldLabel(cleanExisting) == normTarget { return true }
            if !concept.hasPrefix("topic:") && !Self.hasQualifierConflict(existingKey, targetKey) {
                return Self.semanticConceptKey(for: cleanExisting).key == concept
            }
            return false
        }
        for stale in staleKeys {
            self.profileAnswers.removeValue(forKey: stale)
        }
        self.profileAnswers[targetKey] = value
        saveProfileAnswers()
        rebuildAdaptiveProfile()
    }
    
    @discardableResult
    public func addCustomProfileEntry(question: String, answer: String) -> AdaptiveProfileEntry? {
        let cleanQ = Self.cleanQuestionTitle(question)
        guard !cleanQ.isEmpty else { return nil }
        let concept = Self.semanticConceptKey(for: cleanQ).key
        let normQ = Self.normalizeFieldLabel(cleanQ)
        if dismissedAdaptiveProfileKeys.remove(concept) != nil || dismissedAdaptiveProfileKeys.remove(normQ) != nil {
            saveDismissedAdaptiveProfileKeys()
        }
        self.profileAnswers[cleanQ] = answer
        saveProfileAnswers()
        rebuildAdaptiveProfile()
        return adaptiveProfileEntries.first(where: {
            $0.canonicalKey == concept || Self.normalizeFieldLabel($0.question) == normQ
        })
    }
    
    public func deleteAdaptiveProfileEntry(id: String) {
        guard let target = adaptiveProfileEntries.first(where: { $0.id == id }) else { return }
        dismissedAdaptiveProfileKeys.insert(target.canonicalKey)
        dismissedAdaptiveProfileKeys.insert(Self.normalizeFieldLabel(target.question))
        for alias in target.aliases {
            dismissedAdaptiveProfileKeys.insert(Self.normalizeFieldLabel(alias))
        }
        saveDismissedAdaptiveProfileKeys()
        
        let aliasNorms = Set(([target.question] + target.aliases).map { Self.normalizeFieldLabel($0) })
        let keysToRemove = profileAnswers.keys.filter { k in
            let normK = Self.normalizeFieldLabel(k)
            return aliasNorms.contains(normK) || Self.semanticConceptKey(for: k).key == target.canonicalKey
        }
        for k in keysToRemove {
            profileAnswers.removeValue(forKey: k)
        }
        saveProfileAnswers()
        rebuildAdaptiveProfile()
        showToast("Removed \"\(target.question)\" from Adaptive Profile")
    }
    
    @discardableResult
    public func saveFormSnapshot(flashLabel: Bool = false) -> SavedFormCopyRecord? {
        guard let session = activeSession else { return nil }
        var ans: [String: String] = [:]
        for f in session.fields where f.isActionableQuestion {
            let resolved = f.value.isEmpty ? (profileAnswers[f.label] ?? "") : f.value
            ans[f.label] = resolved
            if !resolved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let concept = Self.semanticConceptKey(for: f.label).key
                let clearedKeys = profileAnswers.keys.filter { k in
                    let v = profileAnswers[k]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard v.isEmpty else { return false }
                    return Self.normalizeFieldLabel(k) == Self.normalizeFieldLabel(f.label) ||
                        (!Self.hasQualifierConflict(k, f.label) && Self.semanticConceptKey(for: k).key == concept)
                }
                if !clearedKeys.isEmpty {
                    for ck in clearedKeys { profileAnswers.removeValue(forKey: ck) }
                    saveProfileAnswers()
                }
            }
        }
        
        let rec = SavedFormCopyRecord(
            id: UUID().uuidString,
            sessionId: session.id.uuidString,
            formTitle: session.formTitle.isEmpty ? "Google Form" : session.formTitle,
            savedAt: Date(),
            answers: ans,
            sourceURL: session.sourceURL,
            sourceAppName: session.sourceAppName
        )
        savedFormCopies.insert(rec, at: 0)
        saveSavedFormCopies()
        rebuildAdaptiveProfile()
        
        // Save to Supabase memory store locally immediately
        let memory = GlassMemoryItem(
            id: rec.id,
            userId: SupabaseService.shared.currentUser.id,
            kind: "form",
            title: rec.formTitle,
            body: session.formattedSummary,
            metaJSON: rec.answersJSONString,
            createdAt: rec.savedAt,
            updatedAt: rec.savedAt,
            syncStatus: "local"
        )
        if let idx = SupabaseService.shared.memoryItems.firstIndex(where: { $0.id == memory.id }) {
            SupabaseService.shared.memoryItems[idx] = memory
        } else {
            SupabaseService.shared.memoryItems.insert(memory, at: 0)
        }
        SupabaseService.shared.saveMemoryItemsCache()
        Task {
            await SupabaseService.shared.saveMemoryItem(memory)
        }
        
        // Also sync to form_receipts
        syncToSupabase()
        
        if flashLabel {
            showToast("Saved form copy to Memory!")
        }
        return rec
    }
    
    private static func answersOverlapCleanly(_ a: [String: String], _ b: [String: String]) -> Bool {
        let nonEmptyA = a.reduce(into: [String: String]()) { res, kv in
            let v = kv.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { res[normalizeFieldLabel(cleanQuestionTitle(kv.key))] = v }
        }
        let nonEmptyB = b.reduce(into: [String: String]()) { res, kv in
            let v = kv.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { res[normalizeFieldLabel(cleanQuestionTitle(kv.key))] = v }
        }
        guard !nonEmptyA.isEmpty && !nonEmptyB.isEmpty else { return false }
        var shared = 0
        for (k, va) in nonEmptyA {
            if let vb = nonEmptyB[k], vb.caseInsensitiveCompare(va) == .orderedSame {
                shared += 1
            } else if nonEmptyB[k] != nil {
                return false
            }
        }
        return shared == min(nonEmptyA.count, nonEmptyB.count) && shared >= 1
    }
    
    public func deleteSavedFormCopy(id: String) {
        let removedCopy = savedFormCopies.first(where: { $0.id == id })
        savedFormCopies.removeAll(where: { $0.id == id })
        saveSavedFormCopies()
        
        SupabaseService.shared.removeMemoryItemLocally(id: id)
        Task {
            await SupabaseService.shared.deleteMemoryItem(id: id)
        }
        
        var matchingReceiptIDs: [String] = []
        if SupabaseService.shared.formReceipts.contains(where: { $0.id == id }) {
            matchingReceiptIDs.append(id)
        }
        if let linkedSid = removedCopy?.sessionId,
           SupabaseService.shared.formReceipts.contains(where: { $0.id == linkedSid }),
           !matchingReceiptIDs.contains(linkedSid) {
            matchingReceiptIDs.append(linkedSid)
        }
        if let removed = removedCopy {
            let removedFormID = removed.sourceURL.flatMap { DefaultApplicationFormDetector.extractFormIdentifier(from: $0) }
            for receipt in SupabaseService.shared.formReceipts where !matchingReceiptIDs.contains(receipt.id) {
                let sameTitle = receipt.formTitle.caseInsensitiveCompare(removed.formTitle) == .orderedSame
                let receiptFormID = receipt.sourceURL.flatMap { DefaultApplicationFormDetector.extractFormIdentifier(from: $0) }
                let sameURL = (removed.sourceURL != nil && receipt.sourceURL == removed.sourceURL) ||
                              (removedFormID != nil && receiptFormID == removedFormID)
                let closeInTime = abs(receipt.createdAt.timeIntervalSince(removed.savedAt)) < 120.0
                let receiptAnswers = Dictionary(receipt.fields.filter { $0.isActionableQuestion }.map { ($0.label, $0.value) }, uniquingKeysWith: { first, _ in first })
                let sameAnswers = Self.answersOverlapCleanly(removed.answers, receiptAnswers)
                if (sameURL || sameTitle) && (closeInTime || sameAnswers) {
                    matchingReceiptIDs.append(receipt.id)
                }
            }
        }
        for rid in matchingReceiptIDs {
            SupabaseService.shared.removeFormReceiptLocally(id: rid)
            Task {
                await SupabaseService.shared.deleteFormReceipt(id: rid)
            }
        }
        
        var removedHistory = false
        let prevHistCount = historySessions.count
        historySessions.removeAll { hist in
            let sid = hist.id.uuidString
            if sid == id || (removedCopy?.sessionId == sid) || matchingReceiptIDs.contains(sid) {
                return true
            }
            if let removed = removedCopy {
                let sameTitle = hist.formTitle.caseInsensitiveCompare(removed.formTitle) == .orderedSame
                let sameURL = DefaultApplicationFormDetector.isSameForm(titleA: hist.formTitle, urlA: hist.sourceURL, titleB: removed.formTitle, urlB: removed.sourceURL)
                let histAnswers = Dictionary(hist.fields.filter { $0.isActionableQuestion }.map { ($0.label, $0.value) }, uniquingKeysWith: { first, _ in first })
                if (sameTitle || sameURL) && Self.answersOverlapCleanly(removed.answers, histAnswers) {
                    return true
                }
            }
            return false
        }
        if historySessions.count != prevHistCount {
            removedHistory = true
        }
        if let susp = suspendedSession {
            let sID = susp.id.uuidString
            if sID == id || removedCopy?.sessionId == sID || matchingReceiptIDs.contains(sID) {
                suspendedSession = nil
                removedHistory = true
            }
        }
        if removedHistory {
            saveDrafts(syncCloud: false)
        }
        
        if let ctrl = MorphController.shared, ctrl.model.selectedFormCopyId == id {
            ctrl.model.selectedFormCopyId = nil
            ctrl.model.isFormCopyDetailOpen = false
        }
        
        rebuildAdaptiveProfile()
        showToast("Deleted saved form copy")
    }
    
    public func deleteFormReceipt(id: String) {
        let removedReceipt = SupabaseService.shared.formReceipts.first(where: { $0.id == id })
        SupabaseService.shared.removeFormReceiptLocally(id: id)
        Task {
            await SupabaseService.shared.deleteFormReceipt(id: id)
        }
        if savedFormCopies.contains(where: { $0.id == id || $0.sessionId == id }) {
            savedFormCopies.removeAll(where: { $0.id == id || $0.sessionId == id })
            saveSavedFormCopies()
        }
        SupabaseService.shared.removeMemoryItemLocally(id: id)
        Task {
            await SupabaseService.shared.deleteMemoryItem(id: id)
        }
        let receiptAnswers: [String: String] = Dictionary(
            (removedReceipt?.fields ?? []).filter { $0.isActionableQuestion }.map { ($0.label, $0.value) },
            uniquingKeysWith: { first, _ in first }
        )
        let prevHistCount = historySessions.count
        historySessions.removeAll { hist in
            if hist.id.uuidString == id { return true }
            if let rr = removedReceipt {
                let sameTitle = hist.formTitle.caseInsensitiveCompare(rr.formTitle) == .orderedSame
                let sameURL = DefaultApplicationFormDetector.isSameForm(titleA: hist.formTitle, urlA: hist.sourceURL, titleB: rr.formTitle, urlB: rr.sourceURL)
                let histAnswers = Dictionary(hist.fields.filter { $0.isActionableQuestion }.map { ($0.label, $0.value) }, uniquingKeysWith: { first, _ in first })
                if (sameTitle || sameURL) && Self.answersOverlapCleanly(receiptAnswers, histAnswers) {
                    return true
                }
            }
            return false
        }
        var draftsChanged = (historySessions.count != prevHistCount)
        if suspendedSession?.id.uuidString == id {
            suspendedSession = nil
            draftsChanged = true
        }
        if draftsChanged {
            saveDrafts(syncCloud: false)
        }
        if let ctrl = MorphController.shared, ctrl.model.selectedFormCopyId == id {
            ctrl.model.selectedFormCopyId = nil
            ctrl.model.isFormCopyDetailOpen = false
        }
        rebuildAdaptiveProfile()
        showToast("Deleted form receipt")
    }
    
    public func markFormSubmitted() {
        guard var session = activeSession else { return }
        session.isSubmitted = true
        activeSession = session
        recordBlinkSuppressionBaseline(for: session.sourceURL)
        _ = saveFormSnapshot(flashLabel: false)
        showToast("Form submitted · Copy saved in Island")
    }
    
    // MARK: - Domain-Agnostic Semantic Clustering & Adaptive Profile
    
    nonisolated private static let relationQualifiers: Set<String> = [
        "parent", "parents", "guardian", "guardians", "emergency",
        "reference", "references", "referee", "referees",
        "supervisor", "supervisors", "manager", "managers",
        "advisor", "advisors", "mentor", "mentors",
        "spouse", "spouses", "partner", "partners",
        "mother", "father", "mom", "dad",
        "child", "children", "sibling", "siblings",
        "doctor", "doctors", "physician", "physicians",
        "recommender", "recommenders"
    ]
    
    nonisolated private static let entityPartQualifiers: Set<String> = [
        "first", "last", "middle", "given", "family", "surname",
        "nick", "nickname", "nicknames", "user", "username", "usernames",
        "handle", "handles",
        "company", "companies", "organization", "organizations", "org", "orgs",
        "school", "schools", "university", "universities",
        "college", "colleges", "institution", "institutions",
        "team", "teams", "project", "projects", "event", "events",
        "product", "products", "course", "courses"
    ]
    
    nonisolated private static let nonPersonNameQualifiers: Set<String> = relationQualifiers
        .union(entityPartQualifiers)
        .union(["file", "tab", "judge", "judges", "host", "safety", "officer", "officers"])
    
    nonisolated private static let labelStopWords: Set<String> = [
        "the", "a", "an", "of", "for", "to", "in", "on", "at",
        "your", "you", "do", "did", "are", "is", "was", "were",
        "what", "which", "who", "how", "please", "enter", "provide",
        "list", "any", "if", "with", "and", "or", "from", "by", "have", "has"
    ]
    
    nonisolated public static func hasQualifierConflict(_ a: String, _ b: String) -> Bool {
        let tokensA = Set(normalizeFieldLabel(a).components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
        let tokensB = Set(normalizeFieldLabel(b).components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
        guard !tokensA.isEmpty && !tokensB.isEmpty else { return false }
        
        let relA = tokensA.intersection(relationQualifiers)
        let relB = tokensB.intersection(relationQualifiers)
        if relA != relB {
            return true
        }
        
        let partA = tokensA.intersection(entityPartQualifiers)
        let partB = tokensB.intersection(entityPartQualifiers)
        if partA != partB {
            let structuredNouns: Set<String> = ["name", "address", "number", "phone", "id"]
            if !tokensA.intersection(structuredNouns).isEmpty || !tokensB.intersection(structuredNouns).isEmpty {
                return true
            }
        }
        return false
    }
    
    nonisolated public static func semanticConceptKey(for label: String) -> (key: String, displayLabel: String) {
        let clean = cleanQuestionTitle(label)
        let norm = normalizeFieldLabel(clean)
        let rawTokens = norm.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        let tokenSet = Set(rawTokens)
        let sigTokens = rawTokens.filter { !labelStopWords.contains($0) && $0.count >= 2 }
        let sortedSig = Array(Set(sigTokens)).sorted()
        let topicKey = "topic:" + (sortedSig.isEmpty ? norm.replacingOccurrences(of: " ", with: "_") : sortedSig.joined(separator: "_"))
        
        // Relation-qualified fields stay isolated from applicant's own personal concepts
        if !tokenSet.intersection(relationQualifiers).isEmpty {
            return (topicKey, clean)
        }
        
        // Structured name concepts
        if tokenSet.contains("name") || tokenSet.contains("surname") || tokenSet.contains("nickname") {
            if tokenSet.contains("first") || (tokenSet.contains("given") && tokenSet.contains("name")) {
                return ("concept:first_name", "First Name")
            }
            if tokenSet.contains("last") || tokenSet.contains("surname") || (tokenSet.contains("family") && tokenSet.contains("name")) {
                return ("concept:last_name", "Last Name")
            }
            if tokenSet.contains("middle") {
                return ("concept:middle_name", "Middle Name")
            }
            if tokenSet.contains("preferred") || tokenSet.contains("nick") || tokenSet.contains("nickname") {
                return ("concept:preferred_name", "Preferred Name")
            }
            if tokenSet.intersection(nonPersonNameQualifiers).isEmpty {
                return ("concept:full_name", "Full Name")
            }
        }
        
        // Universal contact & identity concepts
        if tokenSet.contains("email") || (tokenSet.contains("e") && tokenSet.contains("mail")) {
            return ("concept:email", "Email Address")
        }
        if tokenSet.contains("phone") || tokenSet.contains("telephone") || tokenSet.contains("mobile") || (tokenSet.contains("cell") && !tokenSet.contains("biology")) {
            return ("concept:phone", "Phone Number")
        }
        if tokenSet.contains("linkedin") {
            return ("concept:linkedin", "LinkedIn")
        }
        if tokenSet.contains("github") {
            return ("concept:github", "GitHub")
        }
        if tokenSet.contains("portfolio") || tokenSet.contains("website") || norm.contains("personal site") {
            return ("concept:website", "Website / Portfolio")
        }
        if tokenSet.contains("pronouns") || tokenSet.contains("pronoun") {
            return ("concept:pronouns", "Pronouns")
        }
        if (tokenSet.contains("university") || tokenSet.contains("college") || tokenSet.contains("school") ||
            tokenSet.contains("institution") || tokenSet.contains("company") || tokenSet.contains("organization") ||
            tokenSet.contains("affiliation") || tokenSet.contains("employer")) &&
            !tokenSet.contains("conflict") && !tokenSet.contains("conflicts") &&
            !tokenSet.contains("year") && !tokenSet.contains("graduation") && !tokenSet.contains("grad") {
            return ("concept:organization", "Organization / School")
        }
        if tokenSet.contains("major") || (tokenSet.contains("field") && tokenSet.contains("study")) || tokenSet.contains("degree") {
            return ("concept:major", "Major / Degree")
        }
        if (tokenSet.contains("graduation") || tokenSet.contains("grad") || tokenSet.contains("class")) && tokenSet.contains("year") {
            return ("concept:graduation_year", "Graduation Year")
        }
        if tokenSet.contains("address") || tokenSet.contains("street") || tokenSet.contains("mailing") || tokenSet.contains("postal") || tokenSet.contains("zip") {
            return ("concept:address", "Address")
        }
        if tokenSet.contains("city") || tokenSet.contains("location") || tokenSet.contains("hometown") {
            return ("concept:location", "City / Location")
        }
        if tokenSet.contains("availability") || tokenSet.contains("available") || tokenSet.contains("schedule") {
            return ("concept:availability", "Availability")
        }
        if tokenSet.contains("dietary") || tokenSet.contains("allergies") || tokenSet.contains("allergy") {
            return ("concept:dietary", "Dietary Restrictions")
        }
        if tokenSet.contains("bio") || norm.contains("about you") || norm.contains("about yourself") || norm.contains("statement of purpose") {
            return ("concept:bio", "Bio / Statement")
        }
        
        return (topicKey, clean)
    }
    
    public func rebuildAdaptiveProfile() {
        struct ConceptAcc {
            var canonicalKey: String
            var displayLabel: String
            var aliasCounts: [String: Int] = [:]
            var answer: String = ""
            var answerUpdatedAt: Date = .distantPast
            var lastSeenAt: Date = .distantPast
            var frequency: Int = 0
            var isUserEdited: Bool = false
            var isCustom: Bool = false
        }
        
        var docs: [(id: String, title: String, url: String?, date: Date, pairs: [(String, String)])] = []
        var seenDocFingerprints = Set<String>()
        
        func docFingerprint(title: String, url: String?, answersCount: Int) -> String {
            let normTitle = Self.normalizeFieldLabel(title)
            let formID = url.flatMap { DefaultApplicationFormDetector.extractFormIdentifier(from: $0) } ?? ""
            return "\(normTitle)|\(formID)|\(answersCount)"
        }
        
        for copy in savedFormCopies {
            let pairs = copy.answers.map { ($0.key, $0.value) }
            docs.append((id: copy.id, title: copy.formTitle, url: copy.sourceURL, date: copy.savedAt, pairs: pairs))
            seenDocFingerprints.insert(docFingerprint(title: copy.formTitle, url: copy.sourceURL, answersCount: pairs.count))
        }
        
        for receipt in SupabaseService.shared.formReceipts {
            if savedFormCopies.contains(where: { $0.id == receipt.id || $0.sessionId == receipt.id }) { continue }
            let pairs = receipt.fields.filter { $0.isActionableQuestion }.map { ($0.label, $0.value) }
            let fp = docFingerprint(title: receipt.formTitle, url: receipt.sourceURL, answersCount: pairs.count)
            let isDupByCopy = savedFormCopies.contains { copy in
                let sameTitle = copy.formTitle.caseInsensitiveCompare(receipt.formTitle) == .orderedSame
                let sameURL = copy.sourceURL != nil && receipt.sourceURL != nil &&
                    DefaultApplicationFormDetector.extractFormIdentifier(from: copy.sourceURL!) == DefaultApplicationFormDetector.extractFormIdentifier(from: receipt.sourceURL!)
                return (sameTitle || sameURL) && abs(copy.savedAt.timeIntervalSince(receipt.createdAt)) < 120.0
            }
            if isDupByCopy || (pairs.count > 0 && seenDocFingerprints.contains(fp) && receipt.submittedAt == nil) {
                continue
            }
            seenDocFingerprints.insert(fp)
            docs.append((id: receipt.id, title: receipt.formTitle, url: receipt.sourceURL, date: receipt.submittedAt ?? receipt.createdAt, pairs: pairs))
        }
        
        for hist in historySessions {
            if savedFormCopies.contains(where: { $0.id == hist.id.uuidString || $0.sessionId == hist.id.uuidString }) { continue }
            let pairs = hist.fields.filter { $0.isActionableQuestion }.map { ($0.label, $0.value) }
            guard !pairs.isEmpty else { continue }
            let isDup = docs.contains { doc in
                doc.id == hist.id.uuidString ||
                (doc.title.caseInsensitiveCompare(hist.formTitle) == .orderedSame && abs(doc.date.timeIntervalSince(hist.completedAt ?? hist.startedAt)) < 120.0)
            }
            if isDup { continue }
            docs.append((id: hist.id.uuidString, title: hist.formTitle, url: hist.sourceURL, date: hist.completedAt ?? hist.startedAt, pairs: pairs))
        }
        
        var clusters: [String: ConceptAcc] = [:]
        var clusterOrder: [String] = []
        
        func topicTokens(_ s: String) -> Set<String> {
            let norm = Self.normalizeFieldLabel(Self.cleanQuestionTitle(s))
            return Set(norm.components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 2 && !Self.labelStopWords.contains($0) })
        }
        
        func matchingClusterKey(for label: String, conceptKey: String) -> String {
            if clusters[conceptKey] != nil {
                return conceptKey
            }
            if conceptKey.hasPrefix("topic:") {
                let targetNorm = Self.normalizeFieldLabel(Self.cleanQuestionTitle(label))
                let targetToks = topicTokens(label)
                for key in clusterOrder where key.hasPrefix("topic:") {
                    guard let existing = clusters[key] else { continue }
                    let existingLabels = [existing.displayLabel] + Array(existing.aliasCounts.keys)
                    for exLbl in existingLabels {
                        if Self.hasQualifierConflict(exLbl, label) { continue }
                        let exNorm = Self.normalizeFieldLabel(Self.cleanQuestionTitle(exLbl))
                        if !exNorm.isEmpty && exNorm == targetNorm {
                            return key
                        }
                        let exToks = topicTokens(exLbl)
                        let unionCount = targetToks.union(exToks).count
                        if unionCount > 0 {
                            let jaccard = Double(targetToks.intersection(exToks).count) / Double(unionCount)
                            if jaccard >= 0.75 {
                                return key
                            }
                        }
                    }
                }
            }
            return conceptKey
        }
        
        for doc in docs {
            var seenInDoc = Set<String>()
            for (rawLabel, rawValue) in doc.pairs {
                let cleanLbl = Self.cleanQuestionTitle(rawLabel)
                guard !cleanLbl.isEmpty else { continue }
                let (initialKey, suggestedDisplay) = Self.semanticConceptKey(for: cleanLbl)
                let clusterKey = matchingClusterKey(for: cleanLbl, conceptKey: initialKey)
                
                var acc = clusters[clusterKey] ?? ConceptAcc(canonicalKey: clusterKey, displayLabel: suggestedDisplay)
                acc.aliasCounts[cleanLbl, default: 0] += 1
                if !seenInDoc.contains(clusterKey) {
                    acc.frequency += 1
                    seenInDoc.insert(clusterKey)
                }
                let trimmedVal = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedVal.isEmpty && doc.date >= acc.answerUpdatedAt {
                    acc.answer = trimmedVal
                    acc.answerUpdatedAt = doc.date
                }
                if doc.date > acc.lastSeenAt {
                    acc.lastSeenAt = doc.date
                }
                if clusters[clusterKey] == nil {
                    clusterOrder.append(clusterKey)
                }
                clusters[clusterKey] = acc
            }
        }
        
        for (rawKey, rawVal) in profileAnswers {
            let cleanKey = Self.cleanQuestionTitle(rawKey)
            guard !cleanKey.isEmpty else { continue }
            let (initialKey, suggestedDisplay) = Self.semanticConceptKey(for: cleanKey)
            let clusterKey = matchingClusterKey(for: cleanKey, conceptKey: initialKey)
            
            if var existing = clusters[clusterKey] {
                existing.aliasCounts[cleanKey, default: 0] += 1
                existing.answer = rawVal
                existing.isUserEdited = true
                clusters[clusterKey] = existing
            } else {
                var acc = ConceptAcc(canonicalKey: clusterKey, displayLabel: suggestedDisplay)
                acc.aliasCounts[cleanKey] = 1
                acc.answer = rawVal
                acc.frequency = 1
                acc.lastSeenAt = Date()
                acc.isUserEdited = true
                acc.isCustom = true
                clusterOrder.append(clusterKey)
                clusters[clusterKey] = acc
            }
        }
        
        var built: [AdaptiveProfileEntry] = []
        for key in clusterOrder {
            guard let acc = clusters[key] else { continue }
            let aliases = acc.aliasCounts.keys.sorted {
                let c0 = acc.aliasCounts[$0, default: 0]
                let c1 = acc.aliasCounts[$1, default: 0]
                if c0 != c1 { return c0 > c1 }
                return $0.count < $1.count
            }
            let chosenQuestion = acc.displayLabel.isEmpty ? (aliases.first ?? acc.canonicalKey) : acc.displayLabel
            let normChosen = Self.normalizeFieldLabel(chosenQuestion)
            let isDismissed = dismissedAdaptiveProfileKeys.contains(acc.canonicalKey) ||
                              dismissedAdaptiveProfileKeys.contains(normChosen) ||
                              aliases.contains(where: { dismissedAdaptiveProfileKeys.contains(Self.normalizeFieldLabel($0)) })
            if isDismissed { continue }
            
            built.append(AdaptiveProfileEntry(
                id: acc.canonicalKey,
                canonicalKey: acc.canonicalKey,
                question: chosenQuestion,
                answer: acc.answer,
                frequency: max(1, acc.frequency),
                aliases: aliases,
                lastSeenAt: acc.lastSeenAt == .distantPast ? Date() : acc.lastSeenAt,
                isUserEdited: acc.isUserEdited,
                isCustom: acc.isCustom
            ))
        }
        
        built.sort { lhs, rhs in
            if lhs.frequency != rhs.frequency {
                return lhs.frequency > rhs.frequency
            }
            let lhsActive = lhs.isUserEdited || !lhs.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let rhsActive = rhs.isUserEdited || !rhs.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if lhsActive != rhsActive {
                return lhsActive
            }
            if lhs.lastSeenAt != rhs.lastSeenAt {
                return lhs.lastSeenAt > rhs.lastSeenAt
            }
            return lhs.question.localizedCaseInsensitiveCompare(rhs.question) == .orderedAscending
        }
        
        if self.adaptiveProfileEntries != built {
            self.adaptiveProfileEntries = built
        }
        if self.adaptiveSourceCount != docs.count {
            self.adaptiveSourceCount = docs.count
        }
    }
    
    // MARK: - Question Matching & Input Memory Resolution
    
    public func matchQuestionTitles(_ a: String, _ b: String) -> Bool {
        let cleanA = Self.cleanQuestionTitle(a)
        let cleanB = Self.cleanQuestionTitle(b)
        if cleanA.caseInsensitiveCompare(cleanB) == .orderedSame { return true }
        let normA = Self.normalizeFieldLabel(cleanA)
        let normB = Self.normalizeFieldLabel(cleanB)
        if !normA.isEmpty && normA == normB { return true }
        
        if Self.hasQualifierConflict(cleanA, cleanB) {
            return false
        }
        
        let conceptA = Self.semanticConceptKey(for: cleanA).key
        let conceptB = Self.semanticConceptKey(for: cleanB).key
        if !conceptA.isEmpty && conceptA == conceptB {
            return true
        }
        
        let rawTokensA = Set(normA.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 2 && !Self.labelStopWords.contains($0) })
        let rawTokensB = Set(normB.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 2 && !Self.labelStopWords.contains($0) })
        if !rawTokensA.isEmpty && !rawTokensB.isEmpty {
            let inter = rawTokensA.intersection(rawTokensB)
            let minCount = min(rawTokensA.count, rawTokensB.count)
            if minCount > 0 && Double(inter.count) / Double(minCount) >= 0.70 {
                return true
            }
        }
        
        let minLen = min(normA.count, normB.count)
        let maxLen = max(normA.count, normB.count)
        if minLen >= 5 && maxLen > 0 && Double(minLen) / Double(maxLen) >= 0.65 && (normA.contains(normB) || normB.contains(normA)) {
            return true
        }
        
        return false
    }
    
    /// Resolves the previously recorded or saved user input for a question across:
    /// 1. Current session field value (if already entered)
    /// 2. User-edited Profile Answers (`profileAnswers`)
    /// 3. Adaptive Profile learned clusters (`adaptiveProfileEntries`)
    /// 4. Saved Form Copies (`savedFormCopies`)
    /// 5. Supabase Form Receipts (`SupabaseService.shared.formReceipts`)
    /// 6. History Sessions (`historySessions`)
    /// 7. Supabase Memory Items (`SupabaseService.shared.memoryItems`)
    public func resolveSavedInput(for field: FormInputField) -> String? {
        let trimmedVal = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedVal.isEmpty {
            return trimmedVal
        }
        return resolveSavedInput(forQuestionLabel: field.label)
    }
    
    public func resolveSavedInput(forQuestionLabel label: String) -> String? {
        let cleanLabel = Self.cleanQuestionTitle(label)
        guard !cleanLabel.isEmpty else { return nil }
        let targetConcept = Self.semanticConceptKey(for: cleanLabel).key
        
        // 1. Check User-Edited Profile Answers (exact, then semantic/fuzzy match)
        // Explicit empty string ("") in profileAnswers means the user deliberately cleared it,
        // so return nil instead of resurrecting older copy values.
        if let exact = profileAnswers[cleanLabel] {
            let trimmed = exact.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let exactRaw = profileAnswers[label] {
            let trimmed = exactRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        for (k, v) in profileAnswers {
            if matchQuestionTitles(k, cleanLabel) {
                let trimmed = v.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        }
        
        // 2. Check Adaptive Profile Entries (learned across all saved copies)
        for entry in adaptiveProfileEntries {
            let trimmed = entry.answer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if !Self.hasQualifierConflict(entry.question, cleanLabel) &&
                (entry.canonicalKey == targetConcept ||
                 matchQuestionTitles(entry.question, cleanLabel) ||
                 entry.aliases.contains(where: { matchQuestionTitles($0, cleanLabel) })) {
                return trimmed
            }
        }
        
        // 3. Check Saved Form Copies (newest first — remember savedFormCopies inserts newest at index 0)
        for copy in savedFormCopies {
            if let exact = copy.answers[cleanLabel], !exact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return exact
            }
            if let exactRaw = copy.answers[label], !exactRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return exactRaw
            }
            for (k, v) in copy.answers where !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if matchQuestionTitles(k, cleanLabel) {
                    return v
                }
            }
        }
        
        // 4. Check Supabase Form Receipts (newest first)
        for receipt in SupabaseService.shared.formReceipts {
            for f in receipt.fields where !f.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if matchQuestionTitles(f.label, cleanLabel) {
                    return f.value
                }
            }
        }
        
        // 5. Check History Sessions (newest first)
        for session in historySessions {
            for f in session.fields where !f.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if matchQuestionTitles(f.label, cleanLabel) {
                    return f.value
                }
            }
        }
        
        // 6. Check Supabase Memory Items
        for item in SupabaseService.shared.memoryItems where item.kind == "form" {
            if let metaData = item.metaJSON.data(using: .utf8),
               let dict = try? JSONDecoder().decode([String: String].self, from: metaData) {
                if let exact = dict[cleanLabel], !exact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return exact
                }
                for (k, v) in dict where !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if matchQuestionTitles(k, cleanLabel) {
                        return v
                    }
                }
            }
            if !item.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if matchQuestionTitles(item.title, cleanLabel) {
                    return item.body
                }
            }
        }
        
        return nil
    }
    
    /// Number of actionable empty fields on the active form that have saved answers ready in memory.
    public var readyToAutofillCount: Int {
        guard let session = activeSession else { return 0 }
        var count = 0
        for field in session.fields where field.isActionableQuestion && field.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if resolveSavedInput(for: field) != nil {
                count += 1
            }
        }
        return count
    }
    
    /// Resolves what appears on the right side of a live form question row:
    /// user's live/captured input strictly takes priority over Autofill suggestions.
    public func rightSideDisplay(for field: FormInputField) -> FormRowRightDisplay {
        if !field.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .userInput(field.value)
        }
        if let saved = resolveSavedInput(for: field),
           !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .autofillSuggestion(saved)
        }
        return .empty
    }
    
    // MARK: - Browser Field Injection & Question Inputting
    
    private func resolveTargetBrowserApplication() -> NSRunningApplication? {
        if let front = NSWorkspace.shared.frontmostApplication,
           DefaultApplicationFormDetector.isBrowserApplication(front) {
            return front
        }
        let activeAppName = (activeSession?.sourceAppName ?? detectedAppName).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !activeAppName.isEmpty {
            if let named = NSWorkspace.shared.runningApplications.first(where: {
                !$0.isTerminated &&
                DefaultApplicationFormDetector.isBrowserApplication($0) &&
                (($0.localizedName?.lowercased().contains(activeAppName) == true) ||
                 activeAppName.contains($0.localizedName?.lowercased() ?? ""))
            }) {
                return named
            }
        }
        let windows = (CGWindowListCopyWindowInfo([.excludeDesktopElements, .optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]) ?? []
        for win in windows {
            let layer = win[kCGWindowLayer as String] as? Int ?? -1
            guard layer == 0 else { continue }
            if let pid = win[kCGWindowOwnerPID as String] as? pid_t,
               let app = NSRunningApplication(processIdentifier: pid),
               !app.isTerminated,
               DefaultApplicationFormDetector.isBrowserApplication(app) {
                return app
            }
        }
        return PersonalizedBrowserDetector.rankedRunningBrowsers().first
    }
    
    public func injectAnswersWithReport(answers: [String: String]) -> BrowserInjectionResult {
        guard !answers.isEmpty else {
            return BrowserInjectionResult(injectedCount: 0, injectedLabels: [], errorMessage: nil)
        }
        lastInjectionError = nil
        
        if let override = testBrowserInjectionOverride {
            let result = override(answers)
            self.lastInjectionError = result.errorMessage
            return result
        }
        
        if MorphEnvironment.isTestingEnvironment {
            return BrowserInjectionResult(injectedCount: answers.count, injectedLabels: Set(answers.keys), errorMessage: nil)
        }
        
        guard let app = resolveTargetBrowserApplication() else {
            let err = "No active browser window found"
            lastInjectionError = err
            return BrowserInjectionResult(injectedCount: 0, injectedLabels: [], errorMessage: err)
        }
        let bundleID = app.bundleIdentifier ?? ""
        let lowerBundle = bundleID.lowercased()
        let appDisplay = app.localizedName ?? "Browser"
        let targetURL = activeSession?.sourceURL ?? detectedURL
        let schemaFields = activeSession?.fields ?? []
        
        // Layer 1: Schema-aware AppleScript DOM Injection directly into the matching form tab
        if let script = FormInputAutoTracker.buildDOMInjectionAppleScript(
            bundleID: bundleID,
            answers: answers,
            fields: schemaFields,
            targetURL: targetURL
        ),
           let resultStr = FormInputAutoTracker.executeAppleScript(script) {
            let trimmed = resultStr.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("__JS_ERROR__:") {
                let rawErr = String(trimmed.dropFirst("__JS_ERROR__:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
                if rawErr.localizedCaseInsensitiveContains("apple events") ||
                   (rawErr.localizedCaseInsensitiveContains("javascript") && rawErr.localizedCaseInsensitiveContains("turned off")) {
                    if appDisplay.localizedCaseInsensitiveContains("safari") {
                        lastInjectionError = "Enable Safari: Develop > Allow JavaScript from Apple Events"
                    } else {
                        lastInjectionError = "Enable \(appDisplay): View > Developer > Allow JavaScript from Apple Events"
                    }
                } else {
                    lastInjectionError = rawErr.isEmpty ? "Browser rejected JavaScript execution" : rawErr
                }
            } else {
                let parsedCount: Int? = {
                    if let c = Int(trimmed), c > 0 { return c }
                    if trimmed.hasPrefix("__PENDING__:"),
                       let c = Int(String(trimmed.dropFirst("__PENDING__:".count)).trimmingCharacters(in: .whitespacesAndNewlines)),
                       c > 0 {
                        return c
                    }
                    return nil
                }()
                if let count = parsedCount {
                    var filledLabels = Set<String>()
                    if let filledScript = FormInputAutoTracker.buildDOMFilledLabelsAppleScript(bundleID: bundleID, targetURL: targetURL),
                       let jsonOut = FormInputAutoTracker.executeAppleScript(filledScript),
                       let data = jsonOut.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
                       let decoded = try? JSONDecoder().decode([String].self, from: data) {
                        filledLabels = Set(decoded)
                    }
                    if filledLabels.isEmpty && count >= answers.count {
                        filledLabels = Set(answers.keys)
                    }
                    lastInjectionError = nil
                    return BrowserInjectionResult(injectedCount: count, injectedLabels: filledLabels, errorMessage: nil)
                }
            }
        }
        
        // Layer 2: macOS Accessibility API injection (works without AppleScript JS if Accessibility is granted & AXWebArea exists)
        if AXIsProcessTrusted() {
            let axReport = FormInputAutoTracker.injectAnswersViaAccessibilityWithReport(app: app, answers: answers, fields: schemaFields)
            if axReport.count > 0 {
                lastInjectionError = nil
                return BrowserInjectionResult(injectedCount: axReport.count, injectedLabels: axReport.labels, errorMessage: nil)
            }
        }
        
        // Layer 3: Single focused field clipboard paste fallback
        var blockedHeadlessFocusMismatchLabel: String? = nil
        if answers.count == 1,
           let targetLabel = answers.keys.first,
           let val = answers.values.first,
           !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           AXIsProcessTrusted(),
           FormInputAutoTracker.activateBrowser(app),
           !FormInputAutoTracker.isBrowserChromeInputFocused(for: app) {
            let appElem = AXUIElementCreateApplication(app.processIdentifier)
            let hasWebArea = DefaultApplicationFormDetector.getBrowserWindowElement(appElem: appElem)
                .flatMap { FormInputAutoTracker.findWebAreaElement(in: $0) } != nil
            var allowFocusedPaste = false
            if hasWebArea, let resolved = FormInputAutoTracker.resolveFocusedElement(for: app) {
                allowFocusedPaste = FormInputAutoTracker.isElementInsideWebArea(resolved.element) &&
                    (resolved.role == "AXTextField" || resolved.role == "AXTextArea" || resolved.role == "AXSearchField" || resolved.role == "AXComboBox")
            } else if !hasWebArea {
                // Headless browsers (e.g. Polar) expose no AXWebArea or scriptable DOM:
                // Only paste when the requested question is a text-entry control AND focus is confirmed on that question.
                let normTarget = Self.normalizeFieldLabel(targetLabel)
                let matchedField = schemaFields.first {
                    $0.label.caseInsensitiveCompare(targetLabel) == .orderedSame ||
                    Self.normalizeFieldLabel($0.label) == normTarget
                }
                let isTextTarget = matchedField.map { FormInputAutoTracker.isTextEntryType($0.questionType) } ?? true
                let confirmedID = autoTracker?.confirmedFieldID
                let focusMatchesTarget = (confirmedID != nil && matchedField?.id == confirmedID)
                allowFocusedPaste = isTextTarget && focusMatchesTarget
                if !allowFocusedPaste {
                    blockedHeadlessFocusMismatchLabel = targetLabel
                }
            }
            if allowFocusedPaste {
                FormInputAutoTracker.simulatePasteText(val, targetApp: app, selectAllFirst: true)
                lastInjectionError = nil
                return BrowserInjectionResult(injectedCount: 1, injectedLabels: Set(answers.keys), errorMessage: nil)
            }
        }
        
        if let focusHintLabel = blockedHeadlessFocusMismatchLabel {
            lastInjectionError = "Click \"\(focusHintLabel)\" in \(appDisplay) first, then tap to paste"
        } else if (lowerBundle.contains("com.polar.browser") || appDisplay.lowercased() == "polar") && answers.count > 1 {
            lastInjectionError = "Polar blocks multi-field autofill — tap each question to paste, or use Chrome/Safari"
        } else if !AXIsProcessTrusted() {
            if let jsErr = lastInjectionError, jsErr.contains("Allow JavaScript from Apple Events") {
                lastInjectionError = "\(jsErr), or grant Accessibility permission"
            } else {
                lastInjectionError = "Grant Morph Accessibility permission in System Settings to autofill directly"
            }
        } else if lastInjectionError == nil {
            lastInjectionError = "Could not match form inputs in \(appDisplay)"
        }
        return BrowserInjectionResult(injectedCount: 0, injectedLabels: [], errorMessage: lastInjectionError)
    }
    
    @discardableResult
    public func injectAnswersIntoBrowser(answers: [String: String]) -> Int {
        return injectAnswersWithReport(answers: answers).injectedCount
    }
    
    /// Inputs the saved answer that the user previously put in for the specified question (or active question)
    /// directly into the browser form field and updates Morph's active session only when written.
    @discardableResult
    public func inputAnswerIntoActiveQuestion(fieldID: UUID? = nil, value: String? = nil) -> Bool {
        guard var session = activeSession, !session.fields.isEmpty else {
            showToast("No active form detected")
            return false
        }
        
        let targetIdx: Int
        if let fid = fieldID, let idx = session.fields.firstIndex(where: { $0.id == fid }) {
            targetIdx = idx
        } else {
            targetIdx = max(0, min(activeFieldIndex, session.fields.count - 1))
        }
        
        let field = session.fields[targetIdx]
        guard let valToInput = value ?? resolveSavedInput(for: field),
              !valToInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showToast("No saved answer found for \"\(field.label)\"")
            return false
        }
        
        // Physically inject into the active browser on screen
        let report = injectAnswersWithReport(answers: [field.label: valToInput])
        
        if report.injectedCount > 0 {
            objectWillChange.send()
            session.fields[targetIdx].value = valToInput
            self.browserCapturedFieldIDs.insert(session.fields[targetIdx].id)
            self.activeSession = session
            self.activeFieldIndex = targetIdx
            saveDrafts()
            
            if !MorphEnvironment.isTestingEnvironment {
                if let hostApp = resolveTargetBrowserApplication(),
                   let ctrl = MorphController.shared,
                   ctrl.model.glassIslandState == .idle {
                    hostApp.activate()
                }
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    self?.syncLiveFormInputValues(isBackground: true)
                }
            }
            
            showToast("Filled \"\(field.label)\" in form")
            return true
        }
        
        showToast(report.errorMessage ?? lastInjectionError ?? "Could not write to \"\(field.label)\"")
        return false
    }
    
    /// Inputs the saved answer for whichever question is currently active/focused.
    @discardableResult
    public func inputSavedAnswerForActiveQuestion() -> Bool {
        return inputAnswerIntoActiveQuestion(fieldID: nil, value: nil)
    }
    
    @discardableResult
    public func autofillActiveForm() -> Int {
        guard var session = activeSession else { return 0 }
        var answersToInject: [String: String] = [:]
        var matchedIndices: [(Int, String)] = []
        
        for idx in session.fields.indices {
            if session.fields[idx].isActionableQuestion && session.fields[idx].value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let val = resolveSavedInput(for: session.fields[idx]) {
                    answersToInject[session.fields[idx].label] = val
                    matchedIndices.append((idx, val))
                }
            }
        }
        
        guard !matchedIndices.isEmpty else {
            let hasEmptyFields = session.fields.contains {
                $0.isActionableQuestion && $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            showToast(hasEmptyFields ? "No matching answers in Adaptive Profile yet" : "Form answers already filled!")
            return 0
        }
        
        let report = injectAnswersWithReport(answers: answersToInject)
        if report.injectedCount > 0 {
            let trustAllMatched = MorphEnvironment.isTestingEnvironment && testBrowserInjectionOverride == nil
            var updatedCount = 0
            for (idx, val) in matchedIndices {
                let label = session.fields[idx].label
                let normLabel = Self.normalizeFieldLabel(label)
                let wasInjected = trustAllMatched ||
                    report.injectedLabels.contains(label) ||
                    report.injectedLabels.contains(where: {
                        $0.caseInsensitiveCompare(label) == .orderedSame ||
                        Self.normalizeFieldLabel($0) == normLabel
                    }) ||
                    (report.injectedLabels.isEmpty && report.injectedCount >= matchedIndices.count)
                if wasInjected {
                    session.fields[idx].value = val
                    self.browserCapturedFieldIDs.insert(session.fields[idx].id)
                    updatedCount += 1
                }
            }
            if updatedCount > 0 {
                objectWillChange.send()
                self.activeSession = session
                saveDrafts()
            }
            
            if !MorphEnvironment.isTestingEnvironment {
                if let hostApp = resolveTargetBrowserApplication(),
                   let ctrl = MorphController.shared,
                   ctrl.model.glassIslandState == .idle {
                    hostApp.activate()
                }
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    self?.syncLiveFormInputValues(isBackground: true)
                }
            }
            
            if updatedCount > 0 {
                if !report.injectedLabels.isEmpty && updatedCount < matchedIndices.count {
                    showToast("Autofilled \(updatedCount)/\(matchedIndices.count) fields into form")
                } else {
                    showToast("Autofilled \(updatedCount) \(updatedCount == 1 ? "field" : "fields") directly into form!")
                }
                return updatedCount
            }
            
            showToast("Wrote \(report.injectedCount) \(report.injectedCount == 1 ? "field" : "fields") in browser — syncing fields")
            return 0
        }
        
        showToast(report.errorMessage ?? lastInjectionError ?? "Could not write to form — check active tab")
        return 0
    }
    
    // MARK: - Draft & History Persistence
    nonisolated public static let draftsStorageKey = "com.morph.applicationForm.drafts"
    
    public func saveDrafts(syncCloud: Bool = true) {
        var draftsToSave: [ApplicationFormSession] = []
        if let active = activeSession {
            let app = active.sourceAppName.lowercased()
            let title = active.formTitle.lowercased()
            if !app.contains("antigravity") && !title.contains("antigravity") && !DefaultApplicationFormDetector.isNonFormApplication(bundleID: "", appName: active.sourceAppName) {
                draftsToSave.append(active)
            }
        }
        if let suspended = suspendedSession {
            let app = suspended.sourceAppName.lowercased()
            let title = suspended.formTitle.lowercased()
            if !app.contains("antigravity") && !title.contains("antigravity") && !DefaultApplicationFormDetector.isNonFormApplication(bundleID: "", appName: suspended.sourceAppName) {
                if !draftsToSave.contains(where: { $0.id == suspended.id }) {
                    draftsToSave.append(suspended)
                }
            }
        }
        for hist in historySessions {
            let app = hist.sourceAppName.lowercased()
            let title = hist.formTitle.lowercased()
            if !app.contains("antigravity") && !title.contains("antigravity") && !DefaultApplicationFormDetector.isNonFormApplication(bundleID: "", appName: hist.sourceAppName) {
                if !draftsToSave.contains(where: { $0.id == hist.id }) {
                    draftsToSave.append(hist)
                }
            }
        }
        
        do {
            let data = try JSONEncoder().encode(draftsToSave)
            UserDefaults.standard.set(data, forKey: Self.draftsStorageKey)
            if syncCloud {
                syncToSupabase()
            }
        } catch {
            NSLog("[MORPH-FORM] Failed to encode form drafts: %@", error.localizedDescription)
        }
    }
    
    public func loadDrafts() {
        guard let data = UserDefaults.standard.data(forKey: Self.draftsStorageKey) else { return }
        do {
            var loaded = try JSONDecoder().decode([ApplicationFormSession].self, from: data)
            let bogusLabels: Set<String> = [
                "all", "required", "polar", "morph", "ask polar",
                "tab name", "tab", "tab bar", "address and search bar", "address",
                "search or enter website name", "search", "new tab", "close tab", "active tab"
            ]
            // Strictly exclude any drafts that were erroneously captured from Antigravity, code editors, or non-form apps
            loaded.removeAll { session in
                let app = session.sourceAppName.lowercased()
                let title = session.formTitle.lowercased()
                let url = session.sourceURL?.lowercased() ?? ""
                return app.contains("antigravity") || title.contains("antigravity") ||
                       title.contains("youtube") || url.contains("youtube.com") ||
                       url.contains("instructure.com") || url.contains("canvas") ||
                       url.contains("blackboard") || url.contains("moodle") ||
                       url.contains("brightspace") ||
                       DefaultApplicationFormDetector.isNonFormApplication(bundleID: "", appName: session.sourceAppName)
            }
            for sessionIdx in loaded.indices {
                if loaded[sessionIdx].recipientEmail.isEmpty || loaded[sessionIdx].recipientEmail == "user@example.com" || loaded[sessionIdx].recipientEmail.contains("minh7898888") {
                    loaded[sessionIdx].recipientEmail = Self.defaultRecipientEmail
                }
                loaded[sessionIdx].fields.removeAll { field in
                    guard field.entryKey == nil else { return false }
                    let lbl = field.label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    return bogusLabels.contains(lbl) || lbl.hasPrefix("all,") || lbl.hasPrefix("required,")
                }
                for fieldIdx in loaded[sessionIdx].fields.indices {
                    if loaded[sessionIdx].fields[fieldIdx].entryKey == nil && loaded[sessionIdx].fields[fieldIdx].questionType == "text" {
                        loaded[sessionIdx].fields[fieldIdx].questionType = "info"
                        loaded[sessionIdx].fields[fieldIdx].isRequired = false
                    }
                }
            }
            self.historySessions = loaded
            self.saveDrafts()
        } catch {
            NSLog("[MORPH-FORM] Failed to decode form drafts: %@", error.localizedDescription)
        }
    }
    
    public func clearSavedDrafts() {
        UserDefaults.standard.removeObject(forKey: Self.draftsStorageKey)
    }
    
    public func advanceToFirstUnansweredFieldIfNeeded() {
        guard let session = activeSession, !session.fields.isEmpty else { return }
        
        let curIdx = self.activeFieldIndex
        let fields = session.fields
        let isReqFilter = (filterMode == .requiredOnly && session.hasRequiredFields)
        
        // If current index is valid, keep it when:
        // 1. autoTracker has confirmed focus on this exact question (so activeFieldIndex never jumps mid-typing), OR
        // 2. it is unanswered and matches current filter mode.
        if curIdx >= 0 && curIdx < fields.count {
            let curField = fields[curIdx]
            if curField.isActionableQuestion, autoTracker?.confirmedFieldID == curField.id {
                return
            }
            if !curField.isAnswered && curField.isActionableQuestion {
                if !isReqFilter || curField.isRequired {
                    return
                }
            }
        }
        
        // Find the first unanswered question (prioritizing required if in requiredOnly mode)
        if isReqFilter {
            if let firstReq = fields.indices.first(where: { !fields[$0].isAnswered && fields[$0].isActionableQuestion && fields[$0].isRequired }) {
                self.objectWillChange.send()
                self.activeFieldIndex = firstReq
                return
            }
        }
        
        if let firstUnanswered = fields.indices.first(where: { !fields[$0].isAnswered && fields[$0].isActionableQuestion }) {
            self.objectWillChange.send()
            self.activeFieldIndex = firstUnanswered
        }
    }
    
    public func refreshUserDefaultBrowser() {
        self.userDefaultBrowser = PersonalizedBrowserDetector.detectDefaultBrowser()
    }
    
    public func stopPolling() {
        autoTracker?.stop()
        autoTracker = nil
        if let obs = workspaceNotificationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            workspaceNotificationObserver = nil
        }
        if let obs = workspaceLaunchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            workspaceLaunchObserver = nil
        }
        if let obs = workspaceUnhideObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            workspaceUnhideObserver = nil
        }
        pollTimer?.cancel()
        pollTimer = nil
        justDetectedResetTask?.cancel()
        axObserverDebounceTask?.cancel()
        axObserverDebounceTask = nil
        activeRetrievalTask?.cancel()
        activeRetrievalTask = nil
        activeRetrievalURL = nil
        axObserverBox.detach()
    }
    
    private func startPolling() {
        // 1. Observe application activations across the computer
        workspaceNotificationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshBrowserAXObserverIfNeeded()
                self?.scheduleBackgroundActiveApplicationCheck()
            }
        }
        
        // 2. Observe new application launches
        workspaceLaunchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshBrowserAXObserverIfNeeded()
                self?.scheduleBackgroundActiveApplicationCheck()
            }
        }
        
        // 3. Observe application unhide
        workspaceUnhideObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didUnhideApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshBrowserAXObserverIfNeeded()
                self?.scheduleBackgroundActiveApplicationCheck()
            }
        }
        
        // 4. Periodic 0.25s backup monitor (off-main-actor) complementing event-driven AXObserver
        pollTimer = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshBrowserAXObserverIfNeeded()
                self?.scheduleBackgroundActiveApplicationCheck()
            }
        
        refreshBrowserAXObserverIfNeeded()
        scheduleBackgroundActiveApplicationCheck()
    }
    
    private func refreshBrowserAXObserverIfNeeded() {
        guard isFormFeatureEnabled, !MorphEnvironment.isTestingEnvironment else {
            axObserverBox.detach()
            return
        }
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            axObserverBox.detach()
            return
        }
        let bundleID = frontApp.bundleIdentifier?.lowercased() ?? ""
        let appName = frontApp.localizedName?.lowercased() ?? ""
        let isMorphFront = bundleID.contains("com.morph.") || bundleID == "morph" || bundleID.hasSuffix(".morph") || appName == "morph"
        if isMorphFront {
            // Keep existing browser observer attached while interacting with Morph if a form is active
            if !isFormDetected {
                axObserverBox.detach()
            }
            return
        }
        if DefaultApplicationFormDetector.isBrowserApplication(frontApp) {
            let pid = frontApp.processIdentifier
            if axObserverBox.currentPID() != pid {
                axObserverBox.attach(pid: pid) { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.handleBrowserAXEvent()
                    }
                }
            }
        } else {
            axObserverBox.detach()
        }
    }
    
    private func handleBrowserAXEvent() {
        guard isFormFeatureEnabled, !MorphEnvironment.isTestingEnvironment else { return }
        axObserverDebounceTask?.cancel()
        axObserverDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 25_000_000)
            guard !Task.isCancelled else { return }
            self?.scheduleBackgroundActiveApplicationCheck()
        }
    }
    
    private func isMorphOpenAndFrontmost() -> Bool {
        guard !MorphEnvironment.isTestingEnvironment,
              let frontApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        let bundleID = frontApp.bundleIdentifier?.lowercased() ?? ""
        let appName = frontApp.localizedName?.lowercased() ?? ""
        guard bundleID.contains("com.morph.") || bundleID == "morph" || bundleID.hasSuffix(".morph") || appName == "morph" else {
            return false
        }
        if let ctrl = MorphController.shared {
            return ctrl.model.isExpanded || (ctrl.model.isGlassIslandEnabled && ctrl.model.glassIslandState != .idle)
        }
        return false
    }
    
    public func scheduleBackgroundActiveApplicationCheck() {
        guard isFormFeatureEnabled else {
            if self.isFormDetected || self.isTracking {
                if let current = self.activeSession {
                    self.suspendedSession = current
                }
                self.isFormDetected = false
                self.isJustDetected = false
                self.isTracking = false
                self.detectedBrowserFamily = .unknown
                self.detectedScreenIndex = nil
                self.detectedScreenName = nil
                self.justDetectedResetTask?.cancel()
                self.activeRetrievalTask?.cancel()
                self.activeRetrievalTask = nil
                self.activeRetrievalURL = nil
                self.isAutoRetrievingSchema = false
            }
            return
        }
        
        if isMorphOpenAndFrontmost() {
            return
        }
        
        if MorphEnvironment.isTestingEnvironment {
            checkActiveApplication()
            return
        }
        
        if isBackgroundDetectionInFlight {
            hasPendingBackgroundDetection = true
            return
        }
        isBackgroundDetectionInFlight = true
        let currentDetector = self.detector
        
        Task.detached(priority: .userInitiated) { [weak self] in
            let result = currentDetector.detectActiveApplicationForm()
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.isBackgroundDetectionInFlight = false
                if self.isFormFeatureEnabled && !self.isMorphOpenAndFrontmost() {
                    self.applyDetectionResult(result)
                }
                if self.hasPendingBackgroundDetection {
                    self.hasPendingBackgroundDetection = false
                    self.scheduleBackgroundActiveApplicationCheck()
                }
            }
        }
    }
    
    // MARK: - Active Form Detection
    public func checkActiveApplication() {
        guard isFormFeatureEnabled else {
            if self.isFormDetected || self.isTracking {
                if let current = self.activeSession {
                    self.suspendedSession = current
                }
                self.isFormDetected = false
                self.isJustDetected = false
                self.isTracking = false
                self.detectedBrowserFamily = .unknown
                self.detectedScreenIndex = nil
                self.detectedScreenName = nil
                self.justDetectedResetTask?.cancel()
                self.activeRetrievalTask?.cancel()
                self.activeRetrievalTask = nil
                self.activeRetrievalURL = nil
                self.isAutoRetrievingSchema = false
            }
            return
        }
        
        if isMorphOpenAndFrontmost() {
            return
        }
        
        let result = detector.detectActiveApplicationForm()
        applyDetectionResult(result)
    }
    
    @MainActor
    public func applyDetectionResult(_ result: FormDetectionResult) {
        if result.isDetected != self.isFormDetected {
            NSLog("[MORPH-FORM] applyDetectionResult: isDetected changed from %d to %d (title: %@, app: %@, url: %@)", self.isFormDetected ? 1 : 0, result.isDetected ? 1 : 0, result.title ?? "nil", result.appName ?? "nil", result.url ?? "nil")
        }
        if result.isDetected {
            self.consecutiveMissedDetections = 0
            let title = result.title ?? "Application Form"
            let app = result.appName ?? userDefaultBrowser.displayName
            let url = result.url
            let family = result.browserFamily ?? PersonalizedBrowserDetector.engineFamily(for: "", name: app)
            let normalizedURL = url != nil ? FormContentRetriever.normalizeURLScheme(url!) : nil
            
            let wasDetected = self.isFormDetected
            if !wasDetected {
                self.isJustDetected = true
                justDetectedResetTask?.cancel()
                justDetectedResetTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 4_500_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self?.isJustDetected = false
                    }
                }
            }
            
            self.isFormDetected = true
            self.detectedFormTitle = title
            self.detectedAppName = app
            self.detectedURL = normalizedURL
            self.detectedBrowserFamily = family
            self.detectedScreenIndex = result.screenIndex
            self.detectedScreenName = result.screenName
            
            // Multi-Form Awareness & Resumption:
            // 1. If we have a suspended session (user switched away and came back), check if it's the SAME form
            if let suspended = suspendedSession {
                let isSame = DefaultApplicationFormDetector.isSameForm(
                    titleA: suspended.formTitle, urlA: suspended.sourceURL,
                    titleB: title, urlB: normalizedURL
                )
                
                if isSame {
                    var resumed = suspended
                    let reopenedAfterSubmission = resumed.isSubmitted ||
                        (Self.isFormSubmissionURL(resumed.sourceURL) && !Self.isFormSubmissionURL(normalizedURL))
                    if reopenedAfterSubmission {
                        resetSessionForFreshOpen(&resumed)
                    } else {
                        self.awaitingReopenSnapshotClear = true
                    }
                    self.activeSession = resumed
                    self.suspendedSession = nil
                    self.isTracking = true
                    self.isClosedOrExpired = resumed.isClosedOrExpired
                    self.closedReason = resumed.closedReason
                    let cleanCurr = DefaultApplicationFormDetector.cleanTitle(title)
                    let cleanOld = DefaultApplicationFormDetector.cleanTitle(resumed.formTitle)
                    let genericTitles = ["application form", "google forms", "untitled form", "polar"]
                    if genericTitles.contains(cleanOld.lowercased()) && !genericTitles.contains(cleanCurr.lowercased()) && !cleanCurr.isEmpty {
                        self.activeSession?.formTitle = title
                        self.detectedFormTitle = title
                    }
                    if let u = normalizedURL, !u.isEmpty {
                        let prevURL = self.activeSession?.sourceURL
                        if prevURL == nil || prevURL?.isEmpty == true || reopenedAfterSubmission {
                            self.activeSession?.sourceURL = u
                        }
                        if reopenedAfterSubmission || (self.activeSession?.fields.isEmpty ?? true) {
                            autoRetrieveFormContent(url: u)
                        }
                    }
                } else {
                    // Different form opened: archive suspended session to history
                    var old = suspended
                    old.completedAt = Date()
                    recordBlinkSuppressionBaseline(for: old.sourceURL)
                    if let existingIdx = historySessions.firstIndex(where: { $0.id == old.id }) {
                        historySessions[existingIdx] = old
                    } else {
                        historySessions.insert(old, at: 0)
                    }
                    self.suspendedSession = nil
                }
            }
            
            if let active = activeSession {
                // 2. Already tracking an active session: check if user switched to a DIFFERENT form
                let isSame = DefaultApplicationFormDetector.isSameForm(
                    titleA: active.formTitle, urlA: active.sourceURL,
                    titleB: title, urlB: normalizedURL
                )
                
                if !isSame {
                    // Different form opened! Archive old session to history
                    var old = active
                    old.completedAt = Date()
                    recordBlinkSuppressionBaseline(for: old.sourceURL)
                    if let existingIdx = historySessions.firstIndex(where: { $0.id == old.id }) {
                        historySessions[existingIdx] = old
                    } else {
                        historySessions.insert(old, at: 0)
                    }
                    self.activeSession = nil
                } else {
                    let restartedAfterSubmit = (active.isSubmitted && !Self.isFormSubmissionURL(normalizedURL)) ||
                        (Self.isFormSubmissionURL(active.sourceURL) && !Self.isFormSubmissionURL(normalizedURL))
                    if restartedAfterSubmit {
                        var fresh = active
                        resetSessionForFreshOpen(&fresh)
                        let cleanCurr = DefaultApplicationFormDetector.cleanTitle(title)
                        let cleanOld = DefaultApplicationFormDetector.cleanTitle(fresh.formTitle)
                        let genericTitles = ["application form", "google forms", "untitled form", "polar"]
                        if genericTitles.contains(cleanOld.lowercased()) && !genericTitles.contains(cleanCurr.lowercased()) && !cleanCurr.isEmpty {
                            fresh.formTitle = title
                            self.detectedFormTitle = title
                        }
                        fresh.sourceAppName = app
                        if let u = normalizedURL, !u.isEmpty {
                            fresh.sourceURL = u
                            self.detectedURL = u
                        }
                        self.activeSession = fresh
                        if let u = fresh.sourceURL ?? normalizedURL, !u.isEmpty {
                            autoRetrieveFormContent(url: u)
                        }
                    } else {
                        // Same form: refine title/URL if transitioning from generic to specific
                        let cleanCurr = DefaultApplicationFormDetector.cleanTitle(title)
                        let cleanOld = DefaultApplicationFormDetector.cleanTitle(active.formTitle)
                        let genericTitles = ["application form", "google forms", "untitled form", "polar"]
                        if genericTitles.contains(cleanOld.lowercased()) && !genericTitles.contains(cleanCurr.lowercased()) && !cleanCurr.isEmpty {
                            activeSession?.formTitle = title
                            self.detectedFormTitle = title
                        }
                        activeSession?.sourceAppName = app
                        if let u = normalizedURL, !u.isEmpty {
                            if activeSession?.sourceURL != u {
                                activeSession?.sourceURL = u
                                self.detectedURL = u
                                if activeSession?.fields.isEmpty ?? true {
                                    autoRetrieveFormContent(url: u)
                                }
                            } else if (activeSession?.fields.isEmpty ?? true) && !isAutoRetrievingSchema {
                                autoRetrieveFormContent(url: u)
                            }
                        }
                    }
                }
            }
            
            // 3. Search history / drafts memory for this form, always clearing previous answers for a fresh open
            if activeSession == nil {
                if let matchIdx = historySessions.firstIndex(where: {
                    DefaultApplicationFormDetector.isSameForm(
                        titleA: $0.formTitle, urlA: $0.sourceURL,
                        titleB: title, urlB: normalizedURL
                    )
                }) {
                    var restored = historySessions.remove(at: matchIdx)
                    resetSessionForFreshOpen(&restored)
                    let cleanCurr = DefaultApplicationFormDetector.cleanTitle(title)
                    let cleanOld = DefaultApplicationFormDetector.cleanTitle(restored.formTitle)
                    let genericTitles = ["application form", "google forms", "untitled form", "polar"]
                    if genericTitles.contains(cleanOld.lowercased()) && !genericTitles.contains(cleanCurr.lowercased()) && !cleanCurr.isEmpty {
                        restored.formTitle = title
                    }
                    if let u = normalizedURL, !u.isEmpty {
                        restored.sourceURL = u
                    }
                    restored.sourceAppName = app
                    self.activeSession = restored
                    self.isTracking = true
                    NSLog("[MORPH-FORM] Reopened form session '%@' cleanly with %d fields", restored.formTitle, restored.fields.count)
                    advanceToFirstUnansweredFieldIfNeeded()
                    saveDrafts()
                    if let u = restored.sourceURL ?? normalizedURL, !u.isEmpty {
                        autoRetrieveFormContent(url: u)
                    }
                } else {
                    // No existing session in drafts or history: start tracking fresh
                    startTracking(title: title, appName: app, url: normalizedURL)
                }
            }
            
            syncLiveFormInputValues(isBackground: !MorphEnvironment.isTestingEnvironment)
            advanceToFirstUnansweredFieldIfNeeded()
            saveDrafts()
        } else {
            // If Morph itself is expanded/open and frontmost and we already have an active form session,
            // retain the state while the user interacts with the Notch/HUD
            if !MorphEnvironment.isTestingEnvironment, let frontApp = NSWorkspace.shared.frontmostApplication {
                let bundleID = frontApp.bundleIdentifier?.lowercased() ?? ""
                let appName = frontApp.localizedName?.lowercased() ?? ""
                let isMorphOpen: Bool
                if let ctrl = MorphController.shared {
                    isMorphOpen = ctrl.model.isExpanded || (ctrl.model.isGlassIslandEnabled && ctrl.model.glassIslandState != .idle)
                } else {
                    isMorphOpen = false
                }
                if isMorphOpen && (bundleID.contains("com.morph.") || bundleID == "morph" || bundleID.hasSuffix(".morph") || appName == "morph") && self.isFormDetected {
                    return
                }
            }
            
            self.consecutiveMissedDetections += 1
            
            // Immediate collapse when form is closed or navigated away:
            // Stash active session into suspendedSession so when the user goes back to the form,
            // it resumes without losing entered fields or answers.
            if self.isFormDetected || self.isTracking {
                if let current = self.activeSession {
                    self.suspendedSession = current
                }
                self.isFormDetected = false
                self.isJustDetected = false
                self.isTracking = false
                self.detectedBrowserFamily = .unknown
                self.detectedScreenIndex = nil
                self.detectedScreenName = nil
                self.justDetectedResetTask?.cancel()
                self.activeRetrievalTask?.cancel()
                self.activeRetrievalTask = nil
                self.activeRetrievalURL = nil
                self.isAutoRetrievingSchema = false
            }
        }
    }
    
    // MARK: - Session Lifecycle
    nonisolated private static func isFormSubmissionURL(_ url: String?) -> Bool {
        return url?.lowercased().contains("/formresponse") == true
    }
    
    @MainActor
    private func recordBlinkSuppressionBaseline(for urlString: String?) {
        guard let url = urlString, !url.isEmpty,
              let formID = DefaultApplicationFormDetector.extractFormIdentifier(from: url),
              !formID.isEmpty else { return }
        if let prevSig = lastObservedBlinkSignatureByFormID[formID] {
            ignoredBlinkSignatureByFormID[formID] = prevSig
            pendingBlinkBaselineCapture.remove(formID)
        } else {
            pendingBlinkBaselineCapture.insert(formID)
        }
        strictBlinkWindowByFormID.insert(formID)
    }
    
    @MainActor
    private func resetSessionForFreshOpen(_ session: inout ApplicationFormSession) {
        for i in session.fields.indices {
            session.fields[i].value = ""
        }
        session.startedAt = Date()
        session.completedAt = nil
        session.isSubmitted = false
        session.emailDeliveryStatus = .idle
        session.lastDispatchedAt = nil
        session.isClosedOrExpired = false
        session.closedReason = nil
        session.activeFieldIndex = 0
        self.activeFieldIndex = 0
        self.isClosedOrExpired = false
        self.closedReason = nil
        self.browserCapturedFieldIDs.removeAll()
        self.manuallyEditedFieldIDs.removeAll()
        self.lastKeystrokeAt = nil
        self.lastAutoCapturedAt = nil
        self.awaitingReopenSnapshotClear = false
        self.autoTracker?.invalidateFocus()
        self.recordBlinkSuppressionBaseline(for: session.sourceURL)
    }
    
    public func startTracking(
        title: String? = nil,
        appName: String? = nil,
        url: String? = nil,
        defaultEmail: String? = nil
    ) {
        let finalTitle = title ?? (detectedFormTitle.isEmpty ? "Application Form" : detectedFormTitle)
        let finalApp = appName ?? (detectedAppName.isEmpty ? "Web Browser" : detectedAppName)
        let rawUrl = url ?? detectedURL
        let finalUrl = rawUrl != nil ? FormContentRetriever.normalizeURLScheme(rawUrl!) : nil
        let emailToUse: String
        if let d = defaultEmail, !d.isEmpty && d != "user@example.com" {
            emailToUse = d
        } else if !recipientEmail.isEmpty && recipientEmail != "user@example.com" && !recipientEmail.contains("minh7898888") {
            emailToUse = recipientEmail
        } else {
            emailToUse = Self.defaultRecipientEmail
        }
        
        self.recipientEmail = emailToUse
        
        // Search history/drafts for an existing session for this form, always resetting stale answers on open
        if let matchIdx = historySessions.firstIndex(where: {
            DefaultApplicationFormDetector.isSameForm(
                titleA: $0.formTitle, urlA: $0.sourceURL,
                titleB: finalTitle, urlB: finalUrl
            )
        }) {
            var restored = historySessions.remove(at: matchIdx)
            resetSessionForFreshOpen(&restored)
            if !finalTitle.isEmpty && finalTitle != "Application Form" {
                restored.formTitle = finalTitle
            }
            if let u = finalUrl, !u.isEmpty {
                restored.sourceURL = u
            }
            restored.sourceAppName = finalApp
            self.activeSession = restored
            self.isTracking = true
            self.isFormDetected = true
            self.isClosedOrExpired = restored.isClosedOrExpired
            self.closedReason = restored.closedReason
            self.detectedFormTitle = restored.formTitle
            self.detectedAppName = finalApp
            self.detectedURL = finalUrl
            advanceToFirstUnansweredFieldIfNeeded()
            saveDrafts()
            if let u = restored.sourceURL ?? finalUrl, !u.isEmpty {
                autoRetrieveFormContent(url: u)
            }
            return
        }
        
        let session = ApplicationFormSession(
            formTitle: finalTitle,
            sourceAppName: finalApp,
            sourceURL: finalUrl,
            recipientEmail: emailToUse
        )
        
        self.activeSession = session
        self.activeFieldIndex = 0
        self.browserCapturedFieldIDs.removeAll()
        self.manuallyEditedFieldIDs.removeAll()
        self.lastKeystrokeAt = nil
        self.lastAutoCapturedAt = nil
        self.awaitingReopenSnapshotClear = false
        self.autoTracker?.invalidateFocus()
        self.recordBlinkSuppressionBaseline(for: finalUrl)
        self.isTracking = true
        self.isFormDetected = true
        self.isClosedOrExpired = false
        self.closedReason = nil
        self.detectedFormTitle = finalTitle
        self.detectedAppName = finalApp
        self.detectedURL = finalUrl
        
        saveDrafts()
        
        if let formURL = finalUrl, !formURL.isEmpty {
            autoRetrieveFormContent(url: formURL)
        }
    }
    
    public func stopTracking() {
        if var session = activeSession {
            session.completedAt = Date()
            recordBlinkSuppressionBaseline(for: session.sourceURL)
            if let existingIdx = historySessions.firstIndex(where: { $0.id == session.id }) {
                historySessions[existingIdx] = session
            } else {
                historySessions.insert(session, at: 0)
            }
        } else if var session = suspendedSession {
            session.completedAt = Date()
            recordBlinkSuppressionBaseline(for: session.sourceURL)
            if let existingIdx = historySessions.firstIndex(where: { $0.id == session.id }) {
                historySessions[existingIdx] = session
            } else {
                historySessions.insert(session, at: 0)
            }
        }
        self.activeSession = nil
        self.suspendedSession = nil
        self.activeFieldIndex = 0
        self.browserCapturedFieldIDs.removeAll()
        self.manuallyEditedFieldIDs.removeAll()
        self.awaitingReopenSnapshotClear = false
        self.autoTracker?.invalidateFocus()
        self.isTracking = false
        self.isFormDetected = false
        self.isJustDetected = false
        self.justDetectedResetTask?.cancel()
        saveDrafts()
        self.onFormClosed?()
    }
    
    // MARK: - Closed / Expired Form State
    @MainActor
    public func markFormClosed(reason: String) {
        self.isClosedOrExpired = true
        self.closedReason = reason
        self.activeSession?.isClosedOrExpired = true
        self.activeSession?.closedReason = reason
        self.saveDrafts()
        self.syncToSupabase()
        self.showToast("Form Closed: \(reason)")
    }
    
    // MARK: - Supabase Cloud Synchronization
    public func syncToSupabase() {
        guard let session = activeSession else { return }
        let jsonString = (try? String(data: JSONEncoder().encode(session.fields), encoding: .utf8)) ?? "[]"
        let summary = session.formattedSummary
        let record = FormReceiptRecord(
            id: session.id.uuidString,
            userId: SupabaseService.shared.currentUser.id,
            userEmail: SupabaseService.shared.currentUser.email,
            formTitle: session.formTitle,
            sourceURL: session.sourceURL,
            sourceAppName: session.sourceAppName,
            recipientEmail: self.recipientEmail,
            totalQuestions: session.fields.count,
            answeredCount: session.answeredCount,
            isSubmitted: session.isSubmitted,
            isClosedOrExpired: session.isClosedOrExpired,
            closedReason: session.closedReason,
            fieldsJSON: jsonString,
            formattedSummary: summary,
            submittedAt: session.lastDispatchedAt,
            createdAt: session.startedAt
        )
        Task {
            await SupabaseService.shared.recordFormReceipt(record)
        }
    }
    
    // MARK: - Autonomous Form Schema Retrieval
    nonisolated private static func extractSchemaFromBrowserDOM(
        bundleIDs: [String],
        formURL: String,
        fallbackTitle: String
    ) async -> FormSchema? {
        guard !bundleIDs.isEmpty else { return nil }
        for bid in bundleIDs {
            if Task.isCancelled { return nil }
            guard let liveItems = FormInputAutoTracker.extractItemsSnapshotViaAppleScript(bundleID: bid, targetURL: formURL),
                  !liveItems.isEmpty else {
                continue
            }
            if liveItems.contains(where: { $0.label == "__FORM_SUBMITTED__" || $0.questionType == "submitted" }) {
                return nil
            }
            if let closedItem = liveItems.first(where: { $0.label == "__FORM_CLOSED__" || $0.questionType == "closed" }) {
                let reason = !closedItem.value.isEmpty ? closedItem.value : "This form is no longer accepting responses."
                return FormSchema(title: fallbackTitle, description: "", fields: [], isClosed: true, closedMessage: reason)
            }
            let liveFields = liveItems.compactMap { item -> FormInputField? in
                guard item.label != "__FORM_CLOSED__" && item.label != "__FORM_SUBMITTED__" && !item.label.isEmpty else { return nil }
                let cat = FormContentRetriever.inferCategory(from: item.label)
                return FormInputField(
                    label: item.label,
                    value: item.value,
                    category: cat,
                    options: item.options,
                    questionType: item.questionType ?? "shortAnswer",
                    isRequired: item.isRequired
                )
            }
            if !liveFields.isEmpty {
                return FormSchema(title: fallbackTitle, description: "", fields: liveFields)
            }
        }
        return nil
    }
    
    public func autoRetrieveFormContent(url: String) {
        guard !url.isEmpty else { return }
        if isAutoRetrievingSchema && activeRetrievalURL == url {
            return
        }
        activeRetrievalTask?.cancel()
        retrievalGeneration &+= 1
        let gen = retrievalGeneration
        activeRetrievalURL = url
        isAutoRetrievingSchema = true
        
        let detectedAppSnapshot = detectedAppName
        let detectedTitleSnapshot = detectedFormTitle.isEmpty ? "Google Form" : detectedFormTitle
        let isWebURL = url.lowercased().hasPrefix("http://") || url.lowercased().hasPrefix("https://")
        let hostBundleIDs: [String] = (isWebURL && !MorphEnvironment.isTestingEnvironment)
            ? Self.formHostBrowsers(detectedAppName: detectedAppSnapshot).compactMap { $0.bundleIdentifier }
            : []
        
        activeRetrievalTask = Task { [weak self] in
            await withTaskGroup(of: (isHTTP: Bool, schema: FormSchema?).self) { group in
                group.addTask {
                    let s = await FormContentRetriever.retrieveForm(from: url)
                    return (true, s)
                }
                if !hostBundleIDs.isEmpty {
                    group.addTask {
                        let s = await Self.extractSchemaFromBrowserDOM(
                            bundleIDs: hostBundleIDs,
                            formURL: url,
                            fallbackTitle: detectedTitleSnapshot
                        )
                        return (false, s)
                    }
                }
                
                for await (isHTTP, schemaOpt) in group {
                    if Task.isCancelled { break }
                    guard let schema = schemaOpt else { continue }
                    await MainActor.run { [weak self] in
                        guard let self = self, self.retrievalGeneration == gen else { return }
                        self.applyRetrievedSchema(schema, sourceURL: url, isAuthoritativeHTTP: isHTTP)
                    }
                }
            }
            
            // Retry browser DOM schema extraction briefly for slow-rendering tabs or login-walled forms
            if !hostBundleIDs.isEmpty {
                for delayNs in [250_000_000 as UInt64, 500_000_000, 900_000_000] {
                    if Task.isCancelled { break }
                    let needsSchema = await MainActor.run { [weak self] () -> Bool in
                        guard let self = self, self.retrievalGeneration == gen, !self.isClosedOrExpired else { return false }
                        return self.activeSession?.fields.isEmpty ?? true
                    }
                    if !needsSchema { break }
                    try? await Task.sleep(nanoseconds: delayNs)
                    if Task.isCancelled { break }
                    if let domSchema = await Self.extractSchemaFromBrowserDOM(
                        bundleIDs: hostBundleIDs,
                        formURL: url,
                        fallbackTitle: detectedTitleSnapshot
                    ) {
                        await MainActor.run { [weak self] in
                            guard let self = self, self.retrievalGeneration == gen else { return }
                            self.applyRetrievedSchema(domSchema, sourceURL: url, isAuthoritativeHTTP: false)
                        }
                        break
                    }
                }
            }
            
            await MainActor.run { [weak self] in
                guard let self = self, self.retrievalGeneration == gen else { return }
                self.isAutoRetrievingSchema = false
                self.activeRetrievalURL = nil
            }
        }
    }
    
    @MainActor
    public func applyRetrievedSchema(_ schema: FormSchema, sourceURL url: String, isAuthoritativeHTTP: Bool) {
        guard self.isFormDetected, self.activeSession != nil else {
            return
        }
        if schema.isClosed {
            let reason = schema.closedMessage ?? "This form is no longer accepting responses."
            self.markFormClosed(reason: reason)
            return
        }
        
        // Discard schema if user already navigated to a different form
        if let curURL = self.activeSession?.sourceURL, !curURL.isEmpty {
            let curID = DefaultApplicationFormDetector.extractFormIdentifier(from: curURL)
            let schemaID = DefaultApplicationFormDetector.extractFormIdentifier(from: url)
            if curID != nil && schemaID != nil && curID != schemaID {
                NSLog("[MORPH-FORM] autoRetrieveFormContent: Discarding stale schema for '%@' because active session is '%@'", url, curURL)
                return
            }
        }
        
        self.isClosedOrExpired = false
        self.closedReason = nil
        self.activeSession?.isClosedOrExpired = false
        self.activeSession?.closedReason = nil
        
        let currentTitle = self.activeSession?.formTitle ?? self.detectedFormTitle
        let genericTitles: Set<String> = ["", "application form", "google form", "google forms", "untitled form", "polar"]
        let isCurrentTitleGeneric = genericTitles.contains(DefaultApplicationFormDetector.cleanTitle(currentTitle).lowercased())
        
        if !schema.title.isEmpty && (isAuthoritativeHTTP || isCurrentTitleGeneric) {
            self.detectedFormTitle = schema.title
            self.activeSession?.formTitle = schema.title
        }
        if !schema.description.isEmpty && isAuthoritativeHTTP {
            self.activeSession?.formDescription = schema.description
        }
        
        if !schema.fields.isEmpty {
            let current = self.activeSession?.fields ?? []
            if !isAuthoritativeHTTP && self.hasLoadedSchema && !current.isEmpty {
                // Authoritative HTTP schema with entryKey metadata already loaded:
                // hydrate live values/options/required state from browser DOM without discarding metadata,
                // and add a DOM-rendered Email responder collection question if FB_PUBLIC_LOAD_DATA_ omitted it.
                for field in schema.fields {
                    let normLbl = Self.normalizeFieldLabel(field.label)
                    if (normLbl == "email" || normLbl == "email address"),
                       Self.strictMatchingFieldIndex(for: field.label, in: self.activeSession?.fields ?? []) == nil {
                        var emailField = field
                        emailField.isRequired = true
                        emailField.category = .contact
                        let insertIdx = self.activeSession?.fields.firstIndex(where: { $0.isActionableQuestion }) ?? 0
                        self.objectWillChange.send()
                        self.activeSession?.fields.insert(emailField, at: insertIdx)
                        if !emailField.value.isEmpty {
                            self.browserCapturedFieldIDs.insert(emailField.id)
                        }
                        continue
                    }
                    if !field.value.isEmpty || !field.options.isEmpty || !field.questionType.isEmpty || field.isRequired {
                        self.applyExtractedInput(
                            label: field.label,
                            value: field.value,
                            detectedType: field.questionType,
                            options: field.options,
                            isRequired: field.isRequired
                        )
                    }
                }
            } else if !current.isEmpty {
                // Merge fields preserving any user input or adopting newly discovered metadata
                var merged = schema.fields
                for i in 0..<merged.count {
                    if let matchIdx = Self.bestMatchingFieldIndex(for: merged[i].label, in: current) {
                        let existing = current[matchIdx]
                        if !existing.value.isEmpty {
                            merged[i].value = existing.value
                            merged[i].id = existing.id
                            if !self.manuallyEditedFieldIDs.contains(existing.id) {
                                self.browserCapturedFieldIDs.insert(existing.id)
                            }
                        }
                        if !existing.options.isEmpty && merged[i].options.isEmpty {
                            merged[i].options = existing.options
                        }
                    } else if let existing = current.first(where: {
                        $0.entryKey != nil && $0.entryKey == merged[i].entryKey
                    }) {
                        if !existing.value.isEmpty {
                            merged[i].value = existing.value
                            merged[i].id = existing.id
                            if !self.manuallyEditedFieldIDs.contains(existing.id) {
                                self.browserCapturedFieldIDs.insert(existing.id)
                            }
                        }
                        if !existing.options.isEmpty && merged[i].options.isEmpty {
                            merged[i].options = existing.options
                        }
                    }
                }
                if isAuthoritativeHTTP {
                    for existing in current where existing.isActionableQuestion {
                        let normLbl = Self.normalizeFieldLabel(existing.label)
                        if (normLbl == "email" || normLbl == "email address"),
                           Self.bestMatchingFieldIndex(for: existing.label, in: merged) == nil {
                            var emailField = existing
                            emailField.isRequired = true
                            emailField.category = .contact
                            let insertIdx = merged.firstIndex(where: { $0.isActionableQuestion }) ?? 0
                            merged.insert(emailField, at: insertIdx)
                            if !emailField.value.isEmpty && !self.manuallyEditedFieldIDs.contains(emailField.id) {
                                self.browserCapturedFieldIDs.insert(emailField.id)
                            }
                            break
                        }
                    }
                }
                // Authoritative schema: Only real questions defined by the form platform are retained.
                // Never append non-schema dynamically scanned noise (such as browser tabs or UI chrome).
                self.activeSession?.fields = merged
            } else {
                self.activeSession?.fields = schema.fields
            }
            
            // Auto-update recipientEmail if default and an email field has value
            for field in self.activeSession?.fields ?? [] {
                if (field.category == .contact || field.label.lowercased().contains("email")) && !field.value.isEmpty && field.value.contains("@") {
                    if self.recipientEmail.isEmpty || self.recipientEmail.contains("example.com") || self.recipientEmail.contains("@test.com") {
                        self.setRecipientEmail(field.value)
                    }
                    break
                }
            }
            
            if self.activeSession?.hasRequiredFields == true {
                self.filterMode = .requiredOnly
            }
        }
        
        // Immediately synchronize live inputs from browser
        self.syncLiveFormInputValues(isBackground: !MorphEnvironment.isTestingEnvironment)
        self.advanceToFirstUnansweredFieldIfNeeded()
        self.saveDrafts()
    }
    
    // MARK: - Live Input Hydration & Synchronization
    @MainActor
    public func syncLiveFormInputValues(isBackground: Bool = false, urgent: Bool = false) {
        guard isFormDetected, isAutoCaptureEnabled,
              let session = activeSession else { return }
        let snapshotStartedAt = Date()
        
        // 1. If form source is a local file or file URL, re-parse if any fields are empty
        if let urlStr = session.sourceURL, (urlStr.hasPrefix("/") || urlStr.hasPrefix("file://")) {
            let path = urlStr.hasPrefix("file://") ? (URL(string: urlStr)?.path ?? urlStr.replacingOccurrences(of: "file://", with: "")) : urlStr
            let cleanFilePath: String
            if let qIdx = path.firstIndex(of: "?") {
                cleanFilePath = String(path[..<qIdx])
            } else {
                cleanFilePath = path
            }
            if FileManager.default.fileExists(atPath: cleanFilePath), let content = try? String(contentsOfFile: cleanFilePath, encoding: .utf8) {
                if let schema = FormContentRetriever.parseGenericHTMLForm(content, url: urlStr) {
                    for parsedField in schema.fields {
                        if !parsedField.value.isEmpty || parsedField.isSelection {
                            applyExtractedInput(label: parsedField.label, value: parsedField.value, detectedType: parsedField.questionType, options: parsedField.options, isRequired: parsedField.isRequired)
                        }
                    }
                }
            }
        }
        
        // 2. Scan ONLY the browser hosting the detected form (other browsers/windows may show unrelated pages
        //    whose question labels would otherwise leak answers into this form)
        let targetApps = Self.formHostBrowsers(detectedAppName: detectedAppName)
        let schemaFields = activeSession?.fields ?? []
        
        if isBackground {
            let axStart = snapshotStartedAt
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                var allItems: [ExtractedInputItem] = []
                for app in targetApps {
                    let appElem = AXUIElementCreateApplication(app.processIdentifier)
                    if let items = FormInputAutoTracker.scanBrowserWindowInputItems(appElem: appElem, fields: schemaFields), !items.isEmpty {
                        allItems.append(contentsOf: items)
                    }
                }
                if !allItems.isEmpty {
                    Task { @MainActor [weak self] in
                        self?.applyLiveItemsSnapshot(allItems, snapshotStartedAt: axStart)
                    }
                }
            }
        } else {
            for app in targetApps {
                let appElem = AXUIElementCreateApplication(app.processIdentifier)
                if let items = FormInputAutoTracker.scanBrowserWindowInputItems(appElem: appElem, fields: schemaFields), !items.isEmpty {
                    applyLiveItemsSnapshot(items, snapshotStartedAt: snapshotStartedAt)
                }
            }
        }
        
        // 3. Fallback for scriptable browsers (Safari, Chrome) via AppleScript DOM extraction on background queue
        if isAppleScriptSyncRunning {
            if !isBackground || urgent {
                hasPendingUrgentLiveSync = true
            }
        } else {
            isAppleScriptSyncRunning = true
            hasPendingUrgentLiveSync = false
            let bundleIDs = targetApps.compactMap { $0.bundleIdentifier }
            let targetFormURL = session.sourceURL ?? detectedURL
            let domStart = snapshotStartedAt
            DispatchQueue.global(qos: .utility).async { [weak self] in
                defer {
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        self.isAppleScriptSyncRunning = false
                        if self.hasPendingUrgentLiveSync {
                            self.hasPendingUrgentLiveSync = false
                            self.syncLiveFormInputValues(isBackground: true, urgent: false)
                        }
                    }
                }
                for bid in bundleIDs {
                    if let items = FormInputAutoTracker.extractItemsSnapshotViaAppleScript(bundleID: bid, targetURL: targetFormURL), !items.isEmpty {
                        Task { @MainActor [weak self] in
                            self?.applyLiveItemsSnapshot(items, snapshotStartedAt: domStart)
                        }
                    }
                }
            }
        }
        
        // 3b. Polar Chromium host Blink serialized form state synchronization (active session window only)
        let isPolarHost = detectedBrowserFamily == .polar ||
                          detectedAppName.lowercased() == "polar" ||
                          session.sourceAppName.lowercased() == "polar"
        if isPolarHost, !MorphEnvironment.isTestingEnvironment,
           let formURL = session.sourceURL, !formURL.isEmpty, !schemaFields.isEmpty {
            let startedAt = session.startedAt
            let formID = DefaultApplicationFormDetector.extractFormIdentifier(from: formURL) ?? formURL
            let useLookback = !strictBlinkWindowByFormID.contains(formID)
            let needsBaseline = pendingBlinkBaselineCapture.contains(formID) && ignoredBlinkSignatureByFormID[formID] == nil
            let baselineMaxDate: Date? = lastKeystrokeAt ?? ((Date().timeIntervalSince(startedAt) < 1.5 && !isClosedOrExpired) ? nil : startedAt)
            let blinkSnapAt = snapshotStartedAt
            let applyFilteredBlinkState: @MainActor (
                ApplicationFormModel,
                (pairs: [(label: String, value: String)], signature: String?),
                String?
            ) -> Void = { targetModel, state, preOpenBaseline in
                targetModel.pendingBlinkBaselineCapture.remove(formID)
                if let baseline = preOpenBaseline, targetModel.ignoredBlinkSignatureByFormID[formID] == nil {
                    targetModel.ignoredBlinkSignatureByFormID[formID] = baseline
                }
                if let sig = state.signature {
                    targetModel.lastObservedBlinkSignatureByFormID[formID] = sig
                    if sig == targetModel.ignoredBlinkSignatureByFormID[formID] {
                        return
                    }
                }
                guard !state.pairs.isEmpty else { return }
                targetModel.ignoredBlinkSignatureByFormID.removeValue(forKey: formID)
                let isQuiet = targetModel.lastKeystrokeAt.map { Date().timeIntervalSince($0) >= 0.40 } ?? true
                let currentFields = targetModel.activeSession?.fields ?? []
                for pair in state.pairs {
                    if !isQuiet,
                       let idx = Self.strictMatchingFieldIndex(for: pair.label, in: currentFields) {
                        let existing = currentFields[idx].value
                        if !existing.isEmpty && pair.value.count < existing.count {
                            continue
                        }
                    }
                    targetModel.applyExtractedInput(label: pair.label, value: pair.value, snapshotStartedAt: blinkSnapAt)
                }
            }
            if isBackground {
                DispatchQueue.global(qos: .utility).async { [weak self] in
                    let baselineSig = needsBaseline ? FormInputAutoTracker.extractLatestPolarBlinkSignature(
                        formURL: formURL,
                        sessionStartedAt: .distantPast,
                        maxModificationDate: baselineMaxDate
                    ) : nil
                    let blinkState = FormInputAutoTracker.extractLatestPolarBlinkState(
                        formURL: formURL,
                        fields: schemaFields,
                        sessionStartedAt: startedAt,
                        useLookback: useLookback
                    )
                    guard baselineSig != nil || blinkState.signature != nil || !blinkState.pairs.isEmpty else { return }
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        applyFilteredBlinkState(self, blinkState, baselineSig)
                    }
                }
            } else {
                let baselineSig = needsBaseline ? FormInputAutoTracker.extractLatestPolarBlinkSignature(
                    formURL: formURL,
                    sessionStartedAt: .distantPast,
                    maxModificationDate: baselineMaxDate
                ) : nil
                let blinkState = FormInputAutoTracker.extractLatestPolarBlinkState(
                    formURL: formURL,
                    fields: schemaFields,
                    sessionStartedAt: startedAt,
                    useLookback: useLookback
                )
                applyFilteredBlinkState(self, blinkState, baselineSig)
            }
        }
        
        // 4. Auto-detect recipient email from any field containing email
        for field in activeSession?.fields ?? [] {
            if (field.category == .contact || field.label.lowercased().contains("email")) && !field.value.isEmpty && field.value.contains("@") {
                if recipientEmail.isEmpty || recipientEmail.contains("example.com") || recipientEmail.contains("@test.com") {
                    setRecipientEmail(field.value)
                }
                break
            }
        }
    }
    
    /// Browsers that may host the detected form: the app named by the detection, else the frontmost browser.
    @MainActor
    static func formHostBrowsers(detectedAppName: String) -> [NSRunningApplication] {
        let running = PersonalizedBrowserDetector.rankedRunningBrowsers()
        let name = detectedAppName.lowercased()
        if !name.isEmpty {
            let hosts = running.filter { ($0.localizedName ?? "").lowercased() == name }
            if !hosts.isEmpty { return hosts }
        }
        if let front = NSWorkspace.shared.frontmostApplication, DefaultApplicationFormDetector.isBrowserApplication(front) {
            return [front]
        }
        return []
    }
    
    /// Marks a field's value as read from the browser (eligible for automatic clearing).
    public func markBrowserCaptured(_ id: UUID) {
        browserCapturedFieldIDs.insert(id)
        manuallyEditedFieldIDs.remove(id)
    }
    
    /// True when the session was loaded from a real form schema (fields carry entry keys).
    public var hasLoadedSchema: Bool {
        activeSession?.fields.contains(where: { $0.entryKey != nil }) ?? false
    }
    
    /// Matches a label to an ACTIONABLE question only (never info/section headers). Returns nil when nothing matches.
    nonisolated public static func strictMatchingFieldIndex(for label: String, in fields: [FormInputField]) -> Int? {
        let indices = fields.indices.filter { fields[$0].isActionableQuestion }
        guard !indices.isEmpty else { return nil }
        let subset = indices.map { fields[$0] }
        guard let local = bestMatchingFieldIndex(for: label, in: subset) else { return nil }
        return indices[local]
    }
    
    // MARK: - Hierarchical Label Normalization & Robust Matching
    nonisolated public static func cleanQuestionTitle(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "\\s*\\*+\\s*$", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\s*\\(required\\)\\s*$", with: "", options: [.regularExpression, .caseInsensitive])
        s = s.replacingOccurrences(of: "^(Q\\d+[:.]?|\\d+[.)])\\s*", with: "", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated public static func normalizeFieldLabel(_ label: String) -> String {
        var s = cleanQuestionTitle(label).lowercased()
        s = s.replacingOccurrences(of: "^[*#\\-\\s]+", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "[*:\\-\\s]+$", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "^\\(?\\d+[\\.\\):]?\\s*", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated public static func bestMatchingFieldIndex(for label: String, in fields: [FormInputField]) -> Int? {
        guard !fields.isEmpty else { return nil }
        let rawLabel = cleanQuestionTitle(label)
        guard !rawLabel.isEmpty else { return nil }
        let normInput = normalizeFieldLabel(rawLabel)
        
        // Tier 1: Exact raw match (case-insensitive)
        if let idx = fields.firstIndex(where: { $0.label.caseInsensitiveCompare(rawLabel) == .orderedSame }) {
            return idx
        }
        
        // Tier 2: Exact normalized match
        if !normInput.isEmpty {
            if let idx = fields.firstIndex(where: { normalizeFieldLabel($0.label) == normInput }) {
                return idx
            }
        }
        
        // Tier 3: Token-overlap scoring
        let inputTokens = Set(normInput.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 2 })
        var bestIdx: Int? = nil
        var highestScore: Double = 0.0
        
        for (idx, field) in fields.enumerated() {
            if hasQualifierConflict(rawLabel, field.label) {
                continue
            }
            let normField = normalizeFieldLabel(field.label)
            let fieldTokens = Set(normField.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 2 })
            
            if !inputTokens.isEmpty && !fieldTokens.isEmpty {
                let intersection = inputTokens.intersection(fieldTokens)
                let union = inputTokens.union(fieldTokens)
                let jaccard = Double(intersection.count) / Double(union.count)
                
                let minTokens = min(inputTokens.count, fieldTokens.count)
                let containment = Double(intersection.count) / Double(minTokens)
                
                if containment >= 0.8 && minTokens >= 2 && jaccard >= 0.5 {
                    let score = 0.7 + (jaccard * 0.3)
                    if score > highestScore {
                        highestScore = score
                        bestIdx = idx
                    }
                } else if jaccard >= 0.6 {
                    if jaccard > highestScore {
                        highestScore = jaccard
                        bestIdx = idx
                    }
                }
            }
            
            // Tier 4: Substring match with strict length ratio constraint (>= 0.7)
            if !normInput.isEmpty && !normField.isEmpty {
                if normInput.contains(normField) || normField.contains(normInput) {
                    let minLen = min(normInput.count, normField.count)
                    let maxLen = max(normInput.count, normField.count)
                    let ratio = Double(minLen) / Double(maxLen)
                    if ratio >= 0.7 && minLen >= 4 {
                        let score = 0.5 + (ratio * 0.2)
                        if score > highestScore {
                            highestScore = score
                            bestIdx = idx
                        }
                    }
                }
            }
        }
        
        return bestIdx
    }
    
    @discardableResult
    public func applyExtractedInput(
        label: String,
        value: String,
        detectedType: String? = nil,
        options: [String]? = nil,
        isRequired: Bool? = nil,
        snapshotStartedAt: Date? = nil
    ) -> Bool {
        guard let session = activeSession else { return false }
        let cleanVal = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLbl = Self.cleanQuestionTitle(label)
        guard !cleanLbl.isEmpty else { return false }
        
        let alwaysIgnoredChrome: Set<String> = [
            "address and search bar", "search or enter website name", "ask polar", "morph"
        ]
        let lowerLbl = cleanLbl.lowercased()
        if alwaysIgnoredChrome.contains(lowerLbl) || lowerLbl.hasPrefix("all,") || lowerLbl.hasPrefix("required,") {
            return false
        }
        
        let matchedIdx = Self.strictMatchingFieldIndex(for: cleanLbl, in: session.fields)
        let matchesAuthoritativeSchemaField: Bool = {
            guard let idx = matchedIdx else { return false }
            return session.fields[idx].entryKey != nil ||
                   session.fields[idx].label.caseInsensitiveCompare(cleanLbl) == .orderedSame
        }()
        
        if !matchesAuthoritativeSchemaField {
            let ignoredTitles: Set<String> = [
                "address", "address and search bar", "search", "search or enter website name",
                "back", "forward", "reload", "refresh", "home", "sidebar", "show sidebar", "hide sidebar",
                "extensions", "extension", "profiles", "profiles and menu", "profile", "bookmarks", "bookmark",
                "bookmark this page", "downloads", "history", "settings", "options", "menu", "close", "minimize",
                "zoom", "fullscreen", "new tab", "tab", "tab name", "all", "required", "ask polar", "polar", "morph"
            ]
            if ignoredTitles.contains(lowerLbl) {
                return false
            }
        }
        
        var didUpdate = false
        if let idx = matchedIdx {
            var fieldUpdated = false
            let existingVal = activeSession?.fields[idx].value ?? ""
            let isTypingActively = lastKeystrokeAt.map { Date().timeIntervalSince($0) < 0.45 } ?? false
            let isPreKeystrokeSnapshot: Bool = {
                guard let snapAt = snapshotStartedAt,
                      let lastKey = lastKeystrokeAt,
                      let fid = activeSession?.fields[idx].id,
                      autoTracker?.confirmedFieldID == fid else { return false }
                return snapAt < lastKey
            }()
            let isLaggingTypedSnapshot = isPreKeystrokeSnapshot || (
                isTypingActively &&
                !existingVal.isEmpty &&
                existingVal.lowercased().hasPrefix(cleanVal.lowercased()) &&
                cleanVal.count < existingVal.count
            )
            if !cleanVal.isEmpty && existingVal != cleanVal && !isLaggingTypedSnapshot {
                activeSession?.fields[idx].value = cleanVal
                fieldUpdated = true
            }
            if let dt = detectedType, !dt.isEmpty,
               let existingDT = activeSession?.fields[idx].questionType,
               existingDT != dt {
                let genericTypes: Set<String> = ["", "text", "unknown", "shortAnswer"]
                let specificChoiceTypes: Set<String> = ["linearScale", "grid", "checkboxes", "dropdown", "date", "time", "fileUpload"]
                let wouldDowngradeToShort = (dt == "shortAnswer" && !genericTypes.contains(existingDT))
                let wouldDowngradeLinearToMC = (dt == "multipleChoice" && specificChoiceTypes.contains(existingDT))
                if !wouldDowngradeToShort && !wouldDowngradeLinearToMC {
                    activeSession?.fields[idx].questionType = dt
                    fieldUpdated = true
                }
            }
            if isRequired == true, activeSession?.fields[idx].isRequired == false {
                activeSession?.fields[idx].isRequired = true
                fieldUpdated = true
            }
            if let opts = options, !opts.isEmpty, (activeSession?.fields[idx].options.isEmpty ?? true) {
                activeSession?.fields[idx].options = opts
                fieldUpdated = true
            }
            if fieldUpdated {
                objectWillChange.send()
                lastAutoCapturedAt = Date()
                didUpdate = true
            }
            if let fid = activeSession?.fields[idx].id { browserCapturedFieldIDs.insert(fid) }
        } else if !hasLoadedSchema && (!cleanVal.isEmpty || (options != nil && !options!.isEmpty) || (detectedType != nil && !detectedType!.isEmpty)) {
            // Dynamic field addition when a question is extracted from the web area
            let alreadyExists = session.fields.contains(where: {
                Self.normalizeFieldLabel($0.label) == Self.normalizeFieldLabel(cleanLbl)
            })
            if !alreadyExists {
                let cat = FormContentRetriever.inferCategory(from: cleanLbl)
                let qType = detectedType ?? (cleanLbl.lowercased().contains("why") || cleanLbl.lowercased().contains("about") ? "paragraph" : "shortAnswer")
                let newField = FormInputField(
                    label: cleanLbl,
                    value: cleanVal,
                    category: cat,
                    options: options ?? [],
                    questionType: qType,
                    isRequired: isRequired ?? false
                )
                objectWillChange.send()
                activeSession?.fields.append(newField)
                if !cleanVal.isEmpty {
                    browserCapturedFieldIDs.insert(newField.id)
                }
                lastAutoCapturedAt = Date()
                didUpdate = !cleanVal.isEmpty
            }
        }
        
        // Auto-update recipientEmail if value is a valid email
        let isContact = cleanLbl.lowercased().contains("email")
        if didUpdate && cleanVal.contains("@") && cleanVal.contains(".") && cleanVal.count >= 5 {
            if isContact || recipientEmail.isEmpty || recipientEmail.contains("example.com") || recipientEmail.contains("@test.com") {
                setRecipientEmail(cleanVal)
            }
        }
        
        if didUpdate {
            saveDrafts()
            advanceToFirstUnansweredFieldIfNeeded()
        }
        
        return didUpdate
    }
    
    /// Applies a full browser snapshot of ExtractedInputItem records, updating values, format, and choices.
    @discardableResult
    public func applyLiveItemsSnapshot(_ items: [ExtractedInputItem], now: Date = Date(), snapshotStartedAt: Date? = nil) -> Int {
        guard isFormDetected, isAutoCaptureEnabled, let session = activeSession else { return 0 }
        
        if items.contains(where: { $0.label == "__FORM_SUBMITTED__" || $0.questionType == "submitted" }) {
            if !(activeSession?.isSubmitted ?? true) && (activeSession?.answeredCount ?? 0) > 0 {
                markFormSubmitted()
            }
            return 0
        }
        
        if let closedItem = items.first(where: { $0.label == "__FORM_CLOSED__" || $0.questionType == "closed" }) {
            let reason = !closedItem.value.isEmpty ? closedItem.value : "This form is no longer accepting responses."
            markFormClosed(reason: reason)
            return 0
        }
        
        let nonEmpties = items.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // 1. Check if the entire form was cleared in the browser (all scanned inputs are empty while Morph had answers)
        let lastCapture = lastKeystrokeAt ?? lastAutoCapturedAt
        let isQuiet = lastCapture.map { now.timeIntervalSince($0) >= Self.clearGuardInterval } ?? true
        if nonEmpties.isEmpty && !items.isEmpty && session.answeredCount > 0 {
            // Ensure the empty items in the snapshot actually correspond to the answered fields of this form
            let answeredFields = session.fields.filter { $0.isAnswered }
            let hasNoManualEdits = answeredFields.allSatisfy { !self.manuallyEditedFieldIDs.contains($0.id) }
            let matchedAnsweredCount = answeredFields.filter { field in
                items.contains(where: { ApplicationFormModel.strictMatchingFieldIndex(for: $0.label, in: [field]) != nil }) ||
                items.contains(where: { Self.normalizeFieldLabel($0.label) == Self.normalizeFieldLabel(field.label) })
            }.count
            
            // Multi-field clear (e.g. "Clear form" clicked clearing 2+ questions simultaneously):
            let isMultiFieldClear = (matchedAnsweredCount >= 2 && hasNoManualEdits)
            // Single-field full clear during quiet period:
            let isQuietFullClear = (isQuiet && matchedAnsweredCount > 0 && hasNoManualEdits)
            // Reopened form confirmed empty by first live snapshot (bypasses clearGuardInterval & manual edits):
            let isReopenConfirmedEmpty = (awaitingReopenSnapshotClear && matchedAnsweredCount > 0)
            
            if isMultiFieldClear || isQuietFullClear || isReopenConfirmedEmpty {
                let clearedCount = session.answeredCount
                clearAllFormAnswers()
                awaitingReopenSnapshotClear = false
                return clearedCount
            }
        }
        
        var changed = 0
        // Apply all items (updating answers, question format, required status, and options)
        for item in items {
            if applyExtractedInput(
                label: item.label,
                value: item.value,
                detectedType: item.questionType,
                options: item.options,
                isRequired: item.isRequired,
                snapshotStartedAt: snapshotStartedAt
            ) {
                changed += 1
            }
        }
        
        // Check for individual cleared fields
        let empties = items.filter { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let allowReopenClear = awaitingReopenSnapshotClear
        for item in empties {
            guard let idx = ApplicationFormModel.strictMatchingFieldIndex(for: item.label, in: session.fields) ??
                            session.fields.firstIndex(where: { Self.normalizeFieldLabel($0.label) == Self.normalizeFieldLabel(item.label) }) else { continue }
            let field = session.fields[idx]
            guard !field.value.isEmpty else { continue }
            if !allowReopenClear {
                guard !manuallyEditedFieldIDs.contains(field.id) else { continue }
                if let last = lastCapture, now.timeIntervalSince(last) < Self.clearGuardInterval { continue }
            }
            objectWillChange.send()
            activeSession?.fields[idx].value = ""
            browserCapturedFieldIDs.remove(field.id)
            if allowReopenClear {
                manuallyEditedFieldIDs.remove(field.id)
            }
            changed += 1
        }
        
        if awaitingReopenSnapshotClear, let curFields = activeSession?.fields {
            let matchedAnySchemaQuestion = items.contains { item in
                ApplicationFormModel.strictMatchingFieldIndex(for: item.label, in: curFields) != nil ||
                curFields.contains(where: { Self.normalizeFieldLabel($0.label) == Self.normalizeFieldLabel(item.label) })
            }
            if matchedAnySchemaQuestion {
                awaitingReopenSnapshotClear = false
            }
        }
        
        if changed > 0 {
            saveDrafts()
            advanceToFirstUnansweredFieldIfNeeded()
        }
        return changed
    }
    
    /// Applies a full browser snapshot of question/answer pairs.
    @discardableResult
    public func applyLiveSnapshot(_ pairs: [(label: String, value: String)], now: Date = Date()) -> Int {
        return applyLiveItemsSnapshot(pairs.map { ExtractedInputItem(label: $0.label, value: $0.value) }, now: now)
    }
    
    /// Resets all field answers to empty strings, clears browser capture tracking, and advances to the first field.
    @MainActor
    public func clearAllFormAnswers() {
        guard let session = activeSession else { return }
        objectWillChange.send()
        for i in 0..<session.fields.count {
            activeSession?.fields[i].value = ""
        }
        browserCapturedFieldIDs.removeAll()
        manuallyEditedFieldIDs.removeAll()
        lastAutoCapturedAt = Date()
        saveDrafts()
        advanceToFirstUnansweredFieldIfNeeded()
    }

    public func selectActiveField(_ index: Int) {
        guard let fields = activeSession?.fields, index >= 0 && index < fields.count else { return }
        objectWillChange.send()
        self.activeFieldIndex = index
        self.autoTracker?.confirmFocus(fieldID: fields[index].id)
    }
    
    public func updateFieldByIndex(_ index: Int, value: String) {
        guard let fields = activeSession?.fields, index >= 0 && index < fields.count else { return }
        objectWillChange.send()
        browserCapturedFieldIDs.remove(fields[index].id)
        manuallyEditedFieldIDs.insert(fields[index].id)
        activeSession?.fields[index].value = value
        lastAutoCapturedAt = Date()
        saveDrafts()
    }
    
    public func setRecipientEmail(_ email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        self.recipientEmail = trimmed
        if activeSession != nil {
            activeSession?.recipientEmail = trimmed
        }
        saveDrafts()
    }
    
    // MARK: - Field Management
    public func addField(
        label: String,
        value: String,
        category: FormFieldCategory = .custom,
        options: [String] = [],
        questionType: String = "shortAnswer"
    ) {
        guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        if activeSession == nil {
            startTracking()
        }
        
        let field = FormInputField(
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            value: value.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            options: options,
            questionType: questionType
        )
        
        activeSession?.fields.append(field)
        saveDrafts()
        
        // If user entered an email field, auto-suggest or update recipientEmail
        if category == .contact || label.lowercased().contains("email") {
            let emailCandidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if emailCandidate.contains("@") && (category == .contact || recipientEmail.isEmpty || recipientEmail.contains("example.com") || recipientEmail.contains("@test.com")) {
                setRecipientEmail(emailCandidate)
            }
        }
    }
    
    public func updateField(id: UUID, value: String) {
        guard let idx = activeSession?.fields.firstIndex(where: { $0.id == id }) else { return }
        objectWillChange.send()
        browserCapturedFieldIDs.remove(id)
        manuallyEditedFieldIDs.insert(id)
        activeSession?.fields[idx].value = value
        saveDrafts()
    }
    
    public func removeField(id: UUID) {
        activeSession?.fields.removeAll(where: { $0.id == id })
        saveDrafts()
    }
    
    public func clearFields() {
        activeSession?.fields.removeAll()
    }
    
    /// Parses clipboard text or multi-line key-value entries into fields.
    /// Handles lines like "Full Name: John Doe", "Email: john@test.com", "Why Stripe: I love APIs".
    @discardableResult
    public func parseAndAddFromClipboard(rawText: String) -> Int {
        let lines = rawText.components(separatedBy: .newlines)
        var addedCount = 0
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            
            if let colonIdx = line.firstIndex(of: ":") {
                let key = String(line[..<colonIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
                let val = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !key.isEmpty && !val.isEmpty {
                    let cat = inferCategory(from: key)
                    addField(label: key, value: val, category: cat)
                    addedCount += 1
                    continue
                }
            }
            
            // If line contains no colon but is non-empty, add as general response entry
            if line.count >= 3 {
                addField(label: "Answer / Note \( (activeSession?.fields.count ?? 0) + 1 )", value: line, category: .question)
                addedCount += 1
            }
        }
        
        return addedCount
    }
    
    private func inferCategory(from key: String) -> FormFieldCategory {
        let k = key.lowercased()
        if k.contains("name") || k.contains("pronoun") || k.contains("citizenship") {
            return .personal
        } else if k.contains("email") || k.contains("phone") || k.contains("address") || k.contains("linkedin") || k.contains("github") || k.contains("portfolio") || k.contains("website") {
            return .contact
        } else if k.contains("experience") || k.contains("salary") || k.contains("compensation") || k.contains("education") || k.contains("school") || k.contains("degree") || k.contains("company") || k.contains("title") || k.contains("skills") {
            return .experience
        } else if k.contains("why") || k.contains("tell us") || k.contains("cover letter") || k.contains("statement") || k.contains("question") || k.contains("challenge") || k.contains("summary") || k.contains("project") {
            return .question
        }
        return .custom
    }
    
    // MARK: - Email Dispatch (Deprecated - Replaced by Supabase Memory Storage)
    public func dispatchEmailCopy() async -> Bool {
        _ = saveFormSnapshot(flashLabel: false)
        showToast("Saved copy to Supabase Memory!")
        return true
    }
    
    // MARK: - Utilities
    public func copySummaryToClipboard() {
        guard let summary = activeSession?.formattedSummary else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
        showToast("Summary copied to clipboard!")
    }
    
    public func appendSummaryToScratchpad(_ scratchpad: ScratchpadModel) {
        guard let summary = activeSession?.formattedSummary else { return }
        let current = scratchpad.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = current.isEmpty ? summary : "\(current)\n\n\(summary)"
        scratchpad.text = combined
        showToast("Saved copy into Notes!")
    }
    
    public func showToast(_ msg: String) {
        deliveryToastMessage = msg
        toastDismissTask?.cancel()
        toastDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled else { return }
            self?.deliveryToastMessage = nil
        }
    }
    
    public func dismissToast() {
        toastDismissTask?.cancel()
        deliveryToastMessage = nil
    }
}
