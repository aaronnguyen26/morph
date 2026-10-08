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
}
