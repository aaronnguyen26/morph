import SwiftUI
import Combine

@MainActor
public final class MediaControllerModel: ObservableObject {
    @Published public var trackTitle: String = "Starboy"
    @Published public var artistName: String = "The Weeknd • Daft Punk"
    @Published public var albumArtURL: String? = nil
    @Published public var isPlaying: Bool = true
    @Published public var currentTime: TimeInterval = 64
    @Published public var duration: TimeInterval = 230
    @Published public var volume: Double = 0.75
    @Published public var isMuted: Bool = false
    @Published public var sourceName: String = "YouTube Music"
    @Published public var isBrowserConnected: Bool = false
    
    // Ambient 3-bar equalizer heights (0.15 ... 1.0)
    @Published public var visualizerBars: [CGFloat] = [0.4, 0.85, 0.55]
    
    private var visualizerTimer: AnyCancellable?
    private var playbackTimer: AnyCancellable?
    private var browserPollTimer: AnyCancellable?
    
    public init() {
        startVisualizer()
        startPlaybackTick()
        startBrowserPolling()
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
    
    public func togglePlay() {
        isPlaying.toggle()
        executeBrowserPlayPause()
    }
    
    public func nextTrack() {
        executeBrowserNextTrack()
        // Simulated track rotation if offline
        if !isBrowserConnected {
            simulateNextTrack()
        }
    }
    
    public func previousTrack() {
        executeBrowserPreviousTrack()
        if !isBrowserConnected {
            currentTime = 0
        }
    }
    
    public func seek(to progressFraction: Double) {
        let clamped = max(0, min(1, progressFraction))
        currentTime = clamped * duration
        executeBrowserSeek(to: currentTime)
    }
    
    public func setVolume(_ newVol: Double) {
        volume = max(0, min(1, newVol))
        if volume > 0 && isMuted {
            isMuted = false
        }
        executeBrowserVolume(volume)
    }
    
    public func toggleMute() {
        isMuted.toggle()
        executeBrowserMute(isMuted)
    }
    
    // MARK: - Ambient Visualizer & Timers
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
    
    private func startPlaybackTick() {
        playbackTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.isPlaying {
                    if self.currentTime < self.duration {
                        self.currentTime += 1
                    } else {
                        self.nextTrack()
                    }
                }
            }
    }
    
    private func startBrowserPolling() {
        // Poll every 3 seconds for active YouTube Music tab in Chrome or Safari
        browserPollTimer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.pollBrowserState()
                }
            }
    }
    
    // MARK: - Simulated Track Rotation
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
    
    // MARK: - Browser AppleScript Bridge
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
        self.sourceName = source
        self.isBrowserConnected = true
        
        var clean = rawTitle.replacingOccurrences(of: " - YouTube Music", with: "")
        clean = clean.replacingOccurrences(of: "YouTube Music", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        if clean.isEmpty {
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
    }
    
    private func executeBrowserPlayPause() {
        let script = """
        tell application "System Events"
            if (name of processes) contains "Google Chrome" then
                tell application "Google Chrome"
                    repeat with w in windows
                        repeat with t in tabs of w
                            if (URL of t) contains "music.youtube.com" then
                                -- Try JS first if enabled
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
    
    private func executeBrowserNextTrack() {
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
