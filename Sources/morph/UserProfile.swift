import Foundation

public struct UserProfile: Codable, Equatable, Sendable {
    public var id: String
    public var firstName: String
    public var lastName: String
    public var email: String
    public var targetRole: String
    public var streakDays: Int
    public var totalFocusMinutes: Int
    public var currentStatus: String
    public var avatarInitials: String
    
    public var displayName: String {
        let fullName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        if !fullName.isEmpty {
            return fullName
        }
        if !email.isEmpty {
            return email.components(separatedBy: "@").first ?? email
        }
        return "Morph Explorer"
    }
    
    public var displayInitials: String {
        if !avatarInitials.isEmpty {
            return avatarInitials.uppercased()
        }
        let initials = "\(firstName.prefix(1))\(lastName.prefix(1))".trimmingCharacters(in: .whitespaces)
        if !initials.isEmpty {
            return initials.uppercased()
        }
        return "ME"
    }
    
    public var isAuthenticated: Bool {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleanEmail.isEmpty && cleanEmail.contains("@")
    }

    
    public init(
        id: String = "local_user",
        firstName: String = "Aaron",
        lastName: String = "Nguyen",
        email: String = "minh7898888@gmail.com",
        targetRole: String = "Senior Software Engineer",
        streakDays: Int = 5,
        totalFocusMinutes: Int = 120,
        currentStatus: String = "In the Zone",
        avatarInitials: String = "AN"
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.targetRole = targetRole
        self.streakDays = streakDays
        self.totalFocusMinutes = totalFocusMinutes
        self.currentStatus = currentStatus
        self.avatarInitials = avatarInitials
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case firstName = "first_name"
        case lastName = "last_name"
        case email
        case targetRole = "target_role"
        case streakDays = "streak_days"
        case totalFocusMinutes = "total_focus_minutes"
        case currentStatus = "current_status"
        case avatarInitials = "avatar_initials"
    }
}
