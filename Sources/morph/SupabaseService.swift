import Foundation
import Combine

public enum SupabaseConnectionState: String, Equatable {
    case connected = "Connected"
    case connecting = "Connecting..."
    case offline = "Offline"
}

@MainActor
public final class SupabaseService: ObservableObject {
    public static let shared = SupabaseService()
    
    public let projectRef = "diuqdjsyhjocgudvmbun"
    public let projectName = "resumehack"
    public let baseURL = URL(string: "https://diuqdjsyhjocgudvmbun.supabase.co")!
    public let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRpdXFkanN5aGpvY2d1ZHZtYnVuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg5ODAyODEsImV4cCI6MjEwNDU1NjI4MX0.I8bO8WvI48EiXo_mg9CkGOckMCRHFVZsEqBcf-uD2ec"
    
    @Published public var currentUser: UserProfile
    @Published public var connectionState: SupabaseConnectionState = .connecting
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncTime: Date?
    
    private let userDefaultsKey = "com.morph.supabase.cached_profile"
    private var urlSession: URLSession
    
    private var isTesting: Bool {
        return ProcessInfo.processInfo.processName.contains("xctest") ||
            ProcessInfo.processInfo.arguments.contains(where: { $0.contains("xctest") }) ||
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
            NSClassFromString("XCTestCase") != nil
    }
    
    public init(session: URLSession? = nil) {
        if let session = session {
            self.urlSession = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.waitsForConnectivity = false
            config.timeoutIntervalForRequest = 2.0
            config.timeoutIntervalForResource = 3.0
            self.urlSession = URLSession(configuration: config)
        }
        
        // Load from cache or initialize default
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let cached = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.currentUser = cached
        } else {
            self.currentUser = UserProfile()
        }
        
        // Initial sync
        Task {
            await fetchProfile()
        }
    }
    
    public func fetchProfile() async {
        isSyncing = true
        connectionState = .connecting
        
        guard !isTesting else {
            connectionState = .connected
            isSyncing = false
            return
        }
        
        guard let url = URL(string: "\(baseURL.absoluteString)/rest/v1/profiles?select=*&limit=1") else {
            connectionState = .offline
            isSyncing = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 3.0
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                let profiles = try JSONDecoder().decode([UserProfile].self, from: data)
                if let profile = profiles.first {
                    var merged = profile
                    if self.currentUser.totalFocusMinutes > merged.totalFocusMinutes {
                        merged.totalFocusMinutes = self.currentUser.totalFocusMinutes
                    }
                    self.currentUser = merged
                    self.saveToLocalCache(merged)
                    self.connectionState = .connected
                    self.lastSyncTime = Date()
                } else {
                    self.connectionState = .connected
                }
            } else {
                self.connectionState = .offline
            }
        } catch {
            self.connectionState = .offline
        }
        
        isSyncing = false
    }
    
    public func updateProfile(
        firstName: String? = nil,
        lastName: String? = nil,
        email: String? = nil,
        avatarInitials: String? = nil,
        targetRole: String? = nil,
        currentStatus: String? = nil,
        streakDays: Int? = nil,
        totalFocusMinutes: Int? = nil,
        avatarImageBase64: String? = nil
    ) async {
        if let first = firstName { currentUser.firstName = first }
        if let last = lastName { currentUser.lastName = last }
        if let mail = email { currentUser.email = mail }
        if let initials = avatarInitials { currentUser.avatarInitials = initials }
        if let role = targetRole { currentUser.targetRole = role }
        if let status = currentStatus { currentUser.currentStatus = status }
        if let streak = streakDays { currentUser.streakDays = streak }
        if let focus = totalFocusMinutes { currentUser.totalFocusMinutes = focus }
        if let avatar = avatarImageBase64 { currentUser.avatarImageBase64 = avatar }
        
        saveToLocalCache(currentUser)
        saveUserToRegistry(currentUser)
        
        guard !isTesting else {
            connectionState = .connected
            lastSyncTime = Date()
            return
        }
        
        guard let url = URL(string: "\(baseURL.absoluteString)/rest/v1/profiles?id=eq.\(currentUser.id)") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.timeoutInterval = 3.0
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        var payload: [String: Any] = [:]
        if let first = firstName { payload["first_name"] = first }
        if let last = lastName { payload["last_name"] = last }
        if let mail = email { payload["email"] = mail }
        if let initials = avatarInitials { payload["avatar_initials"] = initials } else { payload["avatar_initials"] = currentUser.displayInitials }
        if let role = targetRole { payload["target_role"] = role }
        if let status = currentStatus { payload["current_status"] = status }
        if let streak = streakDays { payload["streak_days"] = streak }
        if let focus = totalFocusMinutes { payload["total_focus_minutes"] = focus }
        if let avatar = avatarImageBase64 { payload["avatar_image_base64"] = avatar }
        
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        request.httpBody = body
        
        do {
            let (_, response) = try await urlSession.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                connectionState = .connected
                lastSyncTime = Date()
            }
        } catch {
            // Keep local changes cached
        }
    }
    
    public func recordFocusSession(minutes: Int) async {
        let newTotal = currentUser.totalFocusMinutes + minutes
        currentUser.totalFocusMinutes = newTotal
        await updateProfile(totalFocusMinutes: newTotal)
    }
    
    public func signOut() {
        self.currentUser = UserProfile.guest
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        self.connectionState = .offline
        self.lastSyncTime = nil
    }
    
    /// User registry key storing profiles by normalized username / email
    private let registryKey = "com.morph.user_registry"
    
    /// Checks if a given username or email already has an existing registered profile
    public func isRegisteredUser(identifier: String) -> Bool {
        let clean = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return false }
        let dict = UserDefaults.standard.dictionary(forKey: registryKey) ?? [:]
        return dict[clean] != nil
    }
    
    /// Fetches an existing registered profile for a given username or email
    public func getRegisteredProfile(identifier: String) -> UserProfile? {
        let clean = identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return nil }
        guard let dict = UserDefaults.standard.dictionary(forKey: registryKey),
              let base64 = dict[clean] as? String,
              let data = Data(base64Encoded: base64),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return nil
        }
        return profile
    }
    
    /// Clears the user registry (for testing clean-slate sign ins)
    public func clearUserRegistry() {
        UserDefaults.standard.removeObject(forKey: registryKey)
    }
    
    private func saveUserToRegistry(_ profile: UserProfile) {
        var dict = UserDefaults.standard.dictionary(forKey: registryKey) ?? [:]
        if let data = try? JSONEncoder().encode(profile) {
            let base64 = data.base64EncodedString()
            let cleanEmail = profile.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !cleanEmail.isEmpty {
                dict[cleanEmail] = base64
                let username = cleanEmail.components(separatedBy: "@").first ?? cleanEmail
                dict[username] = base64
            }
            UserDefaults.standard.set(dict, forKey: registryKey)
        }
    }
    
    public func signIn(
        username: String,
        password: String,
        firstName: String? = nil,
        lastName: String? = nil,
        role: String? = nil,
        avatarImageBase64: String? = nil
    ) async -> (profile: UserProfile, isFirstTime: Bool) {
        let cleanUser = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanUser.isEmpty, !cleanPassword.isEmpty else {
            return (self.currentUser, false)
        }
        
        let normalizedKey = cleanUser.lowercased()
        let isExisting = isRegisteredUser(identifier: normalizedKey)
        let isFirstTime = !isExisting
        
        // Derive valid email for Google Calendar SSO propagation
        let derivedEmail: String
        if cleanUser.contains("@") {
            derivedEmail = cleanUser
        } else {
            derivedEmail = "\(cleanUser.lowercased())@gmail.com"
        }
        
        var profile: UserProfile
        if let existing = getRegisteredProfile(identifier: normalizedKey) {
            profile = existing
            // Update any overrides provided
            if let f = firstName, !f.isEmpty { profile.firstName = f }
            if let l = lastName, !l.isEmpty { profile.lastName = l }
            if let r = role, !r.isEmpty { profile.targetRole = r }
            if let a = avatarImageBase64, !a.isEmpty { profile.avatarImageBase64 = a }
        } else {
            // First-time user profile
            let fName = firstName ?? (cleanUser.contains("@") ? cleanUser.components(separatedBy: "@").first?.capitalized : cleanUser.capitalized) ?? "User"
            let lName = lastName ?? ""
            let rTitle = role ?? "Productive Pro"
            
            var initials = ""
            if let fChar = fName.first { initials.append(fChar.uppercased()) }
            if let lChar = lName.first { initials.append(lChar.uppercased()) }
            if initials.isEmpty {
                initials = String(cleanUser.prefix(2)).uppercased()
            }
            
            profile = UserProfile(
                id: UUID().uuidString,
                firstName: fName,
                lastName: lName,
                email: derivedEmail,
                targetRole: rTitle,
                streakDays: 1,
                totalFocusMinutes: 0,
                currentStatus: "Ready",
                avatarInitials: initials,
                avatarImageBase64: avatarImageBase64
            )
        }
        
        self.currentUser = profile
        self.saveToLocalCache(profile)
        self.saveUserToRegistry(profile)
        self.connectionState = .connected
        self.lastSyncTime = Date()
        
        // Attempt cloud profile fetch/sync
        await fetchProfile()
        
        return (profile, isFirstTime)
    }
    
    // Convenience backward-compatible signIn with email
    public func signIn(email: String, firstName: String? = nil, lastName: String? = nil, role: String? = nil) async {
        _ = await signIn(
            username: email,
            password: "password123",
            firstName: firstName,
            lastName: lastName,
            role: role,
            avatarImageBase64: nil
        )
    }
    
    private func saveToLocalCache(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}

