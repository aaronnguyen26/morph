import Foundation
import AppKit
import MediaPlayer
import Combine

/// Manages macOS system-wide Now Playing integration and remote playback commands
/// (MPRemoteCommandCenter and MPNowPlayingInfoCenter) matching Spotify, Apple Music, and YouTube Music.
/// Enables hardware media keys (F7, F8, F9), Control Center Now Playing, lock screen controls,
/// Touch Bar, AirPods / Bluetooth headphone controls, and Apple Watch playback sync.
@MainActor
public final class NowPlayingManager: NSObject, ObservableObject {
    public static let shared = NowPlayingManager()
    
    public weak var media: MediaControllerModel?
    private var cancellables = Set<AnyCancellable>()
    private var isConfigured = false
    
    /// Thread-safe immutable artwork payload cached by URL so `MPMediaItemArtwork` handlers
    /// can decode fresh `NSImage` instances safely on `MediaPlayer`'s background queues.
    public final class CachedArtwork: NSObject, @unchecked Sendable {
        public let data: Data
        public let size: NSSize
        
        public init(data: Data, size: NSSize) {
            self.data = data
            self.size = (size.width > 0 && size.height > 0) ? size : NSSize(width: 512, height: 512)
            super.init()
        }
    }
    
    public override init() {
        super.init()
    }
    
    public func configure(media: MediaControllerModel) {
        self.media = media
        guard !isConfigured else { return }
        isConfigured = true
        
        setupRemoteCommands()
        setupNowPlayingObservers()
    }
    
    // MARK: - MPRemoteCommandCenter Registration
    private func setupRemoteCommands() {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        Self.registerRemoteCommands(for: self)
    }
    
    /// Registered from a `nonisolated` context so Objective-C command blocks never inherit
    /// `@MainActor` runtime executor assertions (`swift_task_isCurrentExecutor`) under Swift 6.
    nonisolated private static func registerRemoteCommands(for manager: NowPlayingManager) {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // 1. Play / Pause / Toggle
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in
                ShortcutManager.shared.performTogglePlayPause(fromRemoteCommand: true)
            }
            return .success
        }
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            Task { @MainActor in
                ShortcutManager.shared.performPlayMusic(fromRemoteCommand: true)
            }
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            Task { @MainActor in
                ShortcutManager.shared.performPauseMusic(fromRemoteCommand: true)
            }
            return .success
        }
        
        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget { [weak manager] _ in
            Task { @MainActor [weak manager] in
                ShortcutManager.shared.performPauseMusic(fromRemoteCommand: true)
                manager?.media?.stop()
            }
            return .success
        }
        
        // 2. Next Track (F9 / Skip)
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { _ in
            Task { @MainActor in
                ShortcutManager.shared.nextTrack()
            }
            return .success
        }
        
        // 3. Previous Track (F7 / Rewind / Restart)
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { _ in
            Task { @MainActor in
                ShortcutManager.shared.prevTrack()
            }
            return .success
        }
        
        // 4. Scrubber / Position Seeking
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak manager] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let positionTime = posEvent.positionTime
            Task { @MainActor [weak manager] in
                manager?.media?.seek(toSeconds: positionTime)
            }
            return .success
        }
        
        // 5. Like / Favorite Track
        commandCenter.likeCommand.isEnabled = true
        commandCenter.likeCommand.isActive = false
        commandCenter.likeCommand.addTarget { [weak manager] _ in
            Task { @MainActor [weak manager] in
                manager?.media?.toggleLike()
            }
            return .success
        }
        
        // 6. Dislike Track
        commandCenter.dislikeCommand.isEnabled = true
        commandCenter.dislikeCommand.isActive = false
        commandCenter.dislikeCommand.addTarget { [weak manager] _ in
            Task { @MainActor [weak manager] in
                manager?.media?.toggleDislike()
            }
            return .success
        }
    }
    
    private var pendingArtworkURLString: String?
    private var inFlightArtworkURLString: String?
    private var failedArtworkURLs: Set<String> = []
    private var artworkLoadTask: Task<Void, Never>?
    private var isNowPlayingUpdateScheduled: Bool = false
    
    // MARK: - Now Playing Info Center Synchronization
    private func scheduleNowPlayingUpdate() {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        guard !isNowPlayingUpdateScheduled else { return }
        isNowPlayingUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isNowPlayingUpdateScheduled = false
            self.updateNowPlayingInfo()
        }
    }
    
    private func setupNowPlayingObservers() {
        guard let media = media else { return }
        
        // Synchronize on track metadata changes (scheduled asynchronously past Combine @Published willSet)
        Publishers.CombineLatest4(
            media.$trackTitle,
            media.$artistName,
            media.$duration,
            media.$isPlaying
        )
        .sink { [weak self] _ in
            self?.scheduleNowPlayingUpdate()
        }
        .store(in: &cancellables)
        
        media.$currentTime
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.scheduleNowPlayingUpdate()
            }
            .store(in: &cancellables)
            
        media.$albumArtURL
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.scheduleNowPlayingUpdate()
            }
            .store(in: &cancellables)
            
        media.engine.$trackData
            .sink { [weak self] _ in
                self?.scheduleNowPlayingUpdate()
            }
            .store(in: &cancellables)
            
        media.$isLiked
            .sink { [weak self] _ in
                guard !MorphEnvironment.isTestingEnvironment else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let media = self.media else { return }
                    MPRemoteCommandCenter.shared().likeCommand.isActive = media.isLiked
                }
            }
            .store(in: &cancellables)
            
        media.$isDisliked
            .sink { [weak self] _ in
                guard !MorphEnvironment.isTestingEnvironment else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let media = self.media else { return }
                    MPRemoteCommandCenter.shared().dislikeCommand.isActive = media.isDisliked
                }
            }
            .store(in: &cancellables)
    }
    
    /// Updates the macOS Now Playing Info dictionary for Control Center, Lock Screen, and Media Keys.
    public func updateNowPlayingInfo() {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        guard let media = media else { return }
        
        let isPlaying = media.isEffectivelyPlaying
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        
        let rawTitle = media.trackTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveTitle: String
        if !rawTitle.isEmpty {
            effectiveTitle = rawTitle
        } else if isPlaying {
            effectiveTitle = "YouTube Music"
        } else {
            effectiveTitle = ""
        }
        
        guard !effectiveTitle.isEmpty else {
            pendingArtworkURLString = nil
            inFlightArtworkURLString = nil
            artworkLoadTask?.cancel()
            artworkLoadTask = nil
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            MPNowPlayingInfoCenter.default().playbackState = .stopped
            return
        }
        
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = effectiveTitle
        info[MPMediaItemPropertyArtist] = media.artistName.isEmpty ? "Morph Music" : media.artistName
        info[MPMediaItemPropertyPlaybackDuration] = media.duration > 0 ? media.duration : 180.0
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = media.currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        info[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        
        // Artwork handling: attach cached artwork synchronously BEFORE assigning nowPlayingInfo,
        // using a strictly nonisolated requestHandler so MediaPlayer background queues never trap.
        if let artStr = media.albumArtURL, let artURL = URL(string: artStr) {
            if pendingArtworkURLString != artStr {
                failedArtworkURLs.remove(artStr)
            }
            pendingArtworkURLString = artStr
            if let cached = artworkCache.object(forKey: artURL as NSURL) {
                info[MPMediaItemPropertyArtwork] = Self.makeArtwork(data: cached.data, size: cached.size)
            } else if !failedArtworkURLs.contains(artStr) {
                startArtworkLoadIfNeeded(from: artURL, expectedURLString: artStr)
            }
        } else {
            pendingArtworkURLString = nil
            inFlightArtworkURLString = nil
            artworkLoadTask?.cancel()
            artworkLoadTask = nil
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    /// Constructs an `MPMediaItemArtwork` whose request handler is `nonisolated`, ensuring Swift 6
    /// does not insert a `@MainActor` executor check that traps on `MediaPlayer`'s `*/accessQueue`.
    nonisolated public static func makeArtwork(data: Data, size: NSSize = NSSize(width: 512, height: 512)) -> MPMediaItemArtwork {
        let validSize = (size.width > 0 && size.height > 0) ? size : NSSize(width: 512, height: 512)
        return MPMediaItemArtwork(boundsSize: validSize) { requestedSize in
            if let decoded = NSImage(data: data) {
                return decoded
            }
            let fallbackSize = (requestedSize.width > 0 && requestedSize.height > 0) ? requestedSize : validSize
            return NSImage(size: fallbackSize)
        }
    }
    
    nonisolated(unsafe) private let artworkCache = NSCache<NSURL, CachedArtwork>()
    
    private func startArtworkLoadIfNeeded(from url: URL, expectedURLString: String) {
        if inFlightArtworkURLString == expectedURLString, artworkLoadTask != nil {
            return
        }
        
        artworkLoadTask?.cancel()
        inFlightArtworkURLString = expectedURLString
        
        artworkLoadTask = Task { [weak self] in
            let cached = await Self.fetchArtworkPayload(from: url)
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                if self.inFlightArtworkURLString == expectedURLString {
                    self.inFlightArtworkURLString = nil
                    self.artworkLoadTask = nil
                }
                guard !Task.isCancelled else { return }
                guard let cached = cached else {
                    if self.failedArtworkURLs.count > 64 {
                        self.failedArtworkURLs.removeAll()
                    }
                    self.failedArtworkURLs.insert(expectedURLString)
                    return
                }
                self.artworkCache.setObject(cached, forKey: url as NSURL)
                guard self.media?.albumArtURL == expectedURLString,
                      self.pendingArtworkURLString == expectedURLString else { return }
                self.updateNowPlayingInfo()
            }
        }
    }
    
    nonisolated private static func fetchArtworkPayload(from url: URL) async -> CachedArtwork? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard !Task.isCancelled, !data.isEmpty, let image = NSImage(data: data) else {
                return nil
            }
            return CachedArtwork(data: data, size: image.size)
        } catch {
            return nil
        }
    }
}
