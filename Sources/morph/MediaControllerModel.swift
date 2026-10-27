import SwiftUI
import Combine

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
    @Published public var quickPicks: [YTMPlaylistItem] = []
    @Published public var isLoadingQuickPicks: Bool = false
    @Published public var quickPicksError: String? = nil
    @Published public var isSignedIn: Bool = false
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
    private var lastProcessedQueueIds: [String] = []
    private var lastProcessedTrackSignature: String = ""
    
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
    
    public let engine: YouTubeMusicEngine
    public let systemAudio: SystemAudioServiceProtocol
    
    private var isTestingEnvironment: Bool {
        return MorphEnvironment.isTestingEnvironment
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var visualizerTimer: AnyCancellable?
    private var browserPollTimer: AnyCancellable?
    private var playbackTicker: AnyCancellable?
    
    @Published public var isLoadingPlaylists: Bool = false
    
    // Playlist detail loading + YouTube Music catalog search state
    @Published public var isLoadingTracks: Bool = false
    @Published public var tracksError: String? = nil
    @Published public var libraryError: String? = nil
    @Published public var searchResults: [YTMSearchResult] = []
    @Published public var isSearchingCatalog: Bool = false
    @Published public var catalogSearchError: String? = nil
    @Published public var isWaitingForBrowserSignIn: Bool = false
    @Published public var browserAuthStatusMessage: String? = nil
    private var searchTask: Task<Void, Never>?
    private var trackLoadTask: Task<Void, Never>?
    
    public static let defaultOfflineTracks: [YTMPlaylistItem] = [
        YTMPlaylistItem(
            id: "offline_1",
            title: "Resonance",
            artist: "HOME",
            duration: "3:32",
            isPlaying: false,
            videoId: "8GW6sLrK40k",
            thumbnailURL: "https://i.ytimg.com/vi/8GW6sLrK40k/hqdefault.jpg"
        ),
        YTMPlaylistItem(
            id: "offline_2",
            title: "Midnight City",
            artist: "M83",
            duration: "4:04",
            isPlaying: false,
            videoId: "dX3k_QDnzHE",
            thumbnailURL: "https://i.ytimg.com/vi/dX3k_QDnzHE/hqdefault.jpg"
        ),
        YTMPlaylistItem(
            id: "offline_3",
            title: "Starboy",
            artist: "The Weeknd, Daft Punk",
            duration: "3:50",
            isPlaying: false,
            videoId: "34Na4j8AVgA",
            thumbnailURL: "https://i.ytimg.com/vi/34Na4j8AVgA/hqdefault.jpg"
        ),
        YTMPlaylistItem(
            id: "offline_4",
            title: "After Dark",
            artist: "Mr.Kitty",
            duration: "4:18",
            isPlaying: false,
            videoId: "waAlgFq9Xq8",
            thumbnailURL: "https://i.ytimg.com/vi/waAlgFq9Xq8/hqdefault.jpg"
        ),
        YTMPlaylistItem(
            id: "offline_5",
            title: "Nightcall",
            artist: "Kavinsky",
            duration: "4:19",
            isPlaying: false,
            videoId: "MV_3Dpw-BRY",
            thumbnailURL: "https://i.ytimg.com/vi/MV_3Dpw-BRY/hqdefault.jpg"
        )
    ]
    
    public init(
        engine: YouTubeMusicEngine = YouTubeMusicEngine.shared,
        systemAudio: SystemAudioServiceProtocol = MorphEnvironment.isTestingEnvironment ? MockSystemAudioService() : SystemAudioService.shared,
        networkMonitor: NetworkMonitor = NetworkMonitor.shared
    ) {
        self.engine = engine
        self.systemAudio = systemAudio
        self.networkMonitor = networkMonitor
        self.isOffline = !networkMonitor.isConnected
        self.downloadedTracks = Self.defaultOfflineTracks
        self.playlists = []
        self.quickPicks = engine.quickPicks.isEmpty ? YTMParser.defaultQuickPicks : engine.quickPicks
        
        let initialVol = systemAudio.getVolume()
        let initialMuted = systemAudio.getMuted()
        self.volume = max(0.0, min(1.0, initialVol))
        self.isMuted = initialMuted
        
        setupEngineObservers()
        setupSystemAudioObserver()
        setupNetworkObserver()
        scanLocalDownloads()
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
                    guard let self = self, self.isPlaying else { return }
                    // Only advance artificial ticker if completely in offline demo mode.
                    // Never fight real WebKit or browser streams!
                    if !self.isDirectEngineConnected && !self.isBrowserConnected {
                        if self.currentTime < self.duration {
                            self.currentTime += 1
                        } else {
                            if self.repeatMode == .one {
                                self.currentTime = 0
                            } else {
                                self.nextTrack()
                            }
                        }
                    } else if self.isDirectEngineConnected {
                        // Watchdog auto-advance: if playback finishes and engine is at duration end
                        if self.duration > 0 && self.currentTime >= (self.duration - 0.5) {
                            if self.repeatMode == .one {
                                // Smoothly loop single track back to start
                                self.currentTime = 0
                                self.seek(to: 0)
                            } else {
                                self.nextTrack()
                            }
                        }
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
                
                // If YouTube Music is playing or has track data, prioritize direct engine
                if !data.title.isEmpty && data.title != "YouTube Music" && data.duration > 0 {
                    self.trackTitle = data.title
                    self.artistName = data.artist.isEmpty ? "YouTube Music" : data.artist
                    self.albumArtURL = data.albumArtURL
                    self.isPlaying = data.isPlaying
                    if let seekTime = self.lastSeekToZeroTime, Date().timeIntervalSince(seekTime) < 1.8 {
                        // In-flight seek-to-zero lockout: protect against stale updates
                        if data.currentTime > 3.0 && data.title == self.trackTitle {
                            // ignore stale pre-seek currentTime
                        } else {
                            self.currentTime = data.currentTime
                            if data.currentTime <= 1.0 {
                                self.lastSeekToZeroTime = nil
                            }
                        }
                    } else {
                        self.currentTime = data.currentTime
                    }
                    self.duration = data.duration
                    // Auto-correct YouTube Music player if web player drifted from the correlated volume
                    if abs(data.volume - self.volume) > 0.08 && !self.isTestingEnvironment && self.duration > 0 {
                        if self.isDirectEngineActive {
                            self.engine.setVolume(self.volume)
                        }
                    }
                    if data.isMuted != self.isMuted && !self.isTestingEnvironment && self.duration > 0 {
                        if self.isDirectEngineActive {
                            self.engine.setMuted(self.isMuted)
                        }
                    }
                    self.isLiked = data.isLiked
                    self.isDisliked = data.isDisliked
                    self.isShuffle = data.isShuffle
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
                    }
                    self.sourceName = "YouTube Music Direct"
                    self.isDirectEngineConnected = true
                    
                    let currentSignature = "\(data.title)|\(data.artist)|\(data.isPlaying)"
                    let trackChanged = (currentSignature != self.lastProcessedTrackSignature)
                    if queueChanged || trackChanged {
                        self.lastProcessedTrackSignature = currentSignature
                        self.syncPlayingTrackWithPlaylists()
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
                    if self.playlists.isEmpty {
                        self.refreshPlaylists()
                    }
                    if self.quickPicks.isEmpty {
                        self.refreshQuickPicks()
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
            .receive(on: DispatchQueue.main)
            .sink { [weak self] picks in
                guard let self = self else { return }
                if !picks.isEmpty {
                    self.quickPicks = picks
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
            .removeDuplicates()
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                self?.runCatalogSearch(query)
            }
            .store(in: &cancellables)
    }
    
    /// Merges incoming playlists by id, keeping any tracks that were already loaded.
    func mergePlaylists(_ incoming: [YTMPlaylist]) {
        var merged = playlists
        for ep in incoming {
            if let idx = merged.firstIndex(where: { $0.id == ep.id }) {
                var updated = ep
                if updated.tracks.isEmpty { updated.tracks = merged[idx].tracks }
                if updated.playbackListId == nil { updated.playbackListId = merged[idx].playbackListId }
                merged[idx] = updated
            } else {
                merged.append(ep)
            }
        }
        playlists = merged
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
    
    public func play() {
        isPlaying = true
        if isDirectEngineActive || isDirectEngineConnected || !isBrowserConnected {
            engine.play()
            engine.setVolume(volume)
            if isMuted {
                engine.setMuted(true)
            }
        } else {
            executeBrowserPlay()
        }
    }
    
    public func pause() {
        isPlaying = false
        if isDirectEngineActive || isDirectEngineConnected || !isBrowserConnected {
            engine.pause()
        } else {
            executeBrowserPause()
        }
    }
    
    public func stop() {
        isPlaying = false
        currentTime = 0
        if isDirectEngineActive || isDirectEngineConnected || !isBrowserConnected {
            engine.stop()
        } else {
            executeBrowserStop()
        }
    }
    
    public func togglePlay() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    public func nextTrack() {
        if isDirectEngineActive {
            if repeatMode == .all {
                if let sel = selectedPlaylist, !sel.tracks.isEmpty {
                    let activeId = activeTrackId(in: sel.tracks)
                    if let currentIdx = sel.tracks.firstIndex(where: { $0.isPlaying || ($0.id == activeId && activeId != nil) }),
                       currentIdx == sel.tracks.count - 1 {
                        let firstItem = sel.tracks[0]
                        playSongInSelectedPlaylist(firstItem)
                        return
                    }
                } else if !playlist.isEmpty {
                    let activeId = activeTrackId(in: playlist)
                    if let currentIdx = playlist.firstIndex(where: { $0.isPlaying || ($0.id == activeId && activeId != nil) }),
                       currentIdx == playlist.count - 1 {
                        let firstItem = playlist[0]
                        markPlaying(firstItem)
                        if let qIdx = Int(firstItem.id) {
                            engine.playQueueIndex(qIdx)
                        } else {
                            engine.playQueueIndex(0)
                        }
                        return
                    }
                }
            }
            engine.nextTrack()
            return
        }
        
        // Continuous Playback: If we have an active playlist or queue, advance to next track
        if let sel = selectedPlaylist, !sel.tracks.isEmpty {
            let activeId = activeTrackId(in: sel.tracks)
            if let currentIdx = sel.tracks.firstIndex(where: { $0.isPlaying || ($0.id == activeId && activeId != nil) }) {
                let nextIdx = currentIdx + 1
                if nextIdx < sel.tracks.count {
                    let nextItem = sel.tracks[nextIdx]
                    playSongInSelectedPlaylist(nextItem)
                    return
                } else if repeatMode == .all {
                    // Loop back to start
                    let firstItem = sel.tracks[0]
                    playSongInSelectedPlaylist(firstItem)
                    return
                }
            }
        } else if !playlist.isEmpty {
            let activeId = activeTrackId(in: playlist)
            if let currentIdx = playlist.firstIndex(where: { $0.isPlaying || ($0.id == activeId && activeId != nil) }) {
                let nextIdx = currentIdx + 1
                if nextIdx < playlist.count {
                    let nextItem = playlist[nextIdx]
                    playQueueTrack(nextItem)
                    return
                } else if repeatMode == .all {
                    let firstItem = playlist[0]
                    playQueueTrack(firstItem)
                    return
                }
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
                        if let qIdx = Int(prevItem.id) {
                            engine.playQueueIndex(qIdx)
                        } else {
                            engine.playQueueIndex(prevIdx)
                        }
                    } else {
                        playQueueTrack(prevItem)
                    }
                    return
                } else if repeatMode == .all {
                    let lastIdx = playlist.count - 1
                    let lastItem = playlist[lastIdx]
                    markPlaying(lastItem)
                    if isDirectEngineActive {
                        if let qIdx = Int(lastItem.id) {
                            engine.playQueueIndex(qIdx)
                        } else {
                            engine.playQueueIndex(lastIdx)
                        }
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
        isPlaying = true
        engine.playVibe(vibe)
    }
    
    public func playSearch(_ query: String) {
        if isOffline {
            triggerOfflineHandling(for: query)
            return
        }
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
    
    public func setVolume(_ newVol: Double) {
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
        Publishers.CombineLatest(networkMonitor.$isConnected, engine.$isOffline)
            .sink { [weak self] isConnected, engineOffline in
                guard let self = self else { return }
                let currentlyOffline = !isConnected || engineOffline
                let prevOffline = self.isOffline
                self.isOffline = currentlyOffline
                
                if currentlyOffline && !prevOffline {
                    self.offlineHUDMessage = "No Internet Connection"
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
        let query = playlistSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return playlists
        }
        return playlists.filter {
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
        
        selectedPlaylist = p
        rightDeckSection = .playlists
        isSearchingSongs = false
        songSearchQuery = ""
        tracksError = nil
        trackLoadTask?.cancel()
        syncPlayingTrackWithPlaylists()
        
        // The live queue is mirrored from the player; everything else is fetched natively.
        guard p.id != "pl_queue", p.kind != .queue else {
            isLoadingTracks = false
            return
        }
        // Already loaded (cached) → show immediately.
        guard p.tracks.isEmpty else {
            isLoadingTracks = false
            return
        }
        loadTracksForSelectedPlaylist()
    }
    
    /// Fetches the real tracks (playlist, album or artist) of `selectedPlaylist` from YouTube Music.
    public func loadTracksForSelectedPlaylist() {
        guard let pl = selectedPlaylist, pl.id != "pl_queue", pl.kind != .queue else { return }
        trackLoadTask?.cancel()
        isLoadingTracks = true
        tracksError = nil
        trackLoadTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let page = try await self.engine.loadTracks(for: pl)
                guard !Task.isCancelled, self.selectedPlaylist?.id == pl.id else { return }
                self.applyLoadedTracks(page, to: pl)
                self.tracksError = page.tracks.isEmpty ? "No songs found in this \(pl.kind == .artist ? "artist" : "playlist")." : nil
            } catch {
                guard !Task.isCancelled, self.selectedPlaylist?.id == pl.id else { return }
                self.tracksError = error.localizedDescription
            }
            self.isLoadingTracks = false
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
        if updated.kind == .playlist, playlists.contains(where: { $0.id == updated.id }) {
            mergePlaylists([updated])
        }
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
        Task { @MainActor in
            await engine.refreshQuickPicks()
        }
    }
    
    public func playQuickPick(_ track: YTMPlaylistItem, startRadio: Bool = true) {
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
        trackTitle = track.title
        artistName = track.artist.isEmpty ? "YouTube Music" : track.artist
        albumArtURL = track.thumbnailURL
        isPlaying = true
        currentTime = 0
        duration = 0
        
        for i in 0..<quickPicks.count {
            quickPicks[i].isPlaying = (quickPicks[i].id == track.id || quickPicks[i].videoId == vid)
        }
        
        let radioListId = startRadio ? "RDAMVM\(vid)" : nil
        engine.play(videoId: vid, listId: radioListId)
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
    public func switchRightDeck(to section: YTMRightDeckSection) {
        switch section {
        case .home: openHubHome()
        case .playlists: openPlaylistsSection()
        case .queue: openQueueSection()
        case .downloads: openDownloadsSection()
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
        
        offlineHUDMessage = "Offline • Switched to Downloads"
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
        artistName = item.artist.isEmpty ? "Local Download" : item.artist
        albumArtURL = item.thumbnailURL
        currentTime = 0
        duration = 210
        isPlaying = true
        sourceName = "Offline Downloads"
        
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
    
    public func scanLocalDownloads() {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        Task { [weak self] in
            let fileManager = FileManager.default
            var localItems: [YTMPlaylistItem] = []
            let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac"]
            let directories = [
                fileManager.urls(for: .musicDirectory, in: .userDomainMask).first,
                fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ].compactMap { $0 }
            
            for dir in directories {
                if let contents = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    for url in contents {
                        if audioExtensions.contains(url.pathExtension.lowercased()) {
                            let fileName = url.deletingPathExtension().lastPathComponent
                            let parts = fileName.components(separatedBy: " - ")
                            let artist = parts.count > 1 ? parts[0] : "Local Audio"
                            let title = parts.count > 1 ? parts[1] : fileName
                            let item = YTMPlaylistItem(
                                id: "local_\(url.lastPathComponent)",
                                title: title,
                                artist: artist,
                                duration: "Local",
                                isPlaying: false,
                                videoId: nil,
                                thumbnailURL: nil
                            )
                            localItems.append(item)
                        }
                    }
                }
            }
            if !localItems.isEmpty {
                await MainActor.run {
                    var merged = Self.defaultOfflineTracks
                    for itm in localItems {
                        if !merged.contains(where: { $0.title == itm.title }) {
                            merged.append(itm)
                        }
                    }
                    self?.downloadedTracks = merged
                }
            }
        }
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
        guard let sel = selectedPlaylist, sel.kind != .artist, sel.kind != .queue, sel.id != "pl_queue" else { return nil }
        let raw = sel.playbackListId ?? (sel.kind == .playlist ? sel.id : nil)
        guard let r = raw else { return nil }
        return r.hasPrefix("VL") ? String(r.dropFirst(2)) : r
    }
    
    private func markPlaying(_ item: YTMPlaylistItem) {
        trackTitle = item.title
        if !item.artist.isEmpty {
            artistName = item.artist
        }
        currentTime = 0
        isPlaying = true
        for i in 0..<playlist.count {
            playlist[i].isPlaying = (playlist[i].id == item.id || (playlist[i].title == item.title && playlist[i].artist == item.artist))
        }
        syncPlayingTrackWithPlaylists()
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
    
    /// Resolves the single active track ID inside a given list of tracks.
    /// Strictly guarantees at most ONE track can ever be identified as active.
    public func activeTrackId(in tracks: [YTMPlaylistItem]) -> String? {
        guard !tracks.isEmpty else { return nil }
        
        let currentTitleClean = Self.normalizeTitle(trackTitle)
        let currentArtistClean = artistName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Active queue item videoId (if available and matching current trackTitle)
        let activeQueueVideoId: String? = {
            if let qItem = playlist.first(where: { $0.isPlaying }),
               let vid = qItem.videoId, !vid.isEmpty,
               (currentTitleClean.isEmpty || Self.normalizeTitle(qItem.title) == currentTitleClean) {
                return vid
            }
            return nil
        }()
        
        // Tier 1: Match by videoId with active queue track
        if let targetVid = activeQueueVideoId {
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
            if changed {
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
        if selectedPlaylist?.id == "pl_downloads" {
            playDownloadedTrack(item)
            return
        }
        if isOffline {
            triggerOfflineHandling(for: item.title)
            return
        }
        markPlaying(item)
        
        if selectedPlaylist?.id == "pl_queue" || rightDeckSection == .queue {
            // Live queue: play by exact queue index or fallback to direct videoId
            if let idx = Int(item.id) {
                engine.playQueueIndex(idx)
            } else if let matchIdx = effectivePlaylist.firstIndex(where: { $0.id == item.id }) {
                engine.playQueueIndex(matchIdx)
            } else if let matchIdx = playlist.firstIndex(where: { $0.id == item.id || ($0.title == item.title && $0.artist == item.artist) }) {
                engine.playQueueIndex(matchIdx)
            } else if let vid = item.videoId, !vid.isEmpty {
                engine.play(videoId: vid)
            } else {
                playSearch("\(item.title) \(item.artist)")
            }
        } else if let vid = item.videoId, !vid.isEmpty {
            // Direct playback of the exact clicked track in the playlist container
            engine.play(videoId: vid, listId: selectedPlaybackListId)
        } else {
            // Never blindly click random DOM list items on unrelated pages; search and play exact track
            playSearch("\(item.title) \(item.artist)")
        }
    }
    
    public func playEntireSelectedPlaylist() {
        guard let sel = selectedPlaylist, let first = sel.tracks.first else { return }
        if sel.id == "pl_downloads" {
            playDownloadedTrack(first)
            return
        }
        if isOffline {
            triggerOfflineHandling(for: sel.title)
            return
        }
        if let vid = first.videoId, sel.id != "pl_queue" {
            markPlaying(first)
            engine.play(videoId: vid, listId: selectedPlaybackListId)
            return
        }
        playSongInSelectedPlaylist(first)
        engine.playEntirePlaylist()
    }
    
    public func refreshPlaylists() {
        isLoadingPlaylists = true
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.engine.refreshLibraryPlaylists()
            self.isLoadingPlaylists = false
        }
    }
    
    // MARK: - YouTube Music catalog search (songs / artists / albums / playlists)
    func runCatalogSearch(_ rawQuery: String) {
        searchTask?.cancel()
        let q = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else {
            searchResults = []
            isSearchingCatalog = false
            catalogSearchError = nil
            return
        }
        isSearchingCatalog = true
        catalogSearchError = nil
        searchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let results = try await self.engine.searchCatalog(q)
                guard !Task.isCancelled,
                      self.playlistSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == q else { return }
                self.searchResults = results
                self.catalogSearchError = results.isEmpty ? "No results on YouTube Music for \"\(q)\"." : nil
            } catch {
                guard !Task.isCancelled,
                      self.playlistSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == q else { return }
                self.searchResults = []
                self.catalogSearchError = error.localizedDescription
            }
            self.isSearchingCatalog = false
        }
    }
    
    /// Search results grouped like the YouTube Music results page (top result first, then Songs, Artists, Albums, Playlists, Videos).
    public var groupedSearchResults: [(kind: YTMSearchKind, items: [YTMSearchResult])] {
        let order: [YTMSearchKind] = [.song, .artist, .album, .playlist, .video]
        return order.compactMap { k in
            let items = searchResults.filter { $0.kind == k }
            return items.isEmpty ? nil : (kind: k, items: Array(items.prefix(k == .song ? 6 : 4)))
        }
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
            trackTitle = track.title
            if !track.artist.isEmpty { artistName = track.artist }
            currentTime = 0
            isPlaying = true
            if let vid = track.videoId { engine.play(videoId: vid) }
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
    
    public func clearPlaylistSearch() {
        searchTask?.cancel()
        playlistSearchQuery = ""
        searchResults = []
        isSearchingCatalog = false
        catalogSearchError = nil
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
        if downloadedTracks.contains(where: { $0.id == item.id }) {
            playDownloadedTrack(item)
            return
        }
        if isOffline {
            triggerOfflineHandling(for: item.title)
            return
        }
        trackTitle = item.title
        artistName = item.artist
        currentTime = 0
        isPlaying = true
        
        if let idx = Int(item.id) {
            engine.playQueueIndex(idx)
        } else if let matchIdx = playlist.firstIndex(where: { $0.id == item.id }) {
            engine.playQueueIndex(matchIdx)
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
    
    public func toggleShuffle() {
        isShuffle.toggle()
        engine.toggleShuffle()
    }
    
    public func setRepeatMode(_ newMode: YTMRepeatMode) {
        repeatMode = newMode
        repeatModeLockoutUntil = Date().addingTimeInterval(1.5)
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
    
    // MARK: - Browser-Based Authentication & Tab Management
    public func openSignIn() {
        isWaitingForBrowserSignIn = true
        browserAuthStatusMessage = "Opened YouTube Music sign-in tab in your browser. Once signed in, you can close that tab and play directly from Morph."
        engine.openSignInInBrowser()
    }
    
    public func openInBrowser() {
        engine.openYouTubeMusicInBrowser()
    }
    
    public func syncSessionFromBrowser() {
        browserAuthStatusMessage = "Syncing session from browser tab..."
        engine.syncSessionFromBrowser()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            if self?.engine.isSignedIn == true {
                self?.browserAuthStatusMessage = "Connected! You can now close your browser tab."
                self?.isWaitingForBrowserSignIn = false
            } else {
                self?.browserAuthStatusMessage = "No active session detected. Please sign in via the browser tab first."
            }
        }
    }
    
    public func openPlayerWindow() {
        if !isSignedIn {
            openSignIn()
        } else {
            openInBrowser()
        }
    }
    
    // MARK: - Ambient Visualizer
    private func startVisualizer() {
        visualizerTimer = Timer.publish(every: 0.12, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.isPlaying && !self.isMuted {
                    self.visualizerBars = [
                        CGFloat.random(in: 0.25...0.95),
                        CGFloat.random(in: 0.45...1.0),
                        CGFloat.random(in: 0.20...0.85)
                    ]
                } else {
                    self.visualizerBars = [0.18, 0.18, 0.18]
                }
            }
    }
    
    // MARK: - Fallback Browser AppleScript Bridge (When external browser is used)
    private func startBrowserPolling() {
        browserPollTimer = Timer.publish(every: 8.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    // Only poll external browser if direct engine is idle and not connected
                    if let self = self, !self.isTestingEnvironment, !self.engine.trackData.isPlaying, !self.isDirectEngineConnected {
                        await self.pollBrowserState()
                    }
                }
            }
    }
    
    private func pollBrowserState() async {
        guard !isTestingEnvironment else { return }
        
        // Fast, non-blocking check using Cocoa NSRunningApplication
        let chromeRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").isEmpty
        let safariRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty
        guard chromeRunning || safariRunning else { return }
        
        // Run off-main asynchronously so the main thread and UI runloop are never blocked
        let result: String = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var script = ""
                if chromeRunning {
                    script = """
                    tell application "Google Chrome"
                        repeat with w in windows
                            repeat with t in tabs of w
                                if (URL of t) contains "music.youtube.com" then
                                    return "CHROME_YTM:" & (title of t)
                                end if
                            end repeat
                        end repeat
                    end tell
                    return "NONE"
                    """
                } else if safariRunning {
                    script = """
                    tell application "Safari"
                        repeat with w in windows
                            repeat with t in tabs of w
                                if (URL of t) contains "music.youtube.com" then
                                    return "SAFARI_YTM:" & (name of t)
                                end if
                            end repeat
                        end repeat
                    end tell
                    return "NONE"
                    """
                }
                
                guard let appleScript = NSAppleScript(source: script) else {
                    continuation.resume(returning: "NONE")
                    return
                }
                var error: NSDictionary?
                let res = appleScript.executeAndReturnError(&error).stringValue ?? "NONE"
                continuation.resume(returning: res)
            }
        }
        
        guard !engine.trackData.isPlaying else { return }
        
        if result.starts(with: "CHROME_YTM:") {
            let rawTitle = result.replacingOccurrences(of: "CHROME_YTM:", with: "")
            parseTabTitle(rawTitle, source: "YouTube Music • Chrome")
        } else if result.starts(with: "SAFARI_YTM:") {
            let rawTitle = result.replacingOccurrences(of: "SAFARI_YTM:", with: "")
            parseTabTitle(rawTitle, source: "YouTube Music • Safari")
        }
    }
    
    private func parseTabTitle(_ rawTitle: String, source: String) {
        guard !engine.trackData.isPlaying else { return }
        self.sourceName = source
        self.isBrowserConnected = true
        
        var clean = rawTitle.replacingOccurrences(of: " - YouTube Music", with: "")
        clean = clean.replacingOccurrences(of: "YouTube Music", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        if clean.isEmpty { return }
        
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
        self.syncPlayingTrackWithPlaylists()
    }
    
    private func executeBrowserPlayPause() {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        let script = """
        tell application "Google Chrome"
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t) contains "music.youtube.com" then
                        try
                            execute t javascript "document.querySelector('video') ? (document.querySelector('video').paused ? document.querySelector('video').play() : document.querySelector('video').pause()) : null;"
                        end try
                    end if
                end repeat
            end repeat
        end tell
        """
        runScriptAsync(script)
    }
    
    private func executeBrowserPlay() {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        let script = """
        tell application "Google Chrome"
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t) contains "music.youtube.com" then
                        try
                            execute t javascript "var v = document.querySelector('video'); if (v && v.paused) { v.play(); }"
                        end try
                    end if
                end repeat
            end repeat
        end tell
        """
        runScriptAsync(script)
    }
    
    private func executeBrowserPause() {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        let script = """
        tell application "Google Chrome"
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t) contains "music.youtube.com" then
                        try
                            execute t javascript "var v = document.querySelector('video'); if (v) { v.pause(); }"
                        end try
                    end if
                end repeat
            end repeat
        end tell
        """
        runScriptAsync(script)
    }
    
    private func executeBrowserStop() {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        let script = """
        tell application "Google Chrome"
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t) contains "music.youtube.com" then
                        try
                            execute t javascript "var v = document.querySelector('video'); if (v) { v.pause(); v.currentTime = 0; }"
                        end try
                    end if
                end repeat
            end repeat
        end tell
        """
        runScriptAsync(script)
    }
    
    private func executeBrowserNextTrack() {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        let jsCommand = """
        (function() {
            var confirmButtons = document.querySelectorAll('ytmusic-you-there-renderer #confirm-button, tp-yt-paper-dialog #confirm-button');
            for (var i = 0; i < confirmButtons.length; i++) { confirmButtons[i].click(); }
            var btn = document.querySelector('.next-button') || document.querySelector('ytmusic-player-bar .next-button');
            if (btn) btn.click();
        })();
        """
        let escapedJS = jsCommand.replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: " ")
        let script = """
        tell application "Google Chrome"
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
        """
        runScriptAsync(script)
    }
    
    private func executeBrowserPreviousTrack() {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        let script = """
        tell application "Google Chrome"
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t) contains "music.youtube.com" then
                        try
                            execute t javascript "document.querySelector('.previous-button') ? document.querySelector('.previous-button').click() : null;"
                        end try
                    end if
                end repeat
            end repeat
        end tell
        """
        runScriptAsync(script)
    }
    
    private func executeBrowserSeek(to seconds: TimeInterval) {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        let script = """
        tell application "Google Chrome"
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t) contains "music.youtube.com" then
                        try
                            execute t javascript "var v = document.querySelector('video'); if (v) { v.currentTime = \(seconds); }"
                        end try
                    end if
                end repeat
            end repeat
        end tell
        """
        runScriptAsync(script)
    }
    
    private func executeBrowserVolume(_ vol: Double) {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        let script = """
        tell application "Google Chrome"
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t) contains "music.youtube.com" then
                        try
                            execute t javascript "var v = document.querySelector('video'); if (v) { v.volume = \(vol); }"
                        end try
                    end if
                end repeat
            end repeat
        end tell
        """
        runScriptAsync(script)
    }
    
    private func executeBrowserMute(_ muted: Bool) {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        let script = """
        tell application "Google Chrome"
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t) contains "music.youtube.com" then
                        try
                            execute t javascript "var v = document.querySelector('video'); if (v) { v.muted = \(muted); }"
                        end try
                    end if
                end repeat
            end repeat
        end tell
        """
        runScriptAsync(script)
    }
    
    private func executeBrowserRepeat(_ mode: YTMRepeatMode) {
        guard !isDirectEngineActive && !isTestingEnvironment else { return }
        let script = """
        tell application "Google Chrome"
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t) contains "music.youtube.com" then
                        try
                            execute t javascript "(function() { var v = document.querySelector('video'); if (v) { v.loop = (\(mode == .one)); } var btn = document.querySelector('ytmusic-player-bar .repeat') || document.querySelector('#right-controls .repeat') || document.querySelector('.repeat'); if (btn) { var inner = btn.querySelector('button, #button'); (inner || btn).click(); } })();"
                        end try
                    end if
                end repeat
            end repeat
        end tell
        """
        runScriptAsync(script)
    }
    
    private func runScriptAsync(_ scriptSource: String) {
        guard !isTestingEnvironment else { return }
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").isEmpty else { return }
        
        Task.detached(priority: .utility) {
            var error: NSDictionary?
            if let script = NSAppleScript(source: scriptSource) {
                script.executeAndReturnError(&error)
            }
        }
    }
}
