import Foundation
import Combine
import SwiftUI

@MainActor
public final class CalendarModel: ObservableObject {
    @Published public var selectedDate: Date = Date() {
        didSet {
            if eventKitEngine.isAuthorized {
                _ = eventKitEngine.fetchEvents(for: selectedDate, matchingEmail: configuredUserEmail)
                mergeAllEvents()
            }
        }
    }
    @Published public var displayedMonth: Date = Date()
    @Published public var events: [CalendarEvent] = []
    @Published public var isSyncing: Bool = false
    @Published public var activeAlertEvent: CalendarEvent?
    @Published public var showNotchAlert: Bool = false
    @Published public var configuredUserEmail: String?
    @Published public var isSignedIn: Bool = false
    
    public let engine: GoogleCalendarEngine
    public let eventKitEngine: EventKitCalendarEngine
    public let icsEngine: GoogleICSEngine
    private var cancellables = Set<AnyCancellable>()
    private var alertTimer: AnyCancellable?
    
    private static var isTestingEnvironment: Bool {
        return ProcessInfo.processInfo.processName.contains("xctest") ||
            ProcessInfo.processInfo.arguments.contains(where: { $0.contains("xctest") }) ||
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
            NSClassFromString("XCTestCase") != nil
    }
    
    public init(
        engine: GoogleCalendarEngine? = nil,
        eventKitEngine: EventKitCalendarEngine? = nil,
        icsEngine: GoogleICSEngine? = nil
    ) {
        if let engine = engine {
            self.engine = engine
        } else if Self.isTestingEnvironment {
            self.engine = GoogleCalendarEngine()
        } else {
            self.engine = GoogleCalendarEngine.shared
        }
        
        if let ek = eventKitEngine {
            self.eventKitEngine = ek
        } else if Self.isTestingEnvironment {
            self.eventKitEngine = EventKitCalendarEngine()
        } else {
            self.eventKitEngine = EventKitCalendarEngine.shared
        }
        
        if let ics = icsEngine {
            self.icsEngine = ics
        } else if Self.isTestingEnvironment {
            self.icsEngine = GoogleICSEngine()
        } else {
            self.icsEngine = GoogleICSEngine.shared
        }
        
        loadInitialMockEvents()
        setupEngineObservers()
        startAlertWatcher()
        
        if self.eventKitEngine.isAuthorized && !Self.isTestingEnvironment {
            _ = self.eventKitEngine.fetchEvents(for: selectedDate, matchingEmail: configuredUserEmail)
            mergeAllEvents()
        }
    }
    
    private func setupEngineObservers() {
        engine.$isSyncing
            .assign(to: \.isSyncing, on: self)
            .store(in: &cancellables)
            
        engine.$isSignedIn
            .sink { [weak self] signedIn in
                guard let self = self else { return }
                if signedIn || self.configuredUserEmail != nil {
                    self.isSignedIn = true
                }
            }
            .store(in: &cancellables)
            
        engine.$configuredUserEmail
            .assign(to: \.configuredUserEmail, on: self)
            .store(in: &cancellables)
            
        engine.$rawEvents
            .sink { [weak self] newEvents in
                guard let self = self else { return }
                if self.configuredUserEmail != nil {
                    self.mergeAllEvents(overrideGoogleEvents: newEvents)
                } else if !newEvents.isEmpty {
                    self.mergeAllEvents(overrideGoogleEvents: newEvents)
                } else {
                    self.events = []
                    self.evaluateUpcomingAlerts()
                }
            }
            .store(in: &cancellables)
            
        eventKitEngine.$events
            .sink { [weak self] newEvents in
                guard let self = self else { return }
                if self.configuredUserEmail != nil {
                    self.mergeAllEvents(overrideEventKitEvents: newEvents)
                } else if !newEvents.isEmpty {
                    self.mergeAllEvents(overrideEventKitEvents: newEvents)
                }
            }
            .store(in: &cancellables)
            
        icsEngine.$events
            .sink { [weak self] newEvents in
                guard let self = self else { return }
                if self.configuredUserEmail != nil {
                    self.mergeAllEvents(overrideICSEvents: newEvents)
                } else if !newEvents.isEmpty {
                    self.mergeAllEvents(overrideICSEvents: newEvents)
                }
            }
            .store(in: &cancellables)
    }
    
    public func mergeAllEvents(
        overrideGoogleEvents: [CalendarEvent]? = nil,
        overrideEventKitEvents: [CalendarEvent]? = nil,
        overrideICSEvents: [CalendarEvent]? = nil
    ) {
        var combined: [CalendarEvent] = []
        var seenIDs = Set<String>()
        
        func isAlreadyIncluded(_ evt: CalendarEvent) -> Bool {
            if seenIDs.contains(evt.id) { return true }
            return combined.contains { existing in
                existing.title.lowercased() == evt.title.lowercased() &&
                abs(existing.startTime.timeIntervalSince(evt.startTime)) < 90
            }
        }
        
        let googleEvents = overrideGoogleEvents ?? engine.rawEvents
        let ekEvents = overrideEventKitEvents ?? eventKitEngine.events
        let ics = overrideICSEvents ?? icsEngine.events
        
        // 1. Ingest Google Calendar Engine events
        for evt in googleEvents {
            if !isAlreadyIncluded(evt) {
                seenIDs.insert(evt.id)
                combined.append(evt)
            }
        }
        
        // 2. Ingest native macOS EventKit events (includes Google Calendar if connected in macOS)
        for evt in ekEvents {
            if !isAlreadyIncluded(evt) {
                seenIDs.insert(evt.id)
                combined.append(evt)
            }
        }
        
        // 3. Ingest Google private ICS Feed events
        for evt in ics {
            if !isAlreadyIncluded(evt) {
                seenIDs.insert(evt.id)
                combined.append(evt)
            }
        }
        
        if configuredUserEmail != nil {
            // Real profile user signed in: strictly show merged real events
            self.events = combined.sorted(by: { $0.startTime < $1.startTime })
        } else if !combined.isEmpty {
            self.events = combined.sorted(by: { $0.startTime < $1.startTime })
        } else {
            self.events = []
        }
        
        evaluateUpcomingAlerts()
    }
    
    public func configureUser(email: String) {
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.contains("@") else { return }
        self.configuredUserEmail = clean
        self.isSignedIn = true
        engine.configureAccount(email: clean)
        mergeAllEvents()
        
        // Seamlessly sync with native macOS Calendar (which connects to the user's Google Calendar)
        if !Self.isTestingEnvironment {
            Task {
                await syncWithSystemCalendarAsync()
            }
        }
    }
    
    public func clearUser() {
        self.configuredUserEmail = nil
        self.isSignedIn = false
        self.events = []
        self.activeAlertEvent = nil
        self.showNotchAlert = false
        engine.clearAccount()
        eventKitEngine.events = []
        icsEngine.events = []
    }

    
    private func startAlertWatcher() {
        // Watch for events starting within the next 15 minutes and trigger notch notification
        alertTimer = Timer.publish(every: 10, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.evaluateUpcomingAlerts()
            }
    }
    
    public func evaluateUpcomingAlerts() {
        if events.isEmpty {
            self.showNotchAlert = false
            self.activeAlertEvent = nil
            return
        }
        
        let now = Date()
        let upcoming = events.filter { evt in
            let diff = evt.startTime.timeIntervalSince(now)
            return diff > 0 && diff <= 900 // Within 15 minutes
        }
        
        if let next = upcoming.sorted(by: { $0.startTime < $1.startTime }).first {
            if self.activeAlertEvent?.id != next.id || !self.showNotchAlert {
                self.activeAlertEvent = next
                self.showNotchAlert = true
            }
        } else {
            self.showNotchAlert = false
            self.activeAlertEvent = nil
        }
    }
    
    public func dismissNotchAlert() {
        showNotchAlert = false
    }
    
    public var nextUpcomingEvent: CalendarEvent? {
        let now = Date()
        return events
            .filter { $0.endTime > now }
            .sorted(by: { $0.startTime < $1.startTime })
            .first
    }
    
    public var eventsForSelectedDate: [CalendarEvent] {
        let cal = Calendar.current
        return events.filter { cal.isDate($0.startTime, inSameDayAs: selectedDate) }
            .sorted(by: { $0.startTime < $1.startTime })
    }
    
    public func eventsForDate(_ date: Date) -> [CalendarEvent] {
        let cal = Calendar.current
        return events.filter { cal.isDate($0.startTime, inSameDayAs: date) }
    }
    
    public func previousMonth() {
        if let prev = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = prev
        }
    }
    
    public func nextMonth() {
        if let next = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = next
        }
    }
    
    public func goToToday() {
        displayedMonth = Date()
        selectedDate = Date()
    }
    
    public func syncWithGoogle() {
        engine.refresh()
        if eventKitEngine.isAuthorized {
            _ = eventKitEngine.fetchEvents(for: selectedDate, matchingEmail: configuredUserEmail)
            mergeAllEvents()
        }
        if let feed = icsEngine.feedURL {
            Task {
                _ = await icsEngine.sync(feedURL: feed)
                await MainActor.run {
                    self.mergeAllEvents()
                }
            }
        }
    }
    
    public func signInWithGoogle() {
        // 1. Open the user's default system browser (Safari / Chrome) for reliable login without embedded WebKit block
        engine.openGoogleCalendarInBrowser()
        // 2. Also prompt native macOS Calendar authorization to sync seamlessly
        Task {
            await syncWithSystemCalendarAsync()
        }
        // 3. Bring up calendar window for viewing
        engine.showCalendarWindow()
    }
    
    public func syncWithSystemCalendar() {
        Task {
            await syncWithSystemCalendarAsync()
        }
    }
    
    public func syncWithSystemCalendarAsync() async {
        let granted = await eventKitEngine.requestAccess()
        if granted {
            _ = eventKitEngine.fetchEvents(for: selectedDate, matchingEmail: configuredUserEmail)
            self.isSignedIn = true
            mergeAllEvents()
        }
    }
    
    public func openGoogleCalendar() {
        engine.openGoogleCalendarInBrowser()
    }
    
    public func openMacCalendarApp() {
        eventKitEngine.openMacCalendarApp()
    }
    
    public func openInternetAccountsSettings() {
        eventKitEngine.openInternetAccountsSettings()
    }
    
    public func addQuickEvent(title: String, durationMinutes: Int = 30) {
        let start = Date().addingTimeInterval(3600) // 1 hour from now
        let end = start.addingTimeInterval(Double(durationMinutes * 60))
        
        if eventKitEngine.isAuthorized,
           let created = eventKitEngine.createEvent(
            title: title,
            startDate: start,
            endDate: end,
            description: "Created via Morph Dynamic Notch",
            location: "Morph Workspace",
            url: URL(string: "https://meet.google.com/new"),
            matchingEmail: configuredUserEmail
           ) {
            if !events.contains(where: { $0.id == created.id }) {
                events.append(created)
            }
        } else {
            let newEvent = CalendarEvent(
                title: title,
                startTime: start,
                endTime: end,
                meetLink: "https://meet.google.com/new"
            )
            events.append(newEvent)
        }
        evaluateUpcomingAlerts()
    }
    
    private func loadInitialMockEvents() {
        let now = Date()
        let cal = Calendar.current
        
        let start1 = now.addingTimeInterval(12 * 60) // In 12 minutes!
        let end1 = start1.addingTimeInterval(45 * 60)
        
        let start2 = cal.date(bySettingHour: 14, minute: 0, second: 0, of: now) ?? now.addingTimeInterval(3600 * 2)
        let end2 = start2.addingTimeInterval(60 * 60)
        
        let start3 = cal.date(bySettingHour: 16, minute: 30, second: 0, of: now) ?? now.addingTimeInterval(3600 * 4)
        let end3 = start3.addingTimeInterval(30 * 60)
        
        self.events = [
            CalendarEvent(
                id: "evt_1",
                title: "Design System Architecture Review",
                description: "Review Morph Notch OLED tokens and Stitch components",
                startTime: start1,
                endTime: end1,
                meetLink: "https://meet.google.com/abc-defg-hij",
                location: "Google Meet",
                attendees: ["alex@google.com", "sarah@morph.design"]
            ),
            CalendarEvent(
                id: "evt_2",
                title: "Q4 Product Roadmap Sync",
                description: "Quarterly milestone alignment and feature priorities",
                startTime: start2,
                endTime: end2,
                meetLink: "https://meet.google.com/xyz-uvwx-rst",
                location: "Zoom Room 3",
                attendees: ["team@morph.design"]
            ),
            CalendarEvent(
                id: "evt_3",
                title: "Haptics & Dynamic Island Workshop",
                description: "Fine-tuning hardware notch spring dynamics and audio cues",
                startTime: start3,
                endTime: end3,
                meetLink: nil,
                location: "Spatial Lab",
                attendees: ["engineering@morph.design"]
            )
        ]
    }
}
