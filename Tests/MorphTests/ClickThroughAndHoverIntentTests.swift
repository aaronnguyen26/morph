import XCTest
import SwiftUI
import AppKit
@testable import morph

@MainActor
final class ClickThroughAndHoverIntentTests: XCTestCase {
    
    func testPassthroughHostingViewReturnsNilWhenIdle() {
        let model = NotchModel()
        model.isExpanded = false
        
        let islandView = MorphIslandView(model: model, onMouseEnter: {}, onMouseExit: {})
        let hostingView = PassthroughHostingView(rootView: islandView)
        hostingView.isExpanded = { model.isExpanded }
        hostingView.frame = NSRect(x: 0, y: 0, width: 210, height: 36)
        hostingView.layoutSubtreeIfNeeded()
        
        // Test multiple points across the pill bounds
        let centerPoint = NSPoint(x: 105, y: 18)
        let leftPoint = NSPoint(x: 20, y: 18)
        let rightPoint = NSPoint(x: 190, y: 18)
        let topPoint = NSPoint(x: 105, y: 30)
        let bottomPoint = NSPoint(x: 105, y: 5)
        
        // While idle, hitTest MUST ALWAYS return nil so clicks pass straight through to background windows
        XCTAssertNil(hostingView.hitTest(centerPoint), "Center point must return nil to allow click-through")
        XCTAssertNil(hostingView.hitTest(leftPoint), "Left point must return nil to allow click-through")
        XCTAssertNil(hostingView.hitTest(rightPoint), "Right point must return nil to allow click-through")
        XCTAssertNil(hostingView.hitTest(topPoint), "Top point must return nil to allow click-through")
        XCTAssertNil(hostingView.hitTest(bottomPoint), "Bottom point must return nil to allow click-through")
    }
    
    func testPassthroughHostingViewAcceptsClicksWhenExpanded() {
        let model = NotchModel()
        model.isExpanded = true
        
        let islandView = MorphIslandView(model: model, onMouseEnter: {}, onMouseExit: {})
        let hostingView = PassthroughHostingView(rootView: islandView)
        hostingView.isExpanded = { model.isExpanded }
        hostingView.frame = NSRect(x: 0, y: 0, width: 640, height: 225)
        hostingView.layoutSubtreeIfNeeded()
        
        let centerPoint = NSPoint(x: 320, y: 112)
        XCTAssertNotNil(hostingView.hitTest(centerPoint), "When expanded, hosting view must accept clicks for UI controls")
    }
    
    func testDynamicIslandRestingDimensionsAndPosition() {
        let model = NotchModel()
        XCTAssertEqual(model.idleWidth, 179)
        XCTAssertEqual(model.idleHeight, 32)
        XCTAssertFalse(model.isExpanded)
        
        // Verify panel frame placement with original 14pt floating clearance below top bar
        let dummyScreen = NSScreen.main ?? NSScreen.screens[0]
        let panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: model.idleWidth, height: model.idleHeight))
        panel.updatePosition(screen: dummyScreen, width: model.idleWidth, height: model.idleHeight)
        
        let topBarHeight = max(dummyScreen.safeAreaInsets.top, dummyScreen.frame.maxY - dummyScreen.visibleFrame.maxY)
        let topClearance: CGFloat = 14.0
        let expectedY = floor(dummyScreen.frame.maxY - topBarHeight - topClearance - model.idleHeight)
        let expectedX = floor(dummyScreen.frame.midX - (model.idleWidth / 2))
        
        XCTAssertEqual(panel.frame.origin.x, expectedX, accuracy: 1.0)
        XCTAssertEqual(panel.frame.origin.y, expectedY, accuracy: 1.0)
        XCTAssertEqual(panel.frame.width, model.idleWidth, accuracy: 1.0)
        XCTAssertEqual(panel.frame.height, model.idleHeight, accuracy: 1.0)
    }
    
    func testPanelIgnoresMouseEventsWhenIdle() {
        let panel = NotchPanel(contentRect: NSRect(x: 0, y: 0, width: 210, height: 36))
        XCTAssertTrue(panel.ignoresMouseEvents, "Panel must ignore mouse events by default when created")
    }
    
    func testMorphControllerClickThroughModeAndDwellLogic() {
        let model = NotchModel()
        let controller = MorphController(model: model)
        controller.hoverDwellDelay = 0.32
        defer { controller.teardown() }
        
        // 1. Initial State: not expanded, panel ignores mouse events
        XCTAssertFalse(model.isExpanded)
        XCTAssertTrue(controller.panel.ignoresMouseEvents, "Collapsed Morph must ignore mouse events to allow clicking browser tabs")
        
        // 2. Fast mouse sweep (simulating flick to browser tab)
        let uiRect = controller.activeUIRect()
        let insidePt1 = NSPoint(x: uiRect.midX - 50, y: uiRect.midY)
        let insidePt2 = NSPoint(x: uiRect.midX + 50, y: uiRect.midY)
        
        // Move to pt1
        controller.checkMousePosition(insidePt1)
        // Immediately move 100px away (high velocity sweep)
        controller.checkMousePosition(insidePt2)
        
        // Fast sweep must NOT immediately expand panel
        XCTAssertFalse(model.isExpanded, "Fast cursor sweep across island must not trigger expansion")
        XCTAssertTrue(controller.panel.ignoresMouseEvents, "Fast sweep must preserve click-through mode")
    }
    
    func testUniversalPlatformInteractionSuppressesAccidentalExpansion() {
        let model = NotchModel()
        let controller = MorphController(model: model)
        controller.hoverDwellDelay = 0.32
        defer { controller.teardown() }
        
        let uiRect = controller.activeUIRect()
        let insidePt = NSPoint(x: uiRect.midX, y: uiRect.midY)
        
        // Scenario 1: User is clicking in ANY app (VS Code, Terminal, Figma, Slack, Word, etc.)
        controller.registerUnderlyingAppInteraction()
        controller.checkMousePosition(insidePt)
        XCTAssertFalse(model.isExpanded, "Clicks in underlying app must suppress hover expansion")
        XCTAssertNil(controller.hoverIntentWorkItem, "Pending hover work item must be canceled upon underlying app click")
        
        // Scenario 2: Zero bottom padding ensures titlebar tabs / controls of ANY app are 100% accessible
        let justBelowPill = NSPoint(x: uiRect.midX, y: uiRect.minY - 2)
        XCTAssertFalse(controller.isMouseInsideMorphUI(justBelowPill), "Points below the resting pill must not be captured, preserving full accessibility for tabs/controls in any app")
    }
    
    // MARK: - Glass Island Pass-By vs Intentional Hover Dwell Tests
    func testGlassIslandPassByCursorMotionDoesNotOpen() {
        let model = NotchModel()
        model.isGlassIslandEnabled = true
        model.setGlassIslandState(.idle)
        
        let controller = MorphController(model: model)
        controller.hoverDwellDelay = 0.32
        defer { controller.teardown() }
        
        let uiRect = controller.activeUIRect()
        let insidePt1 = NSPoint(x: uiRect.midX - 40, y: uiRect.midY)
        let insidePt2 = NSPoint(x: uiRect.midX + 40, y: uiRect.midY)
        
        // Fast sweep across the dynamic island (cursor passing through)
        controller.checkMousePosition(insidePt1)
        controller.checkMousePosition(insidePt2)
        
        XCTAssertEqual(model.glassIslandState, .idle, "Cursor sweeping through dynamic island must NOT expand it")
        XCTAssertFalse(model.isHovered, "Pass-by motion must not set isHovered")
        XCTAssertNil(controller.hoverIntentWorkItem, "Pass-by motion with displacement > 8 must cancel dwell intent")
    }
    
    func testGlassIslandStationaryDwellOpensIntentionalHover() async throws {
        let model = NotchModel()
        model.isGlassIslandEnabled = true
        model.setGlassIslandState(.idle)
        
        let controller = MorphController(model: model)
        controller.hoverDwellDelay = 0.05 // Short dwell for test execution
        defer { controller.teardown() }
        
        let uiRect = controller.activeUIRect()
        let stationaryPt = NSPoint(x: uiRect.midX, y: uiRect.midY)
        
        // Cursor settles stationary inside dynamic island
        controller.checkMousePosition(stationaryPt)
        XCTAssertEqual(model.glassIslandState, .idle, "Must stay idle initially before dwell completes")
        
        // Wait for stationary dwell delay to complete
        try await Task.sleep(nanoseconds: 80_000_000)
        
        XCTAssertNotEqual(model.glassIslandState, .idle, "Stationary dwell over dynamic island must intentionally expand it")
        XCTAssertEqual(model.glassIslandState, model.contextualOpenState, "Must expand to contextual open state")
    }
    
    func testGlassIslandTargetedMiniSubWidgetDwellOpensTarget() {
        let model = NotchModel()
        model.isGlassIslandEnabled = true
        model.setGlassIslandState(.idle)
        
        let controller = MorphController(model: model)
        controller.hoverDwellDelay = 0.0
        defer { controller.teardown() }
        
        // When user hovers on miniTimerView, targetedHoverGlassState is set
        model.targetedHoverGlassState = .timer
        controller.handleMouseEnter()
        XCTAssertEqual(model.glassIslandState, .timer, "Hover dwell targeted on timer mini widget must open timer")
        XCTAssertNil(model.targetedHoverGlassState, "Targeted state must be consumed on open")
        
        // When user hovers on miniMusicView
        model.setGlassIslandState(.idle)
        model.targetedHoverGlassState = .music
        controller.handleMouseEnter()
        XCTAssertEqual(model.glassIslandState, .music, "Hover dwell targeted on music mini widget must open music")
        XCTAssertNil(model.targetedHoverGlassState)
    }
}
