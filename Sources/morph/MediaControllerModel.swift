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
    
    // Ambient 3-bar equalizer heights (0.15 ... 1.0)
    @Published public var visualizerBars: [CGFloat] = [0.18, 0.18, 0.18]
    
    public let engine: YouTubeMusicEngine
    
    private var cancellables = Set<AnyCancellable>()
    private var visualizerTimer: AnyCancellable?
    private var browserPollTimer: AnyCancellable?
    private var playbackTicker: AnyCancellable?
    
    public init(engine: YouTubeMusicEngine = YouTubeMusicEngine.shared) {
        self.engine = engine
        
        setupEngineObservers()
        startVisualizer()
        startPlaybackTicker()
        startBrowserPolling()
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
    
    private func setupEngineObservers() {
        // Observe direct WebKit engine track updates synchronously on MainActor
        engine.$trackData
            .sink { [weak self] data in
                guard let self = self else { return }
                
                // If YouTube Music is playing or has track data, prioritize direct engine
                if !data.title.isEmpty && data.title != "YouTube Music" {
                    self.trackTitle = data.title
                    self.artistName = data.artist.isEmpty ? "YouTube Music" : data.artist
                    self.albumArtURL = data.albumArtURL
                    self.isPlaying = data.isPlaying
                    self.currentTime = data.currentTime
                    if data.duration > 0 {
                        self.duration = data.duration
                    }
                    self.volume = data.volume
                    self.isMuted = data.isMuted
                    self.isLiked = data.isLiked
                    self.isDisliked = data.isDisliked
                    self.isShuffle = data.isShuffle
                    self.repeatMode = data.repeatMode
                    self.sourceName = "YouTube Music Direct"
                    self.isDirectEngineConnected = true
                }
            }
            .store(in: &cancellables)
            
        engine.$isEngineLoaded
            .sink { [weak self] loaded in
                if loaded {
                    self?.isDirectEngineConnected = true
                }
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
    
    private func formatTime(_ time: TimeInterval) -> String {
        let mins = Int(time) / 60
        let secs = Int(time) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    public func play() {
        isPlaying = true
        engine.play()
        executeBrowserPlay()
    }
    
    public func pause() {
        isPlaying = false
        engine.pause()
        executeBrowserPause()
    }
    
    public func stop() {
        isPlaying = false
        currentTime = 0
        engine.stop()
        executeBrowserStop()
    }
    
    public func togglePlay() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    public func nextTrack() {
        engine.nextTrack()
        executeBrowserNextTrack()
        if !isDirectEngineConnected && !isBrowserConnected {
            simulateNextTrack()
        }
    }
    
    public func previousTrack() {
        engine.previousTrack()
        executeBrowserPreviousTrack()
        if !isDirectEngineConnected && !isBrowserConnected {
            currentTime = 0
        }
    }
    
    public func seek(to progressFraction: Double) {
        let clamped = max(0, min(1, progressFraction))
        currentTime = clamped * duration
        engine.seek(to: currentTime)
        executeBrowserSeek(to: currentTime)
    }
    
    public func setVolume(_ newVol: Double) {
        volume = max(0, min(1, newVol))
        if volume > 0 && isMuted {
            isMuted = false
        }
        engine.setVolume(volume)
        executeBrowserVolume(volume)
    }
    
    public func toggleMute() {
        isMuted.toggle()
        engine.toggleMute()
        executeBrowserMute(isMuted)
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
        let script = """
        tell application "System Events"
            set chromeRunning to (name of processes) contains "Google Chrome"
            set safariRunning to (name of processes) contains "Safari"
        end tell
        
        if chromeRunning then
            tell application "Google Chrome"
                repeat with w in windows
                    repeat with t in tabs of w
                        if (URL of t) contains "music.youtube.com" then
                            return "CHROME_YTM:" & (title of t)
                        end if
                    end repeat
                end repeat
            end tell
        end if
        
        if safariRunning then
            tell application "Safari"
                repeat with w in windows
                    repeat with t in tabs of w
                        if (URL of t) contains "music.youtube.com" then
                            return "SAFARI_YTM:" & (name of t)
                        end if
                    end repeat
                end repeat
            end tell
        end if
        
        return "NONE"
        """
        
        guard let appleScript = NSAppleScript(source: script) else { return }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error).stringValue ?? "NONE"
        
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
        guard !isDirectEngineConnected else { return }
        let script = """
        tell application "System Events"
            if (name of processes) contains "Google Chrome" then
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
            end if
        end tell
        """
        runScriptAsync(script)
    }
    
    private func executeBrowserPlay() {
        guard !isDirectEngineConnected else { return }
        let script = """
        tell application "System Events"
            if (name of processes) contains "Google Chrome" then
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
            end if
        end tell
        """
        runScriptAsync(script)
    }
    
    private func executeBrowserPause() {
        guard !isDirectEngineConnected else { return }
        let script = """
        tell application "System Events"
            if (name of processes) contains "Google Chrome" then
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
            end if
        end tell
        """
        runScriptAsync(script)
    }
    
    private func executeBrowserStop() {
        guard !isDirectEngineConnected else { return }
        let script = """
        tell application "System Events"
            if (name of processes) contains "Google Chrome" then
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
            end if
        end tell
        """
        runScriptAsync(script)
    }
    
    private func executeBrowserNextTrack() {
        guard !isDirectEngineConnected else { return }
        let script = """
        tell application "System Events"
            if (name of processes) contains "Google Chrome" then
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
            end if
        end tell
        """
        runScriptAsync(script)
    }
    
    private func executeBrowserPreviousTrack() {
        guard !isDirectEngineConnected else { return }
        let script = """
        tell application "System Events"
            if (name of processes) contains "Google Chrome" then
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
            end if
        end tell
        """
        runScriptAsync(script)
    }
    
    private func executeBrowserSeek(to seconds: TimeInterval) {
        guard !isDirectEngineConnected else { return }
        let script = """
        tell application "System Events"
            if (name of processes) contains "Google Chrome" then
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
            end if
        end tell
        """
        runScriptAsync(script)
    }
    
    private func executeBrowserVolume(_ vol: Double) {
        guard !isDirectEngineConnected else { return }
        let script = """
        tell application "System Events"
            if (name of processes) contains "Google Chrome" then
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
            end if
        end tell
        """
        runScriptAsync(script)
    }
    
    private func executeBrowserMute(_ muted: Bool) {
        guard !isDirectEngineConnected else { return }
        let script = """
        tell application "System Events"
            if (name of processes) contains "Google Chrome" then
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
            end if
        end tell
        """
        runScriptAsync(script)
    }
    
    private func runScriptAsync(_ scriptSource: String) {
        Task.detached(priority: .userInitiated) {
            var error: NSDictionary?
            if let script = NSAppleScript(source: scriptSource) {
                script.executeAndReturnError(&error)
            }
        }
    }
}
