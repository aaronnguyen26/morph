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
        XCTAssertEqual(model.currentWidth, 510, "Spotlight bar must expand horizontally to widened 510 pt, perfectly balanced")
        XCTAssertLessThan(model.currentWidth, 600)
        XCTAssertGreaterThan(model.currentWidth, model.timerPopupWidth)
        XCTAssertEqual(model.currentHeight, 38, "Spotlight bar must remain a slim 38 pt height")
        XCTAssertEqual(model.islandState, .spotlightBar)
    }
    
    // MARK: - Requirement 4: Typing Bar is Strictly for Typing (No Buttons & No Premature Launch)
    func testSpotlightBarIsPureTypingInput() {
        model.isSpotlightBarActive = true
        model.spotlightQuery = ""
        
        // Simulating typing queries into the text field: typing should NOT trigger popup prematurely
        model.handleSpotlightQueryChanged("2")
        XCTAssertEqual(model.spotlightQuery, "2")
        XCTAssertTrue(model.isSpotlightBarActive, "Typing '2' must keep spotlight bar active for the user to continue typing")
        XCTAssertFalse(model.isTimerPopupActive, "Typing must not launch popup until Enter/submit")
        
        model.handleSpotlightQueryChanged("25m")
        XCTAssertEqual(model.spotlightQuery, "25m")
        XCTAssertTrue(model.isSpotlightBarActive)
        XCTAssertFalse(model.isTimerPopupActive)
        
        model.handleSpotlightQueryChanged("focus timer")
        XCTAssertEqual(model.spotlightQuery, "focus timer")
        XCTAssertTrue(model.isSpotlightBarActive)
        XCTAssertFalse(model.isTimerPopupActive)
        
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
    
    // MARK: - Requirement 6: Typed Submit Transitions Directly to Extended Pill HUD (2nd Screenshot, Not 1st)
    func testTypedSubmitPopsUpTimerAndShrinksHorizontally() {
        // 1. Activate spotlight bar
        model.isSpotlightBarActive = true
        XCTAssertEqual(model.currentWidth, 510)
        
        // 2. User types "25m" and submits (presses Enter)
        model.spotlightQuery = "25m"
        model.handleSpotlightSubmit()
        
        // 3. Verify state transition directly to 2nd screenshot (Extended Pill HUD, NOT 1st screenshot popup)
        XCTAssertFalse(model.isSpotlightBarActive, "Spotlight bar should be dismissed")
        XCTAssertFalse(model.isTimerPopupActive, "Timer popup card (1st screenshot) must NOT appear")
        XCTAssertTrue(model.isCompactActive, "Compact Dynamic Island HUD must be active")
        XCTAssertEqual(model.compactHUDMode, .pomodoroOnly)
        XCTAssertEqual(model.islandState, .extendedPill, "Must transition directly to Extended Pill HUD (2nd screenshot)")
        
        // 4. Verify slim pill dimensions
        XCTAssertEqual(model.currentWidth, model.compactWidth)
        XCTAssertEqual(model.currentHeight, model.idleHeight)
        
        // 5. Verify timer was configured and started
        XCTAssertEqual(model.pomodoro.timeRemaining, 25 * 60)
        XCTAssertTrue(model.pomodoro.isRunning)
    }
    
    // MARK: - Requirement 7: Custom Duration Parsing and Launch
    func testCustomDurationLaunch() {
        model.isSpotlightBarActive = true
        model.spotlightQuery = "10m"
        model.handleSpotlightSubmit()
        
        XCTAssertFalse(model.isTimerPopupActive, "Must not show 1st screenshot popup")
        XCTAssertEqual(model.islandState, .extendedPill, "Must show 2nd screenshot extended pill")
        XCTAssertEqual(model.pomodoro.timeRemaining, 10 * 60)
        XCTAssertTrue(model.pomodoro.isRunning)
    }
    
    // MARK: - Requirement 8: Personalized Timer Title and Custom Message
    func testPersonalizedTimerTitleAndDuration() {
        model.isSpotlightBarActive = true
        model.spotlightQuery = "Math homework 30m"
        model.handleSpotlightSubmit()
        
        XCTAssertFalse(model.isTimerPopupActive)
        XCTAssertEqual(model.islandState, .extendedPill)
        XCTAssertEqual(model.requestedTimerMinutes, 30)
        XCTAssertEqual(model.customTimerTitle, "Math Homework")
        XCTAssertEqual(model.pomodoro.timeRemaining, 30 * 60)
        XCTAssertTrue(model.pomodoro.isRunning)
        
        // Test another custom personalized query
        model.spotlightQuery = "Read biology 45m"
        model.handleSpotlightSubmit()
        XCTAssertEqual(model.requestedTimerMinutes, 45)
        XCTAssertEqual(model.customTimerTitle, "Read Biology")
        
        // Test query with simple title and number
        model.spotlightQuery = "Code review 20 mins"
        model.handleSpotlightSubmit()
        XCTAssertEqual(model.requestedTimerMinutes, 20)
        XCTAssertEqual(model.customTimerTitle, "Code Review")
    }
    
    // MARK: - Requirement 9: Adjusting Time and Shortened 300pt Bar
    func testAdjustTimerDurationInPillUI() {
        model.startFocusTimerInPill(minutes: 25, title: "Deep Work", autoStart: true)
        XCTAssertEqual(model.pomodoro.timeRemaining, 25 * 60)
        XCTAssertEqual(model.compactWidth, 300, "Compact timer pill must be shortened horizontally to exactly 300 pt")
        XCTAssertEqual(model.currentWidth, 300, "Current width must reflect the shortened 300 pt width")
        
        // Time adjustment programmatically via pomodoro model
        model.pomodoro.adjustTime(deltaMinutes: 5)
        XCTAssertEqual(model.pomodoro.timeRemaining, 30 * 60, "Adjusting time by +5m increases remaining time to 30 mins")
        
        model.pomodoro.adjustTime(deltaMinutes: -5)
        XCTAssertEqual(model.pomodoro.timeRemaining, 25 * 60, "Adjusting time by -5m decreases remaining time back to 25 mins")
    }
    
    // MARK: - Requirement 10: Editing Timer Task & Duration Directly in Pill
    func testEditingTimerInPillUI() {
        model.startFocusTimerInPill(minutes: 20, title: "Writing", autoStart: true)
        XCTAssertFalse(model.isEditingTimerInPill)
        
        // User taps edit button or task capsule or anywhere on the bar
        model.startEditingTimerInPill()
        XCTAssertTrue(model.isEditingTimerInPill, "Tapping edit must activate inline pill editor")
        XCTAssertEqual(model.pillEditingText, "Writing 20m")
        
        // User edits text to "Design Sprint 35m" and commits (hits Enter or Done)
        model.pillEditingText = "Design Sprint 35m"
        model.commitPillTimerEdit()
        
        XCTAssertFalse(model.isEditingTimerInPill, "Editor must be dismissed after commit")
        XCTAssertEqual(model.customTimerTitle, "Design Sprint")
        XCTAssertEqual(model.pomodoro.timeRemaining, 35 * 60)
        XCTAssertTrue(model.pomodoro.isRunning)
    }
    
    // MARK: - Requirement 10b: Clicking Bar Directly Triggers Inline Editing & Shortened 300pt Width
    func testClickingBarActivatesEditingAndShortenedWidth() {
        model.startFocusTimerInPill(minutes: 15, title: "Sprint", autoStart: true)
        XCTAssertEqual(model.compactHUDMode, .pomodoroOnly)
        XCTAssertEqual(model.compactWidth, 300, "Must be shortened to 300 pt")
        XCTAssertFalse(model.isEditingTimerInPill)
        
        // When user clicks anywhere onto the pill bar
        model.startEditingTimerInPill()
        XCTAssertTrue(model.isEditingTimerInPill)
        XCTAssertEqual(model.pillEditingText, "Sprint 15m")
        
        // Canceling editing restores pill view
        model.cancelPillTimerEdit()
        XCTAssertFalse(model.isEditingTimerInPill)
        XCTAssertEqual(model.compactWidth, 300)
    }
    
    // MARK: - Requirement 11: Stopping the Timer from 2nd Screenshot UI
    func testStopTimerFromPillUI() {
        model.startFocusTimerInPill(minutes: 25, title: "Focus", autoStart: true)
        XCTAssertTrue(model.isCompactActive)
        XCTAssertEqual(model.compactHUDMode, .pomodoroOnly)
        XCTAssertEqual(model.islandState, .extendedPill)
        
        // User clicks the Stop button (stop.fill)
        model.stopFocusTimer()
        
        XCTAssertFalse(model.pomodoro.isRunning, "Timer must be stopped")
        XCTAssertFalse(model.isPomodoroSessionActive, "Session must be deactivated")
        XCTAssertEqual(model.compactHUDMode, .none, "HUD mode must clear to .none")
        XCTAssertEqual(model.islandState, .resting, "Island must return to resting notch state")
        XCTAssertEqual(model.currentWidth, model.idleWidth)
        XCTAssertEqual(model.currentHeight, model.idleHeight)
    }
    
    // MARK: - Requirement 12: Pausing Keeps 2nd Screenshot UI Visible (Doesn't Vanish)
    func testPauseKeepsPillHUDVisible() {
        model.startFocusTimerInPill(minutes: 25, title: "Focus", autoStart: true)
        XCTAssertTrue(model.pomodoro.isRunning)
        XCTAssertEqual(model.islandState, .extendedPill)
        
        // User clicks Pause button
        model.pomodoro.pause()
        XCTAssertFalse(model.pomodoro.isRunning)
        
        // Verify pill HUD remains visible with play button so user can resume!
        XCTAssertTrue(model.isPomodoroSessionActive)
        XCTAssertEqual(model.compactHUDMode, .pomodoroOnly, "Pill must stay active while paused")
        XCTAssertEqual(model.islandState, .extendedPill)
        
        // User clicks Play button to resume
        model.pomodoro.start()
        XCTAssertTrue(model.pomodoro.isRunning)
        XCTAssertEqual(model.islandState, .extendedPill)
    }
    
    // MARK: - Requirement 13: Keyboard Controls (Space to Pause, Stop to Reset)
    func testKeyboardControlsOnTimerPopup() {
        let shortcuts = ShortcutManager.shared
        shortcuts.configure(model: model, controller: controller)
        
        // 1. Launch timer in pill with autoStart: true
        model.triggerTimerPopup(minutes: 25, autoStart: true)
        XCTAssertFalse(model.isTimerPopupActive, "Popup card must not appear")
        XCTAssertTrue(model.isCompactActive, "Pill HUD must be active")
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
        XCTAssertTrue(model.isCompactActive, "Pill remains active while paused so user can resume or edit")
        
        // 3. Stop timer
        model.stopFocusTimer()
        XCTAssertFalse(model.pomodoro.isRunning)
        XCTAssertEqual(model.compactHUDMode, .none)
        XCTAssertEqual(model.islandState, .resting, "Stopping timer must return to resting notch state")
        XCTAssertEqual(model.currentWidth, model.idleWidth)
    }
    
    // MARK: - Requirement 14: Smooth Resting-to-Spotlight Transition Without Glitch
    func testSmoothRestingToSpotlightOpeningWithoutGlitch() {
        XCTAssertEqual(model.islandState, .resting)
        XCTAssertEqual(model.currentWidth, model.idleWidth)
        
        // Mouse enters resting stealth notch
        controller.handleMouseEnter()
        
        XCTAssertTrue(model.isSpotlightBarActive)
        XCTAssertEqual(model.islandState, .spotlightBar)
        XCTAssertEqual(model.currentWidth, model.spotlightBarWidth)
        XCTAssertEqual(model.currentWidth, 510)
        
        // Controller panel is expanded immediately without AppKit frame animation fighting SwiftUI
        XCTAssertGreaterThanOrEqual(controller.panel.frame.width, 510)
    }
    
    // MARK: - Requirement 15: Afterward UI of Timer Placed in Middle Centered
    func testCenteredPomodoroPillViewInAfterwardUI() {
        // Launch focus timer from spotlight typing bar
        model.startFocusTimerInPill(minutes: 25, title: "Deep Work", autoStart: true)
        
        XCTAssertFalse(model.isSpotlightBarActive, "Spotlight bar must dismiss")
        XCTAssertEqual(model.islandState, .extendedPill, "Afterward UI must transition to extended pill")
        XCTAssertEqual(model.compactHUDMode, .pomodoroOnly, "HUD mode must be .pomodoroOnly")
        XCTAssertEqual(model.compactWidth, 300, "Afterward pill must be shortened to 300 pt")
        XCTAssertEqual(model.currentWidth, 300)
        
        // Timer countdown and progress
        XCTAssertEqual(model.pomodoro.remainingMinutes, 25)
        XCTAssertEqual(model.pomodoro.formattedTime, "25:00")
        XCTAssertTrue(model.pomodoro.isRunning)
        
        // Verify stopping returns cleanly to resting state
        model.stopFocusTimer()
        XCTAssertEqual(model.islandState, .resting)
        XCTAssertEqual(model.compactHUDMode, .none)
        XCTAssertEqual(model.currentWidth, model.idleWidth)
    }
    
    // MARK: - Requirement 16: Music Player Spotlight Commands
    func testSpotlightMusicPlayerCommands() {
        // "play lofi" starts music playback and activates mediaOnly HUD
        model.isSpotlightBarActive = true
        model.spotlightQuery = "play lofi"
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: model.spotlightQuery), .music)
        
        let cmd = MorphSpotlightCommandParser.parse(model.spotlightQuery)
        XCTAssertEqual(cmd, .music(action: .play(query: "lofi")))
        
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isSpotlightBarActive)
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertEqual(model.compactHUDMode, .mediaOnly, "Submitting play command must activate mediaOnly compact HUD")
        
        // "pause" pauses music playback
        model.spotlightQuery = "pause"
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: model.spotlightQuery), .music)
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.media.isPlaying)
        
        // "music" opens music tab
        model.spotlightQuery = "music"
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.selectedTab, .music)
    }
    
    // MARK: - Requirement 17: Notes Scratchpad Spotlight Commands
    func testSpotlightNotesScratchpadCommands() {
        // "note buy groceries" appends text and pins to notch HUD
        model.isSpotlightBarActive = true
        model.spotlightQuery = "note buy groceries"
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: model.spotlightQuery), .note)
        
        let cmd = MorphSpotlightCommandParser.parse(model.spotlightQuery)
        XCTAssertEqual(cmd, .note(action: .add(text: "buy groceries", pinToNotch: true)))
        
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isSpotlightBarActive)
        XCTAssertTrue(model.scratchpad.text.contains("buy groceries"))
        XCTAssertTrue(model.isNotePinnedToNotch)
        XCTAssertEqual(model.compactHUDMode, .notesPinned)
        
        // "todo finish proposal" appends second line
        model.spotlightQuery = "todo finish proposal"
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.scratchpad.text.contains("finish proposal"))
        
        // "notes" opens scratchpad expanded tab
        model.spotlightQuery = "notes"
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.selectedTab, .notes)
        
        // "clear notes"
        model.spotlightQuery = "clear notes"
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.scratchpad.text.isEmpty)
        XCTAssertFalse(model.isNotePinnedToNotch)
    }
    
    // MARK: - Requirement 18: Calendar Spotlight Commands
    func testSpotlightCalendarCommands() {
        // "meet Sarah at 2:30pm" creates quick event and opens calendar
        model.isSpotlightBarActive = true
        model.spotlightQuery = "meet Sarah at 2:30pm"
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: model.spotlightQuery), .calendar)
        
        let cmd = MorphSpotlightCommandParser.parse(model.spotlightQuery)
        XCTAssertEqual(cmd, .calendar(action: .add(title: "Sarah", hour: 14, minute: 30, duration: 30)))
        
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isSpotlightBarActive)
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.selectedTab, .calendar)
        XCTAssertTrue(model.calendar.events.contains(where: { $0.title == "Sarah" }))
        
        // "event Team Sync at 10am for 45m"
        model.spotlightQuery = "event Team Sync at 10am for 45m"
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.calendar.events.contains(where: { $0.title == "Team Sync" }))
        
        // "calendar" opens calendar tab
        model.spotlightQuery = "calendar"
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.selectedTab, .calendar)
    }
    
    // MARK: - Requirement 19: Dynamic Icon Type Detection Across Features
    func testSpotlightDynamicIconDetection() {
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "play lofi"), .music)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "pause"), .music)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "note buy groceries"), .note)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "notes"), .note)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "meet Sarah at 3pm"), .calendar)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "calendar"), .calendar)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "25m"), .timer)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: ""), .unknown)
    }
    
    // MARK: - Requirement 20: Standalone Original Resting Clearance
    func testStandaloneOriginalRestingClearance() {
        // Original standalone clearance is exactly 14.0 pt below the top bar
        let dummyScreen = NSScreen.main ?? NSScreen.screens[0]
        controller.panel.updatePosition(screen: dummyScreen, width: model.idleWidth, height: model.idleHeight)
        
        let topBarHeight = max(dummyScreen.safeAreaInsets.top, dummyScreen.frame.maxY - dummyScreen.visibleFrame.maxY)
        let expectedClearance: CGFloat = 14.0
        let expectedY = floor(dummyScreen.frame.maxY - topBarHeight - expectedClearance - model.idleHeight)
        let expectedX = floor(dummyScreen.frame.midX - (model.idleWidth / 2))
        
        XCTAssertEqual(controller.panel.frame.origin.x, expectedX, accuracy: 1.0)
        XCTAssertEqual(controller.panel.frame.origin.y, expectedY, accuracy: 1.0)
    }
}
