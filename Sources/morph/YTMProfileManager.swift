import Foundation
import Combine
import WebKit
import AppKit

/// Represents an isolated user profile for YouTube Music inside Morph.
public struct YTMProfile: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var email: String
    public var displayName: String
    public var avatarLocalPath: String?
    public var avatarURL: String?
    public var isDefault: Bool
    public var createdAt: Date
    public var lastUsedAt: Date
    public var isChromeImported: Bool
    public var accountTier: YTMAccountTier
    
    public init(
        id: UUID = UUID(),
        email: String,
        displayName: String = "",
        avatarLocalPath: String? = nil,
        avatarURL: String? = nil,
        isDefault: Bool = false,
        createdAt: Date = Date(),
        lastUsedAt: Date = Date(),
        isChromeImported: Bool = false,
        accountTier: YTMAccountTier = .unknown
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName.isEmpty ? (email.components(separatedBy: "@").first ?? "Profile") : displayName
        self.avatarLocalPath = avatarLocalPath
        self.avatarURL = avatarURL
        self.isDefault = isDefault
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.isChromeImported = isChromeImported
        self.accountTier = accountTier
    }
    
    enum CodingKeys: String, CodingKey {
        case id, email, displayName, avatarLocalPath, avatarURL, isDefault, createdAt, lastUsedAt, isChromeImported, accountTier
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.email = try container.decode(String.self, forKey: .email)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        self.avatarLocalPath = try container.decodeIfPresent(String.self, forKey: .avatarLocalPath)
        self.avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        self.isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt) ?? Date()
        self.isChromeImported = try container.decodeIfPresent(Bool.self, forKey: .isChromeImported) ?? false
        self.accountTier = try container.decodeIfPresent(YTMAccountTier.self, forKey: .accountTier) ?? .unknown
    }
    
    public var avatarImage: NSImage? {
        if let path = avatarLocalPath, FileManager.default.fileExists(atPath: path), let img = NSImage(contentsOfFile: path) {
            return img
        }
        return nil
    }
}

/// Central manager for user profiles in Morph's music player.
/// Allows switching between multiple Gmail / YouTube accounts seamlessly,
/// each with its own isolated WebKit website data store.
@MainActor
public final class YTMProfileManager: ObservableObject {
    public static let shared = YTMProfileManager()
    
    @Published public private(set) var profiles: [YTMProfile] = []
    @Published public private(set) var activeProfileId: UUID? = nil
    
    public var activeProfile: YTMProfile? {
        profiles.first { $0.id == activeProfileId } ?? profiles.first { $0.isDefault } ?? profiles.first
    }
    
    private let kProfilesKey = "com.morph.ytm_profiles"
    private let kActiveProfileKey = "com.morph.ytm_active_profile_id"
    private let kInitialEmailKey = "com.morph.ytm_initial_email"
    
    public init() {
        loadProfiles()
    }
    
    public func loadProfiles() {
        if let data = UserDefaults.standard.data(forKey: kProfilesKey),
           let decoded = try? JSONDecoder().decode([YTMProfile].self, from: data),
           !decoded.isEmpty {
            self.profiles = decoded
        } else {
            // No saved profile: initialize empty state with zero dummy profiles or hardcoded accounts
            self.profiles = []
            self.activeProfileId = nil
        }
        
        // Enrich any existing profile with accurate avatar for its specific email
        var modified = false
        for i in 0..<profiles.count {
            let email = profiles[i].email
            if !email.isEmpty {
                let av = resolveAvatarForProfile(email: email)
                if av.localPath != nil && profiles[i].avatarLocalPath != av.localPath {
                    profiles[i].avatarLocalPath = av.localPath
                    modified = true
                }
                if av.url != nil && profiles[i].avatarURL == nil {
                    profiles[i].avatarURL = av.url
                    modified = true
                }
            }
        }
        if modified {
            saveProfiles()
        }
        
        if let savedIdStr = UserDefaults.standard.string(forKey: kActiveProfileKey),
           let savedId = UUID(uuidString: savedIdStr),
           profiles.contains(where: { $0.id == savedId }) {
            self.activeProfileId = savedId
        } else {
            self.activeProfileId = profiles.first?.id
        }
    }
    
    public func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(encoded, forKey: kProfilesKey)
        }
        if let activeId = activeProfileId {
            UserDefaults.standard.set(activeId.uuidString, forKey: kActiveProfileKey)
        }
    }
    
    /// Switches to the specified profile.
    public func switchProfile(to id: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].lastUsedAt = Date()
        self.activeProfileId = id
        saveProfiles()
    }
    
    /// Clears the active profile on user log out.
    public func clearActiveProfile() {
        self.activeProfileId = nil
        UserDefaults.standard.removeObject(forKey: kActiveProfileKey)
    }
    
    /// Completely clears all stored profiles upon user log out, guaranteeing clean single-account isolation.
    public func clearAllProfiles() {
        self.profiles = []
        self.activeProfileId = nil
        UserDefaults.standard.removeObject(forKey: kProfilesKey)
        UserDefaults.standard.removeObject(forKey: kActiveProfileKey)
        UserDefaults.standard.removeObject(forKey: kInitialEmailKey)
        DispatchQueue.main.async { self.objectWillChange.send() }
    }
    
    /// Adds a new profile and sets it as active.
    @discardableResult
    public func addProfile(
        email: String,
        displayName: String = "",
        avatarLocalPath: String? = nil,
        avatarURL: String? = nil,
        isChromeImported: Bool = false
    ) -> YTMProfile {
        if let existing = profiles.first(where: { $0.email.lowercased() == email.lowercased() && !email.isEmpty }) {
            switchProfile(to: existing.id)
            return existing
        }
        
        let resolved = (avatarLocalPath != nil) ? (localPath: avatarLocalPath, url: avatarURL) : resolveAvatarForProfile(email: email)
        
        let newProfile = YTMProfile(
            id: UUID(),
            email: email,
            displayName: displayName,
            avatarLocalPath: resolved.localPath,
            avatarURL: resolved.url,
            isDefault: profiles.isEmpty,
            createdAt: Date(),
            lastUsedAt: Date(),
            isChromeImported: isChromeImported
        )
        profiles.append(newProfile)
        self.activeProfileId = newProfile.id
        saveProfiles()
        return newProfile
    }
    
    /// Removes a profile. If the removed profile was active, switches to another profile.
    public func removeProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
        if activeProfileId == id {
            activeProfileId = profiles.first?.id
        }
        saveProfiles()
    }
    
    /// Updates the currently active profile when a new email is detected from the web player.
    /// Strictly guarantees single-account isolation: whatever Google account the user signs into
    /// is the single account displayed on Morph.
    public func handleDetectedEmail(_ email: String, avatarURL: String? = nil, displayName: String? = nil, accountTier: YTMAccountTier = .unknown) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { return }
        
        let avatarInfo = resolveAvatarForProfile(email: trimmedEmail)
        let effectiveAvatarPath = avatarInfo.localPath
        let effectiveAvatarURL = avatarURL ?? avatarInfo.url
        let effectiveName = displayName ?? (trimmedEmail.components(separatedBy: "@").first ?? "User")
        
        // Single Account Guarantee: Whatever account they sign into is the only one present
        var profile = YTMProfile(
            email: trimmedEmail,
            displayName: effectiveName,
            avatarLocalPath: effectiveAvatarPath,
            avatarURL: effectiveAvatarURL,
            isDefault: true,
            lastUsedAt: Date(),
            accountTier: accountTier
        )
        if let existing = profiles.first(where: { $0.email.lowercased() == trimmedEmail.lowercased() }) {
            profile.id = existing.id
            if effectiveAvatarPath == nil { profile.avatarLocalPath = existing.avatarLocalPath }
            if effectiveAvatarURL == nil { profile.avatarURL = existing.avatarURL }
            if accountTier == .unknown && existing.accountTier != .unknown { profile.accountTier = existing.accountTier }
        }
        
        self.profiles = [profile]
        self.activeProfileId = profile.id
        saveProfiles()
        DispatchQueue.main.async { self.objectWillChange.send() }
    }
    
    public func updateActiveProfileTier(_ tier: YTMAccountTier) {
        guard let active = activeProfile else { return }
        updateProfileTier(id: active.id, tier: tier)
    }
    
    public func updateProfileTier(id: UUID, tier: YTMAccountTier) {
        guard let idx = profiles.firstIndex(where: { $0.id == id }) else { return }
        if profiles[idx].accountTier != tier {
            profiles[idx].accountTier = tier
            saveProfiles()
            DispatchQueue.main.async { self.objectWillChange.send() }
        }
    }
    
    /// Updates the active profile's remote avatar URL (e.g. from YouTube Music webview DOM img#avatar-btn)
    public func updateActiveProfileAvatar(url: String) {
        guard !url.isEmpty, let activeId = activeProfileId,
              let idx = profiles.firstIndex(where: { $0.id == activeId }) else { return }
        profiles[idx].avatarURL = url
        saveProfiles()
        DispatchQueue.main.async { self.objectWillChange.send() }
    }
    
    /// Resolves local avatar PNG and remote GAIA picture URL from Chrome profiles on disk for a specific email.
    public func resolveAvatarForProfile(email: String) -> (localPath: String?, url: String?) {
        guard !email.isEmpty else { return (nil, nil) }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let chromeBase = home + "/Library/Application Support/Google/Chrome"
        let localStatePath = chromeBase + "/Local State"
        guard FileManager.default.fileExists(atPath: localStatePath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: localStatePath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profileDict = json["profile"] as? [String: Any],
              let infoCache = profileDict["info_cache"] as? [String: Any] else {
            return (nil, nil)
        }
        
        for (folder, value) in infoCache {
            guard let info = value as? [String: Any] else { continue }
            let user = (info["user_name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if user.lowercased() == email.lowercased() {
                let picName = info["gaia_picture_file_name"] as? String ?? "Google Profile Picture.png"
                let picPath = "\(chromeBase)/\(folder)/\(picName)"
                let url = info["last_downloaded_gaia_picture_url_with_size"] as? String
                let validPath = FileManager.default.fileExists(atPath: picPath) ? picPath : nil
                return (validPath, url)
            }
        }
        
        return (nil, nil)
    }
    
    /// Scans Google Chrome's Local State configuration to detect all signed-in Google profiles
    /// (e.g. Cabdi flathcabdi393@gmail.com, Aaron minh7898888@gmail.com) so the user can import with one click.
    public func detectAvailableBrowserProfiles() -> [(name: String, email: String, profileFolder: String, avatarLocalPath: String?, avatarURL: String?)] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let chromeBase = home + "/Library/Application Support/Google/Chrome"
        let localStatePath = chromeBase + "/Local State"
        guard FileManager.default.fileExists(atPath: localStatePath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: localStatePath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profileDict = json["profile"] as? [String: Any],
              let infoCache = profileDict["info_cache"] as? [String: Any] else {
            return []
        }
        
        var results: [(name: String, email: String, profileFolder: String, avatarLocalPath: String?, avatarURL: String?)] = []
        let existingEmails = Set(profiles.map { $0.email.lowercased() })
        
        for (folder, value) in infoCache {
            guard let info = value as? [String: Any] else { continue }
            let email = (info["user_name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !email.isEmpty, email.contains("@") else { continue }
            
            // Skip if already in Morph profiles
            if existingEmails.contains(email.lowercased()) {
                continue
            }
            
            let name = (info["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let gaiaName = (info["gaia_name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let effectiveName = !name.isEmpty ? name : (!gaiaName.isEmpty ? gaiaName : (email.components(separatedBy: "@").first ?? "Profile"))
            
            let picName = info["gaia_picture_file_name"] as? String ?? "Google Profile Picture.png"
            let picPath = "\(chromeBase)/\(folder)/\(picName)"
            let url = info["last_downloaded_gaia_picture_url_with_size"] as? String
            let validPath = FileManager.default.fileExists(atPath: picPath) ? picPath : nil
            
            results.append((name: effectiveName, email: email, profileFolder: folder, avatarLocalPath: validPath, avatarURL: url))
        }
        
        return results.sorted { $0.name < $1.name }
    }
}
