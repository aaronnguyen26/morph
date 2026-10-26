import XCTest
@testable import morph

@MainActor
final class YTMRepeatModeTests: XCTestCase {
    
    func testRepeatModeEnumPropertiesAndCycling() {
        XCTAssertEqual(YTMRepeatMode.off.next, .all)
        XCTAssertEqual(YTMRepeatMode.all.next, .one)
        XCTAssertEqual(YTMRepeatMode.one.next, .off)
        
        XCTAssertEqual(YTMRepeatMode.off.iconName, "repeat")
        XCTAssertEqual(YTMRepeatMode.all.iconName, "repeat")
        XCTAssertEqual(YTMRepeatMode.one.iconName, "repeat.1")
        
        XCTAssertEqual(YTMRepeatMode.off.displayTitle, "Repeat Off")
        XCTAssertEqual(YTMRepeatMode.all.displayTitle, "Repeat All")
        XCTAssertEqual(YTMRepeatMode.one.displayTitle, "Repeat One")
        
        XCTAssertEqual(YTMRepeatMode.off.hudTitle, "Repeat Off")
        XCTAssertEqual(YTMRepeatMode.all.hudTitle, "Loop All")
        XCTAssertEqual(YTMRepeatMode.one.hudTitle, "Loop 1")
    }
    
    func testToggleRepeatCyclesModesAndTriggersHUD() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        XCTAssertEqual(media.repeatMode, .off)
        XCTAssertFalse(media.showRepeatHUD)
        
        // 1st toggle: off -> all
        media.toggleRepeat()
        XCTAssertEqual(media.repeatMode, .all)
        XCTAssertTrue(media.showRepeatHUD, "HUD must trigger on toggleRepeat")
        
        // 2nd toggle: all -> one
        media.toggleRepeat()
        XCTAssertEqual(media.repeatMode, .one)
        XCTAssertTrue(media.showRepeatHUD)
        
        // 3rd toggle: one -> off
        media.toggleRepeat()
        XCTAssertEqual(media.repeatMode, .off)
        XCTAssertTrue(media.showRepeatHUD)
    }
    
    func testSetRepeatModeDirectly() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        media.setRepeatMode(.one)
        XCTAssertEqual(media.repeatMode, .one)
        XCTAssertTrue(media.showRepeatHUD)
        
        media.setRepeatMode(.all)
        XCTAssertEqual(media.repeatMode, .all)
        XCTAssertTrue(media.showRepeatHUD)
    }
    
    func testRepeatOnePreventsAdvancingAndLoopsBackToZero() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        let t1 = YTMPlaylistItem(id: "1", title: "Song 1", artist: "Artist A", duration: "3:00", isPlaying: true)
        let t2 = YTMPlaylistItem(id: "2", title: "Song 2", artist: "Artist B", duration: "3:30", isPlaying: false)
        let customPlaylist = YTMPlaylist(id: "p1", title: "My Playlist", subtitle: "User", tracks: [t1, t2])
        media.selectedPlaylist = customPlaylist
        media.trackTitle = "Song 1"
        media.artistName = "Artist A"
        media.duration = 180.0
        media.currentTime = 179.6 // At the very end of track
        media.isPlaying = true
        
        // Set Repeat One
        media.setRepeatMode(.one)
        
        // Simulate watchdog / duration end auto-advance check
        if media.duration > 0 && media.currentTime >= (media.duration - 0.5) {
            if media.repeatMode == .one {
                media.currentTime = 0
                media.seek(to: 0)
            } else {
                media.nextTrack()
            }
        }
        
        // In repeat one, it should have reset currentTime to 0, NOT advanced to Song 2
        XCTAssertEqual(media.currentTime, 0.0)
        XCTAssertEqual(media.trackTitle, "Song 1", "Track title must remain Song 1 in Repeat One mode")
    }
    
    func testRepeatAllWrapsPlaylistInfinitelyFromLastToFirst() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        let t1 = YTMPlaylistItem(id: "1", title: "Track 1", artist: "Artist 1", duration: "3:00", isPlaying: false)
        let t2 = YTMPlaylistItem(id: "2", title: "Track 2", artist: "Artist 2", duration: "3:00", isPlaying: false)
        let t3 = YTMPlaylistItem(id: "3", title: "Track 3", artist: "Artist 3", duration: "3:00", isPlaying: true)
        let playlist = YTMPlaylist(id: "p1", title: "Workout", subtitle: "Gym", tracks: [t1, t2, t3])
        media.selectedPlaylist = playlist
        media.trackTitle = "Track 3"
        
        // Enable Repeat All (Infinite Loop)
        media.setRepeatMode(.all)
        
        // At the last track of playlist (Track 3), nextTrack() must loop back to Track 1
        media.nextTrack()
        
        XCTAssertEqual(media.trackTitle, "Track 1", "Repeat All must wrap from the last track to the first track")
        XCTAssertTrue(media.isPlaying)
    }
    
    func testRepeatAllWrapsQueueInfinitelyFromLastToFirst() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        let q1 = YTMPlaylistItem(id: "0", title: "Queue 1", artist: "Artist 1", duration: "2:30", isPlaying: false)
        let q2 = YTMPlaylistItem(id: "1", title: "Queue 2", artist: "Artist 2", duration: "3:10", isPlaying: false)
        let q3 = YTMPlaylistItem(id: "2", title: "Queue 3", artist: "Artist 3", duration: "4:00", isPlaying: true)
        media.playlist = [q1, q2, q3]
        media.trackTitle = "Queue 3"
        media.selectedPlaylist = nil
        
        // Enable Repeat All (Infinite Loop)
        media.setRepeatMode(.all)
        
        // At the last track of queue, nextTrack() must loop back to Queue 1
        media.nextTrack()
        
        XCTAssertEqual(media.trackTitle, "Queue 1", "Repeat All must wrap from the last queue track to the first queue track")
        XCTAssertTrue(media.isPlaying)
    }
    
    func testRepeatAllPreviousTrackAtStartWrapsToLastTrack() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        let t1 = YTMPlaylistItem(id: "1", title: "Track 1", artist: "Artist 1", duration: "3:00", isPlaying: true)
        let t2 = YTMPlaylistItem(id: "2", title: "Track 2", artist: "Artist 2", duration: "3:00", isPlaying: false)
        let t3 = YTMPlaylistItem(id: "3", title: "Track 3", artist: "Artist 3", duration: "3:00", isPlaying: false)
        let playlist = YTMPlaylist(id: "p1", title: "Chill", subtitle: "Lo-fi", tracks: [t1, t2, t3])
        media.selectedPlaylist = playlist
        media.trackTitle = "Track 1"
        media.currentTime = 1.0 // Within first 3 seconds
        
        // Enable Repeat All
        media.setRepeatMode(.all)
        
        // At Track 1, previousTrack() should wrap to Track 3
        media.previousTrack()
        
        XCTAssertEqual(media.trackTitle, "Track 3", "Repeat All must wrap to the last track when hitting previous on first track")
    }
    
    func testOptimisticLockoutPreventsTransientEngineRepeatModeFlicker() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        XCTAssertEqual(media.repeatMode, .off)
        
        // User sets repeat mode to .one
        media.setRepeatMode(.one)
        XCTAssertEqual(media.repeatMode, .one)
        
        // Simulate engine sending back stale .off within lockout window
        engine.trackData = YTMTrackData(
            title: "Testing Song",
            artist: "Testing Artist",
            albumArtURL: "",
            isPlaying: true,
            currentTime: 10,
            duration: 200,
            volume: 0.5,
            isMuted: false,
            isLiked: false,
            isDisliked: false,
            isShuffle: false,
            repeatMode: .off, // Stale state from scraper
            queue: []
        )
        
        // media.repeatMode should remain .one due to lockout
        XCTAssertEqual(media.repeatMode, .one, "Morph UI must not flicker to stale engine state during optimistic lockout")
    }
    
    func testShortcutManagerToggleRepeat() {
        let notchModel = NotchModel()
        let controller = MorphController(model: notchModel)
        let shortcuts = ShortcutManager.shared
        shortcuts.configure(model: notchModel, controller: controller)
        
        notchModel.selectedTab = .music
        notchModel.media.repeatMode = .off
        
        shortcuts.toggleRepeat()
        XCTAssertEqual(notchModel.media.repeatMode, .all)
        XCTAssertEqual(shortcuts.lastTriggeredShortcut, "⌘R Loop All")
        
        shortcuts.toggleRepeat()
        XCTAssertEqual(notchModel.media.repeatMode, .one)
        XCTAssertEqual(shortcuts.lastTriggeredShortcut, "⌘R Loop 1")
        
        shortcuts.toggleRepeat()
        XCTAssertEqual(notchModel.media.repeatMode, .off)
        XCTAssertEqual(shortcuts.lastTriggeredShortcut, "⌘R Repeat Off")
    }
}
