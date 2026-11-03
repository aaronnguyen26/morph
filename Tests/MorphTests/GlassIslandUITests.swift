import XCTest
import SwiftUI
@testable import morph

@MainActor
final class GlassIslandUITests: XCTestCase {
    var model: NotchModel!
    
    override func setUp() async throws {
        try await super.setUp()
        model = NotchModel()
    }
    
    override func tearDown() async throws {
        model.resetTransientStateOnCollapse()
        model = nil
        try await super.tearDown()
    }
    
    // MARK: - 1. Glass Island Exact Dimensions Specification
    func testGlassIslandDimensions() {
        XCTAssertEqual(model.compactStageWidth, 440.0, "Glass Island compact stage width must be exactly 440 pt")
        XCTAssertEqual(model.compactStageHeight, 142.0, "Glass Island compact stage height must be exactly 142 pt")
        XCTAssertEqual(model.idleWidth, 179.0, "Resting faint glass pill width must be 179 pt")
        XCTAssertEqual(model.idleHeight, 32.0, "Resting faint glass pill height must be 32 pt")
        XCTAssertEqual(model.spotlightBarWidth, 510.0, "Stretched hover prompt bar width must be 510 pt")
        XCTAssertEqual(model.spotlightBarHeight, 38.0, "Stretched hover prompt bar height must be 38 pt")
    }
    
    // MARK: - 2. Intermediary Stage Geometry Activation
    func testIntermediaryStageActiveGeometry() {
        // When resting
        XCTAssertFalse(model.isIntermediaryStageActive)
        XCTAssertEqual(model.currentWidth, 179.0)
        XCTAssertEqual(model.currentHeight, 32.0)
        
        // When Home intermediary stage is presented
        model.presentIntermediaryHome()
        XCTAssertTrue(model.isIntermediaryStageActive)
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.currentWidth, 440.0)
        XCTAssertEqual(model.currentHeight, 142.0)
        
        // Dismissing collapses back to resting stealth
        model.resetTransientStateOnCollapse()
        XCTAssertFalse(model.isIntermediaryStageActive)
        XCTAssertFalse(model.isExpanded)
        XCTAssertEqual(model.currentWidth, 179.0)
        XCTAssertEqual(model.currentHeight, 32.0)
    }
    
    // MARK: - 3. Focus Timer Stage & Transition to Live Activity Pill
    func testFocusTimerStageAndCommitToLiveActivity() {
        model.presentIntermediaryTimer(minutes: 25, title: "Deep Work")
        XCTAssertTrue(model.isIntermediaryStageActive)
        XCTAssertEqual(model.currentWidth, 440.0)
        XCTAssertEqual(model.currentHeight, 142.0)
        
        if case .timer(let mins, let title) = model.activeIntermediaryStage {
            XCTAssertEqual(mins, 25)
            XCTAssertEqual(title, "Deep Work")
        } else {
            XCTFail("Stage must be .timer")
        }
        
        // User clicks primary action: Start 25m Focus
        model.commitIntermediaryTimer()
        
        // Transitions from intermediary card to live activity background task pill (510x38pt)
        XCTAssertFalse(model.isExpanded, "Must collapse from expanded card to background live activity pill")
        XCTAssertNil(model.activeIntermediaryStage)
        XCTAssertEqual(model.islandState, .spotlightBar)
        XCTAssertEqual(model.currentWidth, 510.0)
        XCTAssertEqual(model.currentHeight, 38.0)
        
        if case .timer(let title, let mins) = model.activeBackgroundTaskPill {
            XCTAssertEqual(title, "Deep Work")
            XCTAssertEqual(mins, 25)
        } else {
            XCTFail("activeBackgroundTaskPill must be .timer")
        }
    }
    
    // MARK: - 4. Music Player Stage ("Glass Hours" / "Marlowe Vale") & Live Activity
    func testMusicPlayerStageAndCommitToLiveActivity() {
        model.presentIntermediaryMusic(action: .play(query: "Glass Hours"))
        XCTAssertTrue(model.isIntermediaryStageActive)
        XCTAssertEqual(model.currentWidth, 440.0)
        XCTAssertEqual(model.currentHeight, 142.0)
        
        if case .music(let query, let track, let artist, _) = model.activeIntermediaryStage {
            XCTAssertEqual(query, "Glass Hours")
            XCTAssertEqual(track, "Glass Hours")
            XCTAssertEqual(artist, "Marlowe Vale")
        } else {
            XCTFail("Stage must be .music")
        }
        
        // User starts music playback
        model.commitIntermediaryMusic(play: true)
        
        // Transitions to live activity background task pill
        XCTAssertFalse(model.isExpanded)
        XCTAssertNil(model.activeIntermediaryStage)
        XCTAssertEqual(model.islandState, .spotlightBar)
        XCTAssertEqual(model.currentWidth, 510.0)
        XCTAssertEqual(model.currentHeight, 38.0)
        
        if case .media(let track, let artist) = model.activeBackgroundTaskPill {
            XCTAssertEqual(track, "Glass Hours")
            XCTAssertEqual(artist, "Marlowe Vale")
        } else {
            XCTFail("activeBackgroundTaskPill must be .media")
        }
    }
    
    // MARK: - 5. Calendar Stage ("Monday 2" / "November 2026")
    func testCalendarStageAndCommit() {
        model.presentIntermediaryCalendar(action: .todaySummary)
        XCTAssertTrue(model.isIntermediaryStageActive)
        XCTAssertEqual(model.currentWidth, 440.0)
        XCTAssertEqual(model.currentHeight, 142.0)
        
        if case .calendar(let headline, let subtitle, _) = model.activeIntermediaryStage {
            XCTAssertEqual(headline, "Monday 2")
            XCTAssertTrue(subtitle.contains("November 2026"))
        } else {
            XCTFail("Stage must be .calendar")
        }
        
        // Joining call commits and transitions to live activity pill
        model.commitIntermediaryCalendarJoinCall()
        XCTAssertFalse(model.isExpanded)
        XCTAssertNil(model.activeIntermediaryStage)
        XCTAssertEqual(model.islandState, .spotlightBar)
    }
    
    // MARK: - 6. Notes Stage ("3 notes" / "buy oat milk")
    func testNotesStageAndPinToNotch() {
        model.presentIntermediaryNote(action: .add(text: "buy oat milk", pinToNotch: false))
        XCTAssertTrue(model.isIntermediaryStageActive)
        XCTAssertEqual(model.currentWidth, 440.0)
        XCTAssertEqual(model.currentHeight, 142.0)
        
        if case .notes(let preview) = model.activeIntermediaryStage {
            XCTAssertEqual(preview, "buy oat milk")
        } else {
            XCTFail("Stage must be .notes")
        }
        
        // Pin to Notch commits and transitions to live activity pill
        model.commitIntermediaryNotesPin()
        XCTAssertFalse(model.isExpanded)
        XCTAssertNil(model.activeIntermediaryStage)
        XCTAssertEqual(model.islandState, .spotlightBar)
        
        if case .note(let preview) = model.activeBackgroundTaskPill {
            XCTAssertEqual(preview, "buy oat milk")
        } else {
            XCTFail("activeBackgroundTaskPill must be .note")
        }
    }
    
    // MARK: - 7. Direct Answer / You Asked Stage
    func testDirectAnswerStageAndDone() {
        model.presentIntermediaryAnswer(
            query: "what is the date",
            headline: "Monday 2",
            subtitle: "November 2, 2026",
            icon: "calendar"
        )
        XCTAssertTrue(model.isIntermediaryStageActive)
        XCTAssertEqual(model.currentWidth, 440.0)
        XCTAssertEqual(model.currentHeight, 142.0)
        
        if case .answer(let q, let h, let s, _) = model.activeIntermediaryStage {
            XCTAssertEqual(q, "what is the date")
            XCTAssertEqual(h, "Monday 2")
            XCTAssertEqual(s, "November 2, 2026")
        } else {
            XCTFail("Stage must be .answer")
        }
        
        // Done button commits and transitions to background pill
        model.commitIntermediaryAnswerDone()
        XCTAssertFalse(model.isExpanded)
        XCTAssertNil(model.activeIntermediaryStage)
        XCTAssertEqual(model.islandState, .spotlightBar)
        
        if case .directAnswer(let text, let icon) = model.activeBackgroundTaskPill {
            XCTAssertEqual(text, "Monday 2")
            XCTAssertEqual(icon, "calendar")
        } else {
            XCTFail("activeBackgroundTaskPill must be .directAnswer")
        }
    }
}
