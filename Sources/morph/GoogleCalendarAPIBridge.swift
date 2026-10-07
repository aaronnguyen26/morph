import Foundation
import Combine

public struct GoogleCalendarInfo: Identifiable, Hashable, Equatable {
    public let id: String
    public let summary: String
    public let isPrimary: Bool
    public let accessRole: String
    
    public init(id: String, summary: String, isPrimary: Bool, accessRole: String) {
        self.id = id
        self.summary = summary
        self.isPrimary = isPrimary
        self.accessRole = accessRole
    }
}

@MainActor
public final class GoogleCalendarAPIBridge: ObservableObject {
    public static let shared = GoogleCalendarAPIBridge()
    
    @Published public var isSyncing: Bool = false
    @Published public var isAuthenticated: Bool = false
    @Published public var events: [CalendarEvent] = []
    @Published public var primaryEmail: String?
    @Published public var lastSyncDate: Date?
    @Published public var availableCalendars: [GoogleCalendarInfo] = []
    
    // Map event ID -> Google Calendar ID (e.g. primary or secondary group calendar)
    private var eventCalendarMap: [String: String] = [:]
    
    private let clientInfoPath = ("~/.config/google-mcp/oauth_client.json" as NSString).expandingTildeInPath
    private let tokensPath = ("~/.mcp-auth/mcp-remote-v1/f257e7d5e7cfcb809c421abe8c7962ae_tokens.json" as NSString).expandingTildeInPath
    
    private var accessToken: String?
    private var tokenExpiry: Date?
    
    private static var isTestingEnvironment: Bool {
        return ProcessInfo.processInfo.processName.contains("xctest") ||
            ProcessInfo.processInfo.arguments.contains(where: { $0.contains("xctest") }) ||
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
            NSClassFromString("XCTestCase") != nil
    }
    
    public init() {
        if !Self.isTestingEnvironment {
            checkTokenAvailability()
        }
    }
    
    public func checkTokenAvailability() {
        if FileManager.default.fileExists(atPath: tokensPath) {
            self.isAuthenticated = true
        }
    }
    
    public func ensureValidAccessToken() async -> String? {
        if let token = accessToken, let expiry = tokenExpiry, expiry > Date().addingTimeInterval(60) {
            return token
        }
        
        guard let clientData = try? Data(contentsOf: URL(fileURLWithPath: clientInfoPath)),
              let clientJson = try? JSONSerialization.jsonObject(with: clientData) as? [String: Any],
              let clientId = clientJson["client_id"] as? String,
              let clientSecret = clientJson["client_secret"] as? String else {
            return nil
        }
        
        guard let tokensData = try? Data(contentsOf: URL(fileURLWithPath: tokensPath)),
              let tokensJson = try? JSONSerialization.jsonObject(with: tokensData) as? [String: Any],
              let refreshToken = tokensJson["refresh_token"] as? String else {
            return nil
        }
        
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "client_id=\(clientId)&client_secret=\(clientSecret)&refresh_token=\(refreshToken)&grant_type=refresh_token"
        request.httpBody = body.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newAccessToken = json["access_token"] as? String else {
                return nil
            }
            
            let expiresIn = (json["expires_in"] as? Double) ?? 3600.0
            self.accessToken = newAccessToken
            self.tokenExpiry = Date().addingTimeInterval(expiresIn)
            self.isAuthenticated = true
            
            // Persist updated token to tokens.json to keep auth in sync
            var updatedTokens = tokensJson
            updatedTokens["access_token"] = newAccessToken
            updatedTokens["expires_in"] = Int(expiresIn)
            updatedTokens["expires_at"] = Int(Date().timeIntervalSince1970 * 1000.0) + Int(expiresIn * 1000.0)
            if let updatedData = try? JSONSerialization.data(withJSONObject: updatedTokens, options: [.prettyPrinted]) {
                try? updatedData.write(to: URL(fileURLWithPath: tokensPath))
            }
            
            return newAccessToken
        } catch {
            return nil
        }
    }
    
    public func fetchAllGoogleCalendarEvents() async -> [CalendarEvent] {
        guard let token = await ensureValidAccessToken() else {
            return []
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        // 1. Fetch calendar list
        var calListReq = URLRequest(url: URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!)
        calListReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        guard let (calListData, calListResp) = try? await URLSession.shared.data(for: calListReq),
              let http = calListResp as? HTTPURLResponse, http.statusCode == 200,
              let calListJson = try? JSONSerialization.jsonObject(with: calListData) as? [String: Any],
              let items = calListJson["items"] as? [[String: Any]] else {
            return []
        }
        
        // Ingest available calendars list
        var loadedCalendars: [GoogleCalendarInfo] = []
        for c in items {
            guard let id = c["id"] as? String else { continue }
            let summary = (c["summary"] as? String) ?? id
            let isPrimary = (c["primary"] as? Bool) ?? false
            let accessRole = (c["accessRole"] as? String) ?? "reader"
            loadedCalendars.append(GoogleCalendarInfo(id: id, summary: summary, isPrimary: isPrimary, accessRole: accessRole))
        }
        self.availableCalendars = loadedCalendars

        // Detect primary calendar email
        if let primaryCal = items.first(where: { ($0["primary"] as? Bool) == true }),
           let id = primaryCal["id"] as? String {
            self.primaryEmail = id
        }
        
        // 2. Fetch events across all calendars for [-7 days ... +35 days]
        let now = Date()
        let startQueryDate = now.addingTimeInterval(-86400 * 7)
        let endQueryDate = now.addingTimeInterval(86400 * 35)
        
        let isoFormatter = ISO8601DateFormatter()
        let timeMinStr = isoFormatter.string(from: startQueryDate)
        let timeMaxStr = isoFormatter.string(from: endQueryDate)
        
        var combinedEvents: [CalendarEvent] = []
        var seenIDs = Set<String>()
        
        for cal in items {
            guard let calId = cal["id"] as? String else { continue }
            let calSummary = (cal["summary"] as? String) ?? "Google Calendar"
            
            guard let encodedId = calId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
                  let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/\(encodedId)/events?timeMin=\(timeMinStr)&timeMax=\(timeMaxStr)&singleEvents=true&orderBy=startTime&maxResults=50") else {
                continue
            }
            
            var eventReq = URLRequest(url: url)
            eventReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            guard let (evtData, evtResp) = try? await URLSession.shared.data(for: eventReq),
                  let evtHttp = evtResp as? HTTPURLResponse, evtHttp.statusCode == 200,
                  let evtJson = try? JSONSerialization.jsonObject(with: evtData) as? [String: Any],
                  let eventItems = evtJson["items"] as? [[String: Any]] else {
                continue
            }
            
            for item in eventItems {
                guard let id = item["id"] as? String, !seenIDs.contains(id) else { continue }
                seenIDs.insert(id)
                
                let title = (item["summary"] as? String) ?? "Untitled Event"
                let desc = (item["description"] as? String) ?? ""
                let loc = item["location"] as? String
                let meet = (item["hangoutLink"] as? String) ?? extractMeetLink(from: desc) ?? extractMeetLink(from: loc ?? "")
                
                var start = now
                var end = now.addingTimeInterval(1800)
                var isAllDay = false
                
                if let startDict = item["start"] as? [String: Any] {
                    if let dtStr = startDict["dateTime"] as? String, let parsed = isoFormatter.date(from: dtStr) {
                        start = parsed
                    } else if let dStr = startDict["date"] as? String {
                        let df = DateFormatter()
                        df.dateFormat = "yyyy-MM-dd"
                        df.timeZone = TimeZone.current
                        if let parsed = df.date(from: dStr) {
                            start = parsed
                            isAllDay = true
                        }
                    }
                }
                
                if let endDict = item["end"] as? [String: Any] {
                    if let dtStr = endDict["dateTime"] as? String, let parsed = isoFormatter.date(from: dtStr) {
                        end = parsed
                    } else if let dStr = endDict["date"] as? String {
                        let df = DateFormatter()
                        df.dateFormat = "yyyy-MM-dd"
                        df.timeZone = TimeZone.current
                        if let parsed = df.date(from: dStr) {
                            end = parsed
                        }
                    }
                }
                
                let event = CalendarEvent(
                    id: "gcal_\(id)",
                    title: title,
                    description: desc.isEmpty ? calSummary : "\(calSummary) • \(desc)",
                    startTime: start,
                    endTime: end,
                    isAllDay: isAllDay,
                    meetLink: meet,
                    location: loc ?? (meet != nil ? "Google Meet" : nil),
                    attendees: []
                )
                self.eventCalendarMap[id] = calId
                self.eventCalendarMap[event.id] = calId
                combinedEvents.append(event)
            }
        }
        
        combinedEvents.sort(by: { $0.startTime < $1.startTime })
        self.events = combinedEvents
        self.lastSyncDate = Date()
        return combinedEvents
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
    
    public func createGoogleCalendarEvent(
        title: String,
        startTime: Date,
        endTime: Date,
        description: String? = nil,
        location: String? = nil,
        addMeetLink: Bool = false,
        calendarId: String? = nil
    ) async -> CalendarEvent? {
        guard let token = await ensureValidAccessToken() else {
            return nil
        }
        
        let targetCalId = calendarId ?? primaryEmail ?? "primary"
        guard let encodedCalId = targetCalId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        
        let urlString = addMeetLink 
            ? "https://www.googleapis.com/calendar/v3/calendars/\(encodedCalId)/events?conferenceDataVersion=1"
            : "https://www.googleapis.com/calendar/v3/calendars/\(encodedCalId)/events"
        guard let url = URL(string: urlString) else {
            return nil
        }
        
        let isoFormatter = ISO8601DateFormatter()
        let startStr = isoFormatter.string(from: startTime)
        let endStr = isoFormatter.string(from: endTime)
        let timeZoneId = TimeZone.current.identifier
        
        var bodyDict: [String: Any] = [
            "summary": title,
            "start": [
                "dateTime": startStr,
                "timeZone": timeZoneId
            ],
            "end": [
                "dateTime": endStr,
                "timeZone": timeZoneId
            ]
        ]
        
        if let desc = description, !desc.isEmpty {
            bodyDict["description"] = desc
        }
        if let loc = location, !loc.isEmpty {
            bodyDict["location"] = loc
        }
        if addMeetLink {
            bodyDict["conferenceData"] = [
                "createRequest": [
                    "requestId": "morph-\(UUID().uuidString)",
                    "conferenceSolutionKey": [
                        "type": "hangoutsMeet"
                    ]
                ]
            ]
        }
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: bodyDict, options: []) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let eventId = json["id"] as? String else {
                return nil
            }
            
            let meet = (json["hangoutLink"] as? String) ?? extractMeetLink(from: description ?? "")
            let newEvent = CalendarEvent(
                id: "gcal_\(eventId)",
                title: title,
                description: description ?? "Google Calendar Event",
                startTime: startTime,
                endTime: endTime,
                isAllDay: false,
                meetLink: meet,
                location: location,
                attendees: []
            )
            
            // Ingest into local event cache
            self.eventCalendarMap[eventId] = targetCalId
            self.eventCalendarMap[newEvent.id] = targetCalId
            if !self.events.contains(where: { $0.id == newEvent.id }) {
                self.events.append(newEvent)
                self.events.sort(by: { $0.startTime < $1.startTime })
            }
            
            return newEvent
        } catch {
            return nil
        }
    }
    
    @discardableResult
    public func deleteGoogleCalendarEvent(id: String) async -> Bool {
        guard let token = await ensureValidAccessToken() else {
            return false
        }
        
        // Strip any "gcal_" prefix if present to obtain the raw Google Calendar event ID
        let rawEventId = id.hasPrefix("gcal_") ? String(id.dropFirst(5)) : id
        let calId = eventCalendarMap[id] ?? eventCalendarMap[rawEventId] ?? primaryEmail ?? "primary"
        
        guard let encodedCalId = calId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let encodedEventId = rawEventId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/\(encodedCalId)/events/\(encodedEventId)") else {
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) || http.statusCode == 404 || http.statusCode == 410 {
                // Remove from in-memory cache
                self.events.removeAll(where: { $0.id == id || $0.id == "gcal_\(rawEventId)" || $0.id == rawEventId })
                self.eventCalendarMap.removeValue(forKey: id)
                self.eventCalendarMap.removeValue(forKey: rawEventId)
                return true
            }
            return false
        } catch {
            return false
        }
    }
}
