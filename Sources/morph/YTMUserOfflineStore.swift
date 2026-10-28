import Foundation

/// Persistent offline cache storing the user's actual YouTube Music tracks.
/// Whenever the user listens to music, loads playlists (e.g. Liked Music), or receives
/// algorithmic recommendations, tracks are automatically cached here so they are
/// instantly available for zero-latency offline playback when disconnected from Wi-Fi.
public final class YTMUserOfflineStore: @unchecked Sendable {
    public static let shared = YTMUserOfflineStore()
    
    private let userDefaultsKey = "com.morph.ytm_user_offline_tracks"
    private let queue = DispatchQueue(label: "com.morph.ytm.offline_store", qos: .utility)
    private let maxCachedTracks = 100
    
    public init() {}
    
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
    
    /// Clears cached offline tracks (useful for unit testing).
    public func clear() {
        queue.sync {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        }
    }
}
