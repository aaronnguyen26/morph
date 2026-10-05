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
public final class YouTubeMusicEngine: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    public static let shared = YouTubeMusicEngine()
    
    @Published public var trackData: YTMTrackData = YTMTrackData()
    @Published public var isEngineLoaded: Bool = false
    @Published public var isPlayerWindowVisible: Bool = false
    @Published public var currentURLString: String = "https://music.youtube.com"
    @Published public var connectionState: String = "Connecting..."
    @Published public var canGoBack: Bool = false
    @Published public var canGoForward: Bool = false
    
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
    
    // MARK: - WKNavigationDelegate
    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        updateNavigationState()
    }
    
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.isEngineLoaded = true
        updateNavigationState()
        self.connectionState = "YouTube Music Loaded"
        injectPeriodicObserver()
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
    public func showPlayerWindow() {
        if playerWindow == nil {
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
            
            // Direct Google Sign-In Action Button
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
