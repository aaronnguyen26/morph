import XCTest
@testable import morph

@MainActor
final class YTMLibraryPersistenceTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            YouTubeMusicEngine.shared.userPlaylists = []
            YouTubeMusicEngine.shared.innerTubeOverride = nil
        }
        YTMUserOfflineStore.shared.clear()
        YTMUserOfflineStore.shared.clear(for: "user1@gmail.com")
        YTMUserOfflineStore.shared.clear(for: "user2@gmail.com")
    }
    
    override func tearDown() {
        MainActor.assumeIsolated {
            YouTubeMusicEngine.shared.userPlaylists = []
            YouTubeMusicEngine.shared.innerTubeOverride = nil
        }
        YTMUserOfflineStore.shared.clear()
        YTMUserOfflineStore.shared.clear(for: "user1@gmail.com")
        YTMUserOfflineStore.shared.clear(for: "user2@gmail.com")
        super.tearDown()
    }
    
    override func setUp() async throws {
        try await super.setUp()
        YouTubeMusicEngine.shared.userPlaylists = []
        YouTubeMusicEngine.shared.innerTubeOverride = nil
        YTMUserOfflineStore.shared.clear()
        YTMUserOfflineStore.shared.clear(for: "user1@gmail.com")
        YTMUserOfflineStore.shared.clear(for: "user2@gmail.com")
    }
    
    override func tearDown() async throws {
        YouTubeMusicEngine.shared.userPlaylists = []
        YouTubeMusicEngine.shared.innerTubeOverride = nil
        YTMUserOfflineStore.shared.clear()
        YTMUserOfflineStore.shared.clear(for: "user1@gmail.com")
        YTMUserOfflineStore.shared.clear(for: "user2@gmail.com")
        try await super.tearDown()
    }
    
    // MARK: - 1. YTMUserOfflineStore Core Playlist Storage & Retrieval
    
    func testOfflineStoreSavesAndRetrievesUserPlaylists() {
        let store = YTMUserOfflineStore.shared
        
        let samplePlaylists = [
            YTMPlaylist(
                id: "PL_lofi_beats",
                title: "Lofi Coding & Study",
                subtitle: "Playlist • 50 songs",
                thumbnailURL: "https://lh3.googleusercontent.com/lofi.jpg",
                trackCount: 2,
                tracks: [
                    YTMPlaylistItem(id: "trk_1", title: "Midnight Chill", artist: "Kowloon", duration: "2:45", videoId: "vid1", thumbnailURL: "https://lh3.googleusercontent.com/trk1.jpg"),
                    YTMPlaylistItem(id: "trk_2", title: "Morning Rain", artist: "Coffee Shop", duration: "3:10", videoId: "vid2", thumbnailURL: "https://lh3.googleusercontent.com/trk2.jpg")
                ],
                browseId: "VLPL_lofi_beats",
                kind: .playlist,
                playbackListId: "PL_lofi_beats"
            ),
            YTMPlaylist(
                id: "LM",
                title: "Liked Music",
                subtitle: "Auto playlist",
                thumbnailURL: "https://lh3.googleusercontent.com/liked.jpg",
                trackCount: 1,
                tracks: [
                    YTMPlaylistItem(id: "trk_3", title: "Starboy", artist: "The Weeknd", duration: "3:50", videoId: "vid3", thumbnailURL: "https://lh3.googleusercontent.com/trk3.jpg")
                ],
                browseId: "VLLM",
                kind: .playlist,
                playbackListId: "LM"
            )
        ]
        
        store.savePlaylists(samplePlaylists)
        
        let retrieved = store.getStoredPlaylists()
        XCTAssertEqual(retrieved.count, 2)
        XCTAssertEqual(retrieved[0].id, "PL_lofi_beats")
        XCTAssertEqual(retrieved[0].title, "Lofi Coding & Study")
        XCTAssertEqual(retrieved[0].tracks.count, 2)
        XCTAssertEqual(retrieved[0].tracks[0].title, "Midnight Chill")
        XCTAssertEqual(retrieved[1].id, "LM")
        XCTAssertEqual(retrieved[1].title, "Liked Music")
        XCTAssertEqual(retrieved[1].tracks.count, 1)
    }
    
    // MARK: - 2. User Isolation / Email-Scoped Storage
    
    func testOfflineStoreIsolatesPlaylistsByUserEmail() {
        let store = YTMUserOfflineStore.shared
        
        let user1Playlists = [
            YTMPlaylist(id: "PL_user1", title: "User 1 Heavy Metal", subtitle: "Playlist", browseId: "VLPL_user1", kind: .playlist)
        ]
        let user2Playlists = [
            YTMPlaylist(id: "PL_user2", title: "User 2 Acoustic Chill", subtitle: "Playlist", browseId: "VLPL_user2", kind: .playlist)
        ]
        
        store.savePlaylists(user1Playlists, for: "user1@gmail.com")
        store.savePlaylists(user2Playlists, for: "user2@gmail.com")
        
        let retrievedUser1 = store.getStoredPlaylists(for: "user1@gmail.com")
        let retrievedUser2 = store.getStoredPlaylists(for: "user2@gmail.com")
        
        XCTAssertEqual(retrievedUser1.count, 1)
        XCTAssertEqual(retrievedUser1.first?.title, "User 1 Heavy Metal")
        
        XCTAssertEqual(retrievedUser2.count, 1)
        XCTAssertEqual(retrievedUser2.first?.title, "User 2 Acoustic Chill")
    }
    
    // MARK: - 3. Engine refreshLibraryPlaylists Automatically Stores Fetched Playlists
    
    func testEngineRefreshLibraryPlaylistsStoresPlaylistsInOfflineStore() async throws {
        let engine = YouTubeMusicEngine()
        engine.userEmail = "user1@gmail.com"
        
        let fakeBrowseResponse: [String: Any] = [
            "contents": [
                "singleColumnBrowseResultsRenderer": [
                    "tabs": [[
                        "tabRenderer": [
                            "content": [
                                "sectionListRenderer": [
                                    "contents": [[
                                        "gridRenderer": [
                                            "items": [
                                                [
                                                    "musicTwoRowItemRenderer": [
                                                        "title": ["runs": [["text": "Synthwave 1984"]]],
                                                        "subtitle": ["runs": [["text": "Playlist • 30 songs"]]],
                                                        "navigationEndpoint": [
                                                            "browseEndpoint": ["browseId": "VLPL_synth_1984"]
                                                        ],
                                                        "thumbnailRenderer": [
                                                            "musicThumbnailRenderer": [
                                                                "thumbnail": ["thumbnails": [["url": "https://img.ytm/synth.jpg"]]]
                                                            ]
                                                        ]
                                                    ]
                                                ]
                                            ]
                                        ]
                                    ]]
                                ]
                            ]
                        ]
                    ]]
                ]
            ]
        ]
        
        engine.innerTubeOverride = { endpoint, body in
            if endpoint == "browse" && (body["browseId"] as? String) == "FEmusic_liked_playlists" {
                return fakeBrowseResponse
            }
            return [:]
        }
        
        await engine.refreshLibraryPlaylists()
        
        XCTAssertFalse(engine.userPlaylists.isEmpty, "Engine should parse fetched playlists")
        XCTAssertTrue(engine.userPlaylists.contains(where: { $0.id == "PL_synth_1984" }))
        
        // Verify persistent store received and stored the playlists
        let stored = YTMUserOfflineStore.shared.getStoredPlaylists(for: "user1@gmail.com")
        XCTAssertFalse(stored.isEmpty, "Offline store must store playlists fetched from the music provider")
        XCTAssertTrue(stored.contains(where: { $0.id == "PL_synth_1984" && $0.title == "Synthwave 1984" }))
    }
    
    // MARK: - 4. MediaControllerModel Hydrates From Stored Playlists on Init
    
    func testMediaControllerModelHydratesFromStoredPlaylistsOnLaunch() {
        let store = YTMUserOfflineStore.shared
        store.clear()
        let existingPlaylists = [
            YTMPlaylist(id: "PL_saved_1", title: "Saved Jazz Classics", subtitle: "Playlist • 15 tracks", browseId: "VLPL_saved_1", kind: .playlist),
            YTMPlaylist(id: "PL_saved_2", title: "Saved Ambient Echoes", subtitle: "Playlist • 25 tracks", browseId: "VLPL_saved_2", kind: .playlist)
        ]
        store.savePlaylists(existingPlaylists)
        
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: MockSystemAudioService(), networkMonitor: NetworkMonitor.shared)
        
        // Immediately merge or hydrate stored playlists
        media.mergePlaylists(store.getStoredPlaylists())
        
        XCTAssertEqual(media.playlists.count, 2)
        XCTAssertEqual(media.playlists[0].title, "Saved Jazz Classics")
        XCTAssertEqual(media.playlists[1].title, "Saved Ambient Echoes")
    }
    
    // MARK: - 5. Library Section of Dynamic Island / Notch Populates Stored Playlists
    
    func testNotchModelLibrarySectionShowcasesAndStoresPlaylists() {
        let store = YTMUserOfflineStore.shared
        let savedPlaylists = [
            YTMPlaylist(
                id: "PL_deep_house",
                title: "Deep House Ibiza",
                subtitle: "Playlist",
                thumbnailURL: "https://img.ytm/ibiza.jpg",
                trackCount: 2,
                tracks: [
                    YTMPlaylistItem(id: "dh_1", title: "Sunset Bliss", artist: "Ibiza Crew", duration: "4:12", videoId: "v_ibz1"),
                    YTMPlaylistItem(id: "dh_2", title: "Ocean Breeze", artist: "Deep Vibe", duration: "5:00", videoId: "v_ibz2")
                ],
                browseId: "VLPL_deep_house",
                kind: .playlist
            )
        ]
        store.savePlaylists(savedPlaylists)
        
        let notchModel = NotchModel()
        notchModel.media.playlists = [] // Simulate unhydrated in-memory state
        
        // Transition to Library subtab
        notchModel.setGlassMusicSubtab(.library)
        
        XCTAssertEqual(notchModel.glassMusicSubtab, .library)
        XCTAssertFalse(notchModel.media.playlists.isEmpty, "Switching to library section must hydrate playlists from stored offline store")
        XCTAssertEqual(notchModel.media.playlists.first?.title, "Deep House Ibiza")
        
        // Verify glassAllLibraryTracks incorporates the songs from the user's stored playlist
        let allTracks = notchModel.glassAllLibraryTracks
        XCTAssertTrue(allTracks.contains(where: { $0.title == "Sunset Bliss" }))
        XCTAssertTrue(allTracks.contains(where: { $0.title == "Ocean Breeze" }))
    }
    
    // MARK: - 6. DOM Scraper Merges and Stores Playlists into Offline Store
    
    func testDOMScrapedPlaylistsAreStoredPermanently() {
        let store = YTMUserOfflineStore.shared
        let engine = YouTubeMusicEngine()
        engine.userEmail = "user1@gmail.com"
        
        engine.parseIncomingPayload([
            "title": "Starboy",
            "artist": "The Weeknd",
            "duration": 230.0,
            "isPlaying": true,
            "playlists": [
                [
                    "title": "Gym Motivation 2026",
                    "browseId": "VLPL_gym_2026",
                    "thumbnailURL": "https://img.ytm/gym.jpg"
                ]
            ]
        ])
        
        XCTAssertTrue(engine.userPlaylists.contains(where: { $0.id == "PL_gym_2026" }))
        
        let stored = store.getStoredPlaylists(for: "user1@gmail.com")
        XCTAssertTrue(stored.contains(where: { $0.id == "PL_gym_2026" && $0.title == "Gym Motivation 2026" }),
                      "Playlists scraped from the signed-in music provider web page must be stored in YTMUserOfflineStore")
    }
    
    // MARK: - 7. Track Parser Extracts simpleText and Fallback Video IDs
    
    func testTrackParserExtractsSimpleTextAndFallbackVideoId() {
        let rawItem: [String: Any] = [
            "musicResponsiveListItemFlexColumnRenderer": [
                "text": ["simpleText": "Resonance"]
            ]
        ]
        let itemDoc: [String: Any] = [
            "flexColumns": [
                rawItem,
                [
                    "musicResponsiveListItemFlexColumnRenderer": [
                        "text": ["simpleText": "HOME • Chillwave • 3:32"]
                    ]
                ]
            ],
            "playlistItemData": [
                "videoId": "8GW6sLrK40k",
                "playlistSetVideoId": "set_res_001"
            ]
        ]
        
        let track = YTMParser.track(from: itemDoc, index: 0)
        XCTAssertNotNil(track)
        XCTAssertEqual(track?.title, "Resonance")
        XCTAssertEqual(track?.artist, "HOME")
        XCTAssertEqual(track?.duration, "3:32")
        XCTAssertEqual(track?.videoId, "8GW6sLrK40k")
        XCTAssertEqual(track?.id, "set_res_001")
        
        // Test track page fallback when shelves are omitted
        let pageDoc: [String: Any] = [
            "contents": [
                "musicResponsiveListItemRenderer": itemDoc
            ]
        ]
        let trackPage = YTMParser.parseTrackPage(pageDoc)
        XCTAssertEqual(trackPage.tracks.count, 1)
        XCTAssertEqual(trackPage.tracks.first?.title, "Resonance")
    }
    
    // MARK: - 8. Playlist Selection Loads Real Songs into MediaControllerModel
    
    func testPlaylistSelectionLoadsTracksAndUpdatesMediaControllerModel() async {
        let store = YTMUserOfflineStore.shared
        store.clear()
        
        let engine = YouTubeMusicEngine()
        engine.innerTubeOverride = { endpoint, body in
            if endpoint == "browse" && (body["browseId"] as? String)?.contains("PL_synth") == true {
                return [
                    "musicPlaylistShelfRenderer": [
                        "contents": [
                            [
                                "musicResponsiveListItemRenderer": [
                                    "flexColumns": [
                                        [
                                            "musicResponsiveListItemFlexColumnRenderer": [
                                                "text": ["runs": [["text": "Neon Blade"]]]
                                            ]
                                        ],
                                        [
                                            "musicResponsiveListItemFlexColumnRenderer": [
                                                "text": ["runs": [["text": "MoonDeity • Phonk • 4:10"]]]
                                            ]
                                        ]
                                    ],
                                    "playlistItemData": [
                                        "videoId": "vid_neon"
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            }
            return [:]
        }
        
        let media = MediaControllerModel(engine: engine, systemAudio: MockSystemAudioService(), networkMonitor: NetworkMonitor.shared)
        let playlist = YTMPlaylist(id: "PL_synth", title: "Synth Phonk", subtitle: "Playlist", browseId: "VLPL_synth", kind: .playlist)
        
        media.selectPlaylist(playlist)
        XCTAssertEqual(media.selectedPlaylist?.id, "PL_synth")
        
        // Await the asynchronous track loading task
        for _ in 0..<30 {
            if !(media.selectedPlaylist?.tracks.isEmpty ?? true) { break }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        
        XCTAssertFalse(media.selectedPlaylist?.tracks.isEmpty ?? true, "Selected playlist must display the loaded songs")
        XCTAssertEqual(media.selectedPlaylist?.tracks.first?.title, "Neon Blade")
        XCTAssertEqual(media.selectedPlaylist?.tracks.first?.artist, "MoonDeity")
        
        // Verify tracks are saved to offline store
        let cachedTracks = store.getStoredTracks(forPlaylist: "PL_synth", email: media.userEmail)
        XCTAssertEqual(cachedTracks.count, 1)
        XCTAssertEqual(cachedTracks.first?.title, "Neon Blade")
    }
    
    // MARK: - 8. Library Section Exclusivity & Playlist Dropdown Track Sync
    
    func testLibrarySectionContainsOnlyUserPlaylistsAndExcludesIndividualSongsAndRadios() async {
        let store = YTMUserOfflineStore.shared
        store.clear()
        
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: MockSystemAudioService(), networkMonitor: NetworkMonitor.shared)
        let notchModel = NotchModel(media: media)
        
        let mixedItems = [
            YTMPlaylist(id: "PL_my_vibes", title: "My Vibes", subtitle: "Playlist", kind: .playlist),
            YTMPlaylist(id: "LM", title: "Liked Music", subtitle: "Playlist", kind: .playlist),
            YTMPlaylist(id: "RDAMVM_xyz123", title: "Song Radio: Blinding Lights", subtitle: "Radio", kind: .playlist), // single song radio - must be excluded
            YTMPlaylist(id: "MPREb_album999", title: "Starboy Album", subtitle: "Album", kind: .album), // album - must be excluded
            YTMPlaylist(id: "PL_podcast_1", title: "Daily English Conversation", subtitle: "Podcast • 10 episodes", kind: .playlist), // podcast - must be excluded
            YTMPlaylist(id: "PL_podcast_2", title: "Tech Talk Podcast", subtitle: "Show", kind: .playlist), // podcast - must be excluded
            YTMPlaylist(id: "PL_coding_mode", title: "Coding Focus", subtitle: "Playlist", kind: .playlist)
        ]
        
        media.mergePlaylists(mixedItems)
        
        // Verify userLibraryPlaylists contains only actual user playlists (no individual song radios, albums, or podcasts)
        let libraryPlaylists = media.userLibraryPlaylists
        XCTAssertEqual(libraryPlaylists.count, 3)
        XCTAssertTrue(libraryPlaylists.contains(where: { $0.id == "PL_my_vibes" }))
        XCTAssertTrue(libraryPlaylists.contains(where: { $0.id == "LM" }))
        XCTAssertTrue(libraryPlaylists.contains(where: { $0.id == "PL_coding_mode" }))
        XCTAssertFalse(libraryPlaylists.contains(where: { $0.id.contains("RD") }))
        XCTAssertFalse(libraryPlaylists.contains(where: { $0.id.contains("MPRE") }))
        XCTAssertFalse(libraryPlaylists.contains(where: { $0.id == "PL_podcast_1" }))
        XCTAssertFalse(libraryPlaylists.contains(where: { $0.id == "PL_podcast_2" }))
        
        // Populate songs in PL_my_vibes
        let song1 = YTMPlaylistItem(id: "s1", title: "First Song", artist: "Artist A", duration: "3:00", videoId: "v1")
        let song2 = YTMPlaylistItem(id: "s2", title: "Second Song", artist: "Artist B", duration: "4:00", videoId: "v2")
        store.savePlaylistTracks([song1, song2], forPlaylist: "PL_my_vibes", email: media.userEmail)
        
        // When user clicks onto and views the playlist in NotchModel
        let targetPlaylist = libraryPlaylists.first(where: { $0.id == "PL_my_vibes" })!
        notchModel.selectGlassPlaylist(targetPlaylist)
        
        // Verify glassSelectedPlaylist immediately has the dropdown tracks of every song belonging to that playlist
        XCTAssertNotNil(notchModel.glassSelectedPlaylist)
        XCTAssertEqual(notchModel.glassSelectedPlaylist?.id, "PL_my_vibes")
        XCTAssertEqual(notchModel.glassSelectedPlaylist?.tracks.count, 2, "Playlist must contain every song belonging to it")
        XCTAssertEqual(notchModel.glassSelectedPlaylist?.tracks[0].title, "First Song")
        XCTAssertEqual(notchModel.glassSelectedPlaylist?.tracks[1].title, "Second Song")
    }
    
    // MARK: - 9. Playlist Sorting & Activity Tracking
    
    func testPlaylistSortingByRecentActivityAndMostPlayedAndAlphabetical() {
        let now = Date()
        let pA = YTMPlaylist(id: "PL_A", title: "Alpha Playlist", subtitle: "Playlist", lastPlayedDate: now.addingTimeInterval(-3600), playCount: 5)
        let pB = YTMPlaylist(id: "PL_B", title: "Beta Playlist", subtitle: "Playlist", lastPlayedDate: now, playCount: 2)
        let pC = YTMPlaylist(id: "PL_C", title: "Gamma Playlist", subtitle: "Playlist", lastPlayedDate: nil, playCount: 20)
        let pD = YTMPlaylist(id: "PL_D", title: "Delta Playlist", subtitle: "Playlist", lastPlayedDate: now.addingTimeInterval(-100), playCount: 1)
        
        let list = [pA, pB, pC, pD]
        
        // 1. Sort by Recent Activity: most recent date first, then higher playCount, then title
        let sortedByRecent = YTMUserOfflineStore.sortPlaylists(list, mode: .recentActivity)
        XCTAssertEqual(sortedByRecent[0].id, "PL_B") // now
        XCTAssertEqual(sortedByRecent[1].id, "PL_D") // now - 100
        XCTAssertEqual(sortedByRecent[2].id, "PL_A") // now - 3600
        XCTAssertEqual(sortedByRecent[3].id, "PL_C") // no lastPlayedDate
        
        // 2. Sort by Most Played: highest playCount first
        let sortedByPlays = YTMUserOfflineStore.sortPlaylists(list, mode: .mostPlayed)
        XCTAssertEqual(sortedByPlays[0].id, "PL_C") // 20 plays
        XCTAssertEqual(sortedByPlays[1].id, "PL_A") // 5 plays
        XCTAssertEqual(sortedByPlays[2].id, "PL_B") // 2 plays
        XCTAssertEqual(sortedByPlays[3].id, "PL_D") // 1 play
        
        // 3. Sort Alphabetically
        let sortedAlpha = YTMUserOfflineStore.sortPlaylists(list, mode: .alphabetical)
        XCTAssertEqual(sortedAlpha.map { $0.id }, ["PL_A", "PL_B", "PL_D", "PL_C"])
    }
    
    func testPlaylistUsageRecordingUpdatesPlayCountAndLastPlayedDate() {
        let store = YTMUserOfflineStore.shared
        store.clear()
        
        let initialPl = YTMPlaylist(id: "PL_test_usage", title: "Test Usage", subtitle: "Playlist", playCount: 0)
        store.savePlaylists([initialPl])
        
        let retrieved = store.getStoredPlaylists()
        XCTAssertEqual(retrieved.first?.playCount, 0)
        XCTAssertNil(retrieved.first?.lastPlayedDate)
        
        // Record playlist usage
        store.recordPlaylistUsage(id: "PL_test_usage")
        
        let updated = store.getStoredPlaylists()
        XCTAssertEqual(updated.first?.playCount, 1)
        XCTAssertNotNil(updated.first?.lastPlayedDate)
        
        // Record again
        store.recordPlaylistUsage(id: "PL_test_usage")
        let updatedAgain = store.getStoredPlaylists()
        XCTAssertEqual(updatedAgain.first?.playCount, 2)
    }
    
    func testSubtitleTrackCountParsingInLibraryPlaylists() {
        let rawDoc: [String: Any] = [
            "musicTwoRowItemRenderer": [
                "title": ["runs": [["text": "Cyberpunk Synthetics"]]],
                "subtitle": ["runs": [["text": "Playlist • 42 songs"]]],
                "navigationEndpoint": [
                    "browseEndpoint": [
                        "browseId": "VLPL_cyberpunk_synth"
                    ]
                ],
                "thumbnailRenderer": [
                    "musicThumbnailRenderer": [
                        "thumbnail": [
                            "thumbnails": [["url": "https://lh3.googleusercontent.com/cyber.jpg"]]
                        ]
                    ]
                ]
            ]
        ]
        
        let result = YTMParser.parseLibraryPlaylists(rawDoc)
        XCTAssertEqual(result.playlists.count, 1)
        let pl = result.playlists[0]
        XCTAssertEqual(pl.id, "PL_cyberpunk_synth")
        XCTAssertEqual(pl.title, "Cyberpunk Synthetics")
        XCTAssertEqual(pl.trackCount, 42, "Track count should be parsed accurately from subtitle 'Playlist • 42 songs'")
    }
    
    // MARK: - 11. Browser Scraped Playlists Integration & Parity Verification
    
    func testBrowserScrapedPlaylistsIntegrationAndDeduplication() {
        let media = MediaControllerModel()
        media.playlists = []
        
        let scrapedPlaylists = [
            YTMPlaylist(id: "PL_ambient_space", title: "Ambient Space", subtitle: "Playlist", browseId: "VLPL_ambient_space", kind: .playlist),
            YTMPlaylist(id: "PL_synthwave_night", title: "Synthwave Night Drive", subtitle: "Playlist • 50 songs", browseId: "VLPL_synthwave_night", kind: .playlist),
            YTMPlaylist(id: "LM", title: "Liked Music", subtitle: "Auto playlist", browseId: "VLLM", kind: .playlist)
        ]
        
        media.mergePlaylists(scrapedPlaylists)
        
        XCTAssertEqual(media.userLibraryPlaylists.count, 3)
        XCTAssertTrue(media.userLibraryPlaylists.contains(where: { $0.id == "PL_ambient_space" }))
        XCTAssertTrue(media.userLibraryPlaylists.contains(where: { $0.id == "PL_synthwave_night" }))
        XCTAssertTrue(media.userLibraryPlaylists.contains(where: { $0.id == "LM" }))
        
        // Re-merging with same IDs must not create duplicates
        media.mergePlaylists(scrapedPlaylists)
        XCTAssertEqual(media.userLibraryPlaylists.count, 3)
    }
    
    // MARK: - 12. Liquid Glass Theme: No Solid White Play Buttons
    
    func testLiquidGlassThemeEliminatesSolidWhitePlayButtons() {
        let directPath = "/Users/minhnguyen/Desktop/Coding/morph/Sources/morph/MorphIslandView.swift"
        let fallbackURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/morph/MorphIslandView.swift")
        
        let fileURL = FileManager.default.fileExists(atPath: directPath) ? URL(fileURLWithPath: directPath) : fallbackURL
        
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            XCTFail("Failed to load MorphIslandView.swift for liquid glass validation at \(fileURL.path)")
            return
        }
        
        // Verify that glassCompactPlaylistGridCard does not use solid white button
        XCTAssertFalse(content.contains("Capsule().fill(Color.white)"), "No button in the island view should use Capsule().fill(Color.white)")
        
        // Verify that glassPlaylistCard does not use solid white circle play button
        XCTAssertFalse(content.contains("Circle().fill(Color.white)"), "No play button in the playlist card should use Circle().fill(Color.white)")
        
        // Verify that the Liquid Glass play buttons have glowing cyan accents
        XCTAssertTrue(content.contains("#00f0ff"), "Liquid glass play button icons must use glowing cyan accent (#00f0ff)")
    }
}
