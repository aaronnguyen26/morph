import XCTest
@testable import morph

@MainActor
final class YTMContinuousPlaylistAndQueueTests: XCTestCase {
    
    // MARK: - 1. Continuous Entire Playlist Playback Auto-Advance
    func testContinuousEntirePlaylistAutoAdvancementFromFirstToLast() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        let t0 = YTMPlaylistItem(id: "t0", title: "Track Zero", artist: "Artist", duration: "3:00", videoId: "v0")
        let t1 = YTMPlaylistItem(id: "t1", title: "Track One", artist: "Artist", duration: "3:20", videoId: "v1")
        let t2 = YTMPlaylistItem(id: "t2", title: "Track Two", artist: "Artist", duration: "4:00", videoId: "v2")
        let playlist = YTMPlaylist(id: "pl_album", title: "Album Playback", tracks: [t0, t1, t2])
        
        media.selectedPlaylist = playlist
        media.repeatMode = .off
        
        // Start entire playlist playback
        media.playEntireSelectedPlaylist()
        XCTAssertEqual(media.trackTitle, "Track Zero")
        XCTAssertTrue(media.isPlaying)
        XCTAssertEqual(media.selectedPlaylist?.tracks[0].isPlaying, true)
        
        // Track 0 finishes -> auto-advance to Track 1
        media.handleTrackEnded(force: true)
        XCTAssertEqual(media.trackTitle, "Track One", "Must advance to track 1 after track 0 ends")
        XCTAssertTrue(media.isPlaying)
        XCTAssertEqual(media.selectedPlaylist?.tracks[1].isPlaying, true)
        
        // Track 1 finishes -> auto-advance to Track 2
        media.handleTrackEnded(force: true)
        XCTAssertEqual(media.trackTitle, "Track Two", "Must advance to track 2 after track 1 ends")
        XCTAssertTrue(media.isPlaying)
        XCTAssertEqual(media.selectedPlaylist?.tracks[2].isPlaying, true)
        
        // Track 2 (last track) finishes with repeatMode == .off -> stops cleanly
        media.handleTrackEnded(force: true)
        XCTAssertFalse(media.isPlaying, "Must cleanly stop at end of playlist when repeat is off")
    }
    
    // MARK: - 2. Continuous Entire Playlist with Repeat All (Infinite Loop)
    func testContinuousEntirePlaylistAutoAdvancementWithRepeatAll() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        let t0 = YTMPlaylistItem(id: "t0", title: "Track Zero", artist: "Artist", duration: "3:00", videoId: "v0")
        let t1 = YTMPlaylistItem(id: "t1", title: "Track One", artist: "Artist", duration: "3:20", videoId: "v1")
        let playlist = YTMPlaylist(id: "pl_loop", title: "Loop Playlist", tracks: [t0, t1])
        
        media.selectedPlaylist = playlist
        media.repeatMode = .all
        
        media.playEntireSelectedPlaylist()
        XCTAssertEqual(media.trackTitle, "Track Zero")
        
        // Track 0 ends -> Track 1
        media.handleTrackEnded(force: true)
        XCTAssertEqual(media.trackTitle, "Track One")
        
        // Track 1 ends with repeatMode == .all -> Loops back to Track 0
        media.handleTrackEnded(force: true)
        XCTAssertEqual(media.trackTitle, "Track Zero", "Repeat All must wrap back to track 0 when last song ends")
        XCTAssertTrue(media.isPlaying)
    }
    
    // MARK: - 3. Repeat One / Loop Current Track
    func testRepeatOneLoopsCurrentTrackWithoutAdvancing() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        let t0 = YTMPlaylistItem(id: "t0", title: "Solo Track", artist: "Artist", duration: "3:00", videoId: "v0")
        let t1 = YTMPlaylistItem(id: "t1", title: "Next Track", artist: "Artist", duration: "3:00", videoId: "v1")
        media.selectedPlaylist = YTMPlaylist(id: "pl_one", title: "Solo List", tracks: [t0, t1])
        media.repeatMode = .one
        media.trackTitle = "Solo Track"
        media.isPlaying = true
        media.currentTime = 179.8
        media.duration = 180.0
        
        // Song ends in Repeat One
        media.handleTrackEnded(force: true)
        
        XCTAssertEqual(media.trackTitle, "Solo Track", "Repeat One must keep playing the current track")
        XCTAssertEqual(media.currentTime, 0.0, "Current time must reset to 0 for loop")
        XCTAssertTrue(media.isPlaying)
    }
    
    // MARK: - 4. Queue Pick & Play Next Feature
    func testPlayNextInsertsDirectlyAfterPlayingSongAndPlaysNext() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        let songA = YTMPlaylistItem(id: "0", title: "Song A", artist: "Artist", isPlaying: true, videoId: "vA")
        let songB = YTMPlaylistItem(id: "1", title: "Song B", artist: "Artist", videoId: "vB")
        let songC = YTMPlaylistItem(id: "2", title: "Song C", artist: "Artist", videoId: "vC")
        media.playlist = [songA, songB, songC]
        media.trackTitle = "Song A"
        media.isPlaying = true
        
        // User selects "Play Next" on an upcoming or new track
        let chosenTrack = YTMPlaylistItem(id: "chosen", title: "Chosen Next", artist: "Artist", videoId: "vChosen")
        media.playNext(chosenTrack)
        
        // The queue order must now be: Song A (playing) -> Chosen Next -> Song B -> Song C
        XCTAssertEqual(media.playlist.count, 4)
        XCTAssertEqual(media.playlist[0].title, "Song A")
        XCTAssertEqual(media.playlist[1].title, "Chosen Next", "Play Next must insert track right after the playing song")
        XCTAssertEqual(media.playlist[2].title, "Song B")
        XCTAssertEqual(media.playlist[3].title, "Song C")
        
        // When Song A finishes, Chosen Next must be played next!
        media.handleTrackEnded(force: true)
        XCTAssertEqual(media.trackTitle, "Chosen Next", "Next song played must be the 'Play Next' inserted track")
        XCTAssertTrue(media.isPlaying)
    }
    
    // MARK: - 5. Queue Picking Any Song Plays It Immediately & Continues Forward
    func testQueuePickAndChoosePlaysSongAndSubsequentSongFollows() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        let q0 = YTMPlaylistItem(id: "0", title: "Queue 0", artist: "Artist", isPlaying: true, videoId: "v0")
        let q1 = YTMPlaylistItem(id: "1", title: "Queue 1", artist: "Artist", videoId: "v1")
        let q2 = YTMPlaylistItem(id: "2", title: "Queue 2", artist: "Artist", videoId: "v2")
        let q3 = YTMPlaylistItem(id: "3", title: "Queue 3", artist: "Artist", videoId: "v3")
        media.playlist = [q0, q1, q2, q3]
        media.trackTitle = "Queue 0"
        media.isPlaying = true
        media.selectedPlaylist = media.nowPlayingQueuePlaylist
        
        // User chooses Queue 2 from the queue view
        media.playSongInSelectedPlaylist(q2)
        XCTAssertEqual(media.trackTitle, "Queue 2", "Picking Queue 2 must immediately play Queue 2")
        XCTAssertTrue(media.isPlaying)
        XCTAssertTrue(media.playlist[2].isPlaying)
        
        // When Queue 2 finishes, Queue 3 must play next automatically!
        media.handleTrackEnded(force: true)
        XCTAssertEqual(media.trackTitle, "Queue 3", "Queue must advance to Queue 3 after Queue 2 finishes")
        XCTAssertTrue(media.isPlaying)
        XCTAssertTrue(media.playlist[3].isPlaying)
    }
    
    // MARK: - 6. Stalled Playback Recovery Watchdog
    func testStalledPlaybackWatchdogTriggersEnsurePlayback() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        media.isTestingSimulation = true
        
        var ensurePlaybackEvaluated = false
        engine.onEvaluate = { script in
            if script.contains("ensureActivePlayback") || script.contains("dismissModalsAndEnableAutoplay") {
                ensurePlaybackEvaluated = true
            }
        }
        
        // Update 1: Stalled at 0s with isPlaying = true
        let stalledData1 = YTMTrackData(
            title: "Stalled Track",
            artist: "Artist",
            albumArtURL: nil,
            isPlaying: true,
            currentTime: 0.0,
            duration: 240.0,
            volume: 1.0,
            isMuted: false,
            isLiked: false,
            isDisliked: false,
            isShuffle: false,
            repeatMode: .off,
            queue: []
        )
        engine.simulateTrackDataUpdate(stalledData1)
        
        // Update 2: Still stalled at 0s
        let stalledData2 = YTMTrackData(
            title: "Stalled Track",
            artist: "Artist",
            albumArtURL: nil,
            isPlaying: true,
            currentTime: 0.0,
            duration: 240.0,
            volume: 1.0,
            isMuted: false,
            isLiked: false,
            isDisliked: false,
            isShuffle: false,
            repeatMode: .off,
            queue: []
        )
        engine.simulateTrackDataUpdate(stalledData2)
        
        XCTAssertTrue(ensurePlaybackEvaluated, "Stalled playback watchdog must evaluate unblocking recovery script")
    }
}
