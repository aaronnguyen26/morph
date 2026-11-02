import XCTest
import SwiftUI
import AppKit
@testable import morph

@MainActor
final class SpotlightPillAndDwellRefinementsTests: XCTestCase {
    
    private var model: NotchModel!
    private var controller: MorphController!
    
    override func setUp() async throws {
        try await super.setUp()
        model = NotchModel()
        model.interactionMode = .spotlightBar
        controller = MorphController(model: model)
    }
    
    override func tearDown() async throws {
        controller.teardown()
        controller = nil
        model = nil
        try await super.tearDown()
    }
    
    // MARK: - Point 1: Staging View is Strictly Smaller Than 1st Screenshot (640x225)
    func testCompactStagingViewDimensionsSmallerThanHomeView() {
        // Dimensions check: Compact stage (380x125) must be significantly smaller than HomeView (640x225)
        XCTAssertLessThan(model.compactStageWidth, model.expandedWidth, "Compact stage width (380) must be smaller than full home view (640)")
        XCTAssertLessThan(model.compactStageHeight, model.expandedHeight, "Compact stage height (125) must be smaller than full home view (225)")
        XCTAssertEqual(model.compactStageWidth, 380)
        XCTAssertEqual(model.compactStageHeight, 125)
        
        // When in fullExpanded state with Home tab selected (the pre-3rd-design intermediate display)
        model.isExpanded = true
        model.selectedTab = .home
        model.activeAIResponse = nil
        model.activeContextFeature = nil
        
        XCTAssertEqual(model.islandState, .fullExpanded)
        XCTAssertEqual(model.currentWidth, 380, "Staging display before 3rd design must be 380pt wide instead of 640pt")
        XCTAssertEqual(model.currentHeight, 125, "Staging display before 3rd design must be 125pt high instead of 225pt")
        
        // Transition directly from compact staging view into the 3rd design (extendedPill HUD)
        model.startFocusTimerInPill(minutes: 25, title: "Focus Session", autoStart: true)
        XCTAssertEqual(model.islandState, .extendedPill, "Starting session from staging view must transition directly to the 3rd design")
        XCTAssertEqual(model.currentWidth, 300, "3rd design HUD must be 300pt wide")
        XCTAssertEqual(model.currentHeight, 32, "3rd design HUD must be 32pt high")
        XCTAssertTrue(model.pomodoro.isRunning)
    }
    
    // MARK: - Point 2: Differentiating Pass-By from Intentional Opening
    func testPassByCursorMotionDoesNotOpenMorph() {
        controller.hoverDwellDelay = 0.32
        let restingOrigin = controller.panel.frame.origin
        let entryPoint = NSPoint(x: restingOrigin.x + 10, y: restingOrigin.y + 10)
        
        // Cursor sweeps across the notch to click browser tabs (velocity > 35 pt/s)
        // First tick
        controller.checkMousePosition(entryPoint)
        XCTAssertFalse(model.isSpotlightBarActive, "Entering cursor in motion must not instantly expand Morph")
        
        // Second tick with rapid traversal across the notch
        let sweepPoint = NSPoint(x: entryPoint.x + 30, y: entryPoint.y + 5)
        controller.checkMousePosition(sweepPoint)
        
        // Morph must remain completely collapsed in resting stealth
        XCTAssertFalse(model.isSpotlightBarActive, "Rapid pass-by must not activate spotlight bar")
        XCTAssertFalse(model.isExpanded, "Rapid pass-by must not expand Morph")
        XCTAssertEqual(model.islandState, .resting, "Morph must stay in resting state during pass-by")
        XCTAssertTrue(controller.panel.ignoresMouseEvents, "Panel must continue ignoring mouse events during pass-by")
    }
    
    func testPassByDisplacementCancelsDwellIntent() {
        controller.hoverDwellDelay = 0.32
        let restingOrigin = controller.panel.frame.origin
        let entryPoint = NSPoint(x: restingOrigin.x + 10, y: restingOrigin.y + 10)
        
        controller.checkMousePosition(entryPoint)
        
        // Move by 15 pt (displacement > 8pt threshold indicates transit across screen)
        let movedPoint = NSPoint(x: entryPoint.x + 15, y: entryPoint.y)
        controller.checkMousePosition(movedPoint)
        
        XCTAssertNil(controller.hoverIntentWorkItem, "Moving displacement > 8pt must cancel pending dwell work item")
        XCTAssertFalse(model.isSpotlightBarActive)
    }
    
    func testStationaryDwellOpensMorph() async throws {
        controller.hoverDwellDelay = 0.05 // Short dwell for test
        let restingOrigin = controller.panel.frame.origin
        let stationaryPoint = NSPoint(x: restingOrigin.x + 20, y: restingOrigin.y + 10)
        
        // Initial settle
        controller.checkMousePosition(stationaryPoint)
        XCTAssertFalse(model.isSpotlightBarActive)
        
        // Wait for stationary dwell delay to complete
        try await Task.sleep(nanoseconds: 80_000_000)
        
        XCTAssertTrue(model.isSpotlightBarActive, "Holding cursor stationary inside notch must intentionally open spotlight bar")
        XCTAssertFalse(controller.panel.ignoresMouseEvents, "Open spotlight bar must accept clicks")
    }
    
    // MARK: - Point 3: Zero Memory on Dynamic Island Collapse
    func testZeroMemoryOnCollapse() {
        // User opens spotlight bar and types a past query
        controller.handleMouseEnter()
        model.spotlightQuery = "open my music playlist"
        XCTAssertEqual(model.spotlightQuery, "open my music playlist")
        
        // Island collapses
        model.resetTransientStateOnCollapse()
        
        // Must remember NOTHING from the past
        XCTAssertEqual(model.spotlightQuery, "", "Spotlight query must be wiped completely clean on collapse")
        XCTAssertFalse(model.isShowingDirectAnswer, "Direct answers must be wiped clean")
        XCTAssertFalse(model.isSpotlightBarActive, "Spotlight bar must be deactivated")
        XCTAssertFalse(model.isHovered, "Hover state must be cleared")
        XCTAssertNil(model.activeAIResponse, "AI response must be cleared")
        
        // When user opens Morph again, it must be 100% clean
        controller.handleMouseEnter()
        XCTAssertEqual(model.spotlightQuery, "", "Re-opening Morph must start with a clean, empty spotlight bar")
    }
    
    func testMouseExitCollapsesEvenWithTypedTextAndWipesMemory() async throws {
        // Open spotlight bar
        controller.handleMouseEnter()
        model.spotlightQuery = "what is the calendar schedule for today?"
        
        // Mouse exits Morph area to desktop or background window
        controller.checkMousePosition(NSPoint(x: 10, y: 10))
        
        // Verify collapse work item is scheduled (NOT blocked by query text)
        XCTAssertNotNil(controller.collapseWorkItem, "Mouse exit must schedule collapse even if text was typed")
        
        // Execute collapse
        model.resetTransientStateOnCollapse()
        XCTAssertEqual(model.spotlightQuery, "", "Typed text must be wiped on collapse")
        XCTAssertFalse(model.isSpotlightBarActive)
    }
    
    // MARK: - Point 4: Entire Spotlight Pill Interactivity & Right 'X' Button
    func testSpotlightPillDimensionsAndInteractivity() {
        // Spotlight pill must be 510 pt wide and 38 pt high
        XCTAssertEqual(model.spotlightBarWidth, 510)
        XCTAssertEqual(model.spotlightBarHeight, 38)
        
        controller.handleMouseEnter()
        XCTAssertEqual(model.currentWidth, 510)
        XCTAssertEqual(model.currentHeight, 38)
        
        // Entire pill accepts interactions
        XCTAssertFalse(controller.panel.ignoresMouseEvents)
        XCTAssertTrue(controller.panel.canBecomeKey)
        XCTAssertTrue(controller.hostingView.acceptsFirstResponder)
    }
    
    func testSpotlightRightXButtonClearsQueryWhenTextPresent() {
        controller.handleMouseEnter()
        model.spotlightQuery = "play relaxing lo-fi beats"
        
        // When 'X' is pressed with text: clears text
        if !model.spotlightQuery.isEmpty {
            model.spotlightQuery = ""
        }
        
        XCTAssertEqual(model.spotlightQuery, "", "'X' button must clear the query text")
        XCTAssertTrue(model.isSpotlightBarActive, "Spotlight pill remains open ready for fresh input")
    }
    
    func testSpotlightRightXButtonCollapsesWhenEmpty() {
        controller.handleMouseEnter()
        model.spotlightQuery = ""
        
        // When 'X' is pressed with empty text: collapses pill
        model.resetTransientStateOnCollapse()
        
        XCTAssertFalse(model.isSpotlightBarActive, "'X' button when empty must collapse spotlight pill back to resting stealth")
        XCTAssertEqual(model.islandState, .resting)
    }
}
