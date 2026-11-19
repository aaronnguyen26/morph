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
}
