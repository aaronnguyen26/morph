import Cocoa
import SwiftUI
import Combine

public struct DetectedMeetingInfo: Equatable, Sendable {
    public var isDetected: Bool
    public var service: MeetingService
    public var title: String
    public var url: URL?
    public var browserBundleID: String?
    public var browserName: String?
    public var isLobbyOrPreJoin: Bool
    public var isInCall: Bool
    
    public init(
        isDetected: Bool = false,
        service: MeetingService = .genericWeb,
        title: String = "",
        url: URL? = nil,
        browserBundleID: String? = nil,
        browserName: String? = nil,
        isLobbyOrPreJoin: Bool = false,
        isInCall: Bool = false
    ) {
        self.isDetected = isDetected
        self.service = service
        self.title = title
        self.url = url
        self.browserBundleID = browserBundleID
        self.browserName = browserName
        self.isLobbyOrPreJoin = isLobbyOrPreJoin
        self.isInCall = isInCall
    }
}

public protocol MeetingAppDetector: Sendable {
    @MainActor func detectRunningMeetingApp() -> (isRunning: Bool, appName: String?)
    @MainActor func detectMeetingContext() -> DetectedMeetingInfo?
}

extension MeetingAppDetector {
    @MainActor
    public func detectMeetingContext() -> DetectedMeetingInfo? {
        let (running, name) = detectRunningMeetingApp()
        if running {
            let svc = (name?.lowercased().contains("zoom") == true) ? MeetingService.zoom : .genericWeb
            return DetectedMeetingInfo(
                isDetected: true,
                service: svc,
                title: name ?? "Active Call",
                url: nil,
                browserBundleID: nil,
                browserName: name,
                isLobbyOrPreJoin: false,
                isInCall: true
            )
        }
        return nil
    }
}

public struct DefaultMeetingAppDetector: MeetingAppDetector {
    public init() {}
    
    @MainActor
    public func detectRunningMeetingApp() -> (isRunning: Bool, appName: String?) {
        if let info = detectMeetingContext(), info.isDetected {
            return (true, info.browserName ?? info.service.rawValue)
        }
        return (false, nil)
    }
    
    @MainActor
    public func detectMeetingContext() -> DetectedMeetingInfo? {
        // 1. Check in-app Morph meeting engine
        if InAppMeetingEngine.shared.isInCall {
            return DetectedMeetingInfo(
                isDetected: true,
                service: InAppMeetingEngine.shared.activeService,
                title: InAppMeetingEngine.shared.activeCallTitle ?? "Morph Stage Call",
                url: InAppMeetingEngine.shared.currentMeetingURL,
                browserBundleID: nil,
                browserName: "Morph Stage",
                isLobbyOrPreJoin: false,
                isInCall: true
            )
        }
        
        // 2. Fast WindowServer inspection across on-screen windows (layer == 0, visible dimensions)
        let options = CGWindowListOption(arrayLiteral: .excludeDesktopElements, .optionOnScreenOnly)
        if let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
            for win in list {
                let owner = win[kCGWindowOwnerName as String] as? String ?? ""
                let title = win[kCGWindowName as String] as? String ?? ""
                let layer = win[kCGWindowLayer as String] as? Int ?? -1
                let bounds = win[kCGWindowBounds as String] as? [String: Any] ?? [:]
                let w = bounds["Width"] as? Double ?? 0
                let h = bounds["Height"] as? Double ?? 0
                
                guard layer == 0 && w >= 260 && h >= 180 else { continue }
                
                if let parsed = Self.parseMeetingWindowTitle(title, owner: owner) {
                    let service = parsed.service
                    let isLobby = parsed.isLobby
                    let inCall = parsed.isInCall
                    
                    let cleanTitle = Self.cleanedMeetingTitle(title, service: service)
                    let bundleID = Self.bundleIDForAppOwner(owner)
                    
                    return DetectedMeetingInfo(
                        isDetected: true,
                        service: service,
                        title: cleanTitle,
                        url: nil,
                        browserBundleID: bundleID,
                        browserName: owner,
                        isLobbyOrPreJoin: isLobby,
                        isInCall: inCall
                    )
                }
            }
        }
        
        // 3. Browser Tab Inspection for running browsers (Chrome, Safari, Polar, Arc, Brave, Edge, etc.)
        if let browserInfo = Self.inspectBrowserTabsForMeetings() {
            return browserInfo
        }
        
        return nil
    }
    
    /// Parses window title and owner name to identify Google Meet or Zoom
    public static func parseMeetingWindowTitle(_ title: String, owner: String = "") -> (service: MeetingService, isLobby: Bool, isInCall: Bool)? {
        let lowerTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lowerOwner = owner.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Immediately ignore ended or left calls
        if lowerTitle.contains("you left the meeting") ||
           lowerTitle.contains("left the call") ||
           lowerTitle.contains("đã rời khỏi cuộc họp") ||
           lowerTitle.contains("meeting ended") ||
           lowerTitle.contains("call ended") {
            return nil
        }
        
        // A. Google Meet in Browser
        let isMeetTitle = lowerTitle.contains("meet – ") ||
                          lowerTitle.contains("meet - ") ||
                          lowerTitle.contains("google meet") ||
                          lowerTitle.hasPrefix("meet:") ||
                          lowerTitle.contains("meet.google.com")
                          
        if isMeetTitle {
            let isLobby = lowerTitle.contains("ready to join") ||
                          lowerTitle.contains("sẵn sàng tham gia") ||
                          lowerTitle.contains("ask to join") ||
                          lowerTitle.contains("getting ready")
            return (.googleMeet, isLobby, !isLobby)
        }
        
        // B. Native Zoom App
        if lowerOwner.contains("zoom") {
            if lowerTitle.contains("zoom meeting") ||
               lowerTitle.contains("zoom webinar") ||
               (lowerTitle.contains("meeting") && !lowerTitle.contains("left")) {
                let isLobby = lowerTitle.contains("launch") || lowerTitle.contains("waiting") || lowerTitle.contains("joining")
                return (.zoom, isLobby, !isLobby)
            }
        }
        
        // C. Zoom Web in Browser or standalone window
        if lowerTitle.contains("zoom meeting") ||
           lowerTitle.contains("zoom webinar") ||
           lowerTitle.contains("launch meeting - zoom") ||
           lowerTitle.contains("zoom - launching") ||
           lowerTitle.contains("zoom – launching") ||
           (lowerTitle.contains("zoom") && (lowerTitle.contains("launch") || lowerTitle.contains("waiting") || lowerTitle.contains("call") || lowerTitle.contains("join") || lowerTitle.contains("meeting") || lowerTitle.contains("webinar"))) {
            let isLobby = lowerTitle.contains("launch") || lowerTitle.contains("waiting") || lowerTitle.contains("joining")
            return (.zoom, isLobby, !isLobby)
        }
        
        return nil
    }
    
    public static func cleanedMeetingTitle(_ title: String, service: MeetingService) -> String {
        var clean = title
        let prefixes = ["Meet – ", "Meet - ", "Meet: ", "Google Meet – ", "Google Meet - ", "Launch Meeting - Zoom"]
        for p in prefixes {
            if clean.hasPrefix(p) {
                clean = String(clean.dropFirst(p.count))
            }
        }
        let suffixes = [" - Google Chrome", " - Safari", " - Arc", " - Brave", " - Microsoft Edge", " - Polar", " - Zoom"]
        for s in suffixes {
            if clean.hasSuffix(s) {
                clean = String(clean.dropLast(s.count))
            }
        }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            return service == .googleMeet ? "Google Meet" : "Zoom Meeting"
        }
        return clean
    }
    
    public static func bundleIDForAppOwner(_ owner: String) -> String? {
        let lower = owner.lowercased()
        for app in NSWorkspace.shared.runningApplications {
            let appName = (app.localizedName ?? "").lowercased()
            if appName == lower || lower.contains(appName) {
                return app.bundleIdentifier
            }
        }
        return nil
    }
    
    /// Queries running web browsers to detect active Google Meet or Zoom tabs
    private static func inspectBrowserTabsForMeetings() -> DetectedMeetingInfo? {
        let runningApps = NSWorkspace.shared.runningApplications
        
        let targetBrowsers: [(bundleID: String, name: String)] = [
            ("com.google.Chrome", "Google Chrome"),
            ("com.apple.Safari", "Safari"),
            ("company.thebrowser.Browser", "Arc"),
            ("com.brave.Browser", "Brave"),
            ("com.microsoft.edgemac", "Microsoft Edge")
        ]
        
        for browser in targetBrowsers {
            guard runningApps.contains(where: { $0.bundleIdentifier == browser.bundleID }) else { continue }
            
            let script: String
            if browser.bundleID.contains("Safari") {
                script = """
                tell application "Safari"
                    if (count of documents) > 0 then
                        repeat with w in windows
                            repeat with t in tabs of w
                                set u to URL of t
                                if u contains "meet.google.com" or u contains "zoom.us" then
                                    return u & " ||| " & (name of t)
                                end if
                            end repeat
                        end repeat
                    end if
                    return ""
                end tell
                """
            } else {
                script = """
                tell application id "\(browser.bundleID)"
                    if (count of windows) > 0 then
                        repeat with w in windows
                            repeat with t in tabs of w
                                set u to URL of t
                                if u contains "meet.google.com" or u contains "zoom.us" then
                                    return u & " ||| " & (title of t)
                                end if
                            end repeat
                        end repeat
                    end if
                    return ""
                end tell
                """
            }
            
            if let output = DefaultApplicationFormDetector.executeSimpleAppleScript(script), !output.isEmpty {
                let parts = output.components(separatedBy: " ||| ")
                let urlStr = parts.first?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
                let titleStr = parts.count > 1 ? parts[1].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) : ""
                
                // Discard landing pages without meeting codes
                if urlStr.hasSuffix("meet.google.com/") || urlStr.hasSuffix("meet.google.com/landing") {
                    continue
                }
                
                let service: MeetingService = urlStr.contains("zoom.us") ? .zoom : .googleMeet
                let isLobby = titleStr.lowercased().contains("ready to join") ||
                              titleStr.lowercased().contains("sẵn sàng tham gia") ||
                              titleStr.lowercased().contains("launch meeting") ||
                              urlStr.contains("/wc/join")
                
                return DetectedMeetingInfo(
                    isDetected: true,
                    service: service,
                    title: cleanedMeetingTitle(titleStr, service: service),
                    url: URL(string: urlStr),
                    browserBundleID: browser.bundleID,
                    browserName: browser.name,
                    isLobbyOrPreJoin: isLobby,
                    isInCall: !isLobby
                )
            }
        }
        
        return nil
    }
}

@MainActor
public final class MeetingFlightControllerModel: ObservableObject {
    @Published public var upcomingMeeting: CalendarEvent?
    @Published public var isPreMeetingWindow: Bool = false
    @Published public var isInCall: Bool = false {
        didSet {
            updateActiveOrDetectedState()
        }
    }
    @Published public var isMeetingDetected: Bool = false {
        didSet {
            updateActiveOrDetectedState()
        }
    }
    @Published public var isLobbyOrPreJoin: Bool = false
    @Published public var isMeetingActiveOrDetected: Bool = false
    @Published public var detectedMeetingInfo: DetectedMeetingInfo? {
        didSet {
            if let info = detectedMeetingInfo {
                self.isMeetingDetected = info.isDetected
                self.isMeetingActiveOrDetected = info.isDetected
                self.detectedAppName = info.browserName ?? info.service.rawValue
                self.activeService = info.service
                self.detectedBrowserBundleID = info.browserBundleID
                self.detectedMeetingURL = info.url
                self.isLobbyOrPreJoin = info.isLobbyOrPreJoin
                if info.isInCall && !self.isInCall {
                    self.startCall(title: info.title.isEmpty ? info.service.rawValue : info.title)
                }
            } else {
                self.isMeetingDetected = false
                self.isLobbyOrPreJoin = false
                self.detectedBrowserBundleID = nil
                self.detectedMeetingURL = nil
                if !self.engine.isInCall {
                    self.isInCall = false
                    self.isMeetingActiveOrDetected = false
                    self.activeCallTitle = nil
                    self.activeCallDuration = 0
                    self.formattedCallDuration = "00:00"
                } else {
                    self.isMeetingActiveOrDetected = self.isInCall
                }
            }
        }
    }
    
    @Published public var detectedMeetingURL: URL?
    @Published public var detectedBrowserBundleID: String?
    @Published public var activeCallTitle: String?
    @Published public var callStartedAt: Date?
    @Published public var activeCallDuration: TimeInterval = 0
    @Published public var formattedCallDuration: String = "00:00"
    @Published public var isMuted: Bool = false
    @Published public var quickNotes: String = ""
    @Published public var detectedAppName: String?
    @Published public var activeService: MeetingService = .genericWeb
    
    public var detector: MeetingAppDetector
    public var urlOpener: ((URL) -> Bool)?
    public let engine: InAppMeetingEngine
    
    private var timerCancellable: AnyCancellable?
    private var scanCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    private static var isTestingEnvironment: Bool {
        return MorphEnvironment.isTestingEnvironment
    }
    
    public init(
        detector: MeetingAppDetector? = nil,
        urlOpener: ((URL) -> Bool)? = nil,
        engine: InAppMeetingEngine? = nil
    ) {
        self.detector = detector ?? DefaultMeetingAppDetector()
        self.urlOpener = urlOpener
        self.engine = engine ?? (Self.isTestingEnvironment ? InAppMeetingEngine() : InAppMeetingEngine.shared)
        
        setupEngineObservers()
        
        if !Self.isTestingEnvironment {
            startPeriodicCallTimer()
            startPeriodicAppScanning()
        }
    }
    
    private func updateActiveOrDetectedState() {
        let active = isInCall || isMeetingDetected
        if self.isMeetingActiveOrDetected != active {
            self.isMeetingActiveOrDetected = active
        }
    }
    
    private func setupEngineObservers() {
        engine.$isInCall
            .sink { [weak self] inCall in
                guard let self = self else { return }
                if self.isInCall != inCall {
                    self.isInCall = inCall
                    if !inCall {
                        self.callStartedAt = nil
                        self.activeCallDuration = 0
                        self.formattedCallDuration = "00:00"
                        self.activeCallTitle = nil
                    }
                    self.updateActiveOrDetectedState()
                }
            }
            .store(in: &cancellables)
            
        engine.$formattedCallDuration
            .sink { [weak self] duration in
                guard let self = self, self.engine.isInCall else { return }
                self.formattedCallDuration = duration
            }
            .store(in: &cancellables)
            
        engine.$activeService
            .assign(to: \.activeService, on: self)
            .store(in: &cancellables)
            
        engine.$isMuted
            .assign(to: \.isMuted, on: self)
            .store(in: &cancellables)
            
        engine.onCallEnded = { [weak self] in
            guard let self = self else { return }
            self.isInCall = false
            self.isMeetingDetected = false
            self.callStartedAt = nil
            self.activeCallDuration = 0
            self.formattedCallDuration = "00:00"
            self.activeCallTitle = nil
            self.isMuted = false
            self.updateActiveOrDetectedState()
        }
    }
    
    // MARK: - Upcoming Meetings Evaluation
    
    public func updateFromCalendar(events: [CalendarEvent], now: Date = Date()) {
        let upcoming = events.filter { event in
            guard hasMeetingLinkOrLocation(event) else { return false }
            
            // Event is upcoming or currently running
            let timeUntilStart = event.startTime.timeIntervalSince(now)
            let hasEnded = event.endTime <= now
            
            // Starting within 10 minutes (600s) or currently ongoing
            return !hasEnded && (timeUntilStart <= 10 * 60)
        }
        .sorted { $0.startTime < $1.startTime }
        .first
        
        self.upcomingMeeting = upcoming
        
        if let upcoming = upcoming {
            let timeUntilStart = upcoming.startTime.timeIntervalSince(now)
            // Pre-meeting readiness window: within 5 minutes of start (300s)
            self.isPreMeetingWindow = timeUntilStart <= 5 * 60 && timeUntilStart > -60
        } else {
            self.isPreMeetingWindow = false
        }
    }
    
    public func hasMeetingLinkOrLocation(_ event: CalendarEvent) -> Bool {
        if let link = event.meetLink, !link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if let loc = event.location, extractMeetingURL(from: loc) != nil {
            return true
        }
        if extractMeetingURL(from: event.description) != nil {
            return true
        }
        return false
    }
    
    public func extractMeetingURL(from text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        for match in matches ?? [] {
            if let url = match.url {
                let urlStr = url.absoluteString.lowercased()
                if urlStr.contains("zoom.us") ||
                    urlStr.contains("meet.google.com") ||
                    urlStr.contains("teams.microsoft.com") ||
                    urlStr.contains("webex.com") {
                    return url
                }
            }
        }
        
        // Fallback to any valid HTTP/HTTPS URL
        if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.scheme == "http" || url.scheme == "https" {
            return url
        }
        
        return nil
    }
    
    public func resolvedMeetingURL(for event: CalendarEvent) -> URL? {
        if let link = event.meetLink?.trimmingCharacters(in: .whitespacesAndNewlines),
           let url = URL(string: link), url.scheme != nil {
            return url
        }
        if let loc = event.location, let url = extractMeetingURL(from: loc) {
            return url
        }
        if let url = extractMeetingURL(from: event.description) {
            return url
        }
        return nil
    }
    
    // MARK: - Actions
    
    @discardableResult
    public func openMeetLink(event: CalendarEvent? = nil, inApp: Bool = true, scratchpad: ScratchpadModel? = nil) -> Bool {
        let targetEvent = event ?? upcomingMeeting
        guard let targetEvent = targetEvent,
              let url = resolvedMeetingURL(for: targetEvent) else {
            return false
        }
        
        self.activeService = MeetingService.detect(url: url)
        
        if let customOpener = urlOpener {
            let opened = customOpener(url)
            if opened {
                startCall(title: targetEvent.title)
            }
            return opened
        }
        
        if inApp {
            // Direct In-Morph Call Stage for Zoom & Google Meet
            let started = engine.startCall(url: url, title: targetEvent.title, scratchpadModel: scratchpad)
            if started {
                startCall(title: targetEvent.title)
            }
            return started
        } else {
            let opened = NSWorkspace.shared.open(url)
            if opened {
                startCall(title: targetEvent.title)
            }
            return opened
        }
    }
    
    public func startCall(title: String? = nil, startTime: Date = Date()) {
        self.isInCall = true
        self.isLobbyOrPreJoin = false
        self.activeCallTitle = title ?? upcomingMeeting?.title ?? (self.activeService == .googleMeet ? "Google Meet" : "Zoom Meeting")
        self.callStartedAt = startTime
        self.activeCallDuration = 0
        self.formattedCallDuration = "00:00"
        self.isPreMeetingWindow = false
        updateActiveOrDetectedState()
    }
    
    /// Joins the detected Google Meet or Zoom call automatically (wired into browser or in-app stage)
    public func joinDetectedMeeting() {
        // 1. If in-app Morph meeting engine is loaded
        if engine.isInCall {
            let joinScript = """
            (function() {
                var btns = Array.from(document.querySelectorAll('button, div[role="button"]'));
                for (var i = 0; i < btns.length; i++) {
                    var text = (btns[i].innerText || btns[i].textContent || '').trim().toLowerCase();
                    var label = (btns[i].getAttribute('aria-label') || '').toLowerCase();
                    var jsname = btns[i].getAttribute('jsname') || '';
                    if (jsname === 'Qx7uuf' || text === 'join now' || text === 'ask to join' || text === 'tham gia ngay' || label.includes('join now') || label.includes('ask to join')) {
                        btns[i].click();
                        return 'joined';
                    }
                }
                var zBtn = document.querySelector('button.join-btn, button[aria-label*="Join"], .preview-join-button');
                if (zBtn) { zBtn.click(); return 'joined'; }
                return 'not_found';
            })()
            """
            engine.webView.evaluateJavaScript(joinScript) { _, _ in }
            self.isLobbyOrPreJoin = false
            self.startCall(title: self.activeCallTitle)
            return
        }
        
        // 2. If detected in external browser (Google Meet or Zoom Web)
        let joinJS = """
        (function() {
            var btns = Array.from(document.querySelectorAll('button, div[role="button"]'));
            for (var i = 0; i < btns.length; i++) {
                var text = (btns[i].innerText || btns[i].textContent || '').trim().toLowerCase();
                var label = (btns[i].getAttribute('aria-label') || '').toLowerCase();
                var jsname = btns[i].getAttribute('jsname') || '';
                if (jsname === 'Qx7uuf' || text === 'join now' || text === 'ask to join' || text === 'tham gia ngay' || label.includes('join now') || label.includes('ask to join')) {
                    btns[i].click();
                    return 'joined';
                }
            }
            var zBtn = document.querySelector('button.join-btn, button[aria-label*="Join"], .preview-join-button');
            if (zBtn) { zBtn.click(); return 'joined'; }
            return 'not_found';
        })()
        """
        if let bundleID = detectedBrowserBundleID {
            Self.executeScriptInBrowser(bundleID: bundleID, script: joinJS)
        } else {
            let browsers = ["com.google.Chrome", "com.apple.Safari", "company.thebrowser.Browser", "com.brave.Browser", "com.microsoft.edgemac", "com.polar.browser"]
            for b in browsers {
                Self.executeScriptInBrowser(bundleID: b, script: joinJS)
            }
        }
        
        // 3. Mark call as active
        self.startCall(title: self.activeCallTitle ?? (self.activeService == .googleMeet ? "Google Meet" : "Zoom Meeting"))
        self.isLobbyOrPreJoin = false
    }
    
    /// Ends the active call and disconnects Google Meet or Zoom (wired into browser, native app, or in-app stage)
    public func endCall() {
        self.isInCall = false
        self.isMeetingDetected = false
        self.detectedMeetingInfo = nil
        self.isLobbyOrPreJoin = false
        self.callStartedAt = nil
        self.activeCallDuration = 0
        self.formattedCallDuration = "00:00"
        self.activeCallTitle = nil
        self.isMuted = false
        updateActiveOrDetectedState()
        
        // 1. Cleanly close in-app meeting stage and stop WebRTC camera/mic
        if engine.isInCall {
            engine.leaveAndCloseCall()
        }
        
        // 2. Wired disconnect for browser-based Google Meet and Zoom
        let leaveJS = """
        (function() {
            var meetLeave = document.querySelector('button[aria-label*="Leave call"], button[aria-label*="Rời khỏi cuộc gọi"], button[jsname="CQylAd"], button[data-call-ended]');
            if (meetLeave) { meetLeave.click(); return 'left'; }
            
            var zoomLeave = document.querySelector('.footer__leave-btn, button[aria-label*="Leave"], button[aria-label*="End"]');
            if (zoomLeave) {
                zoomLeave.click();
                setTimeout(function() {
                    var confirm = document.querySelector('button.zm-btn--danger, .leave-meeting-options button');
                    if (confirm) { confirm.click(); }
                }, 150);
                return 'left';
            }
            
            var btns = Array.from(document.querySelectorAll('button'));
            for (var i = 0; i < btns.length; i++) {
                var label = (btns[i].getAttribute('aria-label') || '').toLowerCase();
                if (label.includes('leave call') || label.includes('end call') || label.includes('rời khỏi')) {
                    btns[i].click();
                    return 'left';
                }
            }
            return 'not_found';
        })()
        """
        
        if let bundleID = detectedBrowserBundleID {
            Self.executeScriptInBrowser(bundleID: bundleID, script: leaveJS)
        } else {
            let browsers = ["com.google.Chrome", "com.apple.Safari", "company.thebrowser.Browser", "com.brave.Browser", "com.microsoft.edgemac", "com.polar.browser"]
            for b in browsers {
                Self.executeScriptInBrowser(bundleID: b, script: leaveJS)
            }
        }
        
        // 3. Wired disconnect for native Zoom app via AppleScript shortcut
        let zoomScript = """
        tell application "System Events"
            if exists process "zoom.us" then
                tell process "zoom.us"
                    set frontmost to true
                    keystroke "w" using command down
                    delay 0.15
                    keystroke return
                end tell
            end if
        end tell
        """
        _ = DefaultApplicationFormDetector.executeSimpleAppleScript(zoomScript)
    }
    
    public func toggleMute() {
        self.isMuted.toggle()
        if engine.isInCall {
            engine.toggleMute()
        }
        
        let muteJS = """
        (function() {
            var meetMic = document.querySelector('button[aria-label*="microphone"], button[aria-label*="Microphone"], button[data-is-muted]');
            if (meetMic) { meetMic.click(); return 'toggled'; }
            
            var zoomMic = document.querySelector('.join-audio, .audio-option button, button[aria-label*="mute"], button[aria-label*="Mute"]');
            if (zoomMic) { zoomMic.click(); return 'toggled'; }
            return 'not_found';
        })()
        """
        if let bundleID = detectedBrowserBundleID {
            Self.executeScriptInBrowser(bundleID: bundleID, script: muteJS)
        }
    }
    
    public func toggleCamera() {
        if engine.isInCall {
            engine.toggleCamera()
        }
        
        let camJS = """
        (function() {
            var meetCam = document.querySelector('button[aria-label*="camera"], button[aria-label*="Camera"]');
            if (meetCam) { meetCam.click(); return 'toggled'; }
            
            var zoomCam = document.querySelector('.video-option button, button[aria-label*="video"], button[aria-label*="Video"]');
            if (zoomCam) { zoomCam.click(); return 'toggled'; }
            return 'not_found';
        })()
        """
        if let bundleID = detectedBrowserBundleID {
            Self.executeScriptInBrowser(bundleID: bundleID, script: camJS)
        }
    }
    
    @discardableResult
    public static func executeScriptInBrowser(bundleID: String, script: String) -> String? {
        let escapedScript = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            
        let scriptSource: String
        if bundleID.contains("Safari") {
            scriptSource = """
            tell application "Safari"
                if (count of documents) > 0 then
                    repeat with w in windows
                        repeat with t in tabs of w
                            set u to URL of t
                            if u contains "meet.google.com" or u contains "zoom.us" then
                                tell t to do JavaScript "\(escapedScript)"
                                return "executed"
                            end if
                        end repeat
                    end repeat
                end if
                return ""
            end tell
            """
        } else {
            scriptSource = """
            tell application id "\(bundleID)"
                if (count of windows) > 0 then
                    repeat with w in windows
                        repeat with t in tabs of w
                            set u to URL of t
                            if u contains "meet.google.com" or u contains "zoom.us" then
                                tell t to execute javascript "\(escapedScript)"
                                return "executed"
                            end if
                        end repeat
                    end repeat
                end if
                return ""
            end tell
            """
        }
        
        return DefaultApplicationFormDetector.executeSimpleAppleScript(scriptSource)
    }
    
    public func tickCallTimer(seconds: TimeInterval = 1) {
        guard isInCall else { return }
        activeCallDuration += seconds
        formatDuration()
    }
    
    private func formatDuration() {
        let totalSeconds = Int(activeCallDuration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            formattedCallDuration = String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            formattedCallDuration = String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    public func checkRunningMeetingApps() {
        if let info = detector.detectMeetingContext(), info.isDetected {
            self.isMeetingDetected = true
            self.detectedAppName = info.browserName ?? info.service.rawValue
            self.activeService = info.service
            self.detectedBrowserBundleID = info.browserBundleID
            self.detectedMeetingURL = info.url
            self.isLobbyOrPreJoin = info.isLobbyOrPreJoin
            
            if info.isInCall {
                if !self.isInCall {
                    self.startCall(title: info.title.isEmpty ? info.service.rawValue : info.title)
                } else {
                    if let newTitle = Optional(info.title), !newTitle.isEmpty {
                        self.activeCallTitle = newTitle
                    }
                }
            } else if info.isLobbyOrPreJoin {
                self.activeCallTitle = info.title.isEmpty ? info.service.rawValue : info.title
            }
        } else {
            // No meeting detected via detector
            if !engine.isInCall {
                let wasActive = self.isInCall || self.isMeetingDetected
                self.isMeetingDetected = false
                self.isInCall = false
                self.detectedAppName = nil
                self.detectedMeetingURL = nil
                self.detectedBrowserBundleID = nil
                self.isLobbyOrPreJoin = false
                if wasActive {
                    self.activeCallTitle = nil
                    self.callStartedAt = nil
                    self.activeCallDuration = 0
                    self.formattedCallDuration = "00:00"
                }
            }
        }
        updateActiveOrDetectedState()
    }
    
    public func appendNoteToScratchpad(_ scratchpad: ScratchpadModel) {
        let note = quickNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else { return }
        
        let headerTitle = activeCallTitle ?? upcomingMeeting?.title ?? "Meeting"
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)
        let snippet = "\n\n--- [\(headerTitle)] \(timestamp) ---\n\(note)\n"
        
        scratchpad.text += snippet
        quickNotes = ""
    }
    
    public func startInstantCall(service: MeetingService, scratchpad: ScratchpadModel? = nil) {
        let url: URL
        switch service {
        case .googleMeet:
            url = URL(string: "https://meet.google.com/new")!
        case .zoom:
            url = URL(string: "https://zoom.us/start/videomeeting")!
        default:
            url = URL(string: "https://meet.google.com/new")!
        }
        
        openMeetLink(
            event: CalendarEvent(
                id: "instant_\(UUID().uuidString)",
                title: "\(service.rawValue) Instant Call",
                startTime: Date(),
                endTime: Date().addingTimeInterval(3600),
                meetLink: url.absoluteString
            ),
            inApp: true,
            scratchpad: scratchpad
        )
    }
    
    // MARK: - Timers
    
    private func startPeriodicCallTimer() {
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tickCallTimer()
            }
    }
    
    private func startPeriodicAppScanning() {
        scanCancellable = Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkRunningMeetingApps()
            }
    }
}
