import Cocoa
import WebKit
import SwiftUI
import Combine
import CryptoKit

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
    
    public var hudTitle: String {
        switch self {
        case .off: return "Repeat Off"
        case .all: return "Loop All"
        case .one: return "Loop 1"
        }
    }
    
    public var next: YTMRepeatMode {
        switch self {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }
}

/// Represents the subscription tier of a YouTube Music account.
/// Distinguishes between paid ad-free subscribers and free ad-supported accounts.
public enum YTMAccountTier: String, Codable, CaseIterable, Equatable, Sendable {
    case basic = "basic"
    case premium = "premium"
    case unknown = "unknown"
    
    public var isPremium: Bool {
        return self == .premium
    }
    
    public var displayTitle: String {
        switch self {
        case .premium: return "YouTube Music Premium"
        case .basic: return "YouTube Music Free"
        case .unknown: return "Direct Stream"
        }
    }
    
    public var shortTitle: String {
        switch self {
        case .premium: return "Premium"
        case .basic: return "Basic"
        case .unknown: return "Free"
        }
    }
    
    public var badgeTitle: String {
        switch self {
        case .premium: return "PRO"
        case .basic: return "BASIC"
        case .unknown: return "GUEST"
        }
    }
    
    public var hasAds: Bool {
        switch self {
        case .premium: return false
        case .basic: return true
        case .unknown: return true
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
    
    public var durationSeconds: Int {
        let parts = duration.split(separator: ":").compactMap { Int($0) }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        } else if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        return 180
    }
    
    public init(id: String = UUID().uuidString, title: String, artist: String, duration: String = "", isPlaying: Bool = false, videoId: String? = nil, thumbnailURL: String? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.isPlaying = isPlaying
        self.videoId = videoId
        self.thumbnailURL = thumbnailURL
    }
    
    /// Returns the tracks with adjacent duplicates collapsed (same videoId, or same title and matching artist).
    public static func deduplicateAdjacent(_ tracks: [YTMPlaylistItem]) -> [YTMPlaylistItem] {
        var result: [YTMPlaylistItem] = []
        for track in tracks {
            if let last = result.last {
                let sameVideoId = (track.videoId != nil && !track.videoId!.isEmpty && track.videoId == last.videoId)
                let cleanTitle1 = track.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let cleanTitle2 = last.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let sameTitle = !cleanTitle1.isEmpty && cleanTitle1 == cleanTitle2
                
                let cleanArtist1 = track.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let cleanArtist2 = last.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let sameArtist = cleanArtist1 == cleanArtist2 || cleanArtist1.isEmpty || cleanArtist2.isEmpty
                
                if sameVideoId || (sameTitle && sameArtist) {
                    continue
                }
            }
            result.append(track)
        }
        return result
    }
    
    /// Matches artist strings even if names are permuted or contain feat/ft variations
    /// (e.g. "Low G & JustaTee" matches "JustaTee & Low G", "Wren Evans (ft. itsnk)" matches "itsnk & Wren Evans")
    public static func areArtistsMatching(_ a1: String, _ a2: String) -> Bool {
        let clean1 = a1.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let clean2 = a2.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if clean1.isEmpty || clean2.isEmpty || clean1 == clean2 { return true }
        if clean1.contains(clean2) || clean2.contains(clean1) { return true }
        
        let separators = CharacterSet(charactersIn: ",&+•/()[]")
        func extractTokens(_ raw: String) -> Set<String> {
            let sanitized = raw
                .replacingOccurrences(of: "feat.", with: ",")
                .replacingOccurrences(of: "feat", with: ",")
                .replacingOccurrences(of: "ft.", with: ",")
                .replacingOccurrences(of: "ft", with: ",")
                .replacingOccurrences(of: " and ", with: ",")
            let parts = sanitized.components(separatedBy: separators)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return Set(parts)
        }
        
        let set1 = extractTokens(clean1)
        let set2 = extractTokens(clean2)
        if !set1.isEmpty && !set2.isEmpty && (set1 == set2 || !set1.isDisjoint(with: set2)) {
            return true
        }
        return false
    }
    
    /// Returns the tracks with ALL duplicate entries eliminated across the entire playlist,
    /// deduplicating by videoId (if available) and normalized title + artist.
    public static func deduplicate(_ tracks: [YTMPlaylistItem]) -> [YTMPlaylistItem] {
        var result: [YTMPlaylistItem] = []
        var videoIdIndex: [String: Int] = [:]
        var titleArtistIndex: [String: Int] = [:]
        var titleOnlyIndex: [String: Int] = [:]
        
        for track in tracks {
            let vid = track.videoId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let cleanTitle = MediaControllerModel.normalizeTitle(track.title)
            let rawTitle = track.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let cleanArtist = track.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let titleArtistKey = "\(cleanTitle)|\(cleanArtist)"
            
            var existingIdx: Int?
            
            // 1. Check videoId duplication
            if !vid.isEmpty, let idx = videoIdIndex[vid] {
                existingIdx = idx
            }
            // 2. Check title + artist duplication
            else if !cleanTitle.isEmpty && !cleanArtist.isEmpty, let idx = titleArtistIndex[titleArtistKey] {
                existingIdx = idx
            }
            // 3. Check normalized title duplication if artists match / overlap
            else if !cleanTitle.isEmpty, let idx = titleOnlyIndex[cleanTitle] {
                let existingArtist = result[idx].artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if areArtistsMatching(cleanArtist, existingArtist) {
                    existingIdx = idx
                }
            }
            // 4. Raw title check fallback
            else if !rawTitle.isEmpty, let idx = titleOnlyIndex[rawTitle] {
                let existingArtist = result[idx].artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if areArtistsMatching(cleanArtist, existingArtist) {
                    existingIdx = idx
                }
            }
            
            if let idx = existingIdx {
                // Enrich existing item if new item has richer metadata
                if result[idx].artist.isEmpty && !track.artist.isEmpty {
                    result[idx].artist = track.artist
                }
                if (result[idx].videoId == nil || result[idx].videoId!.isEmpty) && track.videoId != nil {
                    result[idx].videoId = track.videoId
                }
                if result[idx].duration.isEmpty && !track.duration.isEmpty {
                    result[idx].duration = track.duration
                }
                if result[idx].thumbnailURL == nil && track.thumbnailURL != nil {
                    result[idx].thumbnailURL = track.thumbnailURL
                }
                if !result[idx].isPlaying && track.isPlaying {
                    result[idx].isPlaying = true
                }
                continue
            }
            
            let newIdx = result.count
            if !vid.isEmpty {
                videoIdIndex[vid] = newIdx
            }
            if !cleanTitle.isEmpty && !cleanArtist.isEmpty {
                titleArtistIndex[titleArtistKey] = newIdx
            }
            if !cleanTitle.isEmpty {
                titleOnlyIndex[cleanTitle] = newIdx
            }
            if !rawTitle.isEmpty {
                titleOnlyIndex[rawTitle] = newIdx
            }
            result.append(track)
        }
        return result
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
    /// Date when the playlist was most recently played or accessed.
    public var lastPlayedDate: Date?
    /// Number of times songs from this playlist have been played.
    public var playCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, thumbnailURL, trackCount, tracks, browseId, kind, playbackListId, lastPlayedDate, playCount
    }
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String = "",
        thumbnailURL: String? = nil,
        trackCount: Int? = nil,
        tracks: [YTMPlaylistItem] = [],
        browseId: String? = nil,
        kind: YTMPlaylistKind = .playlist,
        playbackListId: String? = nil,
        lastPlayedDate: Date? = nil,
        playCount: Int = 0
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
        self.lastPlayedDate = lastPlayedDate
        self.playCount = playCount
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.title = try c.decode(String.self, forKey: .title)
        self.subtitle = (try? c.decode(String.self, forKey: .subtitle)) ?? ""
        self.thumbnailURL = try? c.decode(String.self, forKey: .thumbnailURL)
        self.trackCount = try? c.decode(Int.self, forKey: .trackCount)
        self.tracks = (try? c.decode([YTMPlaylistItem].self, forKey: .tracks)) ?? []
        self.browseId = try? c.decode(String.self, forKey: .browseId)
        self.kind = (try? c.decode(YTMPlaylistKind.self, forKey: .kind)) ?? .playlist
        self.playbackListId = try? c.decode(String.self, forKey: .playbackListId)
        self.lastPlayedDate = try? c.decode(Date.self, forKey: .lastPlayedDate)
        self.playCount = (try? c.decode(Int.self, forKey: .playCount)) ?? 0
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
    public var userEmail: String?
    public var accountTier: YTMAccountTier
    public var isAdPlaying: Bool
    public var adSuppressedCount: Int
    public var videoId: String?
    
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
        isSignedIn: Bool = false,
        userEmail: String? = nil,
        accountTier: YTMAccountTier = .unknown,
        isAdPlaying: Bool = false,
        adSuppressedCount: Int = 0,
        videoId: String? = nil
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
        self.userEmail = userEmail
        self.accountTier = accountTier
        self.isAdPlaying = isAdPlaying
        self.adSuppressedCount = adSuppressedCount
        self.videoId = videoId
    }
}

@MainActor
public final class YouTubeMusicEngine: NSObject, ObservableObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    public static let shared = YouTubeMusicEngine()
    
    @Published public var trackData: YTMTrackData = YTMTrackData()
    @Published public var userPlaylists: [YTMPlaylist] = []
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
    
    public var effectiveUserEmail: String? {
        if let mail = userEmail, !mail.isEmpty { return mail }
        if let mail = activeProfile?.email, !mail.isEmpty { return mail }
        return nil
    }
    @Published public var isEngineLoaded: Bool = false
    @Published public var isPlayerWindowVisible: Bool = false
    @Published public var isWaitingForSignInCompletion: Bool = false
    @Published public var currentURLString: String = "https://music.youtube.com"
    @Published public var connectionState: String = "Connecting..."
    @Published public var canGoBack: Bool = false
    @Published public var canGoForward: Bool = false
    @Published public var isOffline: Bool = false
    @Published public var libraryError: String? = nil
    @Published public var isLoadingLibrary: Bool = false
    private var lastLibrarySync: Date?
    public var lastLibrarySyncTime: Date? { lastLibrarySync }
    
    @Published public var quickPicks: [YTMPlaylistItem] = []
    @Published public var isLoadingQuickPicks: Bool = false
    @Published public var quickPicksError: String? = nil
    private var lastQuickPicksSync: Date?
    
    public let trackEndedPublisher = PassthroughSubject<Void, Never>()
    
    public var lastEvaluatedScript: String?
    public var onEvaluate: ((String) -> Void)?
    
    public func simulateTrackDataUpdate(_ data: YTMTrackData) {
        self.trackData = data
    }
    
    public private(set) var webView: WKWebView!
    private var playerWindow: NSWindow?
    private var windowDelegate: PlayerWindowDelegate?
    private var resumeRetryWorkItems: [DispatchWorkItem] = []
    private var isResumeRequested: Bool = false
    @Published public var activeProfile: YTMProfile? = nil
    
    private let kHandlerName = "morphYTM"
    private let kYTMURL = "https://music.youtube.com"
    // Modern Desktop Chrome User Agent on macOS to ensure standard browser classification
    private let kCustomUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    
    public override init() {
        super.init()
        self.quickPicks = YTMParser.defaultQuickPicks
        self.activeProfile = YTMProfileManager.shared.activeProfile
        if let initialEmail = self.activeProfile?.email, !initialEmail.isEmpty {
            self.userEmail = initialEmail
        }
        if let initialTier = self.activeProfile?.accountTier, initialTier != .unknown {
            self.accountTier = initialTier
        }
        let stored = YTMUserOfflineStore.shared.getStoredPlaylists(for: self.userEmail)
        if !stored.isEmpty {
            self.userPlaylists = stored
        }
        setupWebView(for: self.activeProfile)
    }
    
    // MARK: - Declarative WebKit Content Blocking (Zero Ad Guarantee)
    public static var compiledAdBlockRuleList: WKContentRuleList?
    public static let adBlockRuleListIdentifier = "MorphYTMAdBlockRulesV2"
    public static let declarativeAdBlockRulesJSON: String = """
    [
        { "trigger": { "url-filter": "googleads" }, "action": { "type": "block" } },
        { "trigger": { "url-filter": "doubleclick" }, "action": { "type": "block" } },
        { "trigger": { "url-filter": "googlesyndication" }, "action": { "type": "block" } },
        { "trigger": { "url-filter": "pagead" }, "action": { "type": "block" } },
        { "trigger": { "url-filter": "/api/stats/ads" }, "action": { "type": "block" } },
        { "trigger": { "url-filter": "/ptracking" }, "action": { "type": "block" } },
        { "trigger": { "url-filter": "adformat=" }, "action": { "type": "block" } },
        { "trigger": { "url-filter": "/get_midroll_info" }, "action": { "type": "block" } },
        { "trigger": { "url-filter": "ad_break" }, "action": { "type": "block" } },
        {
            "trigger": { "url-filter": ".*" },
            "action": {
                "type": "css-display-none",
                "selector": ".ytp-ad-module, .video-ads, ytmusic-mealbar-promo-renderer, ytmusic-upsell-dialog-renderer, .ytp-ad-player-overlay, .ytp-ad-preview-text, .ytp-ad-text, .ytp-ad-skip-button-slot, tp-yt-paper-dialog.ytmusic-upsell-dialog-renderer"
            }
        }
    ]
    """
    
    public func applyDeclarativeAdBlocking(to contentController: WKUserContentController) {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        if let cached = Self.compiledAdBlockRuleList {
            contentController.add(cached)
            return
        }
        
        guard let store = WKContentRuleListStore.default() else { return }
        
        store.lookUpContentRuleList(forIdentifier: Self.adBlockRuleListIdentifier) { [weak contentController] list, error in
            if let list = list {
                Self.compiledAdBlockRuleList = list
                contentController?.add(list)
            } else {
                store.compileContentRuleList(forIdentifier: Self.adBlockRuleListIdentifier, encodedContentRuleList: Self.declarativeAdBlockRulesJSON) { [weak contentController] compiledList, compileError in
                    if let compiledList = compiledList {
                        Self.compiledAdBlockRuleList = compiledList
                        contentController?.add(compiledList)
                    }
                }
            }
        }
    }
    
    public func setupWebView(for profile: YTMProfile? = nil) {
        let contentController = WKUserContentController()
        contentController.add(self, name: kHandlerName)
        
        // 1. Injected at Document Start: Chrome Stealth Fingerprint & Player Ad Neutralizer
        // Satisfies Google Botguard checks on accounts.google.com and strips ads from player responses before execution
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
        
        // 3. Declarative Content Blocking: Native WebKit-level blocking of ad servers and ad video requests
        applyDeclarativeAdBlocking(to: contentController)
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        let target = profile ?? YTMProfileManager.shared.activeProfile
        self.activeProfile = target
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
        
        // In modern Morph architecture, webView is hosted directly within Morph's active notch panel (attachToHostingView),
        // completely eliminating any ghost/invisible NSWindow on the user's desktop screen.
        if !MorphEnvironment.isTestingEnvironment {
            loadHome(for: self.activeProfile)
        }
    }
    
    public func switchProfile(to profile: YTMProfile) {
        self.activeProfile = profile
        self.userEmail = profile.email
        if profile.accountTier != .unknown {
            self.accountTier = profile.accountTier
        }
        YTMProfileManager.shared.switchProfile(to: profile.id)
        
        // Load stored library for this profile immediately
        let cached = YTMUserOfflineStore.shared.getStoredPlaylists(for: profile.email)
        self.userPlaylists = cached
        self.quickPicks = []
        self.isLoadingLibrary = cached.isEmpty
        self.isLoadingQuickPicks = true
        
        guard !MorphEnvironment.isTestingEnvironment else { return }
        
        // Sync any cookies from active browser tabs
        syncSessionFromBrowser()
        
        // Load YouTube Music with Google's multi-account authuser parameter
        loadHome(for: profile)
        checkAuthCookies()
        
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard let self = self else { return }
            self.fetchRealUserPlaylists()
            self.fetchQuickPicks()
        }
    }
    
    public func loadHome(for profile: YTMProfile? = nil) {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        let target = profile ?? self.activeProfile
        let targetEmail = target?.email ?? self.effectiveUserEmail
        var urlStr = kYTMURL
        if let email = targetEmail, !email.isEmpty {
            let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
            urlStr = "\(kYTMURL)/?authuser=\(encoded)"
        }
        if let url = URL(string: urlStr) {
            let request = URLRequest(url: url)
            self.webView.load(request)
        }
    }
    
    public func loadGoogleSignIn(for email: String? = nil) {
        self.isWaitingForSignInCompletion = true
        guard !MorphEnvironment.isTestingEnvironment else { return }
        var signInURLString = "https://accounts.google.com/ServiceLogin?service=youtube&passive=true&continue=https%3A%2F%2Fmusic.youtube.com%2F"
        if let targetEmail = email ?? self.activeProfile?.email, !targetEmail.isEmpty {
            let encoded = targetEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? targetEmail
            signInURLString += "&Email=\(encoded)"
        }
        if let url = URL(string: signInURLString) {
            let request = URLRequest(url: url)
            self.webView.load(request)
        }
        showPlayerWindow()
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
        signOut()
    }
    
    public func signOut() {
        self.isSignedIn = false
        self.userEmail = nil
        self.userPlaylists = []
        self.trackData.isSignedIn = false
        self.trackData.userEmail = nil
        self.lastLibrarySync = nil
        self.lastQuickPicksSync = nil
        
        guard !MorphEnvironment.isTestingEnvironment else {
            return
        }
        
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let dateFrom = Date(timeIntervalSince1970: 0)
        dataStore.removeData(ofTypes: types, modifiedSince: dateFrom) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.loadHome()
            }
        }
        
        dataStore.httpCookieStore.getAllCookies { cookies in
            for cookie in cookies {
                if cookie.domain.contains("youtube.com") || cookie.domain.contains("google.com") {
                    dataStore.httpCookieStore.delete(cookie)
                }
            }
        }
        
        // Clear local storage and cookies via script
        let script = """
        (function() {
            try {
                document.cookie.split(";").forEach(function(c) {
                    document.cookie = c.replace(/^ +/, "").replace(/=.*/, "=;expires=" + new Date().toUTCString() + ";path=/;domain=.youtube.com");
                    document.cookie = c.replace(/^ +/, "").replace(/=.*/, "=;expires=" + new Date().toUTCString() + ";path=/");
                });
                localStorage.clear();
                sessionStorage.clear();
            } catch(e) {}
        })();
        """
        evaluate(script)
        
        if let logoutURL = URL(string: "https://accounts.google.com/Logout") {
            self.webView.load(URLRequest(url: logoutURL))
        }
    }
    
    // MARK: - Script Message Handler
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == kHandlerName, let body = message.body as? [String: Any] else { return }
        
        self.parseIncomingPayload(body)
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
        let isEnded = (body["isEnded"] as? Bool) ?? false
        let rawTier = (body["accountTier"] as? String)?.lowercased() ?? "unknown"
        let detectedTier = YTMAccountTier(rawValue: rawTier) ?? .unknown
        let isAd = (body["isAdPlaying"] as? Bool) ?? false
        let adCount = (body["adSuppressedCount"] as? Int) ?? 0
        let incomingVideoId = (body["videoId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if isEnded {
            self.trackEndedPublisher.send()
        }
        
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
            parsedQueue = YTMPlaylistItem.deduplicate(parsedQueue)
            
            // Synchronize current playing song with queue
            if !title.isEmpty && title != "YouTube Music" {
                let normCurrent = MediaControllerModel.normalizeTitle(title)
                var matchedIdx = -1
                for (qIdx, qItem) in parsedQueue.enumerated() {
                    let normItem = MediaControllerModel.normalizeTitle(qItem.title)
                    if normItem == normCurrent || (!normItem.isEmpty && (normCurrent.contains(normItem) || normItem.contains(normCurrent))) {
                        matchedIdx = qIdx
                        break
                    }
                }
                
                if matchedIdx >= 0 {
                    for i in 0..<parsedQueue.count {
                        parsedQueue[i].isPlaying = (i == matchedIdx && playing)
                    }
                } else if playing {
                    let currentItem = YTMPlaylistItem(
                        id: "current_live_track",
                        title: title,
                        artist: artist,
                        duration: "",
                        isPlaying: true,
                        videoId: nil,
                        thumbnailURL: art
                    )
                    for i in 0..<parsedQueue.count {
                        parsedQueue[i].isPlaying = false
                    }
                    parsedQueue.insert(currentItem, at: 0)
                }
            } else {
                var seenPlaying = false
                for i in 0..<parsedQueue.count {
                    if parsedQueue[i].isPlaying {
                        if !seenPlaying {
                            seenPlaying = true
                        } else {
                            parsedQueue[i].isPlaying = false
                        }
                    }
                }
            }
        }
        
        var parsedPlaylists: [YTMPlaylist] = []
        if let rawPlaylists = body["playlists"] as? [[String: Any]] {
            for (idx, item) in rawPlaylists.enumerated() {
                let rawId = (item["id"] as? String) ?? ""
                let pBrowse = item["browseId"] as? String
                let pId: String = {
                    if !rawId.isEmpty { return rawId }
                    if let b = pBrowse, !b.isEmpty {
                        if b.hasPrefix("VL") {
                            return String(b.dropFirst(2))
                        } else if let match = b.range(of: "list=([a-zA-Z0-9_-]+)", options: .regularExpression) {
                            return String(b[match]).replacingOccurrences(of: "list=", with: "")
                        }
                        return b
                    }
                    return "\(idx)"
                }()
                let pTitle = (item["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let pSub = (item["subtitle"] as? String) ?? "Playlist"
                let pThumb = item["thumbnailURL"] as? String
                // Strictly require actual user playlist: PL, LM, LL, WL, VL, FL (reject single song radios and albums)
                guard pId.hasPrefix("PL") || pId == "LM" || pId == "LL" || pId == "WL" || pId.hasPrefix("VL") || pId.hasPrefix("FL") else { continue }
                guard !pId.contains("RD") && !pId.contains("MPRE") && !pId.contains("OLAK") else { continue }
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
            var combined = self.userPlaylists
            for pl in parsedPlaylists {
                if let idx = combined.firstIndex(where: { $0.id == pl.id }) {
                    if combined[idx].tracks.isEmpty && !pl.tracks.isEmpty {
                        combined[idx].tracks = pl.tracks
                    }
                    if combined[idx].thumbnailURL == nil {
                        combined[idx].thumbnailURL = pl.thumbnailURL
                    }
                } else {
                    combined.append(pl)
                }
            }
            self.userPlaylists = combined
            YTMUserOfflineStore.shared.savePlaylists(combined, for: self.userEmail)
        }
        
        if let rawPicks = body["quickPicks"] as? [[String: Any]], !rawPicks.isEmpty {
            var parsedPicks: [YTMPlaylistItem] = []
            for (idx, item) in rawPicks.enumerated() {
                let pTitle = (item["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !pTitle.isEmpty else { continue }
                let pArtist = (item["artist"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let pDuration = (item["duration"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let pVideoId = item["videoId"] as? String
                let pThumb = item["thumbnailURL"] as? String
                let pId = (item["id"] as? String) ?? (pVideoId ?? "qp_\(idx)")
                parsedPicks.append(YTMPlaylistItem(
                    id: pId,
                    title: pTitle,
                    artist: pArtist,
                    duration: pDuration,
                    videoId: pVideoId,
                    thumbnailURL: pThumb
                ))
            }
            if !parsedPicks.isEmpty {
                let deduped = YTMPlaylistItem.deduplicate(parsedPicks)
                // Only publish a new quickPicks array when the content actually changed.
                // The JS payload fires every ~1s; without this guard every poll replaces the
                // entire array, causing SwiftUI to re-render every Quick Picks row (flickering).
                let newIds = deduped.map { $0.videoId ?? $0.id }
                let oldIds = self.quickPicks.map { $0.videoId ?? $0.id }
                if newIds != oldIds {
                    self.quickPicks = deduped
                    self.lastQuickPicksSync = Date()
                }
            }
        }
        
        let previousSignedIn = self.isSignedIn
        if signedIn {
            self.isSignedIn = true
        } else if !self.currentURLString.contains("accounts.google.com") {
            self.isSignedIn = false
        }
        
        let extractedEmail = (body["userEmail"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let extractedAvatarURL = (body["userAvatarURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let extractedDisplayName = (body["userDisplayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let email = extractedEmail, !email.isEmpty {
            self.userEmail = email
            YTMProfileManager.shared.handleDetectedEmail(
                email,
                avatarURL: (extractedAvatarURL?.isEmpty == false ? extractedAvatarURL : nil),
                displayName: (extractedDisplayName?.isEmpty == false ? extractedDisplayName : nil),
                accountTier: detectedTier
            )
            self.activeProfile = YTMProfileManager.shared.activeProfile
        } else if let avUrl = extractedAvatarURL, !avUrl.isEmpty, self.isSignedIn {
            YTMProfileManager.shared.updateActiveProfileAvatar(url: avUrl)
            self.activeProfile = YTMProfileManager.shared.activeProfile
        } else if !self.isSignedIn {
            self.userEmail = nil
        }
        
        if detectedTier != .unknown {
            self.accountTier = detectedTier
            if let prof = self.activeProfile {
                YTMProfileManager.shared.updateProfileTier(id: prof.id, tier: detectedTier)
                self.activeProfile = YTMProfileManager.shared.activeProfile
            }
        }
        self.isAdPlaying = isAd
        self.adSuppressedCount = adCount
        
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
            isSignedIn: self.isSignedIn,
            userEmail: self.userEmail,
            accountTier: self.accountTier,
            isAdPlaying: self.isAdPlaying,
            adSuppressedCount: self.adSuppressedCount,
            videoId: (incomingVideoId?.isEmpty ?? true) ? nil : incomingVideoId
        )
        if playing {
            self.isResumeRequested = false
        }
        
        // Auto-sync playlists and quick picks immediately when transitioning from not signed in to signed in
        if self.isSignedIn && !previousSignedIn {
            self.lastLibrarySync = nil
            self.lastQuickPicksSync = nil
            self.libraryError = nil
            fetchRealUserPlaylists()
            fetchQuickPicks()
            
            // If the user was signing in via Morph's dedicated window, auto-dismiss and return to Morph
            if self.isWaitingForSignInCompletion || (self.isPlayerWindowVisible && self.currentURLString.contains("music.youtube.com")) {
                self.isWaitingForSignInCompletion = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    guard let self = self else { return }
                    if self.isPlayerWindowVisible {
                        self.hidePlayerWindow()
                    }
                }
            }
        }
        
        if !title.isEmpty && title != "YouTube Music" {
            self.connectionState = "Connected • Direct WebKit"
        }
    }
    
    /// Checks WebKit's persistent cookie store for valid YouTube / Google session cookies
    /// (`SAPISID`, `__Secure-3PAPISID`, `SID`, `__Secure-3PSID`) so `isSignedIn` transitions immediately upon login.
    public func checkAuthCookies(completion: (@MainActor @Sendable (Bool) -> Void)? = nil) {
        guard !MorphEnvironment.isTestingEnvironment else {
            completion?(self.isSignedIn)
            return
        }
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            let authNames: Set<String> = ["SAPISID", "__Secure-3PAPISID", "__Secure-1PAPISID", "SID", "__Secure-3PSID"]
            let now = Date()
            let hasValidAuthCookie = cookies.contains { cookie in
                let domain = cookie.domain.lowercased()
                guard domain.contains("youtube.com") || domain.contains("google.com") else { return false }
                guard authNames.contains(cookie.name), !cookie.value.isEmpty else { return false }
                if let expires = cookie.expiresDate, expires < now { return false }
                return true
            }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if hasValidAuthCookie && !self.currentURLString.contains("accounts.google.com/ServiceLogin") {
                    let prev = self.isSignedIn
                    self.isSignedIn = true
                    if !prev {
                        self.lastLibrarySync = nil
                        self.lastQuickPicksSync = nil
                        self.libraryError = nil
                        self.fetchRealUserPlaylists()
                        self.fetchQuickPicks()
                    }
                }
                completion?(self.isSignedIn)
            }
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
        self.isOffline = false
        
        // Inspect and flush persistent auth cookies
        checkAuthCookies { [weak self] signedIn in
            guard let self = self else { return }
            if signedIn && (self.isWaitingForSignInCompletion || (self.isPlayerWindowVisible && self.currentURLString.contains("music.youtube.com"))) {
                self.isWaitingForSignInCompletion = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                    guard let self = self else { return }
                    if self.isPlayerWindowVisible {
                        self.hidePlayerWindow()
                    }
                }
            }
        }
        
        // Auto-detect if user just returned from Google Sign-In or arrived at YouTube Music
        if let url = webView.url?.absoluteString {
            if url.contains("music.youtube.com") {
                // Force an immediate DOM state scrape so Morph UI updates without waiting
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                    self?.evaluate("if (typeof window.morphSendUpdate === 'function') window.morphSendUpdate(true);")
                }
                // If watch URL was loaded directly, automatically start playback once page finishes loading
                if url.contains("/watch") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                        self?.play()
                    }
                }
                // Automatically fetch real library playlists and personalized quick picks
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
                    guard let self = self else { return }
                    self.evaluate("if (typeof window.morphSendUpdate === 'function') window.morphSendUpdate(true);")
                    if self.userPlaylists.isEmpty || Date().timeIntervalSince(self.lastLibrarySync ?? .distantPast) > 300 {
                        self.fetchRealUserPlaylists()
                    }
                    if self.quickPicks.isEmpty || self.quickPicks == YTMParser.defaultQuickPicks || Date().timeIntervalSince(self.lastQuickPicksSync ?? .distantPast) > 300 {
                        self.fetchQuickPicks()
                    }
                }
            }
        }
    }
    
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateNavigationState()
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && (nsError.code == NSURLErrorNotConnectedToInternet || nsError.code == NSURLErrorCannotFindHost || nsError.code == NSURLErrorNetworkConnectionLost) {
            self.isOffline = true
            self.connectionState = "Offline: No internet connection"
        } else {
            self.connectionState = "Load failed: \(error.localizedDescription)"
        }
    }
    
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        updateNavigationState()
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && (nsError.code == NSURLErrorNotConnectedToInternet || nsError.code == NSURLErrorCannotFindHost || nsError.code == NSURLErrorNetworkConnectionLost) {
            self.isOffline = true
            self.connectionState = "Offline: No internet connection"
        } else {
            self.connectionState = "Load failed: \(error.localizedDescription)"
        }
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
    private func cancelResumeRetries() {
        for item in resumeRetryWorkItems {
            item.cancel()
        }
        resumeRetryWorkItems.removeAll()
    }
    
    private func scheduleResumeRetries() {
        cancelResumeRetries()
        isResumeRequested = true
        guard !MorphEnvironment.isTestingEnvironment else { return }
        for delay in [0.25, 0.65, 1.25] {
            let workItem = DispatchWorkItem { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isResumeRequested else { return }
                    self.ensurePlaybackAndSync()
                }
            }
            resumeRetryWorkItems.append(workItem)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }
    
    public func ensurePlaybackAndSync() {
        ensurePlayback()
        evaluate("if (typeof window.morphSendUpdate === 'function') { window.morphSendUpdate(true); }")
    }
    
    public func play() {
        isResumeRequested = true
        trackData.isPlaying = true
        let script = """
        (function() {
            window._morphUserPaused = false;
            window._morphPauseLockoutUntil = 0;
            window._morphResumeLockoutUntil = Date.now() + 1400;
            if (typeof dismissModalsAndEnableAutoplay === 'function') {
                dismissModalsAndEnableAutoplay();
            }
            if (typeof window._morphResumeAudioContexts === 'function') {
                window._morphResumeAudioContexts();
            }
            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
            if (p && typeof p.playVideo === 'function') {
                try {
                    p.playVideo();
                } catch(e) {}
            }
            var v = document.querySelector('video');
            if (v && (v.paused || v.ended)) {
                var wasMuted = v.muted;
                var playPromise = v.play();
                if (playPromise !== undefined) {
                    playPromise.catch(function() {
                        // WebKit autoplay rejection: unlock via muted autoplay then restore mute state
                        v.muted = true;
                        v.play().then(function() {
                            setTimeout(function() {
                                v.muted = wasMuted;
                            }, 150);
                        }).catch(function(){});
                    });
                }
            }
            // Only click player-bar play button if playback genuinely did not start and the control says Play (never click a Pause button)
            var isActuallyPlaying = (v && !v.paused && !v.ended) || (p && typeof p.getPlayerState === 'function' && p.getPlayerState() === 1);
            if (!isActuallyPlaying) {
                var btn = document.querySelector('ytmusic-player-bar #play-pause-button') ||
                          document.querySelector('#play-pause-button') ||
                          document.querySelector('ytmusic-player-bar tp-yt-paper-icon-button#play-pause-button') ||
                          document.querySelector('ytmusic-player-bar [aria-label*="Play" i]') ||
                          document.querySelector('ytmusic-player-bar [aria-label*="Phát" i]');
                if (btn) {
                    var innerBtn = btn.querySelector('button, #button') || btn;
                    var label = (btn.getAttribute('aria-label') || btn.getAttribute('title') || innerBtn.getAttribute('aria-label') || innerBtn.getAttribute('title') || '').toLowerCase();
                    var saysPause = label.indexOf('pause') !== -1 || label.indexOf('tạm dừng') !== -1 || label.indexOf('stop') !== -1;
                    var saysPlay = label.indexOf('play') !== -1 || label.indexOf('phát') !== -1 || label.indexOf('resume') !== -1;
                    if (saysPlay && !saysPause) {
                        (innerBtn || btn).click();
                    }
                }
            }
            // If neither has started, start the first playable item / supermix on page
            if ((!p || typeof p.playVideo !== 'function') && (!v || !v.src)) {
                var firstPlay = document.querySelector('ytmusic-responsive-list-item-renderer #play-button, ytmusic-two-row-item-renderer #play-button, ytmusic-play-button-renderer #button, #play-button');
                if (firstPlay) {
                    firstPlay.click();
                }
            }
            if (typeof startTransitionWatchdog === 'function') {
                startTransitionWatchdog();
            }
            if (navigator.mediaSession) {
                navigator.mediaSession.playbackState = 'playing';
            }
            if (typeof window.morphSendUpdate === 'function') {
                window.morphSendUpdate(true);
                setTimeout(function() { window.morphSendUpdate(true); }, 50);
            }
        })();
        """
        evaluate(script)
        scheduleResumeRetries()
    }
    
    public func pause() {
        isResumeRequested = false
        cancelResumeRetries()
        trackData.isPlaying = false
        let script = """
        (function() {
            window._morphUserPaused = true;
            window._morphResumeLockoutUntil = 0;
            window._morphPauseLockoutUntil = Date.now() + 1400;
            _morphTransitionPending = false;
            _morphWasPlayingBeforeTransition = false;
            if (typeof _morphTransitionTimer !== 'undefined' && _morphTransitionTimer) {
                clearTimeout(_morphTransitionTimer);
                _morphTransitionTimer = null;
            }
            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
            if (p && typeof p.pauseVideo === 'function') {
                try {
                    p.pauseVideo();
                } catch(e) {}
            }
            var videos = document.querySelectorAll('video, audio');
            for (var i = 0; i < videos.length; i++) {
                try {
                    if (!videos[i].paused) {
                        videos[i].pause();
                    }
                } catch(e) {}
            }
            if (navigator.mediaSession) {
                navigator.mediaSession.playbackState = 'paused';
            }
            if (typeof window.morphSendUpdate === 'function') {
                window.morphSendUpdate(true);
            }
        })();
        """
        evaluate(script)
        if #available(macOS 11.3, *) {
            webView.pauseAllMediaPlayback()
        }
    }
    
    public func stop() {
        isResumeRequested = false
        cancelResumeRetries()
        trackData.isPlaying = false
        trackData.currentTime = 0
        let script = """
        (function() {
            window._morphUserPaused = true;
            window._morphResumeLockoutUntil = 0;
            window._morphPauseLockoutUntil = Date.now() + 1400;
            _morphTransitionPending = false;
            _morphWasPlayingBeforeTransition = false;
            if (typeof _morphTransitionTimer !== 'undefined' && _morphTransitionTimer) {
                clearTimeout(_morphTransitionTimer);
                _morphTransitionTimer = null;
            }
            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
            if (p && typeof p.stopVideo === 'function') {
                try { p.stopVideo(); } catch(e) {}
            }
            var videos = document.querySelectorAll('video, audio');
            for (var i = 0; i < videos.length; i++) {
                try {
                    videos[i].pause();
                    videos[i].currentTime = 0;
                } catch(e) {}
            }
            if (navigator.mediaSession) {
                navigator.mediaSession.playbackState = 'none';
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(function() { window.morphSendUpdate(true); }, 50);
            }
        })();
        """
        evaluate(script)
        if #available(macOS 11.3, *) {
            webView.pauseAllMediaPlayback()
        }
    }
    
    public func togglePlay() {
        if trackData.isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    public func ensurePlayback() {
        let script = """
        (function() {
            if (window._morphUserPaused) return;
            try {
                if (typeof window._morphResumeAudioContexts === 'function') {
                    window._morphResumeAudioContexts();
                }
                if (typeof dismissModalsAndEnableAutoplay === 'function') {
                    dismissModalsAndEnableAutoplay();
                }
                if (typeof ensureActivePlayback === 'function') {
                    ensureActivePlayback();
                }
                var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
                var v = document.querySelector('video');
                if (p && typeof p.getPlayerState === 'function') {
                    var s = p.getPlayerState();
                    if ((s === -1 || s === 2 || s === 5) && typeof p.playVideo === 'function') {
                        p.playVideo();
                    }
                }
                if (v && v.paused && !v.ended) {
                    var wasMuted = v.muted;
                    var promise = v.play();
                    if (promise !== undefined) {
                        promise.catch(function() {
                            v.muted = true;
                            v.play().then(function() {
                                setTimeout(function() { v.muted = wasMuted; }, 150);
                            }).catch(function(){});
                        });
                    }
                }
            } catch(e) {}
        })();
        """
        evaluate(script)
    }
    
    public func nextTrack() {
        self.trackData.currentTime = 0.0
        let script = """
        (function() {
            try {
                // 1. Dismiss any "Still watching" popups
                var confirmButtons = document.querySelectorAll(
                    'ytmusic-you-there-renderer #confirm-button, ' +
                    'tp-yt-paper-dialog #confirm-button, ' +
                    'yt-confirm-dialog-renderer #confirm-button, ' +
                    '.ytmusic-you-there-renderer button, ' +
                    'ytmusic-dialog-renderer button'
                );
                for (var i = 0; i < confirmButtons.length; i++) {
                    var cb = confirmButtons[i];
                    if (cb && (cb.offsetParent !== null || cb.offsetWidth > 0)) {
                        cb.click();
                    }
                }

                // 2. Ensure autoplay / automix toggle is enabled
                var automixToggle = document.querySelector('#automix-toggle tp-yt-paper-toggle-button') ||
                                    document.querySelector('ytmusic-player-queue tp-yt-paper-toggle-button') ||
                                    document.querySelector('.automix-toggle tp-yt-paper-toggle-button');
                if (automixToggle && !(automixToggle.hasAttribute('checked') || automixToggle.getAttribute('aria-checked') === 'true')) {
                    automixToggle.click();
                }

                // 3. Primary: Click Next Button on player bar
                var btn = document.querySelector('ytmusic-player-bar .next-button') || 
                          document.querySelector('#left-controls .next-button') || 
                          document.querySelector('.next-button.ytmusic-player-bar') ||
                          document.querySelector('tp-yt-paper-icon-button.next-button') ||
                          document.querySelector('.next-button') ||
                          document.querySelector('ytmusic-player-bar [aria-label*="Next" i]') ||
                          document.querySelector('ytmusic-player-bar [aria-label*="tiếp" i]');
                var clicked = false;
                if (btn && !(btn.disabled || btn.getAttribute('aria-disabled') === 'true')) {
                    var inner = btn.querySelector('button, #button');
                    (inner || btn).click();
                    btn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
                    clicked = true;
                }

                // 4. Fallback 1: Player API (direct invocation)
                var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
                if (p && typeof p.nextVideo === 'function') {
                    try { p.nextVideo(); } catch(e) {}
                }

                // 5. Fallback 2: Native Shift+N KeyboardEvent (Universal YouTube Music shortcut)
                if (!clicked) {
                    var shiftN = new KeyboardEvent('keydown', {
                        key: 'N',
                        code: 'KeyN',
                        keyCode: 78,
                        which: 78,
                        shiftKey: true,
                        bubbles: true,
                        cancelable: true
                    });
                    window.dispatchEvent(shiftN);
                    document.dispatchEvent(shiftN);
                    var playerBar = document.querySelector('ytmusic-player-bar');
                    if (playerBar) {
                        playerBar.dispatchEvent(shiftN);
                    }
                }

                // 6. Fallback 3: DOM Queue item fallback
                var queueItems = document.querySelectorAll('ytmusic-player-queue-item');
                if (queueItems && queueItems.length > 1) {
                    for (var qi = 0; qi < queueItems.length - 1; qi++) {
                        var item = queueItems[qi];
                        if (item.hasAttribute('selected') || item.classList.contains('selected') || item.getAttribute('play-state') === 'playing') {
                            var nextItem = queueItems[qi + 1];
                            var playTarget = nextItem.querySelector('#play-button, .play-button, ytmusic-play-button-renderer') || nextItem;
                            var innerTarget = playTarget.querySelector('button, #button');
                            (innerTarget || playTarget).click();
                            nextItem.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
                            break;
                        }
                    }
                }

                // 7. Ensure active video playback with WebKit unblocking
                var v = document.querySelector('video');
                if (v) {
                    var wasMuted = v.muted;
                    var playPromise = v.play();
                    if (playPromise !== undefined) {
                        playPromise.catch(function() {
                            v.muted = true;
                            v.play().then(function() {
                                setTimeout(function() { v.muted = wasMuted; }, 150);
                            }).catch(function(){});
                        });
                    }
                }
            } catch(e) {}
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 350);
            }
        })();
        """
        evaluate(script)
    }
    
    public func previousTrack(forcePreviousTrack: Bool = false) {
        let script = """
        (function() {
            try {
                var force = \(forcePreviousTrack ? "true" : "false");
                var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
                if (force && p && typeof p.previousVideo === 'function') {
                    p.previousVideo();
                    if (typeof window.morphSendUpdate === 'function') {
                        setTimeout(window.morphSendUpdate, 250);
                    }
                    return;
                }
                // 1. Primary: Click Previous Button on player bar
                var btn = document.querySelector('ytmusic-player-bar .previous-button') || 
                          document.querySelector('#left-controls .previous-button') || 
                          document.querySelector('.previous-button.ytmusic-player-bar') ||
                          document.querySelector('tp-yt-paper-icon-button.previous-button') ||
                          document.querySelector('.previous-button') ||
                          document.querySelector('ytmusic-player-bar [aria-label*="Previous" i]') ||
                          document.querySelector('ytmusic-player-bar [aria-label*="trước" i]');
                var clicked = false;
                if (btn && !(btn.disabled || btn.getAttribute('aria-disabled') === 'true')) {
                    btn.click();
                    clicked = true;
                }

                // 2. Fallback 1: Native Shift+P KeyboardEvent (Universal YouTube Music shortcut)
                if (!clicked) {
                    var shiftP = new KeyboardEvent('keydown', {
                        key: 'P',
                        code: 'KeyP',
                        keyCode: 80,
                        which: 80,
                        shiftKey: true,
                        bubbles: true,
                        cancelable: true
                    });
                    window.dispatchEvent(shiftP);
                    document.dispatchEvent(shiftP);
                    var playerBar = document.querySelector('ytmusic-player-bar');
                    if (playerBar) {
                        playerBar.dispatchEvent(shiftP);
                    }
                }

                // 3. Fallback 2: Player API
                var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
                if (!clicked && p && typeof p.previousVideo === 'function') {
                    try { p.previousVideo(); } catch(e) {}
                }

                // 4. Fallback 3: DOM Queue item fallback
                if (!clicked) {
                    var queueItems = document.querySelectorAll('ytmusic-player-queue-item');
                    if (queueItems && queueItems.length > 1) {
                        for (var qi = 1; qi < queueItems.length; qi++) {
                            var item = queueItems[qi];
                            if (item.hasAttribute('selected') || item.classList.contains('selected') || item.getAttribute('play-state') === 'playing') {
                                var prevItem = queueItems[qi - 1];
                                var playTarget = prevItem.querySelector('#play-button, .play-button, ytmusic-play-button-renderer') || prevItem;
                                playTarget.click();
                                break;
                            }
                        }
                    }
                }

                // 5. Ensure video playback
                var v = document.querySelector('video');
                if (v && v.paused) {
                    var wasMuted = v.muted;
                    v.play().catch(function() {
                        v.muted = true;
                        v.play().then(function() {
                            setTimeout(function() { v.muted = wasMuted; }, 150);
                        }).catch(function(){});
                    });
                }
            } catch(e) {}
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
                if (\(seconds) === 0 && typeof p.playVideo === 'function') {
                    p.playVideo();
                }
            } else {
                var v = document.querySelector('video');
                if (v && !isNaN(\(seconds))) {
                    v.currentTime = \(seconds);
                    if (\(seconds) === 0) {
                        v.play().catch(function(){});
                    }
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
    
    public func setMuted(_ muted: Bool) {
        let script = """
        (function() {
            var shouldMute = \(muted);
            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
            if (p) {
                if (shouldMute && typeof p.mute === 'function') {
                    p.mute();
                } else if (!shouldMute && typeof p.unMute === 'function') {
                    p.unMute();
                }
            }
            var v = document.querySelector('video');
            if (v) {
                v.muted = shouldMute;
            }
            if (typeof window.morphSendUpdate === 'function') {
                window.morphSendUpdate();
            }
        })();
        """
        evaluate(script)
    }
    
    public func setShuffle(_ enable: Bool) {
        trackData.isShuffle = enable
        let script = """
        (function() {
            window._morphTargetShuffle = \(enable);
            var btn = document.querySelector('ytmusic-player-bar .shuffle') || 
                      document.querySelector('#right-controls .shuffle') || 
                      document.querySelector('.shuffle.ytmusic-player-bar') ||
                      document.querySelector('tp-yt-paper-icon-button.shuffle') ||
                      document.querySelector('ytmusic-player-bar [aria-label*="Shuffle" i]') ||
                      document.querySelector('ytmusic-player-bar [aria-label*="xáo trộn" i]');
            if (btn) {
                var inner = btn.querySelector('button, #button') || (btn.shadowRoot && btn.shadowRoot.querySelector('button, #button')) || btn;
                var sTitle = (btn.getAttribute('title') || btn.getAttribute('aria-label') || inner.getAttribute('aria-label') || '').toLowerCase();
                var currentPressed = btn.getAttribute('aria-pressed') === 'true' || 
                                     inner.getAttribute('aria-pressed') === 'true' || 
                                     btn.classList.contains('active') ||
                                     sTitle.indexOf('on') !== -1 || sTitle.indexOf('bật') !== -1;
                var target = \(enable);
                if (currentPressed !== target) {
                    (inner || btn).click();
                    btn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
                }
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 200);
            }
        })();
        """
        evaluate(script)
    }

    public func toggleShuffle() {
        setShuffle(!trackData.isShuffle)
    }
    
    public func setRepeatMode(_ mode: YTMRepeatMode) {
        trackData.repeatMode = mode
        let script = """
        (function() {
            window._morphTargetRepeatMode = '\(mode.rawValue)';
            window._morphRepeatLockoutUntil = Date.now() + 2000;
            var repeatBtn = document.querySelector('ytmusic-player-bar .repeat') || 
                            document.querySelector('#right-controls .repeat') || 
                            document.querySelector('.repeat.ytmusic-player-bar') ||
                            document.querySelector('tp-yt-paper-icon-button.repeat') ||
                            document.querySelector('ytmusic-player-bar [aria-label*="Repeat" i]') ||
                            document.querySelector('ytmusic-player-bar [aria-label*="lặp lại" i]');
            if (repeatBtn) {
                var inner = repeatBtn.querySelector('button, #button') || (repeatBtn.shadowRoot && repeatBtn.shadowRoot.querySelector('button, #button')) || repeatBtn;
                function currentYTMMode() {
                    var rText = ((repeatBtn.getAttribute('aria-label') || '') + ' ' + 
                                 (repeatBtn.getAttribute('title') || '') + ' ' + 
                                 (inner.getAttribute('aria-label') || '') + ' ' + 
                                 (inner.getAttribute('title') || '') + ' ' +
                                 (repeatBtn.innerText || '')).toLowerCase();
                    var rPressed = repeatBtn.getAttribute('aria-pressed') === 'true' || 
                                   inner.getAttribute('aria-pressed') === 'true' ||
                                   repeatBtn.classList.contains('active');
                    if (rText.indexOf('one') !== -1 || rText.indexOf('1') !== -1 || rText.indexOf('một') !== -1) {
                        return 'one';
                    } else if (rText.indexOf('all') !== -1 || rText.indexOf('tất cả') !== -1 || (rPressed && rText.indexOf('off') === -1)) {
                        return 'all';
                    } else {
                        return 'off';
                    }
                }
                var target = '\(mode.rawValue)';
                var cur = currentYTMMode();
                var neededClicks = 0;
                if (cur !== target) {
                    if (cur === 'off') {
                        neededClicks = (target === 'all' ? 1 : 2);
                    } else if (cur === 'all') {
                        neededClicks = (target === 'one' ? 1 : 2);
                    } else if (cur === 'one') {
                        neededClicks = (target === 'off' ? 1 : 2);
                    }
                }
                for (var c = 0; c < neededClicks; c++) {
                    (function(delay) {
                        setTimeout(function() {
                            (inner || repeatBtn).click();
                        }, delay);
                    })(c * 150);
                }
                setTimeout(function() {
                    window._morphTargetRepeatMode = currentYTMMode();
                }, (neededClicks * 150) + 100);
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 350);
            }
        })();
        """
        evaluate(script)
    }
    
    public func toggleRepeat() {
        let nextMode = trackData.repeatMode.next
        setRepeatMode(nextMode)
    }
    
    public func toggleLike() {
        let script = """
        (function() {
            var btn = document.querySelector('ytmusic-like-button-renderer #like-button') || 
                      document.querySelector('ytmusic-player-bar ytmusic-like-button-renderer #like-button') ||
                      document.querySelector('ytmusic-like-button-renderer .like') ||
                      document.querySelector('#like-button-renderer yt-icon-button.like') || 
                      document.querySelector('ytmusic-like-button-renderer [aria-label*="Like" i]') ||
                      document.querySelector('ytmusic-like-button-renderer [aria-label*="Thích" i]') ||
                      document.querySelector('ytmusic-like-button-renderer yt-button-shape:first-child') ||
                      document.querySelector('ytmusic-player-bar ytmusic-like-button-renderer button');
            if (btn) {
                btn.click();
                if (btn.tagName && btn.tagName.toLowerCase().indexOf('-') === -1) {
                    var inner = btn.querySelector('button, #button');
                    if (inner) inner.click();
                }
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
                      document.querySelector('ytmusic-player-bar ytmusic-like-button-renderer #dislike-button') ||
                      document.querySelector('ytmusic-like-button-renderer .dislike') ||
                      document.querySelector('#like-button-renderer yt-icon-button.dislike') || 
                      document.querySelector('ytmusic-like-button-renderer [aria-label*="Dislike" i]') ||
                      document.querySelector('ytmusic-like-button-renderer [aria-label*="Không thích" i]') ||
                      document.querySelector('ytmusic-like-button-renderer yt-button-shape:last-child') ||
                      document.querySelector('ytmusic-player-bar ytmusic-like-button-renderer button');
            if (btn) {
                btn.click();
                if (btn.tagName && btn.tagName.toLowerCase().indexOf('-') === -1) {
                    var inner = btn.querySelector('button, #button');
                    if (inner) inner.click();
                }
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 250);
            }
        })();
        """
        evaluate(script)
    }
    
    public func playQueueIndex(_ index: Int, videoId: String? = nil, title: String? = nil, artist: String? = nil) {
        let vidArg = videoId.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"
        let titleArg = title.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"
        let artistArg = artist.map { "'\($0.replacingOccurrences(of: "'", with: "\\'"))'" } ?? "null"
        
        let script = """
        (function() {
            window._morphUserPaused = false;
            var targetIdx = \(index);
            var targetVid = \(vidArg);
            var targetTitle = \(titleArg);
            var targetArtist = \(artistArg);
            
            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
            var played = false;
            
            // 1. Try movie_player API playVideoAt
            if (p && typeof p.playVideoAt === 'function') {
                try {
                    p.playVideoAt(\(index));
                    played = true;
                } catch(e) {}
            }
            
            // 2. DOM Queue Item fallback or targeted matching
            var items = document.querySelectorAll('ytmusic-player-queue-item, ytmusic-player-queue #contents ytmusic-player-queue-item');
            if (items && items.length > 0) {
                var targetItem = null;
                // If title or videoId provided, search for matching DOM element
                if (targetTitle) {
                    var normTarget = targetTitle.toLowerCase();
                    for (var i = 0; i < items.length; i++) {
                        var it = items[i];
                        var tEl = it.querySelector('.song-title') || it.querySelector('.title') || it.querySelector('yt-formatted-string.song-title');
                        var itTitle = (tEl ? (tEl.innerText || tEl.textContent || '') : '').toLowerCase();
                        if (itTitle && (itTitle === normTarget || itTitle.indexOf(normTarget) !== -1 || normTarget.indexOf(itTitle) !== -1)) {
                            targetItem = it;
                            break;
                        }
                    }
                }
                if (!targetItem && targetIdx >= 0 && targetIdx < items.length) {
                    targetItem = items[targetIdx];
                }
                if (targetItem) {
                    var playBtn = targetItem.querySelector('#play-button, .play-button, ytmusic-play-button-renderer') || targetItem;
                    var inner = playBtn.querySelector('button, #button');
                    (inner || playBtn).click();
                    targetItem.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
                    played = true;
                }
            }
            
            // 3. WebKit Autoplay Unblocker & Watchdog Kickoff
            var v = document.querySelector('video');
            if (v) {
                var wasMuted = v.muted;
                var promise = v.play();
                if (promise !== undefined) {
                    promise.catch(function() {
                        v.muted = true;
                        v.play().then(function() {
                            setTimeout(function() { v.muted = wasMuted; }, 150);
                        }).catch(function(){});
                    });
                }
            }
            if (typeof startTransitionWatchdog === 'function') {
                startTransitionWatchdog();
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 250);
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
    /// Test seam: when set, replaces URLSession for direct HTTP InnerTube calls.
    public var urlSessionOverride: (@Sendable (URLRequest) async throws -> (Data, URLResponse))?
    
    private var isWebViewReadyForInnerTube: Bool {
        guard let host = webView.url?.host else { return false }
        return host.hasSuffix("music.youtube.com")
    }
    
    private func waitUntilReady(timeout: TimeInterval = 12) async throws {
        if MorphEnvironment.isTestingEnvironment && innerTubeOverride == nil && !isWebViewReadyForInnerTube {
            throw InnerTubeError.notReady
        }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isWebViewReadyForInnerTube {
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
        let intendedEmail = self.effectiveUserEmail ?? ""
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        let bodyJSON = String(decoding: bodyData, as: UTF8.self)
        let js = """
        const cfg = (window.ytcfg && typeof window.ytcfg.get === 'function') ? window.ytcfg : null;
        let context = cfg ? cfg.get('INNERTUBE_CONTEXT') : null;
        if (!context) { context = { client: { clientName: 'WEB_REMIX', clientVersion: '1.20250310.01.00', hl: 'en', gl: 'US' } }; }
        const apiKey = cfg ? cfg.get('INNERTUBE_API_KEY') : null;
        const payload = JSON.parse(bodyJSON);
        payload.context = context;
        let intendedAuth = '\(intendedEmail)';
        const urlParams = new URLSearchParams(window.location.search);
        let urlAuth = urlParams.get('authuser') || '';
        let targetAuth = (context && context.user && typeof context.user.authuser !== 'undefined') 
            ? context.user.authuser 
            : (urlAuth.length > 0 ? urlAuth : (intendedAuth.length > 0 ? intendedAuth : '0'));
        payload.context.user = payload.context.user || {};
        payload.context.user.authuser = String(targetAuth);
        const headers = { 'Content-Type': 'application/json', 'X-Goog-AuthUser': String(targetAuth), 'X-Origin': 'https://music.youtube.com' };
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
            let nsErr = error as NSError
            let jsMsg = (nsErr.userInfo["WKJavaScriptExceptionMessage"] as? String) ?? ""
            let msg = jsMsg.isEmpty ? error.localizedDescription : "\(jsMsg) \(error.localizedDescription)"
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
    
    /// Calls InnerTube directly via URLSession with WEB_REMIX headers (and WebKit session cookies if signed in)
    /// so catalog search and public browse work immediately even when WKWebView has not finished booting.
    private func directInnerTubeHTTP(_ endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        guard let url = URL(string: "https://music.youtube.com/youtubei/v1/\(endpoint)?prettyPrint=false") else {
            throw InnerTubeError.invalidResponse
        }
        let intendedAuth = self.effectiveUserEmail ?? "0"
        var payload = body
        payload["context"] = [
            "client": [
                "clientName": "WEB_REMIX",
                "clientVersion": "1.20250310.01.00",
                "hl": "en",
                "gl": "US"
            ],
            "user": [
                "authuser": intendedAuth
            ]
        ]
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://music.youtube.com", forHTTPHeaderField: "Origin")
        request.setValue("https://music.youtube.com/", forHTTPHeaderField: "Referer")
        request.setValue("67", forHTTPHeaderField: "X-Youtube-Client-Name")
        request.setValue("1.20250310.01.00", forHTTPHeaderField: "X-Youtube-Client-Version")
        request.setValue(intendedAuth, forHTTPHeaderField: "X-Goog-AuthUser")
        request.setValue(kCustomUserAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        if urlSessionOverride == nil && !MorphEnvironment.isTestingEnvironment {
            let allCookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
            let now = Date()
            let ytmCookies = allCookies.filter { cookie in
                if let exp = cookie.expiresDate, exp < now { return false }
                let d = cookie.domain.lowercased()
                return d == "music.youtube.com" || d == ".music.youtube.com" || d == ".youtube.com" || d == "youtube.com"
            }
            if !ytmCookies.isEmpty {
                request.setValue(ytmCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; "), forHTTPHeaderField: "Cookie")
                if let sapisid = ytmCookies.first(where: { $0.name == "SAPISID" || $0.name == "__Secure-3PAPISID" || $0.name == "__Secure-1PAPISID" })?.value {
                    let ts = Int(Date().timeIntervalSince1970)
                    let digest = Insecure.SHA1.hash(data: Data("\(ts) \(sapisid) https://music.youtube.com".utf8))
                    let hex = digest.map { String(format: "%02x", $0) }.joined()
                    request.setValue("SAPISIDHASH \(ts)_\(hex)", forHTTPHeaderField: "Authorization")
                }
            }
        }
        
        let (data, response): (Data, URLResponse)
        if let override = urlSessionOverride {
            (data, response) = try await override(request)
        } else if MorphEnvironment.isTestingEnvironment {
            throw InnerTubeError.notReady
        } else {
            (data, response) = try await URLSession.shared.data(for: request)
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw InnerTubeError.http(http.statusCode)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw InnerTubeError.invalidResponse
        }
        return json
    }
    
    /// Uses WebKit when ready on music.youtube.com, otherwise calls direct HTTP immediately (and falls back on error)
    /// so searches and browsing never block for 12s waiting on WKWebView.
    private func publicInnerTube(_ endpoint: String, body: [String: Any]) async throws -> [String: Any] {
        if let override = innerTubeOverride {
            return try await override(endpoint, body)
        }
        if urlSessionOverride != nil || !isWebViewReadyForInnerTube {
            return try await directInnerTubeHTTP(endpoint, body: body)
        }
        do {
            return try await innerTube(endpoint, body: body)
        } catch {
            return try await directInnerTubeHTTP(endpoint, body: body)
        }
    }
    
    // MARK: Library playlists
    public func fetchRealUserPlaylists() {
        Task { @MainActor [weak self] in
            await self?.refreshLibraryPlaylists()
        }
    }
    
    /// Scrapes playlists directly from the YouTube Music DOM if the engine's WKWebView has loaded the guide or library page.
    public func scrapePlaylistsFromDOM() async -> [YTMPlaylist] {
        guard let wv = self.webView else { return [] }
        return await withCheckedContinuation { continuation in
            let js = """
            (function() {
                var out = [];
                var seen = {};
                function cleanId(raw) {
                    if (!raw) return '';
                    var m = raw.match(/[?&]list=([a-zA-Z0-9_-]+)/);
                    if (m) return m[1];
                    if (raw.indexOf('browse/VL') !== -1) return raw.split('browse/VL')[1].split('/')[0];
                    return raw;
                }
                var entries = document.querySelectorAll('ytmusic-guide-entry-renderer, tp-yt-paper-item');
                for (var i = 0; i < entries.length; i++) {
                    var el = entries[i];
                    var a = el.querySelector('a[href*="list="], a[href*="browse/VL"]');
                    if (!a) continue;
                    var href = a.getAttribute('href') || '';
                    if (href.indexOf('watch?v=') !== -1) continue;
                    var id = cleanId(href);
                    if (!id || id.indexOf('RD') === 0 || id.indexOf('MPRE') === 0 || id.indexOf('OLAK') === 0) continue;
                    var titleEl = el.querySelector('yt-formatted-string') || el.querySelector('.title') || a;
                    var title = titleEl ? (titleEl.innerText || titleEl.textContent || '').trim() : '';
                    if (title && !seen[id]) {
                        seen[id] = true;
                        var clean = id.indexOf('VL') === 0 ? id.substring(2) : id;
                        var bId = id.indexOf('VL') === 0 ? id : ('VL' + id);
                        out.push({ id: clean, title: title, subtitle: "Playlist", browseId: bId, playbackListId: clean });
                    }
                }
                var cards = document.querySelectorAll('ytmusic-two-row-item-renderer');
                for (var j = 0; j < cards.length; j++) {
                    var c = cards[j];
                    var ca = c.querySelector('a[href*="list="], a[href*="browse/VL"]');
                    if (!ca) continue;
                    var chref = ca.getAttribute('href') || '';
                    if (chref.indexOf('watch?v=') !== -1) continue;
                    var cid = cleanId(chref);
                    if (!cid || cid.indexOf('RD') === 0 || cid.indexOf('MPRE') === 0 || cid.indexOf('OLAK') === 0) continue;
                    var ctitleEl = c.querySelector('.title a') || c.querySelector('.title') || c.querySelector('yt-formatted-string.title');
                    var ctitle = ctitleEl ? (ctitleEl.innerText || ctitleEl.textContent || '').trim() : '';
                    var csubEl = c.querySelector('.subtitle');
                    var csub = csubEl ? (csubEl.innerText || csubEl.textContent || '').trim() : 'Playlist';
                    if (csub.toLowerCase().indexOf('podcast') !== -1 || csub.toLowerCase().indexOf('episode') !== -1 || ctitle.toLowerCase().indexOf('podcast') !== -1) continue;
                    var cimg = c.querySelector('img');
                    var cthumb = cimg ? cimg.src : null;
                    var cleanCid = cid.indexOf('VL') === 0 ? cid.substring(2) : cid;
                    var bCid = cid.indexOf('VL') === 0 ? cid : ('VL' + cid);
                    if (seen[cid] || seen[cleanCid]) {
                        for (var k = 0; k < out.length; k++) {
                            if (out[k].id === cleanCid || out[k].id === cid) {
                                if (cthumb && !out[k].thumbnailURL) out[k].thumbnailURL = cthumb;
                                if (csub && out[k].subtitle === 'Playlist') out[k].subtitle = csub;
                            }
                        }
                    } else if (ctitle) {
                        seen[cid] = true;
                        seen[cleanCid] = true;
                        out.push({ id: cleanCid, title: ctitle, subtitle: csub, thumbnailURL: cthumb, browseId: bCid, playbackListId: cleanCid });
                    }
                }
                return JSON.stringify(out);
            })()
            """
            wv.evaluateJavaScript(js) { res, _ in
                guard let jsonStr = res as? String,
                      let data = jsonStr.data(using: .utf8),
                      let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    continuation.resume(returning: [])
                    return
                }
                var parsed: [YTMPlaylist] = []
                for dict in arr {
                    guard let id = dict["id"] as? String, !id.isEmpty,
                          let title = dict["title"] as? String, !title.isEmpty else { continue }
                    let sub = (dict["subtitle"] as? String) ?? "Playlist"
                    let thumb = dict["thumbnailURL"] as? String
                    let bId = dict["browseId"] as? String
                    let playId = dict["playbackListId"] as? String
                    parsed.append(YTMPlaylist(id: id, title: title, subtitle: sub, thumbnailURL: thumb, browseId: bId, kind: .playlist, playbackListId: playId))
                }
                continuation.resume(returning: parsed)
            }
        }
    }
    
    public func refreshLibraryPlaylists() async {
        isLoadingLibrary = true
        libraryError = nil
        defer { isLoadingLibrary = false }
        do {
            var all: [YTMPlaylist] = []
            var seenIds = Set<String>()
            
            // 1. Scrape directly from DOM if WKWebView is loaded
            let domPlaylists = await scrapePlaylistsFromDOM()
            for p in domPlaylists where seenIds.insert(p.id).inserted {
                all.append(p)
            }
            
            // 2. Query valid InnerTube browse endpoints
            // Prefer FEmusic_liked_playlists (dedicated Playlists section of user library)
            let targets = ["FEmusic_liked_playlists", "FEmusic_library_landing"]
            var lastError: Error?
            for target in targets {
                // If we already obtained real playlists from FEmusic_liked_playlists, do not pollute with library landing
                if !all.isEmpty && target == "FEmusic_library_landing" {
                    break
                }
                do {
                    let doc = try await publicInnerTube("browse", body: ["browseId": target])
                    var parsed = YTMParser.parseLibraryPlaylists(doc)
                    for p in parsed.playlists where seenIds.insert(p.id).inserted {
                        all.append(p)
                    }
                    var token = parsed.continuation
                    var lastToken: String?
                    var pages = 0
                    while let t = token, t != lastToken, pages < 10 {
                        lastToken = t
                        if let nextDoc = try? await publicInnerTube("browse", body: ["continuation": t]) {
                            parsed = YTMParser.parseLibraryPlaylists(nextDoc)
                            for p in parsed.playlists where seenIds.insert(p.id).inserted {
                                all.append(p)
                            }
                            token = parsed.continuation
                            pages += 1
                        } else {
                            break
                        }
                    }
                } catch {
                    lastError = error
                }
            }
            
            if all.isEmpty, let err = lastError {
                throw err
            }
            if !all.contains(where: { $0.id == "LM" }) && (isSignedIn || !all.isEmpty) {
                all.insert(YTMPlaylist(id: "LM", title: "Liked Music", subtitle: "Auto playlist", browseId: "VLLM", kind: .playlist, playbackListId: "LM"), at: 0)
            }
            if all.isEmpty {
                libraryError = isSignedIn ? nil : "Sign in to YouTube Music to see your playlists."
                let cached = YTMUserOfflineStore.shared.getStoredPlaylists(for: self.effectiveUserEmail)
                if !cached.isEmpty {
                    userPlaylists = cached
                }
            } else {
                userPlaylists = all
                lastLibrarySync = Date()
                YTMUserOfflineStore.shared.savePlaylists(all, for: self.effectiveUserEmail)
            }
        } catch {
            libraryError = error.localizedDescription
            let cached = YTMUserOfflineStore.shared.getStoredPlaylists(for: self.effectiveUserEmail)
            if !cached.isEmpty && self.userPlaylists.isEmpty {
                self.userPlaylists = cached
            }
        }
    }
    
    // MARK: Quick Picks
    public func fetchQuickPicks() {
        Task { @MainActor [weak self] in
            await self?.refreshQuickPicks()
        }
    }
    
    public func refreshQuickPicks() async {
        isLoadingQuickPicks = true
        quickPicksError = nil
        defer { isLoadingQuickPicks = false }
        do {
            let doc = try await publicInnerTube("browse", body: ["browseId": "FEmusic_home"])
            let parsed = YTMParser.parseQuickPicks(doc)
            if !parsed.isEmpty {
                self.quickPicks = parsed
                self.lastQuickPicksSync = Date()
            } else if self.quickPicks.isEmpty {
                self.quickPicks = YTMParser.defaultQuickPicks
            }
        } catch {
            self.quickPicksError = error.localizedDescription
            if self.quickPicks.isEmpty {
                self.quickPicks = YTMParser.defaultQuickPicks
            }
        }
    }
    
    // MARK: Tracks of a playlist / album / artist
    private func browseId(for playlist: YTMPlaylist) -> String {
        switch playlist.kind {
        case .artist, .album:
            let raw = playlist.browseId ?? playlist.id
            return raw.replacingOccurrences(of: "/channel/", with: "")
        default:
            var raw = playlist.browseId ?? playlist.id
            if let range = raw.range(of: "list=") {
                raw = String(raw[range.upperBound...])
                if let amp = raw.firstIndex(of: "&") {
                    raw = String(raw[..<amp])
                }
            }
            if raw.hasPrefix("VL") { return raw }
            if raw.hasPrefix("FE") || raw.hasPrefix("UC") || raw.hasPrefix("MPRE") { return raw }
            return "VL\(raw)"
        }
    }
    
    private func loadAllPages(browseId: String, maxTracks: Int = 1500) async throws -> YTMTrackPage {
        print("[Morph YTM] loadAllPages requesting browseId: '\(browseId)'")
        let doc = try await publicInnerTube("browse", body: ["browseId": browseId])
        var page = YTMParser.parseTrackPage(doc)
        var token = page.continuation
        var lastToken: String?
        var guardCount = 0
        while let t = token, t != lastToken, page.tracks.count < maxTracks, guardCount < 40 {
            lastToken = t
            guardCount += 1
            let next = YTMParser.parseTrackPage(try await publicInnerTube("browse", body: ["continuation": t]), startIndex: page.tracks.count)
            if next.tracks.isEmpty { break }
            page.tracks += next.tracks
            token = next.continuation
        }
        page.tracks = YTMPlaylistItem.deduplicate(page.tracks)
        page.continuation = nil
        print("[Morph YTM] loadAllPages parsed \(page.tracks.count) tracks for browseId: '\(browseId)'")
        return page
    }
    
    /// Loads the real tracks of a playlist, album or artist. For artists this returns the full "Top songs" list
    /// (falling back to the handful of songs shown on the artist page).
    public func loadTracks(for playlist: YTMPlaylist) async throws -> YTMTrackPage {
        let bId = browseId(for: playlist)
        print("[Morph YTM] loadTracks for playlist: '\(playlist.title)' (id: '\(playlist.id)', kind: \(playlist.kind), browseId: '\(bId)')")
        var page = (try? await loadAllPages(browseId: bId)) ?? YTMTrackPage()
        
        // If 0 tracks returned with current browseId, attempt alternate browseId (toggle VL prefix)
        if page.tracks.isEmpty {
            let altId = bId.hasPrefix("VL") ? String(bId.dropFirst(2)) : "VL\(bId)"
            if let altPage = try? await loadAllPages(browseId: altId), !altPage.tracks.isEmpty {
                page = altPage
            }
        }
        
        // Liked Music endpoint fallback: if Liked Music has 0 tracks with VLLM/LM, query FEmusic_liked_videos
        if page.tracks.isEmpty && (playlist.id == "LM" || playlist.id == "VLLM" || playlist.title.lowercased().contains("liked")) {
            if let likedPage = try? await loadAllPages(browseId: "FEmusic_liked_videos"), !likedPage.tracks.isEmpty {
                page = likedPage
            }
        }
        
        // If still 0 tracks, fall back to locally stored tracks for this playlist
        if page.tracks.isEmpty {
            let cached = YTMUserOfflineStore.shared.getStoredTracks(forPlaylist: playlist.id, email: self.effectiveUserEmail)
            if !cached.isEmpty {
                page.tracks = cached
            }
        }
        
        if playlist.kind == .artist, let more = page.moreBrowseId, more.hasPrefix("VL") {
            print("[Morph YTM] Fetching full top songs for artist via moreBrowseId: '\(more)'")
            if let full = try? await loadAllPages(browseId: more), full.tracks.count > page.tracks.count {
                page.tracks = full.tracks
            }
        }
        if page.playbackListId == nil, playlist.kind == .playlist {
            page.playbackListId = playlist.playbackListId ?? (playlist.id.hasPrefix("VL") ? String(playlist.id.dropFirst(2)) : playlist.id)
        }
        
        // Persist the loaded tracks in the offline store so they are instantly accessible
        if !page.tracks.isEmpty {
            YTMUserOfflineStore.shared.savePlaylistTracks(page.tracks, forPlaylist: playlist.id, email: self.effectiveUserEmail)
        }
        
        return page
    }
    
    // MARK: Catalog search (songs, artists, albums, playlists)
    public func searchCatalog(_ query: String) async throws -> [YTMSearchResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let doc = try await publicInnerTube("search", body: ["query": q])
        return YTMParser.parseSearch(doc)
    }
    
    // MARK: Live Search Suggestions / Autocomplete
    public func fetchSearchSuggestions(_ query: String) async -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return [] }
        if let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=\(encoded)") {
            var req = URLRequest(url: url)
            req.timeoutInterval = 2.5
            req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [Any], json.count > 1,
               let list = json[1] as? [String], !list.isEmpty {
                return Array(list.prefix(6))
            }
        }
        
        // Fallback: InnerTube music/get_search_suggestions
        if let doc = try? await publicInnerTube("music/get_search_suggestions", body: ["input": q]) {
            return YTMParser.parseSearchSuggestions(doc)
        }
        return []
    }
    
    // MARK: Direct playback by video id
    public func play(videoId: String, listId: String? = nil, fallbackToRadio: Bool = false) {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        let vid = videoId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !vid.isEmpty else { return }
        
        // Normalize listId: strip "VL" browse prefix if present (YouTube watch requires "PL..." or "LM", not "VLPL...")
        var cleanList: String? = listId?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let l = cleanList, l.hasPrefix("VL") {
            cleanList = String(l.dropFirst(2))
        }
        
        // Continuous Playback: Only fallback to radio if explicitly requested
        if (cleanList == nil || cleanList?.isEmpty == true) && fallbackToRadio {
            cleanList = "RDAMVM\(vid)"
        }
        
        // 1. Try immediate in-page playback via movie_player API (seamless, zero full-page reload, preserves WebKit session)
        let listArg = cleanList.map { "'\($0)'" } ?? "null"
        let script = """
        (function() {
            window._morphUserPaused = false;
            window._morphPauseLockoutUntil = 0;
            window._morphResumeLockoutUntil = Date.now() + 1400;
            if (typeof window._morphResumeAudioContexts === 'function') {
                window._morphResumeAudioContexts();
            }
            var vid = '\(vid)';
            var listId = \(listArg);
            
            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
            var played = false;
            if (p) {
                try {
                    if (typeof p.loadVideoById === 'function') {
                        // Direct Song Guarantee: never let RDAMVM automix radio hijack or reorder the first song played!
                        if (listId && listId.length > 0 && listId.indexOf('RDAMVM') === -1) {
                            try {
                                p.loadVideoById({ videoId: vid, list: listId });
                            } catch(e1) {
                                p.loadVideoById(vid);
                            }
                        } else {
                            p.loadVideoById(vid);
                        }
                        played = true;
                    } else if (typeof p.loadVideoByPlayerVars === 'function') {
                        if (listId && listId.length > 0 && listId.indexOf('RDAMVM') === -1) {
                            p.loadVideoByPlayerVars({ videoId: vid, list: listId });
                        } else {
                            p.loadVideoByPlayerVars({ videoId: vid });
                        }
                        played = true;
                    }
                    if (typeof p.playVideo === 'function') {
                        p.playVideo();
                    }
                    var v = document.querySelector('video');
                    if (v) {
                        var wasMuted = v.muted;
                        var promise = v.play();
                        if (promise !== undefined) {
                            promise.catch(function() {
                                v.muted = true;
                                v.play().then(function() {
                                    setTimeout(function() { v.muted = wasMuted; }, 150);
                                }).catch(function(){});
                            });
                        }
                    }
                    if (typeof window.morphSendUpdate === 'function') {
                        setTimeout(window.morphSendUpdate, 250);
                    }
                    return true;
                } catch(e) {}
            }
            
            // 2. Fallback: Trigger Polymer client-side link navigation if movie_player API is not yet loaded
            if (!played) {
                try {
                    var watchPath = '/watch?v=' + encodeURIComponent(vid) + (listId ? ('&list=' + encodeURIComponent(listId)) : '');
                    var link = document.createElement('a');
                    link.href = watchPath;
                    document.body.appendChild(link);
                    link.click();
                    link.remove();
                    played = true;
                } catch(eNav) {}
            }
            if (!played) {
                // Fallback inside page: navigate to absolute canonical URL (never relative, which throws SyntaxError in WebKit)
                var target = 'https://music.youtube.com/watch?v=' + encodeURIComponent(vid) + (listId ? ('&list=' + encodeURIComponent(listId)) : '');
                window.location.href = target;
            }
            return false;
        })();
        """
        
        // If webView is already on music.youtube.com, evaluate the script
        trackData.isPlaying = true
        if let host = webView.url?.host, host.hasSuffix("music.youtube.com") {
            evaluate(script)
            scheduleResumeRetries()
        } else {
            // Initial cold load: construct full watch URL
            var comps = URLComponents(string: "https://music.youtube.com/watch")!
            var items = [URLQueryItem(name: "v", value: vid)]
            if let l = cleanList, !l.isEmpty {
                items.append(URLQueryItem(name: "list", value: l))
            }
            comps.queryItems = items
            if let url = comps.url {
                webView.load(URLRequest(url: url))
            }
        }
    }
    

    public func playPlaylistSong(index: Int) {
        trackData.isPlaying = true
        let script = """
        (function() {
            window._morphUserPaused = false;
            window._morphPauseLockoutUntil = 0;
            window._morphResumeLockoutUntil = Date.now() + 1400;
            if (typeof window._morphResumeAudioContexts === 'function') {
                window._morphResumeAudioContexts();
            }
            var items = document.querySelectorAll('ytmusic-responsive-list-item-renderer');
            if (items && items.length > \(index)) {
                var target = items[\(index)];
                var playBtn = target.querySelector('#play-button, .play-button, ytmusic-play-button-renderer') || target;
                var inner = playBtn.querySelector('button, #button');
                (inner || playBtn).click();
                target.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 350);
            }
        })();
        """
        evaluate(script)
        scheduleResumeRetries()
    }
    
    public func playEntirePlaylist() {
        trackData.isPlaying = true
        let script = """
        (function() {
            window._morphUserPaused = false;
            window._morphPauseLockoutUntil = 0;
            window._morphResumeLockoutUntil = Date.now() + 1400;
            if (typeof window._morphResumeAudioContexts === 'function') {
                window._morphResumeAudioContexts();
            }
            var playBtn = document.querySelector('ytmusic-play-button-renderer #button, ytmusic-responsive-header-renderer #play-button, #play-button, tp-yt-paper-button.play-button');
            if (playBtn) {
                var inner = playBtn.querySelector('button, #button');
                (inner || playBtn).click();
            } else {
                var firstTrack = document.querySelector('ytmusic-responsive-list-item-renderer');
                if (firstTrack) {
                    var pBtn = firstTrack.querySelector('#play-button, .play-button');
                    (pBtn || firstTrack).click();
                }
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 350);
            }
        })();
        """
        evaluate(script)
        scheduleResumeRetries()
    }
    
    public func playSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://music.youtube.com/search?q=\(encoded)") else { return }
        
        trackData.isPlaying = true
        self.webView.load(URLRequest(url: url))
        
        // Auto-click the first playable track or album in search results
        let autoPlayScript = """
        window._morphUserPaused = false;
        window._morphPauseLockoutUntil = 0;
        window._morphResumeLockoutUntil = Date.now() + 1400;
        var checkCount = 0;
        var checkInterval = setInterval(function() {
            checkCount++;
            var firstPlay = document.querySelector('ytmusic-responsive-list-item-renderer #play-button, ytmusic-shelf-renderer #play-button, ytmusic-two-row-item-renderer #play-button, ytmusic-play-button-renderer #button');
            if (firstPlay) {
                clearInterval(checkInterval);
                var inner = firstPlay.querySelector('button, #button');
                (inner || firstPlay).click();
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
        self.lastEvaluatedScript = js
        self.onEvaluate?(js)
        webView.evaluateJavaScript(js) { _, error in
            if let error = error {
                let nsErr = error as NSError
                let detail = nsErr.userInfo["WKJavaScriptExceptionMessage"] as? String
                    ?? nsErr.userInfo["WKJavaScriptExceptionSourceURL"] as? String
                    ?? error.localizedDescription
                let line = nsErr.userInfo["WKJavaScriptExceptionLineNumber"] as? Int
                if let line = line {
                    print("[Morph YTM Engine Error]: \(detail) (line \(line))")
                } else {
                    print("[Morph YTM Engine Error]: \(detail)")
                }
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
    
    // MARK: - NotchPanel View Hierarchy Attachment (Zero Ghost Windows)
    
    /// Attaches the engine's background webView to a hosting view (e.g. Morph's NotchPanel hostingView).
    /// This establishes webView.window != nil within Morph's actual UI window hierarchy,
    /// completely eliminating the need for an invisible, ghost NSWindow on the user's desktop screen.
    public func attachToHostingView(_ containerView: NSView) {
        if self.webView.superview !== containerView {
            self.webView.removeFromSuperview()
            self.webView.frame = NSRect(x: -2000, y: -2000, width: 800, height: 600)
            self.webView.autoresizingMask = []
            containerView.addSubview(self.webView)
        }
        if !MorphEnvironment.isTestingEnvironment && self.webView.url == nil {
            loadHome()
        }
    }
    
    // MARK: - Browser-Based Authentication & Tab Management
    
    /// Opens the Google / YouTube Music sign-in page in the user's external web browser.
    /// Once signed in, the user can close the browser tab, and Morph will wire YouTube Music directly.
    public func openSignInInBrowser() {
        let signInURLString = "https://accounts.google.com/ServiceLogin?service=youtube&passive=true&continue=https%3A%2F%2Fmusic.youtube.com%2F"
        guard let url = URL(string: signInURLString) else { return }
        openInSystemBrowser(url: url)
    }
    
    /// Opens YouTube Music directly in the external web browser.
    public func openYouTubeMusicInBrowser() {
        guard let url = URL(string: kYTMURL) else { return }
        openInSystemBrowser(url: url)
    }
    
    private func openInSystemBrowser(url: URL) {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        
        // Reuse existing browser tab if one is already open to decrease tab clutter
        if reuseExistingBrowserTabIfPossible(targetURL: url) {
            return
        }
        
        if let defaultBrowserAppURL = NSWorkspace.shared.urlForApplication(toOpen: url) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            NSWorkspace.shared.open([url], withApplicationAt: defaultBrowserAppURL, configuration: config, completionHandler: nil)
        } else {
            NSWorkspace.shared.open(url)
        }
    }
    
    @discardableResult
    private func reuseExistingBrowserTabIfPossible(targetURL: URL) -> Bool {
        // 1. Google Chrome
        let chromeScript = """
        tell application "Google Chrome"
            repeat with w in windows
                set tabIndex to 1
                repeat with t in tabs of w
                    set theURL to (URL of t as text)
                    if theURL contains "music.youtube.com" or theURL contains "accounts.google.com" then
                        set URL of t to "\(targetURL.absoluteString)"
                        set active tab index of w to tabIndex
                        set index of w to 1
                        activate
                        return true
                    end if
                    set tabIndex to tabIndex + 1
                end repeat
            end repeat
            return false
        end tell
        """
        
        if MorphAppleScriptRunner.runBoolean(chromeScript, timeout: 2.5) {
            return true
        }
        
        // 2. Safari
        let safariScript = """
        tell application "Safari"
            repeat with w in windows
                set tabIndex to 1
                repeat with t in tabs of w
                    set theURL to (URL of t as text)
                    if theURL contains "music.youtube.com" or theURL contains "accounts.google.com" then
                        set URL of t to "\(targetURL.absoluteString)"
                        set current tab of w to t
                        set index of w to 1
                        activate
                        return true
                    end if
                    set tabIndex to tabIndex + 1
                end repeat
            end repeat
            return false
        end tell
        """
        
        if MorphAppleScriptRunner.runBoolean(safariScript, timeout: 2.5) {
            return true
        }
        
        return false
    }
    
    /// Synchronizes cookies and session state from an active YouTube Music tab in Chrome or Safari,
    /// injecting them into Morph's WKWebsiteDataStore so the user can close their browser tab
    /// and control YouTube Music directly from Morph itself.
    public func syncSessionFromBrowser() {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            // Check Google Chrome for music.youtube.com cookies
            let chromeCookieScript = """
            tell application "Google Chrome"
                repeat with w in windows
                    repeat with t in tabs of w
                        if (URL of t) contains "music.youtube.com" then
                            try
                                return execute t javascript "document.cookie"
                            end try
                        end if
                    end repeat
                end repeat
                return ""
            end tell
            """
            
            var rawCookies = MorphAppleScriptRunner.run(chromeCookieScript, timeout: 2.5) ?? ""
            
            // Check Safari if Chrome didn't have cookies
            if rawCookies.isEmpty {
                let safariCookieScript = """
                tell application "Safari"
                    repeat with w in windows
                        repeat with t in tabs of w
                            if (URL of t) contains "music.youtube.com" then
                                try
                                    return do JavaScript "document.cookie" in t
                                end try
                            end if
                        end repeat
                    end repeat
                    return ""
                end tell
                """
                rawCookies = MorphAppleScriptRunner.run(safariCookieScript, timeout: 2.5) ?? ""
            }
            
            guard !rawCookies.isEmpty else { return }
            
            // Parse cookies string ("key=value; key2=val2")
            let cookiePairs = rawCookies.components(separatedBy: ";")
            let cookieStore = await MainActor.run { WKWebsiteDataStore.default().httpCookieStore }
            var hasRealAuthCookie = false
            
            for pair in cookiePairs {
                let parts = pair.components(separatedBy: "=")
                guard parts.count >= 2 else { continue }
                let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, !value.isEmpty else { continue }
                
                if name == "SAPISID" || name == "__Secure-3PAPISID" || name == "__Secure-1PAPISID" || name == "SSID" || name == "LOGIN_INFO" {
                    hasRealAuthCookie = true
                }
                
                let props: [HTTPCookiePropertyKey: Any] = [
                    .name: name,
                    .value: value,
                    .domain: ".youtube.com",
                    .path: "/",
                    .secure: "TRUE"
                ]
                if let cookie = HTTPCookie(properties: props) {
                    await cookieStore.setCookie(cookie)
                }
            }
            
            await MainActor.run {
                if hasRealAuthCookie {
                    self.isSignedIn = true
                    self.fetchRealUserPlaylists()
                    // Reload internal webView to apply the newly imported session cookies
                    self.loadHome()
                } else {
                    // If HttpOnly credentials were not returned by document.cookie, check existing WK website data store cookies
                    self.checkAuthCookies()
                }
            }
        }
    }
    
    // MARK: - On-Demand Dedicated Web View Window (Zero Ghost Windows On Launch)
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
            self?.hidePlayerWindow()
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
        
        // Zero ghost windows: do NOT order back with alpha = 0.0.
        // The window stays off-screen until explicitly shown via showPlayerWindow().
        win.alphaValue = 1.0
        win.ignoresMouseEvents = false
        
        self.playerWindow = win
        return win
    }
    
    public func showPlayerWindow() {
        guard !MorphEnvironment.isTestingEnvironment else { return }
        let win = ensurePlayerWindow()
        win.ignoresMouseEvents = false
        win.alphaValue = 1.0
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.isPlayerWindowVisible = true
    }
    
    public func hidePlayerWindow() {
        if let win = playerWindow {
            win.orderOut(nil)
            // Re-attach webView back to NotchPanel offscreen so background playback continues seamlessly
            if let hostingView = MorphController.shared?.hostingView {
                attachToHostingView(hostingView)
            }
        }
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
    var chromeStealthJavaScript: String {
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
            
            // 6. Track Web Audio API AudioContexts so Morph can resume suspended contexts on F8 resume
            try {
                window._morphAudioContexts = window._morphAudioContexts || [];
                window._morphResumeAudioContexts = function() {
                    try {
                        var list = window._morphAudioContexts || [];
                        for (var i = 0; i < list.length; i++) {
                            var ctx = list[i];
                            if (ctx && ctx.state === 'suspended' && typeof ctx.resume === 'function') {
                                ctx.resume().catch(function(){});
                            }
                        }
                    } catch(e) {}
                };
                var _morphWrapAudioCtx = function(OrigCtor) {
                    if (!OrigCtor || OrigCtor._morphWrapped) return OrigCtor;
                    var Wrapped = function() {
                        var instance = Reflect.construct(OrigCtor, arguments, new.target || Wrapped);
                        try {
                            if (window._morphAudioContexts.length > 8) {
                                window._morphAudioContexts.shift();
                            }
                            window._morphAudioContexts.push(instance);
                        } catch(e) {}
                        return instance;
                    };
                    Wrapped.prototype = OrigCtor.prototype;
                    try { Object.setPrototypeOf(Wrapped, OrigCtor); } catch(e) {}
                    Wrapped._morphWrapped = true;
                    return Wrapped;
                };
                if (typeof window.AudioContext === 'function') {
                    window.AudioContext = _morphWrapAudioCtx(window.AudioContext);
                }
                if (typeof window.webkitAudioContext === 'function') {
                    window.webkitAudioContext = _morphWrapAudioCtx(window.webkitAudioContext);
                }
            } catch(e) {}
            
            // 7. Ensure document is never considered hidden by YouTube background tab throttling
            try {
                Object.defineProperty(document, 'hidden', {
                    get: function() { return false; },
                    configurable: true
                });
                Object.defineProperty(document, 'visibilityState', {
                    get: function() { return 'visible'; },
                    configurable: true
                });
            } catch(e) {}
            
            // 8. Zero-Ad Guarantee: YouTube Music API Player Response Sanitizer & Fast-Forward
            try {
                function sanitizePlayerResponse(obj) {
                    if (!obj || typeof obj !== 'object') return obj;
                    try {
                        if (obj.adPlacements) delete obj.adPlacements;
                        if (obj.adSlots) delete obj.adSlots;
                        if (obj.playerAds) delete obj.playerAds;
                        if (obj.adBreakHeartbeatParams) delete obj.adBreakHeartbeatParams;
                        if (obj.playbackTracking && obj.playbackTracking.videostatsPlaybackUrl) {
                            delete obj.playbackTracking.videostatsPlaybackUrl;
                        }
                    } catch(e) {}
                    return obj;
                }

                // Monkeypatch window.fetch for /youtubei/v1/player
                if (typeof window.fetch === 'function') {
                    var origFetch = window.fetch;
                    window.fetch = function() {
                        var url = arguments[0];
                        var urlStr = (typeof url === 'string') ? url : (url && url.url ? url.url : '');
                        if (urlStr && urlStr.indexOf('/youtubei/v1/player') !== -1) {
                            return origFetch.apply(this, arguments).then(function(res) {
                                try {
                                    return res.clone().json().then(function(json) {
                                        sanitizePlayerResponse(json);
                                        return new Response(JSON.stringify(json), {
                                            status: res.status,
                                            statusText: res.statusText,
                                            headers: res.headers
                                        });
                                    }).catch(function() { return res; });
                                } catch(e) {
                                    return res;
                                }
                            });
                        }
                        return origFetch.apply(this, arguments);
                    };
                }

                // Monkeypatch XMLHttpRequest for /youtubei/v1/player
                if (typeof window.XMLHttpRequest === 'function') {
                    var origOpen = XMLHttpRequest.prototype.open;
                    var origSend = XMLHttpRequest.prototype.send;
                    XMLHttpRequest.prototype.open = function(method, url) {
                        this._morphReqUrl = url;
                        return origOpen.apply(this, arguments);
                    };
                    XMLHttpRequest.prototype.send = function() {
                        if (this._morphReqUrl && typeof this._morphReqUrl === 'string' && this._morphReqUrl.indexOf('/youtubei/v1/player') !== -1) {
                            var self = this;
                            var origGetter = Object.getOwnPropertyDescriptor(XMLHttpRequest.prototype, 'responseText');
                            if (origGetter && origGetter.get) {
                                Object.defineProperty(self, 'responseText', {
                                    get: function() {
                                        var raw = origGetter.get.call(self);
                                        try {
                                            var parsed = JSON.parse(raw);
                                            sanitizePlayerResponse(parsed);
                                            return JSON.stringify(parsed);
                                        } catch(e) {
                                            return raw;
                                        }
                                    },
                                    configurable: true
                                });
                            }
                        }
                        return origSend.apply(this, arguments);
                    };
                }

                // Intercept window.ytInitialPlayerResponse
                var _morphInitialResponse = window.ytInitialPlayerResponse;
                try {
                    Object.defineProperty(window, 'ytInitialPlayerResponse', {
                        get: function() { return _morphInitialResponse; },
                        set: function(val) {
                            _morphInitialResponse = sanitizePlayerResponse(val);
                        },
                        configurable: true
                    });
                } catch(e) {}

                // Active 0ms Video Fast-Forward & Audio Mute on HTMLMediaElement.prototype.play
                if (typeof HTMLMediaElement === 'function' && HTMLMediaElement.prototype) {
                    var origPlay = HTMLMediaElement.prototype.play;
                    HTMLMediaElement.prototype.play = function() {
                        try {
                            var moviePlayer = document.getElementById('movie_player') || document.querySelector('#movie_player, .html5-video-player');
                            var isAd = (moviePlayer && (moviePlayer.classList.contains('ad-showing') || moviePlayer.classList.contains('ad-interrupting'))) ||
                                       (this.src && (this.src.indexOf('&adformat=') !== -1 || this.src.indexOf('adformat=') !== -1 || this.src.indexOf('/pagead/') !== -1));
                            if (!isAd) {
                                var adShowingEl = document.querySelector('.ad-showing, .ad-interrupting');
                                if (adShowingEl && (adShowingEl.offsetParent !== null || adShowingEl.offsetWidth > 0)) {
                                    isAd = true;
                                }
                            }
                            if (isAd) {
                                this.muted = true;
                                this.playbackRate = 16.0;
                                if (isFinite(this.duration) && this.duration > 0) {
                                    this.currentTime = this.duration;
                                } else {
                                    this.currentTime = 99999;
                                }
                                var skip = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, button.ytp-ad-skip-button, .ytp-skip-ad-button, .ytp-ad-skip-button-slot button');
                                if (skip) {
                                    try { skip.click(); } catch(se) {}
                                }
                            }
                        } catch(e) {}
                        return origPlay.apply(this, arguments);
                    };
                }
            } catch(e) {}
        })();
        """
    }
    
    // MARK: - Injected Player Observer JavaScript Code (.atDocumentEnd)
    var injectedPlayerObserverJavaScript: String {
        return """
        (function() {
            var _morphCachedPlaylists = [];
            var _morphCachedQuickPicks = [];
            var _morphLastHeavyScanTime = 0;
            var _morphLastPathname = '';
            var _morphLastValidTrackTitle = '';
            var _morphLastValidTrackArtist = '';
            var _morphLastValidTrackArt = null;
            var _morphWasAdPlaying = false;
            var _morphAdSuppressedCount = 0;
            var _morphLastKnownAccountTier = 'unknown';

            function getTrackInfo(force) {
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
                
                var videoId = '';
                try {
                    if (playerEl && typeof playerEl.getVideoData === 'function') {
                        var vd = playerEl.getVideoData();
                        if (vd && vd.video_id) videoId = vd.video_id;
                    }
                    if (!videoId) {
                        var mHref = window.location.href.match(/[?&]v=([a-zA-Z0-9_-]{11})/);
                        if (mHref) videoId = mHref[1];
                    }
                    if (!videoId) {
                        var qPlaying = document.querySelector('ytmusic-player-queue-item[selected], ytmusic-player-queue-item[play-state="playing"]');
                        if (qPlaying && qPlaying.data && qPlaying.data.playlistItemData) {
                            videoId = qPlaying.data.playlistItemData.videoId || '';
                        }
                    }
                } catch(ve) {}
                
                // Zero-Ad Guarantee: Detect if an advertisement is playing or interrupting
                var isAdPlaying = false;
                try {
                    var moviePlayer = playerEl || document.getElementById('movie_player') || document.querySelector('#movie_player, .html5-video-player');
                    if (moviePlayer) {
                        if (moviePlayer.classList.contains('ad-showing') || moviePlayer.classList.contains('ad-interrupting')) {
                            isAdPlaying = true;
                        }
                    }
                    if (!isAdPlaying && videoEl && videoEl.src) {
                        if (videoEl.src.indexOf('adformat=') !== -1 || videoEl.src.indexOf('&oad=') !== -1 || videoEl.src.indexOf('/pagead/') !== -1) {
                            isAdPlaying = true;
                        }
                    }
                    if (!isAdPlaying) {
                        var adOverlay = document.querySelector('ytmusic-player[ad-showing], .ad-showing, .ad-interrupting');
                        if (adOverlay && (adOverlay.offsetParent !== null || adOverlay.offsetWidth > 0)) {
                            isAdPlaying = true;
                        }
                    }
                    if (!isAdPlaying) {
                        var adText = document.querySelector('.ytp-ad-preview-text, .ytp-ad-text, .ytp-ad-text-overlay');
                        if (adText && (adText.offsetParent !== null || adText.offsetWidth > 0)) {
                            isAdPlaying = true;
                        }
                    }
                    if (!isAdPlaying && (title.indexOf('Advertisement') !== -1 || title === 'Ad')) {
                        isAdPlaying = true;
                    }
                } catch(e) {}
                
                if (isAdPlaying) {
                    // 1. Audio Mute: Ensure the user NEVER has to listen to ads!
                    if (videoEl && !videoEl.muted) {
                        videoEl.muted = true;
                    }
                    
                    // 2. Click skip button immediately if available
                    var skipBtn = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, button.ytp-ad-skip-button, .ytp-skip-ad-button, .ytp-ad-skip-button-container button, .ytp-ad-skip-button-slot button');
                    if (skipBtn) {
                        try { skipBtn.click(); } catch(se) {}
                    }
                    
                    // 3. Fast-forward video to finish the ad instantly
                    if (videoEl) {
                        try {
                            if (isFinite(videoEl.duration) && videoEl.duration > 0) {
                                videoEl.currentTime = videoEl.duration;
                            } else {
                                videoEl.currentTime = 99999;
                            }
                            videoEl.playbackRate = 16.0;
                        } catch(fe) {}
                    }
                    
                    // 4. Auto-dismiss upsell/promo modals
                    var upsellDismiss = document.querySelectorAll(
                        'ytmusic-mealbar-promo-renderer #dismiss-button, ' +
                        'ytmusic-upsell-dialog-renderer #dismiss-button, ' +
                        'yt-mealbar-promo-renderer #dismiss-button, ' +
                        '.ytp-ad-overlay-close-button, ' +
                        'tp-yt-paper-dialog #dismiss-button'
                    );
                    for (var d = 0; d < upsellDismiss.length; d++) {
                        var ub = upsellDismiss[d];
                        if (ub && (ub.offsetParent !== null || ub.offsetWidth > 0)) {
                            var innerB = ub.querySelector('button, #button') || ub;
                            try { innerB.click(); } catch(de) {}
                        }
                    }
                    
                    // 5. Track metadata protection: keep the real song info
                    if (_morphLastValidTrackTitle) {
                        title = _morphLastValidTrackTitle;
                    }
                    if (_morphLastValidTrackArtist) {
                        artist = _morphLastValidTrackArtist;
                    }
                    if (_morphLastValidTrackArt) {
                        art = _morphLastValidTrackArt;
                    }
                } else {
                    if (window._morphWasAdPlaying) {
                        if (videoEl) {
                            videoEl.muted = (isMuted === true);
                            videoEl.playbackRate = 1.0;
                        }
                        _morphAdSuppressedCount++;
                    }
                    if (title && title !== 'YouTube Music' && !/advertisement/i.test(title)) {
                        _morphLastValidTrackTitle = title;
                        _morphLastValidTrackArtist = artist;
                        _morphLastValidTrackArt = art;
                    }
                }
                window._morphWasAdPlaying = isAdPlaying;
                
                var isPlaying = false;
                if (window._morphUserPaused) {
                    isPlaying = false;
                } else if (playerEl && typeof playerEl.getPlayerState === 'function' && playerEl.getPlayerState() === 1) {
                    isPlaying = true;
                } else if (videoEl && !videoEl.paused && !videoEl.ended) {
                    isPlaying = true;
                } else if (navigator.mediaSession && navigator.mediaSession.playbackState) {
                    isPlaying = (navigator.mediaSession.playbackState === 'playing');
                }
                
                if (title && title !== 'YouTube Music') {
                    if (_morphLastKnownTitle && title !== _morphLastKnownTitle) {
                        if (_morphWasPlayingBeforeTransition || _morphTransitionPending) {
                            startTransitionWatchdog();
                            ensureActivePlayback();
                        }
                    }
                    _morphLastKnownTitle = title;
                }
                if (isPlaying && (videoEl ? videoEl.currentTime > 0 : true)) {
                    _morphWasPlayingBeforeTransition = true;
                    _morphTransitionPending = false;
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
                    var innerShuffle = shuffleBtn.querySelector('button, #button') || (shuffleBtn.shadowRoot && shuffleBtn.shadowRoot.querySelector('button, #button')) || shuffleBtn;
                    var sTitle = (shuffleBtn.getAttribute('title') || shuffleBtn.getAttribute('aria-label') || innerShuffle.getAttribute('aria-label') || '').toLowerCase();
                    isShuffle = (shuffleBtn.getAttribute('aria-pressed') === 'true' || 
                                 innerShuffle.getAttribute('aria-pressed') === 'true' ||
                                 shuffleBtn.classList.contains('active') ||
                                 sTitle.indexOf('on') !== -1 || sTitle.indexOf('bật') !== -1);
                }
                if (typeof window._morphTargetShuffle === 'boolean') {
                    isShuffle = window._morphTargetShuffle;
                } else {
                    window._morphTargetShuffle = isShuffle;
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
                    var innerRepeat = repeatBtn.querySelector('button, #button') || (repeatBtn.shadowRoot && repeatBtn.shadowRoot.querySelector('button, #button')) || repeatBtn;
                    var rText = ((repeatBtn.getAttribute('aria-label') || '') + ' ' + 
                                 (repeatBtn.getAttribute('title') || '') + ' ' + 
                                 (innerRepeat.getAttribute('aria-label') || '') + ' ' + 
                                 (innerRepeat.getAttribute('title') || '') + ' ' + 
                                 (repeatBtn.innerText || '')).toLowerCase();
                    var rPressed = repeatBtn.getAttribute('aria-pressed') === 'true' || 
                                   innerRepeat.getAttribute('aria-pressed') === 'true' ||
                                   repeatBtn.classList.contains('active');
                    if (rText.indexOf('one') !== -1 || rText.indexOf('1') !== -1 || rText.indexOf('một') !== -1) {
                        repeatMode = 'one';
                    } else if (rText.indexOf('all') !== -1 || rText.indexOf('tất cả') !== -1 || (rPressed && rText.indexOf('off') === -1)) {
                        repeatMode = 'all';
                    } else {
                        repeatMode = 'off';
                    }
                }
                if (window._morphTargetRepeatMode && Date.now() < (window._morphRepeatLockoutUntil || 0)) {
                    repeatMode = window._morphTargetRepeatMode;
                } else {
                    window._morphTargetRepeatMode = repeatMode;
                }
                
                // Playlist Queue extraction
                var queue = [];
                var seenQ = {};
                var seenSelected = false;
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
                            if (qTitle) {
                                var normKey = qTitle.toLowerCase().replace(/\\(.*\\)|\\[.*\\]/g, '').trim();
                                if (!seenQ[normKey]) {
                                    seenQ[normKey] = true;
                                    queue.push({
                                        id: '' + i,
                                        title: qTitle,
                                        artist: qArtist,
                                        duration: qDur,
                                        isPlaying: false
                                    });
                                }
                            }
                        }
                    }
                } catch(qe) {}
                
                // User Playlists extraction (Sidebar Guide + Page Shelves)
                var nowScan = Date.now();
                var pathChanged = (window.location.pathname !== _morphLastPathname);
                var shouldScanShelves = force || pathChanged || (nowScan - _morphLastHeavyScanTime > 30000) || (_morphCachedPlaylists.length === 0);
                
                var playlists = _morphCachedPlaylists;
                var quickPicks = _morphCachedQuickPicks;
                
                if (shouldScanShelves) {
                    _morphLastHeavyScanTime = nowScan;
                    _morphLastPathname = window.location.pathname;
                    var newPlaylists = [];
                    var newQuickPicks = [];
                    var seenPlaylists = {};
                    try {
                        // 1. Sidebar Guide Entries (strictly user playlists, never watch/video links)
                        var guideEntries = document.querySelectorAll('ytmusic-guide-entry-renderer, tp-yt-paper-item');
                        for (var g = 0; g < guideEntries.length; g++) {
                            var gel = guideEntries[g];
                            var gLink = gel.querySelector('a[href*="playlist?list="], a[href*="browse/VL"]') || gel.querySelector('a') || gel;
                            var gHref = gLink.getAttribute('href') || '';
                            if (gHref.indexOf('watch?v=') !== -1) continue;
                            var gTitleEl = gel.querySelector('yt-formatted-string.title') || gel.querySelector('.title') || gel.querySelector('tp-yt-paper-item') || gel;
                            var gTitle = gTitleEl ? (gTitleEl.innerText || gTitleEl.textContent || '').trim() : '';
                            
                            if (gHref.indexOf('playlist?list=') !== -1 || gHref.indexOf('browse/VL') !== -1) {
                                var gId = '';
                                var gMatch = gHref.match(/[?&]list=([^&]+)/);
                                if (gMatch) gId = gMatch[1];
                                else if (gHref.indexOf('browse/VL') !== -1) gId = gHref.split('browse/VL')[1].split('/')[0];
                                
                                // Eliminate radios, albums, and single songs
                                if (gId.indexOf('RD') === 0 || gId.indexOf('MPRE') === 0 || gId.indexOf('OLAK') === 0) continue;
                                if (gId.indexOf('PL') !== 0 && gId !== 'LM' && gId !== 'LL' && gId !== 'WL' && gId.indexOf('VLPL') !== 0 && gId !== 'VLLM') continue;
                                
                                var gImg = gel.querySelector('img');
                                var gThumb = gImg ? gImg.src : null;
                                
                                if (gTitle && gId && !seenPlaylists[gId]) {
                                    seenPlaylists[gId] = true;
                                    var bId = gId.indexOf('VL') === 0 ? gId : ('VL' + gId);
                                    newPlaylists.push({
                                        id: gId,
                                        title: gTitle,
                                        subtitle: 'Playlist',
                                        thumbnailURL: gThumb,
                                        browseId: bId
                                    });
                                }
                            }
                        }
                        
                        // 2. Playlists on page grids / shelves (strictly user playlists, never songs/radios)
                        var gridItems = document.querySelectorAll('ytmusic-two-row-item-renderer');
                        for (var gi = 0; gi < gridItems.length; gi++) {
                            var gEl = gridItems[gi];
                            var aEl = gEl.querySelector('a[href*="playlist?list="], a[href*="browse/VLPL"], a[href*="browse/VLLM"]');
                            if (!aEl) continue;
                            var aHref = aEl.getAttribute('href') || '';
                            if (aHref.indexOf('watch?v=') !== -1) continue;
                            var tEl = gEl.querySelector('.title a') || gEl.querySelector('.title') || gEl.querySelector('yt-formatted-string.title');
                            var tText = tEl ? (tEl.innerText || tEl.textContent || '').trim() : '';
                            var imgEl = gEl.querySelector('img');
                            var imgThumb = imgEl ? imgEl.src : null;
                            
                            var plId = '';
                            var plMatch = aHref.match(/[?&]list=([^&]+)/);
                            if (plMatch) plId = plMatch[1];
                            else if (aHref.indexOf('browse/VL') !== -1) plId = aHref.split('browse/VL')[1].split('/')[0];
                            
                            if (plId.indexOf('RD') === 0 || plId.indexOf('MPRE') === 0 || plId.indexOf('OLAK') === 0) continue;
                            if (plId.indexOf('PL') !== 0 && plId !== 'LM' && plId !== 'LL' && plId !== 'WL' && plId.indexOf('VLPL') !== 0 && plId !== 'VLLM') continue;
                            
                            if (plId && tText && !seenPlaylists[plId]) {
                                seenPlaylists[plId] = true;
                                var bId = plId.indexOf('VL') === 0 ? plId : ('VL' + plId);
                                newPlaylists.push({
                                    id: plId,
                                    title: tText,
                                    subtitle: 'Playlist',
                                    thumbnailURL: imgThumb,
                                    browseId: bId
                                });
                            }
                        }

                        // 3. Quick Picks extraction from Home feed
                        try {
                            var shelves = document.querySelectorAll('ytmusic-carousel-shelf-renderer, ytmusic-shelf-renderer');
                            var targetShelf = null;
                            // Pass 1: Prioritize explicit Quick Picks / Lựa chọn nhanh shelf
                            for (var s = 0; s < shelves.length; s++) {
                                var sh = shelves[s];
                                var headerEl = sh.querySelector('ytmusic-carousel-shelf-basic-header-renderer, ytmusic-shelf-basic-header-renderer, .header, #header') || sh;
                                var shHeaderText = (headerEl ? (headerEl.innerText || headerEl.textContent || '') : '').toLowerCase();
                                if (shHeaderText.indexOf('quick pick') !== -1 || shHeaderText.indexOf('lựa chọn nhanh') !== -1) {
                                    targetShelf = sh;
                                    break;
                                }
                            }
                            // Pass 2: If no explicit Quick Picks shelf, fallback only on home page root ('/')
                            if (!targetShelf && window.location.pathname === '/' && shelves.length > 0) {
                                for (var s2 = 0; s2 < shelves.length; s2++) {
                                    var sh2 = shelves[s2];
                                    var headerEl2 = sh2.querySelector('ytmusic-carousel-shelf-basic-header-renderer, ytmusic-shelf-basic-header-renderer, .header, #header') || sh2;
                                    var shHeaderText2 = (headerEl2 ? (headerEl2.innerText || headerEl2.textContent || '') : '').toLowerCase();
                                    if (shHeaderText2.indexOf('listen again') !== -1 || shHeaderText2.indexOf('start radio') !== -1 || s2 === 0) {
                                        targetShelf = sh2;
                                        break;
                                    }
                                }
                            }
                            if (targetShelf) {
                                var items = targetShelf.querySelectorAll('ytmusic-responsive-list-item-renderer, ytmusic-two-row-item-renderer');
                                for (var itIdx = 0; itIdx < Math.min(items.length, 25); itIdx++) {
                                    var itEl = items[itIdx];
                                    var tEl = itEl.querySelector('.title a') || itEl.querySelector('.title') || itEl.querySelector('yt-formatted-string.title');
                                    var aEl = itEl.querySelector('.subtitle a') || itEl.querySelector('.byline a') || itEl.querySelector('.subtitle') || itEl.querySelector('.byline');
                                    var dEl = itEl.querySelector('.fixed-column') || itEl.querySelector('.duration');
                                    var itTitle = tEl ? (tEl.innerText || tEl.textContent || '').trim() : '';
                                    var itArtist = aEl ? (aEl.innerText || aEl.textContent || '').trim() : '';
                                    var itDur = dEl ? (dEl.innerText || dEl.textContent || '').trim() : '';
                                    var linkEl = itEl.querySelector('a[href*="watch?v="]') || itEl.querySelector('a[href*="/watch"]') || itEl.querySelector('a[href*="v="]');
                                    var vId = '';
                                    if (linkEl) {
                                        var href = linkEl.getAttribute('href') || '';
                                        var vMatch = href.match(/[?&]v=([^&]+)/);
                                        if (vMatch) vId = vMatch[1];
                                    }
                                    if (!vId && itEl.data && itEl.data.playlistItemData && itEl.data.playlistItemData.videoId) {
                                        vId = itEl.data.playlistItemData.videoId;
                                    }
                                    var imgEl = itEl.querySelector('img');
                                    var thumb = imgEl ? imgEl.src : null;
                                    if (itTitle) {
                                        newQuickPicks.push({
                                            id: vId ? vId : ('qp_' + itIdx),
                                            title: itTitle,
                                            artist: itArtist,
                                            duration: itDur,
                                            videoId: vId ? vId : null,
                                            thumbnailURL: thumb
                                        });
                                    }
                                }
                            }
                        } catch(qpe) {}

                        // 4. Ensure Liked Music if link is present
                        if (!seenPlaylists['LM']) {
                            var lEl = document.querySelector('a[href*="list=LM"]');
                            if (lEl) {
                                seenPlaylists['LM'] = true;
                                newPlaylists.unshift({
                                    id: 'LM',
                                    title: 'Liked Music',
                                    subtitle: 'Auto Playlist',
                                    thumbnailURL: null,
                                    browseId: 'playlist?list=LM'
                                });
                            }
                        }
                    } catch(pe) {}
                    if (newPlaylists.length > 0) _morphCachedPlaylists = newPlaylists;
                    if (newQuickPicks.length > 0) _morphCachedQuickPicks = newQuickPicks;
                    playlists = _morphCachedPlaylists;
                    quickPicks = _morphCachedQuickPicks;
                }
                    
                    // 5. User Signed-In State & Email Detection
                    var isSignedIn = false;
                    var userEmail = '';
                    var userAvatarURL = '';
                    var userDisplayName = '';
                    try {
                        if (window.ytcfg && typeof window.ytcfg.get === 'function') {
                            var yLoggedIn = window.ytcfg.get('LOGGED_IN');
                            if (typeof yLoggedIn === 'boolean') {
                                isSignedIn = yLoggedIn;
                            }
                            var email = window.ytcfg.get('USER_EMAIL');
                            if (email && typeof email === 'string' && email.indexOf('@') !== -1) {
                                userEmail = email.trim();
                            }
                            var uName = window.ytcfg.get('USER_NAME');
                            if (uName && typeof uName === 'string') {
                                userDisplayName = uName.trim();
                            }
                            var ctx = window.ytcfg.get('INNERTUBE_CONTEXT');
                            if (!userEmail && ctx && ctx.user && ctx.user.email) {
                                userEmail = ctx.user.email.trim();
                            }
                        }
                        if (!userEmail) {
                            var urlMatch = window.location.href.match(/[?&]authuser=([^&]+)/);
                            if (urlMatch) {
                                var decodedAuth = decodeURIComponent(urlMatch[1]).trim();
                                if (decodedAuth.indexOf('@') !== -1) {
                                    userEmail = decodedAuth;
                                }
                            }
                        }
                        if (!isSignedIn) {
                            var hasAvatar = document.querySelector('button#avatar-btn, img#avatar-btn, ytmusic-settings-button, tp-yt-paper-icon-button#avatar-btn, ytmusic-sign-in-button[hidden]');
                            var signInBtn = document.querySelector('ytmusic-sign-in-button:not([hidden]), a[href*="accounts.google.com/ServiceLogin"]:not([hidden])');
                            var hasAuthCookie = /(?:^|;\\s*)(?:SAPISID|__Secure-3PAPISID|__Secure-1PAPISID)=([^;]+)/.test(document.cookie || '');
                            if ((hasAvatar || hasAuthCookie) && !signInBtn) {
                                isSignedIn = true;
                            }
                        }
                        var avatarImg = document.querySelector('button#avatar-btn img, #avatar-btn img, img#avatar-btn, yt-img-shadow#avatar img, ytmusic-settings-button img, yt-icon-button#avatar-btn img');
                        if (avatarImg && avatarImg.src && avatarImg.src.indexOf('http') === 0) {
                            userAvatarURL = avatarImg.src;
                        }
                        var avatarBtn = document.querySelector('button#avatar-btn, img#avatar-btn, tp-yt-paper-icon-button#avatar-btn, ytmusic-settings-button, yt-icon-button#avatar-btn, button[aria-label*="@"]');
                        if (avatarBtn) {
                            var aria = avatarBtn.getAttribute('aria-label') || avatarBtn.getAttribute('alt') || avatarBtn.getAttribute('title') || '';
                            if (!userEmail) {
                                var emailMatch = aria.match(/([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,})/);
                                if (emailMatch) {
                                    userEmail = emailMatch[1];
                                }
                            }
                            if (!userDisplayName) {
                                var nameMatch = aria.match(/(?:Account:\\s*|Profile:\\s*)([^(\\n]+)/i);
                                if (nameMatch) {
                                    userDisplayName = nameMatch[1].trim();
                                }
                            }
                        }
                        if (!userEmail) {
                            var accountEmailEl = document.querySelector('ytd-active-account-header-renderer #email, ytmusic-active-account-header-renderer #email, #account-name + #email, #email.ytd-active-account-header-renderer');
                            if (accountEmailEl) {
                                var em = (accountEmailEl.innerText || accountEmailEl.textContent || '').trim();
                                if (em.indexOf('@') !== -1) userEmail = em;
                            }
                        }
                    } catch(ie) {}
                    
                    // 6. Account Tier (Pro/Premium vs Basic/Free) Detection
                    var accountTier = 'unknown';
                    try {
                        if (window.ytcfg && typeof window.ytcfg.get === 'function') {
                            var ctx = window.ytcfg.get('INNERTUBE_CONTEXT');
                            if (ctx && ctx.user) {
                                if (ctx.user.isSubscriptionUser === true || ctx.user.hasActiveSubscription === true) {
                                    accountTier = 'premium';
                                }
                            }
                            if (accountTier === 'unknown') {
                                if (window.ytcfg.get('USER_IS_PREMIUM') === true || window.ytcfg.get('IS_PREMIUM') === true) {
                                    accountTier = 'premium';
                                }
                            }
                        }
                        
                        if (accountTier === 'unknown') {
                            var logoEl = document.querySelector('ytmusic-logo, ytmusic-nav-bar ytmusic-logo, #logo, #logo-icon, a.ytmusic-logo');
                            if (logoEl) {
                                var aria = (logoEl.getAttribute('aria-label') || logoEl.getAttribute('title') || logoEl.innerText || logoEl.textContent || '');
                                if (/premium/i.test(aria)) {
                                    accountTier = 'premium';
                                }
                            }
                            if (accountTier === 'unknown') {
                                var premSelector = document.querySelector('ytmusic-logo [aria-label*="Premium" i], a[title*="Premium" i], [aria-label*="YouTube Music Premium" i]');
                                if (premSelector) {
                                    accountTier = 'premium';
                                }
                            }
                        }
                        
                        if (accountTier === 'unknown') {
                            var upgradeLink = document.querySelector(
                                'ytmusic-pivot-bar-item-renderer[tab-id="FEmusic_upgrade"], ' +
                                'ytmusic-pivot-bar-renderer a[href*="/upgrade"], ' +
                                'ytmusic-pivot-bar-renderer a[href*="/musicpremium"], ' +
                                'a[href*="/musicpremium"], ' +
                                'ytmusic-guide-entry-renderer a[href*="/musicpremium"], ' +
                                'ytmusic-guide-entry-renderer a[href*="/upgrade"], ' +
                                'a[aria-label*="Upgrade" i], ' +
                                'a[aria-label*="Get Music Premium" i]'
                            );
                            if (upgradeLink) {
                                accountTier = 'basic';
                            }
                        }
                        
                        if (accountTier === 'unknown') {
                            var paidMem = document.querySelector('a[href*="/paid_memberships"], ytmusic-guide-entry-renderer a[href*="/paid_memberships"]');
                            if (paidMem) {
                                accountTier = 'premium';
                            }
                        }
                        
                        if (accountTier === 'unknown' && isSignedIn) {
                            var logoEl2 = document.querySelector('ytmusic-logo, ytmusic-nav-bar ytmusic-logo');
                            if (logoEl2) {
                                accountTier = 'basic';
                            }
                        }
                        if (accountTier !== 'unknown') {
                            _morphLastKnownAccountTier = accountTier;
                        } else if (_morphLastKnownAccountTier !== 'unknown') {
                            accountTier = _morphLastKnownAccountTier;
                        }
                    } catch(te) {}
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
                    quickPicks: quickPicks,
                    isSignedIn: isSignedIn,
                    userEmail: userEmail,
                    userAvatarURL: userAvatarURL,
                    userDisplayName: userDisplayName,
                    accountTier: accountTier,
                    isAdPlaying: isAdPlaying,
                    adSuppressedCount: _morphAdSuppressedCount,
                    videoId: videoId
                };
            }
            
            var _morphLastSendTime = 0;
            var _morphSendPendingTimeout = null;
            var _morphSentPausedState = false;
            
            window.morphSendUpdate = function(force, isEnded) {
                try {
                    var now = Date.now();
                    if (!force && (now - _morphLastSendTime) < 350) {
                        if (!_morphSendPendingTimeout) {
                            _morphSendPendingTimeout = setTimeout(function() {
                                _morphSendPendingTimeout = null;
                                window.morphSendUpdate(false);
                            }, 350 - (now - _morphLastSendTime));
                        }
                        return;
                    }
                    if (_morphSendPendingTimeout) {
                        clearTimeout(_morphSendPendingTimeout);
                        _morphSendPendingTimeout = null;
                    }
                    _morphLastSendTime = now;
                    var data = getTrackInfo(force);
                    if (isEnded) {
                        data.isEnded = true;
                    }
                    if (data.isPlaying) {
                        _morphSentPausedState = false;
                        window.webkit.messageHandlers.\(kHandlerName).postMessage(data);
                    } else if (force || isEnded || !_morphSentPausedState) {
                        _morphSentPausedState = true;
                        window.webkit.messageHandlers.\(kHandlerName).postMessage(data);
                    }
                } catch(e) {}
            };
            
            function dismissModalsAndEnableAutoplay() {
                try {
                    // 1. Dismiss "Still watching?" / "Video paused. Continue watching?" popups
                    var confirmButtons = document.querySelectorAll(
                        'ytmusic-you-there-renderer #confirm-button, ' +
                        'tp-yt-paper-dialog #confirm-button, ' +
                        'yt-confirm-dialog-renderer #confirm-button, ' +
                        '.ytmusic-you-there-renderer button, ' +
                        'ytmusic-dialog-renderer button'
                    );
                    var dismissed = false;
                    for (var i = 0; i < confirmButtons.length; i++) {
                        var cb = confirmButtons[i];
                        if (cb && (cb.offsetParent !== null || cb.offsetWidth > 0)) {
                            var inner = cb.querySelector('button, #button, yt-button-shape');
                            (inner || cb).click();
                            dismissed = true;
                        }
                    }
                    if (dismissed && !window._morphUserPaused) {
                        ensureActivePlayback();
                    }

                    // 2. Ensure YouTube Music Autoplay / Automix toggle is enabled
                    var automixToggle = document.querySelector('#automix-toggle tp-yt-paper-toggle-button') ||
                                        document.querySelector('ytmusic-player-queue tp-yt-paper-toggle-button') ||
                                        document.querySelector('.automix-toggle tp-yt-paper-toggle-button');
                    if (automixToggle) {
                        var isChecked = automixToggle.hasAttribute('checked') || automixToggle.getAttribute('aria-checked') === 'true';
                        if (!isChecked) {
                            automixToggle.click();
                        }
                    }
                } catch(e) {}
            }

            var _morphLastKnownTitle = '';
            var _morphWasPlayingBeforeTransition = false;
            var _morphTransitionPending = false;
            var _morphTransitionTimer = null;

            function ensureActivePlayback() {
                if (window._morphUserPaused) return;
                try {
                    if (typeof window._morphResumeAudioContexts === 'function') {
                        window._morphResumeAudioContexts();
                    }
                    dismissModalsAndEnableAutoplay();
                    var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
                    var v = document.querySelector('video');
                    if (p && typeof p.getPlayerState === 'function') {
                        var state = p.getPlayerState();
                        // State -1: unstarted, 2: paused, 5: cued
                        if ((state === -1 || state === 2 || state === 5) && typeof p.playVideo === 'function') {
                            try { p.playVideo(); } catch(eP) {}
                        }
                    }
                    if (v && v.paused && !v.ended) {
                        var wasMuted = v.muted;
                        var promise = v.play();
                        if (promise !== undefined) {
                            promise.catch(function() {
                                v.muted = true;
                                v.play().then(function() {
                                    setTimeout(function() { v.muted = wasMuted; }, 150);
                                }).catch(function(){});
                            });
                        }
                    }
                } catch(e) {}
            }

            function startTransitionWatchdog() {
                if (window._morphUserPaused) return;
                _morphTransitionPending = true;
                if (_morphTransitionTimer) clearTimeout(_morphTransitionTimer);
                [100, 300, 700, 1300, 2000].forEach(function(d) {
                    setTimeout(function() {
                        if (_morphTransitionPending && !window._morphUserPaused) {
                            ensureActivePlayback();
                            var v = document.querySelector('video');
                            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
                            var isNowPlaying = (v && !v.paused && !v.ended && v.currentTime > 0) || (p && typeof p.getPlayerState === 'function' && p.getPlayerState() === 1);
                            if (isNowPlaying) {
                                _morphTransitionPending = false;
                                _morphWasPlayingBeforeTransition = true;
                            }
                        }
                    }, d);
                });
            }

            function triggerNextVideo() {
                try {
                    dismissModalsAndEnableAutoplay();

                    var v = document.querySelector('video');
                    // Repeat One: replay current video seamlessly
                    if (window._morphTargetRepeatMode === 'one' || (v && v.loop)) {
                        if (v) {
                            v.currentTime = 0;
                            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
                            if (p && typeof p.seekTo === 'function') {
                                p.seekTo(0, true);
                            }
                            if (p && typeof p.playVideo === 'function') {
                                p.playVideo();
                            }
                            var wasMuted = v.muted;
                            var promise = v.play();
                            if (promise !== undefined) {
                                promise.catch(function() {
                                    v.muted = true;
                                    v.play().then(function() {
                                        setTimeout(function() { v.muted = wasMuted; }, 100);
                                    }).catch(function(){});
                                });
                            }
                        }
                        return;
                    }

                    var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
                    var advanced = false;

                    // Fallback / Continuous Queue Check
                    var queueItems = document.querySelectorAll('ytmusic-player-queue-item');
                    var isAtQueueEnd = false;
                    var currentQueueIdx = -1;
                    if (queueItems && queueItems.length > 0) {
                        for (var qi = 0; qi < queueItems.length; qi++) {
                            var qIt = queueItems[qi];
                            if (qIt.hasAttribute('selected') || qIt.classList.contains('selected') || qIt.getAttribute('play-state') === 'playing') {
                                currentQueueIdx = qi;
                                break;
                            }
                        }
                        if (currentQueueIdx === queueItems.length - 1) {
                            isAtQueueEnd = true;
                        }
                    }

                    // If repeatMode is 'all' and we are at the queue end, loop back infinitely to item 0!
                    if (isAtQueueEnd && window._morphTargetRepeatMode === 'all' && queueItems && queueItems.length > 0) {
                        var firstItem = queueItems[0];
                        var playTarget = firstItem.querySelector('#play-button, .play-button, ytmusic-play-button-renderer') || firstItem;
                        var innerTarget = playTarget.querySelector('button, #button');
                        (innerTarget || playTarget).click();
                        firstItem.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
                        advanced = true;
                    }

                    if (!advanced && p && typeof p.nextVideo === 'function') {
                        try {
                            p.nextVideo();
                            advanced = true;
                        } catch(pe) {}
                    }
                    
                    var btn = document.querySelector('ytmusic-player-bar .next-button') || 
                              document.querySelector('#right-controls .next-button') || 
                              document.querySelector('.next-button') ||
                              document.querySelector('ytmusic-player-bar [aria-label*="Next" i]') ||
                              document.querySelector('ytmusic-player-bar [aria-label*="tiếp" i]');
                    if (!advanced && btn && (!btn.disabled && !btn.hasAttribute('disabled'))) {
                        var inner = btn.querySelector('button, #button');
                        (inner || btn).click();
                        btn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
                        advanced = true;
                    }

                    // Fallback: If player has no next video in queue, play next item in DOM queue
                    if (!advanced && queueItems && queueItems.length > 1) {
                        if (window._morphTargetShuffle || (isShuffle && isShuffle !== 'false')) {
                            var candIdx = Math.floor(Math.random() * queueItems.length);
                            if (candIdx === currentQueueIdx && queueItems.length > 1) {
                                candIdx = (candIdx + 1) % queueItems.length;
                            }
                            var randItem = queueItems[candIdx];
                            if (randItem) {
                                var playTargetRand = randItem.querySelector('#play-button, .play-button, ytmusic-play-button-renderer') || randItem;
                                var innerTargetRand = playTargetRand.querySelector('button, #button');
                                (innerTargetRand || playTargetRand).click();
                                randItem.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
                                advanced = true;
                            }
                        } else if (currentQueueIdx !== -1 && currentQueueIdx < queueItems.length - 1) {
                            var nextItem = queueItems[currentQueueIdx + 1];
                            if (nextItem) {
                                var playTargetNext = nextItem.querySelector('#play-button, .play-button, ytmusic-play-button-renderer') || nextItem;
                                var innerTargetNext = playTargetNext.querySelector('button, #button');
                                (innerTargetNext || playTargetNext).click();
                                nextItem.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
                                advanced = true;
                            }
                        } else if (window._morphTargetRepeatMode === 'all' && queueItems.length > 0) {
                            var firstItem2 = queueItems[0];
                            var playTarget2 = firstItem2.querySelector('#play-button, .play-button, ytmusic-play-button-renderer') || firstItem2;
                            var innerTarget2 = playTarget2.querySelector('button, #button');
                            (innerTarget2 || playTarget2).click();
                            firstItem2.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
                            advanced = true;
                        }
                    }

                    // Never click random shelf items or recommendations (prevents jumping to random songs!)
                    ensureActivePlayback();
                } catch(e) {}
            }
            
            function attachVideoListeners() {
                if (navigator.mediaSession && typeof navigator.mediaSession.setActionHandler === 'function' && !navigator.mediaSession._morphIntercepted) {
                    navigator.mediaSession._morphIntercepted = true;
                    var _origSet = navigator.mediaSession.setActionHandler.bind(navigator.mediaSession);
                    navigator.mediaSession.setActionHandler = function(action, handler) {
                        return _origSet(action, function(details) {
                            if (action === 'play' && (window._morphUserPaused || Date.now() < (window._morphPauseLockoutUntil || 0))) {
                                return; // Suppress web-level unpause if Morph user intentionally paused
                            }
                            if ((action === 'pause' || action === 'stop') && !window._morphUserPaused && Date.now() < (window._morphResumeLockoutUntil || 0)) {
                                return; // Suppress OS/WebKit.GPU TogglePlayPause bounce right after Morph resumed playback
                            }
                            if (typeof handler === 'function') {
                                handler(details);
                            }
                        });
                    };
                }
                var v = document.querySelector('video');
                if (v && !v._morphListeners) {
                    v._morphListeners = true;
                    ['loadstart', 'play', 'pause', 'timeupdate', 'ended', 'durationchange', 'volumechange', 'loadedmetadata', 'canplay'].forEach(function(evt) {
                        v.addEventListener(evt, function() {
                            dismissModalsAndEnableAutoplay();
                            
                            // Instant ad fast-forward & mute on any media event
                            try {
                                var pAd = document.getElementById('movie_player') || document.querySelector('#movie_player, .html5-video-player');
                                var isAdNow = (pAd && (pAd.classList.contains('ad-showing') || pAd.classList.contains('ad-interrupting'))) ||
                                              (v.src && (v.src.indexOf('adformat=') !== -1 || v.src.indexOf('/pagead/') !== -1 || v.src.indexOf('&oad=') !== -1));
                                if (!isAdNow) {
                                    var adShowingEl = document.querySelector('.ad-showing, .ad-interrupting');
                                    if (adShowingEl && (adShowingEl.offsetParent !== null || adShowingEl.offsetWidth > 0)) {
                                        isAdNow = true;
                                    }
                                }
                                if (isAdNow) {
                                    v.muted = true;
                                    v.playbackRate = 16.0;
                                    if (isFinite(v.duration) && v.duration > 0) {
                                        v.currentTime = v.duration;
                                    } else {
                                        v.currentTime = 99999;
                                    }
                                    var skip = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern, button.ytp-ad-skip-button, .ytp-skip-ad-button, .ytp-ad-skip-button-slot button');
                                    if (skip) {
                                        try { skip.click(); } catch(se) {}
                                    }
                                } else {
                                    if (v.playbackRate > 1.0) {
                                        v.playbackRate = 1.0;
                                    }
                                }
                            } catch(eAd) {}
                            if (evt === 'play' && (window._morphUserPaused || Date.now() < (window._morphPauseLockoutUntil || 0))) {
                                try {
                                    v.pause();
                                    var pLock = document.getElementById('movie_player') || document.querySelector('#movie_player');
                                    if (pLock && typeof pLock.pauseVideo === 'function') {
                                        pLock.pauseVideo();
                                    }
                                } catch(e) {}
                                window.morphSendUpdate(true);
                                return;
                            }
                            if (evt === 'pause' && !window._morphUserPaused && Date.now() < (window._morphResumeLockoutUntil || 0)) {
                                ensureActivePlayback();
                                return;
                            }
                            if ((evt === 'loadedmetadata' || evt === 'canplay') && _morphTransitionPending && !window._morphUserPaused) {
                                ensureActivePlayback();
                            }
                            window.morphSendUpdate(evt === 'play' || evt === 'pause' || evt === 'ended');
                        });
                    });
                    
                    // Auto-advance or seamless repeat when current track ends
                    v.addEventListener('ended', function(e) {
                        if (window._morphTargetRepeatMode === 'one') {
                            if (e) {
                                e.stopPropagation();
                                e.stopImmediatePropagation();
                            }
                            try {
                                v.currentTime = 0;
                                var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
                                if (p && typeof p.seekTo === 'function') {
                                    p.seekTo(0, true);
                                }
                                if (p && typeof p.playVideo === 'function') {
                                    p.playVideo();
                                }
                                var wasMuted = v.muted;
                                var promise = v.play();
                                if (promise !== undefined) {
                                    promise.catch(function() {
                                        v.muted = true;
                                        v.play().then(function() {
                                            setTimeout(function() { v.muted = wasMuted; }, 100);
                                        }).catch(function(){});
                                    });
                                }
                            } catch(e) {}
                            window.morphSendUpdate(true, false);
                            return;
                        }
                        
                        window.morphSendUpdate(true, true);
                        _morphWasPlayingBeforeTransition = true;
                        startTransitionWatchdog();
                        
                        // If YouTube Music native player has not begun advancing after 2.5s, gently nudge forward
                        setTimeout(function() {
                            var vNow = document.querySelector('video');
                            if (vNow && vNow.ended && !window._morphUserPaused) {
                                triggerNextVideo();
                            }
                        }, 2500);
                    }, true);
                    
                    // Continuous playback: dismiss any "Still watching?" modals and keep autoplay active
                    v.addEventListener('timeupdate', function() {
                        dismissModalsAndEnableAutoplay();
                        if (_morphTransitionPending && !window._morphUserPaused) {
                            ensureActivePlayback();
                        }
                    });
                }
            }
            
            var _morphMutationTimeout = null;
            var observer = new MutationObserver(function() {
                attachVideoListeners();
                if (_morphTransitionPending && !window._morphUserPaused) {
                    ensureActivePlayback();
                }
                if (!_morphMutationTimeout) {
                    _morphMutationTimeout = setTimeout(function() {
                        _morphMutationTimeout = null;
                        window.morphSendUpdate(false);
                    }, 400);
                }
            });
            
            observer.observe(document.body || document.documentElement, {
                childList: true,
                subtree: true
            });
            
            document.addEventListener('DOMContentLoaded', function() {
                attachVideoListeners();
                window.morphSendUpdate(true);
            });
            
            setInterval(function() {
                attachVideoListeners();
                dismissModalsAndEnableAutoplay();
                if (_morphTransitionPending && !window._morphUserPaused) {
                    ensureActivePlayback();
                }
                window.morphSendUpdate(false);
            }, 1000);
        })();
        """
    }
}

// MARK: - Player Window Toolbar (Back, Forward, Reload, Direct Sign-in, Home)
public struct PlayerWindowProfileMenuView: View {
    @ObservedObject var engine: YouTubeMusicEngine
    
    public init(engine: YouTubeMusicEngine) {
        self.engine = engine
    }
    
    public var body: some View {
        Menu {
            Section("Profiles") {
                ForEach(YTMProfileManager.shared.profiles) { p in
                    Button(action: {
                        engine.switchProfile(to: p)
                    }) {
                        HStack {
                            Text(p.displayName.isEmpty ? p.email : "\(p.displayName) (\(p.email))")
                            if p.id == YTMProfileManager.shared.activeProfileId {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            let detected = YTMProfileManager.shared.detectAvailableBrowserProfiles()
            if !detected.isEmpty {
                Section("Import from Chrome") {
                    ForEach(detected, id: \.email) { item in
                        Button(action: {
                            let newP = YTMProfileManager.shared.addProfile(email: item.email, displayName: item.name, isChromeImported: true)
                            engine.switchProfile(to: newP)
                        }) {
                            Label("Import \(item.name) (\(item.email))", systemImage: "arrow.down.circle")
                        }
                    }
                }
            }
            
            Section {
                Button(action: {
                    let newP = YTMProfileManager.shared.addProfile(email: "", displayName: "New Profile")
                    engine.switchProfile(to: newP)
                    engine.loadGoogleSignIn()
                }) {
                    Label("Add New Profile...", systemImage: "person.crop.circle.badge.plus")
                }
                
                if engine.isSignedIn {
                    Button(action: {
                        engine.signOut()
                    }) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                MorphAvatarView(
                    image: engine.activeProfile?.avatarImage,
                    imageURL: engine.activeProfile?.avatarURL,
                    initials: engine.activeProfile?.displayName.isEmpty == false ? engine.activeProfile!.displayName : (engine.userEmail ?? "U"),
                    size: 14
                )
                Text(engine.activeProfile?.displayName.isEmpty == false ? engine.activeProfile!.displayName : (engine.userEmail ?? "Profile"))
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
        }
        .menuStyle(.borderlessButton)
    }
}

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
                .frame(maxWidth: 240)
            
            Spacer()
            
            // Profile Switcher Menu
            PlayerWindowProfileMenuView(engine: engine)
            
            // Direct Google Sign-In Action Button / Signed In Indicator
            if engine.isSignedIn {
                HStack(spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundColor(Color.green)
                        Text(engine.userEmail ?? "Connected • Signed In")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    
                    Button(action: {
                        engine.signOut()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 9.5, weight: .bold))
                            Text("Sign Out")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.75))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Sign out of current YouTube Music account")
                    
                    Button(action: {
                        engine.fetchRealUserPlaylists()
                        engine.fetchQuickPicks()
                        engine.hidePlayerWindow()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 9.5, weight: .bold))
                            Text("Done • Play in Morph")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Sync playlists & return to Morph")
                }
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
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Intercept close button (red traffic light / Cmd+W) to keep background audio pipeline alive
        YouTubeMusicEngine.shared.hidePlayerWindow()
        return false
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
