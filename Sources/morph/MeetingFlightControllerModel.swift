import Cocoa
import SwiftUI
import Combine

public protocol MeetingAppDetector: Sendable {
    func detectRunningMeetingApp() -> (isRunning: Bool, appName: String?)
}

public struct DefaultMeetingAppDetector: MeetingAppDetector {
    public init() {}
    
    public func detectRunningMeetingApp() -> (isRunning: Bool, appName: String?) {
        let runningApps = NSWorkspace.shared.runningApplications
        
        let knownMeetingBundleIDs: [String: String] = [
            "us.zoom.xos": "Zoom",
            "com.microsoft.teams": "Microsoft Teams",
            "com.microsoft.teams2": "Microsoft Teams",
            "com.cisco.webexmeetingsapp": "Webex",
            "Cisco-Systems.Spark": "Webex",
            "com.tinyspeck.slackmacgap": "Slack"
        ]
        
        for app in runningApps {
            if let bundleID = app.bundleIdentifier, let appName = knownMeetingBundleIDs[bundleID] {
                return (true, appName)
            }
        }
        
        return (false, nil)
    }
}

@MainActor
public final class MeetingFlightControllerModel: ObservableObject {
    @Published public var upcomingMeeting: CalendarEvent?
    @Published public var isPreMeetingWindow: Bool = false
    @Published public var isInCall: Bool = false
    @Published public var activeCallTitle: String?
    @Published public var callStartedAt: Date?
    @Published public var activeCallDuration: TimeInterval = 0
    @Published public var formattedCallDuration: String = "00:00"
    @Published public var isMuted: Bool = false
    @Published public var quickNotes: String = ""
    @Published public var detectedAppName: String?
    
    public var detector: MeetingAppDetector
    public var urlOpener: ((URL) -> Bool)?
    
    private var timerCancellable: AnyCancellable?
    private var scanCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    private static var isTestingEnvironment: Bool {
        return ProcessInfo.processInfo.processName.contains("xctest") ||
            ProcessInfo.processInfo.arguments.contains(where: { $0.contains("xctest") }) ||
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
            NSClassFromString("XCTestCase") != nil
    }
    
    public init(
        detector: MeetingAppDetector = DefaultMeetingAppDetector(),
        urlOpener: ((URL) -> Bool)? = nil
    ) {
        self.detector = detector
        self.urlOpener = urlOpener
        
        if !Self.isTestingEnvironment {
            startPeriodicCallTimer()
            startPeriodicAppScanning()
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
        
        // Also fallback to any valid URL if string contains https://
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
    public func openMeetLink(event: CalendarEvent? = nil) -> Bool {
        let targetEvent = event ?? upcomingMeeting
        guard let targetEvent = targetEvent,
              let url = resolvedMeetingURL(for: targetEvent) else {
            return false
        }
        
        let opened: Bool
        if let customOpener = urlOpener {
            opened = customOpener(url)
        } else {
            opened = NSWorkspace.shared.open(url)
        }
        
        if opened {
            startCall(title: targetEvent.title)
        }
        return opened
    }
    
    public func startCall(title: String? = nil, startTime: Date = Date()) {
        self.isInCall = true
        self.activeCallTitle = title ?? upcomingMeeting?.title ?? "Active Meeting"
        self.callStartedAt = startTime
        self.activeCallDuration = 0
        self.formattedCallDuration = "00:00"
        self.isPreMeetingWindow = false
    }
    
    public func endCall() {
        self.isInCall = false
        self.callStartedAt = nil
        self.activeCallDuration = 0
        self.formattedCallDuration = "00:00"
        self.activeCallTitle = nil
        self.isMuted = false
    }
    
    public func toggleMute() {
        self.isMuted.toggle()
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
        let (running, name) = detector.detectRunningMeetingApp()
        self.detectedAppName = name
        if running && !isInCall {
            startCall(title: name ?? "Active Call")
        }
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
    
    // MARK: - Timers
    
    private func startPeriodicCallTimer() {
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tickCallTimer()
            }
    }
    
    private func startPeriodicAppScanning() {
        scanCancellable = Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkRunningMeetingApps()
            }
    }
}
