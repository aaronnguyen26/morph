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
}
