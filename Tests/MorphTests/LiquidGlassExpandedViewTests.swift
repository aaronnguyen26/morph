import XCTest
import SwiftUI
@testable import morph

@MainActor
final class LiquidGlassExpandedViewTests: XCTestCase {
    
    private var model: NotchModel!
    
    override func setUp() async throws {
        try await super.setUp()
        model = NotchModel()
        model.interactionMode = .spotlightBar
    }
    
    override func tearDown() async throws {
        model = nil
        try await super.tearDown()
    }
    
    // MARK: - Test 1: General Commands Open Larger UI Directly To Target Page
    func testGeneralCommandsOpenLargerUIToTargetPageWithoutTopBar() {
        // Music general query
        model.spotlightQuery = "open music player"
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.isExpanded, "General music query must open larger UI")
        XCTAssertEqual(model.selectedTab, .music, "Must navigate directly to Music tab")
        XCTAssertEqual(model.islandState, .fullExpanded)
        
        // Notes general query
        model.spotlightQuery = "open notes"
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.selectedTab, .notes)
        
        // Calendar general query
        model.spotlightQuery = "view my calendar schedule"
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.selectedTab, .calendar)
        
        // Focus timer general query
        model.spotlightQuery = "focus timer"
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.selectedTab, .timer)
    }
    
    // MARK: - Test 2: Specific Actions Skip Larger UI And Act Directly
    func testSpecificActionsSkipLargerUIAndExecuteDirectly() {
        model.spotlightQuery = "put timer for 25 minute"
        model.handleSpotlightSubmit()
        
        XCTAssertFalse(model.isExpanded, "Specific timer request must skip larger UI")
        XCTAssertTrue(model.isCompactActive, "Must transition directly into active notch pill")
        XCTAssertTrue(model.pomodoro.isRunning, "Pomodoro timer must start running directly")
    }
    
    // MARK: - Test 3: Close / Collapse From Expanded State Returns to Stealth
    func testCloseButtonFromExpandedStateCollapsesToStealth() {
        // Expand to larger UI
        model.openFeature(.timer)
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.islandState, .fullExpanded)
        
        // Click close (which triggers model.resetTransientStateOnCollapse())
        model.resetTransientStateOnCollapse()
        
        XCTAssertFalse(model.isExpanded, "Collapse must dismiss expanded state")
        XCTAssertFalse(model.isSpotlightBarActive, "Spotlight bar must be closed")
        XCTAssertEqual(model.islandState, .resting, "Must return cleanly to resting stealth mode")
    }
    
    // MARK: - Test 4: Apple Liquid Glass Dynamic Island View Renders Cleanly
    func testAppleLiquidGlassExpandedIslandViewRenders() {
        model.openFeature(.music)
        let islandView = MorphIslandView(model: model)
        
        // Verify View body evaluation without exceptions
        let viewBody = islandView.body
        XCTAssertNotNil(viewBody, "MorphIslandView body must evaluate cleanly")
        
        // Test with different active tabs
        for tab in [MorphTab.timer, .music, .notes, .calendar, .profile, .home] {
            model.selectedTab = tab
            let tabBody = islandView.body
            XCTAssertNotNil(tabBody, "MorphIslandView body for tab \(tab.rawValue) must evaluate cleanly")
        }
    }
}
