import Foundation
import Combine
import SwiftUI

@MainActor
public final class CalendarModel: ObservableObject {
    @Published public var selectedDate: Date = Date()
    @Published public var displayedMonth: Date = Date()
    @Published public var events: [CalendarEvent] = []
    @Published public var isSyncing: Bool = false
    @Published public var activeAlertEvent: CalendarEvent?
    @Published public var showNotchAlert: Bool = false
    @Published public var configuredUserEmail: String?
    @Published public var isSignedIn: Bool = false
    
    public let engine: GoogleCalendarEngine
    private var cancellables = Set<AnyCancellable>()
    private var alertTimer: AnyCancellable?
    
    public init(engine: GoogleCalendarEngine = GoogleCalendarEngine.shared) {
        self.engine = engine
        loadInitialMockEvents()
        setupEngineObservers()
        startAlertWatcher()
    }
    
    private func setupEngineObservers() {
        engine.$isSyncing
            .assign(to: \.isSyncing, on: self)
            .store(in: &cancellables)
            
        engine.$isSignedIn
            .assign(to: \.isSignedIn, on: self)
            .store(in: &cancellables)
            
        engine.$configuredUserEmail
            .assign(to: \.configuredUserEmail, on: self)
            .store(in: &cancellables)
            
        engine.$rawEvents
            .sink { [weak self] newEvents in
                guard let self = self else { return }
                if self.configuredUserEmail != nil {
                    self.events = newEvents
                    self.evaluateUpcomingAlerts()
                } else if !newEvents.isEmpty {
                    self.events = newEvents
                    self.evaluateUpcomingAlerts()
                }
            }
            .store(in: &cancellables)
    }
    
    public func configureUser(email: String) {
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.contains("@") else { return }
        self.configuredUserEmail = clean
        self.isSignedIn = true
        // Clear mock events so real user Google Calendar data is exclusively displayed
        self.events = self.engine.rawEvents
        engine.configureAccount(email: clean)
    }
    
    public func clearUser() {
        self.configuredUserEmail = nil
        self.isSignedIn = false
        self.events = []
        self.activeAlertEvent = nil
        self.showNotchAlert = false
        engine.clearAccount()
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
    }
    
    public func openGoogleCalendar() {
        engine.openGoogleCalendarInBrowser()
    }
    
    public func addQuickEvent(title: String, durationMinutes: Int = 30) {
        let start = Date().addingTimeInterval(3600) // 1 hour from now
        let end = start.addingTimeInterval(Double(durationMinutes * 60))
        let newEvent = CalendarEvent(
            title: title,
            startTime: start,
            endTime: end,
            meetLink: "https://meet.google.com/new"
        )
        events.append(newEvent)
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
