import Foundation

public struct CalendarEvent: Identifiable, Codable, Equatable {
    public let id: String
    public var title: String
    public var description: String
    public var startTime: Date
    public var endTime: Date
    public var isAllDay: Bool
    public var meetLink: String?
    public var location: String?
    public var attendees: [String]
    public var colorHex: String?
    public var calendarName: String?
    public var hasAlerted: Bool
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        description: String = "",
        startTime: Date,
        endTime: Date,
        isAllDay: Bool = false,
        meetLink: String? = nil,
        location: String? = nil,
        attendees: [String] = [],
        colorHex: String? = nil,
        calendarName: String? = nil,
        hasAlerted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.startTime = startTime
        self.endTime = endTime
        self.isAllDay = isAllDay
        self.meetLink = meetLink
        self.location = location
        self.attendees = attendees
        self.colorHex = colorHex
        self.calendarName = calendarName
        self.hasAlerted = hasAlerted
    }
    
    public var formattedTimeRange: String {
        if isAllDay {
            return "All Day"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
    
    public var formattedStartTime: String {
        if isAllDay {
            return "All Day"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startTime)
    }
    
    public var isStartingSoon: Bool {
        let diff = startTime.timeIntervalSinceNow
        return diff > 0 && diff <= 900 // Within 15 minutes
    }
    
    public var isNow: Bool {
        let now = Date()
        return startTime <= now && endTime >= now
    }
    
    public var minutesUntilStart: Int {
        let diff = startTime.timeIntervalSinceNow
        return max(0, Int(diff / 60))
    }
    
    public var hasMeetLink: Bool {
        guard let link = meetLink?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !link.isEmpty
    }
}

public struct GoogleCalendarColor: Identifiable, Hashable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let hex: String
    
    public init(id: String, name: String, hex: String) {
        self.id = id
        self.name = name
        self.hex = hex
    }
    
    public static let standardPalette: [GoogleCalendarColor] = [
        GoogleCalendarColor(id: "1", name: "Lavender", hex: "#7986cb"),
        GoogleCalendarColor(id: "2", name: "Sage", hex: "#33b679"),
        GoogleCalendarColor(id: "3", name: "Grape", hex: "#8e24aa"),
        GoogleCalendarColor(id: "4", name: "Flamingo", hex: "#e67c73"),
        GoogleCalendarColor(id: "5", name: "Banana", hex: "#f6bf26"),
        GoogleCalendarColor(id: "6", name: "Tangerine", hex: "#f4511e"),
        GoogleCalendarColor(id: "7", name: "Peacock", hex: "#039be5"),
        GoogleCalendarColor(id: "8", name: "Graphite", hex: "#616161"),
        GoogleCalendarColor(id: "9", name: "Blueberry", hex: "#3f51b5"),
        GoogleCalendarColor(id: "10", name: "Basil", hex: "#0b8043"),
        GoogleCalendarColor(id: "11", name: "Tomato", hex: "#d50000")
    ]
    
    public static func hexForColorId(_ colorId: String?) -> String? {
        guard let id = colorId else { return nil }
        return standardPalette.first(where: { $0.id == id })?.hex
    }
    
    public static func labelName(for hex: String?) -> String? {
        guard let h = hex?.lowercased() else { return nil }
        return standardPalette.first(where: { $0.hex.lowercased() == h })?.name
    }
}
