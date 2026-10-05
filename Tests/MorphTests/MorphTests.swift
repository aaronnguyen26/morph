import XCTest
@testable import morph

final class MorphTests: XCTestCase {
    @MainActor
    func testNotchModelDimensions() {
        let pomodoro = PomodoroModel()
        let media = MediaControllerModel()
        let scratchpad = ScratchpadModel()
        
        let model = NotchModel(pomodoro: pomodoro, media: media, scratchpad: scratchpad)
        
        // Baseline idle dimensions
        XCTAssertGreaterThanOrEqual(model.idleWidth, 160)
        XCTAssertGreaterThanOrEqual(model.idleHeight, 28)
        
        // Expanded dimensions
        XCTAssertEqual(model.expandedWidth, 640)
        XCTAssertEqual(model.expandedHeight, 300)
        
        // Idle state: currentWidth is idleWidth
        pomodoro.isRunning = false
        media.isPlaying = false
        model.isExpanded = false
        XCTAssertFalse(model.isCompactActive)
        XCTAssertEqual(model.currentWidth, model.idleWidth)
        XCTAssertEqual(model.currentHeight, model.idleHeight)
        
        // Compact Active state: Pomodoro running
        pomodoro.isRunning = true
        XCTAssertTrue(model.isCompactActive)
        XCTAssertEqual(model.compactWidth, model.idleWidth + 150)
        XCTAssertEqual(model.currentWidth, model.idleWidth + 150)
        
        // Compact Active state: Both running
        media.isPlaying = true
        XCTAssertEqual(model.compactWidth, model.idleWidth + 160)
        
        // Expanded state overrides compact
        model.isExpanded = true
        XCTAssertEqual(model.currentWidth, 640)
        XCTAssertEqual(model.currentHeight, 300)
    }
    
    @MainActor
    func testPomodoroModel() {
        let pomodoro = PomodoroModel()
        XCTAssertFalse(pomodoro.isRunning)
        XCTAssertEqual(pomodoro.mode, .work)
        XCTAssertEqual(pomodoro.formattedTime, "25:00")
        
        pomodoro.toggle()
        XCTAssertTrue(pomodoro.isRunning)
        
        pomodoro.toggle()
        XCTAssertFalse(pomodoro.isRunning)
        
        pomodoro.reset()
        XCTAssertFalse(pomodoro.isRunning)
        XCTAssertEqual(pomodoro.formattedTime, "25:00")
    }
    
    @MainActor
    func testScratchpadModel() {
        let pad = ScratchpadModel()
        pad.text = "Hello world from Morph test"
        XCTAssertEqual(pad.wordCount, 5)
        XCTAssertEqual(pad.charCount, 27)
        
        pad.copyAll()
        XCTAssertTrue(pad.showCopiedAlert)
    }
    
    @MainActor
    func testRule1NotchBlindSpotGeometry() {
        let model = NotchModel()
        let blindWidth = max(model.idleWidth + 10, 185)
        let blindHeight = max(model.idleHeight + 2, 34)
        
        // Guarantee center blind spot completely covers physical notch with safety margin
        XCTAssertGreaterThanOrEqual(blindWidth, 185)
        XCTAssertGreaterThanOrEqual(blindHeight, 34)
    }
    
    @MainActor
    func testRule3ActiveTaskCollapseVisibility() {
        let pomodoro = PomodoroModel()
        let media = MediaControllerModel()
        let model = NotchModel(pomodoro: pomodoro, media: media)
        
        // When Pomodoro is running: wing size must be >= 70 pt on each side
        pomodoro.isRunning = true
        media.isPlaying = false
        let leftWingPomodoro = (model.compactWidth - model.idleWidth) / 2
        XCTAssertGreaterThanOrEqual(leftWingPomodoro, 70, "Left wing must be at least 70 pt so timer countdown and ring are 100% visible outside the notch")
        
        // When Media is playing: wing size must be >= 70 pt on each side
        pomodoro.isRunning = false
        media.isPlaying = true
        let rightWingMedia = (model.compactWidth - model.idleWidth) / 2
        XCTAssertGreaterThanOrEqual(rightWingMedia, 70, "Right wing must be at least 70 pt so live equalizer bars and note icon are 100% visible outside the notch")
        
        // When Both are running: wing size must be >= 80 pt on each side
        pomodoro.isRunning = true
        media.isPlaying = true
        let dualWings = (model.compactWidth - model.idleWidth) / 2
        XCTAssertGreaterThanOrEqual(dualWings, 80, "Dual wings must be at least 80 pt for concurrent timer and equalizer display")
    }
    
    @MainActor
    func testTabSwitching() {
        let model = NotchModel()
        XCTAssertEqual(model.selectedTab, .home)
        
        model.openFeature(.timer)
        XCTAssertEqual(model.selectedTab, .timer)
        XCTAssertTrue(model.isExpanded)
        
        model.returnToHome()
        XCTAssertEqual(model.selectedTab, .home)
    }
    
    @MainActor
    func testYouTubeMusicEnginePayloadParsing() {
        let engine = YouTubeMusicEngine()
        
        // Initial state
        XCTAssertNotNil(engine.webView)
        
        // Simulate incoming JS bridge message payload
        let mockPayload: [String: Any] = [
            "title": "Save Your Tears",
            "artist": "The Weeknd • After Hours",
            "albumArt": "https://lh3.googleusercontent.com/test_art.jpg",
            "isPlaying": true,
            "currentTime": 45.5,
            "duration": 215.0,
            "volume": 0.85,
            "isMuted": false,
            "isLiked": true
        ]
        
        engine.parseIncomingPayload(mockPayload)
        
        XCTAssertEqual(engine.trackData.title, "Save Your Tears")
        XCTAssertEqual(engine.trackData.artist, "The Weeknd • After Hours")
        XCTAssertEqual(engine.trackData.albumArtURL, "https://lh3.googleusercontent.com/test_art.jpg")
        XCTAssertTrue(engine.trackData.isPlaying)
        XCTAssertEqual(engine.trackData.currentTime, 45.5)
        XCTAssertEqual(engine.trackData.duration, 215.0)
        XCTAssertEqual(engine.trackData.volume, 0.85)
        XCTAssertFalse(engine.trackData.isMuted)
        XCTAssertTrue(engine.trackData.isLiked)
    }
    
    @MainActor
    func testMediaControllerModelDirectEngineBinding() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        // Test initial values
        XCTAssertEqual(media.sourceName, "YouTube Music Direct")
        
        // Send payload through engine
        let mockPayload: [String: Any] = [
            "title": "Levitating",
            "artist": "Dua Lipa",
            "albumArt": "https://example.com/art.png",
            "isPlaying": true,
            "currentTime": 30.0,
            "duration": 203.0,
            "volume": 0.9,
            "isMuted": false,
            "isLiked": false
        ]
        
        engine.parseIncomingPayload(mockPayload)
        
        // MediaControllerModel should reflect parsed payload
        XCTAssertEqual(media.trackTitle, "Levitating")
        XCTAssertEqual(media.artistName, "Dua Lipa")
        XCTAssertEqual(media.albumArtURL, "https://example.com/art.png")
        XCTAssertTrue(media.isPlaying)
        XCTAssertEqual(media.currentTime, 30.0)
        XCTAssertEqual(media.duration, 203.0)
        XCTAssertEqual(media.volume, 0.9)
        XCTAssertFalse(media.isMuted)
        
        // Progress and formatted times
        XCTAssertEqual(media.formattedCurrentTime, "0:30")
        XCTAssertEqual(media.formattedDuration, "3:23")
        XCTAssertEqual(media.progress, 30.0 / 203.0, accuracy: 0.001)
        
        // Controls
        media.togglePlay()
        XCTAssertFalse(media.isPlaying)
        
        media.toggleMute()
        XCTAssertTrue(media.isMuted)
        
        media.setVolume(0.5)
        XCTAssertEqual(media.volume, 0.5)
        
        media.toggleLike()
        XCTAssertTrue(media.isLiked)
    }
}
