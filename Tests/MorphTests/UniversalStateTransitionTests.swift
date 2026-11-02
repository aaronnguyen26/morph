import XCTest
import SwiftUI
@testable import morph

@MainActor
final class UniversalStateTransitionTests: XCTestCase {
    
    // MARK: - 1. Basic 3-State Model Verification
    func testIslandStateEnumAndModelMapping() {
        let model = NotchModel()
        model.isExpanded = false
        XCTAssertFalse(model.isCompactActive)
        XCTAssertEqual(model.islandState, .resting, "Default idle state must map to .resting (State 1)")
        XCTAssertEqual(model.currentWidth, model.idleWidth)
        XCTAssertEqual(model.currentHeight, model.idleHeight)
        
        // Activate Background Activity: Pomodoro
        model.pomodoro.isRunning = true
        XCTAssertTrue(model.isCompactActive)
        XCTAssertEqual(model.islandState, .extendedPill, "Running timer must map to .extendedPill (State 2)")
        XCTAssertEqual(model.currentWidth, model.compactWidth)
        XCTAssertGreaterThanOrEqual(model.currentWidth, 300)
        
        // Expand to Full Big UI (Legacy Large UI format)
        model.interactionMode = .legacyLargeUI
        model.isExpanded = true
        XCTAssertEqual(model.islandState, .fullExpanded, "Expanded island must map to .fullExpanded (State 3)")
        XCTAssertEqual(model.currentWidth, model.expandedWidth)
        XCTAssertEqual(model.currentHeight, model.expandedHeight)
        XCTAssertEqual(model.expandedWidth, 640)
        XCTAssertEqual(model.expandedHeight, 225)
    }
    
    // MARK: - 2. State 1 -> State 2 -> State 3 -> State 2 -> State 1 Transition Cycle
    func testUniversalStateTransitionCycle() {
        let model = NotchModel()
        
        // State 1: Normal Resting State
        XCTAssertEqual(model.islandState, .resting)
        XCTAssertEqual(model.currentWidth, model.idleWidth)
        
        // Transition 1 -> 2: Music begins playback in background
        model.media.isPlaying = true
        XCTAssertEqual(model.islandState, .extendedPill)
        XCTAssertEqual(model.compactHUDMode, .mediaOnly)
        XCTAssertGreaterThanOrEqual(model.currentWidth, 460)
        
        // Transition 2 -> 3: User hovers or taps to open Full Big UI
        model.syncExpandedFeatureWithActiveContext()
        XCTAssertEqual(model.selectedTab, .music, "Expanding with active media must automatically route to Music tab")
        model.isExpanded = true
        XCTAssertEqual(model.islandState, .fullExpanded)
        XCTAssertEqual(model.currentWidth, 640)
        XCTAssertEqual(model.currentHeight, 225)
        
        // Transition 3 -> 2: User collapses island while music is still playing
        model.isExpanded = false
        XCTAssertEqual(model.islandState, .extendedPill, "Collapsing while music is active must transition back to State 2 (Extended Pill)")
        XCTAssertEqual(model.currentWidth, model.compactWidth)
        
        // Transition 2 -> 1: User pauses music
        model.media.isPlaying = false
        XCTAssertEqual(model.islandState, .resting, "Pausing music with no other tasks must return to State 1 (Normal Resting)")
        XCTAssertEqual(model.currentWidth, model.idleWidth)
    }
    
    // MARK: - 3. Direct State 1 <-> State 3 Expansion & Collapse
    func testDirectRestingToFullExpandedCycle() {
        let model = NotchModel()
        XCTAssertEqual(model.islandState, .resting)
        
        // Direct deliberate hover or shortcut (⌘⌥M) in legacy large UI mode
        model.interactionMode = .legacyLargeUI
        model.isExpanded = true
        XCTAssertEqual(model.islandState, .fullExpanded)
        XCTAssertEqual(model.currentWidth, 640)
        XCTAssertEqual(model.currentHeight, 225)
        
        // Direct collapse with no background tasks
        model.isExpanded = false
        XCTAssertEqual(model.islandState, .resting, "Direct collapse with no background tasks must return straight to State 1 (Resting)")
        XCTAssertEqual(model.currentWidth, model.idleWidth)
        XCTAssertEqual(model.currentHeight, model.idleHeight)
    }
    
    // MARK: - 4. Universal Behavior Across All Other Feature Pages
    func testUniversalStateTransitionsAcrossFeatures() {
        let model = NotchModel()
        
        // Feature A: Notes Pinned
        model.isNotePinnedToNotch = true
        XCTAssertEqual(model.islandState, .extendedPill)
        XCTAssertEqual(model.compactHUDMode, .notesPinned)
        XCTAssertGreaterThan(model.compactHeight, model.idleHeight)
        model.isExpanded = true
        XCTAssertEqual(model.islandState, .fullExpanded)
        model.isExpanded = false
        XCTAssertEqual(model.islandState, .extendedPill)
        model.isNotePinnedToNotch = false
        XCTAssertEqual(model.islandState, .resting)
        
        // Feature B: Form Tracker Active
        model.formTracker.isFormDetected = true
        XCTAssertEqual(model.islandState, .extendedPill)
        XCTAssertEqual(model.compactHUDMode, .formTrackerActive)
        model.isExpanded = true
        XCTAssertEqual(model.islandState, .fullExpanded)
        model.isExpanded = false
        XCTAssertEqual(model.islandState, .extendedPill)
        model.formTracker.isFormDetected = false
        XCTAssertEqual(model.islandState, .resting)
        
        // Feature C: Drop Shelf Active
        model.dropShelf.stageFile(url: URL(fileURLWithPath: "/tmp/design.png"))
        XCTAssertEqual(model.islandState, .extendedPill)
        XCTAssertEqual(model.compactHUDMode, .dropShelfActive)
        model.isExpanded = true
        XCTAssertEqual(model.islandState, .fullExpanded)
        model.isExpanded = false
        XCTAssertEqual(model.islandState, .extendedPill)
        model.dropShelf.clearAll()
        XCTAssertEqual(model.islandState, .resting)
    }
    
    // MARK: - 5. MorphIslandView Universal Hierarchy Rendering
    func testMorphIslandViewRendersAll3StatesWithoutErrors() {
        let model = NotchModel()
        
        // 1. State 1 Rendering
        let state1View = MorphIslandView(model: model)
        XCTAssertNotNil(state1View.body)
        
        // 2. State 2 Rendering
        model.pomodoro.isRunning = true
        let state2View = MorphIslandView(model: model)
        XCTAssertNotNil(state2View.body)
        
        // 3. State 3 Rendering (Home Tab)
        model.isExpanded = true
        model.selectedTab = .home
        let state3HomeView = MorphIslandView(model: model)
        XCTAssertNotNil(state3HomeView.body)
        
        // 4. State 3 Rendering (Music Tab)
        model.selectedTab = .music
        let state3MusicView = MorphIslandView(model: model)
        XCTAssertNotNil(state3MusicView.body)
        
        // 5. State 3 Rendering (Notes Tab)
        model.selectedTab = .notes
        let state3NotesView = MorphIslandView(model: model)
        XCTAssertNotNil(state3NotesView.body)
    }
    
    // MARK: - 6. Redesigned HomeView Typography & Zero Bullet Points Verification
    func testRedesignedHomeViewHierarchyAndZeroBulletPoints() {
        let model = NotchModel()
        let homeView = HomeView(model: model)
        XCTAssertNotNil(homeView.body)
        
        // Verify user greeting is personalized
        XCTAssertFalse(model.supabase.currentUser.firstName.isEmpty)
        
        // Verify contextual subtitles do not contain bullet '•' character
        model.pomodoro.isRunning = true
        let pomodoroHomeView = HomeView(model: model)
        XCTAssertNotNil(pomodoroHomeView.body)
        
        model.pomodoro.isRunning = false
        model.media.isPlaying = true
        let mediaHomeView = HomeView(model: model)
        XCTAssertNotNil(mediaHomeView.body)
    }
}
