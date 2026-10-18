import XCTest
@testable import morph

private func fixture(_ name: String) throws -> [String: Any] {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/\(name).json")
    let data = try Data(contentsOf: url)
    return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

/// Parser + pipeline tests built on real YouTube Music InnerTube responses (trimmed copies live in Fixtures/).
final class YTMInnerTubeTests: XCTestCase {
    
    // MARK: Parsers
    
    func testPlaylistTracksAreParsedWithVideoIdsAndContinuation() throws {
        let page = YTMParser.parseTrackPage(try fixture("playlist"))
        XCTAssertGreaterThanOrEqual(page.tracks.count, 5, "Playlist fixture must yield its songs")
        for t in page.tracks {
            XCTAssertNotNil(t.videoId, "Every track needs a real videoId to be playable")
            XCTAssertFalse(t.title.isEmpty)
        }
        XCTAssertEqual(Set(page.tracks.map { $0.id }).count, page.tracks.count, "Track ids must be unique (duplicate songs are allowed in playlists)")
        XCTAssertFalse(page.tracks[0].artist.isEmpty, "Artist byline must be parsed")
        XCTAssertTrue(YTMParser.isDuration(page.tracks[0].duration), "Duration must come from the fixed column: \(page.tracks[0].duration)")
        XCTAssertNotNil(page.continuation, "Large playlists must expose a continuation token (>100 songs)")
        XCTAssertNotNil(page.playbackListId, "Playback list id must be derived from the page")
    }
    
    func testArtistPageYieldsTopSongsAndFullListLink() throws {
        let page = YTMParser.parseTrackPage(try fixture("artist"))
        XCTAssertEqual(page.tracks.count, 5, "Artist page must expose their songs (the reported bug: artist opened with no songs)")
        XCTAssertTrue(page.tracks.allSatisfy { $0.videoId != nil })
        XCTAssertTrue(page.moreBrowseId?.hasPrefix("VL") == true, "Top-songs shelf must link to the full song list")
    }
    
    func testSearchParsesTopArtistSongsAndKinds() throws {
        let results = YTMParser.parseSearch(try fixture("search"))
        XCTAssertFalse(results.isEmpty)
        let artist = results.first(where: { $0.kind == .artist })
        XCTAssertNotNil(artist, "Searching an author must surface the artist")
        XCTAssertTrue(artist?.browseId?.hasPrefix("UC") == true)
        XCTAssertEqual(artist?.asPlaylist?.kind, .artist)
        let songs = results.filter { $0.kind == .song }
        XCTAssertFalse(songs.isEmpty, "Songs must be returned")
        XCTAssertTrue(songs.allSatisfy { $0.videoId != nil })
        XCTAssertEqual(Set(results.map { $0.id }).count, results.count, "Results must be de-duplicated")
    }
    
    func testLibraryPlaylistsSkipNewPlaylistCardAndDedupe() {
        func card(_ title: String, _ browse: String?) -> [String: Any] {
            var c: [String: Any] = [
                "title": ["runs": [["text": title]]],
                "subtitle": ["runs": [["text": "Playlist"], ["text": " • "], ["text": "12 songs"]]],
                "thumbnailRenderer": ["musicThumbnailRenderer": ["thumbnail": ["thumbnails": [["url": "https://x/s.jpg"], ["url": "https://x/l.jpg"]]]]]
            ]
            if let b = browse { c["navigationEndpoint"] = ["browseEndpoint": ["browseId": b]] }
            return ["musicTwoRowItemRenderer": c]
        }
        let doc: [String: Any] = [
            "contents": ["singleColumnBrowseResultsRenderer": ["tabs": [["tabRenderer": ["content": ["sectionListRenderer": ["contents": [
                ["gridRenderer": ["items": [
                    card("New playlist", nil),
                    card("Liked Music", "VLLM"),
                    card("Focus", "VLPLfocus"),
                    card("Focus (dup)", "VLPLfocus"),
                    card("Some Album", "MPREb_abc")
                ], "continuations": [["nextContinuationData": ["continuation": "TOKEN1"]]]]]
            ]]]]]]]]
        ]
        let parsed = YTMParser.parseLibraryPlaylists(doc)
        XCTAssertEqual(parsed.playlists.map { $0.id }, ["LM", "PLfocus"])
        XCTAssertEqual(parsed.playlists[1].thumbnailURL, "https://x/l.jpg")
        XCTAssertEqual(parsed.playlists[1].subtitle, "Playlist • 12 songs")
        XCTAssertEqual(parsed.continuation, "TOKEN1")
    }
    
    // MARK: Model pipeline (stubbed network)
    
    @MainActor
    private func makeStubbedModel() throws -> (MediaControllerModel, YouTubeMusicEngine) {
        let engine = YouTubeMusicEngine()
        let playlist = try fixture("playlist")
        let artist = try fixture("artist")
        let search = try fixture("search")
        engine.innerTubeOverride = { endpoint, body in
            switch endpoint {
            case "search": return search
            case "browse":
                let id = body["browseId"] as? String ?? ""
                if id.hasPrefix("UC") { return artist }
                if id.hasPrefix("VLOLAK") { throw YouTubeMusicEngine.InnerTubeError.http(404) } // full list unavailable → fall back to top songs
                return playlist
            default: return [:]
            }
        }
        return (MediaControllerModel(engine: engine), engine)
    }
    
    @MainActor
    private func waitUntil(_ timeout: TimeInterval = 5, _ cond: () -> Bool) async {
        let end = Date().addingTimeInterval(timeout)
        while !cond() && Date() < end { try? await Task.sleep(nanoseconds: 50_000_000) }
    }
    
    @MainActor
    func testOpeningAPlaylistLoadsItsRealSongsAndQueueNoLongerOverwritesThem() async throws {
        let (media, engine) = try makeStubbedModel()
        let pl = YTMPlaylist(id: "PLtest", title: "Test", browseId: "VLPLtest", kind: .playlist)
        media.mergePlaylists([pl])
        
        media.selectPlaylist(pl)
        XCTAssertTrue(media.isLoadingTracks)
        await waitUntil { !media.isLoadingTracks }
        
        let tracks = try XCTUnwrap(media.selectedPlaylist?.tracks)
        XCTAssertGreaterThanOrEqual(tracks.count, 5, "Opened playlist must be populated with its songs")
        XCTAssertNil(media.tracksError)
        XCTAssertEqual(media.playlists.first(where: { $0.id == "PLtest" })?.tracks.count, tracks.count, "Loaded songs are cached on the library entry")
        
        // Regression: the DOM player-queue used to overwrite the selected playlist's tracks.
        engine.parseIncomingPayload([
            "title": "Other", "artist": "X", "duration": 100.0, "isPlaying": true,
            "queue": [["id": "0", "title": "Queue Song", "artist": "Q", "duration": "1:00", "isPlaying": true]]
        ])
        XCTAssertEqual(media.selectedPlaylist?.tracks.count, tracks.count, "Live queue must not replace a real playlist's songs")
        
        // In-playlist search
        let first = tracks[0]
        media.songSearchQuery = String(first.title.prefix(4))
        XCTAssertTrue(media.filteredSongs(for: media.selectedPlaylist!).contains(where: { $0.id == first.id }))
        media.songSearchQuery = "zzzz-no-such-song-zzzz"
        XCTAssertTrue(media.filteredSongs(for: media.selectedPlaylist!).isEmpty)
        media.songSearchQuery = ""
        
        // Selecting a song marks it playing using its real videoId
        media.playSongInSelectedPlaylist(first)
        XCTAssertEqual(media.trackTitle, first.title)
        XCTAssertTrue(media.selectedPlaylist?.tracks.first(where: { $0.id == first.id })?.isPlaying == true)
    }
    
    @MainActor
    func testSearchingAnAuthorShowsArtistAndOpeningItListsSongs() async throws {
        let (media, _) = try makeStubbedModel()
        media.isSearchingPlaylists = true
        media.playlistSearchQuery = "taylor swift"
        media.runCatalogSearch("taylor swift")
        await waitUntil { !media.searchResults.isEmpty }
        
        XCTAssertFalse(media.searchResults.isEmpty, "Typing in the playlist search must query YouTube Music")
        let groups = media.groupedSearchResults
        XCTAssertTrue(groups.contains(where: { $0.kind == .artist }))
        XCTAssertTrue(groups.contains(where: { $0.kind == .song }))
        
        let artist = try XCTUnwrap(media.searchResults.first(where: { $0.kind == .artist }))
        media.openSearchResult(artist)
        XCTAssertEqual(media.selectedPlaylist?.kind, .artist)
        await waitUntil { !media.isLoadingTracks }
        XCTAssertEqual(media.selectedPlaylist?.tracks.count, 5, "Opening an artist must list their songs (previously empty)")
        XCTAssertNil(media.tracksError)
        
        // Songs from search play directly
        let song = try XCTUnwrap(media.searchResults.first(where: { $0.kind == .song }))
        media.backToPlaylists()
        media.openSearchResult(song)
        XCTAssertEqual(media.trackTitle, song.title)
        XCTAssertTrue(media.isPlaying)
        
        // Clearing search resets results
        media.clearPlaylistSearch()
        XCTAssertTrue(media.searchResults.isEmpty)
    }
    
    @MainActor
    func testLibraryRefreshPopulatesPlaylistsAndSurfacesErrors() async throws {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        engine.innerTubeOverride = { _, _ in throw YouTubeMusicEngine.InnerTubeError.http(401) }
        engine.parseIncomingPayload(["isSignedIn": true])
        await engine.refreshLibraryPlaylists()
        XCTAssertNotNil(engine.libraryError, "Failures must be reported, not silently swallowed")
        await waitUntil { media.libraryError != nil }
        XCTAssertNotNil(media.libraryError)
        
        engine.innerTubeOverride = { _, _ in
            [
                "contents": [
                    "singleColumnBrowseResultsRenderer": [
                        "tabs": [
                            [
                                "tabRenderer": [
                                    "content": [
                                        "sectionListRenderer": [
                                            "contents": [
                                                [
                                                    "gridRenderer": [
                                                        "items": [
                                                            [
                                                                "musicTwoRowItemRenderer": [
                                                                    "title": ["runs": [["text": "Road Trip"]]],
                                                                    "subtitle": ["runs": [["text": "Playlist"]]],
                                                                    "navigationEndpoint": ["browseEndpoint": ["browseId": "VLPLroad"]]
                                                                ]
                                                            ]
                                                        ]
                                                    ]
                                                ]
                                            ]
                                        ]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        }
        await engine.refreshLibraryPlaylists()
        XCTAssertNil(engine.libraryError)
        XCTAssertTrue(media.playlists.contains(where: { $0.id == "PLroad" }), "Library playlists must reach the UI model")
        XCTAssertTrue(media.playlists.contains(where: { $0.id == "LM" }), "Liked Music must always be offered when signed in")
    }
    
    // MARK: Adjacent Duplicate Removal
    
    func testAdjacentDuplicateTracksAreRemoved() {
        let t1 = YTMPlaylistItem(id: "1", title: "Song A", artist: "Artist 1", videoId: "v1")
        let t2 = YTMPlaylistItem(id: "2", title: "Song A", artist: "Artist 1", videoId: "v2") // Adjacent duplicate by title + artist
        let t3 = YTMPlaylistItem(id: "3", title: "Song B", artist: "Artist 2", videoId: "v3")
        let t4 = YTMPlaylistItem(id: "4", title: "Song B", artist: "Artist 2", videoId: "v3") // Adjacent duplicate by videoId
        let t5 = YTMPlaylistItem(id: "5", title: "Song A", artist: "Artist 1", videoId: "v1") // Non-adjacent duplicate (must be preserved)
        
        let tracks = [t1, t2, t3, t4, t5]
        let deduplicated = YTMPlaylistItem.deduplicateAdjacent(tracks)
        
        XCTAssertEqual(deduplicated.count, 3)
        XCTAssertEqual(deduplicated.map { $0.id }, ["1", "3", "5"])
        XCTAssertEqual(deduplicated[0].title, "Song A")
        XCTAssertEqual(deduplicated[1].title, "Song B")
        XCTAssertEqual(deduplicated[2].title, "Song A")
    }
    
    @MainActor
    func testFilteredSongsRemovesAdjacentDuplicates() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        let t1 = YTMPlaylistItem(id: "1", title: "Do Anh Si", artist: "Han Sara", videoId: "v1")
        let t2 = YTMPlaylistItem(id: "2", title: "Do Anh Si", artist: "Han Sara", videoId: "v2")
        let t3 = YTMPlaylistItem(id: "3", title: "She Never Cries", artist: "Son K", videoId: "v3")
        let t4 = YTMPlaylistItem(id: "4", title: "She Never Cries", artist: "Son K", videoId: "v4")
        
        let playlist = YTMPlaylist(id: "test_pl", title: "My Mix", tracks: [t1, t2, t3, t4])
        
        let songs = media.filteredSongs(for: playlist)
        XCTAssertEqual(songs.count, 2)
        XCTAssertEqual(songs.map { $0.title }, ["Do Anh Si", "She Never Cries"])
    }
    
    // MARK: Song Picking and Exact Track Playback Verification
    
    @MainActor
    func testPlayingPickedSongFromPlaylistPlaysExactTargetSong() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        let t1 = YTMPlaylistItem(id: "set_1", title: "First Song", artist: "Artist 1", videoId: "VID_FIRST")
        let t2 = YTMPlaylistItem(id: "set_2", title: "Target Song", artist: "Artist 2", videoId: "VID_TARGET")
        let t3 = YTMPlaylistItem(id: "set_3", title: "Third Song", artist: "Artist 3", videoId: "VID_THIRD")
        
        let playlist = YTMPlaylist(id: "PLcustom_123", title: "Favorites", tracks: [t1, t2, t3], browseId: "VLPLcustom_123")
        media.selectPlaylist(playlist)
        
        // Pick song 2 ("Target Song")
        media.playSongInSelectedPlaylist(t2)
        
        XCTAssertEqual(media.trackTitle, "Target Song")
        XCTAssertEqual(media.artistName, "Artist 2")
        XCTAssertTrue(media.isPlaying)
        XCTAssertEqual(media.selectedPlaylist?.tracks[1].isPlaying, true)
        XCTAssertEqual(media.selectedPlaylist?.tracks[0].isPlaying, false)
        XCTAssertEqual(media.selectedPlaylist?.tracks[2].isPlaying, false)
    }
    
    @MainActor
    func testPlayingQueueTrackUsesExactQueueIdentifier() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        let q1 = YTMPlaylistItem(id: "0", title: "Queue Song 0", artist: "Artist 0")
        let q2 = YTMPlaylistItem(id: "3", title: "Queue Song 3", artist: "Artist 3") // After deduplication, index 3 is kept
        
        let queuePlaylist = YTMPlaylist(id: "pl_queue", title: "Now Playing Queue", tracks: [q1, q2], kind: .queue)
        media.selectPlaylist(queuePlaylist)
        
        media.playSongInSelectedPlaylist(q2)
        
        XCTAssertEqual(media.trackTitle, "Queue Song 3")
        XCTAssertEqual(media.artistName, "Artist 3")
        XCTAssertTrue(media.isPlaying)
    }
    
    // MARK: - Global Deduplication, Single Active Song Guarantee & Metadata Harmonization
    
    func testGlobalDeduplicationRemovesNonAdjacentDuplicates() {
        let t1 = YTMPlaylistItem(id: "1", title: "Blinding Lights", artist: "The Weeknd", videoId: "4NRXx6U8ABQ")
        let t2 = YTMPlaylistItem(id: "2", title: "Save Your Tears", artist: "The Weeknd", videoId: "XXYlFuWEuKI")
        let t3 = YTMPlaylistItem(id: "3", title: "Starboy", artist: "The Weeknd", videoId: "34Na4j8AVgA")
        // Non-adjacent duplicate of t1
        let t4 = YTMPlaylistItem(id: "4", title: "Blinding Lights", artist: "The Weeknd", videoId: "4NRXx6U8ABQ")
        // Duplicate with missing artist
        let t5 = YTMPlaylistItem(id: "5", title: "Save Your Tears", artist: "", videoId: "XXYlFuWEuKI")
        
        let tracks = [t1, t2, t3, t4, t5]
        let deduplicated = YTMPlaylistItem.deduplicate(tracks)
        
        XCTAssertEqual(deduplicated.count, 3, "Global deduplication must collapse non-adjacent duplicates and duplicate IDs")
        XCTAssertEqual(deduplicated.map { $0.title }, ["Blinding Lights", "Save Your Tears", "Starboy"])
    }
    
    func testGlobalDeduplicationEnrichesMetadata() {
        let t1 = YTMPlaylistItem(id: "1", title: "As It Was", artist: "", duration: "", videoId: "H5v3kku4y6Q", thumbnailURL: nil)
        let t2 = YTMPlaylistItem(id: "2", title: "As It Was", artist: "Harry Styles", duration: "2:47", videoId: "H5v3kku4y6Q", thumbnailURL: "https://example.com/thumb.jpg")
        
        let deduplicated = YTMPlaylistItem.deduplicate([t1, t2])
        XCTAssertEqual(deduplicated.count, 1)
        XCTAssertEqual(deduplicated[0].artist, "Harry Styles")
        XCTAssertEqual(deduplicated[0].duration, "2:47")
        XCTAssertEqual(deduplicated[0].thumbnailURL, "https://example.com/thumb.jpg")
    }
    
    @MainActor
    func testOnlyOneSongCanBeCurrentInPlaylist() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        // Simulating the bug condition: multiple tracks had isPlaying = true
        let t1 = YTMPlaylistItem(id: "1", title: "Song One", artist: "Artist A", isPlaying: true)
        let t2 = YTMPlaylistItem(id: "2", title: "Song Two", artist: "Artist B", isPlaying: true)
        let t3 = YTMPlaylistItem(id: "3", title: "Song Three", artist: "Artist C", isPlaying: true)
        let tracks = [t1, t2, t3]
        
        media.trackTitle = "Song Two"
        media.artistName = "Artist B"
        media.isPlaying = true
        
        // Count how many songs are considered current by the UI
        let currentSongs = tracks.filter { media.isSongCurrent($0, in: tracks) }
        
        XCTAssertEqual(currentSongs.count, 1, "Strictly ONE song must be current at a time, never multiple")
        XCTAssertEqual(currentSongs.first?.id, "2")
        XCTAssertEqual(currentSongs.first?.title, "Song Two")
        
        XCTAssertFalse(media.isSongCurrent(t1, in: tracks))
        XCTAssertTrue(media.isSongCurrent(t2, in: tracks))
        XCTAssertFalse(media.isSongCurrent(t3, in: tracks))
    }
    
    @MainActor
    func testNoSongsAreCurrentWhenPlaybackIsStopped() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        let t1 = YTMPlaylistItem(id: "1", title: "Song One", artist: "Artist A", isPlaying: true)
        let tracks = [t1]
        
        media.trackTitle = "Song One"
        media.artistName = "Artist A"
        media.isPlaying = false // Paused / Stopped
        
        XCTAssertFalse(media.isSongCurrent(t1, in: tracks), "When not playing, isSongCurrent must be false")
        XCTAssertTrue(media.isSongPausedCurrent(t1, in: tracks), "When paused, isSongPausedCurrent can be true for the active song")
    }
    
    func testTitleNormalizationStripsClutter() {
        XCTAssertEqual(
            MediaControllerModel.normalizeTitle("Blinding Lights (Official Music Video)"),
            "blinding lights"
        )
        XCTAssertEqual(
            MediaControllerModel.normalizeTitle("Flowers [Official Video]"),
            "flowers"
        )
        XCTAssertEqual(
            MediaControllerModel.normalizeTitle("Anti-Hero (Official Lyric Video)"),
            "anti-hero"
        )
        XCTAssertEqual(
            MediaControllerModel.normalizeTitle("Stay [Audio]"),
            "stay"
        )
        XCTAssertEqual(
            MediaControllerModel.normalizeTitle("Levitating (Official Audio)"),
            "levitating"
        )
    }
    
    @MainActor
    func testLeftAndRightSideMetadataHarmonization() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        let playlistTrack = YTMPlaylistItem(
            id: "pl_1",
            title: "Blinding Lights",
            artist: "The Weeknd",
            videoId: "4NRXx6U8ABQ"
        )
        let playlist = YTMPlaylist(
            id: "test_pl",
            title: "Top Hits",
            tracks: [playlistTrack]
        )
        media.selectPlaylist(playlist)
        
        // Web player emits raw title with clutter: "Blinding Lights (Official Music Video)"
        media.trackTitle = "Blinding Lights (Official Music Video)"
        media.artistName = "The Weeknd"
        media.isPlaying = true
        
        // Run sync
        media.syncPlayingTrackWithPlaylists()
        
        // Verify left side has been harmonized with the clean playlist track
        XCTAssertEqual(media.trackTitle, "Blinding Lights", "Left deck title must be harmonized with clean playlist title")
        XCTAssertEqual(media.artistName, "The Weeknd")
        
        // Verify right side track is marked playing
        let currentInPlaylist = media.selectedPlaylist?.tracks.filter { $0.isPlaying }
        XCTAssertEqual(currentInPlaylist?.count, 1)
        XCTAssertEqual(currentInPlaylist?.first?.id, "pl_1")
    }
    
    @MainActor
    func testAutoAdvanceUpdatesActiveTrackCleanly() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        let song1 = YTMPlaylistItem(id: "s1", title: "First Track", artist: "Artist A", videoId: "v1")
        let song2 = YTMPlaylistItem(id: "s2", title: "Second Track", artist: "Artist B", videoId: "v2")
        let playlist = YTMPlaylist(id: "pl_album", title: "Album", tracks: [song1, song2])
        media.selectPlaylist(playlist)
        
        // Start on song 1
        media.playSongInSelectedPlaylist(song1)
        XCTAssertTrue(media.isSongCurrent(song1, in: media.selectedPlaylist!.tracks))
        XCTAssertFalse(media.isSongCurrent(song2, in: media.selectedPlaylist!.tracks))
        
        // Player auto-advances to song 2 (simulating engine track update)
        let advanceData = YTMTrackData(
            title: "Second Track",
            artist: "Artist B",
            albumArtURL: nil,
            isPlaying: true,
            currentTime: 2.0,
            duration: 180.0,
            volume: 1.0,
            isMuted: false,
            isLiked: false,
            isDisliked: false,
            isShuffle: false,
            repeatMode: .off,
            queue: [song1, song2],
            playlists: [],
            isSignedIn: true
        )
        engine.trackData = advanceData
        
        // Both left and right sides reflect song 2, song 1 is deactivated
        XCTAssertEqual(media.trackTitle, "Second Track")
        XCTAssertFalse(media.isSongCurrent(song1, in: media.selectedPlaylist!.tracks))
        XCTAssertTrue(media.isSongCurrent(song2, in: media.selectedPlaylist!.tracks))
        
        let playingTracks = media.selectedPlaylist!.tracks.filter { $0.isPlaying }
        XCTAssertEqual(playingTracks.count, 1, "Exactly one track must be playing after auto-advance")
        XCTAssertEqual(playingTracks.first?.id, "s2")
    }
    
    // MARK: - Seamless Background Playback & Decoupling Tests (Zero Ghost Windows)
    
    @MainActor
    func testZeroGhostWindowsOnLaunchAndHostingAttachment() {
        let engine = YouTubeMusicEngine()
        
        // 1. Verify that on initialization, NO window is created or ordered back in the background
        XCTAssertFalse(engine.isPlayerWindowVisible)
        
        // 2. Verify attachToHostingView attaches webView directly into Morph's UI view hierarchy
        let mockContainer = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let hostWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: [.borderless], backing: .buffered, defer: false)
        hostWindow.contentView = mockContainer
        
        engine.attachToHostingView(mockContainer)
        XCTAssertEqual(engine.webView.superview, mockContainer)
        XCTAssertEqual(engine.webView.window, hostWindow, "WKWebView must share Morph's active window hierarchy without creating separate ghost windows")
    }
    
    @MainActor
    func testPlayerWindowLifecycleAndBackgroundAudioPreservation() {
        let engine = YouTubeMusicEngine()
        let win = engine.ensurePlayerWindow()
        
        // Window is standard opacity when explicitly created, never an invisible 0.0 alpha ghost window
        XCTAssertEqual(win.alphaValue, 1.0)
        XCTAssertFalse(win.ignoresMouseEvents)
        XCTAssertFalse(engine.isPlayerWindowVisible)
        
        // Simulating window close intercept
        guard let delegate = win.delegate else {
            XCTFail("Player window must have a delegate")
            return
        }
        let shouldClose = delegate.windowShouldClose?(win) ?? true
        XCTAssertFalse(shouldClose, "windowShouldClose intercepts close to cleanly orderOut and restore background hosting")
        XCTAssertFalse(engine.isPlayerWindowVisible)
    }
    
    @MainActor
    func testBrowserSignInFlowAndSessionWiring() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        XCTAssertFalse(media.isWaitingForBrowserSignIn)
        XCTAssertNil(media.browserAuthStatusMessage)
        
        // User clicks Sign In
        media.openSignIn()
        XCTAssertTrue(media.isWaitingForBrowserSignIn)
        XCTAssertNotNil(media.browserAuthStatusMessage)
        XCTAssertTrue(media.browserAuthStatusMessage?.contains("browser") == true)
        
        // User triggers session sync
        media.syncSessionFromBrowser()
        XCTAssertNotNil(media.browserAuthStatusMessage)
        
        // Browser tab can now be closed, and direct engine remains active and playable
        media.isDirectEngineConnected = true
        media.play()
        XCTAssertTrue(media.isPlaying)
    }
    
    @MainActor
    func testMediaControllerPlaybackDirectEngineControl() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        // Mark direct engine connected
        media.isDirectEngineConnected = true
        
        media.play()
        XCTAssertTrue(media.isPlaying)
        
        media.pause()
        XCTAssertFalse(media.isPlaying)
        
        media.togglePlay()
        XCTAssertTrue(media.isPlaying)
        
        media.stop()
        XCTAssertFalse(media.isPlaying)
        XCTAssertEqual(media.currentTime, 0)
    }
    
    @MainActor
    func testEngineDirectPlaybackCommandsExecution() {
        let engine = YouTubeMusicEngine()
        
        // Verify all direct control methods execute without error
        engine.play()
        engine.pause()
        engine.stop()
        engine.nextTrack()
        engine.previousTrack()
        engine.toggleShuffle()
        engine.toggleRepeat()
        engine.toggleLike()
        engine.toggleDislike()
        engine.playQueueIndex(0)
        engine.play(videoId: "dQw4w9WgXcQ", listId: "VLPLtest")
        
        XCTAssertNotNil(engine.webView)
    }
    
    @MainActor
    func testAllLeftDeckPlayerButtonsAndControls() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        media.isDirectEngineConnected = true
        
        // 1. Play / Pause Button
        media.isPlaying = false
        media.togglePlay()
        XCTAssertTrue(media.isPlaying)
        media.togglePlay()
        XCTAssertFalse(media.isPlaying)
        
        // 2. Shuffle Button
        XCTAssertFalse(media.isShuffle)
        media.toggleShuffle()
        XCTAssertTrue(media.isShuffle)
        media.toggleShuffle()
        XCTAssertFalse(media.isShuffle)
        
        // 3. Repeat Mode Button (cycles off -> all -> one -> off)
        XCTAssertEqual(media.repeatMode, .off)
        media.toggleRepeat()
        XCTAssertEqual(media.repeatMode, .all)
        media.toggleRepeat()
        XCTAssertEqual(media.repeatMode, .one)
        media.toggleRepeat()
        XCTAssertEqual(media.repeatMode, .off)
        
        // 4. Like & Dislike Buttons (mutually exclusive)
        XCTAssertFalse(media.isLiked)
        XCTAssertFalse(media.isDisliked)
        
        media.toggleLike()
        XCTAssertTrue(media.isLiked)
        XCTAssertFalse(media.isDisliked)
        
        // Disliking while liked should clear liked
        media.toggleDislike()
        XCTAssertFalse(media.isLiked)
        XCTAssertTrue(media.isDisliked)
        
        // Disliking again toggles off
        media.toggleDislike()
        XCTAssertFalse(media.isLiked)
        XCTAssertFalse(media.isDisliked)
        
        // 5. Stop Button
        media.isPlaying = true
        media.currentTime = 45.0
        media.stop()
        XCTAssertFalse(media.isPlaying)
        XCTAssertEqual(media.currentTime, 0.0)
        
        // 6. Mute Toggle & Volume Slider
        media.volume = 0.8
        media.isMuted = false
        media.toggleMute()
        XCTAssertTrue(media.isMuted)
        XCTAssertTrue(media.showVolumeHUD)
        
        // Setting positive volume automatically unmutes
        media.setVolume(0.5)
        XCTAssertFalse(media.isMuted)
        XCTAssertEqual(media.volume, 0.5, accuracy: 0.01)
        
        // Clamping bounds
        media.setVolume(1.5)
        XCTAssertEqual(media.volume, 1.0)
        media.setVolume(-0.5)
        XCTAssertEqual(media.volume, 0.0)
        
        // 7. Timeline Scrubber Seek
        media.duration = 200.0
        media.seek(to: 0.25)
        XCTAssertEqual(media.currentTime, 50.0, accuracy: 0.01)
        XCTAssertEqual(media.progress, 0.25, accuracy: 0.01)
        
        media.seek(to: 1.5) // Clamps to 1.0
        XCTAssertEqual(media.currentTime, 200.0, accuracy: 0.01)
        
        // 8. Next Track & Previous Track in Active Playlist
        let item1 = YTMPlaylistItem(id: "1", title: "Song One", artist: "Artist", isPlaying: true, videoId: "v1")
        let item2 = YTMPlaylistItem(id: "2", title: "Song Two", artist: "Artist", isPlaying: false, videoId: "v2")
        let item3 = YTMPlaylistItem(id: "3", title: "Song Three", artist: "Artist", isPlaying: false, videoId: "v3")
        let testPl = YTMPlaylist(id: "pl_test", title: "Test Playlist", subtitle: "Test", thumbnailURL: nil, trackCount: 3, tracks: [item1, item2, item3], browseId: nil)
        
        media.selectPlaylist(testPl)
        XCTAssertEqual(media.selectedPlaylist?.tracks[0].isPlaying, true)
        
        // Skip Next Track
        media.nextTrack()
        XCTAssertEqual(media.trackTitle, "Song Two")
        XCTAssertEqual(media.selectedPlaylist?.tracks[1].isPlaying, true)
        XCTAssertEqual(media.selectedPlaylist?.tracks[0].isPlaying, false)
        
        // Skip Next Track again
        media.nextTrack()
        XCTAssertEqual(media.trackTitle, "Song Three")
        XCTAssertEqual(media.selectedPlaylist?.tracks[2].isPlaying, true)
        
        // Previous Track when song has played > 3 seconds restarts the current song
        media.currentTime = 10.0
        media.previousTrack()
        XCTAssertEqual(media.currentTime, 0.0)
        XCTAssertEqual(media.trackTitle, "Song Three")
        
        // Previous Track when song is at <= 3 seconds skips to previous song
        media.currentTime = 1.0
        media.previousTrack()
        XCTAssertEqual(media.trackTitle, "Song Two")
        XCTAssertEqual(media.selectedPlaylist?.tracks[1].isPlaying, true)
        
        // 9. Web View Button (openPlayerWindow)
        media.openPlayerWindow()
        // Must execute cleanly without error
    }
}

