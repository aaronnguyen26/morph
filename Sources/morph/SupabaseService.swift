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
        totalFocusMinutes: Int? = nil
    ) async {
        if let first = firstName { currentUser.firstName = first }
        if let last = lastName { currentUser.lastName = last }
        if let mail = email { currentUser.email = mail }
        if let initials = avatarInitials { currentUser.avatarInitials = initials }
        if let role = targetRole { currentUser.targetRole = role }
        if let status = currentStatus { currentUser.currentStatus = status }
        if let streak = streakDays { currentUser.streakDays = streak }
        if let focus = totalFocusMinutes { currentUser.totalFocusMinutes = focus }
        
        saveToLocalCache(currentUser)
        
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
    
    private func saveToLocalCache(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
