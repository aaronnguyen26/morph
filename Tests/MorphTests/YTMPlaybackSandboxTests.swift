import XCTest
@testable import morph

/// Sandbox test harness verifying playback navigation and queue interaction under live conditions,
/// specifically reproducing and testing the resolution of the "3 tries to click back from queue" issue.
final class YTMPlaybackSandboxTests: XCTestCase {
    
    // MARK: - Sandbox Test 1: Single Click When currentTime <= 3.0s
    @MainActor
    func testSingleClickWhenUnderThreeSecondsImmediatelyAdvancesToPreviousTrack() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        let t0 = YTMPlaylistItem(id: "0", title: "First Track", artist: "Artist A", videoId: "vid_0")
        let t1 = YTMPlaylistItem(id: "1", title: "Second Track", artist: "Artist B", isPlaying: true, videoId: "vid_1")
        let t2 = YTMPlaylistItem(id: "2", title: "Third Track", artist: "Artist C", videoId: "vid_2")
        media.playlist = [t0, t1, t2]
        media.trackTitle = "Second Track"
        media.artistName = "Artist B"
        media.isPlaying = true
        media.currentTime = 1.8 // < 3.0s
        media.duration = 200.0
        
        var evaluatedScript: String?
        engine.onEvaluate = { script in
            evaluatedScript = script
        }
        
        // Act: User clicks Previous Track ONCE
        media.previousTrack()
        
        // Assert: It must advance immediately on 1st click to Track 0 (First Track)
        XCTAssertEqual(media.trackTitle, "First Track", "Single click when <= 3.0s must immediately advance to the previous track")
        XCTAssertEqual(media.playlist[0].isPlaying, true, "First track must be marked as playing")
        XCTAssertEqual(media.playlist[1].isPlaying, false, "Second track must no longer be playing")
        XCTAssertNotNil(evaluatedScript, "Engine must execute queue playback script")
        XCTAssertTrue(evaluatedScript?.contains("playVideoAt(0)") == true || evaluatedScript?.contains("previousVideo") == true,
                      "Script must command YouTube Music to play previous queue track at index 0")
    }
    
    // MARK: - Sandbox Test 2: Rapid Double-Click When currentTime > 3.0s
    @MainActor
    func testRapidDoubleClickAlwaysSkipsToPreviousTrackRegardlessOfCurrentTime() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        let t0 = YTMPlaylistItem(id: "0", title: "Track Alpha", artist: "Artist 1", videoId: "alpha")
        let t1 = YTMPlaylistItem(id: "1", title: "Track Beta", artist: "Artist 2", isPlaying: true, videoId: "beta")
        media.playlist = [t0, t1]
        media.trackTitle = "Track Beta"
        media.artistName = "Artist 2"
        media.isPlaying = true
        media.currentTime = 25.0 // > 3.0s: Song is playing well into its duration
        media.duration = 180.0
        
        var evaluatedScripts: [String] = []
        engine.onEvaluate = { script in
            evaluatedScripts.append(script)
        }
        
        // Click 1: User clicks Previous -> Restarts song (seeks to 0)
        media.previousTrack()
        XCTAssertEqual(media.currentTime, 0.0, "Click 1 must seek to 0.0")
        XCTAssertEqual(media.trackTitle, "Track Beta", "Track Beta is still active on click 1 (seeking to 0)")
        
        // Simulate in-flight observer update arriving from WebKit with stale >3s time!
        // (This was the root cause of requiring 3 tries)
        let staleUpdate = YTMTrackData(
            title: "Track Beta",
            artist: "Artist 2",
            albumArtURL: nil,
            isPlaying: true,
            currentTime: 24.8, // stale in-flight update
            duration: 180.0,
            volume: 1.0,
            isMuted: false,
            isLiked: false,
            isDisliked: false,
            isShuffle: false,
            repeatMode: .off,
            queue: [t0, t1]
        )
        engine.simulateTrackDataUpdate(staleUpdate)
        
        // Click 2 within rapid click window (< 2.0s):
        // User explicitly clicks Previous again to go back to the previous track!
        media.previousTrack()
        
        // Assert: Action MUST be completed on Click 2 (the standard double-click skip), NEVER requiring 3 clicks!
        XCTAssertEqual(media.trackTitle, "Track Alpha", "Rapid click 2 must bypass seek-to-0 and advance to Track Alpha")
        XCTAssertEqual(media.playlist[0].isPlaying, true, "Track Alpha must now be playing")
        XCTAssertEqual(media.playlist[1].isPlaying, false, "Track Beta must be stopped")
    }
    
    // MARK: - Sandbox Test 3: Lockout Against Stale In-Flight Observer Updates
    @MainActor
    func testSeekToZeroLockoutProtectsCurrentTimeFromStaleObserverUpdates() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        let t0 = YTMPlaylistItem(id: "0", title: "Song 0", artist: "Artist")
        let t1 = YTMPlaylistItem(id: "1", title: "Song 1", artist: "Artist", isPlaying: true)
        media.playlist = [t0, t1]
        media.trackTitle = "Song 1"
        media.isPlaying = true
        media.currentTime = 42.0
        media.duration = 240.0
        
        // Click 1: Seek to 0
        media.previousTrack()
        XCTAssertEqual(media.currentTime, 0.0)
        
        // In-flight observer arrives 200ms later with stale currentTime = 41.5s
        let staleUpdate = YTMTrackData(
            title: "Song 1",
            artist: "Artist",
            albumArtURL: nil,
            isPlaying: true,
            currentTime: 41.5,
            duration: 240.0,
            volume: 1.0,
            isMuted: false,
            isLiked: false,
            isDisliked: false,
            isShuffle: false,
            repeatMode: .off,
            queue: [t0, t1]
        )
        engine.simulateTrackDataUpdate(staleUpdate)
        
        // Assert: The seek-to-zero lockout must reject the stale 41.5s update for the same track
        XCTAssertLessThanOrEqual(media.currentTime, 3.0, "Lockout must keep currentTime <= 3.0s instead of accepting stale 41.5s")
        
        // Next click naturally advances to Song 0 because currentTime is 0.0s!
        media.previousTrack()
        XCTAssertEqual(media.trackTitle, "Song 0", "Subsequent click advances to Song 0 without requiring 3 tries")
    }
    
    // MARK: - Sandbox Test 4: Queue Section Track Click Dispatches Index Immediately
    @MainActor
    func testClickingQueueTrackInQueueDeckDispatchesQueueIndexWithoutSearchFallback() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        // User is viewing Queue
        media.openQueueSection()
        XCTAssertEqual(media.rightDeckSection, .queue)
        
        let q0 = YTMPlaylistItem(id: "0", title: "Queue Song A", artist: "Artist A", isPlaying: false)
        let q1 = YTMPlaylistItem(id: "1", title: "Queue Song B", artist: "Artist B", isPlaying: true)
        media.playlist = [q0, q1]
        
        var evaluatedScript: String?
        engine.onEvaluate = { script in
            evaluatedScript = script
        }
        
        // User clicks Queue Song A (index 0) to go back in the queue
        media.playSongInSelectedPlaylist(q0)
        
        // Assert: Must invoke playQueueIndex(0) and NOT trigger catalog search
        XCTAssertFalse(media.isSearchingCatalog, "Must not trigger catalog search fallback when playing from queue")
        XCTAssertNotNil(evaluatedScript)
        XCTAssertTrue(evaluatedScript?.contains("playVideoAt(0)") == true, "Must instruct player to playVideoAt(0)")
        XCTAssertEqual(media.trackTitle, "Queue Song A")
        XCTAssertTrue(media.playlist[0].isPlaying)
    }
    
    // MARK: - Sandbox Test 5: Queue Header Back Button Exits Queue on 1st Click
    @MainActor
    func testQueueHeaderBackButtonExitsQueueSectionInSingleClick() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        // User came from Home, then navigated to Queue
        media.openHubHome()
        XCTAssertEqual(media.rightDeckSection, .home)
        
        media.openQueueSection()
        XCTAssertEqual(media.rightDeckSection, .queue)
        XCTAssertNotNil(media.selectedPlaylist, "Queue playlist must be selected when opening queue")
        XCTAssertEqual(media.selectedPlaylist?.id, "pl_queue")
        
        // User clicks the Back button at the top of the Queue
        media.backFromQueue()
        
        // Assert: Must return to Home on the 1st click
        XCTAssertEqual(media.rightDeckSection, .home, "Must immediately exit queue back to Home on 1st click")
        XCTAssertNil(media.selectedPlaylist, "Selected playlist must be cleared")
    }
    
    // MARK: - Sandbox Test 6: Force Previous Video Script Generation
    @MainActor
    func testYouTubeMusicEnginePreviousTrackScriptUsesPreviousVideoDirectlyWhenForced() {
        let engine = YouTubeMusicEngine()
        var evaluatedScript: String?
        engine.onEvaluate = { script in
            evaluatedScript = script
        }
        
        // When forcePreviousTrack is true
        engine.previousTrack(forcePreviousTrack: true)
        
        XCTAssertNotNil(evaluatedScript)
        XCTAssertTrue(evaluatedScript?.contains("p.previousVideo()") == true,
                      "Script must call movie_player.previousVideo() directly to bypass YouTube Music's web player 3-second seek rule")
    }
    
    // MARK: - Sandbox Test 7: Repeat All Loops to End of Queue
    @MainActor
    func testQueuePlaybackLoopingWhenRepeatAll() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        let t0 = YTMPlaylistItem(id: "0", title: "First Track", artist: "Artist A", isPlaying: true, videoId: "v0")
        let t1 = YTMPlaylistItem(id: "1", title: "Middle Track", artist: "Artist B", videoId: "v1")
        let t2 = YTMPlaylistItem(id: "2", title: "Last Track", artist: "Artist C", videoId: "v2")
        media.playlist = [t0, t1, t2]
        media.trackTitle = "First Track"
        media.artistName = "Artist A"
        media.isPlaying = true
        media.currentTime = 0.5 // < 3s
        media.repeatMode = .all
        
        var evaluatedScript: String?
        engine.onEvaluate = { script in
            evaluatedScript = script
        }
        
        media.previousTrack()
        
        XCTAssertEqual(media.trackTitle, "Last Track", "When at track 0 and repeatMode == .all, previousTrack must loop to the last track")
        XCTAssertTrue(media.playlist[2].isPlaying)
        XCTAssertNotNil(evaluatedScript)
        XCTAssertTrue(evaluatedScript?.contains("playVideoAt(2)") == true)
    }
    
    // MARK: - Sandbox Test 8: Live Playback Multi-Track Step Back Under 3 Tries
    @MainActor
    func testLivePlaybackContinuousRapidClicksDoNotRequireThreeTries() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        let t0 = YTMPlaylistItem(id: "0", title: "Song 0", artist: "Artist", videoId: "v0")
        let t1 = YTMPlaylistItem(id: "1", title: "Song 1", artist: "Artist", videoId: "v1")
        let t2 = YTMPlaylistItem(id: "2", title: "Song 2", artist: "Artist", isPlaying: true, videoId: "v2")
        let t3 = YTMPlaylistItem(id: "3", title: "Song 3", artist: "Artist", videoId: "v3")
        media.playlist = [t0, t1, t2, t3]
        media.trackTitle = "Song 2"
        media.artistName = "Artist"
        media.isPlaying = true
        media.currentTime = 55.0 // actively playing
        
        // Click 1: Seeks to 0
        media.previousTrack()
        XCTAssertEqual(media.currentTime, 0.0)
        XCTAssertEqual(media.trackTitle, "Song 2")
        
        // Click 2 (<2.0s): Intentional double-click back -> must immediately be Song 1
        media.previousTrack()
        XCTAssertEqual(media.trackTitle, "Song 1", "Second click must immediately transition to Song 1, never requiring 3 clicks")
        XCTAssertTrue(media.playlist[1].isPlaying)
        
        // While Song 1 is playing at 1.0s (<3s):
        media.currentTime = 1.0
        // Click 1: Must immediately transition to Song 0 on 1st click
        media.previousTrack()
        XCTAssertEqual(media.trackTitle, "Song 0", "First click when under 3s must immediately transition to Song 0")
        XCTAssertTrue(media.playlist[0].isPlaying)
    }
}
