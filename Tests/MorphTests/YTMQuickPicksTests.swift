import XCTest
import SwiftUI
@testable import morph

final class YTMQuickPicksTests: XCTestCase {

    // MARK: - 1. InnerTube Home Parsing Tests

    func testParseQuickPicksWithCarouselShelf() {
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
                                                        "title": ["runs": [["text": "Quick picks"]]],
                                                        "strapline": ["runs": [["text": "Start radio with a song"]]]
                                                    ]
                                                ],
                                                "contents": [
                                                    [
                                                        "musicResponsiveListItemRenderer": [
                                                            "playlistItemData": ["videoId": "vid_starboy"],
                                                            "flexColumns": [
                                                                [
                                                                    "musicResponsiveListItemFlexColumnRenderer": [
                                                                        "text": ["runs": [["text": "Starboy"]]]
                                                                    ]
                                                                ],
                                                                [
                                                                    "musicResponsiveListItemFlexColumnRenderer": [
                                                                        "text": ["runs": [["text": "The Weeknd • Starboy • 3:50"]]]
                                                                    ]
                                                                ]
                                                            ],
                                                            "thumbnail": [
                                                                "musicThumbnailRenderer": [
                                                                    "thumbnail": [
                                                                        "thumbnails": [["url": "https://img.youtube.com/vi/vid_starboy/hqdefault.jpg"]]
                                                                    ]
                                                                ]
                                                            ]
                                                        ]
                                                    ],
                                                    [
                                                        "musicResponsiveListItemRenderer": [
                                                            "playlistItemData": ["videoId": "vid_midnight"],
                                                            "flexColumns": [
                                                                [
                                                                    "musicResponsiveListItemFlexColumnRenderer": [
                                                                        "text": ["runs": [["text": "Midnight City"]]]
                                                                    ]
                                                                ],
                                                                [
                                                                    "musicResponsiveListItemFlexColumnRenderer": [
                                                                        "text": ["runs": [["text": "M83 • 4:04"]]]
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
                    ]]
                ]
            ]
        ]

        let picks = YTMParser.parseQuickPicks(doc)
        XCTAssertEqual(picks.count, 2, "Should parse 2 tracks from Quick picks carousel shelf")
        XCTAssertEqual(picks[0].title, "Starboy")
        XCTAssertEqual(picks[0].artist, "The Weeknd")
        XCTAssertEqual(picks[0].duration, "3:50")
        XCTAssertEqual(picks[0].videoId, "vid_starboy")
        XCTAssertEqual(picks[0].thumbnailURL, "https://img.youtube.com/vi/vid_starboy/hqdefault.jpg")

        XCTAssertEqual(picks[1].title, "Midnight City")
        XCTAssertEqual(picks[1].artist, "M83")
        XCTAssertEqual(picks[1].duration, "4:04")
        XCTAssertEqual(picks[1].videoId, "vid_midnight")
    }

    func testParseQuickPicksWithTwoRowCards() {
        let doc: [String: Any] = [
            "contents": [
                "musicCarouselShelfRenderer": [
                    "header": [
                        "musicCarouselShelfBasicHeaderRenderer": [
                            "title": ["runs": [["text": "Listen again"]]]
                        ]
                    ],
                    "contents": [
                        [
                            "musicTwoRowItemRenderer": [
                                "title": ["runs": [["text": "Resonance"]]],
                                "subtitle": ["runs": [["text": "HOME • 3:32"]]],
                                "navigationEndpoint": [
                                    "watchEndpoint": ["videoId": "vid_resonance"]
                                ],
                                "thumbnailRenderer": [
                                    "musicThumbnailRenderer": [
                                        "thumbnail": [
                                            "thumbnails": [["url": "https://img.youtube.com/vi/vid_resonance/hqdefault.jpg"]]
                                        ]
                                    ]
                                ]
                            ]
                        ],
                        [
                            "musicTwoRowItemRenderer": [
                                "title": ["runs": [["text": "After Dark"]]],
                                "subtitle": ["runs": [["text": "Mr.Kitty • 4:18"]]],
                                "navigationEndpoint": [
                                    "watchEndpoint": ["videoId": "vid_after_dark"]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let picks = YTMParser.parseQuickPicks(doc)
        XCTAssertEqual(picks.count, 2)
        XCTAssertEqual(picks[0].title, "Resonance")
        XCTAssertEqual(picks[0].artist, "HOME")
        XCTAssertEqual(picks[0].duration, "3:32")
        XCTAssertEqual(picks[0].videoId, "vid_resonance")
        XCTAssertEqual(picks[1].title, "After Dark")
        XCTAssertEqual(picks[1].artist, "Mr.Kitty")
    }

    func testParseQuickPicksFallbackToFirstPlayableShelfWhenHeaderDiffers() {
        // Simulates localized interface (e.g. Vietnamese or French) where header text does not match English keywords
        let doc: [String: Any] = [
            "contents": [
                "musicShelfRenderer": [
                    "title": ["runs": [["text": "Lựa chọn cho bạn"]]],
                    "contents": [
                        [
                            "musicResponsiveListItemRenderer": [
                                "playlistItemData": ["videoId": "vid_local1"],
                                "flexColumns": [
                                    ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Song A"]]]]],
                                    ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Artist A • 3:10"]]]]]
                                ]
                            ]
                        ],
                        [
                            "musicResponsiveListItemRenderer": [
                                "playlistItemData": ["videoId": "vid_local2"],
                                "flexColumns": [
                                    ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Song B"]]]]],
                                    ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Artist B • 2:45"]]]]]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let picks = YTMParser.parseQuickPicks(doc)
        XCTAssertEqual(picks.count, 2, "Should fallback to the first playable shelf with playable items")
        XCTAssertEqual(picks[0].title, "Song A")
        XCTAssertEqual(picks[1].title, "Song B")
    }

    func testDefaultQuickPicksContainsValidData() {
        let defaults = YTMParser.defaultQuickPicks
        XCTAssertGreaterThanOrEqual(defaults.count, 5, "Default quick picks must have at least 5 curated tracks")
        for track in defaults {
            XCTAssertFalse(track.title.isEmpty)
            XCTAssertFalse(track.artist.isEmpty)
            XCTAssertNotNil(track.videoId, "Every default quick pick must have a valid videoId for instant playback")
            XCTAssertFalse(track.videoId!.isEmpty)
            XCTAssertNotNil(track.thumbnailURL)
        }
    }

    // MARK: - 2. Engine Level Tests

    @MainActor
    func testEngineQuickPicksInitializationAndRefresh() async {
        let engine = YouTubeMusicEngine()
        XCTAssertFalse(engine.quickPicks.isEmpty, "Engine should initialize with curated fallback quick picks")

        // Override InnerTube response to return custom test recommendations
        let mockHomeDoc: [String: Any] = [
            "contents": [
                "musicCarouselShelfRenderer": [
                    "header": [
                        "musicCarouselShelfBasicHeaderRenderer": [
                            "title": ["runs": [["text": "Quick picks"]]]
                        ]
                    ],
                    "contents": [
                        [
                            "musicResponsiveListItemRenderer": [
                                "playlistItemData": ["videoId": "test_vid_1"],
                                "flexColumns": [
                                    ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Algorithmic Hit 1"]]]]],
                                    ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "AI Artist 1 • 3:00"]]]]]
                                ]
                            ]
                        ],
                        [
                            "musicResponsiveListItemRenderer": [
                                "playlistItemData": ["videoId": "test_vid_2"],
                                "flexColumns": [
                                    ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "Algorithmic Hit 2"]]]]],
                                    ["musicResponsiveListItemFlexColumnRenderer": ["text": ["runs": [["text": "AI Artist 2 • 3:30"]]]]]
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        engine.innerTubeOverride = { endpoint, body in
            if endpoint == "browse" && (body["browseId"] as? String) == "FEmusic_home" {
                return mockHomeDoc
            }
            return [:]
        }

        await engine.refreshQuickPicks()

        XCTAssertEqual(engine.quickPicks.count, 2)
        XCTAssertEqual(engine.quickPicks[0].title, "Algorithmic Hit 1")
        XCTAssertEqual(engine.quickPicks[0].videoId, "test_vid_1")
        XCTAssertEqual(engine.quickPicks[1].title, "Algorithmic Hit 2")
        XCTAssertEqual(engine.quickPicks[1].videoId, "test_vid_2")
    }

    @MainActor
    func testEngineIncomingPayloadUpdatesQuickPicks() {
        let engine = YouTubeMusicEngine()

        let incomingPayload: [String: Any] = [
            "title": "Now Playing",
            "artist": "Active Artist",
            "isPlaying": true,
            "quickPicks": [
                [
                    "id": "dom_1",
                    "title": "DOM Pick 1",
                    "artist": "DOM Artist",
                    "duration": "2:55",
                    "videoId": "vid_dom1",
                    "thumbnailURL": "https://img.youtube.com/vi/vid_dom1/hqdefault.jpg"
                ],
                [
                    "id": "dom_2",
                    "title": "DOM Pick 2",
                    "artist": "DOM Artist 2",
                    "duration": "3:40",
                    "videoId": "vid_dom2"
                ]
            ]
        ]

        engine.parseIncomingPayload(incomingPayload)

        XCTAssertEqual(engine.quickPicks.count, 2)
        XCTAssertEqual(engine.quickPicks[0].title, "DOM Pick 1")
        XCTAssertEqual(engine.quickPicks[0].videoId, "vid_dom1")
        XCTAssertEqual(engine.quickPicks[1].title, "DOM Pick 2")
    }

    // MARK: - 3. MediaControllerModel Tests

    @MainActor
    func testModelQuickPicksDeckNavigationAndSectionSwitching() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)

        XCTAssertEqual(media.rightDeckSection, .home)

        // Navigate to Quick Picks section (routes to Home where Quick Picks is featured)
        media.openQuickPicksSection()
        XCTAssertEqual(media.rightDeckSection, .home)
        XCTAssertNil(media.selectedPlaylist)

        // Switch to other tabs
        media.switchRightDeck(to: .playlists)
        XCTAssertEqual(media.rightDeckSection, .playlists)

        media.switchRightDeck(to: .queue)
        XCTAssertEqual(media.rightDeckSection, .queue)

        media.switchRightDeck(to: .home)
        XCTAssertEqual(media.rightDeckSection, .home)
    }

    @MainActor
    func testPlayQuickPickSeedsAlgorithmicRadio() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)

        let targetTrack = YTMPlaylistItem(
            id: "qp_target",
            title: "Midnight City",
            artist: "M83",
            duration: "4:04",
            videoId: "dX3k_QDnzHE",
            thumbnailURL: "https://i.ytimg.com/vi/dX3k_QDnzHE/hqdefault.jpg"
        )
        media.quickPicks = [targetTrack]

        media.playQuickPick(targetTrack, startRadio: true)

        XCTAssertEqual(media.trackTitle, "Midnight City")
        XCTAssertEqual(media.artistName, "M83")
        XCTAssertEqual(media.albumArtURL, "https://i.ytimg.com/vi/dX3k_QDnzHE/hqdefault.jpg")
        XCTAssertTrue(media.isPlaying)
        XCTAssertTrue(media.isSongCurrent(targetTrack, in: media.quickPicks), "Track must be marked as current playing in quickPicks")
    }

    @MainActor
    func testQuickPicksActiveTrackIdSynchronization() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)

        let t1 = YTMPlaylistItem(id: "qp1", title: "Starboy", artist: "The Weeknd", videoId: "v1")
        let t2 = YTMPlaylistItem(id: "qp2", title: "Resonance", artist: "HOME", videoId: "v2")
        media.quickPicks = [t1, t2]

        media.trackTitle = "Starboy"
        media.artistName = "The Weeknd"
        media.isPlaying = true
        media.syncPlayingTrackWithPlaylists()

        XCTAssertTrue(media.isSongCurrent(t1, in: media.quickPicks))
        XCTAssertFalse(media.isSongCurrent(t2, in: media.quickPicks))

        // Paused state
        media.isPlaying = false
        media.syncPlayingTrackWithPlaylists()
        XCTAssertFalse(media.isSongCurrent(t1, in: media.quickPicks))
        XCTAssertTrue(media.isSongPausedCurrent(t1, in: media.quickPicks))

        // When unrelated song is playing, neither should be active
        media.trackTitle = "Unrelated Song"
        media.artistName = "Other Artist"
        media.isPlaying = true
        media.syncPlayingTrackWithPlaylists()

        XCTAssertFalse(media.isSongCurrent(t1, in: media.quickPicks))
        XCTAssertFalse(media.isSongCurrent(t2, in: media.quickPicks))
    }

    // MARK: - 4. UI View Hierarchy Tests

    @MainActor
    func testMediaViewWithQuickPicksBuildsCleanly() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        let mediaView = MediaView(media: media)

        let hosting = NSHostingView(rootView: mediaView)
        hosting.frame = CGRect(x: 0, y: 0, width: 640, height: 225)
        hosting.layoutSubtreeIfNeeded()

        XCTAssertNotNil(hosting)

        // Switch to playlists tab
        media.switchRightDeck(to: .playlists)
        hosting.layoutSubtreeIfNeeded()
        XCTAssertEqual(media.rightDeckSection, .playlists)

        // Switch back to home
        media.switchRightDeck(to: .home)
        hosting.layoutSubtreeIfNeeded()
        XCTAssertEqual(media.rightDeckSection, .home)
    }

    // MARK: - 5. Quick Picks in Playlist & Sequential Playback Tests

    @MainActor
    func testOpenQuickPicksPlaylistConfiguresContainerAndRendersInPlaylistsTab() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)

        let t1 = YTMPlaylistItem(id: "qp_1", title: "Midnight City", artist: "M83", duration: "4:04", videoId: "vid1")
        let t2 = YTMPlaylistItem(id: "qp_2", title: "Starboy", artist: "The Weeknd", duration: "3:50", videoId: "vid2")
        media.quickPicks = [t1, t2]

        // Act: Open Quick Picks playlist
        media.openQuickPicksPlaylist()

        // Assert: Container setup
        XCTAssertNotNil(media.selectedPlaylist)
        XCTAssertEqual(media.selectedPlaylist?.id, "pl_quickpicks")
        XCTAssertEqual(media.selectedPlaylist?.title, "Quick Picks")
        XCTAssertEqual(media.selectedPlaylist?.tracks.count, 2)
        XCTAssertEqual(media.rightDeckSection, .playlists)

        // Verify layout
        let mediaView = MediaView(media: media)
        let hosting = NSHostingView(rootView: mediaView)
        hosting.frame = CGRect(x: 0, y: 0, width: 640, height: 225)
        hosting.layoutSubtreeIfNeeded()
        XCTAssertNotNil(hosting)

        // Playing a track from quick picks playlist sets active playing state
        media.playSongInSelectedPlaylist(t1)
        XCTAssertEqual(media.trackTitle, "Midnight City")
        XCTAssertTrue(media.isPlaying)
        XCTAssertTrue(media.selectedPlaylist?.tracks[0].isPlaying == true, "First track in Quick Picks playlist must be marked playing")
    }

    @MainActor
    func testPlaylistSequentialNextTrackNeverJumpsToRandomRadioOrShelf() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)

        let s0 = YTMPlaylistItem(id: "s0", title: "Song 0", artist: "Artist A", duration: "3:00", videoId: "v0")
        let s1 = YTMPlaylistItem(id: "s1", title: "Song 1", artist: "Artist A", duration: "3:10", videoId: "v1")
        let s2 = YTMPlaylistItem(id: "s2", title: "Song 2", artist: "Artist A", duration: "3:20", videoId: "v2")
        let playlist = YTMPlaylist(id: "my_playlist", title: "My Favorites", tracks: [s0, s1, s2])

        media.selectPlaylist(playlist)
        XCTAssertEqual(media.selectedPlaylist?.id, "my_playlist")

        // Start on Song 0
        media.playSongInSelectedPlaylist(s0)
        XCTAssertEqual(media.trackTitle, "Song 0")

        // Next track MUST move sequentially to Song 1 in the playlist
        media.nextTrack()
        XCTAssertEqual(media.trackTitle, "Song 1", "nextTrack() inside a selected playlist must advance to Song 1, not jump to random radio")
        XCTAssertTrue(media.selectedPlaylist?.tracks[1].isPlaying == true)

        // Next track again MUST move to Song 2
        media.nextTrack()
        XCTAssertEqual(media.trackTitle, "Song 2", "nextTrack() inside a selected playlist must advance to Song 2")
        XCTAssertTrue(media.selectedPlaylist?.tracks[2].isPlaying == true)
    }

    @MainActor
    func testPlaylistPreviousTrackStepsSequentiallyBackward() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)

        let s0 = YTMPlaylistItem(id: "s0", title: "Song 0", artist: "Artist A", duration: "3:00", videoId: "v0")
        let s1 = YTMPlaylistItem(id: "s1", title: "Song 1", artist: "Artist A", duration: "3:10", videoId: "v1")
        let s2 = YTMPlaylistItem(id: "s2", title: "Song 2", artist: "Artist A", duration: "3:20", videoId: "v2")
        let playlist = YTMPlaylist(id: "my_playlist", title: "My Favorites", tracks: [s0, s1, s2])

        media.selectPlaylist(playlist)
        media.playSongInSelectedPlaylist(s2)
        XCTAssertEqual(media.trackTitle, "Song 2")

        // When currentTime <= 3.0s, previousTrack must immediately step back to Song 1
        media.currentTime = 1.2
        media.previousTrack()
        XCTAssertEqual(media.trackTitle, "Song 1", "previousTrack() under 3s must step back to Song 1")
        XCTAssertTrue(media.selectedPlaylist?.tracks[1].isPlaying == true)

        // Previous track again must step back to Song 0
        media.currentTime = 0.8
        media.previousTrack()
        XCTAssertEqual(media.trackTitle, "Song 0", "previousTrack() under 3s must step back to Song 0")
        XCTAssertTrue(media.selectedPlaylist?.tracks[0].isPlaying == true)
    }

    @MainActor
    func testWatchdogEnsurePlaybackEvaluatesUnblockingScript() {
        let engine = YouTubeMusicEngine()
        var evaluatedScript: String?
        engine.onEvaluate = { script in
            evaluatedScript = script
        }

        engine.ensurePlayback()

        XCTAssertNotNil(evaluatedScript)
        XCTAssertTrue(evaluatedScript?.contains("p.playVideo()") == true, "Must call movie_player.playVideo()")
        XCTAssertTrue(evaluatedScript?.contains("wasMuted = v.muted") == true, "Must include mute-unmute WebKit autoplay unblocker")
    }

    @MainActor
    func testPlaylistQuickPicksShelfEmbeddedInRegularPlaylistDetail() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)

        let s0 = YTMPlaylistItem(id: "s0", title: "Album Song 1", artist: "Band A", videoId: "v0")
        let playlist = YTMPlaylist(id: "album_1", title: "Greatest Hits", tracks: [s0])
        media.selectPlaylist(playlist)

        let q1 = YTMPlaylistItem(id: "q1", title: "Suggested Pick", artist: "Similar Artist", duration: "3:45", videoId: "vq1")
        media.quickPicks = [q1]

        let mediaView = MediaView(media: media)
        let hosting = NSHostingView(rootView: mediaView)
        hosting.frame = CGRect(x: 0, y: 0, width: 640, height: 225)
        hosting.layoutSubtreeIfNeeded()

        XCTAssertNotNil(hosting, "MediaView must build and lay out cleanly with Quick Picks suggestions embedded in playlist detail")
    }
}
