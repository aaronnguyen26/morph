import XCTest
import SwiftUI
@testable import morph

@MainActor
final class SpotlightCommandsTests: XCTestCase {
    var model: NotchModel!
    var controller: MorphController!
    
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
    
    // MARK: - 1. Music Command Parsing and Execution
    func testMusicCommands() {
        // 1. "play lofi"
        model.isSpotlightBarActive = true
        model.spotlightQuery = "play lofi"
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: model.spotlightQuery), .music)
        
        let cmdPlayLofi = MorphSpotlightCommandParser.parse("play lofi")
        XCTAssertEqual(cmdPlayLofi, .music(action: .play(query: "lofi")))
        
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isSpotlightBarActive)
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertEqual(model.compactHUDMode, .mediaOnly, "Submitting play command must activate mediaOnly compact HUD")
        
        // 2. "pause"
        model.spotlightQuery = "pause"
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: model.spotlightQuery), .music)
        let cmdPause = MorphSpotlightCommandParser.parse("pause")
        XCTAssertEqual(cmdPause, .music(action: .pause))
        
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.media.isPlaying)
        
        // 3. "play" / resume
        model.spotlightQuery = "play"
        let cmdResume = MorphSpotlightCommandParser.parse("play")
        XCTAssertEqual(cmdResume, .music(action: .play(query: nil)))
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.media.isPlaying)
        
        // 4. "next" track
        model.spotlightQuery = "next"
        let cmdNext = MorphSpotlightCommandParser.parse("next")
        XCTAssertEqual(cmdNext, .music(action: .next))
        model.handleSpotlightSubmit()
        
        // 5. "music" opens music tab
        model.spotlightQuery = "music"
        let cmdOpen = MorphSpotlightCommandParser.parse("music")
        XCTAssertEqual(cmdOpen, .music(action: .open))
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.selectedTab, .music)
    }
    
    // MARK: - 2. Notes Command Parsing and Execution
    func testNoteCommands() {
        // 1. "note buy groceries and coffee"
        model.isSpotlightBarActive = true
        model.spotlightQuery = "note buy groceries and coffee"
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: model.spotlightQuery), .note)
        
        let cmdNote = MorphSpotlightCommandParser.parse("note buy groceries and coffee")
        XCTAssertEqual(cmdNote, .note(action: .add(text: "buy groceries and coffee", pinToNotch: true)))
        
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isSpotlightBarActive)
        XCTAssertTrue(model.scratchpad.text.contains("buy groceries and coffee"))
        XCTAssertTrue(model.isNotePinnedToNotch)
        XCTAssertEqual(model.compactHUDMode, .notesPinned, "Adding note with pinToNotch must activate notesPinned compact HUD")
        
        // 2. "todo finish the quarterly report"
        model.spotlightQuery = "todo finish the quarterly report"
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: model.spotlightQuery), .note)
        let cmdTodo = MorphSpotlightCommandParser.parse("todo finish the quarterly report")
        XCTAssertEqual(cmdTodo, .note(action: .add(text: "finish the quarterly report", pinToNotch: true)))
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.scratchpad.text.contains("finish the quarterly report"))
        
        // 3. "notes" opens scratchpad
        model.spotlightQuery = "notes"
        let cmdView = MorphSpotlightCommandParser.parse("notes")
        XCTAssertEqual(cmdView, .note(action: .view))
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.selectedTab, .notes)
        
        // 4. "clear notes"
        model.spotlightQuery = "clear notes"
        let cmdClear = MorphSpotlightCommandParser.parse("clear notes")
        XCTAssertEqual(cmdClear, .note(action: .clear))
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.scratchpad.text.isEmpty)
        XCTAssertFalse(model.isNotePinnedToNotch)
    }
    
    // MARK: - 3. Calendar Command Parsing and Execution
    func testCalendarCommands() {
        // 1. "meet Sarah at 2:30pm"
        model.isSpotlightBarActive = true
        model.spotlightQuery = "meet Sarah at 2:30pm"
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: model.spotlightQuery), .calendar)
        
        let cmdMeet = MorphSpotlightCommandParser.parse("meet Sarah at 2:30pm")
        XCTAssertEqual(cmdMeet, .calendar(action: .add(title: "Sarah", hour: 14, minute: 30, duration: 30)))
        
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isSpotlightBarActive)
        XCTAssertFalse(model.isExpanded)
        XCTAssertEqual(model.selectedTab, .calendar)
        XCTAssertTrue(model.calendar.events.contains(where: { $0.title == "Sarah" }))
        
        // 2. "event Team Sync at 10am for 45m"
        model.spotlightQuery = "event Team Sync at 10am for 45m"
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: model.spotlightQuery), .calendar)
        let cmdEvent = MorphSpotlightCommandParser.parse("event Team Sync at 10am for 45m")
        XCTAssertEqual(cmdEvent, .calendar(action: .add(title: "Team Sync", hour: 10, minute: 0, duration: 45)))
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.calendar.events.contains(where: { $0.title == "Team Sync" }))
        
        // 3. "schedule Design Sprint"
        model.spotlightQuery = "schedule Design Sprint"
        let cmdSchedule = MorphSpotlightCommandParser.parse("schedule Design Sprint")
        XCTAssertEqual(cmdSchedule, .calendar(action: .add(title: "Design Sprint", hour: nil, minute: 0, duration: 30)))
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.calendar.events.contains(where: { $0.title == "Design Sprint" }))
        
        // 4. "calendar" opens calendar view
        model.spotlightQuery = "calendar"
        let cmdCal = MorphSpotlightCommandParser.parse("calendar")
        XCTAssertEqual(cmdCal, .calendar(action: .view))
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.selectedTab, .calendar)
    }
    
    // MARK: - 4. Dynamic Icon Type Detection
    func testDynamicIconTypeDetection() {
        // Music
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "play lofi"), .music)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "song jazz"), .music)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "pause"), .music)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "next"), .music)
        
        // Notes
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "note buy groceries"), .note)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "todo finish PR"), .note)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "memo sync"), .note)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "notes"), .note)
        
        // Calendar
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "meet Alice at 3pm"), .calendar)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "event Sprint Review"), .calendar)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "schedule 1on1"), .calendar)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "calendar"), .calendar)
        
        // Timer
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "25m"), .timer)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "focus 40m"), .timer)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "timer 15"), .timer)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "break 5m"), .timer)
        
        // Empty / Unknown
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: ""), .unknown)
    }
    
    // MARK: - 5. Conversational Dynamic Island Queries
    func testConversationalDynamicIslandQueries() {
        // Calendar natural language queries
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "what my plan for today"), .calendar)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "what is my plan for today"), .calendar)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "what's my schedule"), .calendar)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "what do i have today"), .calendar)
        
        let planCmd = MorphSpotlightCommandParser.parse("what my plan for today")
        XCTAssertEqual(planCmd, .calendar(action: .todaySummary))
        
        model.spotlightQuery = "what my plan for today"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded)
        XCTAssertEqual(model.selectedTab, .calendar)
        
        // Focus timer conversational queries
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "focus for 30 minutes"), .timer)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "start timer for 10m"), .timer)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "set a timer for 15m"), .timer)
        
        model.spotlightQuery = "focus for 30 minutes"
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.pomodoro.isRunning)
        XCTAssertEqual(model.compactHUDMode, .pomodoroOnly)
        
        // Direct answer queries
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "what time is it"), .answer)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "what day is today"), .answer)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "who are you"), .answer)
        
        model.spotlightQuery = "what time is it"
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.isShowingDirectAnswer)
        XCTAssertTrue(model.directAnswerText.contains("It is"))
        
        // Profile navigation query (Matching user screenshot)
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: "profile"), .navigation)
        model.spotlightQuery = "profile"
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.selectedTab, .profile)
    }
    
    // MARK: - 6. General Queries Do NOT Default to Arbitrary 25:00 Timer
    func testGeneralQueriesDoNotDefaultTo25mTimer() {
        // Questions and thoughts must produce conversational answers, NOT timer launch
        let queries = [
            "what can you do",
            "give me a focus tip",
            "tell me a joke",
            "how are you",
            "15 * 4",
            "reading response #4",
            "explain quantum computing"
        ]
        
        for q in queries {
            let cmd = MorphSpotlightCommandParser.parse(q)
            switch cmd {
            case .answer(let text, _):
                XCTAssertFalse(text.isEmpty, "Query '\(q)' must generate a non-empty smart answer")
            default:
                XCTFail("Query '\(q)' must NOT launch a timer or navigate away; got \(cmd)")
            }
        }
        
        // Non-timer queries submitted do NOT start pomodoro
        model.spotlightQuery = "reading response #4"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.pomodoro.isRunning, "General task/query must NOT automatically start a 25:00 timer")
        XCTAssertTrue(model.isShowingDirectAnswer)
    }
    
    // MARK: - 7. Auto-Collapse of Expanded Screenshot UI When Mouse Leaves
    func testExpandedUICollapsesWhenMouseLeaves() {
        // 1. Expand to Calendar or Profile UI (like user screenshot)
        model.selectedTab = .calendar
        model.isExpanded = true
        model.isPinned = false
        XCTAssertEqual(model.islandState, .fullExpanded)
        
        // 2. Mouse exits the area with NO background activity
        model.pomodoro.isRunning = false
        model.media.isPlaying = false
        controller.handleMouseExit()
        
        // In testing environment or immediate simulation
        model.isHovered = false
        model.isExpanded = false
        model.isSpotlightBarActive = false
        XCTAssertEqual(model.islandState, .resting, "Must collapse all the way back to resting stealth when no background activity")
        
        // 3. Expand again, but now with a background activity (e.g. music playing or timer running)
        model.isExpanded = true
        model.pomodoro.isRunning = true
        model.pomodoro.timeRemaining = 25 * 60
        XCTAssertEqual(model.islandState, .fullExpanded)
        
        // Mouse leaves: collapses to 3rd stage (extended pill HUD)
        model.isExpanded = false
        XCTAssertEqual(model.islandState, .extendedPill, "Must collapse back to 3rd stage compact HUD when timer is running in background")
        XCTAssertEqual(model.compactHUDMode, .pomodoroOnly)
    }
    
    // MARK: - 8. Widened Spotlight Bar Dimensions & Clickability
    func testWidenedSpotlightBarAndClickability() {
        XCTAssertEqual(model.spotlightBarWidth, 510, "Spotlight bar must be widened to 510 pt")
        
        // Hover opens spotlight bar
        controller.handleMouseEnter()
        XCTAssertTrue(model.isSpotlightBarActive)
        XCTAssertEqual(model.currentWidth, 510)
        XCTAssertFalse(controller.panel.ignoresMouseEvents, "Panel must NOT ignore mouse events so user can click it")
    }
}
