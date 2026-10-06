import SwiftUI
import Combine

@MainActor
public final class MediaControllerModel: ObservableObject {
    @Published public var trackTitle: String = "Starboy"
    @Published public var artistName: String = "The Weeknd • Daft Punk"
    @Published public var albumArtURL: String? = nil
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: TimeInterval = 0
    @Published public var duration: TimeInterval = 230
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
                
                if !data.playlists.isEmpty {
                    var merged = self.playlists
                    for ep in data.playlists {
                        if let existingIdx = merged.firstIndex(where: { $0.id == ep.id }) {
                            merged[existingIdx] = ep
                        } else {
                            merged.append(ep)
                        }
                    }
                    self.playlists = merged
                }
                
                // If a playlist was loaded and engine provided queue, update selectedPlaylist tracks
                if let sel = self.selectedPlaylist, !data.queue.isEmpty {
                    var updated = sel
                    updated.tracks = data.queue
                    self.selectedPlaylist = updated
                }
            }
            .store(in: &cancellables)
            
        engine.$userPlaylists
            .sink { [weak self] enginePlaylists in
                guard let self = self, !enginePlaylists.isEmpty else { return }
                var merged = self.playlists
                for ep in enginePlaylists {
                    if let existingIdx = merged.firstIndex(where: { $0.id == ep.id }) {
                        merged[existingIdx] = ep
                    } else {
                        merged.append(ep)
                    }
                }
                self.playlists = merged
            }
            .store(in: &cancellables)
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
            simulateNextTrack()
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
        
        if isDirectEngineActive && pl.id != "pl_queue" {
            engine.loadPlaylist(id: pl.id)
        }
    }
    
    public func backToPlaylists() {
        selectedPlaylist = nil
        isSearchingSongs = false
        songSearchQuery = ""
    }
    
    public func playSongInSelectedPlaylist(_ item: YTMPlaylistItem) {
        trackTitle = item.title
        if !item.artist.isEmpty {
            artistName = item.artist
        }
        currentTime = 0
        isPlaying = true
        
        // Update isPlaying state across tracks in selectedPlaylist
        if var sel = selectedPlaylist {
            for i in 0..<sel.tracks.count {
                sel.tracks[i].isPlaying = (sel.tracks[i].id == item.id)
            }
            selectedPlaylist = sel
        }
        
        if let idx = Int(item.id) {
            engine.playPlaylistSong(index: idx)
        } else if let matchIdx = selectedPlaylist?.tracks.firstIndex(where: { $0.id == item.id }) {
            engine.playPlaylistSong(index: matchIdx)
        } else {
            playSearch("\(item.title) \(item.artist)")
        }
    }
    
    public func playEntireSelectedPlaylist() {
        guard let sel = selectedPlaylist, !sel.tracks.isEmpty else { return }
        playSongInSelectedPlaylist(sel.tracks[0])
        engine.playEntirePlaylist()
    }
    
    public func refreshPlaylists() {
        isLoadingPlaylists = true
        engine.fetchRealUserPlaylists()
        engine.fetchTracksFromCurrentPage()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.isLoadingPlaylists = false
        }
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
    
    // Demo Track Simulation when completely offline
    private let demoTracks: [(title: String, artist: String, duration: TimeInterval)] = [
        ("Starboy", "The Weeknd • Daft Punk", 230),
        ("Midnight City", "M83", 244),
        ("Blinding Lights", "The Weeknd", 200),
        ("Get Lucky", "Daft Punk • Pharrell Williams", 248),
        ("Resonance", "HOME • Chillwave", 212)
    ]
    private var demoIndex = 0
    
    private func simulateNextTrack() {
        demoIndex = (demoIndex + 1) % demoTracks.count
        let track = demoTracks[demoIndex]
        trackTitle = track.title
        artistName = track.artist
        duration = track.duration
        currentTime = 0
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
