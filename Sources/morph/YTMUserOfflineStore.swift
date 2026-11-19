import Foundation

/// Persistent offline cache storing the user's actual YouTube Music tracks.
/// Whenever the user listens to music, loads playlists (e.g. Liked Music), or receives
/// algorithmic recommendations, tracks are automatically cached here so they are
/// instantly available for zero-latency offline playback when disconnected from Wi-Fi.
public final class YTMUserOfflineStore: @unchecked Sendable {
    public static let shared = YTMUserOfflineStore()
    
    private let userDefaultsKey = "com.morph.ytm_user_offline_tracks"
    private let userPlaylistsBaseKey = "com.morph.ytm_user_library_playlists"
    private let queue = DispatchQueue(label: "com.morph.ytm.offline_store", qos: .utility)
    private let maxCachedTracks = 100
    
    public init() {}
    
    private func playlistsStorageKey(for userEmail: String?) -> String {
        guard let email = userEmail?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !email.isEmpty else {
            return userPlaylistsBaseKey
        }
        return "\(userPlaylistsBaseKey)_\(email)"
    }
    
    /// Validates whether a playlist item represents an actual user playlist (not an individual song, radio, album, or podcast).
    public static func isActualUserPlaylist(_ pl: YTMPlaylist) -> Bool {
        let id = pl.id
        if id == "pl_queue" || id == "pl_quickpicks" { return false }
        let cleanId = id.hasPrefix("VL") ? String(id.dropFirst(2)) : id
        if cleanId.hasPrefix("RD") || cleanId.hasPrefix("MPRE") || cleanId.hasPrefix("OLAK") { return false }
        let sub = pl.subtitle.lowercased()
        if sub.contains("podcast") || sub.contains("episode") || sub.contains("show") { return false }
        let title = pl.title.lowercased()
        if title.contains("podcast") || title.contains("episode") { return false }
        return id.hasPrefix("PL") || id == "LM" || id == "LL" || id == "WL" || id.hasPrefix("VLPL") || id == "VLLM" || id.hasPrefix("VL") || id.hasPrefix("FL") || pl.kind == .playlist
    }
    
    /// Retrieves all stored library playlists for the specified user or current session.
    public func getStoredPlaylists(for userEmail: String? = nil) -> [YTMPlaylist] {
        return queue.sync {
            let key = playlistsStorageKey(for: userEmail)
            if let data = UserDefaults.standard.data(forKey: key),
               let items = try? JSONDecoder().decode([YTMPlaylist].self, from: data) {
                let valid = items.filter { Self.isActualUserPlaylist($0) }
                if !valid.isEmpty { return valid }
            }
            // Only fall back to base key if no specific user email was provided
            if userEmail == nil || userEmail?.isEmpty == true {
                if let data = UserDefaults.standard.data(forKey: userPlaylistsBaseKey),
                   let items = try? JSONDecoder().decode([YTMPlaylist].self, from: data) {
                    let valid = items.filter { Self.isActualUserPlaylist($0) }
                    if !valid.isEmpty { return valid }
                }
            }
            return []
        }
    }
    
    /// Persists the user's library playlists fetched from the music provider.
    public func savePlaylists(_ playlists: [YTMPlaylist], for userEmail: String? = nil) {
        let cleanPlaylists = playlists.filter { Self.isActualUserPlaylist($0) }
        guard !cleanPlaylists.isEmpty else { return }
        queue.sync {
            let key = playlistsStorageKey(for: userEmail)
            
            // Merge with existing playlists so already-loaded tracks are not dropped
            var existing: [YTMPlaylist] = []
            if let data = UserDefaults.standard.data(forKey: key),
               let items = try? JSONDecoder().decode([YTMPlaylist].self, from: data) {
                existing = items.filter { Self.isActualUserPlaylist($0) }
            }
            
            // Base on newly fetched cleanPlaylists, enriching with any existing tracks/counts
            var combined: [YTMPlaylist] = []
            for pl in cleanPlaylists {
                var updated = pl
                if let old = existing.first(where: { $0.id == pl.id }) {
                    if updated.tracks.isEmpty && !old.tracks.isEmpty {
                        updated.tracks = old.tracks
                    }
                    if updated.playbackListId == nil {
                        updated.playbackListId = old.playbackListId
                    }
                    if updated.thumbnailURL == nil && old.thumbnailURL != nil {
                        updated.thumbnailURL = old.thumbnailURL
                    }
                    if updated.trackCount == nil && old.trackCount != nil {
                        updated.trackCount = old.trackCount
                    }
                    if updated.playCount == 0 && old.playCount > 0 {
                        updated.playCount = old.playCount
                    }
                    if updated.lastPlayedDate == nil && old.lastPlayedDate != nil {
                        updated.lastPlayedDate = old.lastPlayedDate
                    }
                }
                combined.append(updated)
            }
            
            if let data = try? JSONEncoder().encode(combined) {
                UserDefaults.standard.set(data, forKey: key)
                if let email = userEmail, !email.isEmpty {
                    UserDefaults.standard.set(data, forKey: userPlaylistsBaseKey)
                }
            }
        }
    }
    
    /// Records an interaction or play of a playlist to keep recent activity and play counts accurate.
    public func recordPlaylistUsage(id: String, email: String? = nil) {
        queue.sync {
            let key = playlistsStorageKey(for: email)
            var existing: [YTMPlaylist] = []
            if let data = UserDefaults.standard.data(forKey: key),
               let items = try? JSONDecoder().decode([YTMPlaylist].self, from: data) {
                existing = items
            }
            if let idx = existing.firstIndex(where: { $0.id == id }) {
                existing[idx].playCount += 1
                existing[idx].lastPlayedDate = Date()
                if let data = try? JSONEncoder().encode(existing) {
                    UserDefaults.standard.set(data, forKey: key)
                    if let email = email, !email.isEmpty {
                        UserDefaults.standard.set(data, forKey: userPlaylistsBaseKey)
                    }
                }
            }
        }
    }
    
    /// Sorts playlists by Recent Activity, Most Played, or Alphabetical.
    public static func sortPlaylists(_ list: [YTMPlaylist], mode: LibrarySortMode) -> [YTMPlaylist] {
        switch mode {
        case .recentActivity:
            return list.sorted { a, b in
                if let dateA = a.lastPlayedDate, let dateB = b.lastPlayedDate {
                    if dateA != dateB { return dateA > dateB }
                } else if a.lastPlayedDate != nil {
                    return true
                } else if b.lastPlayedDate != nil {
                    return false
                }
                if a.playCount != b.playCount {
                    return a.playCount > b.playCount
                }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        case .mostPlayed:
            return list.sorted { a, b in
                if a.playCount != b.playCount {
                    return a.playCount > b.playCount
                }
                if let dateA = a.lastPlayedDate, let dateB = b.lastPlayedDate {
                    if dateA != dateB { return dateA > dateB }
                } else if a.lastPlayedDate != nil {
                    return true
                } else if b.lastPlayedDate != nil {
                    return false
                }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
        case .alphabetical:
            return list.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }
    
    /// Retrieves stored playlists sorted according to the requested library sort mode.
    public func getSortedPlaylists(for userEmail: String? = nil, mode: LibrarySortMode = .recentActivity) -> [YTMPlaylist] {
        let list = getStoredPlaylists(for: userEmail)
        return Self.sortPlaylists(list, mode: mode)
    }
    
    /// Saves or updates a single playlist (e.g. after loading its songs).
    public func savePlaylist(_ playlist: YTMPlaylist, for userEmail: String? = nil) {
        savePlaylists([playlist], for: userEmail)
    }
    
    /// Retrieves all cached tracks for a specific playlist.
    public func getStoredTracks(forPlaylist playlistId: String, email: String? = nil) -> [YTMPlaylistItem] {
        let cleanId = playlistId.hasPrefix("VL") ? String(playlistId.dropFirst(2)) : playlistId
        var playlists = getStoredPlaylists(for: email)
        if let found = playlists.first(where: {
            let c = $0.id.hasPrefix("VL") ? String($0.id.dropFirst(2)) : $0.id
            return c == cleanId || $0.id == playlistId
        }), !found.tracks.isEmpty {
            return found.tracks
        }
        if email != nil {
            playlists = getStoredPlaylists(for: nil)
            if let found = playlists.first(where: {
                let c = $0.id.hasPrefix("VL") ? String($0.id.dropFirst(2)) : $0.id
                return c == cleanId || $0.id == playlistId
            }), !found.tracks.isEmpty {
                return found.tracks
            }
        }
        return []
    }
    
    /// Saves loaded tracks directly into a specific playlist in the persistent store.
    public func savePlaylistTracks(_ tracks: [YTMPlaylistItem], forPlaylist playlistId: String, email: String? = nil) {
        guard !tracks.isEmpty else { return }
        queue.sync {
            let key = playlistsStorageKey(for: email)
            var existing: [YTMPlaylist] = []
            if let data = UserDefaults.standard.data(forKey: key),
               let items = try? JSONDecoder().decode([YTMPlaylist].self, from: data) {
                existing = items
            }
            let cleanId = playlistId.hasPrefix("VL") ? String(playlistId.dropFirst(2)) : playlistId
            if let idx = existing.firstIndex(where: {
                let c = $0.id.hasPrefix("VL") ? String($0.id.dropFirst(2)) : $0.id
                return c == cleanId || $0.id == playlistId
            }) {
                existing[idx].tracks = tracks
                existing[idx].trackCount = tracks.count
                if let data = try? JSONEncoder().encode(existing) {
                    UserDefaults.standard.set(data, forKey: key)
                }
            } else {
                let newPl = YTMPlaylist(id: playlistId, title: "Playlist", subtitle: "Playlist", trackCount: tracks.count, tracks: tracks, browseId: "VL\(playlistId)", kind: .playlist)
                existing.append(newPl)
                if let data = try? JSONEncoder().encode(existing) {
                    UserDefaults.standard.set(data, forKey: key)
                }
            }
        }
    }
    
    /// Retrieves all cached YouTube Music tracks of the user.
    public func getOfflineTracks() -> [YTMPlaylistItem] {
        return queue.sync {
            guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
                  let items = try? JSONDecoder().decode([YTMPlaylistItem].self, from: data) else {
                return []
            }
            return items
        }
    }
    
    /// Replaces the offline tracks cache with the provided items.
    public func saveOfflineTracks(_ tracks: [YTMPlaylistItem]) {
        queue.sync {
            let deduplicated = YTMPlaylistItem.deduplicate(tracks)
            let trimmed = Array(deduplicated.prefix(maxCachedTracks))
            if let data = try? JSONEncoder().encode(trimmed) {
                UserDefaults.standard.set(data, forKey: userDefaultsKey)
            }
        }
    }
    
    /// Records an active or played YouTube Music track into the user's offline downloads.
    public func recordTrack(_ track: YTMPlaylistItem) {
        guard !track.title.isEmpty else { return }
        queue.sync {
            var existing = [YTMPlaylistItem]()
            if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
               let items = try? JSONDecoder().decode([YTMPlaylistItem].self, from: data) {
                existing = items
            }
            
            // Move or insert track at the beginning
            existing.removeAll { $0.id == track.id || ($0.title.lowercased() == track.title.lowercased() && $0.artist.lowercased() == track.artist.lowercased()) }
            existing.insert(track, at: 0)
            
            let trimmed = Array(existing.prefix(maxCachedTracks))
            if let data = try? JSONEncoder().encode(trimmed) {
                UserDefaults.standard.set(data, forKey: userDefaultsKey)
            }
        }
    }
    
    /// Batches multiple YouTube Music tracks from the user's queue or library playlists.
    public func recordTracks(_ tracks: [YTMPlaylistItem]) {
        let valid = tracks.filter { !$0.title.isEmpty }
        guard !valid.isEmpty else { return }
        queue.sync {
            var existing = [YTMPlaylistItem]()
            if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
               let items = try? JSONDecoder().decode([YTMPlaylistItem].self, from: data) {
                existing = items
            }
            
            var seen = Set(existing.map { "\($0.title.lowercased())___\($0.artist.lowercased())" })
            for track in valid {
                let key = "\(track.title.lowercased())___\(track.artist.lowercased())"
                if !seen.contains(key) {
                    seen.insert(key)
                    existing.append(track)
                }
            }
            
            let trimmed = Array(existing.prefix(maxCachedTracks))
            if let data = try? JSONEncoder().encode(trimmed) {
                UserDefaults.standard.set(data, forKey: userDefaultsKey)
            }
        }
    }
    
    /// Clears cached offline tracks and playlists (useful for unit testing).
    public func clear(for userEmail: String? = nil) {
        queue.sync {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
            UserDefaults.standard.removeObject(forKey: userPlaylistsBaseKey)
            if let email = userEmail?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !email.isEmpty {
                UserDefaults.standard.removeObject(forKey: "\(userPlaylistsBaseKey)_\(email)")
            } else {
                let dict = UserDefaults.standard.dictionaryRepresentation()
                for key in dict.keys where key.hasPrefix(userPlaylistsBaseKey) {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
        }
    }
}
