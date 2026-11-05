import XCTest
import AppKit
import SwiftUI
@testable import morph

@MainActor
final class YTMShortcutTests: XCTestCase {
    var model: NotchModel!
    var shortcutManager: ShortcutManager!
    var mockEngine: YouTubeMusicEngine!
    
    override func setUp() async throws {
        try await super.setUp()
        mockEngine = YouTubeMusicEngine.shared
        mockEngine.trackData = YTMTrackData(
            title: "Test Track",
            artist: "Test Artist",
            albumArtURL: nil,
            isPlaying: false,
            currentTime: 60.0,
            duration: 180.0
        )
        
        model = NotchModel()
        model.media.duration = 180.0
        model.media.currentTime = 60.0
        model.media.isPlaying = false
        model.selectedTab = .music
        
        shortcutManager = ShortcutManager.shared
        shortcutManager.configure(model: model, controller: nil)
    }
    
    override func tearDown() async throws {
        shortcutManager = nil
        model = nil
        mockEngine = nil
        try await super.tearDown()
    }
    
    // MARK: - Helper to build synthetic NSEvents
    private func makeKeyEvent(
        characters: String,
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags = []
    ) -> NSEvent {
        return NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifierFlags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: keyCode
        )!
    }
    
    // MARK: - 1. Function Keys (F7, F8, F9)
    func testF7PreviousTrack() {
        let f7Char = String(utf16CodeUnits: [unichar(NSF7FunctionKey)], count: 1)
        let event = makeKeyEvent(characters: f7Char, keyCode: 98)
        
        let handled = shortcutManager.handleKeyEvent(event)
        XCTAssertTrue(handled, "F7 must be handled")
        XCTAssertEqual(shortcutManager.lastTriggeredShortcut, "F7 Previous")
    }
    
    func testF8PlayPauseStop() {
        let f8Char = String(utf16CodeUnits: [unichar(NSF8FunctionKey)], count: 1)
        let event = makeKeyEvent(characters: f8Char, keyCode: 100)
        
        // 1. Initially paused -> should start playing
        model.media.isPlaying = false
        var handled = shortcutManager.handleKeyEvent(event)
        XCTAssertTrue(handled, "F8 must be handled")
        XCTAssertTrue(model.media.isPlaying, "F8 must start playback when paused")
        XCTAssertEqual(shortcutManager.lastTriggeredShortcut, "F8 Playing")
        
        // 2. Currently playing -> should stop/pause
        handled = shortcutManager.handleKeyEvent(event)
        XCTAssertTrue(handled, "F8 must be handled")
        XCTAssertFalse(model.media.isPlaying, "F8 must pause playback when playing")
        XCTAssertEqual(shortcutManager.lastTriggeredShortcut, "F8 Paused")
    }
    
    func testF9NextTrack() {
        let f9Char = String(utf16CodeUnits: [unichar(NSF9FunctionKey)], count: 1)
        let event = makeKeyEvent(characters: f9Char, keyCode: 101)
        
        let handled = shortcutManager.handleKeyEvent(event)
        XCTAssertTrue(handled, "F9 must be handled")
        XCTAssertEqual(shortcutManager.lastTriggeredShortcut, "F9 Next")
    }
    
    func testFunctionKeysWorkAcrossTabs() {
        // Switch to Notes or Home
        model.selectedTab = .notes
        let f8Char = String(utf16CodeUnits: [unichar(NSF8FunctionKey)], count: 1)
        let event = makeKeyEvent(characters: f8Char, keyCode: 100)
        
        let handled = shortcutManager.handleKeyEvent(event)
        XCTAssertTrue(handled, "F8 media key must work even when selectedTab is .notes")
        XCTAssertTrue(model.media.isPlaying)
    }
    
    // MARK: - 2. YouTube Music Direct Shortcuts (When in Music Tab)
    func testSpacePlayPause() {
        model.selectedTab = .music
        model.media.isPlaying = false
        let spaceEvent = makeKeyEvent(characters: " ", keyCode: 49)
        
        let handled = shortcutManager.handleKeyEvent(spaceEvent)
        XCTAssertTrue(handled, "Space must be handled in music player")
        XCTAssertTrue(model.media.isPlaying, "Space must start playback")
    }
    
    func testKPlayPause() {
        model.selectedTab = .music
        model.media.isPlaying = false
        let kEvent = makeKeyEvent(characters: "k", keyCode: 40)
        
        let handled = shortcutManager.handleKeyEvent(kEvent)
        XCTAssertTrue(handled, "k must toggle play/pause")
        XCTAssertTrue(model.media.isPlaying)
    }
    
    func testShiftNNextTrack() {
        model.selectedTab = .music
        let shiftNEvent = makeKeyEvent(characters: "N", keyCode: 45, modifierFlags: [.shift])
        
        let handled = shortcutManager.handleKeyEvent(shiftNEvent)
        XCTAssertTrue(handled, "Shift+N must be handled")
        XCTAssertEqual(shortcutManager.lastTriggeredShortcut, "⇧N Next")
    }
    
    func testShiftPPreviousTrack() {
        model.selectedTab = .music
        let shiftPEvent = makeKeyEvent(characters: "P", keyCode: 35, modifierFlags: [.shift])
        
        let handled = shortcutManager.handleKeyEvent(shiftPEvent)
        XCTAssertTrue(handled, "Shift+P must be handled")
        XCTAssertEqual(shortcutManager.lastTriggeredShortcut, "⇧P Previous")
    }
    
    func testJAndLSeeking() {
        model.selectedTab = .music
        model.media.duration = 200.0
        model.media.currentTime = 100.0
        
        // J rewinds 10s
        let jEvent = makeKeyEvent(characters: "j", keyCode: 38)
        let handledJ = shortcutManager.handleKeyEvent(jEvent)
        XCTAssertTrue(handledJ, "J must seek backward 10s")
        XCTAssertEqual(model.media.currentTime, 90.0, accuracy: 0.001)
        XCTAssertEqual(shortcutManager.lastTriggeredShortcut, "J -10s")
        
        // L fast forwards 10s
        let lEvent = makeKeyEvent(characters: "l", keyCode: 37)
        let handledL = shortcutManager.handleKeyEvent(lEvent)
        XCTAssertTrue(handledL, "L must seek forward 10s")
        XCTAssertEqual(model.media.currentTime, 100.0, accuracy: 0.001)
        XCTAssertEqual(shortcutManager.lastTriggeredShortcut, "L +10s")
    }
    
    func testArrowKeySeekingAndVolume() {
        model.selectedTab = .music
        model.media.duration = 200.0
        model.media.currentTime = 100.0
        model.media.volume = 0.50
        
        // Left arrow (keyCode 123) -> -5s
        let leftEvent = makeKeyEvent(characters: "", keyCode: 123)
        let handledLeft = shortcutManager.handleKeyEvent(leftEvent)
        XCTAssertTrue(handledLeft, "Left arrow must seek backward 5s")
        XCTAssertEqual(model.media.currentTime, 95.0, accuracy: 0.001)
        
        // Right arrow (keyCode 124) -> +5s
        let rightEvent = makeKeyEvent(characters: "", keyCode: 124)
        let handledRight = shortcutManager.handleKeyEvent(rightEvent)
        XCTAssertTrue(handledRight, "Right arrow must seek forward 5s")
        XCTAssertEqual(model.media.currentTime, 100.0, accuracy: 0.001)
        
        // Up arrow (keyCode 126) -> volume +0.05
        let upEvent = makeKeyEvent(characters: "", keyCode: 126)
        let handledUp = shortcutManager.handleKeyEvent(upEvent)
        XCTAssertTrue(handledUp, "Up arrow must increase volume")
        XCTAssertEqual(model.media.volume, 0.55, accuracy: 0.001)
        XCTAssertTrue(model.media.showVolumeHUD, "Volume HUD must be triggered")
        
        // Down arrow (keyCode 125) -> volume -0.05
        let downEvent = makeKeyEvent(characters: "", keyCode: 125)
        let handledDown = shortcutManager.handleKeyEvent(downEvent)
        XCTAssertTrue(handledDown, "Down arrow must decrease volume")
        XCTAssertEqual(model.media.volume, 0.50, accuracy: 0.001)
        XCTAssertTrue(model.media.showVolumeHUD, "Volume HUD must be triggered")
    }
    
    func testMuteToggle() {
        model.selectedTab = .music
        model.media.isMuted = false
        let mEvent = makeKeyEvent(characters: "m", keyCode: 46)
        
        let handled = shortcutManager.handleKeyEvent(mEvent)
        XCTAssertTrue(handled, "M must toggle mute")
        XCTAssertTrue(model.media.isMuted)
    }
    
    func testRepeatToggle() {
        model.selectedTab = .music
        model.media.repeatMode = .off
        let rEvent = makeKeyEvent(characters: "r", keyCode: 15)
        
        let handled = shortcutManager.handleKeyEvent(rEvent)
        XCTAssertTrue(handled, "R must toggle repeat mode")
        XCTAssertEqual(model.media.repeatMode, .all)
        XCTAssertTrue(model.media.showRepeatHUD, "Repeat HUD must be displayed")
    }
    
    func testShuffleToggle() {
        model.selectedTab = .music
        model.media.isShuffle = false
        let sEvent = makeKeyEvent(characters: "s", keyCode: 1)
        
        let handled = shortcutManager.handleKeyEvent(sEvent)
        XCTAssertTrue(handled, "S must toggle shuffle mode")
        XCTAssertTrue(model.media.isShuffle)
        XCTAssertTrue(model.media.showShuffleHUD, "Shuffle HUD must be displayed")
    }
    
    func testLikeAndDislike() {
        model.selectedTab = .music
        model.media.isLiked = false
        let plusEvent = makeKeyEvent(characters: "+", keyCode: 24)
        let handledPlus = shortcutManager.handleKeyEvent(plusEvent)
        XCTAssertTrue(handledPlus, "+ must toggle like")
        XCTAssertTrue(model.media.isLiked)
        
        model.media.isDisliked = false
        let minusEvent = makeKeyEvent(characters: "-", keyCode: 27)
        let handledMinus = shortcutManager.handleKeyEvent(minusEvent)
        XCTAssertTrue(handledMinus, "- must toggle dislike")
        XCTAssertTrue(model.media.isDisliked)
    }
    
    func testPercentageSeeking() {
        model.selectedTab = .music
        model.media.duration = 200.0
        
        // 0 -> 0%
        let zeroEvent = makeKeyEvent(characters: "0", keyCode: 29)
        let handled0 = shortcutManager.handleKeyEvent(zeroEvent)
        XCTAssertTrue(handled0, "0 must seek to 0%")
        XCTAssertEqual(model.media.currentTime, 0.0, accuracy: 0.001)
        
        // 5 -> 50%
        let fiveEvent = makeKeyEvent(characters: "5", keyCode: 23)
        let handled5 = shortcutManager.handleKeyEvent(fiveEvent)
        XCTAssertTrue(handled5, "5 must seek to 50%")
        XCTAssertEqual(model.media.currentTime, 100.0, accuracy: 0.001)
        
        // 9 -> 90%
        let nineEvent = makeKeyEvent(characters: "9", keyCode: 25)
        let handled9 = shortcutManager.handleKeyEvent(nineEvent)
        XCTAssertTrue(handled9, "9 must seek to 90%")
        XCTAssertEqual(model.media.currentTime, 180.0, accuracy: 0.001)
    }
    
    func testSlashSearchTrigger() {
        model.selectedTab = .music
        model.media.selectedPlaylist = nil
        let slashEvent = makeKeyEvent(characters: "/", keyCode: 44)
        
        let handled = shortcutManager.handleKeyEvent(slashEvent)
        XCTAssertTrue(handled, "/ must open search")
        XCTAssertEqual(model.media.rightDeckSection, .search)
    }
    
    // MARK: - 3. Seek Relative Helper Logic
    func testSeekRelativeBounds() {
        model.media.duration = 100.0
        model.media.currentTime = 50.0
        
        // Seek forward past duration clamps to duration
        model.media.seekRelative(deltaSeconds: 70.0)
        XCTAssertEqual(model.media.currentTime, 100.0, accuracy: 0.001)
        
        // Seek backward past zero clamps to 0
        model.media.seekRelative(deltaSeconds: -150.0)
        XCTAssertEqual(model.media.currentTime, 0.0, accuracy: 0.001)
        
        // Direct seconds seek
        model.media.seek(toSeconds: 33.0)
        XCTAssertEqual(model.media.currentTime, 33.0, accuracy: 0.001)
    }
    
    // MARK: - 4. Tab Guarding: Single-keys do not fire on non-music tabs
    func testSingleKeysIgnoredOnNonMusicTabs() {
        model.selectedTab = .notes
        let jEvent = makeKeyEvent(characters: "j", keyCode: 38)
        let handledJ = shortcutManager.handleKeyEvent(jEvent)
        XCTAssertFalse(handledJ, "Single letter keys must NOT be intercepted outside music tab")
        
        let fiveEvent = makeKeyEvent(characters: "5", keyCode: 23)
        let handled5 = shortcutManager.handleKeyEvent(fiveEvent)
        XCTAssertFalse(handled5, "Digit keys must NOT be intercepted outside music tab")
    }
}
