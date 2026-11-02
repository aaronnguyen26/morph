import XCTest
import SwiftUI
@testable import morph

@MainActor
final class ContextEngineUITests: XCTestCase {
    
    // MARK: - 1. DropShelfView Tests
    
    func testDropShelfViewHierarchyAndCompactWings() {
        let model = NotchModel()
        let tempURL = URL(fileURLWithPath: "/tmp/morph_demo.pdf")
        model.dropShelf.stageFile(url: tempURL)
        
        let view = DropShelfView(model: model)
        XCTAssertNotNil(view.body)
        
        let leftWing = CompactDropShelfWingLeft(shelf: model.dropShelf, model: model)
        XCTAssertNotNil(leftWing.body)
        
        let rightWing = CompactDropShelfWingRight(shelf: model.dropShelf, model: model)
        XCTAssertNotNil(rightWing.body)
        
        // Staged card
        if let first = model.dropShelf.stagedItems.first {
            let cardView = DropShelfCardView(item: first, shelf: model.dropShelf)
            XCTAssertNotNil(cardView.body)
        }
    }
    
    // MARK: - 2. MeetingFlightControllerView Tests
    
    func testMeetingFlightControllerViewHierarchyAndCompactWings() {
        let model = NotchModel()
        let now = Date()
        let event = CalendarEvent(
            id: "meet-ui-1",
            title: "Executive Design Review",
            startTime: now.addingTimeInterval(180),
            endTime: now.addingTimeInterval(1980),
            meetLink: "https://meet.google.com/xyz-uvw-rst"
        )
        model.meetingController.updateFromCalendar(events: [event], now: now)
        
        let preMeetingView = MeetingFlightControllerView(model: model)
        XCTAssertNotNil(preMeetingView.body)
        
        // Switch to in-call
        model.meetingController.startCall(title: "Active Call")
        XCTAssertTrue(model.meetingController.isInCall)
        
        let inCallView = MeetingFlightControllerView(model: model)
        XCTAssertNotNil(inCallView.body)
        
        let leftWing = CompactMeetingWingLeft(controller: model.meetingController, model: model)
        XCTAssertNotNil(leftWing.body)
        
        let rightWing = CompactMeetingWingRight(controller: model.meetingController, model: model)
        XCTAssertNotNil(rightWing.body)
    }
    
    // MARK: - 3. MorphIslandView Full Integration Tests
    
    func testMorphIslandViewContextualFeatureRouting() {
        let model = NotchModel()
        let islandView = MorphIslandView(model: model, onMouseEnter: {}, onMouseExit: {})
        XCTAssertNotNil(islandView.body)
        
        // Open contextual feature: Drop Shelf
        model.openContextualFeature(.dropShelf)
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.activeContextFeature, .dropShelf)
        
        // Close contextual feature
        model.closeContextualFeature()
        XCTAssertNil(model.activeContextFeature)
        
        // Open contextual feature: Meeting Flight
        model.openContextualFeature(.meetingFlight)
        XCTAssertEqual(model.activeContextFeature, .meetingFlight)
        
        // Returning to home clears activeContextFeature
        model.returnToHome()
        XCTAssertNil(model.activeContextFeature)
        XCTAssertEqual(model.selectedTab, .home)
    }
    
    func testHoverAndExpandSyncsWithCollapsedFeature() {
        let model = NotchModel()
        
        // 1. Initially idle: Expand stays on current tab (.home)
        model.selectedTab = .home
        model.syncExpandedFeatureWithActiveContext()
        XCTAssertEqual(model.selectedTab, .home)
        XCTAssertNil(model.activeContextFeature)
        
        // 2. Focus Timer running in collapsed HUD -> Hover/expand opens Focus feature
        model.pomodoro.start()
        XCTAssertEqual(model.compactHUDMode, .pomodoroOnly)
        model.syncExpandedFeatureWithActiveContext()
        XCTAssertEqual(model.selectedTab, .timer)
        XCTAssertNil(model.activeContextFeature)
        
        // 3. Media playing only -> Hover/expand opens Music feature
        model.pomodoro.pause()
        model.media.isPlaying = true
        XCTAssertEqual(model.compactHUDMode, .mediaOnly)
        model.syncExpandedFeatureWithActiveContext()
        XCTAssertEqual(model.selectedTab, .music)
        XCTAssertNil(model.activeContextFeature)
        
        // 4. Notes pinned to notch -> Hover/expand opens Notes feature
        model.media.isPlaying = false
        model.isNotePinnedToNotch = true
        XCTAssertEqual(model.compactHUDMode, .notesPinned)
        model.syncExpandedFeatureWithActiveContext()
        XCTAssertEqual(model.selectedTab, .notes)
        XCTAssertNil(model.activeContextFeature)
        model.isNotePinnedToNotch = false
        
        // 5. Calendar alert active -> Hover/expand opens Calendar feature
        model.calendar.showNotchAlert = true
        XCTAssertEqual(model.compactHUDMode, .calendarAlert)
        model.syncExpandedFeatureWithActiveContext()
        XCTAssertEqual(model.selectedTab, .calendar)
        XCTAssertNil(model.activeContextFeature)
        model.calendar.showNotchAlert = false
        
        // 6. Meeting in call or pre-meeting window -> Hover/expand opens Meeting Cockpit
        model.meetingController.startCall(title: "Design Sync")
        XCTAssertEqual(model.compactHUDMode, .meetingFlight)
        model.syncExpandedFeatureWithActiveContext()
        XCTAssertEqual(model.activeContextFeature, .meetingFlight)
        model.meetingController.endCall()
        model.closeContextualFeature()
        
        // 7. Drop shelf with staged files -> Hover/expand opens Drop Shelf
        _ = model.dropShelf.stageFile(url: URL(fileURLWithPath: "/tmp/sample_drop.pdf"))
        XCTAssertEqual(model.compactHUDMode, .dropShelfActive)
        model.syncExpandedFeatureWithActiveContext()
        XCTAssertEqual(model.activeContextFeature, .dropShelf)
        model.dropShelf.clearAll()
        model.closeContextualFeature()
    }
}
