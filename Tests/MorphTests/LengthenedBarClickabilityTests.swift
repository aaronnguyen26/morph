import XCTest
import SwiftUI
import AppKit
@testable import morph

@MainActor
final class LengthenedBarClickabilityTests: XCTestCase {
    
    var model: NotchModel!
    var controller: MorphController!
    
    override func setUp() async throws {
        try await super.setUp()
        model = NotchModel()
        controller = MorphController(model: model)
    }
    
    override func tearDown() async throws {
        controller.teardown()
        controller = nil
        model = nil
        try await super.tearDown()
    }
    
    // MARK: - 1. Every Part of the Lengthened Bar is Clickable (Zero Passthrough to Desktop)
    func testLengthenedBarEveryPartIsClickable() {
        // Activate the lengthened spotlight bar
        model.interactionMode = .spotlightBar
        model.isSpotlightBarActive = true
        controller.updatePanelGeometry(animate: false)
        
        XCTAssertEqual(model.islandState, .spotlightBar)
        XCTAssertEqual(model.currentWidth, 510)
        XCTAssertEqual(model.currentHeight, 38)
        
        // Critical: Panel MUST NOT ignore mouse events (otherwise clicks go to Desktop Wallpaper, triggering Mission Control!)
        XCTAssertFalse(controller.shouldIgnoreMouseEvents, "Lengthened bar must never ignore mouse events")
        XCTAssertFalse(controller.panel.ignoresMouseEvents, "Panel ignoresMouseEvents must be false so clicks are captured by Morph")
        
        let hostingView = controller.hostingView!
        hostingView.frame = NSRect(x: 0, y: 0, width: 510, height: 38)
        hostingView.layoutSubtreeIfNeeded()
        
        // Test points across EVERY PART of the lengthened bar:
        let testPoints: [(name: String, point: NSPoint)] = [
            ("Leftmost margin", NSPoint(x: 10, y: 19)),
            ("Morphy mascot", NSPoint(x: 25, y: 19)),
            ("Search glass icon", NSPoint(x: 55, y: 19)),
            ("TextField start", NSPoint(x: 100, y: 19)),
            ("Center of bar / typing area", NSPoint(x: 255, y: 19)),
            ("TextField right", NSPoint(x: 400, y: 19)),
            ("Right margin before 'X'", NSPoint(x: 475, y: 19)),
            ("Right side 'X' close button", NSPoint(x: 495, y: 19)),
            ("Top edge", NSPoint(x: 255, y: 36)),
            ("Bottom edge", NSPoint(x: 255, y: 2))
        ]
        
        for tp in testPoints {
            let hitView = hostingView.hitTest(tp.point)
            XCTAssertNotNil(
                hitView,
                "Point at '\(tp.name)' (\(tp.point.x), \(tp.point.y)) must be clickable and return a valid NSView, not nil"
            )
        }
    }
    
    // MARK: - 2. Clicking on the Bar Keeps It There (Does Not Move Background Windows)
    func testClickingLengthenedBarKeepsItThereWithoutMovingBackground() {
        model.interactionMode = .spotlightBar
        model.isSpotlightBarActive = true
        controller.updatePanelGeometry(animate: false)
        
        XCTAssertTrue(model.isSpotlightBarActive)
        XCTAssertEqual(model.islandState, .spotlightBar)
        
        // Simulate user clicking on various positions of the bar
        let centerPoint = NSPoint(x: controller.panel.frame.midX, y: controller.panel.frame.midY)
        XCTAssertTrue(controller.isMouseInsideMorphUI(centerPoint), "Click point must be recognized inside Morph UI")
        
        // Simulate mouse check at click location
        controller.checkMousePosition(centerPoint)
        
        // Morph must STAY in place
        XCTAssertTrue(model.isSpotlightBarActive, "Bar must stay active when clicked")
        XCTAssertEqual(model.islandState, .spotlightBar)
        XCTAssertFalse(controller.panel.ignoresMouseEvents, "Clicks must stay trapped in Morph without triggering Mac Mission Control")
        XCTAssertNil(controller.collapseWorkItem, "Clicking the bar must not initiate collapse")
    }
    
    // MARK: - 3. Right Side 'X' Button Functionality (Cleanly Closes the Bar)
    func testRightSideXButtonFunctionalityClosesBar() {
        model.interactionMode = .spotlightBar
        model.isSpotlightBarActive = true
        model.spotlightQuery = "Write email to Alex"
        controller.updatePanelGeometry(animate: false)
        
        XCTAssertTrue(model.isSpotlightBarActive)
        XCTAssertEqual(model.spotlightQuery, "Write email to Alex")
        
        // Simulating user clicking the 'X' button on the right side:
        // 'X' button action executes handleSpotlightCloseOrClear() -> resetTransientStateOnCollapse()
        model.resetTransientStateOnCollapse()
        
        XCTAssertFalse(model.isSpotlightBarActive, "Clicking 'X' button must deactivate spotlight bar")
        XCTAssertEqual(model.spotlightQuery, "", "Clicking 'X' button must clear the search query")
        XCTAssertEqual(model.islandState, .resting, "Bar must return to resting notch state")
        
        // Shrink panel back to resting dimensions
        controller.applyRestingPanelGeometry()
        XCTAssertEqual(controller.panel.frame.width, model.idleWidth, accuracy: 1.0)
        XCTAssertEqual(controller.panel.frame.height, model.idleHeight, accuracy: 1.0)
    }
    
    // MARK: - 4. Points Outside Active Bounds Allow Passthrough
    func testPointsOutsideActiveBoundsAllowPassthrough() {
        model.interactionMode = .spotlightBar
        model.isSpotlightBarActive = true
        controller.updatePanelGeometry(animate: false)
        
        let hostingView = controller.hostingView!
        hostingView.frame = NSRect(x: 0, y: 0, width: 510, height: 38)
        
        // Point far outside the bar bounds
        let outsidePoint = NSPoint(x: 600, y: 100)
        XCTAssertNil(hostingView.hitTest(outsidePoint), "Points outside active bounds must pass through")
    }
    
    // MARK: - 5. Resting Notch Mode Preserves Click-Through for Browser Tabs
    func testRestingNotchAllowsClickThroughForBackgroundBrowserTabs() {
        model.interactionMode = .spotlightBar
        model.isSpotlightBarActive = false
        model.isExpanded = false
        controller.applyRestingPanelGeometry()
        
        XCTAssertEqual(model.islandState, .resting)
        XCTAssertTrue(controller.shouldIgnoreMouseEvents, "Resting idle notch should ignore mouse events to allow clicking browser tabs")
        
        let hostingView = controller.hostingView!
        hostingView.frame = NSRect(x: 0, y: 0, width: model.idleWidth, height: model.idleHeight)
        
        // Points on resting notch return nil so background browser tabs are clickable
        let center = NSPoint(x: model.idleWidth / 2, y: model.idleHeight / 2)
        XCTAssertNil(hostingView.hitTest(center), "Idle resting notch must allow click-through")
    }
    
    // MARK: - 6. Extended Timer Pill Every Part is Clickable & 'X' Stops Timer
    func testExtendedTimerPillEveryPartIsClickableAndXStopsTimer() {
        model.startFocusTimerInPill(minutes: 25, title: "Deep Work", autoStart: true)
        controller.updatePanelGeometry(animate: false)
        
        XCTAssertEqual(model.compactHUDMode, .pomodoroOnly)
        XCTAssertEqual(model.currentWidth, 300)
        XCTAssertEqual(model.islandState, .extendedPill)
        
        XCTAssertFalse(controller.shouldIgnoreMouseEvents)
        XCTAssertFalse(controller.panel.ignoresMouseEvents)
        
        let hostingView = controller.hostingView!
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: model.idleHeight)
        hostingView.layoutSubtreeIfNeeded()
        
        // Test points across 300pt timer pill:
        let timerPillPoints: [(name: String, point: NSPoint)] = [
            ("Left mascot/flame", NSPoint(x: 20, y: 16)),
            ("Timer countdown text", NSPoint(x: 100, y: 16)),
            ("Middle pill area", NSPoint(x: 150, y: 16)),
            ("Right side 'X' stop button", NSPoint(x: 285, y: 16))
        ]
        
        for tp in timerPillPoints {
            let hitView = hostingView.hitTest(tp.point)
            XCTAssertNotNil(hitView, "Point at '\(tp.name)' (\(tp.point.x), \(tp.point.y)) must be clickable")
        }
        
        // User clicks the 'X' button
        model.stopFocusTimer()
        XCTAssertFalse(model.pomodoro.isRunning)
        XCTAssertEqual(model.islandState, .resting)
    }
    
    // MARK: - 7. Dismissing via 'X' Button Cleanly Collapses to Stealth Mode Without Bouncing
    func testDismissToStealthSmoothlyCollapsesWithoutBouncing() {
        model.interactionMode = .spotlightBar
        model.isSpotlightBarActive = true
        model.spotlightQuery = "Focus on coding"
        controller.updatePanelGeometry(animate: false)
        
        XCTAssertTrue(model.isSpotlightBarActive)
        XCTAssertEqual(model.islandState, .spotlightBar)
        XCTAssertEqual(model.currentWidth, 510)
        
        let screen = controller.targetScreen()
        // Cursor location on the 'X' button (right side of 510-pt bar)
        let xButtonScreenPoint = NSPoint(x: screen.frame.midX + 240, y: controller.panel.frame.midY)
        XCTAssertTrue(controller.isMouseInsideMorphUI(xButtonScreenPoint), "Cursor on 'X' button must initially be inside 510pt bar")
        
        // User clicks the 'X' button
        controller.dismissToStealth()
        
        // 1. Immediately returned to stealth / resting state
        XCTAssertFalse(model.isSpotlightBarActive, "Spotlight bar must immediately deactivate")
        XCTAssertEqual(model.islandState, .resting, "Island state must be .resting")
        XCTAssertEqual(model.spotlightQuery, "", "Spotlight query must be cleared")
        XCTAssertEqual(model.currentWidth, model.idleWidth, "Width must immediately target resting notch width")
        XCTAssertEqual(model.currentHeight, model.idleHeight, "Height must immediately target resting notch height")
        
        // 2. Explicitly dismissed flag prevents bouncing even if mouse is still at the old 'X' coordinate
        XCTAssertTrue(controller.isExplicitlyDismissed, "Explicitly dismissed flag must be true")
        XCTAssertNil(controller.hoverIntentWorkItem, "Pending hover work items must be cancelled")
        XCTAssertNil(controller.collapseWorkItem, "Pending collapse work items must be cancelled")
        
        // 3. Check cursor position at old 'X' location:
        // Since resting notch width is 179 pt (extending from midX - 89.5 to midX + 89.5),
        // the coordinate at midX + 240 is now completely OUTSIDE the resting notch!
        XCTAssertFalse(controller.isMouseInsideMorphUI(xButtonScreenPoint), "Cursor at former 'X' coordinate is now outside 179pt resting notch")
        
        // Next poller tick at that coordinate:
        controller.checkMousePosition(xButtonScreenPoint)
        
        // Must stay resting and NOT bounce back or schedule expansion
        XCTAssertFalse(model.isSpotlightBarActive, "Must NOT re-expand or bounce")
        XCTAssertEqual(model.islandState, .resting, "Must remain in .resting stealth mode")
        XCTAssertNil(controller.hoverIntentWorkItem, "Must NOT schedule hover expansion")
    }
}
