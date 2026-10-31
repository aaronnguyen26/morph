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
        activeFieldIndex: Int = 0
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
        
        if fields.isEmpty {
            lines.append("*(No fields captured)*")
        } else {
            for (idx, field) in fields.enumerated() {
                if field.questionType == "info" {
                    lines.append("### ℹ️ \(field.label)")
                    if !field.questionDescription.isEmpty {
                        lines.append(field.questionDescription)
                    }
                    lines.append("")
                } else {
                    let reqBadge = field.isRequired ? " *(Required)*" : ""
                    lines.append("### \(idx + 1). \(field.label)\(reqBadge) [\(field.category.rawValue)]")
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
        }
        lines.append("---")
        lines.append("*Captured automatically by Morph Context Engine • Form Copilot*")
        return lines.joined(separator: "\n")
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
            hostMatches: ["docs.google.com/forms"],
            pathPrefixes: ["/forms/d/", "/forms/u/", "/viewform", "/formresponse", "/edit"],
            titleSuffixes: ["- Google Forms", "— Google Forms", "| Google Forms", "· Google Forms", "- Google Form", "Google Forms:"],
            defaultFormName: "Google Form"
        ),
        FormPlatformSignature(
            type: .googleForms,
            hostMatches: ["forms.google.com", "forms.gle"],
            pathPrefixes: [],
            titleSuffixes: ["- Google Forms", "— Google Forms", "| Google Forms", "· Google Forms", "- Google Form", "Google Forms:"],
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
    
    public init(title: String, description: String = "", fields: [FormInputField]) {
        self.title = title
        self.description = description
        self.fields = fields
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
        "twitter.com", "x.com", "threads.net", "facebook.com", "instagram.com"
    ]
    
    public static func isBlacklistedURL(_ urlString: String) -> Bool {
        let lower = urlString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty else { return false }
        
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
    public static func isFormTitle(_ title: String) -> Bool {
        let lower = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty else { return false }
        
        // 0. Antigravity, AI agent tools, and coding IDE windows are strictly NEVER forms
        if lower.contains("antigravity") || lower.contains("gemini") { return false }
        
        // 0b. Source code, test, project, configuration or script files are NEVER forms
        let codeExtensions = [
            ".swift", ".ts", ".tsx", ".js", ".jsx", ".py", ".json", ".md", ".rs", ".go",
            ".java", ".kt", ".cpp", ".c", ".h", ".hpp", ".rb", ".sh", ".yaml", ".yml",
            ".toml", ".css", ".scss", ".html", ".lock", ".pbxproj", ".xctest", ".xcodeproj"
        ]
        for ext in codeExtensions {
            if lower.contains(ext) {
                return false
            }
        }
        
        // 0c. Reject Negative Non-Form Site Titles (News, Wikis, Repos, LMS)
        let negativeTitleIndicators = [
            " - wikipedia", " | wikipedia", " - youtube", " | youtube",
            " - github", " · pull request", " · issue #",
            " - canvas", " | instructure", " - blackboard", " | blackboard",
            " - google classroom", " | google classroom",
            " - medium", " | medium", " - substack", " | substack",
            " - stack overflow", " | stack overflow",
            "the new york times", "the washington post", "the wall street journal",
            "the verge", "techcrunch", "bloomberg"
        ]
        for neg in negativeTitleIndicators {
            if lower.contains(neg) && !lower.contains("google forms") && !lower.contains("application form") {
                return false
            }
        }
        
        // Reject non-form reading papers and syllabus materials
        if (lower.contains("reading response") || lower.contains("syllabus") || lower.contains("lecture ")) && !lower.contains("google forms") {
            return false
        }
        
        // Reject common non-form review phrases
        if (lower.hasSuffix(" review") || lower.hasSuffix(" reviews")) && !lower.contains("peer review form") {
            return false
        }
        
        // 1. Known Platform Service Suffixes & Brand Markers
        for p in FormPlatformRegistry.platforms {
            for s in p.titleSuffixes {
                if lower.contains(s.lowercased()) {
                    return true
                }
            }
        }
        
        // Direct Google Forms title identifiers
        if lower.contains(" - google forms") || lower.contains(" · google forms") ||
           lower.contains(" | google forms") || lower.contains("— google forms") ||
           lower.contains("google forms:") || lower.contains("google forms") ||
           lower.contains("untitled form") {
            return true
        }
        
        // Specific qualified forms recognized across platforms
        if lower.contains("laguna schools") && (lower.contains("ia/sa") || lower.contains("application")) {
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
            if lower.contains(phrase) {
                return true
            }
        }
        
        // 3. Qualified Compound Suffixes
        if lower.hasSuffix(" application form") || lower.hasSuffix(" registration form") ||
           lower.hasSuffix(" feedback form") || lower.hasSuffix(" intake form") ||
           lower.hasSuffix(" inquiry form") || lower.hasSuffix(" survey form") {
            return true
        }
        
        // Suffix patterns for applications: e.g. "... Application", "... Questionnaire", "... Survey"
        if lower.hasSuffix(" application") || lower.hasSuffix(" questionnaire") ||
           lower.hasSuffix(" survey") || lower.hasSuffix(" registration") ||
           lower.hasSuffix(" sign-up") || lower.hasSuffix(" signup") {
            // Reject non-form phrases: "web application", "ios application", "literature survey"
            if !lower.contains("web application") && !lower.contains("ios application") &&
               !lower.contains("mac application") && !lower.contains("literature survey") {
                return true
            }
        }
        
        // 4. E-Signature Documents & Qualified PDF Forms
        if lower.hasPrefix("please docusign:") || lower.hasPrefix("please sign:") {
            return true
        }
        if lower.hasSuffix(".pdf") {
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
           path.hasSuffix("/job-application") || path.contains("/job-application/") {
            return true
        }
        
        return false
    }
    
    public static func cleanTitle(_ rawTitle: String) -> String {
        var title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            " - Google Chrome Canary",
            " - Google Chrome",
            " - Chromium",
            " - Safari Technology Preview",
            " - Safari",
            " - Polar",
            " - Comet",
            " - Brave Browser Beta",
            " - Brave Browser",
            " - Brave",
            " - Microsoft Edge Canary",
            " - Microsoft Edge Dev",
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
            " - Opera",
            " - Orion",
            " - DuckDuckGo",
            " - Tor Browser",
            " - Floorp",
            " - Waterfox",
            " - LibreWolf",
            " - SigmaOS"
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
    /// Searching kAXWindowsAttribute and checking focused/main windows for a titled content window succeeds reliably.
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
        }
        
        // 2. Prioritize window on the primary/notch display
        let windows = getAllBrowserWindows(appElem: appElem)
        for win in windows {
            let (sIdx, _) = screenForWindow(win)
            if sIdx == 0 { // Primary / Notch screen
                var tRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &tRef) == .success,
                   let t = (tRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !t.isEmpty && t.lowercased() != "polar" {
                    return win
                }
            }
        }
        
        // 3. Fallback to any titled window
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
        let maxVisited = 150
        
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
            if role == "AXTextField" || role == "AXSearchField" || role == "AXComboBox" {
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
                                        desc.localizedCaseInsensitiveContains("url")
                    let looksLikeURL = !trimmed.contains(" ") && (
                        trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") ||
                        trimmed.contains("://") ||
                        trimmed.contains("docs.google.com") ||
                        trimmed.contains("forms.gle") ||
                        trimmed.contains(".com/") || trimmed.contains(".org/") ||
                        trimmed.contains(".net/") || trimmed.contains(".io/") ||
                        trimmed.contains(".so/") || trimmed.contains(".edu/")
                    )
                    if (isAddressDesc || looksLikeURL) && !trimmed.isEmpty {
                        return trimmed
                    }
                }
            }
            
            // Speed optimization: limit depth to 10 and skip scroll areas
            if depth >= 10 { continue }
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
    
    /// Specialized check for Polar Browser:
    /// High-performance native inspection combining sub-millisecond AXUIElement tree inspection
    /// Universal detector for Polar Browser: checks the active on-screen window
    /// and Polar Chromium host session data. Strictly suppresses background tabs.
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
        
        // 1. Identify Polar's active/focused content window
        var activeWin: AXUIElement? = getBrowserWindowElement(appElem: appElem)
        if activeWin == nil {
            var focusedWinRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElem, kAXFocusedWindowAttribute as CFString, &focusedWinRef) == .success,
               let fWin = focusedWinRef {
                activeWin = (fWin as! AXUIElement)
            }
        }
        if activeWin == nil {
            var mainWinRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElem, kAXMainWindowAttribute as CFString, &mainWinRef) == .success,
               let mWin = mainWinRef {
                activeWin = (mWin as! AXUIElement)
            }
        }
        if activeWin == nil {
            let windows = getAllBrowserWindows(appElem: appElem)
            activeWin = windows.first
        }
        
        // 2. Extract active window title (via AX or WindowServer layer 0 window)
        var winTitle = ""
        if let win = activeWin {
            var titleRef: CFTypeRef?
            let tErr = AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
            if tErr == .success, let t = titleRef as? String {
                winTitle = t.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            NSLog("[MORPH-FORM] checkPolarBrowser activeWin title: tErr=%d, winTitle='%@'", tErr.rawValue, winTitle)
        }
        
        // If AX title was empty or generic, inspect the front layer 0 window of Polar from WindowServer
        if winTitle.isEmpty || winTitle.lowercased() == "polar" {
            let options = CGWindowListOption.excludeDesktopElements
            if let winList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
                var foundWSTitles: [String] = []
                for win in winList {
                    let owner = (win[kCGWindowOwnerName as String] as? String ?? "").lowercased()
                    let layer = win[kCGWindowLayer as String] as? Int ?? -1
                    let bounds = win[kCGWindowBounds as String] as? [String: Any] ?? [:]
                    let h = bounds["Height"] as? CGFloat ?? 0
                    if owner.contains("polar") && layer == 0 && h > 100 {
                        let t = (win[kCGWindowName as String] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        foundWSTitles.append(t)
                        if !t.isEmpty && t.lowercased() != "polar" && winTitle.isEmpty {
                            winTitle = t
                        }
                    }
                }
                NSLog("[MORPH-FORM] checkPolarBrowser WS titles: count=%d, titles=%@, chosen='%@'", winList.count, foundWSTitles.joined(separator: " | "), winTitle)
            }
        }
        
        // 3. Inspect active window URL & Title
        let addressURL = activeWin.flatMap { findAddressBarOrWebAreaURL(in: $0) }
        
        // Strict Immediate Rejection: if address bar has a blacklisted non-form URL (Canvas, Blackboard, Wikipedia, ArXiv, Google Docs, etc.)
        if let aURL = addressURL, FormExclusionRegistry.isBlacklistedURL(aURL) {
            NSLog("[MORPH-FORM] checkPolarBrowser: URL is explicitly blacklisted non-form ('%@'). Suppressing.", aURL)
            return nil
        }
        
        let isURLForm = addressURL != nil && isFormURL(addressURL!)
        let isTitleForm = !winTitle.isEmpty && isFormTitle(winTitle)
        let cleaned = cleanTitle(winTitle)
        
        // Match against recent Polar session forms on disk only when we have a confirmed form URL or form title
        var sessionMatch: (url: String, title: String)? = nil
        let strippedTitle = stripServiceSuffixes(cleaned)
        let genericTitles = ["", "polar", "google forms", "google form", "untitled form", "application form"]
        let isSpecificTitle = !genericTitles.contains(strippedTitle.lowercased())
        
        if isURLForm || isTitleForm {
            if isSpecificTitle {
                sessionMatch = readPolarSessionForm(filterTitle: strippedTitle, filterURL: addressURL)
            } else if let aURL = addressURL, isURLForm {
                sessionMatch = readPolarSessionForm(filterTitle: nil, filterURL: aURL)
            }
        }
        
        // Strict Suppression: If the active window has active content and neither URL nor title is a form:
        // NEVER search background windows or session files for unrelated forms!
        let hasActiveContent = (!cleaned.isEmpty && cleaned.lowercased() != "polar") || (addressURL != nil && !addressURL!.isEmpty)
        if hasActiveContent && !isTitleForm && !isURLForm {
            NSLog("[MORPH-FORM] checkPolarBrowser: Active window is non-form content ('%@', url='%@'). Suppressing background form tabs.", winTitle, addressURL ?? "nil")
            return nil
        }
        
        NSLog("[MORPH-FORM] checkPolarBrowser: winTitle='%@', addressURL='%@', isURLForm=%d, isTitleForm=%d, sessionMatch=%@", winTitle, addressURL ?? "nil", isURLForm ? 1 : 0, isTitleForm ? 1 : 0, sessionMatch?.url ?? "nil")
        
        if isURLForm || isTitleForm || sessionMatch != nil {
            // Live addressURL and live window title ALWAYS take precedence over disk session files
            var finalURL = isURLForm ? addressURL : sessionMatch?.url
            var finalTitle = isSpecificTitle ? cleaned : (sessionMatch?.title ?? (finalURL.flatMap { formNameFromURL($0) } ?? (cleaned.isEmpty || cleaned.lowercased() == "polar" ? "Google Form" : cleaned)))
            
            if finalURL == nil && isSpecificTitle {
                if let session = readPolarSessionForm(filterTitle: strippedTitle, filterURL: nil) {
                    finalURL = session.url
                    if finalTitle.isEmpty || finalTitle == "Google Form" || finalTitle.lowercased() == "polar" {
                        finalTitle = session.title
                    }
                }
            }
            
            let (screenIdx, screenName) = activeWin != nil ? screenForWindow(activeWin!) : (nil, nil)
            return FormDetectionResult(
                isDetected: true,
                title: finalTitle,
                appName: "Polar",
                url: finalURL,
                browserFamily: .polar,
                screenIndex: screenIdx,
                screenName: screenName
            )
        }
        
        // Active window is NOT a form (e.g. YouTube, Google Docs, Colab). Background tabs are strictly ignored.
        return nil
    }
    
    /// Reads the active form URL and page title directly from Chromium family host session binary data
    /// (Polar, Google Chrome, Brave, Arc, Edge, and user-data-dir profiles)
    public static func readChromiumSessionForm(filterTitle: String? = nil, filterURL: String? = nil, polarOnly: Bool = false) -> (url: String, title: String)? {
        var possibleDirs: [String] = []
        if polarOnly {
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
        } else {
            let bases = [
                ("~/Library/Application Support/com.polar.browser.host" as NSString).expandingTildeInPath,
                ("~/Library/Application Support/Google/Chrome" as NSString).expandingTildeInPath,
                ("~/Library/Application Support/Google/Chrome Canary" as NSString).expandingTildeInPath,
                ("~/Library/Application Support/Chromium" as NSString).expandingTildeInPath,
                ("~/Library/Application Support/Microsoft Edge" as NSString).expandingTildeInPath,
                ("~/Library/Application Support/BraveSoftware/Brave-Browser" as NSString).expandingTildeInPath,
                ("~/Library/Application Support/Arc/User Data" as NSString).expandingTildeInPath,
                ("~/Library/Application Support/Vivaldi" as NSString).expandingTildeInPath
            ]
            for base in bases {
                possibleDirs.append((base as NSString).appendingPathComponent("Sessions"))
                possibleDirs.append((base as NSString).appendingPathComponent("Default/Sessions"))
                if let subdirs = try? FileManager.default.contentsOfDirectory(atPath: base) {
                    for sub in subdirs {
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
        }
        
        var sessionFiles: [(path: String, mtime: Date)] = []
        for dir in possibleDirs {
            if let files = try? FileManager.default.contentsOfDirectory(atPath: dir) {
                for file in files where file.hasPrefix("Session_") || file.hasPrefix("Tabs_") {
                    let fullPath = (dir as NSString).appendingPathComponent(file)
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                       let mtime = attrs[.modificationDate] as? Date {
                        // Consider sessions modified within the last 24 hours
                        if abs(mtime.timeIntervalSinceNow) < 86400 {
                            sessionFiles.append((fullPath, mtime))
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
        

        for (filePath, _) in sessionFiles.prefix(32) {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else { continue }
            
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
                        
                        // If this entry is a dead "Page Not Found" page, skip to next match
                        if foundTitle.localizedCaseInsensitiveContains("Page Not Found") {
                            searchRange = urlEnd..<data.endIndex
                            continue
                        }
                        
                        // Strictly reject blacklisted non-form URLs
                        guard !FormExclusionRegistry.isBlacklistedURL(cleanURL) else {
                            searchRange = urlEnd..<data.endIndex
                            continue
                        }
                        
                        let fallbackTitle = formNameFromURL(cleanURL) ?? "Google Form"
                        let resTitle = (foundTitle.isEmpty || foundTitle.contains("Page Not Found")) ? fallbackTitle : foundTitle
                        
                        if let fURL = filterURL, !fURL.isEmpty {
                            let cleanF = fURL.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
                            let cleanC = cleanURL.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
                            let idF = extractFormIdentifier(from: fURL)
                            let idC = extractFormIdentifier(from: cleanURL)
                            if (idF != nil && idC != nil && idF == idC) || cleanC.contains(cleanF) || cleanF.contains(cleanC) {
                                return (cleanURL, resTitle)
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
                                    return (cleanURL, resTitle)
                                }
                            }
                        }
                    }
                    searchRange = urlEnd..<data.endIndex
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
        let isSafariAlive = NSWorkspace.shared.runningApplications.contains { app in
            !app.isTerminated && kill(app.processIdentifier, 0) == 0 &&
            (app.bundleIdentifier?.lowercased().contains("com.apple.safari") ?? false ||
             app.localizedName?.lowercased() == "safari")
        }
        guard isSafariAlive else { return nil }
        
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
        guard let output = Self.executeSimpleAppleScript(script), !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: " ||| ")
        let url = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawTitle = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        
        // Strict Immediate Rejection: if address bar has a blacklisted non-form URL
        if !url.isEmpty && FormExclusionRegistry.isBlacklistedURL(url) {
            return nil
        }
        
        let isDetectedByURL = !url.isEmpty && Self.isFormURL(url)
        let isDetectedByTitle = !rawTitle.isEmpty && Self.isFormTitle(rawTitle)
        
        if isDetectedByURL || isDetectedByTitle {
            let cleaned = Self.cleanTitle(rawTitle)
            let finalTitle: String
            if cleaned.isEmpty || cleaned.localizedCaseInsensitiveContains("not found") || cleaned.localizedCaseInsensitiveContains("untitled") {
                finalTitle = Self.formNameFromURL(url) ?? "Google Form"
            } else {
                finalTitle = cleaned
            }
            return FormDetectionResult(
                isDetected: true,
                title: finalTitle,
                appName: "Safari",
                url: isDetectedByURL ? url : nil,
                browserFamily: .safari
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
        let isDetectedByTitle = !rawTitle.isEmpty && Self.isFormTitle(rawTitle)
        let cleaned = Self.cleanTitle(rawTitle)
        
        // Strict suppression if active window content is known and not a form
        let hasActiveContent = (!cleaned.isEmpty && cleaned.lowercased() != appName.lowercased()) || !url.isEmpty
        if hasActiveContent && !isDetectedByURL && !isDetectedByTitle {
            return nil
        }
        
        var sessionMatch: (url: String, title: String)? = nil
        let strippedTitle = Self.stripServiceSuffixes(cleaned)
        let genericTitles = ["", "google forms", "google form", "untitled form", "application form", appName.lowercased()]
        let isSpecificTitle = !genericTitles.contains(strippedTitle.lowercased())
        if isDetectedByURL || isDetectedByTitle {
            sessionMatch = Self.readChromiumSessionForm(filterTitle: isSpecificTitle ? strippedTitle : nil, filterURL: !url.isEmpty ? url : nil, polarOnly: false)
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
        
        let isDetectedByURL = !url.isEmpty && Self.isFormURL(url)
        let isDetectedByTitle = !rawTitle.isEmpty && Self.isFormTitle(rawTitle)
        
        if isDetectedByURL || isDetectedByTitle {
            let cleaned = Self.cleanTitle(rawTitle)
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
                let isDetectedByURL = !url.isEmpty && Self.isFormURL(url)
                let isDetectedByTitle = !rawTitle.isEmpty && Self.isFormTitle(rawTitle)
                if isDetectedByURL || isDetectedByTitle {
                    let cleaned = Self.cleanTitle(rawTitle)
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
        let isDetectedByURL = url != nil && Self.isFormURL(url!)
        let isDetectedByTitle = !rawTitle.isEmpty && Self.isFormTitle(rawTitle)
        
        if isDetectedByURL || isDetectedByTitle {
            let cleaned = Self.cleanTitle(rawTitle)
            let finalTitle: String
            if cleaned.isEmpty || cleaned.localizedCaseInsensitiveContains("not found") || cleaned.localizedCaseInsensitiveContains("untitled") {
                finalTitle = (url != nil ? Self.formNameFromURL(url!) : nil) ?? "Google Form"
            } else {
                finalTitle = cleaned
            }
            return FormDetectionResult(
                isDetected: true,
                title: finalTitle,
                appName: appName,
                url: url,
                browserFamily: .unknown
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
    
    // MARK: - Detect Active Form Across Frontmost On-Screen Context
    public func detectActiveApplicationForm() -> FormDetectionResult {
        // 1. Strictly inspect Frontmost Application context
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return FormDetectionResult(isDetected: false)
        }
        
        let bundleID = frontApp.bundleIdentifier?.lowercased() ?? ""
        let frontAppName = frontApp.localizedName ?? "Application"
        let frontPID = frontApp.processIdentifier
        
        // NEVER detect Antigravity, Morph, code editors, or developer/communication apps as forms
        if Self.isNonFormApplication(bundleID: bundleID, appName: frontAppName) {
            return FormDetectionResult(isDetected: false)
        }
        
        // 2. If frontmost application is a browser:
        let isBrowser = Self.isBrowserApplication(frontApp)
        if isBrowser {
            let family = PersonalizedBrowserDetector.engineFamily(for: bundleID, name: frontAppName)
            
            // Inspect active tab / front window of the frontmost browser
            if let result = checkBrowserByFamily(family: family, appName: frontAppName, bundleID: bundleID, app: frontApp), result.isDetected {
                NSLog("[MORPH-FORM] Browser family %@ MATCHED form: title=%@, url=%@", family.rawValue, result.title ?? "nil", result.url ?? "nil")
                return result
            }
            
            NSLog("[MORPH-FORM] Front browser %@ (%@, family: %@) active tab is NOT a form", frontAppName, bundleID, family.rawValue)
            return FormDetectionResult(isDetected: false)
        }
        
        NSLog("[MORPH-FORM] Front app is NOT a browser: %@ (%@)", frontAppName, bundleID)
        
        // 3. If frontmost application is a dedicated PDF viewer viewing an actual .pdf document
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
        }
        
        // User is in another app (Terminal, Slack, Notes, Finder, etc.) -> strictly suppressed
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
    public var dispatchedAt: Date
    
    public init(success: Bool, message: String, dispatchedAt: Date = Date()) {
        self.success = success
        self.message = message
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
        let subject = "Copy of Your Application: \(session.formTitle)"
        let body = session.formattedSummary
        let recipient = session.recipientEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !recipient.isEmpty else {
            return EmailDispatchResult(success: false, message: "No recipient email provided")
        }
        
        // First try native macOS Mail via AppleScript (creates and sends message cleanly)
        let escapedSubject = subject.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
        let escapedRecipient = recipient.replacingOccurrences(of: "\"", with: "\\\"")
        
        let appleScriptSource = """
        tell application "Mail"
            try
                set msg to make new outgoing message with properties {subject:"\(escapedSubject)", content:"\(escapedBody)\\n", visible:false}
                tell msg
                    make new to recipient at end of to recipients with properties {address:"\(escapedRecipient)"}
                    send
                end tell
                return "sent"
            on error errMsg
                return errMsg
            end try
        end tell
        """
        
        if let appleScript = NSAppleScript(source: appleScriptSource) {
            var errorInfo: NSDictionary?
            let output = appleScript.executeAndReturnError(&errorInfo)
            let resultStr = output.stringValue ?? ""
            if resultStr == "sent" {
                return EmailDispatchResult(success: true, message: "Email sent via Mail.app to \(recipient)")
            }
        }
        
        // Fallback: Mailto URL
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let mailtoURL = URL(string: "mailto:\(recipient)?subject=\(encodedSubject)&body=\(encodedBody)") {
            _ = await MainActor.run {
                NSWorkspace.shared.open(mailtoURL)
            }
            return EmailDispatchResult(success: true, message: "Drafted copy to \(recipient)")
        }
        
        return EmailDispatchResult(success: false, message: "Failed to dispatch email")
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
    
    /// Parses Google Form FB_PUBLIC_LOAD_DATA_ from HTML or raw JSON
    public static func parseGoogleFormPublicLoadData(_ htmlOrJson: String) -> RetrievedFormSchema? {
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
            
            var options: [String] = []
            if let first = firstEntry, first.count > 1, let optList = first[1] as? [[Any?]] {
                options = optList.compactMap { $0.first as? String }
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
            let combinedDesc: String
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
            default:
                if entryKey == nil {
                    qType = "info"
                    cat = .custom
                } else {
                    qType = "shortAnswer"
                    cat = inferCategory(from: cleanPrompt)
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
                let optRegex = try? NSRegularExpression(pattern: "<label[^>]*>(.*?)</label>|<option[^>]*value=[\"']?([^\"'>]+)[\"']?[^>]*>(.*?)</option>", options: [.caseInsensitive])
                if let oMatches = optRegex?.matches(in: blockHTML, range: NSRange(location: 0, length: blockNS.length)) {
                    for om in oMatches {
                        let oRange = om.range(at: 1).location != NSNotFound ? om.range(at: 1) : (om.range(at: 3).location != NSNotFound ? om.range(at: 3) : om.range(at: 2))
                        let cleanOpt = cleanHTMLText(blockNS.substring(with: oRange))
                        if !cleanOpt.isEmpty && cleanOpt != label && !options.contains(cleanOpt) {
                            options.append(cleanOpt)
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
        if htmlContent == nil, let url = URL(string: trimmedURL) {
            var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 4.0)
            req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            req.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                if let http = response as? HTTPURLResponse, http.statusCode < 400 {
                    htmlContent = String(data: data, encoding: .utf8)
                }
            } catch {
                // Ignore network error
            }
        }
        
        guard let html = htmlContent else { return nil }
        
        var schema: RetrievedFormSchema?
        if trimmedURL.contains("docs.google.com/forms") || trimmedURL.contains("forms.gle") || html.contains("FB_PUBLIC_LOAD_DATA_") {
            schema = parseGoogleFormPublicLoadData(html)
        }
        if schema == nil {
            schema = parseGenericHTMLForm(html, url: trimmedURL)
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
    public private(set) var confirmedFieldID: UUID?
    private var confirmedElement: AXUIElement?
    public private(set) var pendingText: String = ""
    private var pendingSince: Date?
    public static let pendingTTL: TimeInterval = 2.0
    
    /// Question types whose answer is produced by typing text (as opposed to picking an option).
    public static func isTextEntryType(_ questionType: String) -> Bool {
        return !["multipleChoice", "checkboxes", "dropdown", "linearScale", "grid", "info", "section", "pageBreak", "header", "title"].contains(questionType)
    }
    
    @MainActor
    private func confirmedFieldIndex(in model: ApplicationFormModel) -> Int? {
        guard let id = confirmedFieldID, let fields = model.activeSession?.fields else { return nil }
        return fields.firstIndex(where: { $0.id == id })
    }
    
    /// Forget which field the browser has focused (focus moved or is unknown). Held typing is discarded.
    @MainActor
    public func invalidateFocus() {
        confirmedFieldID = nil
        confirmedElement = nil
        pendingText = ""
        pendingSince = nil
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
        if changedField || model.activeFieldIndex != idx {
            model.objectWillChange.send()
            model.activeFieldIndex = idx
        }
        let fresh = pendingSince.map { Date().timeIntervalSince($0) < Self.pendingTTL } ?? false
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
                if event.type == .leftMouseDown {
                    let loc = NSEvent.mouseLocation
                    Task { @MainActor [weak self] in
                        self?.handleMouseDown(at: loc)
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
        // Fast 0.2s poll to sync focused element value and active field alignment
        axSyncTimer = Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, let model = self.formModel,
                          model.isFormDetected, model.isAutoCaptureEnabled else { return }
                    self.syncFocusedElement()
                }
            }
        
        // Periodic 1.5s background scan of all browser window inputs & AppleScript fallback
        fullScanTimer = Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, let model = self.formModel,
                          model.isFormDetected, model.isAutoCaptureEnabled else { return }
                    self.formModel?.syncLiveFormInputValues()
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
                        var isFocusedRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(innerElem, kAXFocusedAttribute as CFString, &isFocusedRef) == .success,
                           let isFocused = isFocusedRef as? Bool, !isFocused {
                            return nil
                        }
                        return (innerElem, innerRole)
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
                    var isFocusedRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(innerElem, kAXFocusedAttribute as CFString, &isFocusedRef) == .success,
                       let isFocused = isFocusedRef as? Bool, !isFocused {
                        return nil
                    }
                    return (innerElem, innerRole)
                }
            }
        }
        return nil
    }
    
    @MainActor
    public func handleMouseDown(at location: CGPoint) {
        guard let model = formModel, model.isFormDetected, model.isAutoCaptureEnabled else { return }
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              DefaultApplicationFormDetector.isBrowserApplication(frontApp) else { return }
        
        // Focus is about to move: stop attributing typing to the previous field until re-confirmed
        invalidateFocus()
        
        // Check if user clicked 'Clear form' or confirmed clearing in dialog
        let sys = AXUIElementCreateSystemWide()
        var hitRef: AXUIElement?
        if AXUIElementCopyElementAtPosition(sys, Float(location.x), Float(location.y), &hitRef) == .success,
           let hit = hitRef {
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
            }
        }
        
        // 1. Immediately attempt hit test at click coordinate
        syncFocusedElement(at: location)
        
        // 2. Schedule follow-up after 60ms once browser finalizes internal focus and state changes
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 60_000_000)
            self?.syncFocusedElement()
        }
    }
    
    @MainActor
    public func handleKeyStroke(keyCode: Int, flags: CGEventFlags, characters: String?) {
        guard let model = self.formModel else { return }
        guard model.isFormDetected && model.isAutoCaptureEnabled,
              let session = model.activeSession else { return }
        
        // Only capture if frontmost application is the detected browser / form host (bypassed in unit tests)
        if !MorphEnvironment.isTestingEnvironment {
            guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
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
        }
        
        // If Cmd or Ctrl is pressed:
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            // If Cmd+V (paste into browser field), trigger immediate AX sync in 80ms
            if keyCode == 9 {
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    self?.syncFocusedElement()
                }
            }
            return
        }
        
        // If fields are empty, sync focused element to dynamically discover field first
        if session.fields.isEmpty {
            self.syncFocusedElement()
        }
        guard (model.activeSession?.fields.count ?? 0) > 0 else { return }
        
        // Cheap guard against focus changes we did not see (programmatic focus, shortcuts, tab switches):
        // if the focused element differs from the one we confirmed, re-resolve before attributing anything.
        if !MorphEnvironment.isTestingEnvironment, let confirmed = confirmedElement,
           let current = Self.resolveFocusedElement(for: NSWorkspace.shared.frontmostApplication),
           !CFEqual(confirmed, current.element) {
            invalidateFocus()
            syncFocusedElement()
        }
        
        let confirmedIdx = confirmedFieldIndex(in: model)
        
        // 1. Backspace / Delete (KeyCode 51)
        if keyCode == 51 {
            if let idx = confirmedIdx {
                if Self.isTextEntryType(model.activeSession?.fields[idx].questionType ?? ""),
                   !(model.activeSession?.fields[idx].value.isEmpty ?? true) {
                    model.objectWillChange.send()
                    model.activeSession?.fields[idx].value.removeLast()
                    model.lastAutoCapturedAt = Date()
                    model.lastKeystrokeAt = Date()
                    model.saveDrafts()
                }
            } else if !pendingText.isEmpty {
                pendingText.removeLast()
            }
            self.scheduleDebouncedAXSync()
            return
        }
        
        // 2. Keys that move browser focus (Tab, Shift+Tab, arrows): the destination is unknown until
        //    Accessibility reports the newly focused element, so never guess an index.
        if keyCode == 48 || (123...126).contains(keyCode) {
            invalidateFocus()
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 60_000_000)
                self?.syncFocusedElement()
            }
            return
        }
        
        // 3. Return / Enter (KeyCode 36, 76)
        if keyCode == 36 || keyCode == 76 {
            if let idx = confirmedIdx, model.activeSession?.fields[idx].questionType == "paragraph" {
                model.objectWillChange.send()
                model.activeSession?.fields[idx].value.append("\n")
                model.lastAutoCapturedAt = Date()
                model.lastKeystrokeAt = Date()
                model.saveDrafts()
            } else {
                // Enter may submit, advance or toggle depending on the widget: re-resolve focus
                invalidateFocus()
                Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    self?.syncFocusedElement()
                }
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
        
        guard let idx = confirmedIdx else {
            // Focus not confirmed yet: hold the text; it is flushed to the right field on confirmation
            if pendingText.isEmpty { pendingSince = Date() }
            if pendingText.count < 500 { pendingText.append(printable) }
            self.scheduleDebouncedAXSync()
            return
        }
        
        // Typing does not change radio/checkbox/dropdown answers in the browser, so never record it for them
        guard Self.isTextEntryType(model.activeSession?.fields[idx].questionType ?? "") else { return }
        
        model.objectWillChange.send()
        model.activeSession?.fields[idx].value.append(printable)
        if let fid = model.activeSession?.fields[idx].id { model.markBrowserCaptured(fid) }
        model.lastAutoCapturedAt = Date()
        model.lastKeystrokeAt = Date()
        model.saveDrafts()
        
        // Email detection: if user types email in any field, auto-update recipientEmail
        let curVal = model.activeSession?.fields[idx].value ?? ""
        if curVal.contains("@") && curVal.contains(".") {
            let tokens = curVal.components(separatedBy: .whitespacesAndNewlines)
            for tok in tokens {
                if tok.contains("@") && tok.contains(".") && tok.count >= 5 {
                    if model.recipientEmail.isEmpty || model.recipientEmail.contains("example.com") || model.recipientEmail.contains("@test.com") {
                        model.setRecipientEmail(tok)
                    }
                    break
                }
            }
        }
        
        // Reconcile exact text from browser via debounced AX read (handles cursor moves, edits, replacements)
        self.scheduleDebouncedAXSync()
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
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            self?.syncFocusedElement()
        }
    }
    
    @MainActor
    public func syncFocusedElement(at point: CGPoint? = nil) {
        guard let model = formModel, model.isFormDetected, model.isAutoCaptureEnabled,
              let session = model.activeSession else { return }
        
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              DefaultApplicationFormDetector.isBrowserApplication(frontApp) else { return }
        
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
                    // Check up to 4 ancestors if clicked element was a label, text, or icon inside an input
                    var cur = hit
                    for _ in 0..<4 {
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
            guard let resolved = Self.resolveFocusedElement(for: frontApp) else { return }
            targetElem = resolved.element
            elemRole = resolved.role
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
        
        let elemTitle = ((titleRef as? String) ?? (descRef as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let textVal = (valRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ignore browser address bar
        if elemTitle.localizedCaseInsensitiveContains("address and search bar") || elemTitle.lowercased() == "address" {
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
        if currentType == "shortAnswer" || currentType == "text" || currentType.isEmpty {
            if elemRole == "AXTextArea" {
                model.activeSession?.fields[activeIdx].questionType = "paragraph"
            } else if elemRole == "AXRadioButton" {
                model.activeSession?.fields[activeIdx].questionType = "multipleChoice"
            } else if elemRole == "AXCheckBox" {
                model.activeSession?.fields[activeIdx].questionType = "checkboxes"
            } else if elemRole == "AXPopUpButton" || elemRole == "AXComboBox" {
                model.activeSession?.fields[activeIdx].questionType = "dropdown"
            }
        }
        
        // 2. Text input sync (AXTextField, AXTextArea, AXSearchField, AXComboBox)
        if elemRole == "AXTextField" || elemRole == "AXTextArea" || elemRole == "AXSearchField" || elemRole == "AXComboBox" {
            let tv = textVal ?? ""
            let current = model.activeSession?.fields[activeIdx].value ?? ""
            let isQuiet = model.lastKeystrokeAt.map { Date().timeIntervalSince($0) >= 0.35 } ?? true
            
            if current != tv {
                if !tv.isEmpty {
                    model.objectWillChange.send()
                    model.activeSession?.fields[activeIdx].value = tv
                    model.lastAutoCapturedAt = Date()
                    model.markBrowserCaptured(fieldID)
                } else if isQuiet && !model.manuallyEditedFieldIDs.contains(fieldID) {
                    // Browser input is genuinely empty ("") and user is not actively typing a keystroke:
                    // Reconcile field to empty string so phantom or cleared answers reflect reality immediately.
                    model.objectWillChange.send()
                    model.activeSession?.fields[activeIdx].value = ""
                    model.markBrowserCaptured(fieldID)
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
        
        // 5. Dropdown / PopUpButton selection sync
        if elemRole == "AXPopUpButton" {
            if let selectedVal = textVal ?? (titleRef as? String), !selectedVal.isEmpty,
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
        "tab", "tab name", "tab bar", "tabs", "new tab", "close tab", "active tab",
        "window", "main window", "browser window", "address", "address bar",
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
    
    private static func axChildren(_ elem: AXUIElement) -> [AXUIElement] {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(elem, kAXChildrenAttribute as CFString, &ref) == .success,
              let kids = ref as? [AXUIElement] else { return [] }
        return kids
    }
    
    private static func axText(_ elem: AXUIElement) -> String? {
        axString(elem, kAXValueAttribute as String) ?? axString(elem, kAXTitleAttribute as String) ?? axString(elem, kAXDescriptionAttribute as String)
    }
    
    /// True when an element (or something shallowly beneath it) is an interactive input, i.e. it is another question's container.
    private static func containsInteractiveInput(_ elem: AXUIElement, depth: Int = 2) -> Bool {
        for ch in axChildren(elem).prefix(40) {
            if isInteractiveInputRole(axRole(ch)) && axRole(ch) != "AXButton" { return true }
            if depth > 1 && containsInteractiveInput(ch, depth: depth - 1) { return true }
        }
        return false
    }
    
    /// Ordered question-title candidates for an element, nearest/most specific first:
    /// its own labels, then headings/static text that PRECEDE it in each ancestor (never following siblings, never
    /// other questions' containers), stopping after the first level that yields a real heading. The caller picks the
    /// first candidate that matches a schema question, so a stray decoration can never claim the field.
    public static func candidateQuestionTitles(for elem: AXUIElement, limit: Int = 10) -> [String] {
        var out: [String] = []
        func add(_ raw: String?, minLength: Int = 1) {
            guard out.count < limit, let raw = raw else { return }
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, !t.hasPrefix("http"), t != "*", !t.contains("@") else { return }
            let c = ApplicationFormModel.cleanQuestionTitle(t)
            guard c.count >= minLength, !genericTitleNoise.contains(c.lowercased()), !genericTitleNoise.contains(t.lowercased()) else { return }
            if !out.contains(c) { out.append(c) }
        }
        
        add(axString(elem, kAXTitleAttribute as String))
        add(axString(elem, kAXDescriptionAttribute as String))
        add(axString(elem, kAXHelpAttribute as String))
        
        var titleElemRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(elem, kAXTitleUIElementAttribute as CFString, &titleElemRef) == .success, let te = titleElemRef {
            add(axText(te as! AXUIElement))
        }
        var linkedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(elem, "AXLinkedUIElements" as CFString, &linkedRef) == .success,
           let linkedList = linkedRef as? [AXUIElement] {
            for linked in linkedList { add(axText(linked)) }
        }
        
        var child = elem
        for _ in 0..<9 {
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
                        if let t = axText(sib) { add(t, minLength: 3); foundHeading = true }
                    } else if sr == "AXStaticText" {
                        add(axText(sib), minLength: 3)
                    } else if sr == "AXGroup", !containsInteractiveInput(sib) {
                        let inner = axChildren(sib)
                        for g in inner where axRole(g) == "AXHeading" {
                            if let t = axText(g) { add(t, minLength: 3); foundHeading = true }
                        }
                        if !foundHeading {
                            for g in inner where axRole(g) == "AXStaticText" { add(axText(g), minLength: 3) }
                        }
                    }
                    if foundHeading { break }
                }
            }
            if foundHeading || out.count >= limit { break }
            child = parent
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
            if let text = axText(te as! AXUIElement), !text.isEmpty { return text }
        }
        
        for ch in axChildren(elem) {
            if axRole(ch) == "AXStaticText" {
                if let text = axText(ch), !text.isEmpty { return text }
            }
        }
        
        var parentRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(elem, kAXParentAttribute as CFString, &parentRef) == .success,
           let p = parentRef {
            for sib in axChildren(p as! AXUIElement) {
                if axRole(sib) == "AXStaticText" {
                    if let text = axText(sib), !text.isEmpty { return text }
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
    
    /// Scans the browser content window to extract live input field values paired with their question labels.
    public static func scanBrowserWindowInputs(appElem: AXUIElement, fields: [FormInputField] = []) -> [(label: String, value: String)]? {
        guard let win = DefaultApplicationFormDetector.getBrowserWindowElement(appElem: appElem) else {
            return nil
        }
        
        // Form inputs must reside within web document content (AXWebArea).
        // If no AXWebArea exists, never scan native window chrome (tabs, search bars, toolbars).
        guard let startElem = findWebAreaElement(in: win) else {
            return nil
        }
        
        var fieldValues: [String: String] = [:]
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
                if desc != "Address and search bar" && !desc.localizedCaseInsensitiveContains("address") {
                    var valRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(current, kAXValueAttribute as CFString, &valRef)
                    let textVal = (valRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let label = resolveQuestionLabel(for: current, fields: fields, fallback: desc)
                    let cleanLbl = ApplicationFormModel.cleanQuestionTitle(label)
                    if !cleanLbl.isEmpty {
                        if !textVal.isEmpty || fieldValues[cleanLbl] == nil {
                            fieldValues[cleanLbl] = textVal
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
                    if isChecked {
                        let optionTitle = extractOptionTitle(from: current)
                        if !optionTitle.isEmpty {
                            fieldValues[cleanLbl] = optionTitle
                        }
                    } else if fieldValues[cleanLbl] == nil {
                        fieldValues[cleanLbl] = ""
                    }
                }
            } else if role == "AXCheckBox" {
                var checkedRef: CFTypeRef?
                AXUIElementCopyAttributeValue(current, kAXValueAttribute as CFString, &checkedRef)
                let isChecked = (checkedRef as? Int == 1) || (checkedRef as? Bool == true)
                let qLabel = resolveQuestionLabel(for: current, fields: fields)
                let cleanLbl = ApplicationFormModel.cleanQuestionTitle(qLabel)
                if !cleanLbl.isEmpty {
                    if isChecked {
                        let optionTitle = extractOptionTitle(from: current)
                        if !optionTitle.isEmpty {
                            if let existing = fieldValues[cleanLbl], !existing.isEmpty {
                                if !existing.components(separatedBy: ", ").contains(optionTitle) {
                                    fieldValues[cleanLbl] = existing + ", " + optionTitle
                                }
                            } else {
                                fieldValues[cleanLbl] = optionTitle
                            }
                        }
                    } else if fieldValues[cleanLbl] == nil {
                        fieldValues[cleanLbl] = ""
                    }
                }
            } else if role == "AXPopUpButton" || role == "AXComboBox" {
                var valRef: CFTypeRef?, titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(current, kAXValueAttribute as CFString, &valRef)
                AXUIElementCopyAttributeValue(current, kAXTitleAttribute as CFString, &titleRef)
                let popVal = ((valRef as? String) ?? (titleRef as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let ignoredDrop = ["choose", "select", "select an option", "choose an option"]
                let qLabel = resolveQuestionLabel(for: current, fields: fields)
                let cleanLbl = ApplicationFormModel.cleanQuestionTitle(qLabel)
                if !cleanLbl.isEmpty {
                    if !popVal.isEmpty && !ignoredDrop.contains(popVal.lowercased()) {
                        fieldValues[cleanLbl] = popVal
                    } else if fieldValues[cleanLbl] == nil {
                        fieldValues[cleanLbl] = ""
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
        
        var results: [(label: String, value: String)] = []
        for (lbl, val) in fieldValues {
            results.append((label: lbl, value: val))
        }
        return results
    }
    
    /// JavaScript injected into the active browser tab to read the live answers of a Google Form
    /// (or generic web form). Returns `title:::value` pairs joined by `|||`; unanswered questions are
    /// reported with an empty value so that cleared answers can be detected.
    /// Contains no double quotes so it can be embedded safely in an AppleScript string literal.
    public static let domExtractionScript: String = #"""
    (function() {
        var out = [];
        var seen = [];
        function clean(t) { return (t || '').replace(/\s+/g, ' ').trim(); }
        function text(e) { return e ? clean(e.innerText || e.textContent) : ''; }
        function attr(e, n) { var v = e.getAttribute(n); return v === null ? null : clean(v); }
        function optionValue(e) {
            var v = attr(e, 'data-value');
            if (v === null || v === '') v = attr(e, 'data-answer-value');
            if (v === null || v === '') v = attr(e, 'aria-label');
            if (v === null || v === '') v = clean(e.value);
            if (v === null || v === '') v = text(e);
            return v || '';
        }
        var placeholder = /^(choose|select|select an option|choose an option|-- ?select ?--)$/i;
        var items = document.querySelectorAll('div[role=listitem], .Qr7Oae, .geS5n, .question, .form-group');
        if (items.length > 0) {
            for (var i = 0; i < items.length; i++) {
                var item = items[i];
                if (seen.indexOf(item) >= 0) continue;
                seen.push(item);
                if (item.querySelector('div[role=listitem]')) continue;
                if (!item.querySelector('input:not([type=hidden]), textarea, select, [role=radio], [role=checkbox], [role=listbox], [role=combobox]')) continue;
                var h = item.querySelector('[role=heading], .M7eMe, legend, label, h2, h3, h4');
                var title = text(h).replace(/\s*\*+\s*$/, '').replace(/:::/g, ':').replace(/\|\|\|/g, '|');
                if (!title) continue;
                var val = '';
                var inp = item.querySelector('input[type=text], input[type=email], input[type=tel], input[type=url], input[type=number], input[type=date], input[type=time], input[type=datetime-local], input:not([type]), textarea');
                if (inp && inp.value) val = clean(inp.value);
                if (!val) {
                    var rad = item.querySelector('[role=radio][aria-checked=true], input[type=radio]:checked');
                    if (rad) val = optionValue(rad);
                }
                if (!val) {
                    var chk = item.querySelectorAll('[role=checkbox][aria-checked=true], input[type=checkbox]:checked');
                    var cs = [];
                    for (var j = 0; j < chk.length; j++) {
                        var cv = optionValue(chk[j]);
                        if (cv && cs.indexOf(cv) < 0) cs.push(cv);
                    }
                    val = cs.join(', ');
                }
                if (!val) {
                    var sel = item.querySelector('select');
                    if (sel && sel.selectedIndex >= 0) {
                        var so = sel.options[sel.selectedIndex];
                        var sv = so ? clean(so.value || so.text) : '';
                        if (sv && !placeholder.test(sv)) val = sv;
                    }
                }
                if (!val) {
                    var drop = item.querySelector('[role=option][aria-selected=true]');
                    if (drop) {
                        var dv = optionValue(drop);
                        if (dv && !placeholder.test(dv)) val = dv;
                    }
                }
                val = val.replace(/\|\|\|/g, '|');
                out.push(title + ':::' + val);
            }
        } else {
            var inps = document.querySelectorAll('input:not([type=hidden]):not([type=submit]):not([type=button]), textarea, select');
            for (var k = 0; k < inps.length; k++) {
                var el = inps[k];
                var l = clean(el.getAttribute('aria-label') || el.name || el.placeholder || '');
                if (l && el.value) out.push(l.replace(/:::/g, ':') + ':::' + clean(el.value).replace(/\|\|\|/g, '|'));
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
    
    /// Builds the AppleScript that runs `domExtractionScript` in the frontmost tab of a scriptable browser.
    public static func buildDOMExtractionAppleScript(bundleID: String) -> String? {
        let b = bundleID.lowercased()
        let isChrome = b.contains("chrome") || b.contains("brave") || b.contains("edge") || b.contains("arc") || b.contains("vivaldi") || b.contains("opera") || b.contains("chromium") || b.contains("comet") || b.contains("sigmaos") || b.contains("wavebox")
        let isSafari = b.contains("safari") && !b.contains("technology")
        guard isChrome || isSafari else { return nil }
        
        let escapedJS = appleScriptStringLiteralBody(domExtractionScript)
        if isChrome {
            return """
            tell application id "\(bundleID)"
                if (count of windows) > 0 then
                    try
                        tell front window to tell active tab
                            return execute javascript "\(escapedJS)"
                        end tell
                    end try
                end if
            end tell
            """
        }
        return """
        tell application id "com.apple.Safari"
            if (count of documents) > 0 then
                try
                    tell front window to tell current tab
                        return do JavaScript "\(escapedJS)"
                    end tell
                end try
            end if
        end tell
        """
    }
    
    /// Parses the `title:::value|||title:::value` output of `domExtractionScript`.
    /// Pairs with an empty value are kept so callers can detect cleared answers.
    public static func parseDOMExtractionOutput(_ output: String) -> [(label: String, value: String)] {
        var results: [(label: String, value: String)] = []
        for pair in output.components(separatedBy: "|||") {
            let parts = pair.components(separatedBy: ":::")
            guard parts.count >= 2 else { continue }
            let lbl = ApplicationFormModel.cleanQuestionTitle(parts[0])
            let val = parts[1...].joined(separator: ":::").trimmingCharacters(in: .whitespacesAndNewlines)
            if !lbl.isEmpty {
                results.append((label: lbl, value: val))
            }
        }
        return results
    }
    
    /// Reads every question and its current answer (empty string when unanswered) from the active tab of a
    /// scriptable browser (Safari, Chrome, Brave, Arc, Edge...) via AppleScript DOM extraction.
    public static func extractSnapshotViaAppleScript(bundleID: String) -> [(label: String, value: String)]? {
        guard let scriptSource = buildDOMExtractionAppleScript(bundleID: bundleID),
              let output = executeAppleScript(scriptSource), !output.isEmpty else { return nil }
        return parseDOMExtractionOutput(output)
    }
    
    /// Extracts answered questions (non-empty values only) from scriptable browsers via AppleScript.
    public static func extractInputsViaAppleScript(bundleID: String) -> [(label: String, value: String)]? {
        guard let snapshot = extractSnapshotViaAppleScript(bundleID: bundleID) else { return nil }
        return snapshot.filter { !$0.value.isEmpty }
    }
    
    private static func executeAppleScript(_ source: String) -> String? {
        if let script = NSAppleScript(source: source) {
            var errorDict: NSDictionary?
            let desc = script.executeAndReturnError(&errorDict)
            if errorDict == nil, let val = desc.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !val.isEmpty {
                return val
            }
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", source]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            proc.waitUntilExit()
            if proc.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                    return str
                }
            }
        } catch {}
        return nil
    }
}

// MARK: - Form Field Filter Mode
public enum FormFieldFilterMode: String, CaseIterable, Equatable, Sendable {
    case requiredOnly = "Required"
    case all = "All"
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
    @Published public var recipientEmail: String = ""
    @Published public var deliveryToastMessage: String? = nil
    @Published public var historySessions: [ApplicationFormSession] = []
    @Published public var activeFieldIndex: Int = 0
    @Published public var isAutoRetrievingSchema: Bool = false
    @Published public var lastAutoCapturedAt: Date? = nil
    @Published public var lastKeystrokeAt: Date? = nil
    @Published public var filterMode: FormFieldFilterMode = .requiredOnly
    @Published public var consecutiveMissedDetections: Int = 0
    
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
    
    private var toastDismissTask: Task<Void, Never>?
    private var justDetectedResetTask: Task<Void, Never>?
    private var pollTimer: AnyCancellable?
    private var workspaceNotificationObserver: NSObjectProtocol?
    private var workspaceLaunchObserver: NSObjectProtocol?
    private var workspaceUnhideObserver: NSObjectProtocol?
    private var isAppleScriptSyncRunning: Bool = false
    
    public init(
        detector: ApplicationFormDetectorProtocol? = nil,
        dispatcher: ApplicationEmailDispatcherProtocol? = nil,
        userDefaultBrowser: UserBrowserProfile? = nil
    ) {
        self.detector = detector ?? DefaultApplicationFormDetector()
        self.dispatcher = dispatcher ?? DefaultEmailDispatcher()
        self.userDefaultBrowser = userDefaultBrowser ?? PersonalizedBrowserDetector.detectDefaultBrowser()
        
        if !MorphEnvironment.isTestingEnvironment {
            loadDrafts()
            self.autoTracker = FormInputAutoTracker(model: self)
            self.autoTracker?.start()
            startPolling()
        }
    }
    
    // MARK: - Draft & History Persistence
    nonisolated public static let draftsStorageKey = "com.morph.applicationForm.drafts"
    
    public func saveDrafts() {
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
                loaded[sessionIdx].fields.removeAll { field in
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
        
        // If current index is valid, unanswered, and matches current filter mode, keep it
        if curIdx >= 0 && curIdx < fields.count {
            let curField = fields[curIdx]
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
    }
    
    private func startPolling() {
        // 1. Observe application activations across the computer
        workspaceNotificationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkActiveApplication()
            }
        }
        
        // 2. Observe new application launches
        workspaceLaunchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkActiveApplication()
            }
        }
        
        // 3. Observe application unhide
        workspaceUnhideObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didUnhideApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkActiveApplication()
            }
        }
        
        // 4. Fast 0.5s periodic timer monitoring active on-screen form context
        pollTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkActiveApplication()
            }
    }
    
    // MARK: - Active Form Detection
    public func checkActiveApplication() {
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let bundleID = frontApp.bundleIdentifier?.lowercased() ?? ""
            let appName = frontApp.localizedName?.lowercased() ?? ""
            if (bundleID.contains("com.morph.") || bundleID == "morph" || bundleID.hasSuffix(".morph") || appName == "morph") {
                // Morph itself is frontmost (e.g. interacting with HUD or expanded view).
                // Retain current detection and session state without touching it.
                return
            }
        }
        
        let result = detector.detectActiveApplicationForm()
        if result.isDetected != self.isFormDetected {
            NSLog("[MORPH-FORM] checkActiveApplication: isDetected changed from %d to %d (title: %@, app: %@, url: %@)", self.isFormDetected ? 1 : 0, result.isDetected ? 1 : 0, result.title ?? "nil", result.appName ?? "nil", result.url ?? "nil")
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
                    self.activeSession = suspended
                    self.suspendedSession = nil
                    self.isTracking = true
                    let cleanCurr = DefaultApplicationFormDetector.cleanTitle(title)
                    let cleanOld = DefaultApplicationFormDetector.cleanTitle(suspended.formTitle)
                    let genericTitles = ["application form", "google forms", "untitled form", "polar"]
                    if genericTitles.contains(cleanOld.lowercased()) && !genericTitles.contains(cleanCurr.lowercased()) && !cleanCurr.isEmpty {
                        self.activeSession?.formTitle = title
                        self.detectedFormTitle = title
                    }
                    if let u = normalizedURL, (self.activeSession?.sourceURL == nil || self.activeSession?.sourceURL?.isEmpty == true) {
                        self.activeSession?.sourceURL = u
                    }
                } else {
                    // Different form opened: archive suspended session to history
                    var old = suspended
                    old.completedAt = Date()
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
                    if let existingIdx = historySessions.firstIndex(where: { $0.id == old.id }) {
                        historySessions[existingIdx] = old
                    } else {
                        historySessions.insert(old, at: 0)
                    }
                    self.activeSession = nil
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
            
            // 3. Search history / drafts memory for this form!
            if activeSession == nil {
                if let matchIdx = historySessions.firstIndex(where: {
                    DefaultApplicationFormDetector.isSameForm(
                        titleA: $0.formTitle, urlA: $0.sourceURL,
                        titleB: title, urlB: normalizedURL
                    )
                }) {
                    var restored = historySessions.remove(at: matchIdx)
                    restored.completedAt = nil
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
                    NSLog("[MORPH-FORM] Restored form session '%@' from memory with %d fields (%d answered)", restored.formTitle, restored.fields.count, restored.answeredCount)
                    advanceToFirstUnansweredFieldIfNeeded()
                    saveDrafts()
                } else {
                    // No existing session in drafts or history: start tracking fresh
                    startTracking(title: title, appName: app, url: normalizedURL)
                }
            }
            
            syncLiveFormInputValues()
            advanceToFirstUnansweredFieldIfNeeded()
            saveDrafts()
        } else {
            // If Morph itself is frontmost and we already have an active form session,
            // retain the state while the user interacts with the Notch/HUD
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                let bundleID = frontApp.bundleIdentifier?.lowercased() ?? ""
                let appName = frontApp.localizedName?.lowercased() ?? ""
                if (bundleID.contains("com.morph.") || bundleID == "morph" || bundleID.hasSuffix(".morph") || appName == "morph") && self.isFormDetected {
                    return
                }
            }
            
            self.consecutiveMissedDetections += 1
            
            // Immediate collapse when using something else:
            // Stash active session into suspendedSession so when the user goes back to the form,
            // it resumes without losing entered fields or answers.
            if self.isFormDetected {
                if let current = self.activeSession {
                    self.suspendedSession = current
                }
                self.isFormDetected = false
                self.isJustDetected = false
                self.detectedBrowserFamily = .unknown
                self.detectedScreenIndex = nil
                self.detectedScreenName = nil
                self.justDetectedResetTask?.cancel()
            }
        }
    }
    
    // MARK: - Session Lifecycle
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
        let emailToUse = (defaultEmail?.isEmpty == false ? defaultEmail! : (recipientEmail.isEmpty ? "user@example.com" : recipientEmail))
        
        self.recipientEmail = emailToUse
        
        // Search history/drafts for an existing session for this form before creating a blank one
        if let matchIdx = historySessions.firstIndex(where: {
            DefaultApplicationFormDetector.isSameForm(
                titleA: $0.formTitle, urlA: $0.sourceURL,
                titleB: finalTitle, urlB: finalUrl
            )
        }) {
            var restored = historySessions.remove(at: matchIdx)
            restored.completedAt = nil
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
            self.detectedFormTitle = restored.formTitle
            self.detectedAppName = finalApp
            self.detectedURL = finalUrl
            advanceToFirstUnansweredFieldIfNeeded()
            saveDrafts()
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
        self.isTracking = true
        self.isFormDetected = true
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
            if let existingIdx = historySessions.firstIndex(where: { $0.id == session.id }) {
                historySessions[existingIdx] = session
            } else {
                historySessions.insert(session, at: 0)
            }
        } else if var session = suspendedSession {
            session.completedAt = Date()
            if let existingIdx = historySessions.firstIndex(where: { $0.id == session.id }) {
                historySessions[existingIdx] = session
            } else {
                historySessions.insert(session, at: 0)
            }
        }
        self.activeSession = nil
        self.suspendedSession = nil
        self.activeFieldIndex = 0
        self.isTracking = false
        self.isFormDetected = false
        self.isJustDetected = false
        self.justDetectedResetTask?.cancel()
        saveDrafts()
        self.onFormClosed?()
    }
    
    // MARK: - Autonomous Form Schema Retrieval
    public func autoRetrieveFormContent(url: String) {
        guard !url.isEmpty, !isAutoRetrievingSchema else { return }
        self.isAutoRetrievingSchema = true
        
        Task { [weak self] in
            let schema = await FormContentRetriever.retrieveForm(from: url)
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.isAutoRetrievingSchema = false
                guard let schema = schema else { return }
                
                // Discard schema if user already navigated to a different form
                if let curURL = self.activeSession?.sourceURL, !curURL.isEmpty {
                    let curID = DefaultApplicationFormDetector.extractFormIdentifier(from: curURL)
                    let schemaID = DefaultApplicationFormDetector.extractFormIdentifier(from: url)
                    if curID != nil && schemaID != nil && curID != schemaID {
                        NSLog("[MORPH-FORM] autoRetrieveFormContent: Discarding stale schema for '%@' because active session is '%@'", url, curURL)
                        return
                    }
                }
                
                if !schema.title.isEmpty {
                    self.detectedFormTitle = schema.title
                    self.activeSession?.formTitle = schema.title
                }
                if !schema.description.isEmpty {
                    self.activeSession?.formDescription = schema.description
                }
                
                if !schema.fields.isEmpty {
                    if let current = self.activeSession?.fields, !current.isEmpty {
                        // Merge fields preserving any user input or adopting new values
                        var merged = schema.fields
                        for i in 0..<merged.count {
                            if let matchIdx = Self.bestMatchingFieldIndex(for: merged[i].label, in: current) {
                                let existing = current[matchIdx]
                                if !existing.value.isEmpty && merged[i].value.isEmpty {
                                    merged[i].value = existing.value
                                    merged[i].id = existing.id
                                    self.browserCapturedFieldIDs.insert(existing.id)
                                }
                            } else if let existing = current.first(where: {
                                $0.entryKey != nil && $0.entryKey == merged[i].entryKey
                            }) {
                                if !existing.value.isEmpty && merged[i].value.isEmpty {
                                    merged[i].value = existing.value
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
                self.syncLiveFormInputValues()
                self.advanceToFirstUnansweredFieldIfNeeded()
                self.saveDrafts()
            }
        }
    }
    
    // MARK: - Live Input Hydration & Synchronization
    @MainActor
    public func syncLiveFormInputValues() {
        guard isFormDetected, isAutoCaptureEnabled,
              let session = activeSession else { return }
        
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
                        if !parsedField.value.isEmpty {
                            applyExtractedInput(label: parsedField.label, value: parsedField.value)
                        }
                    }
                }
            }
        }
        
        // 2. Scan ONLY the browser hosting the detected form (other browsers/windows may show unrelated pages
        //    whose question labels would otherwise leak answers into this form)
        let targetApps = Self.formHostBrowsers(detectedAppName: detectedAppName)
        let schemaFields = activeSession?.fields ?? []
        
        for app in targetApps {
            let appElem = AXUIElementCreateApplication(app.processIdentifier)
            if let pairs = FormInputAutoTracker.scanBrowserWindowInputs(appElem: appElem, fields: schemaFields), !pairs.isEmpty {
                applyLiveSnapshot(pairs)
            }
        }
        
        // 3. Fallback for scriptable browsers (Safari, Chrome) via AppleScript DOM extraction on background queue
        if !isAppleScriptSyncRunning {
            isAppleScriptSyncRunning = true
            let bundleIDs = targetApps.compactMap { $0.bundleIdentifier }
            DispatchQueue.global(qos: .utility).async { [weak self] in
                defer {
                    Task { @MainActor [weak self] in
                        self?.isAppleScriptSyncRunning = false
                    }
                }
                for bid in bundleIDs {
                    if let pairs = FormInputAutoTracker.extractSnapshotViaAppleScript(bundleID: bid), !pairs.isEmpty {
                        Task { @MainActor [weak self] in
                            self?.applyLiveSnapshot(pairs)
                        }
                    }
                }
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
    public func applyExtractedInput(label: String, value: String) -> Bool {
        guard let session = activeSession else { return false }
        let cleanVal = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLbl = Self.cleanQuestionTitle(label)
        guard !cleanVal.isEmpty, !cleanLbl.isEmpty else { return false }
        
        let ignoredTitles: Set<String> = [
            "address", "address and search bar", "search", "search or enter website name",
            "back", "forward", "reload", "refresh", "home", "sidebar", "show sidebar", "hide sidebar",
            "extensions", "extension", "profiles", "profiles and menu", "profile", "bookmarks", "bookmark",
            "bookmark this page", "downloads", "history", "settings", "options", "menu", "close", "minimize",
            "zoom", "fullscreen", "new tab", "tab", "tab name", "all", "required", "ask polar", "polar", "morph"
        ]
        let lowerLbl = cleanLbl.lowercased()
        if ignoredTitles.contains(lowerLbl) || lowerLbl.hasPrefix("all,") || lowerLbl.hasPrefix("required,") {
            return false
        }
        
        var didUpdate = false
        if let idx = Self.strictMatchingFieldIndex(for: cleanLbl, in: session.fields) {
            if activeSession?.fields[idx].value != cleanVal {
                objectWillChange.send()
                activeSession?.fields[idx].value = cleanVal
                lastAutoCapturedAt = Date()
                didUpdate = true
            }
            if let fid = activeSession?.fields[idx].id { browserCapturedFieldIDs.insert(fid) }
        } else if !hasLoadedSchema {
            // Dynamic field addition when a real input/answer is extracted (never when a real form schema is loaded:
            // an unmatched label is then browser chrome or another page, not a question of this form)
            let cat = FormContentRetriever.inferCategory(from: cleanLbl)
            let newField = FormInputField(label: cleanLbl, value: cleanVal, category: cat)
            objectWillChange.send()
            activeSession?.fields.append(newField)
            browserCapturedFieldIDs.insert(newField.id)
            lastAutoCapturedAt = Date()
            didUpdate = true
        }
        
        // Auto-update recipientEmail if value is a valid email
        if didUpdate && cleanVal.contains("@") && cleanVal.contains(".") && cleanVal.count >= 5 {
            if recipientEmail.isEmpty || recipientEmail.contains("example.com") || recipientEmail.contains("@test.com") {
                setRecipientEmail(cleanVal)
            }
        }
        
        if didUpdate {
            saveDrafts()
            advanceToFirstUnansweredFieldIfNeeded()
        }
        
        return didUpdate
    }
    
    /// Applies a full browser snapshot of question/answer pairs. Non-empty answers are recorded; an empty answer
    /// clears the matching field only when that field was previously captured from the browser, matches the
    /// question label exactly (after normalization) and has been quiet for `clearGuardInterval`
    /// (protecting live keystroke buffers from stale reads).
    /// - Returns: number of fields that were updated or cleared.
    @discardableResult
    public func applyLiveSnapshot(_ pairs: [(label: String, value: String)], now: Date = Date()) -> Int {
        guard isFormDetected, isAutoCaptureEnabled, let session = activeSession else { return 0 }
        
        let nonEmpties = pairs.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // 1. Check if the entire form was cleared in the browser (all scanned inputs are empty while Morph had answers)
        let lastCapture = lastKeystrokeAt ?? lastAutoCapturedAt
        let isQuiet = lastCapture.map { now.timeIntervalSince($0) >= Self.clearGuardInterval } ?? true
        if nonEmpties.isEmpty && !pairs.isEmpty && session.answeredCount > 0 {
            // Ensure the empty pairs in the snapshot actually correspond to the answered fields of this form
            let answeredFields = session.fields.filter { $0.isAnswered }
            let hasNoManualEdits = answeredFields.allSatisfy { !self.manuallyEditedFieldIDs.contains($0.id) }
            let matchedAnsweredCount = answeredFields.filter { field in
                pairs.contains(where: { ApplicationFormModel.strictMatchingFieldIndex(for: $0.label, in: [field]) != nil }) ||
                pairs.contains(where: { Self.normalizeFieldLabel($0.label) == Self.normalizeFieldLabel(field.label) })
            }.count
            
            // Multi-field clear (e.g. "Clear form" clicked clearing 2+ questions simultaneously):
            let isMultiFieldClear = (matchedAnsweredCount >= 2 && hasNoManualEdits)
            // Single-field full clear during quiet period:
            let isQuietFullClear = (isQuiet && matchedAnsweredCount > 0 && hasNoManualEdits)
            
            if isMultiFieldClear || isQuietFullClear {
                let clearedCount = session.answeredCount
                clearAllFormAnswers()
                return clearedCount
            }
        }
        
        var changed = 0
        // Apply all non-empty values (beforehand answers and live updates)
        for pair in nonEmpties {
            if applyExtractedInput(label: pair.label, value: pair.value) {
                changed += 1
            }
        }
        
        // Check for individual cleared fields
        let empties = pairs.filter { $0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        for pair in empties {
            guard let idx = ApplicationFormModel.strictMatchingFieldIndex(for: pair.label, in: session.fields) ??
                            session.fields.firstIndex(where: { Self.normalizeFieldLabel($0.label) == Self.normalizeFieldLabel(pair.label) }) else { continue }
            let field = session.fields[idx]
            guard !field.value.isEmpty else { continue }
            guard !manuallyEditedFieldIDs.contains(field.id) else { continue }
            if let last = lastCapture, now.timeIntervalSince(last) < Self.clearGuardInterval { continue }
            objectWillChange.send()
            activeSession?.fields[idx].value = ""
            browserCapturedFieldIDs.remove(field.id)
            changed += 1
        }
        
        if changed > 0 {
            saveDrafts()
            advanceToFirstUnansweredFieldIfNeeded()
        }
        return changed
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
    public func addField(label: String, value: String, category: FormFieldCategory = .custom) {
        guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        if activeSession == nil {
            startTracking()
        }
        
        let field = FormInputField(
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            value: value.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category
        )
        
        activeSession?.fields.append(field)
        saveDrafts()
        
        // If user entered an email field, auto-suggest or update recipientEmail if default
        if category == .contact || label.lowercased().contains("email") {
            let emailCandidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if emailCandidate.contains("@") && (recipientEmail.isEmpty || recipientEmail.contains("example.com") || recipientEmail.contains("@test.com")) {
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
    
    // MARK: - Email Dispatch
    public func dispatchEmailCopy() async -> Bool {
        guard var session = activeSession else { return false }
        
        let destination = recipientEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destination.isEmpty && destination.contains("@") else {
            showToast("Invalid email address")
            return false
        }
        
        session.recipientEmail = destination
        session.emailDeliveryStatus = .sending
        activeSession?.emailDeliveryStatus = .sending
        
        do {
            let result = try await dispatcher.dispatchCopy(session: session)
            if result.success {
                session.emailDeliveryStatus = .sent(result.dispatchedAt)
                session.lastDispatchedAt = result.dispatchedAt
                session.isSubmitted = true
                activeSession = session
                
                showToast("Copy emailed to \(destination)!")
                onSessionExported?(session)
                return true
            } else {
                session.emailDeliveryStatus = .failed(result.message)
                activeSession = session
                showToast("Delivery failed: \(result.message)")
                return false
            }
        } catch {
            session.emailDeliveryStatus = .failed(error.localizedDescription)
            activeSession = session
            showToast("Error: \(error.localizedDescription)")
            return false
        }
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
