import Foundation
import AppKit

/// Universal media controller that treats Morph's music player as just one of the tabs
/// of music/video the user has open, allowing F8 and media controls to seamlessly toggle
/// YouTube videos, browser audio/video streams, or Morph itself without collisions.
@MainActor
public final class UniversalMediaController {
    public static let shared = UniversalMediaController()
    
    private init() {}
    
    /// JavaScript evaluated inside browser tabs to universally control YouTube videos,
    /// YouTube Music, and HTML5 media elements.
    public nonisolated static let universalBrowserToggleJS: String = """
    (function() {
        // 1. YouTube desktop video player API (youtube.com/watch, embed, shorts)
        var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
        if (p && typeof p.getPlayerState === 'function') {
            var st = p.getPlayerState();
            if (st === 1) { // 1 = Playing -> Pause
                p.pauseVideo();
                return 'paused_yt';
            } else { // 2 = Paused, 5 = Cued, -1 = Unstarted, 0 = Ended -> Play
                p.playVideo();
                return 'playing_yt';
            }
        }
        
        // 2. HTML5 Media Elements (YouTube, Vimeo, Twitch, podcast/audio embeds)
        var mediaEls = Array.from(document.querySelectorAll('video, audio'));
        for (var i = 0; i < mediaEls.length; i++) {
            var el = mediaEls[i];
            if (!el.paused && !el.ended && el.currentTime > 0) {
                el.pause();
                return 'paused_media';
            }
        }
        for (var j = 0; j < mediaEls.length; j++) {
            var el2 = mediaEls[j];
            if (el2.paused && !el2.ended) {
                var pr = el2.play();
                if (pr && typeof pr.catch === 'function') { pr.catch(function(){}); }
                return 'playing_media';
            }
        }
        
        // 3. YouTube UI Play/Pause button fallback
        var btn = document.querySelector('.ytp-play-button, button.ytp-play-button, ytmusic-player-bar #play-pause-button, #play-pause-button');
        if (btn) {
            btn.click();
            return 'toggled_button';
        }
        
        return 'none';
    })();
    """
    
    /// Toggles playback universally:
    /// - If Morph is actively playing: pauses Morph.
    /// - If Morph is not playing:
    ///   - Checks if any browser tab has a YouTube video or media element to toggle.
    ///   - If toggled, calls completion with `true` (handled externally).
    ///   - If no browser video/tab responded, calls completion with `false` so Morph resumes playback.
    public func toggleUniversalPlayback(
        for model: NotchModel,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        // 1. If in test environment, bypass external AppleScript to maintain test speed & isolation
        if MorphEnvironment.isTestingEnvironment {
            completion(false)
            return
        }
        
        // 2. If Morph is actively playing sound, it owns the active playback -> pause Morph!
        let isMorphPlaying = model.isGlassMusicPlaying || model.media.isEffectivelyPlaying
        if isMorphPlaying {
            completion(false)
            return
        }
        
        // 3. Morph is not playing. Check if the user is interacting with an external YouTube video or browser tab
        Task.detached(priority: .userInitiated) {
            let handled = Self.executeBrowserUniversalToggleSync()
            await MainActor.run {
                completion(handled)
            }
        }
    }
    
    /// Synchronously executes universal toggle across running scriptable browsers via AppleScript.
    /// Returns true if a YouTube video or browser media stream was found and toggled.
    nonisolated public static func executeBrowserUniversalToggleSync() -> Bool {
        let escapedJS = universalBrowserToggleJS
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
        
        // Check running browsers
        let chromeRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").isEmpty
        let safariRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Safari").isEmpty
        let braveRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.brave.Browser").isEmpty
        let edgeRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.microsoft.edgemac").isEmpty
        let arcRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: "company.thebrowser.Browser").isEmpty
        
        guard chromeRunning || safariRunning || braveRunning || edgeRunning || arcRunning else {
            return false
        }
        
        // Fast path 1: Check Chromium browsers (Google Chrome, Brave, Edge, Arc)
        let chromiumApps = [
            (running: chromeRunning, name: "Google Chrome"),
            (running: braveRunning, name: "Brave Browser"),
            (running: edgeRunning, name: "Microsoft Edge"),
            (running: arcRunning, name: "Arc")
        ]
        
        for entry in chromiumApps where entry.running {
            let script = """
            tell application "\(entry.name)"
                if (count of windows) > 0 then
                    set curTab to active tab of front window
                    set tabUrl to URL of curTab
                    if tabUrl contains "youtube.com" or tabUrl contains "youtu.be" or tabUrl contains "music.youtube.com" then
                        try
                            set res to execute curTab javascript "\(escapedJS)"
                            if res is not "none" then return res
                        end try
                    end if
                end if
                repeat with w in windows
                    repeat with t in tabs of w
                        set tabUrl to URL of t
                        if tabUrl contains "youtube.com" or tabUrl contains "youtu.be" or tabUrl contains "music.youtube.com" then
                            try
                                set res to execute t javascript "\(escapedJS)"
                                if res is not "none" then return res
                            end try
                        end if
                    end repeat
                end repeat
                return "none"
            end tell
            """
            if let result = MorphAppleScriptRunner.run(script, timeout: 1.5), result != "none", !result.isEmpty {
                return true
            }
        }
        
        // Fast path 2: Check Safari
        if safariRunning {
            let safariScript = """
            tell application "Safari"
                if (count of windows) > 0 then
                    set curTab to current tab of front window
                    set tabUrl to URL of curTab
                    if tabUrl contains "youtube.com" or tabUrl contains "youtu.be" or tabUrl contains "music.youtube.com" then
                        try
                            set res to do JavaScript "\(escapedJS)" in curTab
                            if res is not "none" then return res
                        end try
                    end if
                end if
                repeat with w in windows
                    repeat with t in tabs of w
                        set tabUrl to URL of t
                        if tabUrl contains "youtube.com" or tabUrl contains "youtu.be" or tabUrl contains "music.youtube.com" then
                            try
                                set res to do JavaScript "\(escapedJS)" in t
                                if res is not "none" then return res
                            end try
                        end if
                    end repeat
                end repeat
                return "none"
            end tell
            """
            if let result = MorphAppleScriptRunner.run(safariScript, timeout: 1.5), result != "none", !result.isEmpty {
                return true
            }
        }
        
        return false
    }
}
