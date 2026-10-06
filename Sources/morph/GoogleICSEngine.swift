import Foundation
import Combine

@MainActor
public final class GoogleICSEngine: ObservableObject {
    public static let shared = GoogleICSEngine()
    
    @Published public var isSyncing: Bool = false
    @Published public var events: [CalendarEvent] = []
    @Published public var feedURL: String?
    @Published public var lastSyncDate: Date?
    
    private let kSavedFeedKey = "com.morph.calendar_ics_feed_url"
    
    public init() {
        if let saved = UserDefaults.standard.string(forKey: kSavedFeedKey), !saved.isEmpty {
            self.feedURL = saved
            Task {
                await self.sync(feedURL: saved)
            }
        }
    }
    
    public func saveAndSync(url: String) async -> Bool {
        let clean = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.hasPrefix("http://") || clean.hasPrefix("https://") else { return false }
        self.feedURL = clean
        UserDefaults.standard.set(clean, forKey: kSavedFeedKey)
        return await sync(feedURL: clean)
    }
    
    public func clearFeed() {
        self.feedURL = nil
        self.events = []
        UserDefaults.standard.removeObject(forKey: kSavedFeedKey)
    }
    
    public func sync(feedURL: String) async -> Bool {
        guard let url = URL(string: feedURL) else { return false }
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return false
            }
            guard let icsString = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
                return false
            }
            
            let parsed = parseICS(icsString)
            self.events = parsed
            self.lastSyncDate = Date()
            return true
        } catch {
            return false
        }
    }
    
    public func parseICS(_ ics: String) -> [CalendarEvent] {
        var result: [CalendarEvent] = []
        let lines = ics.components(separatedBy: .newlines)
        
        var inEvent = false
        var currentSummary = ""
        var currentDesc = ""
        var currentStart: Date?
        var currentEnd: Date?
        var currentUID = ""
        var currentLoc = ""
        
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line == "BEGIN:VEVENT" {
                inEvent = true
                currentSummary = ""
                currentDesc = ""
                currentStart = nil
                currentEnd = nil
                currentUID = ""
                currentLoc = ""
            } else if line == "END:VEVENT" {
                inEvent = false
                if let start = currentStart {
                    let end = currentEnd ?? start.addingTimeInterval(1800)
                    var meetLink: String? = nil
                    if currentDesc.contains("meet.google.com") {
                        meetLink = extractMeetLink(from: currentDesc)
                    } else if currentLoc.contains("meet.google.com") {
                        meetLink = extractMeetLink(from: currentLoc)
                    }
                    
                    let event = CalendarEvent(
                        id: currentUID.isEmpty ? UUID().uuidString : currentUID,
                        title: currentSummary.isEmpty ? "Google Calendar Event" : currentSummary,
                        description: currentDesc,
                        startTime: start,
                        endTime: end,
                        isAllDay: false,
                        meetLink: meetLink,
                        location: currentLoc.isEmpty ? (meetLink != nil ? "Google Meet" : nil) : currentLoc,
                        attendees: []
                    )
                    result.append(event)
                }
            } else if inEvent {
                if line.hasPrefix("SUMMARY:") {
                    currentSummary = String(line.dropFirst(8)).replacingOccurrences(of: "\\,", with: ",").replacingOccurrences(of: "\\n", with: "\n")
                } else if line.hasPrefix("DESCRIPTION:") {
                    currentDesc = String(line.dropFirst(12)).replacingOccurrences(of: "\\,", with: ",").replacingOccurrences(of: "\\n", with: "\n")
                } else if line.hasPrefix("LOCATION:") {
                    currentLoc = String(line.dropFirst(9)).replacingOccurrences(of: "\\,", with: ",").replacingOccurrences(of: "\\n", with: "\n")
                } else if line.hasPrefix("UID:") {
                    currentUID = String(line.dropFirst(4))
                } else if line.hasPrefix("DTSTART") {
                    let val = line.components(separatedBy: ":").last ?? ""
                    currentStart = parseICSDate(val, formatter: df)
                } else if line.hasPrefix("DTEND") {
                    let val = line.components(separatedBy: ":").last ?? ""
                    currentEnd = parseICSDate(val, formatter: df)
                }
            }
        }
        
        result.sort(by: { $0.startTime < $1.startTime })
        return result
    }
    
    private func parseICSDate(_ dateStr: String, formatter: DateFormatter) -> Date? {
        let clean = dateStr.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.count == 16 && clean.hasSuffix("Z") {
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            return formatter.date(from: clean)
        } else if clean.count == 15 {
            formatter.dateFormat = "yyyyMMdd'T'HHmmss"
            return formatter.date(from: clean)
        } else if clean.count == 8 {
            formatter.dateFormat = "yyyyMMdd"
            return formatter.date(from: clean)
        }
        return nil
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
}
