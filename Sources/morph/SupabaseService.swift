import Foundation
import Combine

public enum SupabaseConnectionState: String, Equatable {
    case connected = "Connected"
    case connecting = "Connecting..."
    case offline = "Offline"
}

/// Represents an immutable focus session record stored in Supabase
public struct FocusSessionRecord: Codable, Identifiable, Sendable, Equatable {
    public var id: String
    public var userId: String
    public var userEmail: String
    public var durationMinutes: Int
    public var mode: String
    public var taskLabel: String
    public var completedAt: Date
    
    public init(
        id: String = UUID().uuidString,
        userId: String,
        userEmail: String,
        durationMinutes: Int,
        mode: String = "focus",
        taskLabel: String = "Focus Session",
        completedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.userEmail = userEmail
        self.durationMinutes = durationMinutes
        self.mode = mode
        self.taskLabel = taskLabel
        self.completedAt = completedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case userEmail = "user_email"
        case durationMinutes = "duration_minutes"
        case mode
        case taskLabel = "task_label"
        case completedAt = "completed_at"
    }
}

/// Represents a persistent Google Form / webform detection session & submission receipt in Supabase
public struct FormReceiptRecord: Codable, Identifiable, Sendable, Equatable {
    public var id: String
    public var userId: String
    public var userEmail: String
    public var formTitle: String
    public var sourceURL: String?
    public var sourceAppName: String
    public var recipientEmail: String
    public var totalQuestions: Int
    public var answeredCount: Int
    public var isSubmitted: Bool
    public var isClosedOrExpired: Bool
    public var closedReason: String?
    public var fieldsJSON: String
    public var formattedSummary: String
    public var submittedAt: Date?
    public var createdAt: Date
    
    public init(
        id: String = UUID().uuidString,
        userId: String = "",
        userEmail: String = "",
        formTitle: String,
        sourceURL: String? = nil,
        sourceAppName: String = "Web Browser",
        recipientEmail: String = "",
        totalQuestions: Int = 0,
        answeredCount: Int = 0,
        isSubmitted: Bool = false,
        isClosedOrExpired: Bool = false,
        closedReason: String? = nil,
        fieldsJSON: String = "[]",
        formattedSummary: String = "",
        submittedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.userEmail = userEmail
        self.formTitle = formTitle
        self.sourceURL = sourceURL
        self.sourceAppName = sourceAppName
        self.recipientEmail = recipientEmail
        self.totalQuestions = totalQuestions
        self.answeredCount = answeredCount
        self.isSubmitted = isSubmitted
        self.isClosedOrExpired = isClosedOrExpired
        self.closedReason = closedReason
        self.fieldsJSON = fieldsJSON
        self.formattedSummary = formattedSummary
        self.submittedAt = submittedAt
        self.createdAt = createdAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case userEmail = "user_email"
        case formTitle = "form_title"
        case sourceURL = "source_url"
        case sourceAppName = "source_app_name"
        case recipientEmail = "recipient_email"
        case totalQuestions = "total_questions"
        case answeredCount = "answered_count"
        case isSubmitted = "is_submitted"
        case isClosedOrExpired = "is_closed_or_expired"
        case closedReason = "closed_reason"
        case fieldsJSON = "fields_json"
        case formattedSummary = "formatted_summary"
        case submittedAt = "submitted_at"
        case createdAt = "created_at"
    }
    
    public var fields: [FormInputField] {
        guard let data = fieldsJSON.data(using: .utf8),
              let list = try? JSONDecoder().decode([FormInputField].self, from: data) else {
            return []
        }
        return list
    }
}

/// Represents a local-first memory record synced to Supabase `memories` table (from Glass Island HTML)
public struct GlassMemoryItem: Codable, Identifiable, Sendable, Equatable {
    public var id: String
    public var userId: String
    public var kind: String // "form", "note", "prompt", "focus", "music"
    public var title: String
    public var body: String
    public var metaJSON: String
    public var createdAt: Date
    public var updatedAt: Date
    public var syncStatus: String // "synced", "local", "error"
    
    public init(
        id: String = UUID().uuidString,
        userId: String = "",
        kind: String = "form",
        title: String = "",
        body: String = "",
        metaJSON: String = "{}",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncStatus: String = "local"
    ) {
        self.id = id
        self.userId = userId
        self.kind = kind
        self.title = title
        self.body = body
        self.metaJSON = metaJSON
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncStatus = syncStatus
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case kind
        case title
        case body
        case metaJSON = "meta_json"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case syncStatus = "sync_status"
    }
}

/// Aggregated user statistics and dashboard telemetry
public struct DashboardMetrics: Codable, Sendable, Equatable {
    public var todayFocusMinutes: Int
    public var weeklyFocusMinutes: Int
    public var totalFocusMinutes: Int
    public var todaySessionsCount: Int
    public var totalSessionsCount: Int
    public var streakDays: Int
    public var recentSessions: [FocusSessionRecord]
    public var isConnected: Bool
    public var lastSyncTime: Date?
    
    public init(
        todayFocusMinutes: Int = 0,
        weeklyFocusMinutes: Int = 0,
        totalFocusMinutes: Int = 0,
        todaySessionsCount: Int = 0,
        totalSessionsCount: Int = 0,
        streakDays: Int = 1,
        recentSessions: [FocusSessionRecord] = [],
        isConnected: Bool = true,
        lastSyncTime: Date? = nil
    ) {
        self.todayFocusMinutes = todayFocusMinutes
        self.weeklyFocusMinutes = weeklyFocusMinutes
        self.totalFocusMinutes = totalFocusMinutes
        self.todaySessionsCount = todaySessionsCount
        self.totalSessionsCount = totalSessionsCount
        self.streakDays = streakDays
        self.recentSessions = recentSessions
        self.isConnected = isConnected
        self.lastSyncTime = lastSyncTime
    }
}

@MainActor
public final class SupabaseService: ObservableObject {
    public static let shared = SupabaseService()
    
    public let projectRef = "diuqdjsyhjocgudvmbun"
    public let projectName = "resumehack"
    
    public var baseURL: URL {
        if let env = ProcessInfo.processInfo.environment["MORPH_SUPABASE_URL"], let url = URL(string: env) {
            return url
        }
        if let saved = UserDefaults.standard.string(forKey: "com.morph.supabase.custom_url"), let url = URL(string: saved) {
            return url
        }
        return URL(string: "https://diuqdjsyhjocgudvmbun.supabase.co")!
    }
    
    public var anonKey: String {
        if let env = ProcessInfo.processInfo.environment["MORPH_SUPABASE_ANON_KEY"] {
            return env
        }
        if let saved = UserDefaults.standard.string(forKey: "com.morph.supabase.custom_anon_key") {
            return saved
        }
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRpdXFkanN5aGpvY2d1ZHZtYnVuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg5ODAyODEsImV4cCI6MjEwNDU1NjI4MX0.I8bO8WvI48EiXo_mg9CkGOckMCRHFVZsEqBcf-uD2ec"
    }
    
    @Published public var currentUser: UserProfile
    @Published public var focusSessions: [FocusSessionRecord] = []
    @Published public var formReceipts: [FormReceiptRecord] = []
    @Published public var memoryItems: [GlassMemoryItem] = []
    @Published public var connectionState: SupabaseConnectionState = .connecting
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncTime: Date?
    
    private let userDefaultsKey = "com.morph.supabase.cached_profile"
    private let sessionsCacheKey = "com.morph.supabase.cached_sessions"
    private let formReceiptsCacheKey = "com.morph.supabase.cached_form_receipts"
    private let memoryItemsCacheKey = "com.morph.supabase.cached_memory_items"
    private let offlineQueueKey = "com.morph.supabase.offline_queue"
    private var urlSession: URLSession
    
    private var isTesting: Bool {
        return MorphEnvironment.isTestingEnvironment
    }
    
    public func configureSupabase(url: String, anonKey: String) {
        UserDefaults.standard.set(url, forKey: "com.morph.supabase.custom_url")
        UserDefaults.standard.set(anonKey, forKey: "com.morph.supabase.custom_anon_key")
        Task {
            await self.fetchProfile()
            await self.flushOfflineQueue()
        }
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
        
        // Load cached sessions
        if let data = UserDefaults.standard.data(forKey: sessionsCacheKey),
           let cachedSessions = try? JSONDecoder().decode([FocusSessionRecord].self, from: data) {
            self.focusSessions = cachedSessions
        }
        
        // Load cached form receipts
        if let data = UserDefaults.standard.data(forKey: formReceiptsCacheKey),
           let cachedReceipts = try? JSONDecoder().decode([FormReceiptRecord].self, from: data) {
            self.formReceipts = cachedReceipts
        }
        
        // Load cached memory items
        if let data = UserDefaults.standard.data(forKey: memoryItemsCacheKey),
           let cachedMemories = try? JSONDecoder().decode([GlassMemoryItem].self, from: data) {
            self.memoryItems = cachedMemories
        }
        
        // Initial sync
        Task {
            await self.fetchProfile()
            await self.flushOfflineQueue()
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
        if let initials = avatarInitials {
            currentUser.avatarInitials = initials
        } else if firstName != nil || lastName != nil {
            currentUser.avatarInitials = "\(currentUser.firstName.prefix(1))\(currentUser.lastName.prefix(1))".uppercased()
        }
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
    
    // MARK: - Focus Sessions & Telemetry for Statistics Dashboard
    
    public func recordFocusSession(minutes: Int, mode: String = "focus", label: String = "Focus Session") async {
        let newTotal = currentUser.totalFocusMinutes + minutes
        currentUser.totalFocusMinutes = newTotal
        
        // Create immutable telemetry record
        let record = FocusSessionRecord(
            userId: currentUser.id,
            userEmail: currentUser.email.isEmpty ? "local_user@morph.app" : currentUser.email,
            durationMinutes: minutes,
            mode: mode,
            taskLabel: label,
            completedAt: Date()
        )
        
        focusSessions.insert(record, at: 0)
        saveSessionsCache()
        
        // Update user profile total
        await updateProfile(totalFocusMinutes: newTotal)
        
        guard !isTesting else {
            connectionState = .connected
            lastSyncTime = Date()
            return
        }
        
        // Post directly to Supabase PostgREST table: focus_sessions
        guard let url = URL(string: "\(baseURL.absoluteString)/rest/v1/focus_sessions") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 3.0
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        
        let formatter = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "id": record.id,
            "user_id": record.userId,
            "user_email": record.userEmail,
            "duration_minutes": record.durationMinutes,
            "mode": record.mode,
            "task_label": record.taskLabel,
            "completed_at": formatter.string(from: record.completedAt)
        ]
        
        if let body = try? JSONSerialization.data(withJSONObject: payload) {
            request.httpBody = body
            do {
                let (_, response) = try await urlSession.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    connectionState = .connected
                    lastSyncTime = Date()
                } else {
                    queueOfflineSession(record)
                }
            } catch {
                queueOfflineSession(record)
            }
        }
    }
    
    public func fetchFocusSessions(limit: Int = 20) async -> [FocusSessionRecord] {
        guard !isTesting else {
            return Array(focusSessions.prefix(limit))
        }
        
        guard let url = URL(string: "\(baseURL.absoluteString)/rest/v1/focus_sessions?user_id=eq.\(currentUser.id)&order=completed_at.desc&limit=\(limit)") else {
            return Array(focusSessions.prefix(limit))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3.0
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let remoteSessions = try decoder.decode([FocusSessionRecord].self, from: data)
                
                // Merge with existing local sessions without duplicates
                var existingIds = Set(remoteSessions.map { $0.id })
                var merged = remoteSessions
                for local in focusSessions where !existingIds.contains(local.id) {
                    merged.append(local)
                    existingIds.insert(local.id)
                }
                merged.sort { $0.completedAt > $1.completedAt }
                self.focusSessions = merged
                saveSessionsCache()
                self.connectionState = .connected
                self.lastSyncTime = Date()
                return Array(merged.prefix(limit))
            }
        } catch {
            // Fallback to local cache
        }
        return Array(focusSessions.prefix(limit))
    }
    
    // MARK: - Form Tracking & Receipts in Supabase
    
    public func recordFormReceipt(_ record: FormReceiptRecord) async {
        // Upsert locally
        if let idx = formReceipts.firstIndex(where: { $0.id == record.id }) {
            formReceipts[idx] = record
        } else {
            formReceipts.insert(record, at: 0)
        }
        saveFormReceiptsCache()
        
        guard !isTesting else {
            connectionState = .connected
            lastSyncTime = Date()
            return
        }
        
        // Post directly to Supabase PostgREST table: form_receipts
        guard let url = URL(string: "\(baseURL.absoluteString)/rest/v1/form_receipts") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 3.0
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let formatter = ISO8601DateFormatter()
        var payload: [String: Any] = [
            "id": record.id,
            "user_id": record.userId,
            "user_email": record.userEmail,
            "form_title": record.formTitle,
            "source_app_name": record.sourceAppName,
            "recipient_email": record.recipientEmail,
            "total_questions": record.totalQuestions,
            "answered_count": record.answeredCount,
            "is_submitted": record.isSubmitted,
            "is_closed_or_expired": record.isClosedOrExpired,
            "fields_json": record.fieldsJSON,
            "formatted_summary": record.formattedSummary,
            "created_at": formatter.string(from: record.createdAt)
        ]
        if let u = record.sourceURL { payload["source_url"] = u }
        if let r = record.closedReason { payload["closed_reason"] = r }
        if let s = record.submittedAt { payload["submitted_at"] = formatter.string(from: s) }
        
        if let body = try? JSONSerialization.data(withJSONObject: payload) {
            request.httpBody = body
            do {
                let (_, response) = try await urlSession.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    connectionState = .connected
                    lastSyncTime = Date()
                }
            } catch {
                // Preserved in local cache
            }
        }
    }
    
    public func recordFormReceipt(
        id: String,
        formTitle: String,
        sourceURL: String? = nil,
        sourceAppName: String = "Web Browser",
        recipientEmail: String = "",
        totalQuestions: Int = 0,
        answeredCount: Int = 0,
        isSubmitted: Bool = false,
        isClosedOrExpired: Bool = false,
        closedReason: String? = nil,
        fieldsJSON: String = "[]",
        formattedSummary: String = "",
        submittedAt: Date? = nil,
        createdAt: Date = Date()
    ) async {
        let record = FormReceiptRecord(
            id: id,
            userId: currentUser.id,
            userEmail: currentUser.email.isEmpty ? recipientEmail : currentUser.email,
            formTitle: formTitle,
            sourceURL: sourceURL,
            sourceAppName: sourceAppName,
            recipientEmail: recipientEmail,
            totalQuestions: totalQuestions,
            answeredCount: answeredCount,
            isSubmitted: isSubmitted,
            isClosedOrExpired: isClosedOrExpired,
            closedReason: closedReason,
            fieldsJSON: fieldsJSON,
            formattedSummary: formattedSummary,
            submittedAt: submittedAt,
            createdAt: createdAt
        )
        await recordFormReceipt(record)
    }
    
    public func fetchFormReceipts(limit: Int = 50) async -> [FormReceiptRecord] {
        guard !isTesting else {
            return Array(formReceipts.prefix(limit))
        }
        
        guard let url = URL(string: "\(baseURL.absoluteString)/rest/v1/form_receipts?user_id=eq.\(currentUser.id)&order=created_at.desc&limit=\(limit)") else {
            return Array(formReceipts.prefix(limit))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3.0
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let remoteReceipts = try decoder.decode([FormReceiptRecord].self, from: data)
                
                var existingIds = Set(remoteReceipts.map { $0.id })
                var merged = remoteReceipts
                for local in formReceipts where !existingIds.contains(local.id) {
                    merged.append(local)
                    existingIds.insert(local.id)
                }
                merged.sort { $0.createdAt > $1.createdAt }
                self.formReceipts = merged
                saveFormReceiptsCache()
                self.connectionState = .connected
                self.lastSyncTime = Date()
                return Array(merged.prefix(limit))
            }
        } catch {
            // Fallback to local cache
        }
        return Array(formReceipts.prefix(limit))
    }
    
    public func saveFormReceiptsCache() {
        if let data = try? JSONEncoder().encode(formReceipts) {
            UserDefaults.standard.set(data, forKey: formReceiptsCacheKey)
        }
    }
    
    // MARK: - Glass Island Memory Store (Supabase REST)
    public func saveMemoryItem(_ item: GlassMemoryItem) async {
        // Upsert locally
        let updated = item
        if let idx = memoryItems.firstIndex(where: { $0.id == item.id }) {
            memoryItems[idx] = updated
        } else {
            memoryItems.insert(updated, at: 0)
        }
        saveMemoryItemsCache()
        
        guard !isTesting else {
            connectionState = .connected
            lastSyncTime = Date()
            return
        }
        
        // Post directly to Supabase PostgREST table: memories
        guard let url = URL(string: "\(baseURL.absoluteString)/rest/v1/memories") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 3.0
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        
        let formatter = ISO8601DateFormatter()
        let payload: [String: Any] = [
            "id": updated.id,
            "user_id": updated.userId.isEmpty ? currentUser.id : updated.userId,
            "kind": updated.kind,
            "title": updated.title,
            "body": updated.body,
            "meta": (try? JSONSerialization.jsonObject(with: Data(updated.metaJSON.utf8))) ?? [:],
            "created_at": formatter.string(from: updated.createdAt),
            "updated_at": formatter.string(from: updated.updatedAt)
        ]
        
        if let bodyData = try? JSONSerialization.data(withJSONObject: payload) {
            request.httpBody = bodyData
            do {
                let (_, response) = try await urlSession.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    if let idx = memoryItems.firstIndex(where: { $0.id == updated.id }) {
                        memoryItems[idx].syncStatus = "synced"
                        saveMemoryItemsCache()
                    }
                    connectionState = .connected
                    lastSyncTime = Date()
                }
            } catch {
                // Preserved in local cache
            }
        }
    }
    
    public func fetchMemoryItems(kind: String? = nil, limit: Int = 100) async -> [GlassMemoryItem] {
        guard !isTesting else {
            if let k = kind {
                return memoryItems.filter { $0.kind == k }
            }
            return memoryItems
        }
        
        var urlString = "\(baseURL.absoluteString)/rest/v1/memories?user_id=eq.\(currentUser.id)&order=updated_at.desc&limit=\(limit)"
        if let k = kind {
            urlString += "&kind=eq.\(k)"
        }
        guard let url = URL(string: urlString) else {
            return memoryItems
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3.0
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    let formatter = ISO8601DateFormatter()
                    var remoteItems: [GlassMemoryItem] = []
                    for dict in array {
                        let id = dict["id"] as? String ?? UUID().uuidString
                        let userId = dict["user_id"] as? String ?? ""
                        let k = dict["kind"] as? String ?? "form"
                        let title = dict["title"] as? String ?? ""
                        let body = dict["body"] as? String ?? ""
                        let metaDict = dict["meta"] as? [String: Any] ?? [:]
                        let metaJSON = (try? String(data: JSONSerialization.data(withJSONObject: metaDict), encoding: .utf8)) ?? "{}"
                        let createdStr = dict["created_at"] as? String ?? ""
                        let updatedStr = dict["updated_at"] as? String ?? ""
                        let created = formatter.date(from: createdStr) ?? Date()
                        let updated = formatter.date(from: updatedStr) ?? created
                        
                        remoteItems.append(GlassMemoryItem(
                            id: id,
                            userId: userId,
                            kind: k,
                            title: title,
                            body: body,
                            metaJSON: metaJSON,
                            createdAt: created,
                            updatedAt: updated,
                            syncStatus: "synced"
                        ))
                    }
                    
                    var existingIds = Set(remoteItems.map { $0.id })
                    var merged = remoteItems
                    for local in memoryItems where !existingIds.contains(local.id) {
                        merged.append(local)
                        existingIds.insert(local.id)
                    }
                    merged.sort { $0.updatedAt > $1.updatedAt }
                    self.memoryItems = merged
                    saveMemoryItemsCache()
                    self.connectionState = .connected
                    self.lastSyncTime = Date()
                    return merged
                }
            }
        } catch {
            // Return cached
        }
        return memoryItems
    }
    
    public func searchMemories(query: String) -> [GlassMemoryItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return memoryItems }
        
        let words = q.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !words.isEmpty else { return memoryItems }
        
        var scored: [(item: GlassMemoryItem, score: Double)] = []
        for item in memoryItems {
            let ti = item.title.lowercased()
            let bo = item.body.lowercased()
            let me = item.metaJSON.lowercased()
            let kind = item.kind.lowercased()
            
            var totalScore = 0.0
            var allMatch = true
            
            for w in words {
                let inTitle = ti.contains(w)
                let inBody = bo.contains(w)
                let inMeta = me.contains(w)
                let inKind = kind.contains(w)
                
                if !inTitle && !inBody && !inMeta && !inKind {
                    allMatch = false
                    break
                }
                totalScore += (inTitle ? 3.0 : 0.0) + (inBody ? 1.0 : 0.0) + (inMeta ? 1.5 : 0.0) + (inKind ? 0.5 : 0.0)
            }
            
            if allMatch && totalScore > 0 {
                scored.append((item, totalScore))
            }
        }
        
        scored.sort { $0.score > $1.score }
        return scored.map { $0.item }
    }
    
    public func saveMemoryItemsCache() {
        if let data = try? JSONEncoder().encode(memoryItems) {
            UserDefaults.standard.set(data, forKey: memoryItemsCacheKey)
        }
    }
    
    /// Returns aggregated metrics for displaying in future dashboard views
    public func fetchDashboardMetrics() -> DashboardMetrics {
        let calendar = Calendar.current
        let today = Date()
        
        var todayMinutes = 0
        var weeklyMinutes = 0
        var todayCount = 0
        
        for session in focusSessions {
            if calendar.isDateInToday(session.completedAt) {
                todayMinutes += session.durationMinutes
                todayCount += 1
            }
            if let diff = calendar.dateComponents([.day], from: session.completedAt, to: today).day, diff < 7 {
                weeklyMinutes += session.durationMinutes
            }
        }
        
        let totalMins = max(currentUser.totalFocusMinutes, todayMinutes)
        
        return DashboardMetrics(
            todayFocusMinutes: todayMinutes,
            weeklyFocusMinutes: weeklyMinutes,
            totalFocusMinutes: totalMins,
            todaySessionsCount: todayCount,
            totalSessionsCount: focusSessions.count,
            streakDays: max(1, currentUser.streakDays),
            recentSessions: Array(focusSessions.prefix(10)),
            isConnected: connectionState == .connected,
            lastSyncTime: lastSyncTime
        )
    }
    
    public func flushOfflineQueue() async {
        guard !isTesting else { return }
        guard let data = UserDefaults.standard.data(forKey: offlineQueueKey),
              let queue = try? JSONDecoder().decode([FocusSessionRecord].self, from: data),
              !queue.isEmpty else {
            return
        }
        
        guard let url = URL(string: "\(baseURL.absoluteString)/rest/v1/focus_sessions") else { return }
        
        let formatter = ISO8601DateFormatter()
        var remainingQueue: [FocusSessionRecord] = []
        
        for record in queue {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 3.0
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
            
            let payload: [String: Any] = [
                "id": record.id,
                "user_id": record.userId,
                "user_email": record.userEmail,
                "duration_minutes": record.durationMinutes,
                "mode": record.mode,
                "task_label": record.taskLabel,
                "completed_at": formatter.string(from: record.completedAt)
            ]
            
            if let body = try? JSONSerialization.data(withJSONObject: payload) {
                request.httpBody = body
                do {
                    let (_, response) = try await urlSession.data(for: request)
                    if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                        // Success, do not re-queue
                        continue
                    } else {
                        remainingQueue.append(record)
                    }
                } catch {
                    remainingQueue.append(record)
                }
            }
        }
        
        if remainingQueue.isEmpty {
            UserDefaults.standard.removeObject(forKey: offlineQueueKey)
            connectionState = .connected
            lastSyncTime = Date()
        } else {
            if let encoded = try? JSONEncoder().encode(remainingQueue) {
                UserDefaults.standard.set(encoded, forKey: offlineQueueKey)
            }
        }
    }
    
    private func queueOfflineSession(_ record: FocusSessionRecord) {
        var queue: [FocusSessionRecord] = []
        if let data = UserDefaults.standard.data(forKey: offlineQueueKey),
           let cached = try? JSONDecoder().decode([FocusSessionRecord].self, from: data) {
            queue = cached
        }
        queue.append(record)
        if let encoded = try? JSONEncoder().encode(queue) {
            UserDefaults.standard.set(encoded, forKey: offlineQueueKey)
        }
    }
    
    private func saveSessionsCache() {
        if let data = try? JSONEncoder().encode(focusSessions) {
            UserDefaults.standard.set(data, forKey: sessionsCacheKey)
        }
    }
    
    public func signOut() {
        self.currentUser = UserProfile.guest
        self.focusSessions = []
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: sessionsCacheKey)
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

