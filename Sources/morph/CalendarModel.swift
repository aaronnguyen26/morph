import Foundation
import Combine
import SwiftUI
import UserNotifications

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
    @Published public var isAddingEvent: Bool = false
    @Published public var notificationsEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "com.morph.calendar.notifications_enabled")
        }
    }
    @Published public var notificationLeadMinutes: Int = 10 {
        didSet {
            UserDefaults.standard.set(notificationLeadMinutes, forKey: "com.morph.calendar.lead_minutes")
        }
    }
    private var sentNotificationEventIDs = Set<String>()
    
    public let engine: GoogleCalendarEngine
    public let eventKitEngine: EventKitCalendarEngine
    public let icsEngine: GoogleICSEngine
    public let apiBridge: GoogleCalendarAPIBridge
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
        icsEngine: GoogleICSEngine? = nil,
        apiBridge: GoogleCalendarAPIBridge? = nil
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
        
        if let api = apiBridge {
            self.apiBridge = api
        } else if Self.isTestingEnvironment {
            self.apiBridge = GoogleCalendarAPIBridge()
        } else {
            self.apiBridge = GoogleCalendarAPIBridge.shared
        }
        
        self.events = []
        if UserDefaults.standard.object(forKey: "com.morph.calendar.notifications_enabled") != nil {
            self.notificationsEnabled = UserDefaults.standard.bool(forKey: "com.morph.calendar.notifications_enabled")
        }
        if UserDefaults.standard.object(forKey: "com.morph.calendar.lead_minutes") != nil {
            let savedLead = UserDefaults.standard.integer(forKey: "com.morph.calendar.lead_minutes")
            if savedLead > 0 {
                self.notificationLeadMinutes = savedLead
            }
        }
        
        setupEngineObservers()
        startAlertWatcher()
        
        if !Self.isTestingEnvironment {
            requestNotificationPermission()
            if configuredUserEmail == nil {
                self.configuredUserEmail = "minh7898888@gmail.com"
                self.isSignedIn = true
            }
            if self.eventKitEngine.isAuthorized {
                _ = self.eventKitEngine.fetchEvents(for: selectedDate, matchingEmail: configuredUserEmail)
                mergeAllEvents()
            }
            Task {
                await syncWithSystemCalendarAsync()
            }
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
            
        apiBridge.$events
            .sink { [weak self] newEvents in
                guard let self = self else { return }
                if self.configuredUserEmail != nil {
                    self.mergeAllEvents(overrideAPIEvents: newEvents)
                } else if !newEvents.isEmpty {
                    self.mergeAllEvents(overrideAPIEvents: newEvents)
                }
            }
            .store(in: &cancellables)
            
        apiBridge.$isAuthenticated
            .sink { [weak self] isAuth in
                guard let self = self else { return }
                if isAuth {
                    self.isSignedIn = true
                    if self.configuredUserEmail == nil, let primary = self.apiBridge.primaryEmail {
                        self.configuredUserEmail = primary
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    public func mergeAllEvents(
        overrideGoogleEvents: [CalendarEvent]? = nil,
        overrideEventKitEvents: [CalendarEvent]? = nil,
        overrideICSEvents: [CalendarEvent]? = nil,
        overrideAPIEvents: [CalendarEvent]? = nil
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
        let apiEvents = overrideAPIEvents ?? apiBridge.events
        
        // 1. Ingest Google Calendar REST API events (highest fidelity from Google Cloud OAuth)
        for evt in apiEvents {
            if !isAlreadyIncluded(evt) {
                seenIDs.insert(evt.id)
                combined.append(evt)
            }
        }
        
        // 2. Ingest Google Calendar Engine events
        for evt in googleEvents {
            if !isAlreadyIncluded(evt) {
                seenIDs.insert(evt.id)
                combined.append(evt)
            }
        }
        
        // 3. Ingest native macOS EventKit events (includes Google Calendar if connected in macOS)
        for evt in ekEvents {
            if !isAlreadyIncluded(evt) {
                seenIDs.insert(evt.id)
                combined.append(evt)
            }
        }
        
        // 4. Ingest Google private ICS Feed events
        for evt in ics {
            if !isAlreadyIncluded(evt) {
                seenIDs.insert(evt.id)
                combined.append(evt)
            }
        }
        
        // 5. Ingest optimistic local and currently tracked events in self.events
        for evt in self.events {
            if !isAlreadyIncluded(evt) {
                seenIDs.insert(evt.id)
                combined.append(evt)
            }
        }
        
        // Filter out leftover synthetic test events in production mode
        var finalEvents = combined
        if !Self.isTestingEnvironment {
            finalEvents = finalEvents.filter { evt in
                let t = evt.title.lowercased()
                return !t.contains("emergency retro") &&
                       !t.contains("emergency standup") &&
                       !t.contains("deep work sprint") &&
                       !t.contains("product architecture review")
            }
        }
        
        if configuredUserEmail != nil {
            // Real profile user signed in: strictly show merged real events
            self.events = finalEvents.sorted(by: { $0.startTime < $1.startTime })
        } else if !finalEvents.isEmpty {
            self.events = finalEvents.sorted(by: { $0.startTime < $1.startTime })
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
    
    public func requestNotificationPermission() {
        guard !Self.isTestingEnvironment else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            // System notification permission recorded
        }
    }
    
    public func toggleNotifications() {
        notificationsEnabled.toggle()
        if notificationsEnabled {
            requestNotificationPermission()
            evaluateUpcomingAlerts()
        }
    }
    
    public func cycleNotificationLeadMinutes() {
        switch notificationLeadMinutes {
        case 5: notificationLeadMinutes = 10
        case 10: notificationLeadMinutes = 15
        case 15: notificationLeadMinutes = 30
        default: notificationLeadMinutes = 5
        }
        evaluateUpcomingAlerts()
    }
    
    private var dismissedAlertEventIDs = Set<String>()
    private var alertAutoDismissTask: Task<Void, Never>?
    
    public func evaluateUpcomingAlerts() {
        if events.isEmpty {
            self.showNotchAlert = false
            self.activeAlertEvent = nil
            return
        }
        
        let now = Date()
        let leadSeconds = Double(notificationLeadMinutes * 60)
        let upcoming = events.filter { evt in
            let diff = evt.startTime.timeIntervalSince(now)
            return diff > 0 && diff <= leadSeconds && !dismissedAlertEventIDs.contains(evt.id)
        }
        
        if let next = upcoming.sorted(by: { $0.startTime < $1.startTime }).first {
            if self.activeAlertEvent?.id != next.id || !self.showNotchAlert {
                self.activeAlertEvent = next
                self.showNotchAlert = true
                
                // Cancel previous auto-dismiss task if any
                alertAutoDismissTask?.cancel()
                
                // Auto-dismiss the notch alert after 12 seconds so the collapsed island doesn't stay blocked
                alertAutoDismissTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 12_000_000_000)
                    guard let self = self, !Task.isCancelled else { return }
                    if self.activeAlertEvent?.id == next.id {
                        self.dismissNotchAlert(for: next.id)
                    }
                }
                
                // Dispatch native macOS notification if enabled and not already sent for this event instance
                if notificationsEnabled && !sentNotificationEventIDs.contains(next.id) {
                    dispatchSystemNotification(for: next)
                    sentNotificationEventIDs.insert(next.id)
                }
            }
        } else {
            self.showNotchAlert = false
            self.activeAlertEvent = nil
        }
    }
    
    private func dispatchSystemNotification(for event: CalendarEvent) {
        guard !Self.isTestingEnvironment else { return }
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Meeting in \(event.minutesUntilStart)m"
        content.subtitle = event.title
        var bodyText = event.formattedTimeRange
        if let loc = event.location, !loc.isEmpty {
            bodyText += " • \(loc)"
        }
        if event.meetLink != nil {
            bodyText += " • Google Meet attached"
        }
        content.body = bodyText
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "morph_cal_\(event.id)",
            content: content,
            trigger: nil // Deliver immediately
        )
        
        UNUserNotificationCenter.current().add(request) { _ in }
    }
    
    public func dismissNotchAlert(for eventId: String? = nil) {
        if let id = eventId ?? activeAlertEvent?.id {
            dismissedAlertEventIDs.insert(id)
        }
        alertAutoDismissTask?.cancel()
        alertAutoDismissTask = nil
        showNotchAlert = false
        activeAlertEvent = nil
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
        if !Self.isTestingEnvironment {
            Task {
                let apiEvents = await apiBridge.fetchAllGoogleCalendarEvents()
                await MainActor.run {
                    if !apiEvents.isEmpty {
                        self.isSignedIn = true
                    }
                    self.mergeAllEvents()
                }
            }
        }
    }
    
    public func signInWithGoogle() {
        // 1. Open Google sign-in in user's default browser (or active browser)
        engine.openGoogleSignInInBrowser()
        
        // 2. Automatically request and sync native macOS Calendar authorization & Google API bridge
        Task {
            await syncWithSystemCalendarAsync()
        }
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
        
        // Ingest Google Calendar API events if OAuth tokens are available
        if !Self.isTestingEnvironment {
            let apiEvents = await apiBridge.fetchAllGoogleCalendarEvents()
            if !apiEvents.isEmpty {
                self.isSignedIn = true
            }
            mergeAllEvents()
        }
        
        // If user is already authenticated in Chrome, detect Chrome accounts
        checkChromeGoogleAccountSync()
    }
    
    /// Checks if user is signed in to Google in Chrome and syncs the account
    public func checkChromeGoogleAccountSync() {
        guard !Self.isTestingEnvironment else { return }
        let path = ("~/Library/Application Support/Google/Chrome/Default/Preferences" as NSString).expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accounts = json["account_info"] as? [[String: Any]] else {
            return
        }
        
        let chromeEmails = accounts.compactMap { $0["email"] as? String }
        if let targetEmail = configuredUserEmail {
            if chromeEmails.contains(where: { $0.lowercased() == targetEmail.lowercased() }) {
                self.isSignedIn = true
            }
        } else if let firstEmail = chromeEmails.first {
            self.configuredUserEmail = firstEmail
            self.isSignedIn = true
        }
    }
    
    public func openGoogleCalendarInBrowser() {
        engine.openGoogleCalendarInBrowser()
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
    
    public func addQuickEvent(
        title: String,
        durationMinutes: Int = 30,
        startHour: Int? = nil,
        startMinute: Int = 0,
        addMeetLink: Bool = false,
        description: String? = nil,
        location: String? = nil,
        targetCalendarId: String? = nil
    ) {
        let cal = Calendar.current
        let now = Date()
        
        // Base start time on selectedDate with specified hour or current hour + 1
        var startComponents = cal.dateComponents([.year, .month, .day], from: selectedDate)
        if let hour = startHour {
            startComponents.hour = hour
            startComponents.minute = startMinute
        } else {
            let nowComponents = cal.dateComponents([.hour, .minute], from: now)
            startComponents.hour = (nowComponents.hour ?? 12) + 1
            startComponents.minute = 0
        }
        startComponents.second = 0
        
        let start = cal.date(from: startComponents) ?? now.addingTimeInterval(3600)
        let end = start.addingTimeInterval(Double(durationMinutes * 60))
        
        let initialMeet = addMeetLink ? "https://meet.google.com/new" : nil
        let eventDesc = description ?? "Created via Morph Dynamic Notch"
        let eventLoc = location ?? (addMeetLink ? "Google Meet" : nil)
        
        // Optimistically create local CalendarEvent
        let localEvent = CalendarEvent(
            id: "local_\(UUID().uuidString)",
            title: title,
            description: eventDesc,
            startTime: start,
            endTime: end,
            meetLink: initialMeet,
            location: eventLoc
        )
        if !events.contains(where: { $0.id == localEvent.id }) {
            events.append(localEvent)
            events.sort(by: { $0.startTime < $1.startTime })
        }
        evaluateUpcomingAlerts()
        
        // 1. Direct Google Calendar REST API event creation (updates user's real Google Calendar)
        if !Self.isTestingEnvironment {
            Task {
                if let apiCreated = await apiBridge.createGoogleCalendarEvent(
                    title: title,
                    startTime: start,
                    endTime: end,
                    description: eventDesc,
                    location: eventLoc,
                    addMeetLink: addMeetLink,
                    calendarId: targetCalendarId
                ) {
                    await MainActor.run {
                        // Replace optimistic local event with real Google Calendar event ID
                        self.events.removeAll(where: { $0.id == localEvent.id })
                        if !self.events.contains(where: { $0.id == apiCreated.id }) {
                            self.events.append(apiCreated)
                            self.events.sort(by: { $0.startTime < $1.startTime })
                        }
                        self.evaluateUpcomingAlerts()
                    }
                }
            }
        }
        
        // 2. Also save to EventKit if authorized
        if eventKitEngine.isAuthorized,
           let created = eventKitEngine.createEvent(
            title: title,
            startDate: start,
            endDate: end,
            description: eventDesc,
            location: eventLoc,
            url: addMeetLink ? URL(string: "https://meet.google.com/new") : nil,
            matchingEmail: configuredUserEmail
           ) {
            self.events.removeAll(where: { $0.id == localEvent.id })
            if !self.events.contains(where: { $0.id == created.id }) {
                self.events.append(created)
                self.events.sort(by: { $0.startTime < $1.startTime })
            }
            self.evaluateUpcomingAlerts()
        }
    }
    
    public func deleteEvent(id: String) {
        // 1. Optimistically remove from local array
        self.events.removeAll(where: { $0.id == id })
        if activeAlertEvent?.id == id {
            dismissNotchAlert(for: id)
        }
        evaluateUpcomingAlerts()
        
        // 2. Dispatch deletion to Google Calendar API Bridge if event originated from Google or has gcal_ prefix
        if !Self.isTestingEnvironment {
            Task {
                await apiBridge.deleteGoogleCalendarEvent(id: id)
            }
        }
        
        // 3. Dispatch deletion to EventKit if authorized
        if eventKitEngine.isAuthorized {
            eventKitEngine.deleteEvent(id: id, matchingEmail: configuredUserEmail)
        }
    }
    
    public func deleteEvent(_ event: CalendarEvent) {
        deleteEvent(id: event.id)
    }
}

