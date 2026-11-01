import XCTest
import SwiftUI
@testable import morph

@MainActor
final class SpotlightBarTimerTests: XCTestCase {
    
    var model: NotchModel!
    var controller: MorphController!
    
    override func setUp() async throws {
        try await super.setUp()
        model = NotchModel()
        controller = MorphController(model: model)
    }
    
    override func tearDown() async throws {
        model = nil
        controller = nil
        try await super.tearDown()
    }
    
    // MARK: - Requirement 1: Legacy Large UI Format is Safely Packaged & Preserved
    func testLegacyLargeUIFormatIsPackagedAndPreserved() {
        // Switch to legacy mode
        model.interactionMode = .legacyLargeUI
        XCTAssertEqual(model.interactionMode, .legacyLargeUI)
        
        // Before hover/expand: resting notch dimensions
        XCTAssertFalse(model.isExpanded)
        XCTAssertEqual(model.currentWidth, model.idleWidth)
        XCTAssertEqual(model.currentHeight, model.idleHeight)
        
        // On hover expansion in legacy mode: expands to exact 640 x 225 pt tabbed dashboard
        model.isExpanded = true
        XCTAssertEqual(model.currentWidth, 640, "Legacy mode must preserve exact 640 pt width")
        XCTAssertEqual(model.currentHeight, 225, "Legacy mode must preserve exact 225 pt height")
        XCTAssertEqual(model.islandState, .fullExpanded)
    }
    
    // MARK: - Requirement 2: Default Spotlight Bar Interaction Mode
    func testDefaultInteractionModeIsSpotlightBar() {
        XCTAssertEqual(model.interactionMode, .spotlightBar, "Default mode should be spotlightBar")
        XCTAssertFalse(model.isSpotlightBarActive)
        XCTAssertFalse(model.isTimerPopupActive)
        XCTAssertEqual(model.currentWidth, model.idleWidth)
        XCTAssertEqual(model.currentHeight, model.idleHeight)
        XCTAssertEqual(model.islandState, .resting)
    }
    
    // MARK: - Requirement 3: Hover Expands Horizontally into Elongated Bar
    func testHoverExpandsHorizontallyIntoElongatedBar() {
        // User hovers into the notch area
        controller.handleMouseEnter()
        
        XCTAssertTrue(model.isSpotlightBarActive, "Hover must activate the spotlight typing bar")
        XCTAssertFalse(model.isTimerPopupActive)
        XCTAssertEqual(model.currentWidth, 520, "Spotlight bar must expand horizontally to 520 pt")
        XCTAssertEqual(model.currentHeight, 38, "Spotlight bar must remain a slim 38 pt height")
        XCTAssertEqual(model.islandState, .spotlightBar)
    }
    
    // MARK: - Requirement 4: Typing Bar is Strictly for Typing (No Buttons)
    func testSpotlightBarIsPureTypingInput() {
        model.isSpotlightBarActive = true
        model.spotlightQuery = ""
        
        // Simulating typing queries into the text field
        model.handleSpotlightQueryChanged("25m")
        XCTAssertEqual(model.spotlightQuery, "25m")
        
        model.handleSpotlightQueryChanged("focus timer")
        XCTAssertEqual(model.spotlightQuery, "focus timer")
        
        // Verify resetting
        model.resetSpotlightBar()
        XCTAssertEqual(model.spotlightQuery, "")
        XCTAssertFalse(model.isSpotlightBarActive)
    }
    
    // MARK: - Requirement 5: MorphTimerQueryParser Robust Parsing
    func testMorphTimerQueryParser() {
        // Exact numbers
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "25"), 25)
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "15"), 15)
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "45"), 45)
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "60"), 60)
        
        // Number with 'm' or 'min' or 'mins'
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "25m"), 25)
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "15 min"), 15)
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "50 mins"), 50)
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "5m"), 5)
        
        // Keywords with default 25 min
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "timer"), 25)
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "focus"), 25)
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "focus session"), 25)
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "pomodoro"), 25)
        
        // Break keywords
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "break"), 5)
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "short break"), 5)
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "long break"), 15)
        
        // Compound query e.g. "timer 15" or "focus 30m"
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "timer 15"), 15)
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "focus 30m"), 30)
        XCTAssertEqual(MorphTimerQueryParser.parseMinutes(from: "pomodoro 45 min"), 45)
        
        // Invalid or non-matching query returns nil
        XCTAssertNil(MorphTimerQueryParser.parseMinutes(from: "play music"))
        XCTAssertNil(MorphTimerQueryParser.parseMinutes(from: "xyz random"))
    }
    
    // MARK: - Requirement 6: Typed Submit Pops Up Timer & Shrinks Horizontally
    func testTypedSubmitPopsUpTimerAndShrinksHorizontally() {
        // 1. Activate spotlight bar
        model.isSpotlightBarActive = true
        XCTAssertEqual(model.currentWidth, 520)
        
        // 2. User types "25m" and submits (presses Enter)
        model.spotlightQuery = "25m"
        model.handleSpotlightSubmit()
        
        // 3. Verify state transition to timer popup
        XCTAssertFalse(model.isSpotlightBarActive, "Spotlight bar should be dismissed")
        XCTAssertTrue(model.isTimerPopupActive, "Timer popup must be active")
        XCTAssertEqual(model.islandState, .timerPopup)
        
        // 4. Verify horizontal shrinkage: 320 pt is strictly less than 520 pt (and < 640 pt)
        XCTAssertEqual(model.currentWidth, 320, "Timer popup must shrink horizontally to 320 pt (< 520 pt)")
        XCTAssertLessThan(model.currentWidth, 520)
        XCTAssertLessThan(model.currentWidth, 640)
        
        // 5. Verify vertical height for readable timer controls
        XCTAssertEqual(model.currentHeight, 135, "Timer popup height must expand to 135 pt")
        
        // 6. Verify timer was configured and started
        XCTAssertEqual(model.pomodoro.timeRemaining, 25 * 60)
        XCTAssertTrue(model.pomodoro.isRunning)
    }
    
    // MARK: - Requirement 7: Custom Duration Parsing and Launch
    func testCustomDurationLaunch() {
        model.isSpotlightBarActive = true
        model.spotlightQuery = "10m"
        model.handleSpotlightSubmit()
        
        XCTAssertTrue(model.isTimerPopupActive)
        XCTAssertEqual(model.currentWidth, 320)
        XCTAssertEqual(model.currentHeight, 135)
        XCTAssertEqual(model.pomodoro.timeRemaining, 10 * 60)
        XCTAssertTrue(model.pomodoro.isRunning)
    }
    
    // MARK: - Requirement 8: Keyboard Controls (Space to Pause, ESC to Dismiss)
    func testKeyboardControlsOnTimerPopup() {
        let shortcuts = ShortcutManager.shared
        shortcuts.configure(model: model, controller: controller)
        
        // 1. Launch timer popup with autoStart: true
        model.triggerTimerPopup(minutes: 25, autoStart: true)
        XCTAssertTrue(model.isTimerPopupActive)
        XCTAssertTrue(model.pomodoro.isRunning)
        
        // 2. Space event (keyCode 49) pauses timer
        let spaceEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: " ",
            charactersIgnoringModifiers: " ",
            isARepeat: false,
            keyCode: 49
        )!
        
        let spaceHandled = shortcuts.handleKeyEvent(spaceEvent)
        XCTAssertTrue(spaceHandled)
        XCTAssertFalse(model.pomodoro.isRunning, "Space should toggle timer to paused")
        
        // 3. Reset timer
        model.pomodoro.reset()
        XCTAssertFalse(model.pomodoro.isRunning)
        XCTAssertEqual(model.compactHUDMode, .none)
        
        // 4. ESC event (keyCode 53) dismisses timer popup
        let escEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 53
        )!
        
        let escHandled = shortcuts.handleKeyEvent(escEvent)
        XCTAssertTrue(escHandled)
        XCTAssertFalse(model.isTimerPopupActive, "ESC must dismiss timer popup")
        XCTAssertEqual(model.currentWidth, model.idleWidth, "When reset, should return to resting notch width")
        XCTAssertEqual(model.islandState, .resting)
    }
}
