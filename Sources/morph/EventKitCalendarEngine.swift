import Foundation
import EventKit
import Combine
import SwiftUI

@MainActor
public final class EventKitCalendarEngine: ObservableObject {
    public static let shared = EventKitCalendarEngine()
    
    @Published public var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published public var isSyncing: Bool = false
    @Published public var events: [CalendarEvent] = []
    @Published public var availableCalendars: [String] = []
    @Published public var lastSyncDate: Date?
    
    private let eventStore = EKEventStore()
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        updateAuthStatus()
        observeSystemCalendarChanges()
    }
    
    public func updateAuthStatus() {
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    public var isAuthorized: Bool {
        if #available(macOS 14.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }
    
    public func requestAccess() async -> Bool {
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            var granted = false
            if #available(macOS 14.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                granted = try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { ok, err in
                        if let err = err {
                            continuation.resume(throwing: err)
                        } else {
                            continuation.resume(returning: ok)
                        }
                    }
                }
            }
            
            updateAuthStatus()
            if granted {
                _ = fetchEvents()
            }
            return granted
        } catch {
            updateAuthStatus()
            return false
        }
    }
    
    public func fetchEvents(for date: Date = Date(), matchingEmail: String? = nil) -> [CalendarEvent] {
        updateAuthStatus()
        guard isAuthorized else {
            return []
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date).addingTimeInterval(-86400 * 7) // past 7 days
        let endOfDay = cal.date(byAdding: .day, value: 30, to: startOfDay) ?? date.addingTimeInterval(86400 * 30) // next 30 days
        
        let allCalendars = eventStore.calendars(for: .event)
        self.availableCalendars = allCalendars.map { "\($0.title) (\($0.source.title))" }
        
        var targetCalendars = allCalendars
        if let email = matchingEmail?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            let matched = allCalendars.filter { c in
                c.title.lowercased().contains(email) || c.source.title.lowercased().contains(email)
            }
            if !matched.isEmpty {
                targetCalendars = matched
            }
        }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: targetCalendars)
        let ekEvents = eventStore.events(matching: predicate)
        
        var parsed: [CalendarEvent] = []
        for ek in ekEvents {
            let title = ek.title ?? "Untitled Event"
            let start = ek.startDate ?? date
            let end = ek.endDate ?? start.addingTimeInterval(1800)
            let isAllDay = ek.isAllDay
            let loc = ek.location
            let desc = ek.notes ?? ""
            
            // Extract Google Meet link from notes, URL, or location
            var meetLink: String? = nil
            if let urlStr = ek.url?.absoluteString, urlStr.contains("meet.google.com") {
                meetLink = urlStr
            } else if let detected = extractMeetLink(from: desc) ?? extractMeetLink(from: loc ?? "") {
                meetLink = detected
            }
            
            let attendees = ek.attendees?.compactMap { p -> String? in
                if let name = p.name, !name.isEmpty { return name }
                let urlStr = p.url.absoluteString
                if urlStr.hasPrefix("mailto:") {
                    return urlStr.replacingOccurrences(of: "mailto:", with: "")
                }
                if urlStr.contains("@") { return urlStr }
                return nil
            } ?? []
            
            let event = CalendarEvent(
                id: ek.eventIdentifier ?? UUID().uuidString,
                title: title,
                description: desc,
                startTime: start,
                endTime: end,
                isAllDay: isAllDay,
                meetLink: meetLink,
                location: loc ?? (meetLink != nil ? "Google Meet" : nil),
                attendees: attendees
            )
            parsed.append(event)
        }
        
        parsed.sort(by: { $0.startTime < $1.startTime })
        self.events = parsed
        self.lastSyncDate = Date()
        return parsed
    }
    
    private func extractMeetLink(from text: String) -> String? {
        guard !text.isEmpty else { return nil }
        let pattern = #"https://meet\.google\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(location: 0, length: text.utf16.count)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                if let r = Range(match.range, in: text) {
                    return String(text[r])
                }
            }
        }
        return nil
    }
    
    private func observeSystemCalendarChanges() {
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                _ = self?.fetchEvents()
            }
            .store(in: &cancellables)
    }
}
