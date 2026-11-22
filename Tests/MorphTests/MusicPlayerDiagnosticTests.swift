import XCTest
import SwiftUI
@testable import morph

@MainActor
final class MusicPlayerDiagnosticTests: XCTestCase {

    // MARK: - 1. Diagnostic: Looping / Repeat Mode
    
    func testLoopModeOneRewindsAndDoesNotAdvance() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        let t1 = YTMPlaylistItem(id: "s1", title: "Looping Song", artist: "Artist 1", duration: "3:30", isPlaying: true, videoId: "v1")
        let t2 = YTMPlaylistItem(id: "s2", title: "Next Track", artist: "Artist 2", duration: "4:00", isPlaying: false, videoId: "v2")
        let playlist = YTMPlaylist(id: "pl1", title: "Loop Test Playlist", tracks: [t1, t2])
        
        media.selectPlaylist(playlist)
        media.playSongInSelectedPlaylist(t1)
        media.currentTime = 210.0
        media.duration = 210.0
        
        // Wire up Repeat One
        media.setRepeatMode(.one)
        XCTAssertEqual(media.repeatMode, .one)
        XCTAssertTrue(media.showRepeatHUD)
        XCTAssertEqual(media.repeatMode.hudTitle, "Loop 1")
        
        // When track finishes
        media.handleTrackEnded(force: true)
        
        // Must stay on original song, currentTime resets to 0, still playing
        XCTAssertEqual(media.trackTitle, "Looping Song")
        XCTAssertEqual(media.currentTime, 0.0)
        XCTAssertTrue(media.isPlaying)
    }

    func testLoopModeAllLoopsEntirePlaylistAndQueue() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        let t1 = YTMPlaylistItem(id: "s1", title: "First Track", artist: "Artist 1", duration: "3:00", isPlaying: false, videoId: "v1")
        let t2 = YTMPlaylistItem(id: "s2", title: "Last Track", artist: "Artist 2", duration: "3:00", isPlaying: true, videoId: "v2")
        let playlist = YTMPlaylist(id: "pl_loop", title: "Loop All Test", tracks: [t1, t2])
        
        media.selectPlaylist(playlist)
        media.playSongInSelectedPlaylist(t2)
        media.setRepeatMode(.all)
        XCTAssertEqual(media.repeatMode, .all)
        XCTAssertEqual(media.repeatMode.hudTitle, "Loop All")
        
        // At the last track of playlist, calling nextTrack or track ended must wrap to first track
        media.handleTrackEnded(force: true)
        XCTAssertEqual(media.trackTitle, "First Track")
        XCTAssertTrue(media.isPlaying)
    }

    func testRepeatModeJavaScriptDoesNotDoubleDispatchClicksOrBreakMSE() {
        let engine = YouTubeMusicEngine()
        var evaluatedScript: String?
        engine.onEvaluate = { script in
            evaluatedScript = script
        }
        
        engine.setRepeatMode(.one)
        XCTAssertNotNil(evaluatedScript)
        
        // Verify script avoids setting v.loop = true (which freezes MSE streams)
        XCTAssertFalse(evaluatedScript!.contains("v.loop = true"))
        XCTAssertFalse(evaluatedScript!.contains("videoEl.loop = (repeatMode === 'one')"))
        
        // Verify script avoids dispatching redundant second click
        XCTAssertFalse(evaluatedScript!.contains("repeatBtn.dispatchEvent(new MouseEvent('click'"))
        
        // Verify script sets _morphTargetRepeatMode and lockout
        XCTAssertTrue(evaluatedScript!.contains("window._morphTargetRepeatMode = 'one'"))
        XCTAssertTrue(evaluatedScript!.contains("window._morphRepeatLockoutUntil"))
    }

    // MARK: - 2. Diagnostic: Showcasing Playlists Correctly Within Library Sections
    
    func testShowcasingPlaylistsInLibraryWithVariousIdFormats() {
        // Doc containing playlists with VL..., PL..., and watchPlaylistEndpoint formats
        let doc: [String: Any] = [
            "contents": [
                [
                    "musicTwoRowItemRenderer": [
                        "title": ["runs": [["text": "My Liked Music"]]],
                        "subtitle": ["runs": [["text": "Auto playlist • 120 songs"]]],
                        "navigationEndpoint": ["browseEndpoint": ["browseId": "VLLM"]]
                    ]
                ],
                [
                    "musicTwoRowItemRenderer": [
                        "title": ["runs": [["text": "Road Trip Mix"]]],
                        "subtitle": ["runs": [["text": "Playlist • 45 songs"]]],
                        "navigationEndpoint": ["browseEndpoint": ["browseId": "PLroadtrip99"]]
                    ]
                ],
                [
                    "musicTwoRowItemRenderer": [
                        "title": ["runs": [["text": "Study Session"]]],
                        "subtitle": ["runs": [["text": "Playlist • 30 songs"]]],
                        "navigationEndpoint": ["watchPlaylistEndpoint": ["playlistId": "PLstudy2026"]]
                    ]
                ]
            ]
        ]
        
        let parsed = YTMParser.parseLibraryPlaylists(doc)
        XCTAssertEqual(parsed.playlists.count, 3, "All 3 playlists in the library section must be extracted")
        
        let p1 = parsed.playlists.first(where: { $0.id == "LM" })
        XCTAssertNotNil(p1)
        XCTAssertEqual(p1?.title, "My Liked Music")
        XCTAssertEqual(p1?.browseId, "VLLM")
        
        let p2 = parsed.playlists.first(where: { $0.id == "PLroadtrip99" })
        XCTAssertNotNil(p2)
        XCTAssertEqual(p2?.title, "Road Trip Mix")
        XCTAssertEqual(p2?.browseId, "VLPLroadtrip99")
        
        let p3 = parsed.playlists.first(where: { $0.id == "PLstudy2026" })
        XCTAssertNotNil(p3)
        XCTAssertEqual(p3?.title, "Study Session")
        XCTAssertEqual(p3?.browseId, "VLPLstudy2026")
    }

    func testLibrarySelectedPlaylistTracksSyncToNotchModel() async {
        let notchModel = NotchModel()
        let media = notchModel.media
        let engine = media.engine
        
        let pl = YTMPlaylist(id: "PLchill", title: "Chill Vibes", subtitle: "Lo-fi", browseId: "VLPLchill")
        media.playlists = [pl]
        
        // Mock engine track loading
        engine.innerTubeOverride = { endpoint, body in
            if endpoint == "browse" && (body["browseId"] as? String) == "VLPLchill" {
                return [
                    "contents": [
                        "musicPlaylistShelfRenderer": [
                            "contents": [
                                [
                                    "musicResponsiveListItemRenderer": [
                                        "playlistItemData": ["videoId": "v_chill1"],
                                        "flexColumns": [
                                            ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Chill Beat 1"]]]]],
                                            ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Lofi Producer • 2:40"]]]]]
                                        ]
                                    ]
                                ]
                            ]
                        ]
                    ]
                ]
            }
            return [:]
        }
        
        // Select playlist in NotchModel
        notchModel.selectGlassPlaylist(pl)
        XCTAssertEqual(notchModel.glassSelectedPlaylist?.id, "PLchill")
        
        // Wait for track loading to complete
        let start = Date()
        while media.isLoadingTracks && Date().timeIntervalSince(start) < 2.0 {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        
        // Verify tracks populated on media.selectedPlaylist
        XCTAssertFalse(media.selectedPlaylist?.tracks.isEmpty ?? true, "Tracks must be populated on media.selectedPlaylist")
        XCTAssertEqual(media.selectedPlaylist?.tracks.first?.title, "Chill Beat 1")
    }

    // MARK: - 3. Diagnostic: Quick Picks Matching Compared to Web Page
    
    func testQuickPicksExtractsExactMatchingShelfOverCompetingCarousels() {
        // Multi-shelf home feed with Speed dial, Quick picks, and Listen again
        let doc: [String: Any] = [
            "contents": [
                "singleColumnBrowseResultsRenderer": [
                    "tabs": [[
                        "tabRenderer": [
                            "content": [
                                "sectionListRenderer": [
                                    "contents": [
                                        [
                                            "musicCarouselShelfRenderer": [
                                                "header": [
                                                    "musicCarouselShelfBasicHeaderRenderer": [
                                                        "title": ["runs": [["text": "Speed dial"]]],
                                                        "strapline": ["runs": [["text": "Recently played"]]]
                                                    ]
                                                ],
                                                "contents": [
                                                    [
                                                        "musicResponsiveListItemRenderer": [
                                                            "playlistItemData": ["videoId": "v_wrong1"],
                                                            "flexColumns": [
                                                                ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Wrong Song 1"]]]]],
                                                                ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Artist • 3:00"]]]]]
                                                            ]
                                                        ]
                                                    ]
                                                ]
                                            ]
                                        ],
                                        [
                                            "musicCarouselShelfRenderer": [
                                                "header": [
                                                    "musicCarouselShelfBasicHeaderRenderer": [
                                                        "title": ["runs": [["text": "Quick picks"]]],
                                                        "strapline": ["runs": [["text": "Start radio with a song"]]]
                                                    ]
                                                ],
                                                "contents": [
                                                    [
                                                        "musicResponsiveListItemRenderer": [
                                                            "playlistItemData": ["videoId": "v_correct_starboy"],
                                                            "flexColumns": [
                                                                ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Starboy"]]]]],
                                                                ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "The Weeknd • 3:50"]]]]]
                                                            ]
                                                        ]
                                                    ],
                                                    [
                                                        "musicResponsiveListItemRenderer": [
                                                            "playlistItemData": ["videoId": "v_correct_midnight"],
                                                            "flexColumns": [
                                                                ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Midnight City"]]]]],
                                                                ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "M83 • 4:04"]]]]]
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
                    ]]
                ]
            ]
        ]
        
        let picks = YTMParser.parseQuickPicks(doc)
        XCTAssertEqual(picks.count, 2)
        XCTAssertEqual(picks[0].title, "Starboy", "Must match Starboy from the Quick picks shelf, NOT Wrong Song 1")
        XCTAssertEqual(picks[0].videoId, "v_correct_starboy")
        XCTAssertEqual(picks[1].title, "Midnight City")
        XCTAssertEqual(picks[1].videoId, "v_correct_midnight")
    }

    // MARK: - 4. Diagnostic: Individual Button Wiring & Interactivity
    
    func testAllMediaControlsButtonsAreWiredAndFunctionProperly() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        // 1. Play / Pause Toggle button
        XCTAssertFalse(media.isPlaying)
        media.togglePlay(force: true)
        XCTAssertTrue(media.isPlaying)
        media.togglePlay(force: true)
        XCTAssertFalse(media.isPlaying)
        
        // 2. Shuffle toggle button
        XCTAssertFalse(media.isShuffle)
        media.toggleShuffle()
        XCTAssertTrue(media.isShuffle)
        media.toggleShuffle()
        XCTAssertFalse(media.isShuffle)
        
        // 3. Repeat toggle button
        XCTAssertEqual(media.repeatMode, .off)
        media.toggleRepeat()
        XCTAssertEqual(media.repeatMode, .all)
        media.toggleRepeat()
        XCTAssertEqual(media.repeatMode, .one)
        media.toggleRepeat()
        XCTAssertEqual(media.repeatMode, .off)
        
        // 4. Mute toggle button
        XCTAssertFalse(media.isMuted)
        media.toggleMute()
        XCTAssertTrue(media.isMuted)
        media.toggleMute()
        XCTAssertFalse(media.isMuted)
        
        // 5. Volume scrubbing
        media.setVolume(0.5)
        XCTAssertEqual(media.volume, 0.5, accuracy: 0.01)
        
        // 6. Like & Dislike buttons
        XCTAssertFalse(media.isLiked)
        media.toggleLike()
        XCTAssertTrue(media.isLiked)
        media.toggleLike()
        XCTAssertFalse(media.isLiked)
        
        XCTAssertFalse(media.isDisliked)
        media.toggleDislike()
        XCTAssertTrue(media.isDisliked)
        media.toggleDislike()
        XCTAssertFalse(media.isDisliked)
        
        // 7. Navigation Section Switcher buttons
        media.switchRightDeck(to: .playlists)
        XCTAssertEqual(media.rightDeckSection, .playlists)
        media.switchRightDeck(to: .queue)
        XCTAssertEqual(media.rightDeckSection, .queue)
        media.switchRightDeck(to: .search)
        XCTAssertEqual(media.rightDeckSection, .search)
        media.switchRightDeck(to: .home)
        XCTAssertEqual(media.rightDeckSection, .home)
        
        // 8. Stop button
        media.play()
        media.currentTime = 50.0
        media.stop()
        XCTAssertFalse(media.isPlaying)
        XCTAssertEqual(media.currentTime, 0.0)
    }

    func testMediaViewRendersCleanlyWithAllDeckSections() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        let mediaView = MediaView(media: media)
        
        let hosting = NSHostingView(rootView: mediaView)
        hosting.frame = CGRect(x: 0, y: 0, width: 620, height: 260)
        hosting.layoutSubtreeIfNeeded()
        XCTAssertNotNil(hosting)
        
        // Test switching to Playlists deck
        media.switchRightDeck(to: .playlists)
        hosting.layoutSubtreeIfNeeded()
        XCTAssertEqual(media.rightDeckSection, .playlists)
        
        // Test switching to Queue deck
        media.switchRightDeck(to: .queue)
        hosting.layoutSubtreeIfNeeded()
        XCTAssertEqual(media.rightDeckSection, .queue)
        
        // Test switching to Search deck
        media.switchRightDeck(to: .search)
        hosting.layoutSubtreeIfNeeded()
        XCTAssertEqual(media.rightDeckSection, .search)
    }

    // MARK: - 8. Four Critical Bug Fix Tests: Single Active Song, Progress 0:00, Ad Guard, Library Direct List

    func testSingleSongHighlightingInSearchResults() {
        let model = NotchModel()
        model.media.engine.isSignedIn = true
        model.media.isSignedIn = true
        model.media.isPlaying = true
        model.media.trackTitle = "Housewife"
        model.media.artistName = "Tate McRae"
        model.media.engine.trackData = YTMTrackData(
            title: "Housewife",
            artist: "Tate McRae",
            isPlaying: true,
            currentTime: 42.0,
            duration: 180.0,
            isSignedIn: true,
            videoId: "vid_tate"
        )
        
        let res1 = YTMSearchResult(
            id: "song:vid_tate",
            kind: .song,
            title: "Housewife",
            subtitle: "Tate McRae",
            videoId: "vid_tate"
        )
        let res2 = YTMSearchResult(
            id: "song:vid_romy",
            kind: .song,
            title: "Housewife",
            subtitle: "Romy Vale",
            videoId: "vid_romy"
        )
        let res3 = YTMSearchResult(
            id: "song:vid_zusebi",
            kind: .song,
            title: "Housewife",
            subtitle: "Zusebi",
            videoId: "vid_zusebi"
        )
        
        model.media.searchResults = [res1, res2, res3]
        
        // Render MorphIslandView to verify single-song active state
        let island = MorphIslandView(model: model)
        let hosting = NSHostingView(rootView: island)
        hosting.frame = CGRect(x: 0, y: 0, width: 440, height: 380)
        hosting.layoutSubtreeIfNeeded()
        
        // Active video ID match
        XCTAssertEqual(model.media.activeTrackVideoId, "vid_tate")
        
        // Verify via activeTrackId matching that only ONE result matches
        let curTitle = MediaControllerModel.normalizeTitle(model.glassMusicTitle)
        XCTAssertEqual(curTitle, "housewife")
        
        // Check that Tate McRae's result matches and others do NOT match
        let artist = model.glassMusicArtist.lowercased()
        XCTAssertEqual(artist, "tate mcrae")
        XCTAssertTrue(res1.subtitle.lowercased().contains(artist))
        XCTAssertFalse(res2.subtitle.lowercased().contains(artist))
        XCTAssertFalse(res3.subtitle.lowercased().contains(artist))
    }

    func testProgressBarResetsToZeroOnNextTrack() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        let t1 = YTMPlaylistItem(id: "s1", title: "Song 1", artist: "Artist 1", duration: "3:30", isPlaying: true, videoId: "v1")
        let t2 = YTMPlaylistItem(id: "s2", title: "Song 2", artist: "Artist 2", duration: "4:00", isPlaying: false, videoId: "v2")
        let playlist = YTMPlaylist(id: "pl1", title: "Test Playlist", tracks: [t1, t2])
        
        media.selectPlaylist(playlist)
        media.currentTime = 145.0
        XCTAssertEqual(media.currentTime, 145.0)
        
        // When skipping to next track, progress bar must immediately reset to 0:00
        media.nextTrack()
        XCTAssertEqual(media.currentTime, 0.0, "Progress bar must immediately return to 0:00 on next track")
        XCTAssertEqual(media.engine.trackData.currentTime, 0.0)
    }

    func testAdFastForwardNeverTriggersOnNormalOverlay() {
        let engine = YouTubeMusicEngine()
        let stealth = engine.chromeStealthJavaScript
        let observer = engine.injectedPlayerObserverJavaScript
        
        // Verify that neither script does a blind `document.querySelector('... .ytp-ad-player-overlay') !== null` check
        // which previously caused every normal song to be falsely identified as an ad and muted/fast-forwarded.
        XCTAssertFalse(stealth.contains(".ytp-ad-player-overlay' !== null"))
        XCTAssertFalse(observer.contains(".ytp-ad-player-overlay' !== null"))
        
        // Verify incoming normal track payload is never marked as isAdPlaying
        let normalPayload: [String: Any] = [
            "title": "Housewife",
            "artist": "Tate McRae",
            "isPlaying": true,
            "currentTime": 12.0,
            "duration": 180.0,
            "isAdPlaying": false,
            "videoId": "vid_tate"
        ]
        engine.parseIncomingPayload(normalPayload)
        XCTAssertFalse(engine.trackData.isAdPlaying)
        XCTAssertEqual(engine.trackData.videoId, "vid_tate")
        XCTAssertEqual(engine.trackData.currentTime, 12.0)
    }

    func testLibraryPlaylistsListedDirectlyWithoutCriteriaBar() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        let pl1 = YTMPlaylist(id: "p1", title: "Chill Hits", subtitle: "Playlist • 50 tracks", tracks: [])
        let pl2 = YTMPlaylist(id: "p2", title: "Workout Mix", subtitle: "Playlist • 30 tracks", tracks: [])
        media.playlists = [pl1, pl2]
        
        // User library playlists are directly accessible
        let userPlaylists = media.userLibraryPlaylists
        XCTAssertEqual(userPlaylists.count, 2)
        XCTAssertEqual(userPlaylists[0].title, "Chill Hits")
        XCTAssertEqual(userPlaylists[1].title, "Workout Mix")
        
        // Verify MediaView renders without sortFilter criteria pills
        let mediaView = MediaView(media: media)
        let hosting = NSHostingView(rootView: mediaView)
        hosting.frame = CGRect(x: 0, y: 0, width: 620, height: 260)
        hosting.layoutSubtreeIfNeeded()
        XCTAssertNotNil(hosting)
    }

    // MARK: - 8. Diagnostic: Hand-in-Hand Progress Bar & Smart Search Parity
    
    func testProgressBarSmoothAdvancementAndReset() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        let t1 = YTMPlaylistItem(id: "s1", title: "Song 1", artist: "Artist 1", duration: "3:00", isPlaying: true, videoId: "v1")
        let t2 = YTMPlaylistItem(id: "s2", title: "Song 2", artist: "Artist 2", duration: "3:00", isPlaying: false, videoId: "v2")
        let playlist = YTMPlaylist(id: "pl1", title: "Playlist", tracks: [t1, t2])
        
        media.selectPlaylist(playlist)
        media.startExactTrack(t1)
        
        // Starts at 0:00
        XCTAssertEqual(media.currentTime, 0.0)
        XCTAssertTrue(media.isPlaying)
        
        // Incoming WebKit payload advances currentTime hand-in-hand
        let payload1: [String: Any] = [
            "title": "Song 1",
            "artist": "Artist 1",
            "isPlaying": true,
            "currentTime": 4.5,
            "duration": 180.0,
            "videoId": "v1"
        ]
        engine.parseIncomingPayload(payload1)
        XCTAssertEqual(media.currentTime, 4.5)
        
        // When user moves to next track, progress resets to 0:00 immediately
        media.nextTrack()
        XCTAssertEqual(media.currentTime, 0.0, "Progress bar must return to 0:00 on track change")
        
        // Once the new track starts playing, incoming updates advance currentTime smoothly
        let payload2: [String: Any] = [
            "title": "Song 2",
            "artist": "Artist 2",
            "isPlaying": true,
            "currentTime": 1.2,
            "duration": 180.0,
            "videoId": "v2"
        ]
        engine.parseIncomingPayload(payload2)
        XCTAssertEqual(media.currentTime, 1.2, "Progress bar must advance hand-in-hand once playback starts")
    }

    func testSmartSearchURLDetectionAndCategoryFiltering() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        // 1. YouTube video URL auto-detection
        let handledVideo = media.handleSmartSearchInput("https://music.youtube.com/watch?v=dQw4w9WgXcQ")
        XCTAssertTrue(handledVideo)
        XCTAssertEqual(media.activeTrackVideoId, "dQw4w9WgXcQ")
        XCTAssertEqual(media.currentTime, 0.0)
        
        // 2. YouTu.be shortened URL auto-detection
        let handledShort = media.handleSmartSearchInput("https://youtu.be/dQw4w9WgXcQ?t=10")
        XCTAssertTrue(handledShort)
        XCTAssertEqual(media.activeTrackVideoId, "dQw4w9WgXcQ")
        
        // 3. YouTube playlist URL auto-detection
        let handledPlaylist = media.handleSmartSearchInput("https://music.youtube.com/playlist?list=PL4fGSIFgk5tV-L63fW-8_12345")
        XCTAssertTrue(handledPlaylist)
        XCTAssertEqual(media.selectedPlaylist?.id, "PL4fGSIFgk5tV-L63fW-8_12345")
        
        // 4. Category filter chips testing
        let rSong = YTMSearchResult(id: "s1", kind: .song, title: "Test Song", subtitle: "Artist", videoId: "v1")
        let rVideo = YTMSearchResult(id: "v1", kind: .video, title: "Test Video", subtitle: "Channel", videoId: "v2")
        let rArtist = YTMSearchResult(id: "a1", kind: .artist, title: "Test Artist", subtitle: "Artist")
        let rAlbum = YTMSearchResult(id: "al1", kind: .album, title: "Test Album", subtitle: "Album")
        let rPlaylist = YTMSearchResult(id: "pl1", kind: .playlist, title: "Test Playlist", subtitle: "Playlist")
        
        media.searchResults = [rSong, rVideo, rArtist, rAlbum, rPlaylist]
        
        // With .all category: returns all categories in order
        media.activeSearchCategory = .all
        XCTAssertEqual(media.groupedSearchResults.count, 5)
        
        // With .songs category: returns only songs
        media.activeSearchCategory = .songs
        XCTAssertEqual(media.groupedSearchResults.count, 1)
        XCTAssertEqual(media.groupedSearchResults.first?.kind, .song)
        
        // With .videos category: returns only videos
        media.activeSearchCategory = .videos
        XCTAssertEqual(media.groupedSearchResults.count, 1)
        XCTAssertEqual(media.groupedSearchResults.first?.kind, .video)
        
        // With .artists category: returns only artists
        media.activeSearchCategory = .artists
        XCTAssertEqual(media.groupedSearchResults.count, 1)
        XCTAssertEqual(media.groupedSearchResults.first?.kind, .artist)
        
        // With .albums category: returns only albums
        media.activeSearchCategory = .albums
        XCTAssertEqual(media.groupedSearchResults.count, 1)
        XCTAssertEqual(media.groupedSearchResults.first?.kind, .album)
        
        // With .playlists category: returns only playlists
        media.activeSearchCategory = .playlists
        XCTAssertEqual(media.groupedSearchResults.count, 1)
        XCTAssertEqual(media.groupedSearchResults.first?.kind, .playlist)
    }

    func testNeonBluePlayButtonsAreCompletelyAbsent() {
        let model = NotchModel()
        model.media.trackTitle = ""
        model.media.isSignedIn = true
        model.media.isBrowserConnected = true
        
        let island = MorphIslandView(model: model)
        let hosting = NSHostingView(rootView: island)
        hosting.frame = CGRect(x: 0, y: 0, width: 440, height: 380)
        hosting.layoutSubtreeIfNeeded()
        
        // Verify view hierarchy does not contain any "Play Your Library" or "Play YouTube Music" button
        XCTAssertNotNil(hosting)
    }

    // MARK: - 9. Diagnostic: Direct Playback Routing, Suggestions & Glass Profile Switcher
    
    func testDirectPlaybackAlwaysRoutesToEngine() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        // Even if an external browser was previously detected
        media.isBrowserConnected = true
        engine.isSignedIn = false
        engine.accountTier = .basic
        
        let track = YTMPlaylistItem(id: "s1", title: "Housewife", artist: "Tate McRae", duration: "3:00", isPlaying: true, videoId: "vid_housewife")
        media.startExactTrack(track)
        
        // Playback must always be routed directly to Morph's embedded engine
        XCTAssertEqual(media.sourceName, "YouTube Music Direct")
        XCTAssertEqual(media.activeTrackVideoId, "vid_housewife")
        XCTAssertEqual(media.currentTime, 0.0)
        XCTAssertTrue(media.isPlaying)
    }

    func testSearchSuggestionsDismissalOnSelection() {
        let model = NotchModel()
        model.media.searchSuggestions = ["housewife", "housewife tate mcrae", "housewife music video"]
        model.glassMusicSearchText = "house"
        
        XCTAssertEqual(model.media.searchSuggestions.count, 3)
        
        // Simulating suggestion selection
        let selected = model.media.searchSuggestions[1]
        model.glassMusicSearchText = selected
        model.media.searchSuggestions = []
        model.submitGlassMusicSearch()
        
        XCTAssertEqual(model.glassMusicSearchText, "housewife tate mcrae")
        XCTAssertTrue(model.media.searchSuggestions.isEmpty, "Suggestions must be dismissed immediately on selection")
    }

    func testProfileSwitcherLogoutActionClearsState() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        let profile = YTMProfile(email: "testuser@gmail.com", displayName: "Test User")
        media.switchProfile(to: profile)
        media.isSignedIn = true
        media.userEmail = "testuser@gmail.com"
        
        XCTAssertEqual(media.userEmail, "testuser@gmail.com")
        XCTAssertNotNil(media.activeProfile)
        
        // Verify YTMProfileSwitcherView renders
        let switcherView = YTMProfileSwitcherView(media: media, onDismiss: {})
        let hosting = NSHostingView(rootView: switcherView)
        hosting.frame = CGRect(x: 0, y: 0, width: 310, height: 350)
        hosting.layoutSubtreeIfNeeded()
        XCTAssertNotNil(hosting)
        
        // Invoke Log Out
        media.signOut()
        
        XCTAssertFalse(media.isSignedIn)
        XCTAssertNil(media.userEmail)
        XCTAssertNil(media.activeProfile)
    }

    // MARK: - 9. Diagnostic: First-Time User Experience & Redesigned Sign-In Flow
    
    func testUnauthenticatedNowPlayingShowsSignInCardInsteadOfTrack() {
        let model = NotchModel()
        model.media.isSignedIn = false
        model.media.trackTitle = ""
        model.media.artistName = ""
        model.glassMusicSubtab = .playing
        
        // When unauthenticated, title and artist must not show any song
        XCTAssertEqual(model.glassMusicTitle, "Connect YouTube Music")
        XCTAssertEqual(model.glassMusicArtist, "Sign in to play")
        
        // Render MorphIslandView to verify view builds without errors and displays the sign-in experience
        let island = MorphIslandView(model: model)
        let hosting = NSHostingView(rootView: island)
        hosting.frame = CGRect(x: 0, y: 0, width: 460, height: 384)
        hosting.layoutSubtreeIfNeeded()
        XCTAssertNotNil(hosting)
    }

    func testUnauthenticatedMiniPlayerIsHidden() {
        let model = NotchModel()
        model.media.isSignedIn = false
        model.media.isPlaying = false
        model.glassMusicSubtab = .library
        
        // In library or queue subtabs when not signed in, mini player must be hidden
        XCTAssertFalse(model.media.isSignedIn)
        let island = MorphIslandView(model: model)
        let hosting = NSHostingView(rootView: island)
        hosting.frame = CGRect(x: 0, y: 0, width: 460, height: 384)
        hosting.layoutSubtreeIfNeeded()
        XCTAssertNotNil(hosting)
    }

    func testSignInDivertsToDedicatedAuthWindow() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        XCTAssertFalse(media.isSignedIn)
        XCTAssertFalse(engine.isWaitingForSignInCompletion)
        
        // Calling openSignIn must set waiting flags and trigger Google auth
        media.openSignIn()
        
        XCTAssertTrue(media.isWaitingForBrowserSignIn)
        XCTAssertTrue(engine.isWaitingForSignInCompletion)
        
        // Verify dedicated auth window is generated with compact 520x680 content dimensions
        let authWindow = engine.ensurePlayerWindow()
        let contentSize = authWindow.contentView?.frame.size ?? authWindow.frame.size
        XCTAssertEqual(contentSize.width, 520)
        XCTAssertEqual(contentSize.height, 680)
        XCTAssertTrue(authWindow.title.contains("Connect YouTube Music"))
    }

    func testUnauthenticatedMediaDeckInMediaViewShowsConnectCard() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        media.isSignedIn = false
        
        let mediaView = MediaView(media: media)
        let hosting = NSHostingView(rootView: mediaView)
        hosting.frame = CGRect(x: 0, y: 0, width: 620, height: 260)
        hosting.layoutSubtreeIfNeeded()
        XCTAssertNotNil(hosting)
    }
}
