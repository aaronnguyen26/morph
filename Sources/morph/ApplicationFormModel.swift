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
    
    public init(
        id: UUID = UUID(),
        label: String,
        value: String,
        category: FormFieldCategory = .custom,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.category = category
        self.timestamp = timestamp
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
        lastDispatchedAt: Date? = nil
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
        lines.append("")
        lines.append("---")
        lines.append("## Captured Input Fields (\(fields.count))")
        lines.append("")
        
        if fields.isEmpty {
            lines.append("*(No fields captured)*")
        } else {
            for (idx, field) in fields.enumerated() {
                lines.append("### \(idx + 1). \(field.label) [\(field.category.rawValue)]")
                if field.value.contains("\n") || field.wordCount >= 10 {
                    lines.append(field.value)
                    lines.append("*(Word count: \(field.wordCount))*")
                } else {
                    lines.append("> \(field.value)")
                }
                lines.append("")
            }
        }
        lines.append("---")
        lines.append("*Captured automatically by Morph Context Engine • Form Copilot*")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Detector Protocols
public struct FormDetectionResult: Sendable, Equatable {
    public var isDetected: Bool
    public var title: String?
    public var appName: String?
    public var url: String?
    
    public init(isDetected: Bool, title: String? = nil, appName: String? = nil, url: String? = nil) {
        self.isDetected = isDetected
        self.title = title
        self.appName = appName
        self.url = url
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
            "fill & sign", "interactive form"
        ]
        
        for kw in keywords {
            if lower.contains(kw) {
                return true
            }
        }
        
        // Suffix & separator patterns: e.g. "Customer Inquiry Form", "Program - Application"
        if lower.hasSuffix(" form") || lower.hasSuffix(" forms") || lower.hasSuffix(" application") || lower.hasSuffix(" questionnaire") || lower.hasSuffix(" survey") {
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
            if lower.contains("form") || lower.contains("application") || lower.contains("app") || lower.contains("i-9") || lower.contains("w-4") || lower.contains("w-9") || lower.contains("1040") {
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
        let suffixes = [
            " - Google Chrome",
            " - Safari",
            " - Polar",
            " - Comet",
            " - Brave",
            " - Microsoft Edge",
            " - Arc",
            " — Mozilla Firefox",
            " - Vivaldi",
            " - Opera",
            " - Orion",
            " - Zen Browser"
        ]
        for s in suffixes {
            if title.hasSuffix(s) {
                title = String(title.dropLast(s.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return title
    }
    
    // MARK: - Browser & AX Helpers
    public static func isBrowserApplication(_ app: NSRunningApplication) -> Bool {
        let bundle = app.bundleIdentifier?.lowercased() ?? ""
        let name = app.localizedName?.lowercased() ?? ""
        let keywords = [
            "chrome", "safari", "polar", "comet", "brave", "edge", "arc",
            "firefox", "opera", "vivaldi", "orion", "zen", "browser"
        ]
        return keywords.contains { bundle.contains($0) || name.contains($0) }
    }
    
    public static func findBrowserAddressBarURL(in element: AXUIElement, maxDepth: Int = 6) -> String? {
        guard maxDepth > 0 else { return nil }
        var roleVal: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleVal)
        if let role = roleVal as? String, role == "AXTextField" {
            var valVal: AnyObject?
            if AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valVal) == .success,
               let str = valVal as? String, !str.isEmpty {
                let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.contains(".") || trimmed.contains("://") || trimmed.contains("localhost") {
                    return trimmed
                }
            }
        }
        
        var childrenVal: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenVal) == .success,
           let children = childrenVal as? [AXUIElement] {
            for c in children {
                if let found = findBrowserAddressBarURL(in: c, maxDepth: maxDepth - 1) {
                    return found
                }
            }
        }
        return nil
    }
    
    public static func findBrowserTabTitles(in element: AXUIElement, maxDepth: Int = 5) -> [String] {
        guard maxDepth > 0 else { return [] }
        var results: [String] = []
        var roleVal: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleVal)
        let role = roleVal as? String ?? ""
        
        if role == "AXStaticText" || role == "AXRadioButton" || role == "AXTab" {
            var valVal: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valVal)
            if let v = valVal as? String, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                results.append(v.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            var titleVal: AnyObject?
            AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleVal)
            if let t = titleVal as? String, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed != (valVal as? String) {
                    results.append(trimmed)
                }
            }
        }
        
        var childrenVal: AnyObject?
        if AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenVal) == .success,
           let children = childrenVal as? [AXUIElement] {
            for c in children {
                results.append(contentsOf: findBrowserTabTitles(in: c, maxDepth: maxDepth - 1))
            }
        }
        return results
    }
    
    // MARK: - Browser Tab Inspection
    private func fetchFrontmostBrowserTabInfo(bundleID: String) -> (url: String?, title: String?) {
        let scriptSource: String?
        if bundleID.contains("google.chrome") || bundleID.contains("brave") || bundleID.contains("edge") || bundleID.contains("arc") {
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
        
        guard let source = scriptSource, let appleScript = NSAppleScript(source: source) else {
            return (nil, nil)
        }
        
        var errorDict: NSDictionary?
        let desc = appleScript.executeAndReturnError(&errorDict)
        guard errorDict == nil, let output = desc.stringValue, !output.isEmpty else {
            return (nil, nil)
        }
        
        let parts = output.components(separatedBy: " ||| ")
        let url = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
        return (url, title)
    }
    
    private func executeSimpleAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var errorDict: NSDictionary?
        let desc = script.executeAndReturnError(&errorDict)
        guard errorDict == nil, let val = desc.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !val.isEmpty else {
            return nil
        }
        return val
    }
    
    private func fetchURLForRunningBrowser(ownerName: String) -> String? {
        let lower = ownerName.lowercased()
        if lower.contains("chrome") {
            return executeSimpleAppleScript("tell application \"Google Chrome\" to if (count of windows) > 0 then return URL of active tab of front window")
        } else if lower.contains("safari") {
            return executeSimpleAppleScript("tell application \"Safari\" to if (count of documents) > 0 then return URL of front document")
        } else if lower.contains("brave") {
            return executeSimpleAppleScript("tell application \"Brave Browser\" to if (count of windows) > 0 then return URL of active tab of front window")
        } else if lower.contains("edge") {
            return executeSimpleAppleScript("tell application \"Microsoft Edge\" to if (count of windows) > 0 then return URL of active tab of front window")
        } else if lower.contains("arc") {
            return executeSimpleAppleScript("tell application \"Arc\" to if (count of windows) > 0 then return URL of active tab of front window")
        }
        return nil
    }
    
    private func checkRunningBrowsersForFormURLs(windowList: [[String: Any]]) -> FormDetectionResult? {
        let browserConfigs: [(ownerKey: String, appName: String, script: String)] = [
            ("chrome", "Google Chrome", "tell application \"Google Chrome\" to if (count of windows) > 0 then return (URL of active tab of front window) & \" ||| \" & (title of active tab of front window)"),
            ("safari", "Safari", "tell application \"Safari\" to if (count of documents) > 0 then return (URL of front document) & \" ||| \" & (name of front document)"),
            ("brave", "Brave Browser", "tell application \"Brave Browser\" to if (count of windows) > 0 then return (URL of active tab of front window) & \" ||| \" & (title of active tab of front window)"),
            ("edge", "Microsoft Edge", "tell application \"Microsoft Edge\" to if (count of windows) > 0 then return (URL of active tab of front window) & \" ||| \" & (title of active tab of front window)"),
            ("arc", "Arc", "tell application \"Arc\" to if (count of windows) > 0 then return (URL of active tab of front window) & \" ||| \" & (title of active tab of front window)")
        ]
        
        for config in browserConfigs {
            let hasOnScreenWindow = windowList.contains { win in
                let owner = (win[kCGWindowOwnerName as String] as? String ?? "").lowercased()
                let layer = win[kCGWindowLayer as String] as? Int ?? -1
                return layer == 0 && owner.contains(config.ownerKey)
            }
            guard hasOnScreenWindow else { continue }
            
            if let output = executeSimpleAppleScript(config.script) {
                let parts = output.components(separatedBy: " ||| ")
                let url = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !url.isEmpty && Self.isFormURL(url) {
                    let rawTitle = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                    let cleaned = Self.cleanTitle(rawTitle)
                    let finalTitle = cleaned.isEmpty ? (Self.formNameFromURL(url) ?? "Application Form") : cleaned
                    return FormDetectionResult(
                        isDetected: true,
                        title: finalTitle,
                        appName: config.appName,
                        url: url
                    )
                }
            }
        }
        return nil
    }
    
    // MARK: - Detect Active Form Across Every Window
    public func detectActiveApplicationForm() -> FormDetectionResult {
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return FormDetectionResult(isDetected: false)
        }
        
        let ignoredOwners: Set<String> = [
            "window server", "dock", "systemuiserver", "control center",
            "notification center", "spotlight", "loginwindow", "airplayuiagent",
            "coreservicesuiagent", "morph", "morph.app"
        ]
        
        // 1. Priority 1: Check frontmost application
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let bundleID = frontApp.bundleIdentifier?.lowercased() ?? ""
            let frontAppName = frontApp.localizedName ?? "Application"
            let frontPID = frontApp.processIdentifier
            
            if !bundleID.contains("finder") && !bundleID.contains("morph") && !bundleID.contains("terminal") && !bundleID.contains("dt.xcode") {
                let isBrowser = Self.isBrowserApplication(frontApp)
                let appElem = AXUIElementCreateApplication(frontPID)
                
                var winRef: CFTypeRef?
                _ = AXUIElementCopyAttributeValue(appElem, kAXFocusedWindowAttribute as CFString, &winRef)
                if winRef == nil {
                    _ = AXUIElementCopyAttributeValue(appElem, kAXMainWindowAttribute as CFString, &winRef)
                }
                
                if let win = winRef {
                    let winElement = win as! AXUIElement
                    
                    // 1a. Fast Address Bar URL Inspection (Polar, Chrome, Safari, Comet, Brave, etc.)
                    if isBrowser, let url = Self.findBrowserAddressBarURL(in: winElement), Self.isFormURL(url) {
                        var titleRef: CFTypeRef?
                        _ = AXUIElementCopyAttributeValue(winElement, kAXTitleAttribute as CFString, &titleRef)
                        let rawTitle = titleRef as? String ?? ""
                        let cleaned = Self.cleanTitle(rawTitle)
                        let finalTitle = cleaned.isEmpty ? (Self.formNameFromURL(url) ?? "Google Form") : cleaned
                        return FormDetectionResult(
                            isDetected: true,
                            title: finalTitle,
                            appName: frontAppName,
                            url: url
                        )
                    }
                    
                    // 1b. Focused Window Title Inspection
                    var titleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(winElement, kAXTitleAttribute as CFString, &titleRef) == .success,
                       let rawTitle = titleRef as? String {
                        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        if Self.isFormTitle(title) {
                            let browserURL = isBrowser ? Self.findBrowserAddressBarURL(in: winElement) : nil
                            return FormDetectionResult(
                                isDetected: true,
                                title: Self.cleanTitle(title),
                                appName: frontAppName,
                                url: browserURL
                            )
                        }
                    }
                    
                    // 1c. Tab Bar Inspection in Browser
                    if isBrowser {
                        let tabs = Self.findBrowserTabTitles(in: winElement)
                        for tab in tabs {
                            if Self.isFormTitle(tab) {
                                return FormDetectionResult(
                                    isDetected: true,
                                    title: Self.cleanTitle(tab),
                                    appName: frontAppName,
                                    url: Self.findBrowserAddressBarURL(in: winElement)
                                )
                            }
                        }
                    }
                }
                
                // AppleScript fallback for frontmost scriptable browser
                let tabInfo = fetchFrontmostBrowserTabInfo(bundleID: bundleID)
                if let tabURL = tabInfo.url, !tabURL.isEmpty, Self.isFormURL(tabURL) {
                    let rawTitle = tabInfo.title ?? ""
                    let cleaned = Self.cleanTitle(rawTitle)
                    let finalTitle = cleaned.isEmpty ? (Self.formNameFromURL(tabURL) ?? "Application Form") : cleaned
                    return FormDetectionResult(
                        isDetected: true,
                        title: finalTitle,
                        appName: frontAppName,
                        url: tabURL
                    )
                }
            }
        }
        
        // 2. Priority 2: Scan running browsers across the computer for open form tabs or URLs
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && Self.isBrowserApplication(app) {
            let pid = app.processIdentifier
            let appName = app.localizedName ?? "Browser"
            let appElem = AXUIElementCreateApplication(pid)
            
            var winsVal: AnyObject?
            if AXUIElementCopyAttributeValue(appElem, kAXWindowsAttribute as CFString, &winsVal) == .success,
               let wins = winsVal as? [AXUIElement] {
                for win in wins {
                    // Check address bar
                    if let url = Self.findBrowserAddressBarURL(in: win), Self.isFormURL(url) {
                        var titleRef: CFTypeRef?
                        _ = AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
                        let rawTitle = titleRef as? String ?? ""
                        let cleaned = Self.cleanTitle(rawTitle)
                        let finalTitle = cleaned.isEmpty ? (Self.formNameFromURL(url) ?? "Google Form") : cleaned
                        return FormDetectionResult(
                            isDetected: true,
                            title: finalTitle,
                            appName: appName,
                            url: url
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
                                url: Self.findBrowserAddressBarURL(in: win)
                            )
                        }
                    }
                    
                    // Check visible tabs
                    let tabs = Self.findBrowserTabTitles(in: win)
                    for tab in tabs {
                        if Self.isFormTitle(tab) {
                            return FormDetectionResult(
                                isDetected: true,
                                title: Self.cleanTitle(tab),
                                appName: appName,
                                url: Self.findBrowserAddressBarURL(in: win)
                            )
                        }
                    }
                }
            }
        }
        
        // Priority 2b: Scriptable browser AppleScript fallback
        if let result = checkRunningBrowsersForFormURLs(windowList: windowList) {
            return result
        }
        
        // 3. Priority 3: Scan across EVERY window of the computer in z-order (CGWindowListCopyWindowInfo)
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
                return FormDetectionResult(
                    isDetected: true,
                    title: cleanedTitle,
                    appName: appName,
                    url: browserURL
                )
            }
        }
        
        return FormDetectionResult(isDetected: false)
    }
    
    private static func formNameFromURL(_ urlString: String) -> String? {
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

// MARK: - Main ApplicationFormModel
@MainActor
public final class ApplicationFormModel: ObservableObject {
    @Published public var activeSession: ApplicationFormSession?
    @Published public var isFormDetected: Bool = false
    @Published public var isJustDetected: Bool = false
    @Published public var detectedFormTitle: String = ""
    @Published public var detectedAppName: String = ""
    @Published public var detectedURL: String? = nil
    @Published public var isTracking: Bool = false
    @Published public var isAutoCaptureEnabled: Bool = true
    @Published public var recipientEmail: String = ""
    @Published public var deliveryToastMessage: String? = nil
    @Published public var historySessions: [ApplicationFormSession] = []
    
    public var detector: ApplicationFormDetectorProtocol
    public var dispatcher: ApplicationEmailDispatcherProtocol
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
        dispatcher: ApplicationEmailDispatcherProtocol = DefaultEmailDispatcher()
    ) {
        self.detector = detector
        self.dispatcher = dispatcher
        
        if !MorphEnvironment.isTestingEnvironment {
            startPolling()
        }
    }
    
    public func stopPolling() {
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
            let app = result.appName ?? "Browser"
            let url = result.url
            
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
            
            // If not tracking and a form is newly detected, automatically initiate or stage session
            if activeSession == nil {
                startTracking(title: title, appName: app, url: url)
            } else if activeSession?.formTitle == "Application Form" && title != "Application Form" {
                activeSession?.formTitle = title
                activeSession?.sourceAppName = app
                if url != nil { activeSession?.sourceURL = url }
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
        self.isTracking = true
        self.isFormDetected = true
        self.detectedFormTitle = finalTitle
        self.detectedAppName = finalApp
        self.detectedURL = finalUrl
    }
    
    public func stopTracking() {
        if var session = activeSession {
            session.completedAt = Date()
            historySessions.insert(session, at: 0)
        }
        self.activeSession = nil
        self.isTracking = false
        self.isFormDetected = false
        self.isJustDetected = false
        self.justDetectedResetTask?.cancel()
        self.onFormClosed?()
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
