import XCTest
@testable import morph

final class YouTubeMusicSyncAndDeduplicationTests: XCTestCase {
    
    // MARK: - Global Deduplication Tests
    
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
    
    // MARK: - Single Active Track Guarantee (No 3 Songs Playing Concurrently)
    
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
    
    // MARK: - Title Normalization & Left/Right Synchronization
    
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
    
    // MARK: - Auto-Advance Single Active Track Update
    
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
    
    // MARK: - Inverted Artist Permutations and False Highlight Tests
    
    func testDeduplicationCollapsesInvertedArtistPermutations() {
        // e.g. "Low G & JustaTee" vs "JustaTee & Low G"
        let t1 = YTMPlaylistItem(id: "1", title: "In Love", artist: "Low G & JustaTee")
        let t2 = YTMPlaylistItem(id: "2", title: "In Love", artist: "JustaTee & Low G")
        
        let res = YTMPlaylistItem.deduplicate([t1, t2])
        XCTAssertEqual(res.count, 1, "Inverted artist permutations must be collapsed as duplicates")
        
        // e.g. "Wren Evans (ft. itsnk)" vs "itsnk & Wren Evans"
        let w1 = YTMPlaylistItem(id: "3", title: "ĐĐĐ", artist: "Wren Evans (ft. itsnk)")
        let w2 = YTMPlaylistItem(id: "4", title: "ĐĐĐ", artist: "itsnk & Wren Evans")
        let resW = YTMPlaylistItem.deduplicate([w1, w2])
        XCTAssertEqual(resW.count, 1, "Featured artist variations must be collapsed as duplicates")
    }
    
    @MainActor
    func testActiveTrackIdReturnsNilWhenPlayingSongIsNotInList() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        // Song playing on left: "Em Không Thể" by Tiên Tiên
        media.trackTitle = "Em Không Thể (Reverse Ride)"
        media.artistName = "Tiên Tiên & Touliver"
        media.isPlaying = true
        
        // Tracks in current playlist on right:
        let t1 = YTMPlaylistItem(id: "1", title: "In Love", artist: "Low G & JustaTee", isPlaying: true)
        let t2 = YTMPlaylistItem(id: "2", title: "ĐĐĐ", artist: "Wren Evans", isPlaying: false)
        let tracks = [t1, t2]
        
        // activeTrackId MUST NOT return t1 just because t1 had isPlaying: true
        let activeId = media.activeTrackId(in: tracks)
        XCTAssertNil(activeId, "activeTrackId must return nil when playing track is not in the list, never falsely highlight an unrelated song!")
        
        XCTAssertFalse(media.isSongCurrent(t1, in: tracks))
        XCTAssertFalse(media.isSongCurrent(t2, in: tracks))
    }
    
    @MainActor
    func testRightDeckNavigationSections() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        XCTAssertEqual(media.rightDeckSection, .home)
        
        media.openPlaylistsSection()
        XCTAssertEqual(media.rightDeckSection, .playlists)
        XCTAssertNil(media.selectedPlaylist)
        
        let pl = YTMPlaylist(id: "custom_pl", title: "My Hits", tracks: [])
        media.selectPlaylist(pl)
        XCTAssertEqual(media.rightDeckSection, .playlists)
        XCTAssertEqual(media.selectedPlaylist?.id, "custom_pl")
        
        media.openHubHome()
        XCTAssertEqual(media.rightDeckSection, .home)
        XCTAssertNil(media.selectedPlaylist)
    }
}

