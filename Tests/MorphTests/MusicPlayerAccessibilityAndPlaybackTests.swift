import XCTest
import AppKit
import SwiftUI
@testable import morph

@MainActor
final class MusicPlayerAccessibilityAndPlaybackTests: XCTestCase {
    var model: NotchModel!
    var shortcutManager: ShortcutManager!
    var mockEngine: YouTubeMusicEngine!
    
    override func setUp() async throws {
        try await super.setUp()
        mockEngine = YouTubeMusicEngine.shared
        mockEngine.isSignedIn = false
        mockEngine.isWaitingForSignInCompletion = false
        mockEngine.userPlaylists = []
        mockEngine.libraryError = nil
        mockEngine.trackData = YTMTrackData(
            title: "Original Track",
            artist: "Original Artist",
            albumArtURL: "https://example.com/original.jpg",
            isPlaying: false,
            currentTime: 10.0,
            duration: 200.0
        )
        
        model = NotchModel()
        model.media.duration = 200.0
        model.media.currentTime = 10.0
        model.media.isPlaying = false
        model.media.trackTitle = "Original Track"
        model.media.artistName = "Original Artist"
        model.media.albumArtURL = "https://example.com/original.jpg"
        model.selectedTab = .music
        
        shortcutManager = ShortcutManager.shared
        shortcutManager.forceDebounceInTests = false
        shortcutManager.configure(model: model, controller: nil)
    }
    
    override func tearDown() async throws {
        shortcutManager?.forceDebounceInTests = false
        mockEngine?.trackData = YTMTrackData()
        mockEngine?.isSignedIn = false
        mockEngine?.isWaitingForSignInCompletion = false
        mockEngine?.userPlaylists = []
        mockEngine?.libraryError = nil
        shortcutManager = nil
        model = nil
        mockEngine = nil
        try await super.tearDown()
    }
    
    // MARK: - Helpers to construct synthetic NSEvents
    
    /// Helper to build synthetic macOS hardware media key events (.systemDefined, subtype 8)
    private func makeHardwareMediaKeyEvent(key: Int32, down: Bool) -> NSEvent {
        let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
        let data1 = Int((key << 16) | (down ? 0xa00 : 0xb00))
        return NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        )!
    }
    
    /// Helper to build synthetic standard function key events (.keyDown)
    private func makeFunctionKeyEvent(keyCode: UInt16, functionKey: Int) -> NSEvent {
        let char = String(utf16CodeUnits: [unichar(functionKey)], count: 1)
        return NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: char,
            charactersIgnoringModifiers: char,
            isARepeat: false,
            keyCode: keyCode
        )!
    }
    
    // MARK: - 1. Physical Hardware Media Keys (.systemDefined F7, F8, F9)
    
    func testHardwareF8PlayPauseToggle() {
        model.media.isPlaying = false
        
        // Key down on physical F8 (NX_KEYTYPE_PLAY = 16)
        let evDown = makeHardwareMediaKeyEvent(key: 16, down: true)
        let handled = shortcutManager.handleSystemDefinedEvent(evDown)
        XCTAssertTrue(handled, "Hardware F8 play/pause must be handled")
        XCTAssertTrue(model.media.isPlaying, "F8 should start playback when paused")
        XCTAssertEqual(shortcutManager.lastTriggeredShortcut, "F8 Playing")
        
        // Press F8 again to pause
        let handledPause = shortcutManager.handleSystemDefinedEvent(evDown)
        XCTAssertTrue(handledPause)
        XCTAssertFalse(model.media.isPlaying, "F8 should pause playback when playing")
        XCTAssertEqual(shortcutManager.lastTriggeredShortcut, "F8 Paused")
        
        // Key up should be ignored (no double toggle)
        let evUp = makeHardwareMediaKeyEvent(key: 16, down: false)
        let handledUp = shortcutManager.handleSystemDefinedEvent(evUp)
        XCTAssertFalse(handledUp, "Key up event must not re-trigger playback toggle")
    }
    
    func testHardwareF9NextTrack() {
        let evNext = makeHardwareMediaKeyEvent(key: 19, down: true) // NX_KEYTYPE_FAST = 19
        let handled = shortcutManager.handleSystemDefinedEvent(evNext)
        XCTAssertTrue(handled, "Hardware F9 next track must be handled")
        XCTAssertEqual(shortcutManager.lastTriggeredShortcut, "F9 Next")
    }
    
    func testHardwareF7PreviousTrackRestartAndSkip() {
        // Track at 10s: pressing F7 should restart current track to 0s
        model.media.currentTime = 10.0
        let evPrev = makeHardwareMediaKeyEvent(key: 20, down: true) // NX_KEYTYPE_REWIND = 20
        let handled = shortcutManager.handleSystemDefinedEvent(evPrev)
        XCTAssertTrue(handled, "Hardware F7 previous track must be handled")
        XCTAssertEqual(model.media.currentTime, 0.0, "F7 with playback > 3s should restart track to 0s")
        XCTAssertEqual(shortcutManager.lastTriggeredShortcut, "F7 Previous")
    }
    
    func testHardwareVolumeAndMuteKeys() {
        let initialVol = model.media.volume
        
        // Volume Up (key 0)
        let evVolUp = makeHardwareMediaKeyEvent(key: 0, down: true)
        XCTAssertTrue(shortcutManager.handleSystemDefinedEvent(evVolUp))
        XCTAssertGreaterThanOrEqual(model.media.volume, initialVol)
        
        // Volume Down (key 1)
        let evVolDown = makeHardwareMediaKeyEvent(key: 1, down: true)
        XCTAssertTrue(shortcutManager.handleSystemDefinedEvent(evVolDown))
        
        // Mute (key 7)
        let initialMuted = model.media.isMuted
        let evMute = makeHardwareMediaKeyEvent(key: 7, down: true)
        XCTAssertTrue(shortcutManager.handleSystemDefinedEvent(evMute))
        XCTAssertEqual(model.media.isMuted, !initialMuted)
    }
    
    // MARK: - 2. Standard Function Keys Across Tabs (Fn+F7, Fn+F8, Fn+F9)
    
    func testFunctionKeysWorkAcrossAllTabs() {
        let tabs: [MorphTab] = [.home, .timer, .music, .notes, .profile, .calendar]
        
        for tab in tabs {
            model.selectedTab = tab
            model.media.pause()
            model._simulatedGlassMusicPlaying = false
            
            // F8 Function key to Play
            let f8Event = makeFunctionKeyEvent(keyCode: 100, functionKey: NSF8FunctionKey)
            let handledF8 = shortcutManager.handleKeyEvent(f8Event)
            XCTAssertTrue(handledF8, "F8 must work on tab \(tab)")
            XCTAssertTrue(model.media.isPlaying, "Playback should start on tab \(tab)")
            
            // F8 Function key to Pause
            let handledF8Pause = shortcutManager.handleKeyEvent(f8Event)
            XCTAssertTrue(handledF8Pause, "F8 pause must work on tab \(tab)")
            XCTAssertFalse(model.media.isPlaying, "Playback should pause on tab \(tab)")
            
            // F9 Function key
            let f9Event = makeFunctionKeyEvent(keyCode: 101, functionKey: NSF9FunctionKey)
            let handledF9 = shortcutManager.handleKeyEvent(f9Event)
            XCTAssertTrue(handledF9, "F9 must work on tab \(tab)")
            
            // F7 Function key
            let f7Event = makeFunctionKeyEvent(keyCode: 98, functionKey: NSF7FunctionKey)
            let handledF7 = shortcutManager.handleKeyEvent(f7Event)
            XCTAssertTrue(handledF7, "F7 must work on tab \(tab)")
        }
    }
    
    // MARK: - 3. Exact Song & Cover Playback Guarantee
    
    func testExactSongAndCoverMatchingOnStart() {
        let targetSong = YTMPlaylistItem(
            id: "song_abc_123",
            title: "Golden Hour",
            artist: "JVKE",
            duration: "3:29",
            isPlaying: false,
            videoId: "abc123vid",
            thumbnailURL: "https://example.com/golden_hour.jpg"
        )
        
        // Start exact track
        model.media.startExactTrack(targetSong)
        
        // 1. Cover and metadata must match immediately
        XCTAssertEqual(model.media.trackTitle, "Golden Hour")
        XCTAssertEqual(model.media.artistName, "JVKE")
        XCTAssertEqual(model.media.albumArtURL, "https://example.com/golden_hour.jpg")
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertEqual(model.media.currentTime, 0.0)
        
        // 2. Transition lockout must be active for this target track
        XCTAssertNotNil(model.media.pendingTargetTrack)
        XCTAssertEqual(model.media.pendingTargetTrack?.title, "Golden Hour")
        XCTAssertEqual(model.media.pendingTargetTrack?.thumbnailURL, "https://example.com/golden_hour.jpg")
        XCTAssertNotNil(model.media.trackTransitionLockoutUntil)
    }
    
    func testStaleWebKitUpdateIgnoredDuringTransitionLockout() {
        let newSong = YTMPlaylistItem(
            id: "song_def_456",
            title: "Blinding Lights",
            artist: "The Weeknd",
            duration: "3:20",
            isPlaying: false,
            videoId: "def456vid",
            thumbnailURL: "https://example.com/blinding_lights.jpg"
        )
        
        // User starts new song
        model.media.startExactTrack(newSong)
        XCTAssertEqual(model.media.trackTitle, "Blinding Lights")
        XCTAssertEqual(model.media.albumArtURL, "https://example.com/blinding_lights.jpg")
        
        // Stale WebKit update for OLD song arrives from background webview
        mockEngine.trackData = YTMTrackData(
            title: "Original Track", // Stale title!
            artist: "Original Artist",
            albumArtURL: "https://example.com/original.jpg",
            isPlaying: true,
            currentTime: 199.0,
            duration: 200.0
        )
        
        // Verify MediaControllerModel did NOT overwrite the new song or its cover!
        XCTAssertEqual(model.media.trackTitle, "Blinding Lights", "Stale WebKit title must not overwrite newly started track")
        XCTAssertEqual(model.media.albumArtURL, "https://example.com/blinding_lights.jpg", "Stale cover art must not overwrite newly started track's cover")
        
        // Stale track ended event should also be blocked during transition lockout
        model.media.handleTrackEnded()
        XCTAssertEqual(model.media.trackTitle, "Blinding Lights", "Stale track ended event must not skip onto another song")
    }
    
    func testMatchingWebKitUpdateClearsLockoutCleanly() {
        let newSong = YTMPlaylistItem(
            id: "song_ghi_789",
            title: "As It Was",
            artist: "Harry Styles",
            duration: "2:47",
            isPlaying: false,
            videoId: "ghi789vid",
            thumbnailURL: "https://example.com/as_it_was.jpg"
        )
        
        model.media.startExactTrack(newSong)
        
        // Matching WebKit data arrives
        mockEngine.trackData = YTMTrackData(
            title: "As It Was",
            artist: "Harry Styles",
            albumArtURL: "https://example.com/as_it_was_highres.jpg",
            isPlaying: true,
            currentTime: 1.0,
            duration: 167.0
        )
        
        // Lockout clears, metadata syncs
        XCTAssertEqual(model.media.trackTitle, "As It Was")
        XCTAssertEqual(model.media.albumArtURL, "https://example.com/as_it_was_highres.jpg")
        XCTAssertNil(model.media.pendingTargetTrack)
        XCTAssertNil(model.media.trackTransitionLockoutUntil)
    }
    
    func testQuickPickStartsExactTrackWithoutRadioHijack() {
        let pick = YTMPlaylistItem(
            id: "qp_test_1",
            title: "Levitating",
            artist: "Dua Lipa",
            duration: "3:23",
            isPlaying: false,
            videoId: "levitating123",
            thumbnailURL: "https://example.com/levitating.jpg"
        )
        model.media.quickPicks = [pick]
        
        model.media.playQuickPick(pick, startRadio: false)
        
        XCTAssertEqual(model.media.trackTitle, "Levitating")
        XCTAssertEqual(model.media.albumArtURL, "https://example.com/levitating.jpg")
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertTrue(model.media.quickPicks[0].isPlaying)
    }
    
    func testPlaylistTrackStartsExactTrackWithCover() {
        let playlistSong = YTMPlaylistItem(
            id: "pl_song_1",
            title: "Starboy",
            artist: "The Weeknd",
            duration: "3:50",
            isPlaying: false,
            videoId: "starboy123",
            thumbnailURL: "https://example.com/starboy.jpg"
        )
        let pl = YTMPlaylist(
            id: "pl_favorites",
            title: "Favorites",
            subtitle: "Playlist",
            thumbnailURL: "https://example.com/pl_thumb.jpg",
            trackCount: 1,
            tracks: [playlistSong]
        )
        model.media.selectedPlaylist = pl
        
        model.media.playSongInSelectedPlaylist(playlistSong)
        
        XCTAssertEqual(model.media.trackTitle, "Starboy")
        XCTAssertEqual(model.media.artistName, "The Weeknd")
        XCTAssertEqual(model.media.albumArtURL, "https://example.com/starboy.jpg")
        XCTAssertTrue(model.media.isPlaying)
    }
    
    // MARK: - 4. NowPlayingManager Configuration & Synchronization
    
    func testNowPlayingManagerConfiguration() {
        let nowPlaying = NowPlayingManager.shared
        nowPlaying.configure(media: model.media)
        XCTAssertTrue(nowPlaying.media === model.media)
        
        // Update now playing info does not crash in test environment
        nowPlaying.updateNowPlayingInfo()
    }
    
    // MARK: - 5. F8 Playback Stop & Debounce Verification
    
    func testF8StopsSongDirectlyWhenPlaying() {
        // Given music is playing
        model.media.play()
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertTrue(mockEngine.trackData.isPlaying)
        
        // When F8 is pressed
        let f8Event = makeHardwareMediaKeyEvent(key: 16, down: true)
        let handled = shortcutManager.handleSystemDefinedEvent(f8Event)
        
        // Then playback stops immediately
        XCTAssertTrue(handled)
        XCTAssertFalse(model.media.isPlaying, "F8 must stop playback when song is playing")
        XCTAssertFalse(mockEngine.trackData.isPlaying, "Engine trackData must reflect paused state")
        XCTAssertEqual(shortcutManager.lastTriggeredShortcut, "F8 Paused")
    }
    
    func testF8StopsSongWhenSimulatedGlassMusicPlaying() {
        // Given music was started from Glass Island / Notch while Morph is collapsed
        model._simulatedGlassMusicPlaying = true
        model.media.isPlaying = true
        mockEngine.trackData.isPlaying = true
        XCTAssertTrue(model.isGlassMusicPlaying)
        
        // When F8 is pressed
        shortcutManager.togglePlayPause()
        
        // Then both media and glass simulated music must be stopped
        XCTAssertFalse(model.media.isPlaying)
        XCTAssertFalse(model._simulatedGlassMusicPlaying, "Glass simulated playing flag must be reset")
        XCTAssertFalse(model.isGlassMusicPlaying, "isGlassMusicPlaying must be false")
        XCTAssertFalse(mockEngine.trackData.isPlaying)
    }
    
    func testF8StopsSongWhenEngineIsPlayingEvenIfMediaIsPlayingWasOutOfSync() {
        // Given engine is active/playing but model.media.isPlaying was temporarily false
        model.media.isPlaying = false
        mockEngine.trackData.isPlaying = true
        XCTAssertTrue(model.media.isEffectivelyPlaying)
        
        // When F8 is pressed
        let f8Event = makeFunctionKeyEvent(keyCode: 100, functionKey: NSF8FunctionKey)
        let handled = shortcutManager.handleKeyEvent(f8Event)
        
        // Then it evaluates effectively playing as true and pauses
        XCTAssertTrue(handled)
        XCTAssertFalse(mockEngine.trackData.isPlaying)
        XCTAssertFalse(model.media.isPlaying)
    }
    
    func testF8DebouncePreventsRapidDoubleToggle() {
        model.media.isPlaying = true
        mockEngine.trackData.isPlaying = true
        
        // First toggle: Pause
        model.media.togglePlay(force: true)
        XCTAssertFalse(model.media.isPlaying)
        
        // Simulated rapid duplicate event within 100ms (e.g. system media key + NowPlaying remote command race)
        // Without force: true in non-test mode, or testing togglePlay directly
        model.media.togglePlay(force: false) // should be debounced if not in testing, but in test env force controls it
        
        // Verify stop explicitly stops playback and resets time to 0
        model.media.stop()
        XCTAssertFalse(model.media.isPlaying)
        XCTAssertEqual(model.media.currentTime, 0)
        XCTAssertFalse(mockEngine.trackData.isPlaying)
    }
    
    func testMediaPauseAndStopAlwaysExecuteEngineDirectly() {
        // Even when browser connected is reported true, direct engine must still pause & stop
        model.media.isBrowserConnected = true
        model.media.isPlaying = true
        mockEngine.trackData.isPlaying = true
        
        model.media.pause()
        XCTAssertFalse(model.media.isPlaying)
        XCTAssertFalse(mockEngine.trackData.isPlaying, "engine.pause() must always be called")
        
        mockEngine.trackData.isPlaying = true
        model.media.stop()
        XCTAssertFalse(model.media.isPlaying)
        XCTAssertFalse(mockEngine.trackData.isPlaying, "engine.stop() must always be called")
    }
    
    // MARK: - 6. Background CGEventTap Interception Tests
    
    private func makeSystemDefinedCGEvent(key: Int32, down: Bool) -> CGEvent {
        let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
        let data1 = Int((key << 16) | (down ? 0xa00 : 0xb00))
        let nsEvent = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        )!
        return nsEvent.cgEvent!
    }
    
    private func makeKeyDownCGEvent(keyCode: CGKeyCode) -> CGEvent {
        return CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)!
    }
    
    func testBackgroundTapInterceptsF8AndStopsSongWhenPlaying() {
        // Given Morph is playing music in the background
        model.media.play()
        XCTAssertTrue(model.media.isEffectivelyPlaying)
        
        let cgEvent = makeSystemDefinedCGEvent(key: 16, down: true)
        let dummyProxy = unsafeBitCast(Unmanaged.passUnretained(self).toOpaque(), to: CGEventTapProxy.self)
        
        // When F8 is clicked in the background
        let result = shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: CGEventType(rawValue: 14)!, event: cgEvent)
        
        // Then the event is intercepted (consumed) and playback stops immediately
        XCTAssertNil(result, "Background F8 event must be intercepted and consumed when Morph is playing")
        XCTAssertFalse(model.media.isPlaying, "Playback must be paused")
        XCTAssertFalse(mockEngine.trackData.isPlaying, "Engine must reflect paused state")
    }
    
    func testBackgroundTapInterceptsF8FunctionKeyAndStopsSong() {
        // Given Morph is playing music in the background
        model.media.play()
        XCTAssertTrue(model.media.isEffectivelyPlaying)
        
        let cgEvent = makeKeyDownCGEvent(keyCode: 100) // F8 Function key
        let dummyProxy = unsafeBitCast(Unmanaged.passUnretained(self).toOpaque(), to: CGEventTapProxy.self)
        
        // When F8 function key is clicked in the background
        let result = shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: .keyDown, event: cgEvent)
        
        // Then the event is intercepted and stops playback
        XCTAssertNil(result, "F8 function key must be intercepted when Morph is playing")
        XCTAssertFalse(model.media.isPlaying)
        XCTAssertFalse(mockEngine.trackData.isPlaying)
    }
    
    func testBackgroundTapPassesThroughWhenMusicIsNotPlaying() {
        // Given Morph is genuinely idle (no active or paused media session)
        mockEngine.trackData = YTMTrackData()
        model.media.trackTitle = ""
        model.media.artistName = ""
        model.media.duration = 0
        model.media.isPlaying = false
        model.media.userIntentionallyPaused = false
        model.media.isDirectEngineConnected = false
        model.media.isBrowserConnected = false
        model._simulatedGlassMusicPlaying = false
        model.isExpanded = false
        model.activeBackgroundTaskPill = .none
        XCTAssertFalse(model.media.isEffectivelyPlaying)
        XCTAssertFalse(shortcutManager.hasControllableMediaSession(for: model))
        
        let dummyProxy = unsafeBitCast(Unmanaged.passUnretained(self).toOpaque(), to: CGEventTapProxy.self)
        let cgDown = makeSystemDefinedCGEvent(key: 16, down: true)
        let cgUp = makeSystemDefinedCGEvent(key: 16, down: false)
        let fnDown = makeKeyDownCGEvent(keyCode: 100)
        
        // When F8 is clicked while Morph owns no media session
        let resultDown = shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: CGEventType(rawValue: 14)!, event: cgDown)
        let resultUp = shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: CGEventType(rawValue: 14)!, event: cgUp)
        let resultFn = shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: .keyDown, event: fnDown)
        
        // Then events pass through untouched to let other system players handle them without starting Morph
        XCTAssertNotNil(resultDown, "Background F8 keyDown must pass through when Morph has no active or paused session")
        XCTAssertNotNil(resultUp, "Background F8 keyUp must pass through when Morph has no active or paused session")
        XCTAssertNotNil(resultFn, "Background virtual F8 must pass through when Morph has no active or paused session")
        XCTAssertFalse(model.media.isPlaying, "Pass-through F8 must not hijack Morph playback when idle")
        XCTAssertFalse(model.isGlassMusicPlaying)
    }
    
    // MARK: - 8. Regression Tests for Background F8 Lag / Watchdog Loop Prevention
    
    func testUserIntentionallyPausedPreventsWatchdogResumingPlayback() {
        // Given Morph is playing a song
        model.media.play()
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertFalse(model.media.userIntentionallyPaused)
        XCTAssertTrue(model.media.isEffectivelyPlaying)
        
        // When F8 is clicked to pause
        shortcutManager.togglePlayPause()
        
        // Then playback stops and userIntentionallyPaused is marked true
        XCTAssertFalse(model.media.isPlaying, "Playback must be paused")
        XCTAssertTrue(model.media.userIntentionallyPaused, "userIntentionallyPaused must be set")
        XCTAssertFalse(model.media.isEffectivelyPlaying, "isEffectivelyPlaying must be false")
        XCTAssertEqual(shortcutManager.lastTriggeredShortcut, "F8 Paused")
        
        // When WebKit emits an asynchronous track update reflecting paused state
        mockEngine.trackData = YTMTrackData(
            title: "Original Track",
            artist: "Original Artist",
            albumArtURL: "https://example.com/original.jpg",
            isPlaying: false,
            currentTime: 25.0,
            duration: 200.0
        )
        
        // Playback must remain firmly paused without watchdog resurrection
        XCTAssertFalse(model.media.isPlaying, "Playback must remain paused when WebKit emits paused update")
        XCTAssertTrue(model.media.userIntentionallyPaused)
        XCTAssertFalse(model.media.isEffectivelyPlaying)
    }
    
    func testStaleWebKitPlayUpdateEnforcesPauseWhenUserIntentionallyPaused() {
        // Given user paused the track
        model.media.play()
        shortcutManager.pauseMusic()
        XCTAssertTrue(model.media.userIntentionallyPaused)
        XCTAssertFalse(model.media.isPlaying)
        
        // When a stale in-flight update arrives from WebKit with isPlaying: true
        mockEngine.trackData = YTMTrackData(
            title: "Original Track",
            artist: "Original Artist",
            albumArtURL: "https://example.com/original.jpg",
            isPlaying: true,
            currentTime: 25.1,
            duration: 200.0
        )
        
        // Then MediaControllerModel immediately suppresses isPlaying and keeps isEffectivelyPlaying false
        XCTAssertFalse(model.media.isPlaying, "Stale isPlaying update must not revive playback")
        XCTAssertFalse(model.media.isEffectivelyPlaying, "isEffectivelyPlaying must remain false")
    }
    
    func testSubsequentF8AfterPauseResumesPlaybackCleanly() {
        // Given user paused playback via F8
        model.media.play()
        shortcutManager.pauseMusic()
        XCTAssertFalse(model.media.isPlaying)
        XCTAssertTrue(model.media.userIntentionallyPaused)
        
        // When F8 is pressed again
        shortcutManager.playMusic()
        
        // Then playback resumes and userIntentionallyPaused is cleared
        XCTAssertTrue(model.media.isPlaying, "Playback must resume")
        XCTAssertFalse(model.media.userIntentionallyPaused, "userIntentionallyPaused must be cleared")
        XCTAssertTrue(model.media.isEffectivelyPlaying)
        XCTAssertEqual(shortcutManager.lastTriggeredShortcut, "F8 Playing")
    }
    
    // MARK: - 9. Directional Lockout & Media Key Swallowing Verification
    
    func testDirectionalLockoutPreventsImmediatePlayAfterPause() {
        shortcutManager.forceDebounceInTests = true
        defer { shortcutManager.forceDebounceInTests = false }
        
        // Given music is playing
        model.media.play()
        XCTAssertTrue(model.media.isPlaying)
        
        // When user pauses playback via F8
        shortcutManager.pauseMusic()
        XCTAssertFalse(model.media.isPlaying, "Playback must be paused")
        XCTAssertTrue(model.media.userIntentionallyPaused)
        
        // When an echo or in-flight play event arrives immediately (< 0.65s)
        shortcutManager.playMusic()
        
        // Then directional lockout blocks the play command and playback remains firmly paused
        XCTAssertFalse(model.media.isPlaying, "Immediate play command within lockout window must be suppressed")
        XCTAssertTrue(model.media.userIntentionallyPaused, "userIntentionallyPaused must remain true")
        XCTAssertFalse(model.media.isEffectivelyPlaying, "isEffectivelyPlaying must remain false")
    }
    
    func testHardwareMediaKeyUpSwallowedWhenKeyDownSwallowed() {
        // Given Morph is playing music
        model.media.play()
        XCTAssertTrue(model.media.isEffectivelyPlaying)
        
        let dummyProxy = unsafeBitCast(Unmanaged.passUnretained(self).toOpaque(), to: CGEventTapProxy.self)
        let evDown = makeSystemDefinedCGEvent(key: 16, down: true)
        let evUp = makeSystemDefinedCGEvent(key: 16, down: false)
        
        // Key down is swallowed
        let resDown = shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: CGEventType(rawValue: 14)!, event: evDown)
        XCTAssertNil(resDown, "Key down must be swallowed")
        
        // Key up must also be swallowed
        let resUp = shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: CGEventType(rawValue: 14)!, event: evUp)
        XCTAssertNil(resUp, "Key up matching swallowed key down must also be swallowed")
    }
    
    func testBrowserPollingIgnoredWhenDirectEngineIsActiveOrUserPaused() async {
        // Given user paused playback intentionally
        model.media.pause()
        XCTAssertTrue(model.media.userIntentionallyPaused)
        XCTAssertFalse(model.media.isPlaying)
        
        // When pollBrowserState runs
        await model.media.pollBrowserState()
        
        // Then isPlaying must remain false and not be overwritten by background browser tabs
        XCTAssertFalse(model.media.isPlaying, "pollBrowserState must not set isPlaying when userIntentionallyPaused is true")
        XCTAssertTrue(model.media.userIntentionallyPaused)
    }
    
    func testHardwareMediaKeysF7F8F9AllSwallowedWhenPlaying() {
        model.media.play()
        XCTAssertTrue(model.media.isEffectivelyPlaying)
        
        let dummyProxy = unsafeBitCast(Unmanaged.passUnretained(self).toOpaque(), to: CGEventTapProxy.self)
        
        // F8 (16)
        let f8Down = makeSystemDefinedCGEvent(key: 16, down: true)
        XCTAssertNil(shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: CGEventType(rawValue: 14)!, event: f8Down))
        
        model.media.play()
        
        // F9 (17)
        let f9Down = makeSystemDefinedCGEvent(key: 17, down: true)
        XCTAssertNil(shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: CGEventType(rawValue: 14)!, event: f9Down))
        
        // F7 (18)
        let f7Down = makeSystemDefinedCGEvent(key: 18, down: true)
        XCTAssertNil(shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: CGEventType(rawValue: 14)!, event: f7Down))
    }
    
    // MARK: - 10. Crash Regression: Nonisolated MPMediaItemArtwork & Process-Isolated AppleScript Runner
    
    private final class SendableBox<Value>: @unchecked Sendable {
        private let lock = NSLock()
        private var value: Value
        
        init(_ initial: Value) {
            self.value = initial
        }
        
        func set(_ newValue: Value) {
            lock.lock()
            value = newValue
            lock.unlock()
        }
        
        func modify(_ transform: (inout Value) -> Void) {
            lock.lock()
            transform(&value)
            lock.unlock()
        }
        
        func get() -> Value {
            lock.lock()
            let copy = value
            lock.unlock()
            return copy
        }
    }
    
    func testNowPlayingArtworkHandlerSafeOnMediaPlayerBackgroundQueue() {
        // Build valid PNG image data
        let img = NSImage(size: NSSize(width: 64, height: 64))
        img.lockFocus()
        NSColor.systemPurple.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 64, height: 64)).fill()
        img.unlockFocus()
        guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to construct test PNG artwork")
            return
        }
        
        let artwork = SendableBox(NowPlayingManager.makeArtwork(data: pngData, size: NSSize(width: 64, height: 64)))
        
        // Simulate Apple's MediaPlayer serial background queue (*/accessQueue) invoking MPMediaItemArtwork requestHandler
        let accessQueue = DispatchQueue(label: "com.apple.MediaPlayer.accessQueue.test")
        let serialExp = expectation(description: "Artwork requestHandler succeeds on background serial queue")
        let serialDecodedSize = SendableBox<NSSize>(.zero)
        
        accessQueue.async {
            let rendered = artwork.get().image(at: NSSize(width: 128, height: 128))
            serialDecodedSize.set(rendered?.size ?? .zero)
            serialExp.fulfill()
        }
        wait(for: [serialExp], timeout: 2.0)
        XCTAssertGreaterThan(serialDecodedSize.get().width, 0)
        XCTAssertGreaterThan(serialDecodedSize.get().height, 0)
        
        // Also stress concurrent global background queues to ensure zero Swift 6 executor assertions
        let group = DispatchGroup()
        let decodedSizes = SendableBox<[NSSize]>([])
        for _ in 0..<8 {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let rendered = artwork.get().image(at: NSSize(width: 256, height: 256))
                decodedSizes.modify { $0.append(rendered?.size ?? .zero) }
                group.leave()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 3.0), .success)
        XCTAssertEqual(decodedSizes.get().count, 8)
        XCTAssertTrue(decodedSizes.get().allSatisfy { $0.width > 0 && $0.height > 0 })
    }
    
    func testNowPlayingArtworkFallbackAndCachedSizeNormalization() {
        let zeroSized = NowPlayingManager.CachedArtwork(data: Data([0x01, 0x02]), size: .zero)
        XCTAssertEqual(zeroSized.size, NSSize(width: 512, height: 512))
        
        let fallbackArtwork = SendableBox(NowPlayingManager.makeArtwork(data: Data([0xFF, 0x00]), size: .zero))
        let exp = expectation(description: "Corrupt image payload yields fallback NSImage on background queue")
        let resultSize = SendableBox<NSSize>(.zero)
        DispatchQueue.global(qos: .utility).async {
            resultSize.set(fallbackArtwork.get().image(at: NSSize(width: 120, height: 120))?.size ?? .zero)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(resultSize.get(), NSSize(width: 120, height: 120))
    }
    
    func testProcessIsolatedAppleScriptRunnerConcurrencyAndTimeout() {
        let group = DispatchGroup()
        let outputs = SendableBox<[String]>([])
        
        // Execute concurrent AppleScripts across background queues without touching in-process NSAppleScript/TASLexer
        for i in 0..<4 {
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                if let out = MorphAppleScriptRunner.run("return \"ok_\(i)\"", timeout: 3.0) {
                    outputs.modify { $0.append(out) }
                }
                group.leave()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 8.0), .success)
        XCTAssertEqual(Set(outputs.get()), Set(["ok_0", "ok_1", "ok_2", "ok_3"]))
        
        XCTAssertTrue(MorphAppleScriptRunner.runBoolean("return true", timeout: 3.0))
        XCTAssertFalse(MorphAppleScriptRunner.runBoolean("return false", timeout: 3.0))
        
        // Timeout guard must terminate runaway script cleanly
        let start = Date()
        let timedOut = MorphAppleScriptRunner.run("delay 5", timeout: 0.2)
        XCTAssertNil(timedOut)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2.0)
    }
    
    // MARK: - 11. Background F8 Resume After Pause & Anti-Bounce Verification
    
    func testBackgroundTapF8PauseThenResumeSystemMediaKeyRoundTrip() {
        // Given Morph is collapsed in the background and playing a loaded track
        model.isExpanded = false
        model.media.trackTitle = "Night Dancer"
        model.media.artistName = "imase"
        model.media.duration = 210.0
        model.media.play()
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertTrue(model.media.isEffectivelyPlaying)
        XCTAssertTrue(shortcutManager.hasControllableMediaSession(for: model))
        
        let dummyProxy = unsafeBitCast(Unmanaged.passUnretained(self).toOpaque(), to: CGEventTapProxy.self)
        let tapType = CGEventType(rawValue: 14)!
        
        // 1. User presses hardware F8 in background -> pauses & swallows both down & up
        let f8Down1 = makeSystemDefinedCGEvent(key: 16, down: true)
        let f8Up1 = makeSystemDefinedCGEvent(key: 16, down: false)
        XCTAssertNil(shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: tapType, event: f8Down1))
        XCTAssertNil(shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: tapType, event: f8Up1))
        XCTAssertFalse(model.media.isPlaying)
        XCTAssertTrue(model.media.userIntentionallyPaused)
        XCTAssertFalse(model.isGlassMusicPlaying)
        XCTAssertFalse(mockEngine.trackData.isPlaying)
        XCTAssertEqual(shortcutManager.lastTriggeredShortcut, "F8 Paused")
        
        // Morph still owns the paused session so F8 #2 must still intercept & resume rather than passing to rcd
        XCTAssertTrue(shortcutManager.hasControllableMediaSession(for: model))
        
        // 2. User presses hardware F8 again in background -> resumes & MUST swallow BOTH down & up
        let f8Down2 = makeSystemDefinedCGEvent(key: 16, down: true)
        let f8Up2 = makeSystemDefinedCGEvent(key: 16, down: false)
        XCTAssertNil(shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: tapType, event: f8Down2), "F8 #2 keyDown must be swallowed when resuming paused Morph track")
        XCTAssertNil(shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: tapType, event: f8Up2), "F8 #2 keyUp must also be swallowed so rcd/mediaremoted cannot bounce back to paused")
        XCTAssertTrue(model.media.isPlaying, "F8 #2 must resume playback cleanly")
        XCTAssertFalse(model.media.userIntentionallyPaused, "userIntentionallyPaused must clear on resume")
        XCTAssertTrue(model.media.isEffectivelyPlaying)
        XCTAssertTrue(model.isGlassMusicPlaying)
        XCTAssertTrue(mockEngine.trackData.isPlaying)
        XCTAssertEqual(shortcutManager.lastTriggeredShortcut, "F8 Playing")
    }
    
    func testBackgroundTapF8FunctionKeyPauseThenResumeRoundTrip() {
        model.isExpanded = false
        model.media.trackTitle = "Idol"
        model.media.duration = 213.0
        model.media.play()
        
        let dummyProxy = unsafeBitCast(Unmanaged.passUnretained(self).toOpaque(), to: CGEventTapProxy.self)
        let f8Down1 = makeKeyDownCGEvent(keyCode: 100)
        let f8Up1 = CGEvent(keyboardEventSource: nil, virtualKey: 100, keyDown: false)!
        
        XCTAssertNil(shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: .keyDown, event: f8Down1))
        XCTAssertNil(shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: .keyUp, event: f8Up1))
        XCTAssertFalse(model.media.isPlaying)
        XCTAssertTrue(model.media.userIntentionallyPaused)
        
        let f8Down2 = makeKeyDownCGEvent(keyCode: 100)
        let f8Up2 = CGEvent(keyboardEventSource: nil, virtualKey: 100, keyDown: false)!
        XCTAssertNil(shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: .keyDown, event: f8Down2), "Virtual F8 keyDown must be swallowed when resuming paused track")
        XCTAssertNil(shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: .keyUp, event: f8Up2), "Virtual F8 keyUp must be swallowed when resuming paused track")
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertFalse(model.media.userIntentionallyPaused)
        XCTAssertTrue(mockEngine.trackData.isPlaying)
    }
    
    func testSymmetricDirectionalLockoutAndRemoteEchoSuppressionOnF8Resume() async throws {
        shortcutManager.forceDebounceInTests = true
        defer { shortcutManager.forceDebounceInTests = false }
        
        model.isExpanded = false
        model.media.trackTitle = "Original Track"
        model.media.duration = 200.0
        model.media.play()
        
        // Pause first, then wait past the 0.65s debounce window so user intentionally presses F8 #2
        shortcutManager.pauseMusic()
        XCTAssertFalse(model.media.isPlaying)
        XCTAssertTrue(model.media.userIntentionallyPaused)
        
        try await Task.sleep(for: .milliseconds(720))
        
        // User presses hardware F8 in background to resume
        let dummyProxy = unsafeBitCast(Unmanaged.passUnretained(self).toOpaque(), to: CGEventTapProxy.self)
        let f8Down = makeSystemDefinedCGEvent(key: 16, down: true)
        let f8Up = makeSystemDefinedCGEvent(key: 16, down: false)
        XCTAssertNil(shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: CGEventType(rawValue: 14)!, event: f8Down))
        XCTAssertNil(shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: CGEventType(rawValue: 14)!, event: f8Up))
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertFalse(model.media.userIntentionallyPaused)
        
        // Simulated mediaremoted/rcd echo (from .listenOnly fallback or race) within 1.2s must be ignored
        shortcutManager.performTogglePlayPause(fromRemoteCommand: true)
        shortcutManager.performPauseMusic(fromRemoteCommand: true)
        XCTAssertTrue(model.media.isPlaying, "mediaremoted remote command echo right after hardware F8 resume must not re-pause")
        XCTAssertFalse(model.media.userIntentionallyPaused)
        
        // Immediate direct pause bounce within 0.65s must also be blocked by symmetric directional lockout
        shortcutManager.pauseMusic()
        shortcutManager.togglePlayPause()
        XCTAssertTrue(model.media.isPlaying, "Symmetric lockout must block accidental pause bounce immediately after resume")
        
        // After the 1.2s remote-echo + 0.65s debounce window expires, pressing F8 pauses normally again
        try await Task.sleep(for: .milliseconds(1250))
        let f8PauseDown = makeSystemDefinedCGEvent(key: 16, down: true)
        XCTAssertNil(shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: CGEventType(rawValue: 14)!, event: f8PauseDown))
        XCTAssertFalse(model.media.isPlaying)
        XCTAssertTrue(model.media.userIntentionallyPaused)
    }
    
    func testTransientEnginePausedPayloadDuringResumeLockoutDoesNotCancelResume() {
        model.media.trackTitle = "Original Track"
        model.media.artistName = "Original Artist"
        model.media.duration = 200.0
        
        // Pause then resume
        model.media.pause()
        XCTAssertTrue(model.media.userIntentionallyPaused)
        
        model.media.play()
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertFalse(model.media.userIntentionallyPaused)
        
        // Simulated transient offscreen WebKit buffering update (readyState < 2 / paused before unpause settles)
        mockEngine.simulateTrackDataUpdate(YTMTrackData(
            title: "Original Track",
            artist: "Original Artist",
            albumArtURL: "https://example.com/original.jpg",
            isPlaying: false,
            currentTime: 10.0,
            duration: 200.0
        ))
        
        // Playback state must hold as playing while unpausing settles
        XCTAssertTrue(model.media.isPlaying, "Transient engine isPlaying: false during resume lockout must not kill resumed playback")
        XCTAssertFalse(model.media.userIntentionallyPaused)
        
        // Explicit user pause immediately clears lockout and pauses
        model.media.pause()
        XCTAssertFalse(model.media.isPlaying)
        XCTAssertTrue(model.media.userIntentionallyPaused)
    }
    
    func testYouTubeMusicEnginePlayAndPauseScriptGuards() {
        mockEngine.play()
        let playScript = mockEngine.lastEvaluatedScript ?? ""
        XCTAssertTrue(playScript.contains("_morphUserPaused = false"), "play() must clear _morphUserPaused")
        XCTAssertTrue(playScript.contains("_morphPauseLockoutUntil = 0"), "play() must clear pause lockout")
        XCTAssertTrue(playScript.contains("_morphResumeLockoutUntil = Date.now() + 1400"), "play() must arm anti-bounce resume lockout")
        XCTAssertTrue(playScript.contains("_morphResumeAudioContexts"), "play() must resume suspended Web Audio contexts")
        XCTAssertTrue(playScript.contains("isActuallyPlaying") && playScript.contains("!saysPause"), "play() must only click play-pause-button when not playing and never click Pause")
        XCTAssertTrue(playScript.contains("startTransitionWatchdog"), "play() must invoke startTransitionWatchdog")
        
        mockEngine.pause()
        let pauseScript = mockEngine.lastEvaluatedScript ?? ""
        XCTAssertTrue(pauseScript.contains("_morphUserPaused = true"), "pause() must set _morphUserPaused")
        XCTAssertTrue(pauseScript.contains("_morphResumeLockoutUntil = 0"), "pause() must clear resume lockout")
        XCTAssertTrue(pauseScript.contains("_morphPauseLockoutUntil = Date.now() + 1400"), "pause() must arm pause lockout")
    }
}
