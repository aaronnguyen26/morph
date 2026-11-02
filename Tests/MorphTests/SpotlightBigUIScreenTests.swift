import XCTest
import SwiftUI
import AppKit
@testable import morph

@MainActor
final class SpotlightBigUIScreenTests: XCTestCase {
    
    private var model: NotchModel!
    private var controller: MorphController!
    
    override func setUp() async throws {
        try await super.setUp()
        model = NotchModel()
        model.interactionMode = .spotlightBar
        controller = MorphController(model: model)
        controller.hoverDwellDelay = 0.0 // Instant for test execution
    }
    
    override func tearDown() async throws {
        controller.teardown()
        controller = nil
        model = nil
        try await super.tearDown()
    }
    
    // MARK: - Point 1: Spotlight Pill Clickability & Window Key Activation
    func testSpotlightPillCanBecomeKeyAndAcceptsClicks() {
        // In resting state, panel ignores mouse events
        XCTAssertTrue(controller.panel.ignoresMouseEvents)
        XCTAssertTrue(controller.panel.canBecomeKey, "Panel must be able to become key for text input")
        XCTAssertTrue(controller.hostingView.acceptsFirstResponder, "HostingView must accept first responder for typing")
        
        // Trigger hover expansion into Spotlight bar
        controller.handleMouseEnter()
        XCTAssertTrue(model.isSpotlightBarActive)
        XCTAssertFalse(controller.panel.ignoresMouseEvents, "Active spotlight bar must NOT ignore mouse events so user can click to type")
        XCTAssertEqual(model.currentWidth, 510.0, "Widened spotlight bar width must be 510pt")
    }
    
    // MARK: - Point 2: Queries Open the Biggest UI Screen (Not Just "Noted" in Pill)
    func testAIQueriesDisplayInBiggestUIScreen() {
        // Query: "what is cross entropy loss?" (from user's lecture notes screenshot)
        model.spotlightQuery = "what is cross entropy loss?"
        model.handleSpotlightSubmit()
        
        // Must expand to the biggest UI screen
        XCTAssertTrue(model.isExpanded, "AI query must expand into the biggest UI screen")
        XCTAssertEqual(model.expandedWidth, 640.0, "Biggest UI screen width must be 640pt")
        XCTAssertNotNil(model.activeAIResponse, "Must generate a rich AI response")
        
        if let ai = model.activeAIResponse {
            XCTAssertTrue(ai.title.contains("Cross-Entropy Loss"), "Title must identify Cross-Entropy Loss")
            XCTAssertTrue(ai.detailedContent.contains("ℓ(θ) = - ∑"), "Detailed content must include mathematical formula")
            XCTAssertFalse(ai.keyPoints.isEmpty, "Key insights must be populated")
            XCTAssertFalse(ai.suggestedActions.isEmpty, "Action buttons must be present")
        }
        
        // Query must NOT be trapped in a tiny "noted" pill
        XCTAssertFalse(model.isSpotlightBarActive, "Spotlight typing pill must collapse when expanding into the biggest UI screen")
        XCTAssertTrue(model.spotlightQuery.isEmpty, "Query input must be cleared")
    }
    
    func testMathEvaluationDisplaysInBiggestUIScreen() {
        model.spotlightQuery = "15 * 4"
        model.handleSpotlightSubmit()
        
        XCTAssertTrue(model.isExpanded, "Math query must expand into biggest UI screen")
        XCTAssertNotNil(model.activeAIResponse)
        XCTAssertTrue(model.activeAIResponse?.summary.contains("60") ?? false, "Math answer must be evaluated to 60")
    }
    
    func testStudyPlanQueryDisplaysInBiggestUIScreen() {
        model.spotlightQuery = "study plan for my ML exam"
        model.handleSpotlightSubmit()
        
        XCTAssertTrue(model.isExpanded, "Study plan query must expand into biggest UI screen")
        XCTAssertNotNil(model.activeAIResponse)
        XCTAssertEqual(model.activeAIResponse?.category, "Study Advisor")
    }
    
    func testGeneralQuestionDisplaysInBiggestUIScreen() {
        model.spotlightQuery = "what can you do?"
        model.handleSpotlightSubmit()
        
        XCTAssertTrue(model.isExpanded, "General question must expand into biggest UI screen")
        XCTAssertNotNil(model.activeAIResponse)
        XCTAssertEqual(model.activeAIResponse?.category, "System Capabilities")
    }
    
    // MARK: - Point 2 (Continued): Notes, Calendar, Music Open in Biggest UI Screen
    func testNotesCommandOpensInBiggestUIScreen() {
        model.spotlightQuery = "note sociology reading response #4"
        model.handleSpotlightSubmit()
        
        XCTAssertTrue(model.isExpanded, "Note command must open in the biggest UI screen")
        XCTAssertEqual(model.selectedTab, .notes, "Must navigate to the Notes tab")
        XCTAssertTrue(model.scratchpad.text.contains("sociology reading response #4"), "Note must be captured in scratchpad text")
    }
    
    func testCalendarCommandOpensInBiggestUIScreen() {
        model.spotlightQuery = "what is my plan for today"
        model.handleSpotlightSubmit()
        
        XCTAssertTrue(model.isExpanded, "Calendar command must open in the biggest UI screen")
        XCTAssertEqual(model.selectedTab, .calendar, "Must navigate to the Calendar tab")
    }
    
    func testMusicCommandOpensInBiggestUIScreen() {
        model.spotlightQuery = "play lofi beats"
        model.handleSpotlightSubmit()
        
        XCTAssertTrue(model.isExpanded, "Music command must open in the biggest UI screen")
        XCTAssertEqual(model.selectedTab, .music, "Must navigate to the Music tab")
    }
    
    // MARK: - Point 3: Resting Stealth Position & Scroll-Past Identification
    func testRestingStealthPositionMatchesScreenshotSpecification() {
        let dummyScreen = NSScreen.main ?? NSScreen.screens[0]
        controller.panel.updatePosition(screen: dummyScreen, width: model.idleWidth, height: model.idleHeight)
        
        let topBarHeight = max(dummyScreen.safeAreaInsets.top, dummyScreen.frame.maxY - dummyScreen.visibleFrame.maxY)
        let topClearance: CGFloat = 14.0
        let expectedY = floor(dummyScreen.frame.maxY - topBarHeight - topClearance - model.idleHeight)
        let expectedX = floor(dummyScreen.frame.midX - (model.idleWidth / 2))
        
        XCTAssertEqual(controller.panel.frame.origin.x, expectedX, accuracy: 1.0, "Must be centered horizontally")
        XCTAssertEqual(controller.panel.frame.origin.y, expectedY, accuracy: 1.0, "Must sit exactly 14pt below top bar clearance")
        XCTAssertEqual(controller.panel.frame.width, 179.0, accuracy: 1.0)
        XCTAssertEqual(controller.panel.frame.height, 32.0, accuracy: 1.0)
    }
    
    func testSwiftScrollOrMouseSweepPastNotchDoesNotOpen() {
        controller.hoverDwellDelay = 0.28
        let uiRect = controller.activeUIRect()
        let insidePt1 = NSPoint(x: uiRect.midX - 40, y: uiRect.midY)
        let insidePt2 = NSPoint(x: uiRect.midX + 40, y: uiRect.midY)
        
        // Fast sweep across the notch space
        controller.checkMousePosition(insidePt1)
        controller.checkMousePosition(insidePt2)
        
        // Must NOT open into spotlight bar or expanded UI
        XCTAssertFalse(model.isSpotlightBarActive, "Fast cursor sweep must NOT open spotlight pill")
        XCTAssertFalse(model.isExpanded, "Fast sweep must NOT open expanded UI")
        XCTAssertTrue(controller.panel.ignoresMouseEvents, "Panel must continue ignoring mouse events during sweep")
    }
}
