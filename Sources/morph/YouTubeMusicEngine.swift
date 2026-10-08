import Cocoa
import WebKit
import SwiftUI
import Combine

public enum YTMRepeatMode: String, Codable, CaseIterable {
    case off
    case all
    case one
    
    public var iconName: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
    
    public var displayTitle: String {
        switch self {
        case .off: return "Repeat Off"
        case .all: return "Repeat All"
        case .one: return "Repeat One"
        }
    }
}

public struct YTMPlaylistItem: Identifiable, Codable, Equatable {
    public var id: String
    public var title: String
    public var artist: String
    public var duration: String
    public var isPlaying: Bool
    /// Real YouTube video id (set for tracks fetched through InnerTube). Enables direct playback.
    public var videoId: String?
    public var thumbnailURL: String?
    
    public init(id: String = UUID().uuidString, title: String, artist: String, duration: String = "", isPlaying: Bool = false, videoId: String? = nil, thumbnailURL: String? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.isPlaying = isPlaying
        self.videoId = videoId
        self.thumbnailURL = thumbnailURL
    }
}

public enum YTMPlaylistKind: String, Codable, Equatable {
    case playlist, artist, album, queue
}

public struct YTMPlaylist: Identifiable, Codable, Equatable {
    public var id: String
    public var title: String
    public var subtitle: String
    public var thumbnailURL: String?
    public var trackCount: Int?
    public var tracks: [YTMPlaylistItem]
    public var browseId: String?
    public var kind: YTMPlaylistKind
    /// Playlist id to pass as `list=` when starting playback (nil for artists → plain radio playback).
    public var playbackListId: String?
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String = "",
        thumbnailURL: String? = nil,
        trackCount: Int? = nil,
        tracks: [YTMPlaylistItem] = [],
        browseId: String? = nil,
        kind: YTMPlaylistKind = .playlist,
        playbackListId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.thumbnailURL = thumbnailURL
        self.trackCount = trackCount
        self.tracks = tracks
        self.browseId = browseId
        self.kind = kind
        self.playbackListId = playbackListId
    }
}

public struct YTMTrackData: Codable, Equatable {
    public var title: String
    public var artist: String
    public var albumArtURL: String?
    public var isPlaying: Bool
    public var currentTime: Double
    public var duration: Double
    public var volume: Double
    public var isMuted: Bool
    public var isLiked: Bool
    public var isDisliked: Bool
    public var isShuffle: Bool
    public var repeatMode: YTMRepeatMode
    public var queue: [YTMPlaylistItem]
    public var playlists: [YTMPlaylist]
    public var isSignedIn: Bool
    
    public init(
        title: String = "",
        artist: String = "",
        albumArtURL: String? = nil,
        isPlaying: Bool = false,
        currentTime: Double = 0,
        duration: Double = 0,
        volume: Double = 1.0,
        isMuted: Bool = false,
        isLiked: Bool = false,
        isDisliked: Bool = false,
        isShuffle: Bool = false,
        repeatMode: YTMRepeatMode = .off,
        queue: [YTMPlaylistItem] = [],
        playlists: [YTMPlaylist] = [],
        isSignedIn: Bool = false
    ) {
        self.title = title
        self.artist = artist
        self.albumArtURL = albumArtURL
        self.isPlaying = isPlaying
        self.currentTime = currentTime
        self.duration = duration
        self.volume = volume
        self.isMuted = isMuted
        self.isLiked = isLiked
        self.isDisliked = isDisliked
        self.isShuffle = isShuffle
        self.repeatMode = repeatMode
        self.queue = queue
        self.playlists = playlists
        self.isSignedIn = isSignedIn
    }
}

@MainActor
public final class YouTubeMusicEngine: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    public static let shared = YouTubeMusicEngine()
    
    @Published public var trackData: YTMTrackData = YTMTrackData()
    @Published public var userPlaylists: [YTMPlaylist] = []
    @Published public var isSignedIn: Bool = false
    @Published public var isEngineLoaded: Bool = false
    @Published public var isPlayerWindowVisible: Bool = false
    @Published public var currentURLString: String = "https://music.youtube.com"
    @Published public var connectionState: String = "Connecting..."
    @Published public var canGoBack: Bool = false
    @Published public var canGoForward: Bool = false
    @Published public var libraryError: String? = nil
    @Published public var isLoadingLibrary: Bool = false
    private var lastLibrarySync: Date?
    
    public private(set) var webView: WKWebView!
    private var playerWindow: NSWindow?
    private var windowDelegate: PlayerWindowDelegate?
    
    private let kHandlerName = "morphYTM"
    private let kYTMURL = "https://music.youtube.com"
    // Modern Desktop Chrome User Agent on macOS to ensure standard browser classification
    private let kCustomUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    
    public override init() {
        super.init()
        setupWebView()
    }
    
    private func setupWebView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: kHandlerName)
        
        // 1. Injected at Document Start: Chrome Stealth Fingerprint
        // Satisfies Google Botguard checks on accounts.google.com before any scripts run
        let stealthScript = WKUserScript(
            source: chromeStealthJavaScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        contentController.addUserScript(stealthScript)
        
        // 2. Injected at Document End: YouTube Music Player Observers & Event Bridge
        let bridgeScript = WKUserScript(
            source: injectedPlayerObserverJavaScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        contentController.addUserScript(bridgeScript)
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.websiteDataStore = WKWebsiteDataStore.default() // Persistent cookies across restarts
        config.mediaTypesRequiringUserActionForPlayback = [] // Allow background auto-playback
        config.allowsAirPlayForMediaPlayback = true
        
        // Enable popup window handling required for Google OAuth authorization
        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = preferences
        
        // Initialize web view with standard desktop dimensions
        let rect = NSRect(x: 0, y: 0, width: 1080, height: 720)
        self.webView = WKWebView(frame: rect, configuration: config)
        self.webView.customUserAgent = kCustomUserAgent
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        
        // Host webView in playerWindow immediately so webView.window != nil (prevents WebKit throttling & audio suspension)
        _ = ensurePlayerWindow()
        
        // Initial load
        loadHome()
    }

    
    public func loadHome() {
        if let url = URL(string: kYTMURL) {
            let request = URLRequest(url: url)
            self.webView.load(request)
        }
    }
    
    public func loadGoogleSignIn() {
        // Direct Google Sign-In endpoint that redirects back to YouTube Music once completed
        let signInURLString = "https://accounts.google.com/ServiceLogin?service=youtube&passive=true&continue=https%3A%2F%2Fmusic.youtube.com%2F"
        if let url = URL(string: signInURLString) {
            let request = URLRequest(url: url)
            self.webView.load(request)
        }
    }
    
    public func goBack() {
        if webView.canGoBack {
            webView.goBack()
        }
    }
    
    public func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }
    
    public func reload() {
        webView.reload()
    }
    
    public func clearCookiesAndCache() {
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let dateFrom = Date(timeIntervalSince1970: 0)
        dataStore.removeData(ofTypes: types, modifiedSince: dateFrom) { [weak self] in
            DispatchQueue.main.async {
                self?.loadHome()
            }
        }
    }
    
    // MARK: - Script Message Handler
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == kHandlerName, let body = message.body as? [String: Any] else { return }
        
        Task { @MainActor in
            self.parseIncomingPayload(body)
        }
    }
    
    public func parseIncomingPayload(_ body: [String: Any]) {
        let title = (body["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let artist = (body["artist"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let art = body["albumArt"] as? String
        let playing = (body["isPlaying"] as? Bool) ?? false
        let time = (body["currentTime"] as? Double) ?? 0
        let dur = (body["duration"] as? Double) ?? 0
        let vol = (body["volume"] as? Double) ?? 1.0
        let muted = (body["isMuted"] as? Bool) ?? false
        let liked = (body["isLiked"] as? Bool) ?? false
        let disliked = (body["isDisliked"] as? Bool) ?? false
        let shuffle = (body["isShuffle"] as? Bool) ?? false
        let repStr = (body["repeatMode"] as? String) ?? "off"
        let repeatMode = YTMRepeatMode(rawValue: repStr) ?? .off
        let signedIn = (body["isSignedIn"] as? Bool) ?? false
        
        var parsedQueue: [YTMPlaylistItem] = []
        if let rawQueue = body["queue"] as? [[String: Any]] {
            for (idx, item) in rawQueue.enumerated() {
                let qTitle = (item["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let qArtist = (item["artist"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let qDuration = (item["duration"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let qIsPlaying = (item["isPlaying"] as? Bool) ?? false
                let qId = (item["id"] as? String) ?? "\(idx)"
                if !qTitle.isEmpty {
                    parsedQueue.append(YTMPlaylistItem(
                        id: qId,
                        title: qTitle,
                        artist: qArtist,
                        duration: qDuration,
                        isPlaying: qIsPlaying
                    ))
                }
            }
        }
        
        var parsedPlaylists: [YTMPlaylist] = []
        if let rawPlaylists = body["playlists"] as? [[String: Any]] {
            for (idx, item) in rawPlaylists.enumerated() {
                let pId = (item["id"] as? String) ?? "\(idx)"
                let pTitle = (item["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let pSub = (item["subtitle"] as? String) ?? "Playlist"
                let pThumb = item["thumbnailURL"] as? String
                let pBrowse = item["browseId"] as? String
                if !pTitle.isEmpty {
                    parsedPlaylists.append(YTMPlaylist(
                        id: pId,
                        title: pTitle,
                        subtitle: pSub,
                        thumbnailURL: pThumb,
                        browseId: pBrowse
                    ))
                }
            }
        }
        if !parsedPlaylists.isEmpty {
            self.userPlaylists = parsedPlaylists
        }
        
        let previousSignedIn = self.isSignedIn
        self.isSignedIn = signedIn
        
        self.trackData = YTMTrackData(
            title: title.isEmpty ? "YouTube Music" : title,
            artist: artist.isEmpty ? "Ready to play" : artist,
            albumArtURL: art,
            isPlaying: playing,
            currentTime: time,
            duration: dur,
            volume: vol,
            isMuted: muted,
            isLiked: liked,
            isDisliked: disliked,
            isShuffle: shuffle,
            repeatMode: repeatMode,
            queue: parsedQueue,
            playlists: parsedPlaylists.isEmpty ? self.userPlaylists : parsedPlaylists,
            isSignedIn: signedIn
        )
        
        // Auto-sync playlists immediately when transitioning from not signed in to signed in
        if signedIn && !previousSignedIn {
            fetchRealUserPlaylists()
        }
        
        if !title.isEmpty && title != "YouTube Music" {
            self.connectionState = "Connected • Direct WebKit"
        }
    }
    
    // MARK: - WKNavigationDelegate
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        updateNavigationState()
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.isEngineLoaded = true
        updateNavigationState()
        self.connectionState = "YouTube Music Loaded"
        injectPeriodicObserver()
        
        // Ensure cookies are synchronized and flushed to persistent store
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { _ in }
        
        // Auto-detect if user just returned from Google Sign-In or arrived at YouTube Music
        if let url = webView.url?.absoluteString {
            if url.contains("music.youtube.com") {
                // If returning from Google OAuth redirect, automatically fetch real library playlists
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }
                    // Don't re-sync on every watch-page navigation; only when empty or stale (> 5 min).
                    if self.userPlaylists.isEmpty || Date().timeIntervalSince(self.lastLibrarySync ?? .distantPast) > 300 {
                        self.fetchRealUserPlaylists()
                    }
                }
            }
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateNavigationState()
        self.connectionState = "Load failed: \(error.localizedDescription)"
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
        updateNavigationState()
        decisionHandler(.allow)
    }
    
    private func updateNavigationState() {
        self.canGoBack = webView.canGoBack
        self.canGoForward = webView.canGoForward
        if let url = webView.url?.absoluteString {
            self.currentURLString = url
        }
    }
    
    // MARK: - WKUIDelegate (Handles Google Sign-in Popups & Window Open)
    public func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // When Google Sign-in or YouTube opens a popup or target=_blank, load it directly in this webview
        if navigationAction.targetFrame == nil || !navigationAction.targetFrame!.isMainFrame {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    public func webViewDidClose(_ webView: WKWebView) {
        // If a Google sign-in popup calls window.close() upon auth completion, navigate back to YouTube Music home
        if let url = webView.url?.absoluteString, url.contains("accounts.google.com") {
            loadHome()
        }
    }
    
    // MARK: - Direct Playback Commands
    public func play() {
        let script = """
        (function() {
            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
            if (p && typeof p.playVideo === 'function') {
                p.playVideo();
            }
            var v = document.querySelector('video');
            if (v && v.paused) {
                v.play().catch(function(){});
            }
            var btn = document.querySelector('#play-pause-button') || 
                      document.querySelector('ytmusic-player-bar #play-pause-button') ||
                      document.querySelector('tp-yt-paper-icon-button#play-pause-button') ||
                      document.querySelector('[aria-label*="Play" i]') ||
                      document.querySelector('[aria-label*="Phát" i]');
            if (btn) {
                var label = (btn.getAttribute('aria-label') || btn.getAttribute('title') || '').toLowerCase();
                if (label.indexOf('play') !== -1 || label.indexOf('phát') !== -1 || label === '') {
                    btn.click();
                    var inner = btn.querySelector('button, #button, yt-icon');
                    if (inner) inner.click();
                }
            }
            // If neither has started, start the first playable item / supermix on page
            if ((!p || typeof p.playVideo !== 'function') && (!v || !v.src)) {
                var firstPlay = document.querySelector('ytmusic-responsive-list-item-renderer #play-button, ytmusic-two-row-item-renderer #play-button, ytmusic-play-button-renderer #button, #play-button');
                if (firstPlay) {
                    firstPlay.click();
                    var inner = firstPlay.querySelector('button, #button, yt-icon');
                    if (inner) inner.click();
                }
            }
            if (navigator.mediaSession) {
                navigator.mediaSession.playbackState = 'playing';
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 150);
            }
        })();
        """
        evaluate(script)
    }
    
    public func pause() {
        let script = """
        (function() {
            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
            if (p && typeof p.pauseVideo === 'function') {
                p.pauseVideo();
            }
            var videos = document.querySelectorAll('video, audio');
            for (var i = 0; i < videos.length; i++) {
                videos[i].pause();
            }
            var btn = document.querySelector('#play-pause-button') || 
                      document.querySelector('ytmusic-player-bar #play-pause-button') ||
                      document.querySelector('tp-yt-paper-icon-button#play-pause-button') ||
                      document.querySelector('[aria-label*="Pause" i]') ||
                      document.querySelector('[aria-label*="Tạm dừng" i]');
            if (btn) {
                var label = (btn.getAttribute('aria-label') || btn.getAttribute('title') || '').toLowerCase();
                if (label.indexOf('pause') !== -1 || label.indexOf('tạm dừng') !== -1 || label === '') {
                    btn.click();
                    var inner = btn.querySelector('button, #button, yt-icon');
                    if (inner) inner.click();
                }
            }
            if (navigator.mediaSession) {
                navigator.mediaSession.playbackState = 'paused';
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 150);
            }
        })();
        """
        evaluate(script)
    }
    
    public func stop() {
        let script = """
        (function() {
            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
            if (p && typeof p.stopVideo === 'function') {
                p.stopVideo();
            }
            var videos = document.querySelectorAll('video, audio');
            for (var i = 0; i < videos.length; i++) {
                videos[i].pause();
                try { videos[i].currentTime = 0; } catch(e) {}
            }
            var btn = document.querySelector('#play-pause-button') || 
                      document.querySelector('ytmusic-player-bar #play-pause-button') ||
                      document.querySelector('tp-yt-paper-icon-button#play-pause-button');
            if (btn) {
                var label = (btn.getAttribute('aria-label') || btn.getAttribute('title') || '').toLowerCase();
                if (label.indexOf('pause') !== -1 || label.indexOf('tạm dừng') !== -1) {
                    btn.click();
                }
            }
            if (navigator.mediaSession) {
                navigator.mediaSession.playbackState = 'none';
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 150);
            }
        })();
        """
        evaluate(script)
    }
    
    public func togglePlay() {
        if trackData.isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    public func nextTrack() {
        let script = """
        (function() {
            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
            if (p && typeof p.nextVideo === 'function') {
                p.nextVideo();
            } else {
                var btn = document.querySelector('.next-button') || 
                          document.querySelector('#right-controls .next-button') || 
                          document.querySelector('ytmusic-player-bar .next-button') ||
                          document.querySelector('tp-yt-paper-icon-button.next-button') ||
                          document.querySelector('[aria-label*="Next" i]') ||
                          document.querySelector('[aria-label*="tiếp" i]');
                if (btn) {
                    btn.click();
                    var inner = btn.querySelector('button, #button, yt-icon');
                    if (inner) inner.click();
                }
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 350);
            }
        })();
        """
        evaluate(script)
    }
    
    public func previousTrack() {
        let script = """
        (function() {
            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
            if (p && typeof p.previousVideo === 'function') {
                p.previousVideo();
            } else {
                var btn = document.querySelector('.previous-button') || 
                          document.querySelector('#left-controls .previous-button') || 
                          document.querySelector('ytmusic-player-bar .previous-button') ||
                          document.querySelector('tp-yt-paper-icon-button.previous-button') ||
                          document.querySelector('[aria-label*="Previous" i]') ||
                          document.querySelector('[aria-label*="trước" i]');
                if (btn) {
                    btn.click();
                    var inner = btn.querySelector('button, #button, yt-icon');
                    if (inner) inner.click();
                }
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 350);
            }
        })();
        """
        evaluate(script)
    }
    
    public func seek(to seconds: Double) {
        let script = """
        (function() {
            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
            if (p && typeof p.seekTo === 'function') {
                p.seekTo(\(seconds), true);
            } else {
                var v = document.querySelector('video');
                if (v && !isNaN(\(seconds))) {
                    v.currentTime = \(seconds);
                }
            }
            if (typeof window.morphSendUpdate === 'function') {
                window.morphSendUpdate();
            }
        })();
        """
        evaluate(script)
    }
    
    public func setVolume(_ volume: Double) {
        let clamped = max(0, min(1, volume))
        let script = """
        (function() {
            var vol = \(clamped);
            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
            if (p && typeof p.setVolume === 'function') {
                p.setVolume(Math.round(vol * 100));
                if (vol > 0 && typeof p.unMute === 'function') {
                    p.unMute();
                }
            }
            var v = document.querySelector('video');
            if (v) {
                v.volume = vol;
                if (v.muted && vol > 0) { v.muted = false; }
            }
            if (typeof window.morphSendUpdate === 'function') {
                window.morphSendUpdate();
            }
        })();
        """
        evaluate(script)
    }
    
    public func toggleMute() {
        let script = """
        (function() {
            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
            if (p && typeof p.isMuted === 'function') {
                if (p.isMuted()) {
                    p.unMute();
                } else {
                    p.mute();
                }
            }
            var v = document.querySelector('video');
            if (v) {
                v.muted = !v.muted;
            }
            if (typeof window.morphSendUpdate === 'function') {
                window.morphSendUpdate();
            }
        })();
        """
        evaluate(script)
    }
    
    public func toggleShuffle() {
        let script = """
        (function() {
            var btn = document.querySelector('ytmusic-player-bar .shuffle') || 
                      document.querySelector('#right-controls .shuffle') || 
                      document.querySelector('.shuffle.ytmusic-player-bar') ||
                      document.querySelector('tp-yt-paper-icon-button.shuffle') ||
                      document.querySelector('[aria-label*="Shuffle" i]') ||
                      document.querySelector('[aria-label*="xáo trộn" i]');
            if (btn) {
                btn.click();
                var inner = btn.querySelector('button, #button, yt-icon');
                if (inner) inner.click();
                btn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 250);
            }
        })();
        """
        evaluate(script)
    }
    
    public func toggleRepeat() {
        let script = """
        (function() {
            var btn = document.querySelector('ytmusic-player-bar .repeat') || 
                      document.querySelector('#right-controls .repeat') || 
                      document.querySelector('.repeat.ytmusic-player-bar') ||
                      document.querySelector('tp-yt-paper-icon-button.repeat') ||
                      document.querySelector('[aria-label*="Repeat" i]') ||
                      document.querySelector('[aria-label*="lặp lại" i]');
            if (btn) {
                btn.click();
                var inner = btn.querySelector('button, #button, yt-icon');
                if (inner) inner.click();
                btn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 250);
            }
        })();
        """
        evaluate(script)
    }
    
    public func toggleLike() {
        let script = """
        (function() {
            var btn = document.querySelector('ytmusic-like-button-renderer #like-button') || 
                      document.querySelector('ytmusic-like-button-renderer .like') ||
                      document.querySelector('#like-button-renderer yt-icon-button.like') || 
                      document.querySelector('ytmusic-like-button-renderer [aria-label*="Like" i]') ||
                      document.querySelector('ytmusic-like-button-renderer [aria-label*="Thích" i]') ||
                      document.querySelector('ytmusic-like-button-renderer yt-button-shape:first-child');
            if (btn) {
                btn.click();
                var inner = btn.querySelector('button, #button, yt-icon');
                if (inner) inner.click();
                btn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 250);
            }
        })();
        """
        evaluate(script)
    }
    
    public func toggleDislike() {
        let script = """
        (function() {
            var btn = document.querySelector('ytmusic-like-button-renderer #dislike-button') || 
                      document.querySelector('ytmusic-like-button-renderer .dislike') ||
                      document.querySelector('#like-button-renderer yt-icon-button.dislike') || 
                      document.querySelector('ytmusic-like-button-renderer [aria-label*="Dislike" i]') ||
                      document.querySelector('ytmusic-like-button-renderer [aria-label*="Không thích" i]') ||
                      document.querySelector('ytmusic-like-button-renderer yt-button-shape:last-child');
            if (btn) {
                btn.click();
                var inner = btn.querySelector('button, #button, yt-icon');
                if (inner) inner.click();
                btn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 250);
            }
        })();
        """
        evaluate(script)
    }
    
    public func playQueueIndex(_ index: Int) {
        let script = """
        (function() {
            var items = document.querySelectorAll('ytmusic-player-queue-item, ytmusic-player-queue #contents ytmusic-player-queue-item');
            if (items && items.length > \(index)) {
                var target = items[\(index)];
                var playBtn = target.querySelector('#play-button, .play-button, ytmusic-play-button-renderer') || target;
                playBtn.click();
                target.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 350);
            }
        })();
        """
        evaluate(script)
    }
    
    // MARK: - Native InnerTube Client (authenticated through the signed-in WebKit session)
    public enum InnerTubeError: LocalizedError {
        case notReady
        case http(Int)
        case invalidResponse
        
        public var errorDescription: String? {
            switch self {
            case .notReady: return "YouTube Music isn't ready yet. Open the player window and finish loading / signing in."
            case .http(let code): return code == 401 || code == 403
                ? "YouTube Music rejected the request (HTTP \(code)). Please sign in again."
                : "YouTube Music request failed (HTTP \(code))."
            case .invalidResponse: return "YouTube Music returned an unexpected response."
            }
        }
    }
    
    /// Test seam: when set, replaces the WebKit-backed network call.
    public var innerTubeOverride: (@MainActor @Sendable (String, [String: Any]) async throws -> [String: Any])?
    
    private func waitUntilReady(timeout: TimeInterval = 12) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let host = webView.url?.host, host.hasSuffix("music.youtube.com"), !webView.isLoading {
                return
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        throw InnerTubeError.notReady
    }
    
    /// Calls `https://music.youtube.com/youtubei/v1/<endpoint>` from inside the page (same origin, with the user's
    /// cookies and a freshly computed SAPISIDHASH `Authorization` header — without it YouTube answers as if logged out,
    /// which is why the library used to come back empty).
    public func innerTube(_ endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        if let override = innerTubeOverride {
            return try await override(endpoint, body)
        }
        try await waitUntilReady()
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let bodyJSON = String(decoding: bodyData, as: UTF8.self)
        let js = """
        const cfg = (window.ytcfg && typeof window.ytcfg.get === 'function') ? window.ytcfg : null;
        let context = cfg ? cfg.get('INNERTUBE_CONTEXT') : null;
        if (!context) { context = { client: { clientName: 'WEB_REMIX', clientVersion: '1.20250310.01.00', hl: 'en', gl: 'US' } }; }
        const apiKey = cfg ? cfg.get('INNERTUBE_API_KEY') : null;
        const payload = JSON.parse(bodyJSON);
        payload.context = context;
        const headers = { 'Content-Type': 'application/json', 'X-Goog-AuthUser': '0', 'X-Origin': 'https://music.youtube.com' };
        headers['X-Youtube-Client-Name'] = String((cfg && cfg.get('INNERTUBE_CONTEXT_CLIENT_NAME')) || 67);
        headers['X-Youtube-Client-Version'] = String((cfg && cfg.get('INNERTUBE_CONTEXT_CLIENT_VERSION')) || context.client.clientVersion);
        const visitor = cfg ? cfg.get('VISITOR_DATA') : null;
        if (visitor) { headers['X-Goog-Visitor-Id'] = visitor; }
        const m = document.cookie.match(/(?:^|;\\s*)(?:SAPISID|__Secure-3PAPISID)=([^;]+)/);
        if (m) {
            const ts = Math.floor(Date.now() / 1000);
            const data = new TextEncoder().encode(ts + ' ' + m[1] + ' https://music.youtube.com');
            const digest = await crypto.subtle.digest('SHA-1', data);
            const hex = Array.from(new Uint8Array(digest)).map(function(b) { return b.toString(16).padStart(2, '0'); }).join('');
            headers['Authorization'] = 'SAPISIDHASH ' + ts + '_' + hex;
        }
        const url = '/youtubei/v1/' + endpoint + '?prettyPrint=false' + (apiKey ? ('&key=' + apiKey) : '');
        const res = await fetch(url, { method: 'POST', headers: headers, body: JSON.stringify(payload), credentials: 'include' });
        if (!res.ok) { throw new Error('HTTP ' + res.status); }
        return await res.text();
        """
        let result: Any?
        do {
            result = try await webView.callAsyncJavaScript(js, arguments: ["endpoint": endpoint, "bodyJSON": bodyJSON], in: nil, contentWorld: .page)
        } catch {
            let msg = error.localizedDescription
            if let range = msg.range(of: #"HTTP (\d{3})"#, options: .regularExpression),
               let code = Int(msg[range].dropFirst(5)) {
                throw InnerTubeError.http(code)
            }
            throw error
        }
        guard let text = result as? String,
              let data = text.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InnerTubeError.invalidResponse
        }
        return json
    }
    
    // MARK: Library playlists
    public func fetchRealUserPlaylists() {
        Task { @MainActor in
            await self.refreshLibraryPlaylists()
        }
    }
    
    public func refreshLibraryPlaylists() async {
        isLoadingLibrary = true
        libraryError = nil
        defer { isLoadingLibrary = false }
        do {
            var doc = try await innerTube("browse", body: ["browseId": "FEmusic_liked_playlists"])
            var parsed = YTMParser.parseLibraryPlaylists(doc)
            var all = parsed.playlists
            var seenIds = Set(all.map { $0.id })
            var lastToken: String?
            var pages = 0
            while let token = parsed.continuation, token != lastToken, pages < 15 {
                lastToken = token
                doc = try await innerTube("browse", body: ["continuation": token])
                parsed = YTMParser.parseLibraryPlaylists(doc)
                for p in parsed.playlists where seenIds.insert(p.id).inserted { all.append(p) }
                pages += 1
            }
            if !all.contains(where: { $0.id == "LM" }) && (isSignedIn || !all.isEmpty) {
                all.insert(YTMPlaylist(id: "LM", title: "Liked Music", subtitle: "Auto playlist", browseId: "VLLM", kind: .playlist, playbackListId: "LM"), at: 0)
            }
            if all.isEmpty {
                libraryError = isSignedIn ? nil : "Sign in to YouTube Music to see your playlists."
            } else {
                userPlaylists = all
                lastLibrarySync = Date()
            }
        } catch {
            libraryError = error.localizedDescription
        }
    }
    
    // MARK: Tracks of a playlist / album / artist
    private func browseId(for playlist: YTMPlaylist) -> String {
        switch playlist.kind {
        case .artist, .album:
            return playlist.browseId ?? playlist.id
        default:
            if let b = playlist.browseId, b.hasPrefix("VL") { return b }
            return playlist.id.hasPrefix("VL") ? playlist.id : "VL\(playlist.id)"
        }
    }
    
    private func loadAllPages(browseId: String, maxTracks: Int = 1500) async throws -> YTMTrackPage {
        let doc = try await innerTube("browse", body: ["browseId": browseId])
        var page = YTMParser.parseTrackPage(doc)
        var token = page.continuation
        var lastToken: String?
        var guardCount = 0
        while let t = token, t != lastToken, page.tracks.count < maxTracks, guardCount < 40 {
            lastToken = t
            guardCount += 1
            let next = YTMParser.parseTrackPage(try await innerTube("browse", body: ["continuation": t]), startIndex: page.tracks.count)
            if next.tracks.isEmpty { break }
            page.tracks += next.tracks
            token = next.continuation
        }
        page.continuation = nil
        return page
    }
    
    /// Loads the real tracks of a playlist, album or artist. For artists this returns the full "Top songs" list
    /// (falling back to the handful of songs shown on the artist page).
    public func loadTracks(for playlist: YTMPlaylist) async throws -> YTMTrackPage {
        var page = try await loadAllPages(browseId: browseId(for: playlist))
        if playlist.kind == .artist, let more = page.moreBrowseId, more.hasPrefix("VL") {
            if let full = try? await loadAllPages(browseId: more), full.tracks.count > page.tracks.count {
                page.tracks = full.tracks
            }
        }
        if page.playbackListId == nil, playlist.kind == .playlist {
            page.playbackListId = playlist.playbackListId ?? (playlist.id.hasPrefix("VL") ? String(playlist.id.dropFirst(2)) : playlist.id)
        }
        return page
    }
    
    // MARK: Catalog search (songs, artists, albums, playlists)
    public func searchCatalog(_ query: String) async throws -> [YTMSearchResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let doc = try await innerTube("search", body: ["query": q])
        return YTMParser.parseSearch(doc)
    }
    
    // MARK: Direct playback by video id
    public func play(videoId: String, listId: String? = nil) {
        let vid = videoId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !vid.isEmpty else { return }
        var comps = URLComponents(string: "https://music.youtube.com/watch")!
        var items = [URLQueryItem(name: "v", value: vid)]
        if let l = listId?.trimmingCharacters(in: .whitespacesAndNewlines), !l.isEmpty {
            items.append(URLQueryItem(name: "list", value: l))
        }
        comps.queryItems = items
        if let url = comps.url {
            webView.load(URLRequest(url: url))
        }
    }
    

    public func playPlaylistSong(index: Int) {
        let script = """
        (function() {
            var items = document.querySelectorAll('ytmusic-responsive-list-item-renderer');
            if (items && items.length > \(index)) {
                var target = items[\(index)];
                var playBtn = target.querySelector('#play-button, .play-button, ytmusic-play-button-renderer') || target;
                playBtn.click();
                var inner = target.querySelector('button, #button, yt-icon');
                if (inner) inner.click();
                target.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 350);
            }
        })();
        """
        evaluate(script)
    }
    
    public func playEntirePlaylist() {
        let script = """
        (function() {
            var playBtn = document.querySelector('ytmusic-play-button-renderer #button, ytmusic-responsive-header-renderer #play-button, #play-button, tp-yt-paper-button.play-button');
            if (playBtn) {
                playBtn.click();
                var inner = playBtn.querySelector('button, #button, yt-icon');
                if (inner) inner.click();
            } else {
                var firstTrack = document.querySelector('ytmusic-responsive-list-item-renderer');
                if (firstTrack) {
                    firstTrack.click();
                    var pBtn = firstTrack.querySelector('#play-button, .play-button');
                    if (pBtn) pBtn.click();
                }
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 350);
            }
        })();
        """
        evaluate(script)
    }
    
    public func playSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://music.youtube.com/search?q=\(encoded)") else { return }
        
        self.webView.load(URLRequest(url: url))
        
        // Auto-click the first playable track or album in search results
        let autoPlayScript = """
        var checkCount = 0;
        var checkInterval = setInterval(function() {
            checkCount++;
            var firstPlay = document.querySelector('ytmusic-responsive-list-item-renderer #play-button, ytmusic-shelf-renderer #play-button, ytmusic-two-row-item-renderer #play-button, ytmusic-play-button-renderer #button');
            if (firstPlay) {
                clearInterval(checkInterval);
                firstPlay.click();
                var inner = firstPlay.querySelector('button, #button, yt-icon');
                if (inner) inner.click();
            }
            if (checkCount > 30) {
                clearInterval(checkInterval);
            }
        }, 250);
        """
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.evaluate(autoPlayScript)
        }
    }
    
    public func playVibe(_ vibe: String) {
        let query: String
        switch vibe.lowercased() {
        case "supermix", "my mix":
            query = "My Supermix"
        case "chill":
            query = "Chill Vibes"
        case "focus":
            query = "Deep Focus Study"
        case "lofi":
            query = "Lofi Hip Hop Beats"
        case "hits", "top hits":
            query = "Top Hits Today"
        default:
            query = vibe
        }
        playSearch(query: query)
    }
    
    public func evaluate(_ js: String) {
        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                print("[Morph YTM Engine Error]: \(error.localizedDescription)")
            }
        }
    }
    
    private func injectPeriodicObserver() {
        let script = """
        if (!window._morphObserverInstalled) {
            window._morphObserverInstalled = true;
            setInterval(function() {
                if (typeof window.morphSendUpdate === 'function') {
                    window.morphSendUpdate();
                }
            }, 800);
        }
        """
        evaluate(script)
    }
    
    // MARK: - Dedicated Web View Window (With Navigation Toolbar)
    @discardableResult
    public func ensurePlayerWindow() -> NSWindow {
        if let win = playerWindow {
            return win
        }
        let win = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1100, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        win.title = "YouTube Music — Morph Direct Engine"
        win.titlebarAppearsTransparent = false
        win.isReleasedWhenClosed = false
        win.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
        
        let delegate = PlayerWindowDelegate { [weak self] in
            self?.isPlayerWindowVisible = false
        }
        self.windowDelegate = delegate
        win.delegate = delegate
        
        // Build Container with Top Navigation Toolbar + Web View
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 1100, height: 760))
        container.autoresizingMask = [.width, .height]
        
        // Toolbar Hosting View (Height: 42 pt)
        let toolbarView = NSHostingView(rootView: PlayerWindowToolbarView(engine: self))
        toolbarView.frame = NSRect(x: 0, y: 760 - 42, width: 1100, height: 42)
        toolbarView.autoresizingMask = [.width, .minYMargin]
        
        // Web View (Height: 718 pt)
        self.webView.frame = NSRect(x: 0, y: 0, width: 1100, height: 760 - 42)
        self.webView.autoresizingMask = [.width, .height]
        
        container.addSubview(self.webView)
        container.addSubview(toolbarView)
        
        win.contentView = container
        win.center()
        self.playerWindow = win
        return win
    }
    
    public func showPlayerWindow() {
        let win = ensurePlayerWindow()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.isPlayerWindowVisible = true
    }
    
    public func hidePlayerWindow() {
        playerWindow?.orderOut(nil)
        self.isPlayerWindowVisible = false
    }
    
    public func togglePlayerWindow() {
        if isPlayerWindowVisible {
            hidePlayerWindow()
        } else {
            showPlayerWindow()
        }
    }
    
    // MARK: - Chrome Stealth Fingerprint Script (Injected at .atDocumentStart)
    private var chromeStealthJavaScript: String {
        return """
        (function() {
            // 1. Emulate standard window.chrome namespace
            if (!window.chrome) {
                window.chrome = {
                    app: {
                        isInstalled: false,
                        InstallState: { DISABLED: 'disabled', INSTALLED: 'installed', NOT_INSTALLED: 'not_installed' },
                        RunningState: { CANNOT_RUN: 'cannot_run', READY_TO_RUN: 'ready_to_run', RUNNING: 'running' }
                    },
                    runtime: {
                        OnInstalledReason: {},
                        OnRestartRequiredReason: {},
                        PlatformArch: { ARM: 'arm', X86_64: 'x86_64' },
                        PlatformNaclArch: {},
                        PlatformOs: { MAC: 'mac' },
                        RequestUpdateCheckStatus: {}
                    },
                    loadTimes: function() {
                        return {
                            requestTime: performance.now() / 1000,
                            startLoadTime: performance.now() / 1000,
                            commitLoadTime: performance.now() / 1000,
                            finishDocumentLoadTime: performance.now() / 1000,
                            firstPaintTime: performance.now() / 1000,
                            finishLoadTime: performance.now() / 1000,
                            wasFetchedViaSpdy: true,
                            wasNpnNegotiated: true,
                            npnNegotiatedProtocol: 'h2',
                            wasAlternateProtocolAvailable: false,
                            connectionInfo: 'h2'
                        };
                    },
                    csi: function() {
                        return {
                            startE: Date.now(),
                            onloadT: Date.now(),
                            pageT: performance.now(),
                            tran: 15
                        };
                    }
                };
            }
            
            // 2. Set vendor to 'Google Inc.'
            try {
                Object.defineProperty(navigator, 'vendor', {
                    get: function() { return 'Google Inc.'; },
                    configurable: true
                });
            } catch(e) {}
            
            // 3. Ensure webdriver is false (not automated)
            try {
                Object.defineProperty(navigator, 'webdriver', {
                    get: function() { return false; },
                    configurable: true
                });
            } catch(e) {}
            
            // 4. Emulate navigator.userAgentData client hints
            try {
                if (!navigator.userAgentData) {
                    Object.defineProperty(navigator, 'userAgentData', {
                        get: function() {
                            return {
                                brands: [
                                    { brand: 'Chromium', version: '131' },
                                    { brand: 'Google Chrome', version: '131' },
                                    { brand: 'Not_A Brand', version: '24' }
                                ],
                                mobile: false,
                                platform: 'macOS',
                                getHighEntropyValues: function(hints) {
                                    return Promise.resolve({
                                        architecture: 'arm',
                                        bitness: '64',
                                        brands: [
                                            { brand: 'Chromium', version: '131' },
                                            { brand: 'Google Chrome', version: '131' },
                                            { brand: 'Not_A Brand', version: '24' }
                                        ],
                                        mobile: false,
                                        model: '',
                                        platform: 'macOS',
                                        platformVersion: '15.0.0',
                                        uaFullVersion: '131.0.6778.86'
                                    });
                                }
                            };
                        },
                        configurable: true
                    });
                }
            } catch(e) {}
            
            // 5. Emulate standard Chrome plugins
            try {
                if (!navigator.plugins || navigator.plugins.length === 0) {
                    var fakePlugins = [
                        { name: 'Chrome PDF Plugin', filename: 'internal-pdf-viewer', description: 'Portable Document Format' },
                        { name: 'Chrome PDF Viewer', filename: 'mhjfbmdgcfjbbpaeojofohoefgiehjai', description: '' }
                    ];
                    fakePlugins.item = function(i) { return this[i]; };
                    fakePlugins.namedItem = function(name) {
                        for (var i = 0; i < this.length; i++) {
                            if (this[i].name === name) return this[i];
                        }
                        return null;
                    };
                    fakePlugins.refresh = function() {};
                    Object.defineProperty(navigator, 'plugins', {
                        get: function() { return fakePlugins; },
                        configurable: true
                    });
                }
            } catch(e) {}
        })();
        """
    }
    
    // MARK: - Injected Player Observer JavaScript Code (.atDocumentEnd)
    private var injectedPlayerObserverJavaScript: String {
        return """
        (function() {
            function getTrackInfo() {
                var title = '';
                var artist = '';
                var art = null;
                
                // 1. First priority: navigator.mediaSession.metadata (Official, rock-solid)
                if (navigator.mediaSession && navigator.mediaSession.metadata) {
                    var m = navigator.mediaSession.metadata;
                    if (m.title) title = m.title;
                    if (m.artist) artist = m.artist;
                    if (m.artwork && m.artwork.length > 0) {
                        art = m.artwork[m.artwork.length - 1].src;
                    }
                }
                
                // 2. DOM fallback for title & artist
                if (!title) {
                    var titleEl = document.querySelector('ytmusic-player-bar .title') || 
                                  document.querySelector('.title.ytmusic-player-bar') ||
                                  document.querySelector('ytmusic-player-bar yt-formatted-string.title') ||
                                  document.querySelector('.middle-controls .title');
                    if (titleEl) title = (titleEl.innerText || titleEl.textContent || '').trim();
                }
                
                if (!artist) {
                    var bylineEl = document.querySelector('ytmusic-player-bar .byline') || 
                                   document.querySelector('.byline.ytmusic-player-bar') ||
                                   document.querySelector('ytmusic-player-bar yt-formatted-string.byline') ||
                                   document.querySelector('.middle-controls .byline');
                    if (bylineEl) artist = (bylineEl.innerText || bylineEl.textContent || '').trim();
                }
                
                if (!art) {
                    var imgEl = document.querySelector('ytmusic-player-bar .thumbnail img') || 
                                document.querySelector('#song-image img') || 
                                document.querySelector('ytmusic-player-bar img#img') ||
                                document.querySelector('ytmusic-player-bar .image img');
                    if (imgEl && imgEl.src && imgEl.src.indexOf('data:') !== 0) art = imgEl.src;
                }
                
                var videoEl = document.querySelector('video');
                var playerEl = document.getElementById('movie_player') || document.querySelector('#movie_player');
                
                var isPlaying = false;
                if (navigator.mediaSession && navigator.mediaSession.playbackState) {
                    isPlaying = (navigator.mediaSession.playbackState === 'playing');
                } else if (playerEl && typeof playerEl.getPlayerState === 'function') {
                    var s = playerEl.getPlayerState();
                    isPlaying = (s === 1 || s === 3);
                } else if (videoEl) {
                    isPlaying = (!videoEl.paused && !videoEl.ended);
                }
                
                var currentTime = videoEl ? videoEl.currentTime : (playerEl && typeof playerEl.getCurrentTime === 'function' ? playerEl.getCurrentTime() : 0);
                var duration = videoEl ? videoEl.duration : (playerEl && typeof playerEl.getDuration === 'function' ? playerEl.getDuration() : 0);
                var volume = videoEl ? videoEl.volume : (playerEl && typeof playerEl.getVolume === 'function' ? (playerEl.getVolume() / 100) : 1.0);
                var isMuted = videoEl ? videoEl.muted : (playerEl && typeof playerEl.isMuted === 'function' ? playerEl.isMuted() : false);
                
                // Like / Dislike detection
                var likeBtn = document.querySelector('ytmusic-like-button-renderer #like-button') ||
                              document.querySelector('ytmusic-like-button-renderer .like') ||
                              document.querySelector('#like-button-renderer yt-icon-button.like') ||
                              document.querySelector('ytmusic-like-button-renderer [aria-label*="Like" i]') ||
                              document.querySelector('ytmusic-like-button-renderer [aria-label*="Thích" i]') ||
                              document.querySelector('ytmusic-like-button-renderer yt-button-shape:first-child');
                var dislikeBtn = document.querySelector('ytmusic-like-button-renderer #dislike-button') ||
                                 document.querySelector('ytmusic-like-button-renderer .dislike') ||
                                 document.querySelector('#like-button-renderer yt-icon-button.dislike') ||
                                 document.querySelector('ytmusic-like-button-renderer [aria-label*="Dislike" i]') ||
                                 document.querySelector('ytmusic-like-button-renderer [aria-label*="Không thích" i]') ||
                                 document.querySelector('ytmusic-like-button-renderer yt-button-shape:last-child');
                
                var isLiked = false;
                if (likeBtn) {
                    var innerBtn = likeBtn.querySelector('button') || likeBtn;
                    isLiked = (likeBtn.getAttribute('aria-pressed') === 'true' || 
                               innerBtn.getAttribute('aria-pressed') === 'true' ||
                               likeBtn.classList.contains('active') ||
                               likeBtn.getAttribute('aria-checked') === 'true');
                }
                
                var isDisliked = false;
                if (dislikeBtn) {
                    var innerBtn = dislikeBtn.querySelector('button') || dislikeBtn;
                    isDisliked = (dislikeBtn.getAttribute('aria-pressed') === 'true' || 
                                  innerBtn.getAttribute('aria-pressed') === 'true' ||
                                  dislikeBtn.classList.contains('active') ||
                                  dislikeBtn.getAttribute('aria-checked') === 'true');
                }
                
                // Shuffle detection
                var shuffleBtn = document.querySelector('ytmusic-player-bar .shuffle') || 
                                 document.querySelector('#right-controls .shuffle') || 
                                 document.querySelector('.shuffle.ytmusic-player-bar') ||
                                 document.querySelector('tp-yt-paper-icon-button.shuffle') ||
                                 document.querySelector('[aria-label*="Shuffle" i]') ||
                                 document.querySelector('[aria-label*="xáo trộn" i]');
                var isShuffle = false;
                if (shuffleBtn) {
                    var innerShuffle = shuffleBtn.querySelector('button') || shuffleBtn;
                    var sTitle = (shuffleBtn.getAttribute('title') || shuffleBtn.getAttribute('aria-label') || '').toLowerCase();
                    isShuffle = (shuffleBtn.getAttribute('aria-pressed') === 'true' || 
                                 innerShuffle.getAttribute('aria-pressed') === 'true' ||
                                 shuffleBtn.classList.contains('active') ||
                                 sTitle.indexOf('on') !== -1 || sTitle.indexOf('bật') !== -1);
                }
                
                // Repeat detection
                var repeatBtn = document.querySelector('ytmusic-player-bar .repeat') || 
                                document.querySelector('#right-controls .repeat') || 
                                document.querySelector('.repeat.ytmusic-player-bar') ||
                                document.querySelector('tp-yt-paper-icon-button.repeat') ||
                                document.querySelector('[aria-label*="Repeat" i]') ||
                                document.querySelector('[aria-label*="lặp lại" i]');
                var repeatMode = 'off';
                if (repeatBtn) {
                    var innerRepeat = repeatBtn.querySelector('button') || repeatBtn;
                    var rText = ((repeatBtn.getAttribute('aria-label') || repeatBtn.getAttribute('title') || '') + ' ' + 
                                 (innerRepeat.getAttribute('aria-label') || innerRepeat.getAttribute('title') || '') + ' ' +
                                 (repeatBtn.innerText || '')).toLowerCase();
                    var rPressed = repeatBtn.getAttribute('aria-pressed') === 'true' || innerRepeat.getAttribute('aria-pressed') === 'true';
                    if (rText.indexOf('one') !== -1 || rText.indexOf('1') !== -1 || rText.indexOf('một') !== -1) {
                        repeatMode = 'one';
                    } else if (rText.indexOf('all') !== -1 || rText.indexOf('tất cả') !== -1 || rPressed) {
                        repeatMode = 'all';
                    } else {
                        repeatMode = 'off';
                    }
                }
                
                // Playlist Queue extraction
                var queue = [];
                try {
                    var qItems = document.querySelectorAll('ytmusic-player-queue-item');
                    if (!qItems || qItems.length === 0) {
                        qItems = document.querySelectorAll('ytmusic-player-queue #contents ytmusic-player-queue-item');
                    }
                    if (qItems && qItems.length > 0) {
                        for (var i = 0; i < Math.min(qItems.length, 30); i++) {
                            var it = qItems[i];
                            var qTitleEl = it.querySelector('.song-title') || it.querySelector('.title') || it.querySelector('yt-formatted-string.song-title');
                            var qArtistEl = it.querySelector('.byline') || it.querySelector('.artist') || it.querySelector('yt-formatted-string.byline');
                            var qDurEl = it.querySelector('.duration') || it.querySelector('yt-formatted-string.duration');
                            var qTitle = qTitleEl ? (qTitleEl.innerText || qTitleEl.textContent || '').trim() : '';
                            var qArtist = qArtistEl ? (qArtistEl.innerText || qArtistEl.textContent || '').trim() : '';
                            var qDur = qDurEl ? (qDurEl.innerText || qDurEl.textContent || '').trim() : '';
                            var isSel = it.hasAttribute('selected') || it.classList.contains('selected') || it.getAttribute('play-state') === 'playing';
                            if (qTitle) {
                                queue.push({
                                    id: '' + i,
                                    title: qTitle,
                                    artist: qArtist,
                                    duration: qDur,
                                    isPlaying: isSel
                                });
                            }
                        }
                    }
                } catch(qe) {}
                
                // User Playlists extraction (Sidebar Guide + Page Shelves)
                var playlists = [];
                var seenPlaylists = {};
                try {
                    // 1. Sidebar Guide Entries
                    var guideEntries = document.querySelectorAll('ytmusic-guide-entry-renderer');
                    for (var g = 0; g < guideEntries.length; g++) {
                        var gel = guideEntries[g];
                        var gLink = gel.querySelector('a') || gel;
                        var gHref = gLink.getAttribute('href') || '';
                        var gTitleEl = gel.querySelector('yt-formatted-string.title') || gel.querySelector('.title') || gel.querySelector('tp-yt-paper-item');
                        var gTitle = gTitleEl ? (gTitleEl.innerText || gTitleEl.textContent || '').trim() : '';
                        
                        if (gHref.indexOf('playlist?list=') !== -1 || gHref.indexOf('browse/VL') !== -1) {
                            var gId = '';
                            var gMatch = gHref.match(/[?&]list=([^&]+)/);
                            if (gMatch) gId = gMatch[1];
                            else if (gHref.indexOf('browse/VL') !== -1) gId = gHref.split('browse/VL')[1].split('/')[0];
                            
                            var gImg = gel.querySelector('img');
                            var gThumb = gImg ? gImg.src : null;
                            
                            if (gTitle && gId && !seenPlaylists[gId]) {
                                seenPlaylists[gId] = true;
                                playlists.push({
                                    id: gId,
                                    title: gTitle,
                                    subtitle: 'Playlist',
                                    thumbnailURL: gThumb,
                                    browseId: gHref
                                });
                            }
                        }
                    }
                    
                    // (Page shelves / search-result cards are deliberately NOT scraped: they used to leak
                    // artist radios and recommendations into the user's playlist list.)

                    // 3. Ensure Liked Music if link is present
                    if (!seenPlaylists['LM']) {
                        var lEl = document.querySelector('a[href*="list=LM"]');
                        if (lEl) {
                            seenPlaylists['LM'] = true;
                            playlists.unshift({
                                id: 'LM',
                                title: 'Liked Music',
                                subtitle: 'Auto Playlist',
                                thumbnailURL: null,
                                browseId: 'playlist?list=LM'
                            });
                        }
                    }
                    
                    // 4. User Signed-In State Detection
                    var isSignedIn = false;
                    try {
                        if (window.ytcfg && typeof window.ytcfg.get === 'function') {
                            var yLoggedIn = window.ytcfg.get('LOGGED_IN');
                            if (typeof yLoggedIn === 'boolean') {
                                isSignedIn = yLoggedIn;
                            }
                        }
                        if (!isSignedIn) {
                            var hasAvatar = document.querySelector('button#avatar-btn, img#avatar-btn, ytmusic-settings-button, tp-yt-paper-icon-button#avatar-btn, ytmusic-sign-in-button[hidden]');
                            var signInBtn = document.querySelector('ytmusic-sign-in-button:not([hidden]), a[href*="accounts.google.com/ServiceLogin"]:not([hidden])');
                            if (hasAvatar && !signInBtn) {
                                isSignedIn = true;
                            }
                        }
                    } catch(ie) {}
                } catch(pe) {}
                
                return {
                    title: title,
                    artist: artist,
                    albumArt: art,
                    isPlaying: isPlaying,
                    currentTime: isNaN(currentTime) ? 0 : currentTime,
                    duration: isNaN(duration) ? 0 : duration,
                    volume: isNaN(volume) ? 1.0 : volume,
                    isMuted: isMuted,
                    isLiked: isLiked,
                    isDisliked: isDisliked,
                    isShuffle: isShuffle,
                    repeatMode: repeatMode,
                    queue: queue,
                    playlists: playlists,
                    isSignedIn: isSignedIn
                };
            }
            
            window.morphSendUpdate = function() {
                try {
                    var data = getTrackInfo();
                    window.webkit.messageHandlers.\(kHandlerName).postMessage(data);
                } catch(e) {}
            };
            
            function triggerNextVideo() {
                try {
                    var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
                    if (p && typeof p.nextVideo === 'function') {
                        p.nextVideo();
                    } else {
                        var btn = document.querySelector('.next-button') || 
                                  document.querySelector('#right-controls .next-button') || 
                                  document.querySelector('ytmusic-player-bar .next-button') ||
                                  document.querySelector('tp-yt-paper-icon-button.next-button') ||
                                  document.querySelector('[aria-label*="Next" i]') ||
                                  document.querySelector('[aria-label*="tiếp" i]');
                        if (btn) {
                            btn.click();
                            var inner = btn.querySelector('button, #button, yt-icon');
                            if (inner) inner.click();
                        }
                    }
                } catch(e) {}
            }
            
            function attachVideoListeners() {
                var v = document.querySelector('video');
                if (v && !v._morphListeners) {
                    v._morphListeners = true;
                    ['play', 'pause', 'timeupdate', 'ended', 'durationchange', 'volumechange'].forEach(function(evt) {
                        v.addEventListener(evt, function() {
                            window.morphSendUpdate();
                        });
                    });
                    
                    // Auto-advance to next song immediately when current track ends
                    v.addEventListener('ended', function() {
                        window.morphSendUpdate();
                        setTimeout(function() {
                            triggerNextVideo();
                        }, 250);
                    });
                    
                    // Safety check: if playback reaches the very end (< 0.5s remaining) and is not advancing
                    v.addEventListener('timeupdate', function() {
                        if (v.duration > 3 && v.currentTime >= (v.duration - 0.4) && !v._morphAutoAdvancing) {
                            v._morphAutoAdvancing = true;
                            setTimeout(function() {
                                if (v.ended || v.currentTime >= (v.duration - 0.5)) {
                                    triggerNextVideo();
                                }
                                setTimeout(function() { v._morphAutoAdvancing = false; }, 3000);
                            }, 500);
                        }
                    });
                }
            }
            
            var observer = new MutationObserver(function() {
                attachVideoListeners();
                window.morphSendUpdate();
            });
            
            observer.observe(document.documentElement, {
                childList: true,
                subtree: true,
                attributes: true
            });
            
            document.addEventListener('DOMContentLoaded', function() {
                attachVideoListeners();
                window.morphSendUpdate();
            });
            
            setInterval(function() {
                attachVideoListeners();
                window.morphSendUpdate();
            }, 800);
        })();
        """
    }
}

// MARK: - Player Window Toolbar (Back, Forward, Reload, Direct Sign-in, Home)
public struct PlayerWindowToolbarView: View {
    @ObservedObject var engine: YouTubeMusicEngine
    
    public init(engine: YouTubeMusicEngine) {
        self.engine = engine
    }
    
    public var body: some View {
        HStack(spacing: 10) {
            // Navigation History
            HStack(spacing: 4) {
                Button(action: {
                    engine.goBack()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(engine.canGoBack ? .white : Color.white.opacity(0.3))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!engine.canGoBack)
                
                Button(action: {
                    engine.goForward()
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(engine.canGoForward ? .white : Color.white.opacity(0.3))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!engine.canGoForward)
                
                Button(action: {
                    engine.reload()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            
            // Home Button
            Button(action: {
                engine.loadHome()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "music.note.house.fill")
                        .font(.system(size: 10))
                    Text("YouTube Music")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4.5)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // URL Status Pill
            Text(engine.currentURLString.replacingOccurrences(of: "https://", with: ""))
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.45))
                .lineLimit(1)
                .frame(maxWidth: 300)
            
            Spacer()
            
            // Direct Google Sign-In Action Button / Signed In Indicator
            if engine.isSignedIn {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(Color.green)
                    Text("Signed In")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            } else {
                Button(action: {
                    engine.loadGoogleSignIn()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 10.5, weight: .bold))
                        Text("Sign In with Google")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            // Clear & Reset Cache Button
            Button(action: {
                engine.clearCookiesAndCache()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 10))
                    .foregroundColor(Color.white.opacity(0.55))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Clear Cookies & Reset YouTube Music Session")
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
        .background(Color(red: 0.1, green: 0.1, blue: 0.1))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// Window delegate to track when the player window is closed/hidden
private final class PlayerWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
