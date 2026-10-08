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
    public var avatarImageBase64: String?
    public var avatarURL: String?
    
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
    
    public static var guest: UserProfile {
        UserProfile(
            id: "guest_user",
            firstName: "Guest",
            lastName: "User",
            email: "",
            targetRole: "Explorer",
            streakDays: 0,
            totalFocusMinutes: 0,
            currentStatus: "Signed Out",
            avatarInitials: "GU"
        )
    }

    
    public init(
        id: String = "local_user",
        firstName: String = "",
        lastName: String = "",
        email: String = "",
        targetRole: String = "Morph Explorer",
        streakDays: Int = 0,
        totalFocusMinutes: Int = 0,
        currentStatus: String = "Ready",
        avatarInitials: String = "",
        avatarImageBase64: String? = nil,
        avatarURL: String? = nil
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
        self.avatarImageBase64 = avatarImageBase64
        self.avatarURL = avatarURL
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
        case avatarImageBase64 = "avatar_image_base64"
        case avatarURL = "avatar_url"
    }
}
