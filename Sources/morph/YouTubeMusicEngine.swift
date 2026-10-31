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
    @Published public var isOffline: Bool = false
    @Published public var libraryError: String? = nil
    @Published public var isLoadingLibrary: Bool = false
    private var lastLibrarySync: Date?
    
    @Published public var quickPicks: [YTMPlaylistItem] = []
    @Published public var isLoadingQuickPicks: Bool = false
    @Published public var quickPicksError: String? = nil
    private var lastQuickPicksSync: Date?
    
    public var lastEvaluatedScript: String?
    public var onEvaluate: ((String) -> Void)?
    
    public func simulateTrackDataUpdate(_ data: YTMTrackData) {
        self.trackData = data
    }
    
    public private(set) var webView: WKWebView!
    private var playerWindow: NSWindow?
    private var windowDelegate: PlayerWindowDelegate?
    
    private let kHandlerName = "morphYTM"
    private let kYTMURL = "https://music.youtube.com"
    // Modern Desktop Chrome User Agent on macOS to ensure standard browser classification
    private let kCustomUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
    
    public override init() {
        super.init()
        self.quickPicks = YTMParser.defaultQuickPicks
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
        
        // In modern Morph architecture, webView is hosted directly within Morph's active notch panel (attachToHostingView),
        // completely eliminating any ghost/invisible NSWindow on the user's desktop screen.
        if !MorphEnvironment.isTestingEnvironment {
            loadHome()
        }
    }

    
    public func loadHome() {
        guard !MorphEnvironment.isTestingEnvironment else { return }
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
                self.quickPicks = YTMPlaylistItem.deduplicate(parsedPicks)
                self.lastQuickPicksSync = Date()
            }
        }
        
        let previousSignedIn = self.isSignedIn
        if signedIn {
            self.isSignedIn = true
        } else if !self.currentURLString.contains("accounts.google.com") {
            self.isSignedIn = false
        }
        
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
            isSignedIn: self.isSignedIn
        )
        
        // Auto-sync playlists and quick picks immediately when transitioning from not signed in to signed in
        if self.isSignedIn && !previousSignedIn {
            self.lastLibrarySync = nil
            self.lastQuickPicksSync = nil
            self.libraryError = nil
            fetchRealUserPlaylists()
            fetchQuickPicks()
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
        checkAuthCookies()
        
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
    public func play() {
        let script = """
        (function() {
            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
            if (p && typeof p.playVideo === 'function') {
                try { p.playVideo(); } catch(e) {}
            }
            var v = document.querySelector('video');
            if (v && v.paused) {
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
            // Strict player-bar play button targeting to prevent clicking navigation links like "Playlists"
            var btn = document.querySelector('ytmusic-player-bar #play-pause-button') ||
                      document.querySelector('#play-pause-button') ||
                      document.querySelector('ytmusic-player-bar tp-yt-paper-icon-button#play-pause-button') ||
                      document.querySelector('ytmusic-player-bar [aria-label*="Play" i]') ||
                      document.querySelector('ytmusic-player-bar [aria-label*="Phát" i]');
            if (btn) {
                var label = (btn.getAttribute('aria-label') || btn.getAttribute('title') || '').toLowerCase();
                if (label.indexOf('play') !== -1 || label.indexOf('phát') !== -1 || label === '') {
                    btn.click();
                    if (btn.tagName && btn.tagName.toLowerCase().indexOf('-') === -1) {
                        var inner = btn.querySelector('button, #button');
                        if (inner) inner.click();
                    }
                }
            }
            // If neither has started, start the first playable item / supermix on page
            if ((!p || typeof p.playVideo !== 'function') && (!v || !v.src)) {
                var firstPlay = document.querySelector('ytmusic-responsive-list-item-renderer #play-button, ytmusic-two-row-item-renderer #play-button, ytmusic-play-button-renderer #button, #play-button');
                if (firstPlay) {
                    firstPlay.click();
                    if (firstPlay.tagName && firstPlay.tagName.toLowerCase().indexOf('-') === -1) {
                        var firstInner = firstPlay.querySelector('button, #button');
                        if (firstInner) firstInner.click();
                    }
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
                try { p.pauseVideo(); } catch(e) {}
            }
            var videos = document.querySelectorAll('video, audio');
            for (var i = 0; i < videos.length; i++) {
                try { videos[i].pause(); } catch(e) {}
            }
            var btn = document.querySelector('ytmusic-player-bar #play-pause-button') ||
                      document.querySelector('#play-pause-button') ||
                      document.querySelector('ytmusic-player-bar tp-yt-paper-icon-button#play-pause-button') ||
                      document.querySelector('ytmusic-player-bar [aria-label*="Pause" i]') ||
                      document.querySelector('ytmusic-player-bar [aria-label*="Tạm dừng" i]');
            if (btn) {
                var label = (btn.getAttribute('aria-label') || btn.getAttribute('title') || '').toLowerCase();
                if (label.indexOf('pause') !== -1 || label.indexOf('tạm dừng') !== -1 || label === '') {
                    btn.click();
                    if (btn.tagName && btn.tagName.toLowerCase().indexOf('-') === -1) {
                        var inner = btn.querySelector('button, #button');
                        if (inner) inner.click();
                    }
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
                    btn.click();
                    clicked = true;
                }

                // 4. Fallback 1: Native Shift+N KeyboardEvent (Universal YouTube Music shortcut)
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

                // 5. Fallback 2: Player API
                var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
                if (!clicked && p && typeof p.nextVideo === 'function') {
                    try { p.nextVideo(); } catch(e) {}
                }

                // 6. Fallback 3: DOM Queue item fallback
                if (!clicked) {
                    var queueItems = document.querySelectorAll('ytmusic-player-queue-item');
                    if (queueItems && queueItems.length > 1) {
                        for (var qi = 0; qi < queueItems.length - 1; qi++) {
                            var item = queueItems[qi];
                            if (item.hasAttribute('selected') || item.classList.contains('selected') || item.getAttribute('play-state') === 'playing') {
                                var nextItem = queueItems[qi + 1];
                                var playTarget = nextItem.querySelector('#play-button, .play-button, ytmusic-play-button-renderer') || nextItem;
                                playTarget.click();
                                break;
                            }
                        }
                    }
                }

                // 7. Ensure video playback
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
    
    public func toggleShuffle() {
        let script = """
        (function() {
            var btn = document.querySelector('ytmusic-player-bar .shuffle') || 
                      document.querySelector('#right-controls .shuffle') || 
                      document.querySelector('.shuffle.ytmusic-player-bar') ||
                      document.querySelector('tp-yt-paper-icon-button.shuffle') ||
                      document.querySelector('ytmusic-player-bar [aria-label*="Shuffle" i]') ||
                      document.querySelector('ytmusic-player-bar [aria-label*="xáo trộn" i]');
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
    
    public func setRepeatMode(_ mode: YTMRepeatMode) {
        trackData.repeatMode = mode
        let script = """
        (function() {
            window._morphTargetRepeatMode = '\(mode.rawValue)';
            var v = document.querySelector('video');
            if (v) {
                v.loop = (window._morphTargetRepeatMode === 'one');
            }
            var repeatBtn = document.querySelector('ytmusic-player-bar .repeat') || 
                            document.querySelector('#right-controls .repeat') || 
                            document.querySelector('.repeat.ytmusic-player-bar') ||
                            document.querySelector('tp-yt-paper-icon-button.repeat') ||
                            document.querySelector('ytmusic-player-bar [aria-label*="Repeat" i]') ||
                            document.querySelector('ytmusic-player-bar [aria-label*="lặp lại" i]');
            if (repeatBtn) {
                function currentYTMMode() {
                    var inner = repeatBtn.querySelector('button') || repeatBtn;
                    var rText = ((repeatBtn.getAttribute('aria-label') || repeatBtn.getAttribute('title') || '') + ' ' + 
                                 (inner.getAttribute('aria-label') || inner.getAttribute('title') || '') + ' ' +
                                 (repeatBtn.innerText || '')).toLowerCase();
                    var rPressed = repeatBtn.getAttribute('aria-pressed') === 'true' || inner.getAttribute('aria-pressed') === 'true';
                    if (rText.indexOf('one') !== -1 || rText.indexOf('1') !== -1 || rText.indexOf('một') !== -1) {
                        return 'one';
                    } else if (rText.indexOf('all') !== -1 || rText.indexOf('tất cả') !== -1 || rPressed) {
                        return 'all';
                    } else {
                        return 'off';
                    }
                }
                var target = '\(mode.rawValue)';
                var attempts = 0;
                while (currentYTMMode() !== target && attempts < 4) {
                    var inner = repeatBtn.querySelector('button, #button');
                    (inner || repeatBtn).click();
                    attempts++;
                }
            }
            if (typeof window.morphSendUpdate === 'function') {
                setTimeout(window.morphSendUpdate, 150);
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
    
    public func playQueueIndex(_ index: Int) {
        let script = """
        (function() {
            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
            if (p && typeof p.playVideoAt === 'function') {
                try {
                    p.playVideoAt(\(index));
                    if (typeof window.morphSendUpdate === 'function') {
                        setTimeout(window.morphSendUpdate, 250);
                    }
                    return;
                } catch(e) {}
            }
            var items = document.querySelectorAll('ytmusic-player-queue-item, ytmusic-player-queue #contents ytmusic-player-queue-item');
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
    
    // MARK: Quick Picks
    public func fetchQuickPicks() {
        Task { @MainActor in
            await self.refreshQuickPicks()
        }
    }
    
    public func refreshQuickPicks() async {
        isLoadingQuickPicks = true
        quickPicksError = nil
        defer { isLoadingQuickPicks = false }
        do {
            let doc = try await innerTube("browse", body: ["browseId": "FEmusic_home"])
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
            return "VL\(raw)"
        }
    }
    
    private func loadAllPages(browseId: String, maxTracks: Int = 1500) async throws -> YTMTrackPage {
        print("[Morph YTM] loadAllPages requesting browseId: '\(browseId)'")
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
        var page = try await loadAllPages(browseId: bId)
        if playlist.kind == .artist, let more = page.moreBrowseId, more.hasPrefix("VL") {
            print("[Morph YTM] Fetching full top songs for artist via moreBrowseId: '\(more)'")
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
        guard !MorphEnvironment.isTestingEnvironment else { return }
        let vid = videoId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !vid.isEmpty else { return }
        
        // Normalize listId: strip "VL" browse prefix if present (YouTube watch requires "PL..." or "LM", not "VLPL...")
        var cleanList: String? = listId?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let l = cleanList, l.hasPrefix("VL") {
            cleanList = String(l.dropFirst(2))
        }
        
        // Continuous Playback Guarantee: If no playlist is provided, default to the song's Radio list (RDAMVM<videoId>)
        // YouTube Music uses RDAMVM to automatically generate an endless autoplay queue of related songs.
        if cleanList == nil || cleanList?.isEmpty == true {
            cleanList = "RDAMVM\(vid)"
        }
        
        // 1. Try immediate in-page playback via movie_player API (seamless, zero full-page reload, preserves WebKit session)
        let listArg = cleanList.map { "'\($0)'" } ?? "null"
        let script = """
        (function() {
            var vid = '\(vid)';
            var listId = \(listArg);
            
            // 1. Trigger Polymer client-side link navigation so YouTube Music's SPA router,
            // player bar, queue, and mediaSession update together seamlessly.
            try {
                var watchPath = '/watch?v=' + encodeURIComponent(vid) + (listId ? ('&list=' + encodeURIComponent(listId)) : '');
                var link = document.createElement('a');
                link.href = watchPath;
                document.body.appendChild(link);
                link.click();
                link.remove();
            } catch(eNav) {}
            
            var p = document.getElementById('movie_player') || document.querySelector('#movie_player');
            if (p) {
                try {
                    if (typeof p.loadVideoById === 'function') {
                        if (listId && listId.length > 0) {
                            try {
                                p.loadVideoById({ videoId: vid, list: listId });
                            } catch(e1) {
                                p.loadVideoById(vid);
                            }
                        } else {
                            p.loadVideoById(vid);
                        }
                    } else if (typeof p.loadVideoByPlayerVars === 'function') {
                        p.loadVideoByPlayerVars({ videoId: vid, list: listId });
                    }
                    if (typeof p.playVideo === 'function') {
                        p.playVideo();
                    }
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
                    if (typeof window.morphSendUpdate === 'function') {
                        setTimeout(window.morphSendUpdate, 250);
                    }
                    return true;
                } catch(e) {}
            }
            // Fallback inside page: navigate to absolute canonical URL (never relative, which throws SyntaxError in WebKit)
            var target = 'https://music.youtube.com/watch?v=' + encodeURIComponent(vid) + (listId ? ('&list=' + encodeURIComponent(listId)) : '');
            window.location.href = target;
            return false;
        })();
        """
        
        // If webView is already on music.youtube.com, evaluate the script
        if let host = webView.url?.host, host.hasSuffix("music.youtube.com") {
            evaluate(script)
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
        let script = """
        (function() {
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
    }
    
    public func playEntirePlaylist() {
        let script = """
        (function() {
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
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: chromeScript) {
            let output = scriptObject.executeAndReturnError(&error)
            if error == nil && output.booleanValue {
                return true
            }
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
        
        var safariError: NSDictionary?
        if let safariScriptObject = NSAppleScript(source: safariScript) {
            let output = safariScriptObject.executeAndReturnError(&safariError)
            if safariError == nil && output.booleanValue {
                return true
            }
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
            
            var rawCookies = ""
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: chromeCookieScript) {
                let output = scriptObject.executeAndReturnError(&error)
                if error == nil, let val = output.stringValue, !val.isEmpty {
                    rawCookies = val
                }
            }
            
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
                var safariError: NSDictionary?
                if let scriptObject = NSAppleScript(source: safariCookieScript) {
                    let output = scriptObject.executeAndReturnError(&safariError)
                    if safariError == nil, let val = output.stringValue, !val.isEmpty {
                        rawCookies = val
                    }
                }
            }
            
            guard !rawCookies.isEmpty else { return }
            
            // Parse cookies string ("key=value; key2=val2")
            let cookiePairs = rawCookies.components(separatedBy: ";")
            let cookieStore = await MainActor.run { WKWebsiteDataStore.default().httpCookieStore }
            
            for pair in cookiePairs {
                let parts = pair.components(separatedBy: "=")
                guard parts.count >= 2 else { continue }
                let name = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty, !value.isEmpty else { continue }
                
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
                self.isSignedIn = true
                self.fetchRealUserPlaylists()
                // Reload internal webView to apply the newly imported session cookies
                self.loadHome()
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
                if (window._morphTargetRepeatMode) {
                    repeatMode = window._morphTargetRepeatMode;
                } else {
                    window._morphTargetRepeatMode = repeatMode;
                }
                if (videoEl) {
                    videoEl.loop = (repeatMode === 'one');
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

                    // 3. Quick Picks extraction from Home feed
                    var quickPicks = [];
                    try {
                        var shelves = document.querySelectorAll('ytmusic-carousel-shelf-renderer, ytmusic-shelf-renderer');
                        for (var s = 0; s < shelves.length; s++) {
                            var sh = shelves[s];
                            var shTitleEl = sh.querySelector('yt-formatted-string.title') || sh.querySelector('.title') || sh.querySelector('h2');
                            var shTitle = shTitleEl ? (shTitleEl.innerText || shTitleEl.textContent || '').toLowerCase() : '';
                            if (shTitle.indexOf('quick pick') !== -1 || shTitle.indexOf('listen again') !== -1 || shTitle.indexOf('start radio') !== -1 || (s === 0 && window.location.pathname === '/')) {
                                var items = sh.querySelectorAll('ytmusic-responsive-list-item-renderer, ytmusic-two-row-item-renderer');
                                for (var itIdx = 0; itIdx < Math.min(items.length, 25); itIdx++) {
                                    var itEl = items[itIdx];
                                    var tEl = itEl.querySelector('.title a') || itEl.querySelector('.title') || itEl.querySelector('yt-formatted-string.title');
                                    var aEl = itEl.querySelector('.subtitle a') || itEl.querySelector('.byline a') || itEl.querySelector('.subtitle') || itEl.querySelector('.byline');
                                    var dEl = itEl.querySelector('.fixed-column') || itEl.querySelector('.duration');
                                    var itTitle = tEl ? (tEl.innerText || tEl.textContent || '').trim() : '';
                                    var itArtist = aEl ? (aEl.innerText || aEl.textContent || '').trim() : '';
                                    var itDur = dEl ? (dEl.innerText || dEl.textContent || '').trim() : '';
                                    var linkEl = itEl.querySelector('a[href*="watch?v="]');
                                    var vId = '';
                                    if (linkEl) {
                                        var href = linkEl.getAttribute('href') || '';
                                        var vMatch = href.match(/[?&]v=([^&]+)/);
                                        if (vMatch) vId = vMatch[1];
                                    }
                                    var imgEl = itEl.querySelector('img');
                                    var thumb = imgEl ? imgEl.src : null;
                                    if (itTitle) {
                                        quickPicks.push({
                                            id: vId ? vId : ('qp_' + itIdx),
                                            title: itTitle,
                                            artist: itArtist,
                                            duration: itDur,
                                            videoId: vId ? vId : null,
                                            thumbnailURL: thumb
                                        });
                                    }
                                }
                                if (quickPicks.length > 0) break;
                            }
                        }
                    } catch(qpe) {}

                    // 4. Ensure Liked Music if link is present
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
                    
                    // 5. User Signed-In State Detection
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
                            var hasAuthCookie = /(?:^|;\\s*)(?:SAPISID|__Secure-3PAPISID|__Secure-1PAPISID)=([^;]+)/.test(document.cookie || '');
                            if ((hasAvatar || hasAuthCookie) && !signInBtn) {
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
                    quickPicks: quickPicks,
                    isSignedIn: isSignedIn
                };
            }
            
            var _morphLastSendTime = 0;
            var _morphSendPendingTimeout = null;
            
            window.morphSendUpdate = function(force) {
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
                    var data = getTrackInfo();
                    window.webkit.messageHandlers.\(kHandlerName).postMessage(data);
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
                    for (var i = 0; i < confirmButtons.length; i++) {
                        var cb = confirmButtons[i];
                        if (cb && (cb.offsetParent !== null || cb.offsetWidth > 0)) {
                            var inner = cb.querySelector('button, #button, yt-button-shape');
                            (inner || cb).click();
                        }
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

            function triggerNextVideo() {
                try {
                    dismissModalsAndEnableAutoplay();

                    var v = document.querySelector('video');
                    // Repeat One: replay current video seamlessly
                    if (window._morphTargetRepeatMode === 'one' || (v && v.loop)) {
                        if (v) {
                            v.currentTime = 0;
                            v.play();
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
                        advanced = true;
                    }

                    // Fallback: If player has no next video in queue, play next item in DOM queue
                    if (!advanced && queueItems && queueItems.length > 1) {
                        if (currentQueueIdx !== -1 && currentQueueIdx < queueItems.length - 1) {
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

                    // Fallback 2: Start first playable recommendation or up-next track ONLY if not repeating all/one
                    if (!advanced && window._morphTargetRepeatMode !== 'all' && window._morphTargetRepeatMode !== 'one') {
                        var recPlay = document.querySelector('ytmusic-responsive-list-item-renderer #play-button, ytmusic-shelf-renderer #play-button');
                        if (recPlay) {
                            var innerR = recPlay.querySelector('button, #button');
                            (innerR || recPlay).click();
                        }
                    }
                } catch(e) {}
            }
            
            function attachVideoListeners() {
                var v = document.querySelector('video');
                if (v && !v._morphListeners) {
                    v._morphListeners = true;
                    if (window._morphTargetRepeatMode === 'one') {
                        v.loop = true;
                    }
                    ['play', 'pause', 'timeupdate', 'ended', 'durationchange', 'volumechange'].forEach(function(evt) {
                        v.addEventListener(evt, function() {
                            dismissModalsAndEnableAutoplay();
                            window.morphSendUpdate(evt === 'play' || evt === 'pause' || evt === 'ended');
                        });
                    });
                    
                    // Auto-advance or seamless repeat when current track ends
                    v.addEventListener('ended', function() {
                        window.morphSendUpdate(true);
                        if (window._morphTargetRepeatMode === 'one' || v.loop) {
                            try {
                                v.currentTime = 0;
                                v.play();
                            } catch(e) {}
                            return;
                        }
                        setTimeout(function() {
                            triggerNextVideo();
                        }, 250);
                    });
                    
                    // Continuous playback watchdog: if playback reaches the very end (< 0.5s remaining) and stops/pauses
                    v.addEventListener('timeupdate', function() {
                        dismissModalsAndEnableAutoplay();
                        if (window._morphTargetRepeatMode === 'one' || v.loop) {
                            return;
                        }
                        if (v.duration > 3 && v.currentTime >= (v.duration - 0.4) && !v._morphAutoAdvancing) {
                            v._morphAutoAdvancing = true;
                            setTimeout(function() {
                                if (window._morphTargetRepeatMode === 'one' || v.loop) {
                                    v._morphAutoAdvancing = false;
                                    return;
                                }
                                if (v.ended || v.paused || v.currentTime >= (v.duration - 0.5)) {
                                    triggerNextVideo();
                                }
                                setTimeout(function() { v._morphAutoAdvancing = false; }, 3000);
                            }, 500);
                        }
                    });
                }
            }
            
            var _morphMutationTimeout = null;
            var observer = new MutationObserver(function() {
                attachVideoListeners();
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
                window.morphSendUpdate(false);
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
            
            // Direct Google Sign-In Action Button / Signed In Indicator
            if engine.isSignedIn {
                HStack(spacing: 6) {
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
                    
                    Button(action: {
                        engine.fetchRealUserPlaylists()
                        engine.fetchQuickPicks()
                        engine.hidePlayerWindow()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.system(size: 9.5, weight: .bold))
                            Text("Done • Sync to Morph")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Sync playlists & return to Morph Mini Player")
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
