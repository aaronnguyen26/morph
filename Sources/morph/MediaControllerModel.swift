import SwiftUI
import Combine

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
    @Published public var isSignedIn: Bool = false
    @Published public var selectedPlaylist: YTMPlaylist? = nil
    @Published public var isSearchingPlaylists: Bool = false
    @Published public var playlistSearchQuery: String = ""
    @Published public var isSearchingSongs: Bool = false
    @Published public var songSearchQuery: String = ""
    @Published public var showVolumeHUD: Bool = false
    private var volumeHUDWorkItem: DispatchWorkItem?
    
    // Ambient 3-bar equalizer heights (0.15 ... 1.0)
    @Published public var visualizerBars: [CGFloat] = [0.18, 0.18, 0.18]
    
    public let engine: YouTubeMusicEngine
    
    private var isTestingEnvironment: Bool {
        return ProcessInfo.processInfo.processName.contains("xctest") ||
            ProcessInfo.processInfo.arguments.contains(where: { $0.contains("xctest") }) ||
            ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
            NSClassFromString("XCTestCase") != nil
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
    private var searchTask: Task<Void, Never>?
    private var trackLoadTask: Task<Void, Never>?
    
    public init(engine: YouTubeMusicEngine = YouTubeMusicEngine.shared) {
        self.engine = engine
        self.playlists = []
        
        setupEngineObservers()
        if !isTestingEnvironment {
            startVisualizer()
            startPlaybackTicker()
            startBrowserPolling()
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
                            self.nextTrack()
                        }
                    } else if self.isDirectEngineConnected {
                        // Watchdog auto-advance: if playback finishes and engine is at duration end
                        if self.duration > 0 && self.currentTime >= (self.duration - 0.5) {
                            self.nextTrack()
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
                    self.currentTime = data.currentTime
                    self.duration = data.duration
                    self.volume = data.volume
                    self.isMuted = data.isMuted
                    self.isLiked = data.isLiked
                    self.isDisliked = data.isDisliked
                    self.isShuffle = data.isShuffle
                    self.repeatMode = data.repeatMode
                    self.playlist = data.queue
                    self.sourceName = "YouTube Music Direct"
                    self.isDirectEngineConnected = true
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
                    updated.tracks = data.queue
                    self.selectedPlaylist = updated
                }
            }
            .store(in: &cancellables)
            
        engine.$isSignedIn
            .sink { [weak self] signedIn in
                guard let self = self else { return }
                let prev = self.isSignedIn
                self.isSignedIn = signedIn
                if signedIn && !prev && self.playlists.isEmpty {
                    self.refreshPlaylists()
                }
            }
            .store(in: &cancellables)
            
        engine.$userPlaylists
            .sink { [weak self] enginePlaylists in
                guard let self = self, !enginePlaylists.isEmpty else { return }
                self.mergePlaylists(enginePlaylists)
            }
            .store(in: &cancellables)
        
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
        if isDirectEngineActive {
            engine.play()
        } else if isBrowserConnected {
            executeBrowserPlay()
            Self.postSystemMediaKey(key: 16)
        } else {
            // Kick off playback in direct engine and browser
            engine.play()
            executeBrowserPlay()
            Self.postSystemMediaKey(key: 16)
        }
    }
    
    public func pause() {
        isPlaying = false
        engine.pause()
        executeBrowserPause()
        if !isDirectEngineActive && isBrowserConnected {
            Self.postSystemMediaKey(key: 16)
        }
    }
    
    public func stop() {
        isPlaying = false
        currentTime = 0
        engine.stop()
        executeBrowserStop()
        if !isDirectEngineActive && isBrowserConnected {
            Self.postSystemMediaKey(key: 16)
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
            engine.nextTrack()
        } else if isBrowserConnected {
            executeBrowserNextTrack()
            Self.postSystemMediaKey(key: 19)
        } else {
            engine.nextTrack()
            executeBrowserNextTrack()
            Self.postSystemMediaKey(key: 19)
        }
    }
    
    public func previousTrack() {
        if isDirectEngineActive {
            engine.previousTrack()
        } else if isBrowserConnected {
            executeBrowserPreviousTrack()
            Self.postSystemMediaKey(key: 20)
        } else {
            engine.previousTrack()
            executeBrowserPreviousTrack()
            Self.postSystemMediaKey(key: 20)
            currentTime = 0
        }
    }
    
    public func playQuickVibe(_ vibe: String) {
        isPlaying = true
        engine.playVibe(vibe)
    }
    
    public func playSearch(_ query: String) {
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
    
    public func setVolume(_ newVol: Double) {
        volume = max(0, min(1, newVol))
        if volume > 0 && isMuted {
            isMuted = false
        }
        if isDirectEngineActive {
            engine.setVolume(volume)
        }
        executeBrowserVolume(volume)
        triggerVolumeHUD()
    }
    
    public func toggleMute() {
        isMuted.toggle()
        if isDirectEngineActive {
            engine.toggleMute()
        }
        executeBrowserMute(isMuted)
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
        let list = pl.tracks
        let query = songSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            return list
        }
        return list.filter {
            $0.title.lowercased().contains(query) || $0.artist.lowercased().contains(query)
        }
    }
    
    public func selectPlaylist(_ pl: YTMPlaylist) {
        selectedPlaylist = pl
        isSearchingSongs = false
        songSearchQuery = ""
        tracksError = nil
        trackLoadTask?.cancel()
        
        // The live queue is mirrored from the player; everything else is fetched natively.
        guard pl.id != "pl_queue", pl.kind != .queue else {
            isLoadingTracks = false
            return
        }
        // Already loaded (cached) → show immediately.
        guard pl.tracks.isEmpty else {
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
        updated.tracks = page.tracks.map { t in
            var t = t
            t.isPlaying = (t.title == trackTitle && isPlaying)
            return t
        }
        updated.trackCount = page.tracks.count
        if let list = page.playbackListId { updated.playbackListId = list }
        selectedPlaylist = updated
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
    }
    
    /// `list=` parameter for starting playback inside the currently opened container (artists play as radio).
    private var selectedPlaybackListId: String? {
        guard let sel = selectedPlaylist, sel.kind != .artist, sel.kind != .queue, sel.id != "pl_queue" else { return nil }
        return sel.playbackListId ?? (sel.kind == .playlist ? sel.id : nil)
    }
    
    private func markPlaying(_ item: YTMPlaylistItem) {
        trackTitle = item.title
        if !item.artist.isEmpty {
            artistName = item.artist
        }
        currentTime = 0
        isPlaying = true
        
        if var sel = selectedPlaylist {
            for i in 0..<sel.tracks.count {
                sel.tracks[i].isPlaying = (sel.tracks[i].id == item.id)
            }
            selectedPlaylist = sel
        }
    }
    
    public func playSongInSelectedPlaylist(_ item: YTMPlaylistItem) {
        markPlaying(item)
        
        if selectedPlaylist?.id == "pl_queue" {
            if let matchIdx = selectedPlaylist?.tracks.firstIndex(where: { $0.id == item.id }) {
                engine.playQueueIndex(matchIdx)
            }
        } else if let vid = item.videoId {
            engine.play(videoId: vid, listId: selectedPlaybackListId)
        } else if let idx = Int(item.id) {
            engine.playPlaylistSong(index: idx)
        } else if let matchIdx = selectedPlaylist?.tracks.firstIndex(where: { $0.id == item.id }) {
            engine.playPlaylistSong(index: matchIdx)
        } else {
            playSearch("\(item.title) \(item.artist)")
        }
    }
    
    public func playEntireSelectedPlaylist() {
        guard let sel = selectedPlaylist, let first = sel.tracks.first else { return }
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
        return playlist
    }
    
    public func playQueueTrack(_ item: YTMPlaylistItem) {
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
    
    public func toggleRepeat() {
        switch repeatMode {
        case .off:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .off
        }
        engine.toggleRepeat()
    }
    
    public func openPlayerWindow() {
        engine.showPlayerWindow()
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
        browserPollTimer = Timer.publish(every: 3.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    // Only poll external browser if direct engine is idle
                    if let self = self, !self.engine.trackData.isPlaying {
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
        let script = """
        tell application "Google Chrome"
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t) contains "music.youtube.com" then
                        try
                            execute t javascript "document.querySelector('.next-button') ? document.querySelector('.next-button').click() : null;"
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
