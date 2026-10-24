import Foundation

// MARK: - Models

public enum YTMSearchKind: String, Codable, CaseIterable {
    case song, video, artist, album, playlist
    
    public var sectionTitle: String {
        switch self {
        case .song: return "Songs"
        case .video: return "Videos"
        case .artist: return "Artists"
        case .album: return "Albums"
        case .playlist: return "Playlists"
        }
    }
    
    public var iconName: String {
        switch self {
        case .song: return "music.note"
        case .video: return "play.rectangle.fill"
        case .artist: return "person.fill"
        case .album: return "square.stack.fill"
        case .playlist: return "music.note.list"
        }
    }
}

public struct YTMSearchResult: Identifiable, Equatable {
    public var id: String
    public var kind: YTMSearchKind
    public var title: String
    public var subtitle: String
    public var thumbnailURL: String?
    /// Set for songs / videos.
    public var videoId: String?
    /// Set for artists / albums / playlists (the InnerTube browseId).
    public var browseId: String?
    
    public init(id: String, kind: YTMSearchKind, title: String, subtitle: String = "", thumbnailURL: String? = nil, videoId: String? = nil, browseId: String? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.thumbnailURL = thumbnailURL
        self.videoId = videoId
        self.browseId = browseId
    }
    
    /// Track representation for song / video results.
    public var asTrack: YTMPlaylistItem? {
        guard let videoId = videoId else { return nil }
        return YTMPlaylistItem(id: id, title: title, artist: subtitle, videoId: videoId, thumbnailURL: thumbnailURL)
    }
    
    /// Browsable container representation for artist / album / playlist results.
    public var asPlaylist: YTMPlaylist? {
        guard let browseId = browseId else { return nil }
        let plKind: YTMPlaylistKind
        switch kind {
        case .artist: plKind = .artist
        case .album: plKind = .album
        default: plKind = .playlist
        }
        let plId = (plKind == .playlist && browseId.hasPrefix("VL")) ? String(browseId.dropFirst(2)) : browseId
        return YTMPlaylist(id: plId, title: title, subtitle: subtitle, thumbnailURL: thumbnailURL, browseId: browseId, kind: plKind)
    }
}

public struct YTMTrackPage: Equatable {
    public var tracks: [YTMPlaylistItem] = []
    public var continuation: String? = nil
    /// Playlist id usable for `watch?v=…&list=…` playback (albums, playlists).
    public var playbackListId: String? = nil
    /// Browse id of the full track list (artist "Top songs" → full playlist).
    public var moreBrowseId: String? = nil
    
    public init(tracks: [YTMPlaylistItem] = [], continuation: String? = nil, playbackListId: String? = nil, moreBrowseId: String? = nil) {
        self.tracks = tracks
        self.continuation = continuation
        self.playbackListId = playbackListId
        self.moreBrowseId = moreBrowseId
    }
}

// MARK: - Parser

public enum YTMParser {
    // MARK: JSON helpers
    static func dict(_ any: Any?) -> [String: Any]? { any as? [String: Any] }
    static func array(_ any: Any?) -> [[String: Any]] { (any as? [[String: Any]]) ?? [] }
    
    /// Pre-order walk over every dictionary in the tree (arrays keep their order).
    static func walk(_ node: Any?, _ visit: ([String: Any]) -> Void) {
        if let d = node as? [String: Any] {
            visit(d)
            for (_, v) in d { walk(v, visit) }
        } else if let a = node as? [Any] {
            for v in a { walk(v, visit) }
        }
    }
    
    /// All dictionary values stored under `key` anywhere in the tree, in document order for arrays.
    static func collect(_ node: Any?, key: String) -> [[String: Any]] {
        var out: [[String: Any]] = []
        func rec(_ n: Any?) {
            if let d = n as? [String: Any] {
                if let hit = d[key] as? [String: Any] { out.append(hit) }
                for (k, v) in d where k != key { rec(v) }
                if let hit = d[key] as? [String: Any] { rec(hit) }
            } else if let a = n as? [Any] {
                for v in a { rec(v) }
            }
        }
        rec(node)
        return out
    }
    
    static func firstString(in node: Any?, key: String) -> String? {
        var result: String?
        walk(node) { d in
            if result == nil, let s = d[key] as? String, !s.isEmpty { result = s }
        }
        return result
    }
    
    static func runs(_ text: Any?) -> [[String: Any]] {
        array(dict(text)?["runs"])
    }
    
    static func text(_ text: Any?) -> String {
        runs(text).compactMap { $0["text"] as? String }.joined()
    }
    
    static func thumbnail(_ node: Any?) -> String? {
        var best: String?
        walk(node) { d in
            if best == nil, let thumbs = d["thumbnails"] as? [[String: Any]], let url = thumbs.last?["url"] as? String {
                best = url
            }
        }
        return best
    }
    
    // MARK: Byline cleanup
    private static let typeWords: Set<String> = ["song", "video", "single", "ep", "album", "artist", "playlist", "podcast", "episode", "profile"]
    
    static func isDuration(_ s: String) -> Bool {
        s.range(of: #"^\d{1,2}(:\d{2}){1,2}$"#, options: .regularExpression) != nil
    }
    
    static func isPlayCount(_ s: String) -> Bool {
        s.range(of: #"(?i)^[\d.,]+\s*[KMB]?\s*(plays|views|listeners|monthly audience|subscribers)$"#, options: .regularExpression) != nil
            || s.range(of: #"(?i)^[\d.,]+[KMB]$"#, options: .regularExpression) != nil
    }
    
    /// Splits a " • " separated byline into segments.
    static func segments(_ raw: String) -> [String] {
        raw.components(separatedBy: " • ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    // MARK: Track items
    static func flexText(_ item: [String: Any], _ index: Int) -> [String: Any]? {
        let cols = array(item["flexColumns"])
        guard index < cols.count else { return nil }
        return dict(cols[index]["musicResponsiveListItemFlexColumnRenderer"])?["text"] as? [String: Any]
    }
    
    static func videoId(of item: [String: Any]) -> String? {
        if let v = dict(item["playlistItemData"])?["videoId"] as? String, !v.isEmpty { return v }
        if let overlay = dict(item["overlay"]),
           let v = firstString(in: overlay, key: "videoId"), !v.isEmpty { return v }
        if let r = runs(flexText(item, 0)).first,
           let v = dict(dict(r["navigationEndpoint"])?["watchEndpoint"])?["videoId"] as? String, !v.isEmpty { return v }
        if let v = dict(dict(item["navigationEndpoint"])?["watchEndpoint"])?["videoId"] as? String, !v.isEmpty { return v }
        if let v = dict(dict(item["playNavigationEndpoint"])?["watchEndpoint"])?["videoId"] as? String, !v.isEmpty { return v }
        if let v = dict(dict(item["onTap"])?["watchEndpoint"])?["videoId"] as? String, !v.isEmpty { return v }
        if let v = firstString(in: item, key: "videoId"), !v.isEmpty { return v }
        return nil
    }
    
    static func musicVideoType(of item: [String: Any]) -> String? {
        firstString(in: item["overlay"], key: "musicVideoType")
    }
    
    /// Parses one `musicResponsiveListItemRenderer` into a playable track.
    static func track(from item: [String: Any], index: Int) -> YTMPlaylistItem? {
        guard let vid = videoId(of: item) else { return nil }
        let title = runs(flexText(item, 0)).first?["text"] as? String ?? ""
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        
        var artist = ""
        var duration = ""
        let byline = text(flexText(item, 1))
        for seg in segments(byline) {
            if isDuration(seg) { duration = seg; continue }
            if typeWords.contains(seg.lowercased()) { continue }
            if isPlayCount(seg) { continue }
            if artist.isEmpty { artist = seg }
        }
        
        let fixed = array(item["fixedColumns"])
        if let first = fixed.first,
           let t = dict(first["musicResponsiveListItemFixedColumnRenderer"])?["text"] {
            let d = text(t)
            if !d.isEmpty { duration = d }
        }
        
        let setId = dict(item["playlistItemData"])?["playlistSetVideoId"] as? String
        return YTMPlaylistItem(
            id: setId ?? "\(vid)#\(index)",
            title: title,
            artist: artist,
            duration: duration,
            isPlaying: false,
            videoId: vid,
            thumbnailURL: thumbnail(item["thumbnail"])
        )
    }
    
    // MARK: Continuations
    static func continuation(in node: Any?) -> String? {
        var token: String?
        walk(node) { d in
            guard token == nil else { return }
            if let n = dict(d["nextContinuationData"])?["continuation"] as? String {
                token = n
            } else if let c = dict(d["continuationCommand"])?["token"] as? String {
                token = c
            }
        }
        return token
    }
    
    // MARK: Tracks (playlist / album / artist / continuation pages)
    public static func parseTrackPage(_ doc: [String: Any], startIndex: Int = 0) -> YTMTrackPage {
        var shelves: [[String: Any]] = collect(doc, key: "musicPlaylistShelfRenderer")
        shelves += collect(doc, key: "musicPlaylistShelfContinuation")
        shelves += collect(doc, key: "musicShelfContinuation")
        shelves += collect(doc, key: "appendContinuationItemsAction")
        
        var usedFallbackShelf = false
        if shelves.isEmpty {
            // Albums / artists: first music shelf that actually contains playable items.
            for shelf in collect(doc, key: "musicShelfRenderer") {
                let items = collect(shelf, key: "musicResponsiveListItemRenderer")
                if items.contains(where: { videoId(of: $0) != nil }) {
                    shelves = [shelf]
                    usedFallbackShelf = true
                    break
                }
            }
        }
        
        var page = YTMTrackPage()
        var idx = startIndex
        for shelf in shelves {
            for item in collect(shelf, key: "musicResponsiveListItemRenderer") {
                if let t = track(from: item, index: idx) {
                    page.tracks.append(t)
                    idx += 1
                }
            }
            if page.continuation == nil { page.continuation = continuation(in: shelf) }
            if usedFallbackShelf, page.moreBrowseId == nil {
                page.moreBrowseId = (dict(dict(shelf["bottomEndpoint"])?["browseEndpoint"])?["browseId"] as? String)
                    ?? (dict(dict(runs(shelf["title"]).first?["navigationEndpoint"])?["browseEndpoint"])?["browseId"] as? String)
            }
        }
        
        // First-page playlist responses keep the continuation on the enclosing sectionListRenderer.
        if page.continuation == nil, !usedFallbackShelf, !shelves.isEmpty {
            for section in collect(doc, key: "sectionListRenderer") {
                if let c = continuation(in: section["continuations"]) {
                    page.continuation = c
                    break
                }
            }
        }
        
        // Playback list id from the page header (albums expose their audio playlist here).
        for key in ["musicResponsiveHeaderRenderer", "musicDetailHeaderRenderer", "musicEditablePlaylistDetailHeaderRenderer"] {
            if let header = collect(doc, key: key).first, let pid = firstString(in: header, key: "playlistId") {
                page.playbackListId = pid
                break
            }
        }
        if page.playbackListId == nil, let shelf = shelves.first, !usedFallbackShelf,
           let pid = shelf["playlistId"] as? String {
            page.playbackListId = pid
        }
        page.tracks = YTMPlaylistItem.deduplicate(page.tracks)
        return page
    }
    
    // MARK: Library playlists
    public static func parseLibraryPlaylists(_ doc: [String: Any]) -> (playlists: [YTMPlaylist], continuation: String?) {
        var out: [YTMPlaylist] = []
        var seen = Set<String>()
        
        func add(browseId: String, title: String, subtitle: String, thumb: String?) {
            guard browseId.hasPrefix("VL"), !title.isEmpty else { return }
            let id = String(browseId.dropFirst(2))
            guard !id.isEmpty, seen.insert(id).inserted else { return }
            out.append(YTMPlaylist(id: id, title: title, subtitle: subtitle, thumbnailURL: thumb, browseId: browseId, kind: .playlist))
        }
        
        for card in collect(doc, key: "musicTwoRowItemRenderer") {
            let bid = dict(dict(card["navigationEndpoint"])?["browseEndpoint"])?["browseId"] as? String ?? ""
            add(browseId: bid, title: text(card["title"]), subtitle: text(card["subtitle"]), thumb: thumbnail(card["thumbnailRenderer"]))
        }
        for item in collect(doc, key: "musicResponsiveListItemRenderer") {
            let bid = dict(dict(item["navigationEndpoint"])?["browseEndpoint"])?["browseId"] as? String ?? ""
            let title = runs(flexText(item, 0)).first?["text"] as? String ?? ""
            add(browseId: bid, title: title, subtitle: text(flexText(item, 1)), thumb: thumbnail(item["thumbnail"]))
        }
        return (out, continuation(in: doc))
    }
    
    // MARK: Catalog search
    static func kind(forPageType pageType: String?) -> YTMSearchKind? {
        guard let p = pageType else { return nil }
        if p.contains("ARTIST") || p == "MUSIC_PAGE_TYPE_USER_CHANNEL" { return .artist }
        if p.contains("ALBUM") { return .album }
        if p.contains("PLAYLIST") { return .playlist }
        return nil
    }
    
    static func pageType(of endpoint: Any?) -> String? {
        let browse = dict(dict(endpoint)?["browseEndpoint"])
        return dict(dict(browse?["browseEndpointContextSupportedConfigs"])?["browseEndpointContextMusicConfig"])?["pageType"] as? String
    }
    
    static func cleanedSubtitle(_ raw: String) -> String {
        segments(raw).filter { !typeWords.contains($0.lowercased()) }.joined(separator: " • ")
    }
    
    static func searchResult(fromItem item: [String: Any], index: Int) -> YTMSearchResult? {
        let title = runs(flexText(item, 0)).first?["text"] as? String ?? ""
        guard !title.isEmpty else { return nil }
        let subtitle = cleanedSubtitle(text(flexText(item, 1)))
        let thumb = thumbnail(item["thumbnail"])
        
        if let nav = dict(item["navigationEndpoint"]), let k = kind(forPageType: pageType(of: nav)),
           let bid = dict(nav["browseEndpoint"])?["browseId"] as? String {
            return YTMSearchResult(id: "\(k.rawValue):\(bid)", kind: k, title: title, subtitle: subtitle, thumbnailURL: thumb, browseId: bid)
        }
        
        let mvt = musicVideoType(of: item) ?? ""
        if mvt.contains("PODCAST") { return nil }
        guard let vid = videoId(of: item) else { return nil }
        let isSong = mvt.isEmpty || mvt.contains("ATV")
        // Songs show "Artist • Album • 3:45"; keep artist + album and drop durations / play counts.
        let cleaned = segments(text(flexText(item, 1))).filter { !typeWords.contains($0.lowercased()) && !isDuration($0) && !isPlayCount($0) }
        let sub = cleaned.prefix(2).joined(separator: " • ")
        return YTMSearchResult(id: "\(isSong ? "song" : "video"):\(vid)", kind: isSong ? .song : .video, title: title, subtitle: sub, thumbnailURL: thumb, videoId: vid)
    }
    
    static func searchResult(fromCard card: [String: Any]) -> YTMSearchResult? {
        let title = runs(card["title"]).first?["text"] as? String ?? ""
        guard !title.isEmpty else { return nil }
        let subtitle = cleanedSubtitle(text(card["subtitle"]))
        let thumb = thumbnail(card["thumbnail"])
        let nav = dict(runs(card["title"]).first?["navigationEndpoint"]) ?? dict(card["onTap"])
        if let nav = nav, let bid = dict(nav["browseEndpoint"])?["browseId"] as? String {
            let k = kind(forPageType: pageType(of: nav)) ?? .playlist
            return YTMSearchResult(id: "\(k.rawValue):\(bid)", kind: k, title: title, subtitle: subtitle, thumbnailURL: thumb, browseId: bid)
        }
        if let vid = dict(nav?["watchEndpoint"])?["videoId"] as? String {
            return YTMSearchResult(id: "song:\(vid)", kind: .song, title: title, subtitle: subtitle, thumbnailURL: thumb, videoId: vid)
        }
        return nil
    }
    
    /// Parses a search response. The top-result card (if any) comes first, then every result in page order.
    public static func parseSearch(_ doc: [String: Any]) -> [YTMSearchResult] {
        var results: [YTMSearchResult] = []
        var seen = Set<String>()
        func push(_ r: YTMSearchResult?) {
            if let r = r, seen.insert(r.id).inserted { results.append(r) }
        }
        if let card = collect(doc, key: "musicCardShelfRenderer").first {
            push(searchResult(fromCard: card))
        }
        var idx = 0
        for item in collect(doc, key: "musicResponsiveListItemRenderer") {
            push(searchResult(fromItem: item, index: idx))
            idx += 1
        }
        return results
    }
    
    // MARK: - Quick Picks (Home Algorithmic Recommendations)
    
    static func cardTrack(from card: [String: Any], index: Int) -> YTMPlaylistItem? {
        guard let vid = videoId(of: card) else { return nil }
        let title = text(card["title"]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }
        let subtitle = text(card["subtitle"]).trimmingCharacters(in: .whitespacesAndNewlines)
        var artist = ""
        var duration = ""
        for seg in segments(subtitle) {
            if isDuration(seg) { duration = seg; continue }
            if typeWords.contains(seg.lowercased()) { continue }
            if isPlayCount(seg) { continue }
            if artist.isEmpty { artist = seg }
        }
        let thumb = thumbnail(card["thumbnailRenderer"]) ?? thumbnail(card["thumbnail"])
        return YTMPlaylistItem(
            id: "\(vid)#\(index)",
            title: title,
            artist: artist.isEmpty ? subtitle : artist,
            duration: duration,
            isPlaying: false,
            videoId: vid,
            thumbnailURL: thumb
        )
    }
    
    /// Parses the YouTube Music Home feed (`FEmusic_home`) and extracts the algorithmic Quick Picks shelf.
    public static func parseQuickPicks(_ doc: [String: Any]) -> [YTMPlaylistItem] {
        var candidateShelves: [[String: Any]] = []
        candidateShelves += collect(doc, key: "musicCarouselShelfRenderer")
        candidateShelves += collect(doc, key: "musicShelfRenderer")
        
        let priorityKeywords = [
            "quick pick", "listen again", "start radio", "mixed for you",
            "mixed for", "forgotten favorite", "recommend", "picks",
            "similar to", "deep cuts", "from your library"
        ]
        
        func extractTracks(from shelf: [String: Any]) -> [YTMPlaylistItem] {
            var tracks: [YTMPlaylistItem] = []
            var idx = 0
            for item in collect(shelf, key: "musicResponsiveListItemRenderer") {
                if let t = track(from: item, index: idx) {
                    tracks.append(t)
                    idx += 1
                }
            }
            if tracks.isEmpty {
                for card in collect(shelf, key: "musicTwoRowItemRenderer") {
                    if let t = cardTrack(from: card, index: idx) {
                        tracks.append(t)
                        idx += 1
                    }
                }
            }
            return tracks
        }
        
        // 1. Check matching priority shelves first
        for shelf in candidateShelves {
            let headerText = (text(shelf["header"]) + " " + text(shelf["title"])).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if priorityKeywords.contains(where: { headerText.contains($0) }) {
                let tracks = extractTracks(from: shelf)
                if !tracks.isEmpty {
                    return YTMPlaylistItem.deduplicate(tracks)
                }
            }
        }
        
        // 2. Fallback: First shelf with at least 2 playable songs
        for shelf in candidateShelves {
            let tracks = extractTracks(from: shelf)
            if tracks.count >= 2 {
                return YTMPlaylistItem.deduplicate(tracks)
            }
        }
        
        return []
    }
    
    /// Curated algorithmic starting picks for instant offline playback & guest experience.
    public static var defaultQuickPicks: [YTMPlaylistItem] {
        return [
            YTMPlaylistItem(
                id: "qp_starboy",
                title: "Starboy",
                artist: "The Weeknd ft. Daft Punk",
                duration: "3:50",
                videoId: "34Na4j8AVgA",
                thumbnailURL: "https://i.ytimg.com/vi/34Na4j8AVgA/hqdefault.jpg"
            ),
            YTMPlaylistItem(
                id: "qp_midnight_city",
                title: "Midnight City",
                artist: "M83",
                duration: "4:04",
                videoId: "dX3k_QDnzHE",
                thumbnailURL: "https://i.ytimg.com/vi/dX3k_QDnzHE/hqdefault.jpg"
            ),
            YTMPlaylistItem(
                id: "qp_resonance",
                title: "Resonance",
                artist: "HOME",
                duration: "3:32",
                videoId: "8GW6sLrK40k",
                thumbnailURL: "https://i.ytimg.com/vi/8GW6sLrK40k/hqdefault.jpg"
            ),
            YTMPlaylistItem(
                id: "qp_after_dark",
                title: "After Dark",
                artist: "Mr.Kitty",
                duration: "4:18",
                videoId: "waAlgFq9Xq8",
                thumbnailURL: "https://i.ytimg.com/vi/waAlgFq9Xq8/hqdefault.jpg"
            ),
            YTMPlaylistItem(
                id: "qp_nightcall",
                title: "Nightcall",
                artist: "Kavinsky",
                duration: "4:19",
                videoId: "MV_3Dpw-BRY",
                thumbnailURL: "https://i.ytimg.com/vi/MV_3Dpw-BRY/hqdefault.jpg"
            ),
            YTMPlaylistItem(
                id: "qp_something_about_us",
                title: "Something About Us",
                artist: "Daft Punk",
                duration: "3:52",
                videoId: "em0MknB6wFo",
                thumbnailURL: "https://i.ytimg.com/vi/em0MknB6wFo/hqdefault.jpg"
            ),
            YTMPlaylistItem(
                id: "qp_blinding_lights",
                title: "Blinding Lights",
                artist: "The Weeknd",
                duration: "3:20",
                videoId: "4NRXx6U8ABQ",
                thumbnailURL: "https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg"
            ),
            YTMPlaylistItem(
                id: "qp_get_lucky",
                title: "Get Lucky",
                artist: "Daft Punk ft. Pharrell Williams",
                duration: "4:08",
                videoId: "5NV6Rdv1a3I",
                thumbnailURL: "https://i.ytimg.com/vi/5NV6Rdv1a3I/hqdefault.jpg"
            )
        ]
    }
}
