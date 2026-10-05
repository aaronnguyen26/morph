import Cocoa
import WebKit
import SwiftUI
import Combine

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
    
    public init(
        title: String = "",
        artist: String = "",
        albumArtURL: String? = nil,
        isPlaying: Bool = false,
        currentTime: Double = 0,
        duration: Double = 0,
        volume: Double = 1.0,
        isMuted: Bool = false,
        isLiked: Bool = false
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
    }
}

@MainActor
public final class YouTubeMusicEngine: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate {
    public static let shared = YouTubeMusicEngine()
    
    @Published public var trackData: YTMTrackData = YTMTrackData()
    @Published public var isEngineLoaded: Bool = false
    @Published public var isPlayerWindowVisible: Bool = false
    @Published public var connectionState: String = "Connecting..."
    
    public private(set) var webView: WKWebView!
    private var playerWindow: NSWindow?
    private var windowDelegate: PlayerWindowDelegate?
    
    private let kHandlerName = "morphYTM"
    private let kYTMURL = "https://music.youtube.com"
    private let kCustomUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"
    
    public override init() {
        super.init()
        setupWebView()
    }
    
    private func setupWebView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: kHandlerName)
        
        let bridgeScript = WKUserScript(
            source: injectedJavaScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        contentController.addUserScript(bridgeScript)
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.websiteDataStore = WKWebsiteDataStore.default() // Persistent store across app restarts
        config.mediaTypesRequiringUserActionForPlayback = [] // Allow background auto-playback
        config.allowsAirPlayForMediaPlayback = true
        
        // Initialize web view with desktop size
        let rect = NSRect(x: 0, y: 0, width: 1024, height: 768)
        self.webView = WKWebView(frame: rect, configuration: config)
        self.webView.customUserAgent = kCustomUserAgent
        self.webView.navigationDelegate = self
        
        // Load YouTube Music
        if let url = URL(string: kYTMURL) {
            let request = URLRequest(url: url)
            self.webView.load(request)
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
        
        self.trackData = YTMTrackData(
            title: title.isEmpty ? "YouTube Music" : title,
            artist: artist.isEmpty ? "Ready to play" : artist,
            albumArtURL: art,
            isPlaying: playing,
            currentTime: time,
            duration: dur,
            volume: vol,
            isMuted: muted,
            isLiked: liked
        )
        
        if !title.isEmpty && title != "YouTube Music" {
            self.connectionState = "Connected • Direct WebKit"
        }
    }
    
    // MARK: - Navigation Delegate
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.isEngineLoaded = true
        self.connectionState = "YouTube Music Loaded"
        injectPeriodicObserver()
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.connectionState = "Load failed: \(error.localizedDescription)"
    }
    
    // MARK: - Direct Playback Commands
    public func play() {
        evaluate("var v = document.querySelector('video'); if (v) { v.play(); }")
    }
    
    public func pause() {
        evaluate("var v = document.querySelector('video'); if (v) { v.pause(); }")
    }
    
    public func togglePlay() {
        let script = """
        var btn = document.querySelector('#play-pause-button');
        if (btn) {
            btn.click();
        } else {
            var v = document.querySelector('video');
            if (v) {
                if (v.paused) { v.play(); } else { v.pause(); }
            }
        }
        """
        evaluate(script)
    }
    
    public func nextTrack() {
        let script = """
        var btn = document.querySelector('.next-button') || document.querySelector('#right-controls .next-button');
        if (btn) { btn.click(); }
        """
        evaluate(script)
    }
    
    public func previousTrack() {
        let script = """
        var btn = document.querySelector('.previous-button') || document.querySelector('#left-controls .previous-button');
        if (btn) { btn.click(); }
        """
        evaluate(script)
    }
    
    public func seek(to seconds: Double) {
        let script = """
        var v = document.querySelector('video');
        if (v && !isNaN(\(seconds))) {
            v.currentTime = \(seconds);
        }
        """
        evaluate(script)
    }
    
    public func setVolume(_ volume: Double) {
        let clamped = max(0, min(1, volume))
        let script = """
        var v = document.querySelector('video');
        if (v) {
            v.volume = \(clamped);
            if (v.muted && \(clamped) > 0) { v.muted = false; }
        }
        """
        evaluate(script)
    }
    
    public func toggleMute() {
        let script = """
        var v = document.querySelector('video');
        if (v) {
            v.muted = !v.muted;
        }
        """
        evaluate(script)
    }
    
    public func toggleLike() {
        let script = """
        var btn = document.querySelector('#like-button-renderer yt-icon-button.like') || document.querySelector('ytmusic-like-button-renderer #button');
        if (btn) { btn.click(); }
        """
        evaluate(script)
    }
    
    public func evaluate(_ js: String) {
        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                print("[Morph YTM Engine Error]: \(error.localizedDescription)")
            }
        }
    }
    
    private func injectPeriodicObserver() {
        // Run observer periodically to ensure state updates even if backgrounded
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
    
    // MARK: - Dedicated Web View Window (For Google Sign-In & Music Browsing)
    public func showPlayerWindow() {
        if playerWindow == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: 1080, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "YouTube Music — Morph Direct Engine"
            win.titlebarAppearsTransparent = true
            win.isReleasedWhenClosed = false
            win.backgroundColor = NSColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
            
            let delegate = PlayerWindowDelegate { [weak self] in
                self?.isPlayerWindowVisible = false
            }
            self.windowDelegate = delegate
            win.delegate = delegate
            
            win.contentView = webView
            win.center()
            self.playerWindow = win
        }
        
        playerWindow?.makeKeyAndOrderFront(nil)
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
    
    // MARK: - Injected JavaScript Code
    private var injectedJavaScript: String {
        return """
        (function() {
            function getTrackInfo() {
                var titleEl = document.querySelector('ytmusic-player-bar .title') || document.querySelector('.title.ytmusic-player-bar');
                var bylineEl = document.querySelector('ytmusic-player-bar .byline') || document.querySelector('.byline.ytmusic-player-bar');
                var imgEl = document.querySelector('ytmusic-player-bar .thumbnail img') || document.querySelector('#song-image img') || document.querySelector('ytmusic-player-bar img');
                var videoEl = document.querySelector('video');
                var likeBtn = document.querySelector('#like-button-renderer yt-icon-button.like');
                
                var title = titleEl ? (titleEl.innerText || titleEl.textContent || '') : '';
                var artist = bylineEl ? (bylineEl.innerText || bylineEl.textContent || '') : '';
                var art = imgEl ? imgEl.src : null;
                var isPlaying = videoEl ? (!videoEl.paused && !videoEl.ended) : false;
                var currentTime = videoEl ? videoEl.currentTime : 0;
                var duration = videoEl ? videoEl.duration : 0;
                var volume = videoEl ? videoEl.volume : 1.0;
                var isMuted = videoEl ? videoEl.muted : false;
                var isLiked = likeBtn ? (likeBtn.getAttribute('aria-pressed') === 'true') : false;
                
                return {
                    title: title,
                    artist: artist,
                    albumArt: art,
                    isPlaying: isPlaying,
                    currentTime: isNaN(currentTime) ? 0 : currentTime,
                    duration: isNaN(duration) ? 0 : duration,
                    volume: isNaN(volume) ? 1.0 : volume,
                    isMuted: isMuted,
                    isLiked: isLiked
                };
            }
            
            window.morphSendUpdate = function() {
                try {
                    var data = getTrackInfo();
                    window.webkit.messageHandlers.\(kHandlerName).postMessage(data);
                } catch(e) {}
            };
            
            // Set up video event listeners
            function attachVideoListeners() {
                var v = document.querySelector('video');
                if (v && !v._morphListeners) {
                    v._morphListeners = true;
                    ['play', 'pause', 'timeupdate', 'ended', 'durationchange', 'volumechange'].forEach(function(evt) {
                        v.addEventListener(evt, function() {
                            window.morphSendUpdate();
                        });
                    });
                }
            }
            
            // Observe DOM changes on player bar
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
            }, 1000);
        })();
        """
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
