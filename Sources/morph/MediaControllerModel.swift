import SwiftUI
import Combine
import Cocoa
import CoreGraphics

public enum YTMRightDeckSection: String, CaseIterable, Identifiable {
    case home = "Home"
    case playlists = "Playlists"
    case queue = "Queue"
    case downloads = "Downloads"
    case search = "Search"
    
    public var id: String { rawValue }
    public var title: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .playlists: return "music.note.list"
        case .queue: return "list.bullet"
        case .downloads: return "arrow.down.circle.fill"
        case .search: return "magnifyingglass"
        }
    }
}

public enum YTMSearchCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case songs = "Songs"
    case videos = "Videos"
    case artists = "Artists"
    case albums = "Albums"
    case playlists = "Playlists"
    
    public var id: String { rawValue }
    
    public var matchingKind: YTMSearchKind? {
        switch self {
        case .all: return nil
        case .songs: return .song
        case .videos: return .video
        case .artists: return .artist
        case .albums: return .album
        case .playlists: return .playlist
        }
    }
}

public enum LibrarySortMode: String, CaseIterable, Identifiable, Codable {
    case recentActivity = "Recent Activity"
    case mostPlayed = "Most Played"
    case alphabetical = "A - Z"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .recentActivity: return "clock.arrow.circlepath"
        case .mostPlayed: return "flame.fill"
        case .alphabetical: return "textformat.abc"
        }
    }
}

@MainActor
public final class MediaControllerModel: ObservableObject {
    @Published public var trackTitle: String = ""
    @Published public var artistName: String = ""
    @Published public var albumArtURL: String? = nil
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: TimeInterval = 0
    @Published public var duration: TimeInterval = 0
    @Published public var volume: Double = 0.8
    @Published public var isMuted: Bool = false
    @Published public var isLiked: Bool = false
    @Published public var isDisliked: Bool = false
    @Published public var isShuffle: Bool = false
    @Published public var repeatMode: YTMRepeatMode = .off
    @Published public var sourceName: String = "YouTube Music Direct"
    @Published public var isDirectEngineConnected: Bool = false
    @Published public var isBrowserConnected: Bool = false
    @Published public var playlist: [YTMPlaylistItem] = []
    @Published public var playlists: [YTMPlaylist] = []
    @Published public var librarySortMode: LibrarySortMode = .recentActivity
    @Published public var quickPicks: [YTMPlaylistItem] = []
    @Published public var isLoadingQuickPicks: Bool = false
    @Published public var quickPicksError: String? = nil
    @Published public var isSignedIn: Bool = false
    @Published public var userEmail: String? = nil
    @Published public var accountTier: YTMAccountTier = .unknown
    @Published public var isAdPlaying: Bool = false
    @Published public var adSuppressedCount: Int = 0
    
    public var isAccountPremium: Bool {
        return accountTier == .premium
    }
    
    public var hasAds: Bool {
        return accountTier.hasAds
    }
    
    @Published public var profiles: [YTMProfile] = []
    @Published public var activeProfile: YTMProfile? = nil
    @Published public var isProfileSwitcherOpen: Bool = false
    @Published public var selectedPlaylist: YTMPlaylist? = nil
    @Published public var rightDeckSection: YTMRightDeckSection = .home
    @Published public var previousRightDeckSection: YTMRightDeckSection = .home
    private var lastPreviousClickTime: Date?
    private var lastSeekToZeroTime: Date?
    @Published public var isSearchingPlaylists: Bool = false
    @Published public var playlistSearchQuery: String = ""
    @Published public var isSearchingSongs: Bool = false
    @Published public var songSearchQuery: String = ""
    @Published public var showVolumeHUD: Bool = false
    private var volumeHUDWorkItem: DispatchWorkItem?
    
    @Published public var showRepeatHUD: Bool = false
    private var repeatHUDWorkItem: DispatchWorkItem?
    private var repeatModeLockoutUntil: Date?
    
    @Published public var showShuffleHUD: Bool = false
    private var shuffleHUDWorkItem: DispatchWorkItem?
    private var shuffleLockoutUntil: Date?
    private var playbackHistory: [YTMPlaylistItem] = []
    private var lastProcessedQueueIds: [String] = []
    private var lastProcessedTrackSignature: String = ""
    private var lastProcessedTrackTitle: String = ""
    @Published public var userIntentionallyPaused: Bool = false
    private var stalledPlaybackCount: Int = 0
    private var lastObservedPlaybackTime: Double? = nil
    public var isTestingSimulation: Bool = false
    
    public struct TargetTrack: Equatable {
        public let title: String
        public let artist: String
        public let videoId: String?
        public let thumbnailURL: String?
        
        public init(title: String, artist: String, videoId: String? = nil, thumbnailURL: String? = nil) {
            self.title = title
            self.artist = artist
            self.videoId = videoId
            self.thumbnailURL = thumbnailURL
        }
    }
    @Published public var pendingTargetTrack: TargetTrack? = nil
    @Published public var trackTransitionLockoutUntil: Date? = nil
    private var stalePreviousTitle: String = ""
    private var lastTrackEndedTime: Date? = nil
    private var playResumeLockoutUntil: Date? = nil
    
    // Offline status & Downloads management
    public let networkMonitor: NetworkMonitor
    @Published public var isOffline: Bool = false
    @Published public var showOfflineHUD: Bool = false
    @Published public var offlineHUDMessage: String = "No Internet Connection"
    private var offlineHUDWorkItem: DispatchWorkItem?
    public var lastOfflineClickTime: Date?
    @Published public var downloadedTracks: [YTMPlaylistItem] = []
    
    // Ambient 3-bar equalizer heights (0.15 ... 1.0)
    @Published public var visualizerBars: [CGFloat] = [0.18, 0.18, 0.18]
    public var isVisualizerActive: Bool = false {
        didSet {
            if oldValue != isVisualizerActive {
                syncVisualizerTimer()
            }
        }
    }
    private var lastScriptableScanTimestamp: TimeInterval = 0
    
    public let engine: YouTubeMusicEngine
    public let systemAudio: SystemAudioServiceProtocol
    
    private var isTestingEnvironment: Bool {
        return MorphEnvironment.isTestingEnvironment
    }
    
    private var cancellables = Set<AnyCancellable>()
    internal var visualizerTimer: AnyCancellable?
    public var isVisualizerTimerRunning: Bool { visualizerTimer != nil }
    private var browserPollTimer: AnyCancellable?
    private var playbackTicker: AnyCancellable?
    
    @Published public var isLoadingPlaylists: Bool = false
    
    // Playlist detail loading + YouTube Music catalog search state
    @Published public var isLoadingTracks: Bool = false
    @Published public var tracksError: String? = nil
    @Published public var libraryError: String? = nil
    @Published public var searchResults: [YTMSearchResult] = []
    @Published public var searchSuggestions: [String] = []
    @Published public var activeSearchCategory: YTMSearchCategory = .all
    @Published public var isSearchingCatalog: Bool = false
    @Published public var catalogSearchError: String? = nil
    @Published public var isWaitingForBrowserSignIn: Bool = false
    @Published public var browserAuthStatusMessage: String? = nil
    private var searchTask: Task<Void, Never>?
    public private(set) var activeCatalogQuery: String = ""
    private var trackLoadTask: Task<Void, Never>?
    
    /// User-centric YouTube Music offline tracks (from the user's actual YouTube Music library and queue).
    public static var defaultOfflineTracks: [YTMPlaylistItem] {
        let cached = YTMUserOfflineStore.shared.getOfflineTracks()
        return cached.isEmpty ? YTMParser.defaultQuickPicks : cached
    }
    
    /// Returns the active sections visible in the right deck.
    /// In normal online mode, shows the normal UI (Home, Playlists, Queue, Search).
    /// When offline, focuses on the user's downloaded YouTube Music tracks.
    public var availableRightDeckSections: [YTMRightDeckSection] {
        if isOffline {
            return [.downloads]
        } else {
            return [.home, .playlists, .queue, .search]
        }
    }
    
    @MainActor
    public init(
        engine customEngine: YouTubeMusicEngine? = nil,
        systemAudio customAudio: SystemAudioServiceProtocol? = nil,
        networkMonitor customMonitor: NetworkMonitor? = nil
    ) {
        let engine = customEngine ?? YouTubeMusicEngine.shared
        let systemAudio = customAudio ?? (MorphEnvironment.isTestingEnvironment ? MockSystemAudioService() : SystemAudioService.shared)
        let networkMonitor = customMonitor ?? NetworkMonitor.shared
        
        self.engine = engine
        self.systemAudio = systemAudio
        self.networkMonitor = networkMonitor
        self.isOffline = !networkMonitor.isConnected
        
        let initialCached = YTMUserOfflineStore.shared.getOfflineTracks()
        if !initialCached.isEmpty && !MorphEnvironment.isTestingEnvironment {
            self.downloadedTracks = initialCached
        } else {
            let seed = engine.quickPicks.isEmpty ? YTMParser.defaultQuickPicks : engine.quickPicks
            self.downloadedTracks = seed
            if !MorphEnvironment.isTestingEnvironment {
                YTMUserOfflineStore.shared.recordTracks(seed)
            }
        }
        
        let initialProfile = YTMProfileManager.shared.activeProfile
        self.activeProfile = initialProfile
        if let mail = initialProfile?.email, !mail.isEmpty {
            self.userEmail = mail
        } else if let mail = engine.userEmail, !mail.isEmpty {
            self.userEmail = mail
        }
        if let tier = initialProfile?.accountTier, tier != .unknown {
            self.accountTier = tier
        } else if engine.accountTier != .unknown {
            self.accountTier = engine.accountTier
        }
        
        let storedPlaylists = YTMUserOfflineStore.shared.getStoredPlaylists(for: self.userEmail)
        if !storedPlaylists.isEmpty {
            self.playlists = storedPlaylists
        } else if !engine.userPlaylists.isEmpty {
            self.playlists = engine.userPlaylists
        } else {
            self.playlists = []
        }
        self.quickPicks = engine.quickPicks.isEmpty ? YTMParser.defaultQuickPicks : engine.quickPicks
        self.rightDeckSection = self.isOffline ? .downloads : .home
        
        let initialVol = systemAudio.getVolume()
        let initialMuted = systemAudio.getMuted()
        self.volume = max(0.0, min(1.0, initialVol))
        self.isMuted = initialMuted
        
        setupEngineObservers()
        setupSystemAudioObserver()
        setupNetworkObserver()
        
        Publishers.CombineLatest($isPlaying, $isMuted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncVisualizerTimer()
            }
            .store(in: &cancellables)
            
        if !isTestingEnvironment {
            startVisualizer()
            startPlaybackTicker()
            startBrowserPolling()
            systemAudio.startMonitoring()
            if isDirectEngineActive {
                engine.setVolume(self.volume)
                if self.isMuted {
                    engine.setMuted(true)
                }
            }
        }
    }
    
    private func startPlaybackTicker() {
        playbackTicker = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isPlaying, !self.userIntentionallyPaused else { return }
                    // Smoothly advance progress bar hand-in-hand with playback
                    if self.duration > 0 && self.currentTime < self.duration {
                        self.currentTime += 1.0
                    }
                }
            }
    }
    
    public var isDirectEngineActive: Bool {
        return !engine.trackData.title.isEmpty && engine.trackData.title != "YouTube Music" && engine.trackData.duration > 0
    }
    
    /// Native macOS Hardware Media Key Event Dispatcher (NX_KEYTYPE_PLAY = 16, NX_KEYTYPE_FAST = 19, NX_KEYTYPE_REWIND = 20)
    /// Directs playback control to macOS Now Playing audio daemon natively without requiring browser AppleScript JS permissions
    public static func postSystemMediaKey(key: Int32) {
        guard !ProcessInfo.processInfo.processName.contains("xctest") else { return }
        func postKeyEvent(down: Bool) {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
            let data1 = Int((key << 16) | (down ? 0xa00 : 0xb00))
            let ev = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            if let cgEv = ev?.cgEvent {
                cgEv.post(tap: .cghidEventTap)
            }
        }
        postKeyEvent(down: true)
        postKeyEvent(down: false)
    }

    private func setupEngineObservers() {
        // Observe direct WebKit engine track updates synchronously on MainActor
        engine.$trackData
            .sink { [weak self] data in
                guard let self = self else { return }
                
                if data.accountTier != .unknown && self.accountTier != data.accountTier {
                    self.accountTier = data.accountTier
                }
                self.isAdPlaying = data.isAdPlaying
                self.adSuppressedCount = data.adSuppressedCount
                
                // Zero-Ad Guarantee: If an advertisement is actively playing, protect the displayed song title and artist!
                if data.isAdPlaying {
                    return
                }
                
                // If YouTube Music is playing or has track data, prioritize direct engine
                if !data.title.isEmpty && data.title != "YouTube Music" && data.duration > 0 {
                    let dataTitleNorm = Self.normalizeTitle(data.title)
                    
                    // Exact Track Starting Lockout: prevent stale WebKit updates from previous song from overwriting new track
                    if let lockout = self.trackTransitionLockoutUntil, Date() < lockout {
                        if !self.stalePreviousTitle.isEmpty && dataTitleNorm == self.stalePreviousTitle {
                            // Stale update from prior track: ignore
                            return
                        }
                    }
                    self.trackTransitionLockoutUntil = nil
                    self.stalePreviousTitle = ""
                    self.pendingTargetTrack = nil
                    
                    let wasPlaying = self.isPlaying
                    self.trackTitle = data.title
                    self.artistName = data.artist.isEmpty ? "YouTube Music" : data.artist
                    if let art = data.albumArtURL, !art.isEmpty {
                        self.albumArtURL = art
                    }
                    if self.userIntentionallyPaused {
                        self.playResumeLockoutUntil = nil
                        self.isPlaying = false
                        if data.isPlaying {
                            let eng = self.engine
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self, self.userIntentionallyPaused, eng.trackData.isPlaying else { return }
                                eng.pause()
                            }
                        }
                    } else if data.isPlaying {
                        self.isPlaying = true
                    } else if let lockout = self.playResumeLockoutUntil, Date() < lockout {
                        // Hold resumed UI state and nudge WebKit out of offscreen buffering/suspension while unpausing settles
                        self.isPlaying = true
                        if !self.isTestingEnvironment || self.isTestingSimulation {
                            let eng = self.engine
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self, !self.userIntentionallyPaused, let activeLock = self.playResumeLockoutUntil, Date() < activeLock else { return }
                                eng.ensurePlayback()
                            }
                        }
                    } else {
                        self.playResumeLockoutUntil = nil
                        self.isPlaying = false
                    }
                    if let seekTime = self.lastSeekToZeroTime, Date().timeIntervalSince(seekTime) < 1.5 {
                        // In-flight seek-to-zero lockout: protect against stale updates
                        if data.currentTime > 3.0 && !self.stalePreviousTitle.isEmpty && Self.normalizeTitle(data.title) == self.stalePreviousTitle {
                            // ignore stale pre-seek currentTime from previous track
                        } else {
                            if data.currentTime > 0 {
                                self.currentTime = data.currentTime
                            }
                            if data.currentTime > 0.05 {
                                self.lastSeekToZeroTime = nil
                            }
                        }
                    } else {
                        if data.currentTime > 0 {
                            self.currentTime = data.currentTime
                        }
                    }
                    if data.duration > 0 {
                        self.duration = data.duration
                    }
                    
                    // Stalled playback watchdog: if playing and has duration, but currentTime remains frozen at 0:
                    if !self.userIntentionallyPaused && data.isPlaying && data.duration > 0 {
                        if data.currentTime <= 0.05 && self.lastObservedPlaybackTime != nil && self.lastObservedPlaybackTime! <= 0.05 {
                            self.stalledPlaybackCount += 1
                            if self.stalledPlaybackCount >= 6 && (!self.isTestingEnvironment || self.isTestingSimulation) {
                                self.engine.ensurePlayback()
                            }
                        } else {
                            self.stalledPlaybackCount = 0
                            self.lastObservedPlaybackTime = data.currentTime
                        }
                    } else {
                        self.stalledPlaybackCount = 0
                        self.lastObservedPlaybackTime = nil
                    }
                    
                    // Auto-correct YouTube Music player if web player drifted from the correlated volume
                    let isIncomingDirectActive = !data.title.isEmpty && data.title != "YouTube Music" && data.duration > 0
                    if abs(data.volume - self.volume) > 0.08 && !self.isTestingEnvironment && data.duration > 0 {
                        if isIncomingDirectActive {
                            self.engine.setVolume(self.volume)
                        }
                    }
                    if data.isMuted != self.isMuted && !self.isTestingEnvironment && data.duration > 0 {
                        if isIncomingDirectActive {
                            self.engine.setMuted(self.isMuted)
                        }
                    }
                    self.isLiked = data.isLiked
                    self.isDisliked = data.isDisliked
                    if let lockout = self.shuffleLockoutUntil, Date() < lockout {
                        // Preserve optimistic isShuffle state
                    } else {
                        self.isShuffle = data.isShuffle
                    }
                    if let lockout = self.repeatModeLockoutUntil, Date() < lockout {
                        // Preserve optimistic repeatMode state
                    } else {
                        self.repeatMode = data.repeatMode
                    }
                    
                    let newQueueIds = data.queue.map(\.id)
                    let queueChanged = (newQueueIds != self.lastProcessedQueueIds)
                    if queueChanged {
                        self.lastProcessedQueueIds = newQueueIds
                        self.playlist = YTMPlaylistItem.deduplicate(data.queue)
                        YTMUserOfflineStore.shared.recordTracks(self.playlist)
                    }
                    self.sourceName = "YouTube Music Direct"
                    self.isDirectEngineConnected = self.engine.isSignedIn || (!data.title.isEmpty && data.title != "YouTube Music" && data.duration > 0) || data.isPlaying
                    
                    let trackTitleChanged = (!self.lastProcessedTrackTitle.isEmpty && data.title != self.lastProcessedTrackTitle)
                    self.lastProcessedTrackTitle = data.title
                    
                    // Reset stall counter when the track title changes so the new song gets a fresh window
                    if trackTitleChanged {
                        self.stalledPlaybackCount = 0
                        self.lastObservedPlaybackTime = nil
                        self.currentTime = data.currentTime
                    }
                    
                    let currentSignature = "\(data.title)|\(data.artist)|\(data.isPlaying)"
                    let trackChanged = (currentSignature != self.lastProcessedTrackSignature)
                    if queueChanged || trackChanged {
                        // Watchdog: If previous state was playing and new track loaded in paused state at 0s, nudge playback.
                        // Guarded: Must be an actual track change (not a play/pause toggle), currentTime <= 1.0, and user did NOT intentionally pause!
                        // We defer by 0.8s to give YTM's own player a chance to auto-advance before Morph intervenes.
                        if wasPlaying && !data.isPlaying && data.currentTime <= 1.0 && data.duration > 0 && trackTitleChanged && !self.userIntentionallyPaused && !self.isTestingEnvironment {
                            let eng = self.engine
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                                guard let self = self, !self.userIntentionallyPaused, !eng.trackData.isPlaying else { return }
                                eng.ensurePlayback()
                            }
                        }
                        self.lastProcessedTrackSignature = currentSignature
                        self.syncPlayingTrackWithPlaylists()
                        
                        let matchedVideoId = self.playlist.first(where: { $0.title == data.title })?.videoId
                        let currentItem = YTMPlaylistItem(
                            id: "ytm_\(data.title)_\(data.artist)",
                            title: data.title,
                            artist: data.artist,
                            duration: self.formatTime(data.duration),
                            isPlaying: data.isPlaying,
                            videoId: matchedVideoId,
                            thumbnailURL: data.albumArtURL
                        )
                        YTMUserOfflineStore.shared.recordTrack(currentItem)
                    }
                }
                
                let prevSignedIn = self.isSignedIn
                self.isSignedIn = data.isSignedIn || self.engine.isSignedIn
                
                // If user just transitioned to signed in, automatically refresh playlists
                if self.isSignedIn && !prevSignedIn && self.playlists.isEmpty {
                    self.refreshPlaylists()
                }
                
                if !data.playlists.isEmpty {
                    self.mergePlaylists(data.playlists)
                }
                
                // Only the live "Now Playing Queue" mirrors the player's queue. Real playlists, albums and
                // artists get their tracks from InnerTube (previously the queue overwrote every opened playlist).
                if let sel = self.selectedPlaylist, sel.id == "pl_queue", !data.queue.isEmpty {
                    var updated = sel
                    updated.tracks = self.playlist
                    self.selectedPlaylist = updated
                    self.syncPlayingTrackWithPlaylists()
                }
            }
            .store(in: &cancellables)
            
        engine.$isSignedIn
            .sink { [weak self] signedIn in
                guard let self = self else { return }
                let prev = self.isSignedIn
                self.isSignedIn = signedIn
                if signedIn && !prev {
                    self.isWaitingForBrowserSignIn = false
                    self.browserAuthStatusMessage = nil
                    self.libraryError = nil
                    self.refreshPlaylists()
                    self.refreshQuickPicks()
                } else if !signedIn {
                    self.userEmail = nil
                }
            }
            .store(in: &cancellables)
            
        engine.$userEmail
            .receive(on: DispatchQueue.main)
            .sink { [weak self] email in
                guard let self = self else { return }
                let oldEmail = self.userEmail
                self.userEmail = email
                if let email = email, !email.isEmpty, email != oldEmail {
                    let cached = YTMUserOfflineStore.shared.getStoredPlaylists(for: email)
                    if !cached.isEmpty {
                        self.playlists = cached
                    }
                    if self.isSignedIn {
                        self.refreshPlaylists()
                    }
                }
            }
            .store(in: &cancellables)
            
        engine.$accountTier
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tier in
                guard let self = self else { return }
                if tier != .unknown && self.accountTier != tier {
                    self.accountTier = tier
                }
            }
            .store(in: &cancellables)
            
        engine.$isAdPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAd in
                guard let self = self else { return }
                self.isAdPlaying = isAd
            }
            .store(in: &cancellables)
            
        engine.$adSuppressedCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                guard let self = self else { return }
                self.adSuppressedCount = count
            }
            .store(in: &cancellables)
            
        self.profiles = YTMProfileManager.shared.profiles
        self.activeProfile = YTMProfileManager.shared.activeProfile
        
        YTMProfileManager.shared.$profiles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] profs in
                guard let self = self else { return }
                self.profiles = profs
                self.activeProfile = YTMProfileManager.shared.activeProfile
            }
            .store(in: &cancellables)
            
        YTMProfileManager.shared.$activeProfileId
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.activeProfile = YTMProfileManager.shared.activeProfile
                if let email = self.activeProfile?.email, !email.isEmpty {
                    let oldEmail = self.userEmail
                    self.userEmail = email
                    if email != oldEmail {
                        let cached = YTMUserOfflineStore.shared.getStoredPlaylists(for: email)
                        if !cached.isEmpty {
                            self.playlists = cached
                        }
                        if self.isSignedIn {
                            self.refreshPlaylists()
                        }
                    }
                }
            }
            .store(in: &cancellables)
            
        engine.$userPlaylists
            .sink { [weak self] enginePlaylists in
                guard let self = self, !enginePlaylists.isEmpty else { return }
                self.mergePlaylists(enginePlaylists)
            }
            .store(in: &cancellables)
            
        engine.$quickPicks
            .sink { [weak self] picks in
                guard let self = self else { return }
                if !picks.isEmpty {
                    // Only replace quickPicks if the content actually changed (by videoId fingerprint),
                    // preventing SwiftUI from re-rendering the entire list on every 1-second DOM poll.
                    let newIds = picks.map { $0.videoId ?? $0.id }
                    let oldIds = self.quickPicks.map { $0.videoId ?? $0.id }
                    if newIds != oldIds {
                        self.quickPicks = picks
                    }
                } else if self.quickPicks.isEmpty {
                    self.quickPicks = YTMParser.defaultQuickPicks
                }
            }
            .store(in: &cancellables)
            
        engine.$isLoadingQuickPicks
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoadingQuickPicks)
        
        engine.$libraryError
            .sink { [weak self] err in self?.libraryError = err }
            .store(in: &cancellables)
        
        // Debounced YouTube Music catalog search driven by the playlist search field.
        $playlistSearchQuery
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                self?.runCatalogSearch(query)
            }
            .store(in: &cancellables)
            
        // Observe direct WebKit track completion to drive continuous sequential playlist playback
        engine.trackEndedPublisher
            .sink { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handleTrackEnded()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Returns strictly user-owned or saved playlists (excluding individual songs, radios, or albums)
    public var userLibraryPlaylists: [YTMPlaylist] {
        return playlists.filter { YTMUserOfflineStore.isActualUserPlaylist($0) }
    }
    
    /// Returns user library playlists sorted according to `librarySortMode`.
    public var sortedUserLibraryPlaylists: [YTMPlaylist] {
        return YTMUserOfflineStore.sortPlaylists(userLibraryPlaylists, mode: librarySortMode)
    }
    
    /// Records an interaction or play of a playlist to keep recent activity and play counts accurate.
    public func recordPlaylistUsage(for playlistId: String) {
        if let idx = playlists.firstIndex(where: { $0.id == playlistId }) {
            playlists[idx].playCount += 1
            playlists[idx].lastPlayedDate = Date()
        }
        if selectedPlaylist?.id == playlistId {
            selectedPlaylist?.playCount = (selectedPlaylist?.playCount ?? 0) + 1
            selectedPlaylist?.lastPlayedDate = Date()
        }
        YTMUserOfflineStore.shared.recordPlaylistUsage(id: playlistId, email: userEmail ?? activeProfile?.email)
    }
    
    /// Merges incoming playlists by id, keeping any tracks that were already loaded.
    func mergePlaylists(_ incoming: [YTMPlaylist]) {
        let cleanIncoming = incoming.filter { YTMUserOfflineStore.isActualUserPlaylist($0) }
        var merged = playlists.filter { YTMUserOfflineStore.isActualUserPlaylist($0) }
        for ep in cleanIncoming {
            let epClean = ep.id.hasPrefix("VL") ? String(ep.id.dropFirst(2)) : ep.id
            if let idx = merged.firstIndex(where: {
                let mClean = $0.id.hasPrefix("VL") ? String($0.id.dropFirst(2)) : $0.id
                return mClean == epClean || $0.id == ep.id
            }) {
                var updated = ep
                if updated.tracks.isEmpty { updated.tracks = merged[idx].tracks }
                if updated.playbackListId == nil { updated.playbackListId = merged[idx].playbackListId }
                if updated.thumbnailURL == nil && merged[idx].thumbnailURL != nil {
                    updated.thumbnailURL = merged[idx].thumbnailURL
                }
                if updated.playCount == 0 && merged[idx].playCount > 0 {
                    updated.playCount = merged[idx].playCount
                }
                if updated.lastPlayedDate == nil && merged[idx].lastPlayedDate != nil {
                    updated.lastPlayedDate = merged[idx].lastPlayedDate
                }
                if updated.trackCount == nil && merged[idx].trackCount != nil {
                    updated.trackCount = merged[idx].trackCount
                }
                merged[idx] = updated
            } else {
                merged.append(ep)
            }
        }
        playlists = merged
        YTMUserOfflineStore.shared.savePlaylists(merged, for: userEmail)
    }
    
    public var formattedCurrentTime: String {
        formatTime(currentTime)
    }
    
    public var formattedDuration: String {
        formatTime(duration)
    }
    
    public var progress: Double {
        guard duration > 0 else { return 0 }
        return max(0, min(1, currentTime / duration))
    }
    
    public func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    public var isEffectivelyPlaying: Bool {
        if userIntentionallyPaused {
            return false
        }
        return isPlaying || engine.trackData.isPlaying
    }
    
    private var lastPlayPauseToggleTime: Date = .distantPast
    
    public func play() {
        userIntentionallyPaused = false
        playResumeLockoutUntil = Date().addingTimeInterval(1.8)
        isPlaying = true
        engine.play()
        engine.setVolume(volume)
        if isMuted {
            engine.setMuted(true)
        }
        if isBrowserConnected && !isDirectEngineActive {
            executeBrowserPlay()
        }
        if !isTestingEnvironment {
            NowPlayingManager.shared.updateNowPlayingInfo()
        }
    }
    
    public func pause() {
        playResumeLockoutUntil = nil
        userIntentionallyPaused = true
        isPlaying = false
        engine.pause()
        if isBrowserConnected && !isDirectEngineActive {
            executeBrowserPause()
        }
        if !isTestingEnvironment {
            NowPlayingManager.shared.updateNowPlayingInfo()
        }
    }
    
    public func stop() {
        playResumeLockoutUntil = nil
        userIntentionallyPaused = true
        isPlaying = false
        currentTime = 0
        engine.stop()
        if isBrowserConnected && !isDirectEngineActive {
            executeBrowserStop()
        }
        if !isTestingEnvironment {
            NowPlayingManager.shared.updateNowPlayingInfo()
        }
    }
    
    public func togglePlay(force: Bool = false) {
        let now = Date()
        if !MorphEnvironment.isTestingEnvironment && !force {
            guard now.timeIntervalSince(lastPlayPauseToggleTime) > 0.3 else { return }
            lastPlayPauseToggleTime = now
        }
        
        if isEffectivelyPlaying {
            pause()
        } else {
            play()
        }
    }
    
    public func togglePlayPause() {
        togglePlay()
    }
    
    public func handleTrackEnded(force: Bool = false) {
        guard (!isTestingEnvironment && !isTestingSimulation) || force else { return }
        
        // Exact Track Guarantee: If a new song was just started, ignore any stale ended event from the previous song!
        if !force, let lockout = trackTransitionLockoutUntil, Date() < lockout {
            return
        }
        
        // Debounce track ended triggers to prevent double advance
        let now = Date()
        if !force, let last = lastTrackEndedTime, now.timeIntervalSince(last) < 1.5 {
            return
        }
        lastTrackEndedTime = now
        
        if repeatMode == .one {
            currentTime = 0
            lastSeekToZeroTime = Date()
            seek(to: 0)
            play()
            return
        }
        nextTrack()
    }
    
    public func nextTrack() {
        currentTime = 0.0
        lastSeekToZeroTime = Date()
        engine.trackData.currentTime = 0.0
        
        // 1. If currently inside an active playlist (and not pl_queue), advance sequentially or randomly through the playlist!
        if let sel = selectedPlaylist, !sel.tracks.isEmpty, sel.id != "pl_queue" {
            let activeId = activeTrackId(in: sel.tracks)
            let count = sel.tracks.count
            if let currentIdx = sel.tracks.firstIndex(where: { $0.isPlaying || ($0.id == activeId && activeId != nil) }) {
                // Record current track into playback history for previousTrack navigation
                if currentIdx < count {
                    playbackHistory.append(sel.tracks[currentIdx])
                }
                
                // Random Next (Shuffle Mode)
                if isShuffle && count > 1 {
                    var randomIdx = Int.random(in: 0..<count)
                    if randomIdx == currentIdx {
                        randomIdx = (randomIdx + 1) % count
                    }
                    let nextItem = sel.tracks[randomIdx]
                    playSongInSelectedPlaylist(nextItem)
                    return
                }
                
                let nextIdx = currentIdx + 1
                if nextIdx < count {
                    let nextItem = sel.tracks[nextIdx]
                    playSongInSelectedPlaylist(nextItem)
                    return
                } else if repeatMode == .all {
                    let firstItem = sel.tracks[0]
                    playSongInSelectedPlaylist(firstItem)
                    return
                } else {
                    stop()
                    return
                }
            }
        }
        
        // 2. Queue playback: if user has a populated queue, advance sequentially or randomly
        if !playlist.isEmpty {
            let activeId = activeTrackId(in: playlist)
            let count = playlist.count
            let currentIdx = playlist.firstIndex(where: { $0.isPlaying || ($0.id == activeId && activeId != nil) }) ?? 0
            
            if currentIdx < count {
                playbackHistory.append(playlist[currentIdx])
            }
            
            // Random Next (Shuffle Mode)
            if isShuffle && count > 1 {
                var randomIdx = Int.random(in: 0..<count)
                if randomIdx == currentIdx {
                    randomIdx = (randomIdx + 1) % count
                }
                let nextItem = playlist[randomIdx]
                if isDirectEngineActive {
                    markPlaying(nextItem)
                    let qIdx = Int(nextItem.id) ?? randomIdx
                    engine.playQueueIndex(qIdx, videoId: nextItem.videoId, title: nextItem.title, artist: nextItem.artist)
                } else {
                    playQueueTrack(nextItem)
                }
                return
            }
            
            let nextIdx = currentIdx + 1
            if nextIdx < count {
                let nextItem = playlist[nextIdx]
                if isDirectEngineActive {
                    markPlaying(nextItem)
                    let qIdx = Int(nextItem.id) ?? nextIdx
                    engine.playQueueIndex(qIdx, videoId: nextItem.videoId, title: nextItem.title, artist: nextItem.artist)
                } else {
                    playQueueTrack(nextItem)
                }
                return
            } else if repeatMode == .all {
                let firstItem = playlist[0]
                if isDirectEngineActive {
                    markPlaying(firstItem)
                    let qIdx = Int(firstItem.id) ?? 0
                    engine.playQueueIndex(qIdx, videoId: firstItem.videoId, title: firstItem.title, artist: firstItem.artist)
                } else {
                    playQueueTrack(firstItem)
                }
                return
            } else {
                stop()
                return
            }
        }

        if isDirectEngineActive || isDirectEngineConnected || !isBrowserConnected {
            engine.nextTrack()
        } else {
            executeBrowserNextTrack()
        }
    }
    
    public func previousTrack() {
        let now = Date()
        let isRapidClick = (lastPreviousClickTime != nil && now.timeIntervalSince(lastPreviousClickTime!) < 2.0)
        lastPreviousClickTime = now
        
        // If track has been playing for more than 3 seconds and this is not an intentional double-click skip, restart current track
        if !isRapidClick && currentTime > 3.0 {
            currentTime = 0.0
            lastSeekToZeroTime = now
            seek(to: 0.0)
            return
        }
        
        // If shuffle is active and history exists, go back to previously played track
        if isShuffle && !playbackHistory.isEmpty {
            let lastTrack = playbackHistory.removeLast()
            if let sel = selectedPlaylist, sel.tracks.contains(where: { $0.id == lastTrack.id }) {
                playSongInSelectedPlaylist(lastTrack)
                return
            } else if playlist.contains(where: { $0.id == lastTrack.id }) {
                markPlaying(lastTrack)
                if isDirectEngineActive {
                    let qIdx = Int(lastTrack.id) ?? 0
                    engine.playQueueIndex(qIdx, videoId: lastTrack.videoId, title: lastTrack.title, artist: lastTrack.artist)
                } else {
                    playQueueTrack(lastTrack)
                }
                return
            }
        }
        
        // Continuous Playback / Direct Queue Backward Advance:
        if let sel = selectedPlaylist, !sel.tracks.isEmpty {
            let activeId = activeTrackId(in: sel.tracks)
            if let currentIdx = sel.tracks.firstIndex(where: { $0.isPlaying || ($0.id == activeId && activeId != nil) }) {
                let prevIdx = currentIdx - 1
                if prevIdx >= 0 {
                    let prevItem = sel.tracks[prevIdx]
                    playSongInSelectedPlaylist(prevItem)
                    return
                } else if repeatMode == .all {
                    let lastItem = sel.tracks[sel.tracks.count - 1]
                    playSongInSelectedPlaylist(lastItem)
                    return
                }
            }
        } else if !playlist.isEmpty {
            let activeId = activeTrackId(in: playlist)
            if let currentIdx = playlist.firstIndex(where: { $0.isPlaying || ($0.id == activeId && activeId != nil) }) {
                let prevIdx = currentIdx - 1
                if prevIdx >= 0 {
                    let prevItem = playlist[prevIdx]
                    markPlaying(prevItem)
                    if isDirectEngineActive {
                        let qIdx = Int(prevItem.id) ?? prevIdx
                        engine.playQueueIndex(qIdx, videoId: prevItem.videoId, title: prevItem.title, artist: prevItem.artist)
                    } else {
                        playQueueTrack(prevItem)
                    }
                    return
                } else if repeatMode == .all {
                    let lastIdx = playlist.count - 1
                    let lastItem = playlist[lastIdx]
                    markPlaying(lastItem)
                    if isDirectEngineActive {
                        let qIdx = Int(lastItem.id) ?? lastIdx
                        engine.playQueueIndex(qIdx, videoId: lastItem.videoId, title: lastItem.title, artist: lastItem.artist)
                    } else {
                        playQueueTrack(lastItem)
                    }
                    return
                }
            }
        }

        if isDirectEngineActive || isDirectEngineConnected || !isBrowserConnected {
            engine.previousTrack(forcePreviousTrack: isRapidClick || currentTime <= 3.0)
        } else {
            executeBrowserPreviousTrack()
            currentTime = 0
        }
    }
    
    public func playQuickVibe(_ vibe: String) {
        if isOffline {
            triggerOfflineHandling(for: vibe)
            return
        }
        userIntentionallyPaused = false
        isPlaying = true
        engine.playVibe(vibe)
    }
    
    public func playVibe(_ vibe: String) {
        playQuickVibe(vibe)
    }
    
    public func playSearch(_ query: String) {
        if isOffline {
            triggerOfflineHandling(for: query)
            return
        }
        userIntentionallyPaused = false
        isPlaying = true
        engine.playSearch(query: query)
    }
    
    public func seek(to progressFraction: Double) {
        let clamped = max(0, min(1, progressFraction))
        currentTime = clamped * duration
        if isDirectEngineActive {
            engine.seek(to: currentTime)
        }
        executeBrowserSeek(to: currentTime)
    }
    
    public func seek(toSeconds seconds: Double) {
        guard duration > 0 else {
            currentTime = max(0, seconds)
            return
        }
        let clamped = max(0, min(duration, seconds))
        seek(to: clamped / duration)
    }
    
    public func seekRelative(deltaSeconds: Double) {
        guard duration > 0 else { return }
        seek(toSeconds: currentTime + deltaSeconds)
    }
    
    public func triggerVolumeHUD() {
        showVolumeHUD = true
        volumeHUDWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.showVolumeHUD = false
            }
        }
        volumeHUDWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }
    
    public func triggerRepeatHUD() {
        showRepeatHUD = true
        repeatHUDWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.showRepeatHUD = false
            }
        }
        repeatHUDWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }
    
    public func triggerShuffleHUD() {
        showShuffleHUD = true
        shuffleHUDWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.showShuffleHUD = false
            }
        }
        shuffleHUDWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }
    
    public func setVolume(_ newVol: Double) {
        guard !newVol.isNaN, !newVol.isInfinite else { return }
        volume = max(0, min(1, newVol))
        if volume > 0 && isMuted {
            isMuted = false
            systemAudio.setMuted(false)
        }
        if isDirectEngineActive {
            engine.setVolume(volume)
        }
        executeBrowserVolume(volume)
        systemAudio.setSystemVolume(volume)
        triggerVolumeHUD()
    }
    
    public func toggleMute() {
        isMuted.toggle()
        if isDirectEngineActive {
            engine.setMuted(isMuted)
        }
        executeBrowserMute(isMuted)
        systemAudio.setMuted(isMuted)
        triggerVolumeHUD()
    }
    
    // MARK: - Laptop System Audio Correlation
    private func setupSystemAudioObserver() {
        systemAudio.onVolumeChanged = { [weak self] newVolume, isMuted in
            self?.handleSystemVolumeChanged(volume: newVolume, isMuted: isMuted)
        }
    }
    
    private func setupNetworkObserver() {
        Publishers.CombineLatest3(networkMonitor.$isConnected, networkMonitor.$isWifiConnected, engine.$isOffline)
            .sink { [weak self] isConnected, isWifiConnected, engineOffline in
                guard let self = self else { return }
                // Detect when user loses internet connectivity (works over Wi-Fi, Ethernet, USB, or VPN)
                let currentlyOffline = !isConnected || (engineOffline && !isConnected)
                let prevOffline = self.isOffline
                self.isOffline = currentlyOffline
                
                if currentlyOffline && !prevOffline {
                    // Refresh downloaded tracks from the user's actual YouTube Music offline store
                    let userTracks = YTMUserOfflineStore.shared.getOfflineTracks()
                    if !userTracks.isEmpty {
                        self.downloadedTracks = userTracks
                    }
                    self.offlineHUDMessage = "Offline • Switched to YouTube Music Downloads"
                    self.showOfflineHUD = true
                    self.offlineHUDWorkItem?.cancel()
                    let work = DispatchWorkItem { [weak self] in
                        self?.showOfflineHUD = false
                    }
                    self.offlineHUDWorkItem = work
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
                    
                    if self.rightDeckSection != .downloads {
                        self.openDownloadsSection()
                    }
                } else if !currentlyOffline && prevOffline {
                    // Reconnected to Wi-Fi / Online: restore normal UI immediately!
                    self.showOfflineHUD = false
                    self.offlineHUDWorkItem?.cancel()
                    if self.rightDeckSection == .downloads {
                        self.openHubHome()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    public func handleSystemVolumeChanged(volume newVol: Double, isMuted newMuted: Bool) {
        let clamped = max(0, min(1, newVol))
        let volChanged = abs(self.volume - clamped) > 0.005
        let muteChanged = self.isMuted != newMuted
        
        guard volChanged || muteChanged else { return }
        
        self.volume = clamped
        self.isMuted = newMuted
        
        // Auto-correct YouTube Music player
        if isDirectEngineActive {
            engine.setVolume(clamped)
            engine.setMuted(newMuted)
        }
        executeBrowserVolume(clamped)
        executeBrowserMute(newMuted)
        triggerVolumeHUD()
    }
    
    public var filteredPlaylists: [YTMPlaylist] {
        let base = sortedUserLibraryPlaylists
        let query = playlistSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return base
        }
        return base.filter {
            $0.title.lowercased().contains(query) || $0.subtitle.lowercased().contains(query)
        }
    }
    
    public func filteredSongs(for pl: YTMPlaylist) -> [YTMPlaylistItem] {
        let list = YTMPlaylistItem.deduplicate(pl.tracks)
        let query = songSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return list
        }
        let filtered = list.filter {
            $0.title.lowercased().contains(query) || $0.artist.lowercased().contains(query)
        }
        return YTMPlaylistItem.deduplicate(filtered)
    }
    
    public func selectPlaylist(_ pl: YTMPlaylist) {
        // The live queue belongs to the Queue tab, never to the Playlists tab.
        if pl.id == "pl_queue" || pl.kind == .queue {
            openQueueSection()
            return
        }
        var p = pl
        p.tracks = YTMPlaylistItem.deduplicate(p.tracks)
        
        // If the playlist explicitly contains an actively playing track and our current media
        // player track is not matching any track in this playlist, adopt this active track's info.
        if let existingActive = p.tracks.first(where: { $0.isPlaying }), activeTrackId(in: p.tracks) == nil {
            trackTitle = existingActive.title
            if !existingActive.artist.isEmpty {
                artistName = existingActive.artist
            }
            isPlaying = true
        }
        
        if p.tracks.isEmpty {
            let cached = YTMUserOfflineStore.shared.getStoredTracks(forPlaylist: p.id, email: userEmail)
            if !cached.isEmpty {
                p.tracks = cached
            }
        }
        
        selectedPlaylist = p
        rightDeckSection = .playlists
        isSearchingSongs = false
        songSearchQuery = ""
        tracksError = nil
        trackLoadTask?.cancel()
        syncPlayingTrackWithPlaylists()
        recordPlaylistUsage(for: p.id)
        
        // The live queue is mirrored from the player; everything else is fetched natively.
        guard p.id != "pl_queue", p.kind != .queue else {
            isLoadingTracks = false
            return
        }
        
        // If offline and we have cached tracks, don't attempt network load
        if isOffline {
            isLoadingTracks = false
            return
        }
        
        loadTracksForSelectedPlaylist()
    }
    
    /// Fetches the real tracks (playlist, album or artist) of `selectedPlaylist` from YouTube Music.
    public func loadTracksForSelectedPlaylist() {
        guard let pl = selectedPlaylist, pl.id != "pl_queue", pl.id != "pl_quickpicks", pl.kind != .queue else { return }
        trackLoadTask?.cancel()
        isLoadingTracks = true
        tracksError = nil
        let eng = engine
        trackLoadTask = Task { @MainActor [weak self] in
            do {
                let page = try await eng.loadTracks(for: pl)
                guard let self = self, !Task.isCancelled, self.selectedPlaylist?.id == pl.id else { return }
                self.applyLoadedTracks(page, to: pl)
                self.tracksError = page.tracks.isEmpty ? "No songs found in this \(pl.kind == .artist ? "artist" : "playlist")." : nil
                self.isLoadingTracks = false
            } catch {
                guard let self = self, !Task.isCancelled, self.selectedPlaylist?.id == pl.id else { return }
                if (self.selectedPlaylist?.tracks.isEmpty ?? true) {
                    self.tracksError = error.localizedDescription
                }
                self.isLoadingTracks = false
            }
        }
    }
    
    func applyLoadedTracks(_ page: YTMTrackPage, to pl: YTMPlaylist) {
        var updated = selectedPlaylist ?? pl
        let deduplicated = YTMPlaylistItem.deduplicate(page.tracks)
        updated.tracks = deduplicated
        updated.trackCount = deduplicated.count
        if let list = page.playbackListId { updated.playbackListId = list }
        selectedPlaylist = updated
        syncPlayingTrackWithPlaylists()
        YTMUserOfflineStore.shared.recordTracks(deduplicated)
        if updated.kind == .playlist {
            mergePlaylists([updated])
        }
        YTMUserOfflineStore.shared.savePlaylist(updated, for: userEmail)
    }
    
    public func backToPlaylists() {
        trackLoadTask?.cancel()
        isLoadingTracks = false
        tracksError = nil
        selectedPlaylist = nil
        isSearchingSongs = false
        songSearchQuery = ""
        if rightDeckSection == .queue {
            rightDeckSection = (previousRightDeckSection == .queue) ? .home : previousRightDeckSection
        } else {
            rightDeckSection = .playlists
        }
    }
    
    public func openQuickPicksPlaylist() {
        trackLoadTask?.cancel()
        isLoadingTracks = false
        tracksError = nil
        isSearchingSongs = false
        songSearchQuery = ""
        let picks = quickPicks.isEmpty ? YTMParser.defaultQuickPicks : quickPicks
        let pl = YTMPlaylist(
            id: "pl_quickpicks",
            title: "Quick Picks",
            subtitle: "Personalized Mix • \(picks.count) tracks",
            thumbnailURL: picks.first?.thumbnailURL,
            tracks: picks,
            browseId: "FEmusic_home"
        )
        selectedPlaylist = pl
        rightDeckSection = .playlists
    }
    
    public func openQuickPicksSection() {
        trackLoadTask?.cancel()
        isLoadingTracks = false
        tracksError = nil
        selectedPlaylist = nil
        isSearchingSongs = false
        songSearchQuery = ""
        rightDeckSection = .home
        if quickPicks.isEmpty {
            refreshQuickPicks()
        }
    }
    
    public func refreshQuickPicks() {
        let eng = engine
        Task { @MainActor in
            await eng.refreshQuickPicks()
        }
    }
    
    /// Guaranteed Exact Track Playback:
    /// Explicitly loads and plays `track` while guaranteeing that:
    /// 1. Its title, artist, and cover thumbnail are set immediately.
    /// 2. Stale WebKit updates from previous tracks are ignored.
    /// 3. In-flight ended events from previous tracks cannot skip to another track.
    /// 4. Radio automix queues (RDAMVM) are NEVER used to hijack direct playback.
    public func startExactTrack(_ track: YTMPlaylistItem, listId: String? = nil) {
        if !trackTitle.isEmpty && trackTitle != "YouTube Music" && Self.normalizeTitle(trackTitle) != Self.normalizeTitle(track.title) {
            stalePreviousTitle = Self.normalizeTitle(trackTitle)
            trackTransitionLockoutUntil = Date().addingTimeInterval(2.5)
        } else {
            stalePreviousTitle = ""
            trackTransitionLockoutUntil = nil
        }
        
        trackTitle = track.title
        artistName = track.artist.isEmpty ? "YouTube Music" : track.artist
        if let thumb = track.thumbnailURL, !thumb.isEmpty {
            albumArtURL = thumb
        }
        currentTime = 0
        isPlaying = true
        userIntentionallyPaused = false
        playResumeLockoutUntil = Date().addingTimeInterval(1.8)
        
        pendingTargetTrack = TargetTrack(
            title: track.title,
            artist: track.artist,
            videoId: track.videoId,
            thumbnailURL: track.thumbnailURL
        )
        if trackTransitionLockoutUntil == nil {
            trackTransitionLockoutUntil = Date().addingTimeInterval(2.5)
        }
        
        // Morph is the standalone native media player: always play directly in Morph's embedded engine
        // so that real-time progress bar telemetry, background playback, and switching songs work seamlessly!
        sourceName = "YouTube Music Direct"
        if let vid = track.videoId, !vid.isEmpty {
            engine.play(videoId: vid, listId: listId, fallbackToRadio: false)
        } else {
            let query = "\(track.title) \(track.artist)".trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                playSearch(query)
            }
        }
    }
    
    public func playQuickPick(_ track: YTMPlaylistItem, startRadio: Bool = false) {
        if isOffline {
            triggerOfflineHandling(for: track.title)
            return
        }
        guard let vid = track.videoId, !vid.isEmpty else {
            let query = "\(track.title) \(track.artist)".trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                playSearch(query)
            }
            return
        }
        
        for i in 0..<quickPicks.count {
            quickPicks[i].isPlaying = (quickPicks[i].id == track.id || quickPicks[i].videoId == vid)
        }
        
        let radioListId = startRadio ? "RDAMVM\(vid)" : nil
        startExactTrack(track, listId: radioListId)
        syncPlayingTrackWithPlaylists()
    }
    
    public func openPlaylistsSection() {
        trackLoadTask?.cancel()
        isLoadingTracks = false
        tracksError = nil
        selectedPlaylist = nil
        rightDeckSection = .playlists
        isSearchingSongs = false
        songSearchQuery = ""
    }
    
    /// Switches the right deck tab, clearing any container opened in another tab so each tab shows only its own content.
    public func selectRightDeckSection(_ section: YTMRightDeckSection) {
        switchRightDeck(to: section)
    }
    
    public func switchRightDeck(to section: YTMRightDeckSection) {
        switch section {
        case .home: openHubHome()
        case .playlists: openPlaylistsSection()
        case .queue: openQueueSection()
        case .downloads:
            if isOffline {
                openDownloadsSection()
            } else {
                openHubHome()
            }
        case .search:
            trackLoadTask?.cancel()
            isLoadingTracks = false
            tracksError = nil
            selectedPlaylist = nil
            rightDeckSection = .search
        }
    }
    
    public func openDownloadsSection() {
        trackLoadTask?.cancel()
        isLoadingTracks = false
        tracksError = nil
        selectedPlaylist = nil
        isSearchingSongs = false
        songSearchQuery = ""
        let cached = YTMUserOfflineStore.shared.getOfflineTracks()
        if !cached.isEmpty {
            self.downloadedTracks = cached
        }
        rightDeckSection = .downloads
    }
    
    public func triggerOfflineHandling(for title: String) {
        let now = Date()
        // Debounce / throttle repeated rapid clicks to prevent UI lag and freezing
        if let last = lastOfflineClickTime, now.timeIntervalSince(last) < 1.0 {
            if rightDeckSection != .downloads {
                openDownloadsSection()
            }
            return
        }
        lastOfflineClickTime = now
        
        offlineHUDMessage = "Offline • Switched to YouTube Music Downloads"
        showOfflineHUD = true
        offlineHUDWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.showOfflineHUD = false
        }
        offlineHUDWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8, execute: work)
        
        openDownloadsSection()
    }
    
    public func playDownloadedTrack(_ item: YTMPlaylistItem) {
        trackTitle = item.title
        artistName = item.artist.isEmpty ? "YouTube Music" : item.artist
        albumArtURL = item.thumbnailURL
        currentTime = 0
        duration = 210
        isPlaying = true
        sourceName = "YouTube Music Offline"
        
        for i in 0..<downloadedTracks.count {
            downloadedTracks[i].isPlaying = (downloadedTracks[i].id == item.id)
        }
    }
    
    public func openDownloadsFolder() {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        let fileManager = FileManager.default
        let musicURL = fileManager.urls(for: .musicDirectory, in: .userDomainMask).first
        let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
        let targetURL = musicURL ?? downloadsURL ?? URL(fileURLWithPath: NSHomeDirectory())
        NSWorkspace.shared.open(targetURL)
    }
    
    public func openQueueSection() {
        trackLoadTask?.cancel()
        isLoadingTracks = false
        tracksError = nil
        isSearchingSongs = false
        songSearchQuery = ""
        if rightDeckSection != .queue {
            previousRightDeckSection = rightDeckSection
        }
        selectedPlaylist = nowPlayingQueuePlaylist
        rightDeckSection = .queue
    }
    
    public func backFromQueue() {
        selectedPlaylist = nil
        rightDeckSection = (previousRightDeckSection == .queue) ? .home : previousRightDeckSection
    }
    
    public func openHubHome() {
        trackLoadTask?.cancel()
        isLoadingTracks = false
        tracksError = nil
        selectedPlaylist = nil
        rightDeckSection = .home
    }
    
    /// `list=` parameter for starting playback inside the currently opened container (artists play as radio).
    private var selectedPlaybackListId: String? {
        guard let sel = selectedPlaylist, sel.kind != .artist, sel.kind != .queue, sel.id != "pl_queue", sel.id != "pl_quickpicks" else { return nil }
        let raw = sel.playbackListId ?? (sel.kind == .playlist ? sel.id : nil)
        guard let r = raw else { return nil }
        return r.hasPrefix("VL") ? String(r.dropFirst(2)) : r
    }
    
    private func markPlaying(_ item: YTMPlaylistItem) {
        userIntentionallyPaused = false
        if !trackTitle.isEmpty && trackTitle != "YouTube Music" && Self.normalizeTitle(trackTitle) != Self.normalizeTitle(item.title) {
            stalePreviousTitle = Self.normalizeTitle(trackTitle)
            trackTransitionLockoutUntil = Date().addingTimeInterval(2.5)
        }
        trackTitle = item.title
        if !item.artist.isEmpty {
            artistName = item.artist
        }
        if let thumb = item.thumbnailURL, !thumb.isEmpty {
            albumArtURL = thumb
        }
        currentTime = 0
        isPlaying = true
        for i in 0..<playlist.count {
            playlist[i].isPlaying = (playlist[i].id == item.id || (playlist[i].title == item.title && playlist[i].artist == item.artist))
        }
        syncPlayingTrackWithPlaylists()
        YTMUserOfflineStore.shared.recordTrack(item)
    }
    
    // MARK: - Track Normalization and Active Track Resolution
    
    private nonisolated(unsafe) static let titleNormalizationCache = NSCache<NSString, NSString>()
    
    private nonisolated static let clutterRegex: NSRegularExpression = {
        let pattern = #"\((?:official\s+(?:music\s+|lyric\s+)?video|official\s+audio|visualizer|lyrics?|audio)\)|\[(?:official\s+(?:music\s+|lyric\s+)?video|official\s+audio|visualizer|lyrics?|audio)\]|official\s+(?:music\s+)?video|official\s+audio|lyric\s+video"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()
    
    private nonisolated static let trimCharacterSet: CharacterSet = {
        CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: " -–—\"'()[]"))
    }()

    /// Cleans clutter like "(Official Music Video)", "[Audio]", etc. from track titles
    /// so left and right side titles match cleanly.
    nonisolated public static func normalizeTitle(_ raw: String) -> String {
        let nsRaw = raw as NSString
        if let cached = titleNormalizationCache.object(forKey: nsRaw) {
            return cached as String
        }
        
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            titleNormalizationCache.setObject("" as NSString, forKey: nsRaw)
            return ""
        }
        
        let range = NSRange(location: 0, length: nsRaw.length)
        let cleaned = clutterRegex.stringByReplacingMatches(in: raw, options: [], range: range, withTemplate: "")
        let result = cleaned.trimmingCharacters(in: trimCharacterSet).lowercased()
        
        titleNormalizationCache.setObject(result as NSString, forKey: nsRaw)
        return result
    }
    
    /// The currently active videoId resolved from engine trackData or playing queue item.
    public var activeTrackVideoId: String? {
        if let vid = engine.trackData.videoId, !vid.isEmpty {
            return vid
        }
        if let pending = pendingTargetTrack?.videoId, !pending.isEmpty {
            return pending
        }
        if let qItem = playlist.first(where: { $0.isPlaying }), let vid = qItem.videoId, !vid.isEmpty {
            return vid
        }
        let currentTitleClean = Self.normalizeTitle(trackTitle)
        if !currentTitleClean.isEmpty,
           let match = playlist.first(where: { Self.normalizeTitle($0.title) == currentTitleClean }),
           let vid = match.videoId, !vid.isEmpty {
            return vid
        }
        return nil
    }
    
    /// Resolves the single active track ID inside a given list of tracks.
    /// Strictly guarantees at most ONE track can ever be identified as active.
    public func activeTrackId(in tracks: [YTMPlaylistItem]) -> String? {
        guard !tracks.isEmpty else { return nil }
        
        let currentTitleClean = Self.normalizeTitle(trackTitle)
        let currentArtistClean = artistName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Tier 1: Match by videoId with active queue track or engine track
        if let targetVid = activeTrackVideoId {
            if let match = tracks.first(where: { $0.videoId == targetVid }) {
                return match.id
            }
        }
        
        guard !currentTitleClean.isEmpty && currentTitleClean != "youtube music" else {
            return nil
        }
        
        // Tier 2: Match by normalized title AND artist
        if !currentArtistClean.isEmpty && currentArtistClean != "youtube music" {
            if let match = tracks.first(where: {
                Self.normalizeTitle($0.title) == currentTitleClean &&
                $0.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == currentArtistClean
            }) {
                return match.id
            }
        }
        
        // Tier 3: Match by normalized title alone
        if let match = tracks.first(where: {
            Self.normalizeTitle($0.title) == currentTitleClean
        }) {
            return match.id
        }
        
        // Tier 4: Substring containment
        if let match = tracks.first(where: {
            let t = Self.normalizeTitle($0.title)
            return !t.isEmpty && (currentTitleClean.contains(t) || t.contains(currentTitleClean))
        }) {
            return match.id
        }
        
        // Strictly return nil if no track matches the currently playing song.
        // Under no circumstances should an unrelated track be marked as playing.
        return nil
    }
    
    /// Returns true if and only if this track is the currently playing track in the provided collection.
    /// This strictly prevents multiple tracks from showing as playing at the same time.
    public func isSongCurrent(_ song: YTMPlaylistItem, in tracks: [YTMPlaylistItem]) -> Bool {
        guard isPlaying else { return false }
        return song.id == activeTrackId(in: tracks)
    }
    
    /// Returns true if this track is the currently selected/active track while playback is paused.
    public func isSongPausedCurrent(_ song: YTMPlaylistItem, in tracks: [YTMPlaylistItem]) -> Bool {
        guard !isPlaying else { return false }
        return song.id == activeTrackId(in: tracks)
    }
    
    /// Synchronizes track playing state and metadata across selected playlist and queue.
    /// Ensures both left side (now playing) and right side (playlist) display identical, synchronized info.
    public func syncPlayingTrackWithPlaylists() {
        // 1. Sync selectedPlaylist
        if var sel = selectedPlaylist {
            if sel.id == "pl_quickpicks" {
                sel.tracks = quickPicks
                sel.subtitle = "Personalized Mix • \(quickPicks.count) tracks"
            }
            let activeId = activeTrackId(in: sel.tracks)
            var changed = false
            for i in 0..<sel.tracks.count {
                let shouldBePlaying = isPlaying && (sel.tracks[i].id == activeId)
                if sel.tracks[i].isPlaying != shouldBePlaying {
                    sel.tracks[i].isPlaying = shouldBePlaying
                    changed = true
                }
            }
            if let activeId = activeId, let match = sel.tracks.first(where: { $0.id == activeId }) {
                // Harmonize left deck title/artist with the playlist track's clean metadata
                if Self.normalizeTitle(self.trackTitle) == Self.normalizeTitle(match.title) {
                    if self.trackTitle != match.title {
                        self.trackTitle = match.title
                    }
                    if !match.artist.isEmpty && (self.artistName.isEmpty || self.artistName == "YouTube Music" || self.artistName.lowercased().contains(match.artist.lowercased())) {
                        self.artistName = match.artist
                    }
                }
            }
            if changed || sel.id == "pl_quickpicks" {
                selectedPlaylist = sel
            }
        }
        
        // 2. Sync queue (self.playlist)
        if !playlist.isEmpty {
            let activeQId = activeTrackId(in: playlist)
            for i in 0..<playlist.count {
                playlist[i].isPlaying = isPlaying && (playlist[i].id == activeQId)
            }
            if let activeQId = activeQId, let matchQ = playlist.first(where: { $0.id == activeQId }) {
                if Self.normalizeTitle(self.trackTitle) == Self.normalizeTitle(matchQ.title) {
                    if self.trackTitle != matchQ.title {
                        self.trackTitle = matchQ.title
                    }
                    if !matchQ.artist.isEmpty && (self.artistName.isEmpty || self.artistName == "YouTube Music") {
                        self.artistName = matchQ.artist
                    }
                }
            }
        }
        
        // 3. Sync quickPicks
        if !quickPicks.isEmpty {
            let activeQPId = activeTrackId(in: quickPicks)
            for i in 0..<quickPicks.count {
                let shouldBePlaying = isPlaying && (quickPicks[i].id == activeQPId)
                if quickPicks[i].isPlaying != shouldBePlaying {
                    quickPicks[i].isPlaying = shouldBePlaying
                }
            }
        }
    }
    
    public func playSongInSelectedPlaylist(_ item: YTMPlaylistItem) {
        currentTime = 0.0
        lastSeekToZeroTime = Date()
        engine.trackData.currentTime = 0.0
        
        if let sel = selectedPlaylist {
            recordPlaylistUsage(for: sel.id)
        }
        if selectedPlaylist?.id == "pl_quickpicks" {
            playQuickPick(item, startRadio: true)
            return
        }
        if selectedPlaylist?.id == "pl_downloads" {
            playDownloadedTrack(item)
            return
        }
        if isOffline {
            if let downloaded = downloadedTracks.first(where: {
                $0.id == item.id ||
                (!item.title.isEmpty && $0.title.lowercased() == item.title.lowercased() && $0.artist.lowercased() == item.artist.lowercased()) ||
                ($0.videoId != nil && $0.videoId == item.videoId)
            }) {
                playDownloadedTrack(downloaded)
                return
            }
            triggerOfflineHandling(for: item.title)
            return
        }
        markPlaying(item)
        
        if selectedPlaylist?.id == "pl_queue" || rightDeckSection == .queue {
            // Live queue: play by exact queue index or fallback to direct videoId
            if let idx = Int(item.id) {
                engine.playQueueIndex(idx, videoId: item.videoId, title: item.title, artist: item.artist)
            } else if let matchIdx = effectivePlaylist.firstIndex(where: { $0.id == item.id }) {
                engine.playQueueIndex(matchIdx, videoId: item.videoId, title: item.title, artist: item.artist)
            } else if let matchIdx = playlist.firstIndex(where: { $0.id == item.id || ($0.title == item.title && $0.artist == item.artist) }) {
                engine.playQueueIndex(matchIdx, videoId: item.videoId, title: item.title, artist: item.artist)
            } else if let vid = item.videoId, !vid.isEmpty {
                startExactTrack(item, listId: nil)
            } else {
                playSearch("\(item.title) \(item.artist)")
            }
        } else if let vid = item.videoId, !vid.isEmpty {
            // Direct playback of the exact clicked track in the playlist container (without radio hijack)
            startExactTrack(item, listId: selectedPlaybackListId)
        } else {
            // Never blindly click random DOM list items on unrelated pages; search and play exact track
            playSearch("\(item.title) \(item.artist)")
        }
    }
    
    public func playEntireSelectedPlaylist() {
        guard let sel = selectedPlaylist, let first = sel.tracks.first else { return }
        recordPlaylistUsage(for: sel.id)
        if sel.id == "pl_quickpicks" {
            playQuickPick(first, startRadio: true)
            return
        }
        if sel.id == "pl_downloads" {
            playDownloadedTrack(first)
            return
        }
        if isOffline {
            triggerOfflineHandling(for: sel.title)
            return
        }
        if first.videoId != nil, sel.id != "pl_queue" {
            markPlaying(first)
            startExactTrack(first, listId: selectedPlaybackListId)
            return
        }
        playSongInSelectedPlaylist(first)
        engine.playEntirePlaylist()
    }
    
    /// Inserts a song into the live queue immediately after the currently active playing song.
    public func playNext(_ track: YTMPlaylistItem) {
        var cleanTrack = track
        cleanTrack.isPlaying = false
        
        let activeId = activeTrackId(in: playlist)
        // Remove prior occurrence to prevent duplicates in queue
        playlist.removeAll(where: { $0.id == track.id || (track.videoId?.isEmpty == false && $0.videoId == track.videoId) })
        
        if let currentIdx = playlist.firstIndex(where: { $0.isPlaying || ($0.id == activeId && activeId != nil) }) {
            let insertIdx = min(currentIdx + 1, playlist.count)
            playlist.insert(cleanTrack, at: insertIdx)
        } else {
            playlist.insert(cleanTrack, at: 0)
        }
        
        // Persist offline queue snapshot
        YTMUserOfflineStore.shared.recordTracks(playlist)
        
        // Synchronize opened queue view if visible
        if let sel = selectedPlaylist, sel.id == "pl_queue" {
            var updated = sel
            updated.tracks = playlist
            selectedPlaylist = updated
        }
    }
    // MARK: - Browser playlist scraping (ground truth from user's actual signed-in browser)

    /// JS that scrapes all playlists from the YouTube Music library page.
    /// Covers library grid cards, responsive list items, and sidebar nav entries.
    nonisolated private static func buildLibraryPlaylistJS() -> String {
        return """
        (function() {
            var out = [];
            var seen = {};
            function cleanId(raw) {
                if (!raw) return '';
                var m = raw.match(/[?&]list=([a-zA-Z0-9_-]+)/);
                if (m) return m[1];
                if (raw.indexOf('browse/VL') !== -1) {
                    return raw.split('browse/VL')[1].split('?')[0].split('/')[0];
                }
                if (raw.indexOf('/playlist/') !== -1) {
                    return raw.split('/playlist/')[1].split('?')[0];
                }
                return '';
            }
            function isUserPlaylist(id) {
                if (!id) return false;
                if (id === 'LM' || id === 'LL' || id === 'WL') return true;
                return id.indexOf('PL') === 0 || id.indexOf('VL') === 0 || id.indexOf('FL') === 0;
            }
            function isExcluded(id) {
                if (!id) return true;
                return id.indexOf('RD') === 0 || id.indexOf('MPRE') === 0 || id.indexOf('OLAK') === 0 || id.indexOf('RDEM') === 0;
            }
            function push(id, title, subtitle, thumb, browseId, playId) {
                var clean = id;
                if (clean.indexOf('VL') === 0) clean = clean.substring(2);
                if (!clean || !title || isExcluded(clean) || !isUserPlaylist(clean)) return;
                if (seen[clean]) return;
                seen[clean] = true;
                var bId = browseId || (clean === 'LM' || clean === 'LL' || clean === 'WL' ? 'VL' + clean : 'VL' + clean);
                out.push({ id: clean, title: title.trim(), subtitle: (subtitle || 'Playlist').trim(), thumbnailURL: thumb || null, browseId: bId, playbackListId: playId || clean });
            }

            // --- Strategy 1: Library grid (ytmusic-two-row-item-renderer on /library/playlists page) ---
            var gridCards = document.querySelectorAll('ytmusic-two-row-item-renderer');
            for (var i = 0; i < gridCards.length; i++) {
                var c = gridCards[i];
                var allLinks = c.querySelectorAll('a[href]');
                var id = '';
                for (var li = 0; li < allLinks.length; li++) {
                    var href = allLinks[li].getAttribute('href') || '';
                    id = cleanId(href);
                    if (id) break;
                }
                if (!id) continue;
                var titleEl = c.querySelector('yt-formatted-string.title') || c.querySelector('.title');
                var title = titleEl ? (titleEl.innerText || titleEl.textContent || '').trim() : '';
                if (!title) {
                    var anyFmt = c.querySelectorAll('yt-formatted-string');
                    if (anyFmt.length > 0) title = (anyFmt[0].innerText || anyFmt[0].textContent || '').trim();
                }
                var subEl = c.querySelector('yt-formatted-string.subtitle') || c.querySelector('.subtitle');
                var sub = subEl ? (subEl.innerText || subEl.textContent || '').trim() : 'Playlist';
                var imgEl = c.querySelector('img[src]');
                var thumb = imgEl ? imgEl.getAttribute('src') : null;
                if (thumb && thumb.indexOf('data:') === 0) thumb = null;
                push(id, title, sub, thumb, null, null);
            }

            // --- Strategy 2: Responsive list items ---
            var listItems = document.querySelectorAll('ytmusic-responsive-list-item-renderer');
            for (var j = 0; j < listItems.length; j++) {
                var item = listItems[j];
                var itemLinks = item.querySelectorAll('a[href]');
                var iid = '';
                for (var ll = 0; ll < itemLinks.length; ll++) {
                    var ihref = itemLinks[ll].getAttribute('href') || '';
                    iid = cleanId(ihref);
                    if (iid) break;
                }
                if (!iid) continue;
                var iTitle = '';
                var cols = item.querySelectorAll('.flex-columns yt-formatted-string');
                if (cols.length > 0) iTitle = (cols[0].innerText || cols[0].textContent || '').trim();
                var iSub = cols.length > 1 ? (cols[1].innerText || cols[1].textContent || '').trim() : 'Playlist';
                push(iid, iTitle, iSub, null, null, null);
            }

            // --- Strategy 3: Sidebar nav guide entries (recently used playlists) ---
            var guideItems = document.querySelectorAll('ytmusic-guide-entry-renderer');
            for (var g = 0; g < guideItems.length; g++) {
                var ge = guideItems[g];
                var ga = ge.querySelector('a[href]');
                if (!ga) continue;
                var ghref = ga.getAttribute('href') || '';
                var gid = cleanId(ghref);
                if (!gid) continue;
                var gtitleEl = ge.querySelector('yt-formatted-string') || ge.querySelector('.title');
                var gtitle = gtitleEl ? (gtitleEl.innerText || gtitleEl.textContent || '').trim() : '';
                push(gid, gtitle, 'Playlist', null, null, null);
            }

            console.log('[Morph] library scrape found ' + out.length + ' playlists');
            return JSON.stringify(out);
        })()
        """
    }

    /// Navigates an external browser to YTM's library/playlists page (if not already there),
    /// waits for render, then scrapes all playlist cards. This is the GROUND TRUTH source
    /// because it uses whatever Google account the user is actually signed into in their browser.
    public func scrapePlaylistsFromBrowsers() async -> [YTMPlaylist] {
        guard !isTestingEnvironment else { return [] }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let jsExtract = Self.buildLibraryPlaylistJS()

                // Escape the JS for safe embedding in an AppleScript string literal
                let escapedJS = jsExtract
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: " ")
                    .replacingOccurrences(of: "\r", with: " ")

                let chromiumApps: [(bundleId: String, appName: String)] = [
                    ("com.google.Chrome", "Google Chrome"),
                    ("com.brave.Browser", "Brave Browser"),
                    ("com.microsoft.edgemac", "Microsoft Edge"),
                    ("company.thebrowser.Browser", "Arc")
                ]

                func parseResult(_ res: String?) -> [YTMPlaylist]? {
                    guard let r = res, !r.isEmpty,
                          let data = r.data(using: .utf8),
                          let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                          !arr.isEmpty else { return nil }
                    var parsed: [YTMPlaylist] = []
                    for d in arr {
                        guard let id = d["id"] as? String, !id.isEmpty,
                              let title = d["title"] as? String, !title.isEmpty else { continue }
                        let sub = (d["subtitle"] as? String) ?? "Playlist"
                        let thumb = d["thumbnailURL"] as? String
                        let bId = d["browseId"] as? String
                        let playId = d["playbackListId"] as? String
                        parsed.append(YTMPlaylist(id: id, title: title, subtitle: sub,
                                                  thumbnailURL: thumb, browseId: bId,
                                                  kind: .playlist, playbackListId: playId))
                    }
                    return parsed.isEmpty ? nil : parsed
                }

                for entry in chromiumApps where !NSRunningApplication.runningApplications(withBundleIdentifier: entry.bundleId).isEmpty {
                    let appName = entry.appName

                    // Step 1: Check if YTM is already on the library page — scrape immediately
                    let quickScript = """
                    tell application "\(appName)"
                        repeat with w in windows
                            repeat with t in tabs of w
                                if (URL of t) contains "music.youtube.com" then
                                    try
                                        return (execute t javascript "\(escapedJS)")
                                    end try
                                end if
                            end repeat
                        end repeat
                    end tell
                    return ""
                    """
                    if let res = MorphAppleScriptRunner.run(quickScript, timeout: 3.0),
                       let playlists = parseResult(res) {
                        print("[Morph BrowserScrape] ✅ \(appName): \(playlists.count) playlists from existing tab")
                        continuation.resume(returning: playlists)
                        return
                    }
                }

                // Safari fallback
                if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty {
                    let quickScript = """
                    tell application "Safari"
                        repeat with w in windows
                            repeat with t in tabs of w
                                if (URL of t) contains "music.youtube.com" then
                                    try
                                        return (do JavaScript "\(escapedJS)" in t)
                                    end try
                                end if
                            end repeat
                        end repeat
                    end tell
                    return ""
                    """
                    if let res = MorphAppleScriptRunner.run(quickScript, timeout: 3.0),
                       let playlists = parseResult(res) {
                        print("[Morph BrowserScrape] ✅ Safari: \(playlists.count) playlists from existing tab")
                        continuation.resume(returning: playlists)
                        return
                    }
                }

                print("[Morph BrowserScrape] ⚠️ No browser with YTM tab found, or scraping returned empty")
                continuation.resume(returning: [])
            }
        }
    }

    /// Refreshes playlists: browser scraping is PRIMARY source of truth (user's actual signed-in browser).
    /// InnerTube is secondary for when no browser is open.
    public func refreshPlaylists() {
        isLoadingPlaylists = true
        let eng = engine
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // 1. Browser scraping FIRST — this is ground truth (uses user's actual signed-in account)
            let browserPlaylists = await self.scrapePlaylistsFromBrowsers()
            if !browserPlaylists.isEmpty {
                print("[Morph Playlists] ✅ Browser source: \(browserPlaylists.count) playlists — merging with cache")
                self.mergePlaylists(browserPlaylists)
                self.isLoadingPlaylists = false
                // Also fire InnerTube in background to populate track metadata
                Task { await eng.refreshLibraryPlaylists() }
                return
            }

            // 2. Fall back to InnerTube (Morph's embedded WebView account)
            print("[Morph Playlists] No browser data, falling back to InnerTube")
            await eng.refreshLibraryPlaylists()
            if !eng.userPlaylists.isEmpty {
                self.mergePlaylists(eng.userPlaylists)
            }
            self.isLoadingPlaylists = false
        }
    }

    
    // MARK: - YouTube Music catalog search (songs / artists / albums / playlists)
    public func runCatalogSearch(_ rawQuery: String, allowSingleCharacter: Bool = false) {
        searchTask?.cancel()
        let q = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        activeCatalogQuery = q
        let minLen = allowSingleCharacter ? 1 : 2
        guard q.count >= minLen else {
            searchResults = []
            isSearchingCatalog = false
            catalogSearchError = nil
            return
        }
        isSearchingCatalog = true
        catalogSearchError = nil
        let eng = engine
        searchTask = Task { @MainActor [weak self] in
            do {
                let results = try await eng.searchCatalog(q)
                guard let self = self, !Task.isCancelled, self.activeCatalogQuery == q else { return }
                self.searchResults = results
                self.catalogSearchError = results.isEmpty ? "No results on YouTube Music for \"\(q)\"." : nil
                self.isSearchingCatalog = false
            } catch {
                guard let self = self, !Task.isCancelled, self.activeCatalogQuery == q else { return }
                self.searchResults = []
                self.catalogSearchError = error.localizedDescription
                self.isSearchingCatalog = false
            }
        }
    }
    
    /// Search results grouped like the YouTube Music results page (top result first, then Songs, Artists, Albums, Playlists, Videos).
    public var groupedSearchResults: [(kind: YTMSearchKind, items: [YTMSearchResult])] {
        let order: [YTMSearchKind]
        if let specificKind = activeSearchCategory.matchingKind {
            order = [specificKind]
        } else {
            order = [.song, .artist, .album, .playlist, .video]
        }
        return order.compactMap { k in
            let items = searchResults.filter { $0.kind == k }
            return items.isEmpty ? nil : (kind: k, items: Array(items.prefix(k == .song ? 8 : 5)))
        }
    }
    
    // MARK: - Smart Search Suggestions & Direct Link Autoplay
    private var suggestionsTask: Task<Void, Never>?
    
    public func fetchSuggestions(for query: String) {
        suggestionsTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else {
            self.searchSuggestions = []
            return
        }
        suggestionsTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            let suggestions = await self.engine.fetchSearchSuggestions(q)
            guard !Task.isCancelled else { return }
            self.searchSuggestions = suggestions
        }
    }
    
    /// Parses input for direct YouTube / YouTube Music URL or videoId and auto-plays, or runs catalog search.
    @discardableResult
    public func handleSmartSearchInput(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        // 1. Direct YouTube / YouTube Music video URL
        if let videoId = Self.extractYouTubeVideoId(from: trimmed) {
            let listId = Self.extractYouTubePlaylistId(from: trimmed)
            let dummyTrack = YTMPlaylistItem(
                id: videoId,
                title: "Loading...",
                artist: "YouTube Music",
                duration: "0:00",
                isPlaying: true,
                videoId: videoId
            )
            self.startExactTrack(dummyTrack, listId: listId)
            self.searchSuggestions = []
            return true
        }
        
        // 2. Direct YouTube / YouTube Music playlist URL
        if let listId = Self.extractYouTubePlaylistId(from: trimmed) {
            let pl = YTMPlaylist(
                id: listId,
                title: "YouTube Playlist",
                subtitle: "Direct link",
                browseId: listId.hasPrefix("VL") ? listId : "VL\(listId)"
            )
            self.selectPlaylist(pl)
            self.searchSuggestions = []
            return true
        }
        
        // Normal text search
        self.runCatalogSearch(trimmed)
        return false
    }
    
    public static func extractYouTubeVideoId(from string: String) -> String? {
        let pattern = #"(?:v=|\/embed\/|\/watch\?v=|\/v\/|youtu\.be\/|\/shorts\/)([a-zA-Z0-9_-]{11})"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: string.utf16.count)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: string) else {
            return nil
        }
        return String(string[range])
    }
    
    public static func extractYouTubePlaylistId(from string: String) -> String? {
        let pattern = #"(?:[?&]list=)([a-zA-Z0-9_-]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: string.utf16.count)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: string) else {
            return nil
        }
        return String(string[range])
    }
    
    /// Opens a search result: songs/videos start playing, artists/albums/playlists open with their real songs.
    public func openSearchResult(_ result: YTMSearchResult) {
        if isOffline && (result.kind == .song || result.kind == .video) {
            triggerOfflineHandling(for: result.title)
            return
        }
        switch result.kind {
        case .song, .video:
            guard let track = result.asTrack else { return }
            startExactTrack(track)
        case .artist, .album, .playlist:
            if let pl = result.asPlaylist {
                selectPlaylist(pl)
            }
        }
    }
    
    /// Jumps from an opened playlist to a YouTube Music-wide search for `query`.
    public func searchYouTubeMusic(for query: String) {
        backToPlaylists()
        isSearchingPlaylists = true
        playlistSearchQuery = query
    }
    
    public func clearCatalogSearch() {
        searchTask?.cancel()
        suggestionsTask?.cancel()
        activeCatalogQuery = ""
        searchResults = []
        searchSuggestions = []
        isSearchingCatalog = false
        catalogSearchError = nil
    }
    
    public func clearPlaylistSearch() {
        playlistSearchQuery = ""
        clearCatalogSearch()
    }
    
    public var nowPlayingQueuePlaylist: YTMPlaylist {
        YTMPlaylist(
            id: "pl_queue",
            title: "Now Playing Queue",
            subtitle: "\(effectivePlaylist.count) tracks in live queue",
            thumbnailURL: albumArtURL,
            trackCount: effectivePlaylist.count,
            tracks: effectivePlaylist,
            browseId: nil
        )
    }
    
    public var effectivePlaylist: [YTMPlaylistItem] {
        return YTMPlaylistItem.deduplicate(playlist)
    }
    
    public func playQueueTrack(_ item: YTMPlaylistItem) {
        currentTime = 0.0
        lastSeekToZeroTime = Date()
        engine.trackData.currentTime = 0.0
        
        if isOffline {
            if let downloaded = downloadedTracks.first(where: {
                $0.id == item.id ||
                (!item.title.isEmpty && $0.title.lowercased() == item.title.lowercased() && $0.artist.lowercased() == item.artist.lowercased()) ||
                ($0.videoId != nil && $0.videoId == item.videoId)
            }) {
                playDownloadedTrack(downloaded)
                return
            }
            triggerOfflineHandling(for: item.title)
            return
        }
        markPlaying(item)
        
        let qIdx = Int(item.id) ?? playlist.firstIndex(where: { $0.id == item.id })
        if let idx = qIdx {
            engine.playQueueIndex(idx, videoId: item.videoId, title: item.title, artist: item.artist)
        } else if let vid = item.videoId, !vid.isEmpty {
            startExactTrack(item, listId: nil)
        } else {
            playSearch(item.title + " " + item.artist)
        }
    }
    
    public func toggleLike() {
        isLiked.toggle()
        if isLiked && isDisliked {
            isDisliked = false
        }
        engine.toggleLike()
    }
    
    public func toggleDislike() {
        isDisliked.toggle()
        if isDisliked && isLiked {
            isLiked = false
        }
        engine.toggleDislike()
    }
    
    public func setShuffle(_ enable: Bool) {
        isShuffle = enable
        shuffleLockoutUntil = Date().addingTimeInterval(2.5)
        triggerShuffleHUD()
        if isDirectEngineActive || isDirectEngineConnected {
            engine.setShuffle(enable)
        } else {
            executeBrowserShuffle(enable)
        }
    }

    public func toggleShuffle() {
        setShuffle(!isShuffle)
    }
    
    public func setRepeatMode(_ newMode: YTMRepeatMode) {
        repeatMode = newMode
        repeatModeLockoutUntil = Date().addingTimeInterval(2.5)
        triggerRepeatHUD()
        if isDirectEngineActive || isDirectEngineConnected {
            engine.setRepeatMode(newMode)
        } else {
            executeBrowserRepeat(newMode)
        }
    }
    
    public func toggleRepeat() {
        setRepeatMode(repeatMode.next)
    }
    
    // MARK: - Direct & Browser-Based Authentication & Tab Management
    public func openSignIn() {
        isWaitingForBrowserSignIn = true
        browserAuthStatusMessage = "Sign in via the Morph YouTube Music window. Once signed in, your playlists and music sync directly into Morph."
        engine.loadGoogleSignIn()
    }
    
    public func signOut() {
        isSignedIn = false
        userEmail = nil
        activeProfile = nil
        YTMProfileManager.shared.clearActiveProfile()
        playlists = []
        selectedPlaylist = nil
        isWaitingForBrowserSignIn = false
        browserAuthStatusMessage = nil
        engine.signOut()
        refreshQuickPicks()
    }
    
    public func switchProfile(to profile: YTMProfile) {
        YTMProfileManager.shared.switchProfile(to: profile.id)
        self.activeProfile = profile
        self.userEmail = profile.email
        if profile.accountTier != .unknown {
            self.accountTier = profile.accountTier
        }
        let cached = YTMUserOfflineStore.shared.getStoredPlaylists(for: profile.email)
        self.playlists = cached
        self.selectedPlaylist = nil
        self.quickPicks = []
        self.isLoadingQuickPicks = true
        engine.switchProfile(to: profile)
        refreshPlaylists()
        refreshQuickPicks()
    }
    
    public func addNewProfile() {
        let newP = YTMProfileManager.shared.addProfile(email: "", displayName: "New Profile")
        switchProfile(to: newP)
        openSignIn()
    }
    
    public func importBrowserProfile(email: String, displayName: String) {
        let p = YTMProfileManager.shared.addProfile(email: email, displayName: displayName, isChromeImported: true)
        switchProfile(to: p)
    }
    
    public func removeProfile(id: UUID) {
        YTMProfileManager.shared.removeProfile(id: id)
        if let active = YTMProfileManager.shared.activeProfile {
            switchProfile(to: active)
        }
    }
    
    public func openSignInInBrowser() {
        // Direct in-app sign-in captures session cookies directly into Morph's engine.
        // Directing to openSignIn() ensures the user's login is never isolated in an external browser.
        openSignIn()
    }
    
    public func openInBrowser() {
        engine.openYouTubeMusicInBrowser()
    }
    
    public func syncSessionFromBrowser() {
        browserAuthStatusMessage = "Syncing session from browser tab..."
        engine.syncSessionFromBrowser()
        engine.checkAuthCookies()
        Task {
            await pollBrowserState()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self = self else { return }
                if self.isBrowserConnected || self.engine.isSignedIn || self.isSignedIn {
                    self.browserAuthStatusMessage = "Connected to \(self.sourceName)! Music synced."
                    self.isWaitingForBrowserSignIn = false
                    self.refreshPlaylists()
                    self.refreshQuickPicks()
                } else {
                    self.browserAuthStatusMessage = "No active session detected. Please sign in via the Morph window or open YouTube Music in your browser."
                }
            }
        }
    }
    
    public func openPlayerWindow() {
        engine.showPlayerWindow()
    }
    
    // MARK: - Ambient Visualizer
    public func syncVisualizerTimer() {
        let shouldRun = isVisualizerActive && isPlaying && !isMuted
        if shouldRun {
            if visualizerTimer == nil {
                visualizerTimer = Timer.publish(every: 0.12, on: .main, in: .common)
                    .autoconnect()
                    .sink { [weak self] _ in
                        guard let self = self else { return }
                        if self.isPlaying && !self.isMuted && self.isVisualizerActive {
                            self.visualizerBars = [
                                CGFloat.random(in: 0.25...0.95),
                                CGFloat.random(in: 0.45...1.0),
                                CGFloat.random(in: 0.20...0.85)
                            ]
                        } else {
                            self.visualizerBars = [0.18, 0.18, 0.18]
                            self.syncVisualizerTimer()
                        }
                    }
            }
        } else {
            visualizerTimer?.cancel()
            visualizerTimer = nil
            if visualizerBars != [0.18, 0.18, 0.18] {
                visualizerBars = [0.18, 0.18, 0.18]
            }
        }
    }
    
    private func startVisualizer() {
        syncVisualizerTimer()
    }
    
    // MARK: - Fallback Browser AppleScript Bridge (When external browser is used)
    private func startBrowserPolling() {
        browserPollTimer = Timer.publish(every: 3.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, !self.isTestingEnvironment else { return }
                    if !self.engine.trackData.isPlaying && !self.userIntentionallyPaused && !self.isDirectEngineActive {
                        await self.pollBrowserState()
                    }
                }
            }
    }
    
    public struct WindowServerYTMResult {
        public let found: Bool
        public let browser: String
        public let trackTitle: String
        public let artistName: String
        public let tier: YTMAccountTier
        public let isAd: Bool
        
        public init(found: Bool, browser: String, trackTitle: String, artistName: String, tier: YTMAccountTier = .unknown, isAd: Bool = false) {
            self.found = found
            self.browser = browser
            self.trackTitle = trackTitle
            self.artistName = artistName
            self.tier = tier
            self.isAd = isAd
        }
    }
    
    public func detectYouTubeMusicInWindowServer() -> WindowServerYTMResult {
        guard !isTestingEnvironment else {
            return WindowServerYTMResult(found: false, browser: "", trackTitle: "", artistName: "")
        }
        let options = CGWindowListOption.excludeDesktopElements
        guard let winList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return WindowServerYTMResult(found: false, browser: "", trackTitle: "", artistName: "")
        }
        
        let recognizedBrowsers = [
            "Polar": "Polar",
            "Polar Host": "Polar",
            "Google Chrome": "Chrome",
            "Safari": "Safari",
            "Brave Browser": "Brave",
            "Arc": "Arc",
            "Microsoft Edge": "Edge",
            "Firefox": "Firefox",
            "Vivaldi": "Vivaldi",
            "Opera": "Opera"
        ]
        
        for win in winList {
            let owner = win[kCGWindowOwnerName as String] as? String ?? ""
            let rawTitle = win[kCGWindowName as String] as? String ?? ""
            let layer = win[kCGWindowLayer as String] as? Int ?? -1
            guard layer == 0 || layer == 1 else { continue }
            
            var matchedBrowserName: String? = nil
            for (ownerKey, browserDisplayName) in recognizedBrowsers {
                if owner.caseInsensitiveCompare(ownerKey) == .orderedSame || owner.lowercased().contains(ownerKey.lowercased()) {
                    matchedBrowserName = browserDisplayName
                    break
                }
            }
            guard let browserName = matchedBrowserName else { continue }
            
            let trimmedTitle = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedTitle.contains("YouTube Music") || trimmedTitle.contains("music.youtube.com") {
                let clean = trimmedTitle
                    .replacingOccurrences(of: " - YouTube Music", with: "")
                    .replacingOccurrences(of: "YouTube Music", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                var track = ""
                var artist = ""
                if clean.contains(" • ") {
                    let parts = clean.components(separatedBy: " • ")
                    if parts.count >= 2 {
                        track = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        artist = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        track = clean
                    }
                } else if clean.contains(" - ") {
                    let parts = clean.components(separatedBy: " - ")
                    if parts.count >= 2 {
                        track = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        artist = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        track = clean
                    }
                } else if !clean.isEmpty {
                    track = clean
                }
                
                let isAd = trimmedTitle.localizedCaseInsensitiveContains("Advertisement") || clean.lowercased() == "advertisement"
                let detectedTier: YTMAccountTier = trimmedTitle.contains("YouTube Music Premium") ? .premium : .unknown
                
                return WindowServerYTMResult(
                    found: true,
                    browser: browserName,
                    trackTitle: isAd ? "" : track,
                    artistName: isAd ? "" : artist,
                    tier: detectedTier,
                    isAd: isAd
                )
            }
        }
        return WindowServerYTMResult(found: false, browser: "", trackTitle: "", artistName: "")
    }
    
    public func pollBrowserState() async {
        guard !isTestingEnvironment, !self.userIntentionallyPaused, !(self.isDirectEngineActive && self.engine.trackData.isPlaying) else { return }
        
        // 1. Instant WindowServer Scan (sub-millisecond, covers Polar, Chrome, Safari, etc.)
        let wsDetection = detectYouTubeMusicInWindowServer()
        if wsDetection.found {
            await MainActor.run {
                guard !self.engine.trackData.isPlaying, !self.userIntentionallyPaused else { return }
                self.isBrowserConnected = true
                self.isSignedIn = true
                self.sourceName = "YouTube Music • \(wsDetection.browser)"
                if wsDetection.tier != .unknown && self.accountTier != wsDetection.tier {
                    self.accountTier = wsDetection.tier
                }
                self.isAdPlaying = wsDetection.isAd
                if wsDetection.isAd {
                    return
                }
                
                if !wsDetection.trackTitle.isEmpty {
                    self.trackTitle = wsDetection.trackTitle
                    self.artistName = wsDetection.artistName.isEmpty ? "YouTube Music" : wsDetection.artistName
                    if !self.userIntentionallyPaused {
                        self.isPlaying = true
                    }
                    self.syncPlayingTrackWithPlaylists()
                } else if self.trackTitle.isEmpty {
                    self.trackTitle = "YouTube Music Connected"
                    self.artistName = "Ready in \(wsDetection.browser)"
                }
            }
            return
        }
        
        // 2. Multi-browser AppleScript Tab Inspection (for scriptable browsers with tabs)
        // Throttled: only scan all browser tabs via AppleScript if already connected, or max once every 12 seconds
        let now = ProcessInfo.processInfo.systemUptime
        if !self.isBrowserConnected && (now - self.lastScriptableScanTimestamp < 12.0) {
            return
        }
        self.lastScriptableScanTimestamp = now
        
        let scriptResult = await scanScriptableBrowserTabs()
        guard !isTestingEnvironment, !engine.trackData.isPlaying, !self.userIntentionallyPaused, !(self.isDirectEngineActive && self.engine.trackData.isPlaying) else { return }
        
        if scriptResult.found {
            await MainActor.run {
                guard !self.userIntentionallyPaused, !(self.isDirectEngineActive && self.engine.trackData.isPlaying) else { return }
                self.isBrowserConnected = true
                self.isSignedIn = true
                self.sourceName = "YouTube Music • \(scriptResult.browser)"
                if scriptResult.tier == .premium {
                    self.accountTier = .premium
                    self.engine.accountTier = .premium
                }
                self.parseTabTitle(scriptResult.tabTitle, source: "YouTube Music • \(scriptResult.browser)")
                if self.playlists.isEmpty {
                    Task { [weak self] in
                        guard let self = self else { return }
                        let scraped = await self.scrapePlaylistsFromBrowsers()
                        if !scraped.isEmpty {
                            self.mergePlaylists(scraped)
                            YTMUserOfflineStore.shared.savePlaylists(scraped, for: self.userEmail)
                        }
                    }
                }
            }
        }
    }
    
    private func scanScriptableBrowserTabs() async -> (found: Bool, browser: String, tabTitle: String, tier: YTMAccountTier) {
        guard !isTestingEnvironment else { return (false, "", "", .unknown) }
        
        let chromeRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").isEmpty
        let braveRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.brave.Browser").isEmpty
        let edgeRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.edgemac").isEmpty
        let arcRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "company.thebrowser.Browser").isEmpty
        let safariRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty
        
        guard chromeRunning || braveRunning || edgeRunning || arcRunning || safariRunning else {
            return (false, "", "", .unknown)
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                func runCheck(appName: String, isSafari: Bool = false) -> (title: String, tier: YTMAccountTier)? {
                    let script: String
                    if isSafari {
                        script = """
                        tell application "Safari"
                            repeat with w in windows
                                repeat with t in tabs of w
                                    if (URL of t) contains "music.youtube.com" then
                                        set tabTitle to (title of t)
                                        set isPrem to "false"
                                        try
                                            set isPrem to (do JavaScript "(function() { if (window.ytcfg && typeof ytcfg.get === 'function') { if (ytcfg.get('USER_IS_PREMIUM') === true || ytcfg.get('IS_PREMIUM') === true) return 'true'; var c = ytcfg.get('INNERTUBE_CONTEXT'); if (c && c.user && (c.user.isSubscriptionUser === true || c.user.hasActiveSubscription === true)) return 'true'; } var l = document.querySelector('ytmusic-logo, [aria-label*=\\"Premium\\" i]'); if (l && (l.getAttribute('aria-label')||'').toLowerCase().indexOf('premium') !== -1) return 'true'; return 'false'; })()" in t)
                                        end try
                                        return tabTitle & "|||" & isPrem
                                    end if
                                end repeat
                            end repeat
                        end tell
                        return ""
                        """
                    } else {
                        script = """
                        tell application "\(appName)"
                            repeat with w in windows
                                repeat with t in tabs of w
                                    if (URL of t) contains "music.youtube.com" then
                                        set tabTitle to (title of t)
                                        set isPrem to "false"
                                        try
                                            set isPrem to (execute t javascript "(function() { if (window.ytcfg && typeof ytcfg.get === 'function') { if (ytcfg.get('USER_IS_PREMIUM') === true || ytcfg.get('IS_PREMIUM') === true) return 'true'; var c = ytcfg.get('INNERTUBE_CONTEXT'); if (c && c.user && (c.user.isSubscriptionUser === true || c.user.hasActiveSubscription === true)) return 'true'; } var l = document.querySelector('ytmusic-logo, [aria-label*=\\"Premium\\" i]'); if (l && (l.getAttribute('aria-label')||'').toLowerCase().indexOf('premium') !== -1) return 'true'; return 'false'; })()")
                                        end try
                                        return tabTitle & "|||" & isPrem
                                    end if
                                end repeat
                            end repeat
                        end tell
                        return ""
                        """
                    }
                    guard let raw = MorphAppleScriptRunner.run(script, timeout: 2.0), !raw.isEmpty else { return nil }
                    if raw.contains("|||") {
                        let parts = raw.components(separatedBy: "|||")
                        let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let isPrem = parts.count > 1 && parts[1].trimmingCharacters(in: .whitespacesAndNewlines) == "true"
                        return (title, isPrem ? .premium : .unknown)
                    }
                    return (raw.trimmingCharacters(in: .whitespacesAndNewlines), .unknown)
                }
                
                if chromeRunning, let res = runCheck(appName: "Google Chrome") {
                    continuation.resume(returning: (true, "Chrome", res.title, res.tier))
                    return
                }
                if braveRunning, let res = runCheck(appName: "Brave Browser") {
                    continuation.resume(returning: (true, "Brave", res.title, res.tier))
                    return
                }
                if edgeRunning, let res = runCheck(appName: "Microsoft Edge") {
                    continuation.resume(returning: (true, "Edge", res.title, res.tier))
                    return
                }
                if arcRunning, let res = runCheck(appName: "Arc") {
                    continuation.resume(returning: (true, "Arc", res.title, res.tier))
                    return
                }
                if safariRunning, let res = runCheck(appName: "Safari", isSafari: true) {
                    continuation.resume(returning: (true, "Safari", res.title, res.tier))
                    return
                }
                
                continuation.resume(returning: (false, "", "", .unknown))
            }
        }
    }
    
    private func parseTabTitle(_ rawTitle: String, source: String) {
        guard !engine.trackData.isPlaying, !self.userIntentionallyPaused, !self.isDirectEngineActive else { return }
        self.sourceName = source
        self.isBrowserConnected = true
        self.isSignedIn = true
        
        var clean = rawTitle.replacingOccurrences(of: " - YouTube Music", with: "")
        clean = clean.replacingOccurrences(of: "YouTube Music", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        if clean.isEmpty {
            if self.trackTitle.isEmpty {
                self.trackTitle = "YouTube Music Connected"
                self.artistName = source
            }
            return
        }
        
        if clean.contains(" - ") {
            let parts = clean.components(separatedBy: " - ")
            if parts.count >= 2 {
                self.trackTitle = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                self.artistName = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else if clean.contains(" • ") {
            let parts = clean.components(separatedBy: " • ")
            if parts.count >= 2 {
                self.trackTitle = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                self.artistName = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            self.trackTitle = clean
        }
        if !self.userIntentionallyPaused {
            self.isPlaying = true
        }
        self.syncPlayingTrackWithPlaylists()
    }
    
    private func executeBrowserPlayPause() {
        runBrowserJavaScriptAcrossTabs(
            "var v = document.querySelector('video'); if (v) { if (v.paused || v.ended) { v.play(); } else { v.pause(); } }"
        )
    }
    
    private func executeBrowserPlay() {
        runBrowserJavaScriptAcrossTabs(
            "(function() { var p = document.getElementById('movie_player') || document.querySelector('#movie_player'); if (p && typeof p.playVideo === 'function') { try { p.playVideo(); } catch(e) {} } var v = document.querySelector('video'); if (v && (v.paused || v.ended)) { var pr = v.play(); if (pr && typeof pr.catch === 'function') { pr.catch(function(){ var b = document.querySelector('ytmusic-player-bar #play-pause-button, #play-pause-button'); if (b) { var l = (b.getAttribute('aria-label') || b.getAttribute('title') || '').toLowerCase(); if ((l.indexOf('play') !== -1 || l.indexOf('ph\\u00e1t') !== -1 || l.indexOf('resume') !== -1) && l.indexOf('pause') === -1) { b.click(); } } }); } } })();"
        )
    }
    
    private func executeBrowserPause() {
        runBrowserJavaScriptAcrossTabs(
            "(function() { var p = document.getElementById('movie_player') || document.querySelector('#movie_player'); if (p && typeof p.pauseVideo === 'function') { try { p.pauseVideo(); } catch(e) {} } var v = document.querySelector('video'); if (v && !v.paused) { v.pause(); } })();"
        )
    }
    
    private func executeBrowserStop() {
        runBrowserJavaScriptAcrossTabs(
            "(function() { var p = document.getElementById('movie_player') || document.querySelector('#movie_player'); if (p && typeof p.stopVideo === 'function') { try { p.stopVideo(); } catch(e) {} } var v = document.querySelector('video'); if (v) { v.pause(); v.currentTime = 0; } })();"
        )
    }
    
    private func runBrowserJavaScriptAcrossTabs(_ jsCode: String) {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        let escapedJS = jsCode
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
        let chromiumApps: [(bundleId: String, appName: String)] = [
            ("com.google.Chrome", "Google Chrome"),
            ("com.brave.Browser", "Brave Browser"),
            ("com.microsoft.edgemac", "Microsoft Edge"),
            ("company.thebrowser.Browser", "Arc")
        ]
        var appScripts: [String] = []
        for entry in chromiumApps where !NSRunningApplication.runningApplications(withBundleIdentifier: entry.bundleId).isEmpty {
            appScripts.append("""
            tell application "\(entry.appName)"
                repeat with w in windows
                    repeat with t in tabs of w
                        if (URL of t) contains "music.youtube.com" then
                            try
                                execute t javascript "\(escapedJS)"
                            end try
                        end if
                    end repeat
                end repeat
            end tell
            """)
        }
        if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty {
            appScripts.append("""
            tell application "Safari"
                repeat with w in windows
                    repeat with t in tabs of w
                        if (URL of t) contains "music.youtube.com" then
                            try
                                do JavaScript "\(escapedJS)" in t
                            end try
                        end if
                    end repeat
                end repeat
            end tell
            """)
        }
        guard !appScripts.isEmpty else { return }
        let combinedScript = appScripts.joined(separator: "\n")
        Task.detached(priority: .utility) {
            _ = MorphAppleScriptRunner.run(combinedScript, timeout: 2.5)
        }
    }
    
    private func executeBrowserNextTrack() {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        Self.postSystemMediaKey(key: 19)
        let jsCommand = """
        (function() {
            var confirmButtons = document.querySelectorAll('ytmusic-you-there-renderer #confirm-button, tp-yt-paper-dialog #confirm-button');
            for (var i = 0; i < confirmButtons.length; i++) { confirmButtons[i].click(); }
            var btn = document.querySelector('.next-button') || document.querySelector('ytmusic-player-bar .next-button');
            if (btn) btn.click();
        })();
        """
        runBrowserJavaScriptAcrossTabs(jsCommand)
    }
    
    private func executeBrowserPreviousTrack() {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        Self.postSystemMediaKey(key: 20)
        runBrowserJavaScriptAcrossTabs("document.querySelector('.previous-button') ? document.querySelector('.previous-button').click() : null;")
    }
    
    private func executeBrowserSeek(to seconds: TimeInterval) {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        runBrowserJavaScriptAcrossTabs("var v = document.querySelector('video'); if (v) { v.currentTime = \(seconds); }")
    }
    
    private func executeBrowserVolume(_ vol: Double) {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        runBrowserJavaScriptAcrossTabs("var v = document.querySelector('video'); if (v) { v.volume = \(vol); }")
    }
    
    private func executeBrowserMute(_ muted: Bool) {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        runBrowserJavaScriptAcrossTabs("var v = document.querySelector('video'); if (v) { v.muted = \(muted); }")
    }
    
    private func executeBrowserShuffle(_ enabled: Bool) {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        runBrowserJavaScriptAcrossTabs("(function() { var btn = document.querySelector('ytmusic-player-bar .shuffle') || document.querySelector('#right-controls .shuffle') || document.querySelector('.shuffle'); if (btn) { var inner = btn.querySelector('button, #button') || btn; var cur = btn.getAttribute('aria-pressed') === 'true' || inner.getAttribute('aria-pressed') === 'true' || btn.classList.contains('active'); if (cur !== \(enabled)) { (inner || btn).click(); } } })();")
    }

    private func executeBrowserRepeat(_ mode: YTMRepeatMode) {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        let js = "(function() { var v = document.querySelector('video'); if (v) { v.loop = (\(mode == .one)); } var btn = document.querySelector('ytmusic-player-bar .repeat') || document.querySelector('#right-controls .repeat') || document.querySelector('.repeat'); if (btn) { var inner = btn.querySelector('button, #button') || btn; var getMode = function() { var l = ((btn.getAttribute('aria-label')||'') + ' ' + (inner.getAttribute('aria-label')||'') + ' ' + (btn.getAttribute('title')||'')).toLowerCase(); if (l.indexOf('one')!==-1 || l.indexOf('1')!==-1 || l.indexOf('một')!==-1) return 'one'; if (l.indexOf('all')!==-1 || l.indexOf('tất cả')!==-1) return 'all'; return 'off'; }; var target = '\(mode.rawValue)'; var cur = getMode(); var clicks = 0; if (cur !== target) { if (cur === 'off') clicks = (target === 'all' ? 1 : 2); else if (cur === 'all') clicks = (target === 'one' ? 1 : 2); else if (cur === 'one') clicks = (target === 'off' ? 1 : 2); } for (var i = 0; i < clicks; i++) { (function(d){ setTimeout(function(){ (inner || btn).click(); }, d); })(i * 120); } } })();"
        runBrowserJavaScriptAcrossTabs(js)
    }
    
    public func executeBrowserPlayTrack(videoId: String, listId: String? = nil) {
        guard !isTestingEnvironment else { return }
        let cleanVid = videoId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanVid.isEmpty else { return }
        var targetURL = "https://music.youtube.com/watch?v=\(cleanVid)"
        if let list = listId, !list.isEmpty {
            targetURL += "&list=\(list)"
        }
        runBrowserNavigationAcrossTabs(targetURL: targetURL, videoId: cleanVid)
    }
    
    public func executeBrowserSearch(query: String) {
        guard !isTestingEnvironment else { return }
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clean
        let targetURL = "https://music.youtube.com/search?q=\(encoded)"
        runBrowserNavigationAcrossTabs(targetURL: targetURL, videoId: nil)
    }
    
    private func runBrowserNavigationAcrossTabs(targetURL: String, videoId: String?) {
        guard !isTestingEnvironment else { return }
        let chromiumApps: [(bundleId: String, appName: String)] = [
            ("com.google.Chrome", "Google Chrome"),
            ("com.brave.Browser", "Brave Browser"),
            ("com.microsoft.edgemac", "Microsoft Edge"),
            ("company.thebrowser.Browser", "Arc")
        ]
        
        let jsSnippet: String
        if let vid = videoId, !vid.isEmpty {
            jsSnippet = "(function() { var p = document.getElementById('movie_player'); if (p && typeof p.loadVideoById === 'function') { p.loadVideoById('\(vid)'); } else { window.location.href = '\(targetURL)'; } })();"
        } else {
            jsSnippet = "window.location.href = '\(targetURL)';"
        }
        let escapedJS = jsSnippet
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
        
        var appScripts: [String] = []
        for entry in chromiumApps where !NSRunningApplication.runningApplications(withBundleIdentifier: entry.bundleId).isEmpty {
            appScripts.append("""
            tell application "\(entry.appName)"
                repeat with w in windows
                    repeat with t in tabs of w
                        if (URL of t) contains "music.youtube.com" then
                            try
                                execute t javascript "\(escapedJS)"
                                return
                            on error
                                set URL of t to "\(targetURL)"
                                return
                            end try
                        end if
                    end repeat
                end repeat
            end tell
            """)
        }
        
        if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty {
            appScripts.append("""
            tell application "Safari"
                repeat with w in windows
                    repeat with t in tabs of w
                        if (URL of t) contains "music.youtube.com" then
                            try
                                do JavaScript "\(escapedJS)" in t
                                return
                            on error
                                set URL of t to "\(targetURL)"
                                return
                            end try
                        end if
                    end repeat
                end repeat
            end tell
            """)
        }
        
        guard !appScripts.isEmpty else { return }
        let combinedScript = appScripts.joined(separator: "\n")
        Task.detached(priority: .utility) {
            _ = MorphAppleScriptRunner.run(combinedScript, timeout: 2.5)
        }
    }
    
    private func runScriptAsync(_ scriptSource: String) {
        guard !isTestingEnvironment else { return }
        Task.detached(priority: .utility) {
            _ = MorphAppleScriptRunner.run(scriptSource, timeout: 2.5)
        }
    }
}
