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
    
    public var wordCount: Int {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        return trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
}

// MARK: - Email Delivery Status
public enum EmailDeliveryStatus: Equatable, Sendable {
    case idle
    case sending
    case sent(Date)
    case failed(String)
    
    public var isSent: Bool {
        if case .sent = self { return true }
        return false
    }
}

// MARK: - Application Form Session
public struct ApplicationFormSession: Identifiable, Equatable, Sendable {
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
        fields.filter { $0.isAnswered && $0.questionType != "info" }.count
    }
    
    public var totalQuestions: Int {
        let actionable = fields.filter { $0.questionType != "info" }.count
        return actionable > 0 ? actionable : fields.count
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
            app.activationPolicy == .regular && DefaultApplicationFormDetector.isBrowserApplication(app)
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
    
    public init(isDetected: Bool, title: String? = nil, appName: String? = nil, url: String? = nil, browserFamily: BrowserEngineFamily? = nil) {
        self.isDetected = isDetected
        self.title = title
        self.appName = appName
        self.url = url
        self.browserFamily = browserFamily
    }
}

public protocol ApplicationFormDetectorProtocol: Sendable {
    func detectActiveApplicationForm() -> FormDetectionResult
}

public struct DefaultApplicationFormDetector: ApplicationFormDetectorProtocol {
    public init() {}
    
    // MARK: - Keyword & Pattern Matchers
    public static func isFormTitle(_ title: String) -> Bool {
        let lower = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty else { return false }
        
        let keywords = [
            "untitled form", "google form", "google forms", "google-form",
            "microsoft form", "microsoft forms",
            "typeform", "tally", "jotform", "surveymonkey", "formstack", "wufoo",
            "cognito form", "cognitoform", "fillout",
            "greenhouse", "lever application", "myworkdayjobs", "workday",
            "ashby", "ashbyhq", "smartrecruiters", "jobvite", "icims", "bamboohr",
            "workable", "handshake", "docusign", "submittable",
            "job application", "application form", "apply for", "apply to",
            "employment application", "candidate application", "internship application",
            "rental application", "tenant application", "lease application", "housing application",
            "visa application", "passport application", "scholarship application",
            "college application", "admission application", "admissions application", "university application",
            "membership application", "grant application", "permit application", "volunteer application",
            "credit application", "loan application", "mortgage application",
            "registration form", "signup form", "sign-up form", "event registration", "attendee registration", "rsvp",
            "intake form", "feedback form", "evaluation form", "contact form", "contact us",
            "order form", "submission form", "questionnaire", "survey", "inquiry form", "waitlist",
            "quiz", "pop quiz", "assessment", "evaluation", "exam", "midterm",
            "course evaluation", "student evaluation", "peer review",
            "check-in", "check in", "checkin", "timesheet",
            "onboarding", "intake", "feedback", "poll", "ballot", "petition",
            "worksheet", "assignment", "fill & sign", "interactive form"
        ]
        
        for kw in keywords {
            if lower.contains(kw) {
                return true
            }
        }
        
        // Suffix & separator patterns: e.g. "Customer Inquiry Form", "Program - Application", "Physics 101 Quiz"
        if lower.hasSuffix(" form") || lower.hasSuffix(" forms") || lower.hasSuffix(" application") || lower.hasSuffix(" questionnaire") || lower.hasSuffix(" survey") || lower.hasSuffix(" quiz") || lower.hasSuffix(" exam") || lower.hasSuffix(" assessment") || lower.hasSuffix(" evaluation") || lower.hasSuffix(" feedback") || lower.hasSuffix(" review") || lower.hasSuffix(" check-in") || lower.hasSuffix(" checkin") || lower.hasSuffix(" worksheet") {
            return true
        }
        if lower.contains(" form - ") || lower.contains(" form | ") || lower.contains(" - form") || lower.contains(" | form") || lower.contains(": form") || lower.contains(" forms - ") || lower.contains(" forms | ") {
            return true
        }
        if lower.contains(" application - ") || lower.contains(" application | ") || lower.contains(" - application") || lower.contains(" | application") {
            return true
        }
        
        // Document / PDF forms
        if lower.hasSuffix(".pdf") {
            if lower.contains("form") || lower.contains("application") || lower.contains("app") || lower.contains("i-9") || lower.contains("w-4") || lower.contains("w-9") || lower.contains("1040") || lower.contains("worksheet") || lower.contains("quiz") {
                return true
            }
        }
        
        return false
    }
    
    public static func isFormURL(_ urlString: String) -> Bool {
        let lower = urlString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lower.isEmpty else { return false }
        
        let urlPatterns = [
            "docs.google.com/forms",
            "forms.google.com",
            "forms.gle",
            "google.com/forms",
            "forms.office.com",
            "forms.microsoft.com",
            "typeform.com",
            "tally.so",
            "greenhouse.io",
            "lever.co",
            "myworkdayjobs.com",
            "workday.com",
            "ashbyhq.com",
            "smartrecruiters.com",
            "jotform.com",
            "formstack.com",
            "airtable.com/shr",
            "surveymonkey.com",
            "docusign.net",
            "docusign.com",
            "joinhandshake.com",
            "submittable.com",
            "fillout.com",
            "cognitoforms.com",
            "wufoo.com",
            "/apply",
            "/application",
            "/applications",
            "/forms/",
            "/viewform",
            "/formresponse",
            "/quiz",
            "/quizzes/",
            "/assignment",
            "/job-application"
        ]
        
        for p in urlPatterns {
            if lower.contains(p) {
                return true
            }
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
                title = String(title[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return title
    }
    
    // MARK: - Browser & AX Helpers
    public static func isBrowserApplication(_ app: NSRunningApplication) -> Bool {
        let bundle = app.bundleIdentifier?.lowercased() ?? ""
        let name = app.localizedName?.lowercased() ?? ""
        let keywords = [
            "chrome", "chromium", "safari", "polar", "comet", "brave", "edge", "arc",
            "firefox", "opera", "vivaldi", "orion", "zen", "browser",
            "duckduckgo", "floorp", "waterfox", "librewolf", "tor",
            "sigmaos", "wavebox", "webkit"
        ]
        return keywords.contains { bundle.contains($0) || name.contains($0) }
    }
    
    /// Retrieves the main, focused, or primary content AX window of an application.
    /// Crucial discovery: modern browsers (Polar, Arc, WebKit shells) often have invisible/overlay toolbar windows
    /// where kAXMainWindowAttribute points to an accessory window with an empty title.
    /// Searching kAXWindowsAttribute for a titled content window succeeds reliably.
    public static func getBrowserWindowElement(appElem: AXUIElement) -> AXUIElement? {
        var winsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElem, kAXWindowsAttribute as CFString, &winsRef) == .success,
           let wins = winsRef as? [AXUIElement] {
            // Find a window with a non-empty title (content window)
            for win in wins {
                var titleRef: CFTypeRef?
                _ = AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
                let title = (titleRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !title.isEmpty {
                    return win
                }
            }
            if let first = wins.first {
                return first
            }
        }
        var winRef: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(appElem, kAXMainWindowAttribute as CFString, &winRef)
        if winRef == nil {
            _ = AXUIElementCopyAttributeValue(appElem, kAXFocusedWindowAttribute as CFString, &winRef)
        }
        return winRef as! AXUIElement?
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
                    let isAddressBar = desc == "Address and search bar" ||
                                       desc.localizedCaseInsensitiveContains("address") ||
                                       desc.localizedCaseInsensitiveContains("search") ||
                                       desc.localizedCaseInsensitiveContains("url") ||
                                       desc.localizedCaseInsensitiveContains("location") ||
                                       trimmed.contains(".") ||
                                       trimmed.contains("://")
                    if isAddressBar && !trimmed.isEmpty {
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
        
        guard let source = scriptSource, let output = executeSimpleAppleScript(source) else {
            return (nil, nil)
        }
        
        let parts = output.components(separatedBy: " ||| ")
        let url = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
        return (url, title)
    }
    
    private func executeSimpleAppleScript(_ source: String) -> String? {
        if let script = NSAppleScript(source: source) {
            var errorDict: NSDictionary?
            let desc = script.executeAndReturnError(&errorDict)
            if errorDict == nil, let val = desc.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !val.isEmpty {
                return val
            }
        }
        
        // Out-of-process osascript fallback (bypasses in-process AppleEvents entitlement restrictions)
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
        } catch {
            return nil
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
    /// and Polar Chromium host session data. Zero AppleScript overhead, zero permission dialogs.
    public static func checkPolarBrowser() -> FormDetectionResult? {
        let apps = NSWorkspace.shared.runningApplications.filter { app in
            let b = (app.bundleIdentifier ?? "").lowercased()
            let n = (app.localizedName ?? "").lowercased()
            return b.contains("polar") || n.contains("polar")
        }
        guard let polar = apps.first, !polar.isTerminated else { return nil }
        
        let appElem = AXUIElementCreateApplication(polar.processIdentifier)
        var winsRef: CFTypeRef?
        var openTabTitles: [String] = []
        var detectedLiveResult: FormDetectionResult? = nil
        
        if AXUIElementCopyAttributeValue(appElem, kAXWindowsAttribute as CFString, &winsRef) == .success,
           let wins = winsRef as? [AXUIElement] {
            for win in wins {
                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
                let winTitle = (titleRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                // BFS to inspect address bar and tab strip elements (depth <= 8, max 120 elements)
                var queue: [(elem: AXUIElement, depth: Int)] = [(win, 0)]
                var head = 0
                while head < queue.count && head < 120 {
                    let (elem, depth) = queue[head]
                    head += 1
                    
                    var roleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(elem, kAXRoleAttribute as CFString, &roleRef)
                    let role = (roleRef as? String) ?? ""
                    
                    if role == "AXTextField" || role == "AXComboBox" || role == "AXSearchField" {
                        var valRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(elem, kAXValueAttribute as CFString, &valRef) == .success,
                           let val = valRef as? String {
                            let t = val.trimmingCharacters(in: .whitespacesAndNewlines)
                            if isFormURL(t) {
                                let cleaned = cleanTitle(winTitle)
                                let finalTitle = (cleaned.isEmpty || cleaned.localizedCaseInsensitiveContains("not found") || cleaned.localizedCaseInsensitiveContains("untitled")) ? (formNameFromURL(t) ?? "Google Form") : cleaned
                                return FormDetectionResult(
                                    isDetected: true,
                                    title: finalTitle,
                                    appName: "Polar",
                                    url: t,
                                    browserFamily: .polar
                                )
                            }
                        }
                    }
                    
                    if role == "AXStaticText" || role == "AXButton" {
                        var valRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(elem, kAXValueAttribute as CFString, &valRef) == .success,
                           let val = valRef as? String, !val.isEmpty {
                            let text = val.trimmingCharacters(in: .whitespacesAndNewlines)
                            openTabTitles.append(text)
                            if isFormTitle(text) {
                                let cleaned = cleanTitle(text)
                                detectedLiveResult = FormDetectionResult(
                                    isDetected: true,
                                    title: cleaned,
                                    appName: "Polar",
                                    url: "https://docs.google.com/forms",
                                    browserFamily: .polar
                                )
                            }
                        }
                    }
                    
                    if depth >= 8 { continue }
                    var childrenRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(elem, kAXChildrenAttribute as CFString, &childrenRef) == .success,
                       let children = childrenRef as? [AXUIElement] {
                        for c in children { queue.append((c, depth + 1)) }
                    }
                }
                
                if isFormTitle(winTitle) {
                    return FormDetectionResult(
                        isDetected: true,
                        title: cleanTitle(winTitle),
                        appName: "Polar",
                        url: nil,
                        browserFamily: .polar
                    )
                }
            }
        }
        
        // Fast Session Reader: If Polar is running, inspect recent Polar Chromium host session files
        if let sessionForm = readPolarSessionForm() {
            // Confirm the form is either in live open tabs or Polar has valid session
            let matchesLiveTab = openTabTitles.isEmpty || openTabTitles.contains { tab in
                let t = tab.lowercased()
                let st = sessionForm.title.lowercased()
                return st.contains(t) || t.contains(st) || (t.count >= 8 && st.hasPrefix(String(t.prefix(8))))
            }
            if matchesLiveTab {
                return FormDetectionResult(
                    isDetected: true,
                    title: sessionForm.title,
                    appName: "Polar",
                    url: sessionForm.url,
                    browserFamily: .polar
                )
            }
        }
        
        return detectedLiveResult
    }
    
    /// Reads the active form URL and page title directly from Polar Chromium host session binary data
    public static func readPolarSessionForm() -> (url: String, title: String)? {
        let base = ("~/Library/Application Support/com.polar.browser.host" as NSString).expandingTildeInPath
        guard let enumerator = FileManager.default.enumerator(atPath: base) else { return nil }
        
        var sessionFiles: [(path: String, mtime: Date)] = []
        while let file = enumerator.nextObject() as? String {
            if file.contains("Sessions/Session_") {
                let fullPath = (base as NSString).appendingPathComponent(file)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                   let mtime = attrs[.modificationDate] as? Date {
                    // Only consider sessions modified in the last 2 hours
                    if abs(mtime.timeIntervalSinceNow) < 7200 {
                        sessionFiles.append((fullPath, mtime))
                    }
                }
            }
        }
        sessionFiles.sort { $0.mtime > $1.mtime }
        
        let formPatterns = [
            "docs.google.com/forms", "forms.google.com", "forms.gle",
            "forms.office.com", "typeform.com", "tally.so", "jotform.com",
            "greenhouse.io", "lever.co", "myworkdayjobs.com"
        ]
        
        for (filePath, _) in sessionFiles.prefix(4) {
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
                        let cleanURL = rawURL.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        var foundTitle = ""
                        let postURLStart = urlEnd
                        let postURLEnd = min(data.endIndex, data.index(postURLStart, offsetBy: 350))
                        let postChunk = data[postURLStart..<postURLEnd]
                        
                        if postChunk.count >= 8 {
                            var i = postChunk.startIndex
                            while i < postChunk.endIndex - 12 {
                                if postChunk[i] >= 65 && postChunk[i] <= 122 && postChunk[i+1] == 0 && postChunk[i+3] == 0 {
                                    var titleBytes = [UInt8]()
                                    var j = i
                                    while j < postChunk.endIndex - 1 && (postChunk[j+1] == 0 || postChunk[j] == 0) && postChunk[j] >= 32 && postChunk[j] <= 126 {
                                        titleBytes.append(postChunk[j])
                                        titleBytes.append(postChunk[j+1])
                                        j += 2
                                    }
                                    if titleBytes.count >= 8, let tStr = String(data: Data(titleBytes), encoding: .utf16LittleEndian) {
                                        let tClean = tStr.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if !tClean.contains("http") && !tClean.contains("uuid") && !tClean.contains("Blink") && tClean.count > 3 {
                                            foundTitle = tClean
                                            break
                                        }
                                    }
                                }
                                i = data.index(after: i)
                            }
                        }
                        
                        let fallbackTitle = formNameFromURL(cleanURL) ?? "Google Form"
                        return (cleanURL, foundTitle.isEmpty ? fallbackTitle : foundTitle)
                    }
                    searchRange = urlEnd..<data.endIndex
                }
            }
        }
        return nil
    }
    
    /// Specialized check for Apple Safari: inspects documents and tabs
    private func checkSafariBrowser() -> FormDetectionResult? {
        let script = """
        tell application "Safari"
            repeat with d in documents
                set dURL to URL of d
                set dName to name of d
                if dURL contains "forms" or dURL contains "form" or dURL contains "quiz" or dName contains "Form" or dName contains "Quiz" or dName contains "Survey" or dName contains "Application" then
                    return dURL & " ||| " & dName
                end if
            end repeat
            if (count of documents) > 0 then
                return (URL of front document) & " ||| " & (name of front document)
            end if
            return ""
        end tell
        """
        guard let output = executeSimpleAppleScript(script), !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: " ||| ")
        let url = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawTitle = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        
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
    
    /// Specialized check for Chromium family (Chrome, Brave, Edge, Arc, Opera, Vivaldi)
    private func checkChromiumBrowser(appName: String) -> FormDetectionResult? {
        let script = """
        tell application "\(appName)"
            repeat with w in windows
                repeat with t in tabs of w
                    set tURL to URL of t
                    set tTitle to title of t
                    if tURL contains "forms" or tURL contains "form" or tURL contains "quiz" or tTitle contains "Form" or tTitle contains "Quiz" or tTitle contains "Survey" or tTitle contains "Application" then
                        return tURL & " ||| " & tTitle
                    end if
                end repeat
            end repeat
            if (count of windows) > 0 then
                return (URL of active tab of front window) & " ||| " & (title of active tab of front window)
            end if
            return ""
        end tell
        """
        guard let output = executeSimpleAppleScript(script), !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: " ||| ")
        let url = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawTitle = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        
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
                browserFamily: .chromium
            )
        }
        return nil
    }
    
    /// Specialized check for Gecko family (Firefox, Zen Browser, Floorp, Waterfox, LibreWolf, Tor)
    private func checkGeckoBrowser(appName: String) -> FormDetectionResult? {
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
        guard let output = executeSimpleAppleScript(script), !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: " ||| ")
        let url = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawTitle = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
        
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

    /// Specialized check for WebKit shells (Orion, DuckDuckGo)
    private func checkWebKitBrowser(appName: String) -> FormDetectionResult? {
        let lower = appName.lowercased()
        if lower.contains("orion") {
            let script = """
            tell application "Orion"
                repeat with w in windows
                    repeat with t in tabs of w
                        set tURL to URL of t
                        set tTitle to name of t
                        if tURL contains "forms" or tURL contains "form" or tURL contains "quiz" or tTitle contains "Form" or tTitle contains "Quiz" or tTitle contains "Survey" or tTitle contains "Application" then
                            return tURL & " ||| " & tTitle
                        end if
                    end repeat
                end repeat
                if (count of windows) > 0 then
                    return (URL of current tab of front window) & " ||| " & (name of current tab of front window)
                end if
                return ""
            end tell
            """
            if let output = executeSimpleAppleScript(script), !output.isEmpty {
                let parts = output.components(separatedBy: " ||| ")
                let url = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let rawTitle = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
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
        switch family {
        case .polar:
            return Self.checkPolarBrowser()
        case .safari:
            return checkSafariBrowser()
        case .chromium:
            return checkChromiumBrowser(appName: appName)
        case .gecko:
            return checkGeckoBrowser(appName: appName)
        case .webkit:
            return checkWebKitBrowser(appName: appName)
        case .unknown:
            if let app = app {
                return checkGenericBrowser(app: app)
            }
            return nil
        }
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
    
    // MARK: - Detect Active Form Across Every Window
    public func detectActiveApplicationForm() -> FormDetectionResult {
        let ignoredOwners: Set<String> = [
            "window server", "dock", "systemuiserver", "control center",
            "notification center", "spotlight", "loginwindow", "airplayuiagent",
            "coreservicesuiagent", "morph", "morph.app"
        ]
        
        let runningApps = NSWorkspace.shared.runningApplications
        
        // 1. Priority 1: Personalized Default Browser Check (Highest priority!)
        // Understand the user's primary browser choice and inspect it immediately with its tailored engine strategy
        let defaultProfile = PersonalizedBrowserDetector.detectDefaultBrowser()
        let isDefaultRunning = runningApps.contains { app in
            let b = (app.bundleIdentifier ?? "").lowercased()
            let n = (app.localizedName ?? "").lowercased()
            return b == defaultProfile.bundleIdentifier.lowercased() || n == defaultProfile.displayName.lowercased()
        }
        if isDefaultRunning {
            if let result = checkBrowserByFamily(family: defaultProfile.family, appName: defaultProfile.displayName, bundleID: defaultProfile.bundleIdentifier) {
                return result
            }
        }
        
        // 2. Priority 2: Check frontmost application
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let bundleID = frontApp.bundleIdentifier?.lowercased() ?? ""
            let frontAppName = frontApp.localizedName ?? "Application"
            let frontPID = frontApp.processIdentifier
            
            if !bundleID.contains("finder") && !bundleID.contains("morph") && !bundleID.contains("terminal") && !bundleID.contains("dt.xcode") {
                let isBrowser = Self.isBrowserApplication(frontApp)
                let appElem = AXUIElementCreateApplication(frontPID)
                
                if let winElement = Self.getBrowserWindowElement(appElem: appElem) {
                    // 2a. Fast Live Address Bar / WebArea URL Inspection
                    if isBrowser, let url = Self.findAddressBarOrWebAreaURL(in: winElement), Self.isFormURL(url) {
                        var titleRef: CFTypeRef?
                        _ = AXUIElementCopyAttributeValue(winElement, kAXTitleAttribute as CFString, &titleRef)
                        let rawTitle = titleRef as? String ?? ""
                        let cleaned = Self.cleanTitle(rawTitle)
                        let finalTitle: String
                        if cleaned.isEmpty || cleaned.localizedCaseInsensitiveContains("not found") || cleaned.localizedCaseInsensitiveContains("untitled") {
                            finalTitle = Self.formNameFromURL(url) ?? "Google Form"
                        } else {
                            finalTitle = cleaned
                        }
                        let family = PersonalizedBrowserDetector.engineFamily(for: bundleID, name: frontAppName)
                        return FormDetectionResult(
                            isDetected: true,
                            title: finalTitle,
                            appName: frontAppName,
                            url: url,
                            browserFamily: family
                        )
                    }
                    
                    // 2b. Window Title Inspection
                    var titleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(winElement, kAXTitleAttribute as CFString, &titleRef) == .success,
                       let rawTitle = titleRef as? String {
                        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        if Self.isFormTitle(title) {
                            let browserURL = isBrowser ? Self.findAddressBarOrWebAreaURL(in: winElement) : nil
                            let family = PersonalizedBrowserDetector.engineFamily(for: bundleID, name: frontAppName)
                            return FormDetectionResult(
                                isDetected: true,
                                title: Self.cleanTitle(title),
                                appName: frontAppName,
                                url: browserURL,
                                browserFamily: family
                            )
                        }
                    }
                }
                
                // Frontmost browser tab info check
                let family = PersonalizedBrowserDetector.engineFamily(for: bundleID, name: frontAppName)
                if let result = checkBrowserByFamily(family: family, appName: frontAppName, bundleID: bundleID, app: frontApp) {
                    return result
                }
            }
        }
        
        // 3. Priority 3: Scan running browsers across the computer in ranked order
        let rankedBrowsers = PersonalizedBrowserDetector.rankedRunningBrowsers()
        for app in rankedBrowsers {
            let pid = app.processIdentifier
            let appName = app.localizedName ?? "Browser"
            let bID = (app.bundleIdentifier ?? "").lowercased()
            let family = PersonalizedBrowserDetector.engineFamily(for: bID, name: appName)
            let appElem = AXUIElementCreateApplication(pid)
            let win = Self.getBrowserWindowElement(appElem: appElem)
            let url = win != nil ? Self.findAddressBarOrWebAreaURL(in: win!) : nil
            
            if let win = win {
                // Check address bar / web area URL
                if let url = url, Self.isFormURL(url) {
                    var titleRef: CFTypeRef?
                    _ = AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
                    let rawTitle = titleRef as? String ?? ""
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
                        url: url,
                        browserFamily: family
                    )
                }
                
                // Check window title
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let rawTitle = titleRef as? String {
                    let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    if Self.isFormTitle(title) {
                        return FormDetectionResult(
                            isDetected: true,
                            title: Self.cleanTitle(title),
                            appName: appName,
                            url: url,
                            browserFamily: family
                        )
                    }
                }
            }
            
            // Specialized browser fallback for this running browser
            if let result = checkBrowserByFamily(family: family, appName: appName, bundleID: bID, app: app) {
                return result
            }
        }
        
        // 4. Priority 4: Scan across EVERY window of the computer in z-order (CGWindowListCopyWindowInfo)
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        if let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
            for win in windowList {
                let owner = (win[kCGWindowOwnerName as String] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let lowerOwner = owner.lowercased()
                if ignoredOwners.contains(lowerOwner) || lowerOwner.contains("morph") {
                    continue
                }
                
                let layer = win[kCGWindowLayer as String] as? Int ?? -1
                guard layer == 0 else { continue } // Normal application window layer
                
                let bounds = win[kCGWindowBounds as String] as? [String: Any] ?? [:]
                let width = bounds["Width"] as? CGFloat ?? 0
                let height = bounds["Height"] as? CGFloat ?? 0
                guard width >= 100 && height >= 100 else { continue } // Ignore micro utility/overlay windows
                
                let title = (win[kCGWindowName as String] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { continue }
                
                if Self.isFormTitle(title) {
                    let cleanedTitle = Self.cleanTitle(title)
                    let appName = owner.isEmpty ? "Application" : owner
                    let browserURL = fetchURLForRunningBrowser(ownerName: owner)
                    let family = PersonalizedBrowserDetector.engineFamily(for: "", name: owner)
                    return FormDetectionResult(
                        isDetected: true,
                        title: cleanedTitle,
                        appName: appName,
                        url: browserURL,
                        browserFamily: family
                    )
                }
            }
        }
        
        return FormDetectionResult(isDetected: false)
    }
    
    public static func formNameFromURL(_ urlString: String) -> String? {
        let lower = urlString.lowercased()
        if lower.contains("docs.google.com/forms") || lower.contains("forms.google.com") || lower.contains("forms.gle") {
            return "Google Form"
        } else if lower.contains("forms.office.com") || lower.contains("forms.microsoft.com") {
            return "Microsoft Form"
        } else if lower.contains("typeform.com") {
            return "Typeform"
        } else if lower.contains("tally.so") {
            return "Tally Form"
        } else if lower.contains("greenhouse.io") {
            return "Greenhouse Job Application"
        } else if lower.contains("lever.co") {
            return "Lever Job Application"
        } else if lower.contains("workday") {
            return "Workday Job Application"
        } else if lower.contains("ashby") {
            return "Ashby Job Application"
        }
        return nil
    }
}

public struct MockApplicationFormDetector: ApplicationFormDetectorProtocol {
    public var detected: Bool
    public var title: String?
    public var appName: String?
    public var url: String?
    
    public init(detected: Bool = false, title: String? = nil, appName: String? = nil, url: String? = nil) {
        self.detected = detected
        self.title = title
        self.appName = appName
        self.url = url
    }
    
    public func detectActiveApplicationForm() -> FormDetectionResult {
        return FormDetectionResult(isDetected: detected, title: title, appName: appName, url: url)
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
    
    public struct RetrievedFormSchema: Sendable, Equatable {
        public var title: String
        public var description: String
        public var fields: [FormInputField]
        
        public init(title: String, description: String, fields: [FormInputField]) {
            self.title = title
            self.description = description
            self.fields = fields
        }
    }
    
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
            
            let isRequired: Bool
            if let first = firstEntry, first.count > 2, let reqInt = first[2] as? Int {
                isRequired = (reqInt == 1)
            } else {
                isRequired = false
            }
            
            let qType: String
            let cat: FormFieldCategory
            switch rawType {
            case 0:
                qType = "shortAnswer"
                cat = inferCategory(from: prompt)
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
                qType = "text"
                cat = inferCategory(from: prompt)
            }
            
            let field = FormInputField(
                label: prompt,
                value: "",
                category: cat,
                questionDescription: subtext,
                options: options,
                questionType: qType,
                isRequired: isRequired,
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
                
                let isReq = blockHTML.contains("required") || blockHTML.contains("aria-required=\"true\"") || label.hasSuffix("*")
                let cleanLabel = label.replacingOccurrences(of: "\\*$", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
                
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
    
    /// Autonomously retrieves form content and question schema from any URL or local file path
    public static func retrieveForm(from urlString: String) async -> RetrievedFormSchema? {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
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
    private weak var formModel: ApplicationFormModel?
    private var globalKeyMonitor: Any?
    private var axSyncTimer: AnyCancellable?
    public private(set) var isRunning: Bool = false
    
    public init(model: ApplicationFormModel) {
        self.formModel = model
    }
    
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        setupKeyMonitor()
        setupAXSync()
    }
    
    public func stop() {
        isRunning = false
        if let mon = globalKeyMonitor {
            NSEvent.removeMonitor(mon)
            globalKeyMonitor = nil
        }
        axSyncTimer?.cancel()
        axSyncTimer = nil
    }
    
    private func setupKeyMonitor() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self, self.isRunning else { return }
            self.handleGlobalKeyEvent(event)
        }
    }
    
    private func setupAXSync() {
        // Fast 0.5s poll to sync focused element value, selections, and live browser input changes
        axSyncTimer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.syncFocusedElement()
                    self?.formModel?.syncLiveFormInputValues()
                }
            }
    }
    
    public func handleGlobalKeyEvent(_ event: NSEvent) {
        let keyCode = event.keyCode
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let characters = event.characters
        
        Task { @MainActor [weak self] in
            guard let self = self, let model = self.formModel else { return }
            guard model.isFormDetected && model.isAutoCaptureEnabled,
                  let session = model.activeSession, !session.fields.isEmpty else { return }
            
            // Only capture if frontmost application is the detected browser / form host
            guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
            let frontBundle = frontApp.bundleIdentifier?.lowercased() ?? ""
            let frontName = frontApp.localizedName?.lowercased() ?? ""
            
            // Do NOT intercept if typing inside Morph itself
            if frontBundle.contains("com.morph.") || frontBundle == "morph" || frontName == "morph" {
                return
            }
            
            let isTargetApp = DefaultApplicationFormDetector.isBrowserApplication(frontApp) ||
                              frontName.contains(model.detectedAppName.lowercased()) ||
                              model.detectedAppName.lowercased().contains(frontName)
            guard isTargetApp else { return }
            
            // If Cmd or Ctrl is pressed:
            if flags.contains(.command) || flags.contains(.control) {
                // If Cmd+V (paste into browser field), trigger immediate AX sync in 120ms
                if keyCode == 9 {
                    Task { @MainActor [weak self] in
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        self?.syncFocusedElement()
                    }
                }
                return
            }
            
            let count = model.activeSession?.fields.count ?? 0
            guard count > 0 else { return }
            var activeIdx = model.activeFieldIndex
            if activeIdx >= count { activeIdx = count - 1 }
            if activeIdx < 0 { activeIdx = 0 }
            
            // 1. Backspace / Delete (KeyCode 51)
            if keyCode == 51 {
                if !(model.activeSession?.fields[activeIdx].value.isEmpty ?? true) {
                    model.activeSession?.fields[activeIdx].value.removeLast()
                    model.lastAutoCapturedAt = Date()
                }
                return
            }
            
            // 2. Tab Navigation (KeyCode 48)
            if keyCode == 48 {
                if flags.contains(.shift) {
                    model.activeFieldIndex = max(0, activeIdx - 1)
                } else {
                    model.activeFieldIndex = min(count - 1, activeIdx + 1)
                }
                return
            }
            
            // 3. Return / Enter (KeyCode 36)
            if keyCode == 36 {
                let qType = model.activeSession?.fields[activeIdx].questionType ?? ""
                if qType == "paragraph" {
                    model.activeSession?.fields[activeIdx].value.append("\n")
                    model.lastAutoCapturedAt = Date()
                } else {
                    model.activeFieldIndex = min(count - 1, activeIdx + 1)
                }
                return
            }
            
            // 4. Printable Characters
            if let chars = characters, !chars.isEmpty {
                let printable = chars.filter { ch in
                    guard let s = ch.unicodeScalars.first else { return false }
                    return s.value >= 32 && s.value != 127
                }
                guard !printable.isEmpty else { return }
                
                model.activeSession?.fields[activeIdx].value.append(printable)
                model.lastAutoCapturedAt = Date()
                
                // Email detection: if user types email in any field, auto-update recipientEmail
                let curVal = model.activeSession?.fields[activeIdx].value ?? ""
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
            }
        }
    }
    
    @MainActor
    public func syncFocusedElement() {
        guard let model = formModel, model.isFormDetected, model.isAutoCaptureEnabled,
              let session = model.activeSession, !session.fields.isEmpty else { return }
        
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              DefaultApplicationFormDetector.isBrowserApplication(frontApp) else { return }
        
        let appElem = AXUIElementCreateApplication(frontApp.processIdentifier)
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElem, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focused = focusedRef else { return }
        let elem = focused as! AXUIElement
        
        var roleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(elem, kAXRoleAttribute as CFString, &roleRef)
        let role = (roleRef as? String) ?? ""
        
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(elem, kAXTitleAttribute as CFString, &titleRef)
        var descRef: CFTypeRef?
        AXUIElementCopyAttributeValue(elem, kAXDescriptionAttribute as CFString, &descRef)
        var elemTitle = ((titleRef as? String) ?? (descRef as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If elemTitle is empty or generic (e.g. "Your answer"), resolve question heading via ancestor walk
        if elemTitle.isEmpty || elemTitle.lowercased() == "your answer" || elemTitle.lowercased() == "address and search bar" {
            if let resolved = FormInputAutoTracker.findQuestionTitleForElement(elem) {
                elemTitle = resolved
            }
        }
        
        var valRef: CFTypeRef?
        AXUIElementCopyAttributeValue(elem, kAXValueAttribute as CFString, &valRef)
        let textVal = valRef as? String
        
        // 1. If focused element title/desc matches a question label, align activeFieldIndex
        if !elemTitle.isEmpty {
            if let matchedIdx = session.fields.firstIndex(where: {
                let fl = $0.label.lowercased()
                let el = elemTitle.lowercased()
                return fl == el || fl.contains(el) || el.contains(fl)
            }) {
                if model.activeFieldIndex != matchedIdx {
                    model.activeFieldIndex = matchedIdx
                }
            }
        }
        
        let activeIdx = model.activeFieldIndex
        guard activeIdx < (model.activeSession?.fields.count ?? 0) else { return }
        
        // 2. Text input sync
        if (role == "AXTextField" || role == "AXTextArea" || role == "AXSearchField" || role == "AXComboBox") {
            if let tv = textVal, !tv.isEmpty {
                let current = model.activeSession?.fields[activeIdx].value ?? ""
                if current != tv {
                    model.activeSession?.fields[activeIdx].value = tv
                    model.lastAutoCapturedAt = Date()
                }
            }
        }
        
        // 3. Radio button / Checkbox selection sync
        if role == "AXRadioButton" || role == "AXCheckBox" {
            var checkedRef: CFTypeRef?
            AXUIElementCopyAttributeValue(elem, kAXValueAttribute as CFString, &checkedRef)
            let isChecked = (checkedRef as? Int == 1) || (checkedRef as? Bool == true)
            if isChecked && !elemTitle.isEmpty {
                let current = model.activeSession?.fields[activeIdx].value ?? ""
                if current != elemTitle {
                    model.activeSession?.fields[activeIdx].value = elemTitle
                    model.lastAutoCapturedAt = Date()
                }
            }
        }
    }
    
    // MARK: - Hierarchy Inspection Helpers
    /// Resolves the question title for a focused or scanned element by checking direct attributes,
    /// title UI elements, or climbing ancestor containers to find question headings in Google Forms and web forms.
    public static func findQuestionTitleForElement(_ elem: AXUIElement) -> String? {
        let genericIgnored = ["your answer", "address and search bar", "search", "text", "edit", "input"]
        
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(elem, kAXTitleAttribute as CFString, &titleRef)
        var descRef: CFTypeRef?
        AXUIElementCopyAttributeValue(elem, kAXDescriptionAttribute as CFString, &descRef)
        let t = ((titleRef as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let d = ((descRef as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !t.isEmpty && !genericIgnored.contains(t.lowercased()) {
            return t
        }
        if !d.isEmpty && !genericIgnored.contains(d.lowercased()) {
            return d
        }
        
        // Check kAXTitleUIElementAttribute
        var titleElemRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(elem, kAXTitleUIElementAttribute as CFString, &titleElemRef) == .success,
           let titleElem = titleElemRef {
            let te = titleElem as! AXUIElement
            var valRef: CFTypeRef?
            AXUIElementCopyAttributeValue(te, kAXValueAttribute as CFString, &valRef)
            var tRef: CFTypeRef?
            AXUIElementCopyAttributeValue(te, kAXTitleAttribute as CFString, &tRef)
            let s = ((valRef as? String) ?? (tRef as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty && !genericIgnored.contains(s.lowercased()) {
                return s
            }
        }
        
        // Climb ancestors up to 4 levels
        var current = elem
        for _ in 0..<4 {
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
                    if role == "AXHeading" || role == "AXStaticText" {
                        var vRef: CFTypeRef?, cTitleRef: CFTypeRef?
                        AXUIElementCopyAttributeValue(ch, kAXValueAttribute as CFString, &vRef)
                        AXUIElementCopyAttributeValue(ch, kAXTitleAttribute as CFString, &cTitleRef)
                        let text = ((vRef as? String) ?? (cTitleRef as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                        if !text.isEmpty && text != "*" && !genericIgnored.contains(text.lowercased()) {
                            return text
                        }
                    }
                }
            }
        }
        return nil
    }
    
    /// Scans the browser content window to extract live input field values paired with their question labels.
    public static func scanBrowserWindowInputs(appElem: AXUIElement) -> [(label: String, value: String)]? {
        guard let win = DefaultApplicationFormDetector.getBrowserWindowElement(appElem: appElem) else {
            return nil
        }
        
        var results: [(label: String, value: String)] = []
        var queue: [AXUIElement] = [win]
        var head = 0
        let maxElements = 250
        
        while head < queue.count && head < maxElements {
            let current = queue[head]
            head += 1
            
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(current, kAXRoleAttribute as CFString, &roleRef)
            let role = (roleRef as? String) ?? ""
            
            if role == "AXTextField" || role == "AXTextArea" || role == "AXSearchField" || role == "AXComboBox" {
                var descRef: CFTypeRef?
                AXUIElementCopyAttributeValue(current, kAXDescriptionAttribute as CFString, &descRef)
                let desc = (descRef as? String) ?? ""
                if desc != "Address and search bar" && !desc.localizedCaseInsensitiveContains("address") {
                    var valRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(current, kAXValueAttribute as CFString, &valRef)
                    let textVal = (valRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !textVal.isEmpty {
                        let label = findQuestionTitleForElement(current) ?? desc
                        if !label.isEmpty {
                            results.append((label: label, value: textVal))
                        }
                    }
                }
            } else if role == "AXRadioButton" || role == "AXCheckBox" {
                var checkedRef: CFTypeRef?
                AXUIElementCopyAttributeValue(current, kAXValueAttribute as CFString, &checkedRef)
                let isChecked = (checkedRef as? Int == 1) || (checkedRef as? Bool == true)
                if isChecked {
                    var titleRef: CFTypeRef?
                    AXUIElementCopyAttributeValue(current, kAXTitleAttribute as CFString, &titleRef)
                    let optionTitle = (titleRef as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let qLabel = findQuestionTitleForElement(current) ?? ""
                    if !qLabel.isEmpty && !optionTitle.isEmpty {
                        results.append((label: qLabel, value: optionTitle))
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
        return results
    }
    
    /// Extracts live question inputs from scriptable browsers (Safari, Chrome, Brave, Arc, Edge) via AppleScript.
    public static func extractInputsViaAppleScript(bundleID: String) -> [(label: String, value: String)]? {
        let b = bundleID.lowercased()
        let isChrome = b.contains("chrome") || b.contains("brave") || b.contains("edge") || b.contains("arc") || b.contains("vivaldi") || b.contains("opera")
        let isSafari = b.contains("safari") && !b.contains("technology")
        guard isChrome || isSafari else { return nil }
        
        let jsSnippet = """
        (function() {
            var out = [];
            var items = document.querySelectorAll('div[role=\"listitem\"], .Qr7Oae, .question, .form-group');
            if (items.length > 0) {
                for (var i = 0; i < items.length; i++) {
                    var item = items[i];
                    var h = item.querySelector('[role=\"heading\"], .M7eMe, label, h2, h3, h4');
                    var title = h ? h.innerText.replace(/[*\\n\\r]+/g, ' ').trim() : '';
                    var val = '';
                    var inp = item.querySelector('input.whsOnd, input[type=\"text\"], input[type=\"email\"], textarea.KHxj8b, textarea');
                    if (inp && inp.value) val = inp.value.trim();
                    if (!val) {
                        var rad = item.querySelector('[role=\"radio\"][aria-checked=\"true\"], input[type=\"radio\"]:checked');
                        if (rad) val = rad.getAttribute('data-value') || rad.getAttribute('aria-label') || rad.value || rad.innerText.trim();
                    }
                    if (!val) {
                        var chk = item.querySelectorAll('[role=\"checkbox\"][aria-checked=\"true\"], input[type=\"checkbox\"]:checked');
                        if (chk.length > 0) {
                            var cs = [];
                            for (var j = 0; j < chk.length; j++) {
                                var cv = chk[j].getAttribute('data-value') || chk[j].getAttribute('aria-label') || chk[j].value || chk[j].innerText.trim();
                                if (cv) cs.push(cv);
                            }
                            val = cs.join(', ');
                        }
                    }
                    if (title && val) out.push(title + ':::' + val);
                }
            } else {
                var inps = document.querySelectorAll('input:not([type=\"hidden\"]), textarea');
                for (var k = 0; k < inps.length; k++) {
                    var el = inps[k];
                    var l = el.getAttribute('aria-label') || el.name || el.placeholder || '';
                    if (l && el.value) out.push(l + ':::' + el.value.trim());
                }
            }
            return out.join('|||');
        })()
        """
        
        let scriptSource: String
        if isChrome {
            let escapedJS = jsSnippet.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: " ")
            scriptSource = """
            tell application id "\(bundleID)"
                if (count of windows) > 0 then
                    return execute front window's active tab javascript "\(escapedJS)"
                end if
            end tell
            """
        } else {
            let escapedJS = jsSnippet.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: " ")
            scriptSource = """
            tell application id "com.apple.Safari"
                if (count of documents) > 0 then
                    return do JavaScript "\(escapedJS)" in current tab of front window
                end if
            end tell
            """
        }
        
        guard let output = executeAppleScript(scriptSource), !output.isEmpty else { return nil }
        var results: [(label: String, value: String)] = []
        for pair in output.components(separatedBy: "|||") {
            let parts = pair.components(separatedBy: ":::")
            if parts.count >= 2 {
                let lbl = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let val = parts[1...].joined(separator: ":::").trimmingCharacters(in: .whitespacesAndNewlines)
                if !lbl.isEmpty && !val.isEmpty {
                    results.append((label: lbl, value: val))
                }
            }
        }
        return results
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

// MARK: - Main ApplicationFormModel
@MainActor
public final class ApplicationFormModel: ObservableObject {
    @Published public var activeSession: ApplicationFormSession?
    @Published public var isFormDetected: Bool = false
    @Published public var isJustDetected: Bool = false
    @Published public var detectedFormTitle: String = ""
    @Published public var detectedAppName: String = ""
    @Published public var detectedURL: String? = nil
    @Published public var detectedBrowserFamily: BrowserEngineFamily = .unknown
    @Published public var userDefaultBrowser: UserBrowserProfile
    @Published public var isTracking: Bool = false
    @Published public var isAutoCaptureEnabled: Bool = true
    @Published public var recipientEmail: String = ""
    @Published public var deliveryToastMessage: String? = nil
    @Published public var historySessions: [ApplicationFormSession] = []
    @Published public var activeFieldIndex: Int = 0
    @Published public var isAutoRetrievingSchema: Bool = false
    @Published public var lastAutoCapturedAt: Date? = nil
    
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
    
    public init(
        detector: ApplicationFormDetectorProtocol = DefaultApplicationFormDetector(),
        dispatcher: ApplicationEmailDispatcherProtocol = DefaultEmailDispatcher(),
        userDefaultBrowser: UserBrowserProfile? = nil
    ) {
        self.detector = detector
        self.dispatcher = dispatcher
        self.userDefaultBrowser = userDefaultBrowser ?? PersonalizedBrowserDetector.detectDefaultBrowser()
        
        if !MorphEnvironment.isTestingEnvironment {
            self.autoTracker = FormInputAutoTracker(model: self)
            self.autoTracker?.start()
            startPolling()
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
        
        // 4. Fast 1.0s periodic timer monitoring all on-screen windows across the computer
        pollTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkActiveApplication()
            }
    }
    
    // MARK: - Active Form Detection
    public func checkActiveApplication() {
        let result = detector.detectActiveApplicationForm()
        if result.isDetected {
            let title = result.title ?? "Application Form"
            let app = result.appName ?? userDefaultBrowser.displayName
            let url = result.url
            let family = result.browserFamily ?? PersonalizedBrowserDetector.engineFamily(for: "", name: app)
            
            if !self.isFormDetected {
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
            self.detectedURL = url
            self.detectedBrowserFamily = family
            
            // If not tracking and a form is newly detected, automatically initiate or stage session
            if activeSession == nil {
                startTracking(title: title, appName: app, url: url)
            } else {
                if activeSession?.formTitle == "Application Form" && title != "Application Form" {
                    activeSession?.formTitle = title
                    activeSession?.sourceAppName = app
                }
                if let u = url, !u.isEmpty {
                    if activeSession?.sourceURL != u {
                        activeSession?.sourceURL = u
                        self.detectedURL = u
                        autoRetrieveFormContent(url: u)
                    } else if (activeSession?.fields.isEmpty ?? true) && !isAutoRetrievingSchema {
                        autoRetrieveFormContent(url: u)
                    }
                }
                syncLiveFormInputValues()
            }
        } else {
            // If Morph itself is frontmost and we already have an active form session,
            // retain the state while the user interacts with the Notch/HUD
            if let frontApp = NSWorkspace.shared.frontmostApplication {
                let bundleID = frontApp.bundleIdentifier?.lowercased() ?? ""
                if (bundleID.contains("com.morph.") || bundleID == "morph" || bundleID.hasSuffix(".morph")) && self.isFormDetected {
                    return
                }
            }
            
            // Strictly context-aware: when no form is detected across any window, reset isFormDetected immediately
            self.isFormDetected = false
            self.isJustDetected = false
            self.detectedBrowserFamily = .unknown
            justDetectedResetTask?.cancel()
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
        let finalUrl = url ?? detectedURL
        let emailToUse = (defaultEmail?.isEmpty == false ? defaultEmail! : (recipientEmail.isEmpty ? "user@example.com" : recipientEmail))
        
        self.recipientEmail = emailToUse
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
        
        if let formURL = finalUrl, !formURL.isEmpty {
            autoRetrieveFormContent(url: formURL)
        }
    }
    
    public func stopTracking() {
        if var session = activeSession {
            session.completedAt = Date()
            historySessions.insert(session, at: 0)
        }
        self.activeSession = nil
        self.activeFieldIndex = 0
        self.isTracking = false
        self.isFormDetected = false
        self.isJustDetected = false
        self.justDetectedResetTask?.cancel()
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
                            if let existing = current.first(where: {
                                $0.label.lowercased() == merged[i].label.lowercased() ||
                                ($0.entryKey != nil && $0.entryKey == merged[i].entryKey)
                            }) {
                                if !existing.value.isEmpty && merged[i].value.isEmpty {
                                    merged[i].value = existing.value
                                }
                            }
                        }
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
                }
                
                // Immediately synchronize live inputs from browser
                self.syncLiveFormInputValues()
            }
        }
    }
    
    // MARK: - Live Input Hydration & Synchronization
    @MainActor
    public func syncLiveFormInputValues() {
        guard isFormDetected, isAutoCaptureEnabled,
              let session = activeSession, !session.fields.isEmpty else { return }
        
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
        
        // 2. Scan running browser windows via AXUIElement
        let runningBrowsers = PersonalizedBrowserDetector.rankedRunningBrowsers()
        var targetApps = runningBrowsers
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           DefaultApplicationFormDetector.isBrowserApplication(frontApp) && !targetApps.contains(frontApp) {
            targetApps.insert(frontApp, at: 0)
        }
        
        for app in targetApps {
            let appElem = AXUIElementCreateApplication(app.processIdentifier)
            if let pairs = FormInputAutoTracker.scanBrowserWindowInputs(appElem: appElem), !pairs.isEmpty {
                for pair in pairs {
                    applyExtractedInput(label: pair.label, value: pair.value)
                }
            }
        }
        
        // 3. Fallback for scriptable browsers (Safari, Chrome) via AppleScript DOM extraction
        for app in targetApps {
            let bid = app.bundleIdentifier ?? ""
            if let pairs = FormInputAutoTracker.extractInputsViaAppleScript(bundleID: bid), !pairs.isEmpty {
                for pair in pairs {
                    applyExtractedInput(label: pair.label, value: pair.value)
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
    
    @discardableResult
    public func applyExtractedInput(label: String, value: String) -> Bool {
        guard let session = activeSession, !session.fields.isEmpty else { return false }
        let cleanVal = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanVal.isEmpty else { return false }
        
        let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // 1. Exact or substring match by label
        if let idx = session.fields.firstIndex(where: {
            let fl = $0.label.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            return fl == cleanLabel || fl.contains(cleanLabel) || cleanLabel.contains(fl)
        }) {
            if activeSession?.fields[idx].value != cleanVal {
                activeSession?.fields[idx].value = cleanVal
                lastAutoCapturedAt = Date()
                return true
            }
        }
        return false
    }
    
    public func selectActiveField(_ index: Int) {
        guard let fields = activeSession?.fields, index >= 0 && index < fields.count else { return }
        self.activeFieldIndex = index
    }
    
    public func updateFieldByIndex(_ index: Int, value: String) {
        guard let fields = activeSession?.fields, index >= 0 && index < fields.count else { return }
        activeSession?.fields[index].value = value
        lastAutoCapturedAt = Date()
    }
    
    public func setRecipientEmail(_ email: String) {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        self.recipientEmail = trimmed
        if activeSession != nil {
            activeSession?.recipientEmail = trimmed
        }
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
        activeSession?.fields[idx].value = value
    }
    
    public func removeField(id: UUID) {
        activeSession?.fields.removeAll(where: { $0.id == id })
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
