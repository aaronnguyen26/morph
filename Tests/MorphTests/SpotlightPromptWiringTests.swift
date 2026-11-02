import XCTest
import SwiftUI
@testable import morph

@MainActor
final class SpotlightPromptWiringTests: XCTestCase {
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
    
    // MARK: - 1. Music Player Wiring (Semantic Understanding without hardcoded 'music' keyword)
    func testMusicSemanticPromptUnderstandingAndWiring() {
        let musicQueries = [
            "can you play some relaxing lofi beats while i study",
            "put on taylor swift 1989",
            "i want to listen to chopin",
            "stream synthwave",
            "shuffle study playlist",
            "pause",
            "resume",
            "skip track"
        ]
        
        for q in musicQueries {
            let detected = MorphSpotlightCommandParser.detectType(from: q)
            XCTAssertEqual(detected, .music, "Query '\(q)' must be detected as .music intent")
            XCTAssertEqual(detected.iconName, "music.note", "Query '\(q)' must have dynamic icon music.note")
        }
        
        // A. Conversational playback prompt
        let query1 = "can you play some relaxing lofi beats while i study"
        let cmd1 = MorphSpotlightCommandParser.parse(query1)
        XCTAssertEqual(cmd1, .music(action: .play(query: "relaxing lofi beats")))
        model.spotlightQuery = query1
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isSpotlightBarActive)
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertEqual(model.selectedTab, .music, "Must wire directly to Music Player")
        XCTAssertEqual(model.compactHUDMode, .mediaOnly)
        
        // B. 'put on' artist prompt without word 'music'
        let query2 = "put on taylor swift 1989"
        let cmd2 = MorphSpotlightCommandParser.parse(query2)
        XCTAssertEqual(cmd2, .music(action: .play(query: "taylor swift 1989")))
        model.spotlightQuery = query2
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertEqual(model.selectedTab, .music)
        
        // C. 'i want to listen to' prompt without word 'music'
        let query3 = "i want to listen to chopin"
        let cmd3 = MorphSpotlightCommandParser.parse(query3)
        XCTAssertEqual(cmd3, .music(action: .play(query: "chopin")))
        model.spotlightQuery = query3
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertEqual(model.selectedTab, .music)
        
        // D. 'stream' prompt
        let query4 = "stream synthwave"
        let cmd4 = MorphSpotlightCommandParser.parse(query4)
        XCTAssertEqual(cmd4, .music(action: .play(query: "synthwave")))
        model.spotlightQuery = query4
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertEqual(model.selectedTab, .music)
        
        // E. 'shuffle' playlist prompt
        let query5 = "shuffle study playlist"
        let cmd5 = MorphSpotlightCommandParser.parse(query5)
        XCTAssertEqual(cmd5, .music(action: .play(query: "study playlist")))
        model.spotlightQuery = query5
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertEqual(model.selectedTab, .music)
        
        // F. Playback controls without 'music'
        model.spotlightQuery = "pause"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.media.isPlaying)
        XCTAssertEqual(model.selectedTab, .music)
        
        model.spotlightQuery = "resume"
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertEqual(model.selectedTab, .music)
        
        model.spotlightQuery = "skip track"
        model.handleSpotlightSubmit()
        XCTAssertEqual(model.selectedTab, .music)
    }
    
    // MARK: - 2. Focus Timer Wiring (Natural Language understanding & auto-start)
    func testFocusTimerPromptUnderstandingAndWiring() {
        let timerQueries = [
            "lock in for 45 minutes on cs project",
            "give me a 10 minute break",
            "set a timer for 1 hour to study",
            "start timer for 15m",
            "focus timer",
            "25m"
        ]
        
        for q in timerQueries {
            let detected = MorphSpotlightCommandParser.detectType(from: q)
            XCTAssertEqual(detected, .timer, "Query '\(q)' must be detected as .timer intent")
            XCTAssertEqual(detected.iconName, "timer", "Query '\(q)' must have dynamic icon timer")
        }
        
        // A. 'lock in for 45 minutes on cs project'
        let query1 = "lock in for 45 minutes on cs project"
        let cmd1 = MorphSpotlightCommandParser.parse(query1)
        switch cmd1 {
        case .timer(let minutes, let title, let autoStart):
            XCTAssertEqual(minutes, 45)
            XCTAssertTrue(autoStart)
            XCTAssertTrue(title.contains("Cs Project") || title.contains("Deep Work") || title.contains("45m"))
        default:
            XCTFail("Must parse as timer")
        }
        
        model.spotlightQuery = query1
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isSpotlightBarActive)
        XCTAssertTrue(model.pomodoro.isRunning, "Must wire and start pomodoro focus timer")
        XCTAssertTrue(model.isPomodoroSessionActive)
        XCTAssertEqual(model.compactHUDMode, .pomodoroOnly)
        
        // B. 'give me a 10 minute break'
        let query2 = "give me a 10 minute break"
        let cmd2 = MorphSpotlightCommandParser.parse(query2)
        switch cmd2 {
        case .timer(let minutes, let title, let autoStart):
            XCTAssertEqual(minutes, 10)
            XCTAssertEqual(title, "Break")
            XCTAssertTrue(autoStart)
        default:
            XCTFail("Must parse as timer")
        }
        model.spotlightQuery = query2
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.pomodoro.isRunning)
        XCTAssertEqual(model.requestedTimerMinutes, 10)
        XCTAssertEqual(model.compactHUDMode, .pomodoroOnly)
        
        // C. 'set a timer for 1 hour to study'
        let query3 = "set a timer for 1 hour to study"
        let cmd3 = MorphSpotlightCommandParser.parse(query3)
        switch cmd3 {
        case .timer(let minutes, _, let autoStart):
            XCTAssertEqual(minutes, 60, "1 hour should convert to 60 minutes")
            XCTAssertTrue(autoStart)
        default:
            XCTFail("Must parse as timer")
        }
        model.spotlightQuery = query3
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.pomodoro.isRunning)
        XCTAssertEqual(model.requestedTimerMinutes, 60)
        XCTAssertEqual(model.compactHUDMode, .pomodoroOnly)
        
        // D. 'start timer for 15m'
        let query4 = "start timer for 15m"
        let cmd4 = MorphSpotlightCommandParser.parse(query4)
        switch cmd4 {
        case .timer(let minutes, _, let autoStart):
            XCTAssertEqual(minutes, 15)
            XCTAssertTrue(autoStart)
        default:
            XCTFail("Must parse as timer")
        }
        model.spotlightQuery = query4
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.pomodoro.isRunning)
        XCTAssertEqual(model.requestedTimerMinutes, 15)
        XCTAssertEqual(model.compactHUDMode, .pomodoroOnly)
        
        // E. '25m'
        let query5 = "25m"
        let cmd5 = MorphSpotlightCommandParser.parse(query5)
        switch cmd5 {
        case .timer(let minutes, _, let autoStart):
            XCTAssertEqual(minutes, 25)
            XCTAssertTrue(autoStart)
        default:
            XCTFail("Must parse as timer")
        }
        model.spotlightQuery = query5
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.pomodoro.isRunning)
        XCTAssertEqual(model.requestedTimerMinutes, 25)
        XCTAssertEqual(model.compactHUDMode, .pomodoroOnly)
        
        // F. Navigation prompt
        let query6 = "focus timer"
        let cmd6 = MorphSpotlightCommandParser.parse(query6)
        XCTAssertEqual(cmd6, .navigation(tab: .timer))
        model.spotlightQuery = query6
        model.handleSpotlightSubmit()
        XCTAssertEqual(model.selectedTab, .timer)
    }
    
    // MARK: - 3. Calendar Wiring (Natural Language inquiries & event scheduling)
    func testCalendarPromptUnderstandingAndWiring() {
        let calendarQueries = [
            "what's my schedule tomorrow",
            "what do i have today",
            "check my calendar",
            "coffee with Sarah at 10am for 45m",
            "dentist appointment at 2:30pm",
            "sync with design team at 4pm for 1 hour"
        ]
        
        for q in calendarQueries {
            let detected = MorphSpotlightCommandParser.detectType(from: q)
            XCTAssertEqual(detected, .calendar, "Query '\(q)' must be detected as .calendar intent")
            XCTAssertEqual(detected.iconName, "calendar", "Query '\(q)' must have dynamic icon calendar")
        }
        
        // A. Natural schedule inquiries
        let inquiries = [
            "what's my schedule tomorrow",
            "what do i have today",
            "check my calendar"
        ]
        for inquiry in inquiries {
            XCTAssertEqual(MorphSpotlightCommandParser.parse(inquiry), .calendar(action: .view))
            model.spotlightQuery = inquiry
            model.handleSpotlightSubmit()
            XCTAssertFalse(model.isSpotlightBarActive)
            XCTAssertTrue(model.isExpanded)
            XCTAssertEqual(model.selectedTab, .calendar, "Must wire directly to Calendar tab")
        }
        
        // B. 'coffee with Sarah at 10am for 45m'
        let eventQuery1 = "coffee with Sarah at 10am for 45m"
        let cmdEvent1 = MorphSpotlightCommandParser.parse(eventQuery1)
        switch cmdEvent1 {
        case .calendar(action: .add(let title, let hour, let minute, let duration)):
            XCTAssertTrue(title.contains("Sarah") || title.contains("Coffee"))
            XCTAssertEqual(hour, 10)
            XCTAssertEqual(minute, 0)
            XCTAssertEqual(duration, 45)
        default:
            XCTFail("Must parse as calendar event add")
        }
        model.spotlightQuery = eventQuery1
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.calendar.events.contains(where: { $0.title.contains("Sarah") }))
        XCTAssertEqual(model.selectedTab, .calendar)
        
        // C. 'dentist appointment at 2:30pm'
        let eventQuery2 = "dentist appointment at 2:30pm"
        let cmdEvent2 = MorphSpotlightCommandParser.parse(eventQuery2)
        switch cmdEvent2 {
        case .calendar(action: .add(let title, let hour, let minute, let duration)):
            XCTAssertTrue(title.contains("Dentist"))
            XCTAssertEqual(hour, 14)
            XCTAssertEqual(minute, 30)
            XCTAssertEqual(duration, 30)
        default:
            XCTFail("Must parse as calendar event add")
        }
        model.spotlightQuery = eventQuery2
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.calendar.events.contains(where: { $0.title.contains("Dentist") }))
        XCTAssertEqual(model.selectedTab, .calendar)
        
        // D. 'sync with design team at 4pm for 1 hour'
        let eventQuery3 = "sync with design team at 4pm for 1 hour"
        let cmdEvent3 = MorphSpotlightCommandParser.parse(eventQuery3)
        switch cmdEvent3 {
        case .calendar(action: .add(let title, let hour, let minute, let duration)):
            XCTAssertTrue(title.contains("Sync") || title.contains("Design"))
            XCTAssertEqual(hour, 16)
            XCTAssertEqual(minute, 0)
            XCTAssertEqual(duration, 60)
        default:
            XCTFail("Must parse as calendar event add")
        }
        model.spotlightQuery = eventQuery3
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.calendar.events.contains(where: { $0.title.contains("Sync") || $0.title.contains("Design") }))
        XCTAssertEqual(model.selectedTab, .calendar)
    }
    
    // MARK: - 4. Note (Scratchpad) Wiring (Natural Language capture & management)
    func testNotePromptUnderstandingAndWiring() {
        let noteQueries = [
            "remember to pick up dry cleaning",
            "don't forget to submit the timesheet",
            "save this to notes: API keys rotation",
            "scratchpad: buy groceries",
            "open notes",
            "clear notes"
        ]
        
        for q in noteQueries {
            let detected = MorphSpotlightCommandParser.detectType(from: q)
            XCTAssertEqual(detected, .note, "Query '\(q)' must be detected as .note intent")
            XCTAssertEqual(detected.iconName, "note.text", "Query '\(q)' must have dynamic icon note.text")
        }
        
        // A. 'remember to pick up dry cleaning'
        let noteQuery1 = "remember to pick up dry cleaning"
        let cmd1 = MorphSpotlightCommandParser.parse(noteQuery1)
        XCTAssertEqual(cmd1, .note(action: .add(text: "pick up dry cleaning", pinToNotch: true)))
        model.spotlightQuery = noteQuery1
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isSpotlightBarActive)
        XCTAssertTrue(model.scratchpad.text.contains("pick up dry cleaning"), "Must append note to scratchpad")
        XCTAssertTrue(model.isNotePinnedToNotch)
        XCTAssertEqual(model.selectedTab, .notes, "Must wire directly to Notes tab")
        
        // B. 'don't forget to submit the timesheet'
        let noteQuery2 = "don't forget to submit the timesheet"
        let cmd2 = MorphSpotlightCommandParser.parse(noteQuery2)
        XCTAssertEqual(cmd2, .note(action: .add(text: "submit the timesheet", pinToNotch: true)))
        model.spotlightQuery = noteQuery2
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.scratchpad.text.contains("submit the timesheet"))
        XCTAssertEqual(model.selectedTab, .notes)
        
        // C. 'save this to notes: API keys rotation'
        let noteQuery3 = "save this to notes: API keys rotation"
        let cmd3 = MorphSpotlightCommandParser.parse(noteQuery3)
        XCTAssertEqual(cmd3, .note(action: .add(text: "API keys rotation", pinToNotch: true)))
        model.spotlightQuery = noteQuery3
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.scratchpad.text.contains("API keys rotation"))
        XCTAssertEqual(model.selectedTab, .notes)
        
        // D. 'scratchpad: buy groceries'
        let noteQuery4 = "scratchpad: buy groceries"
        let cmd4 = MorphSpotlightCommandParser.parse(noteQuery4)
        XCTAssertEqual(cmd4, .note(action: .add(text: "buy groceries", pinToNotch: true)))
        model.spotlightQuery = noteQuery4
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.scratchpad.text.contains("buy groceries"))
        XCTAssertEqual(model.selectedTab, .notes)
        
        // E. 'open notes'
        let noteQuery5 = "open notes"
        let cmd5 = MorphSpotlightCommandParser.parse(noteQuery5)
        XCTAssertEqual(cmd5, .note(action: .view))
        model.spotlightQuery = noteQuery5
        model.handleSpotlightSubmit()
        XCTAssertEqual(model.selectedTab, .notes)
        
        // F. 'clear notes'
        let noteQuery6 = "clear notes"
        let cmd6 = MorphSpotlightCommandParser.parse(noteQuery6)
        XCTAssertEqual(cmd6, .note(action: .clear))
        model.spotlightQuery = noteQuery6
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.scratchpad.text.isEmpty, "Scratchpad should be cleared")
        XCTAssertFalse(model.isNotePinnedToNotch)
        XCTAssertEqual(model.selectedTab, .notes)
    }
    
    // MARK: - 5. User Order Verification: Specific Action Skips Larger UI, General Opens Larger UI to Pick
    func testOrderSpecificActionSkipsLargerUIAndGeneralOpensLargerUI() {
        // --- A. Focus Timer ---
        // 1. Specific action: "put timer for 25 minute" -> MUST SKIP LARGER UI & give result directly in compact pill HUD
        let specificTimerQuery = "put timer for 25 minute"
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: specificTimerQuery), .timer)
        let parsedSpecificTimer = MorphSpotlightCommandParser.parse(specificTimerQuery)
        switch parsedSpecificTimer {
        case .timer(let minutes, let title, let autoStart):
            XCTAssertEqual(minutes, 25)
            XCTAssertTrue(autoStart)
            XCTAssertTrue(title == "Focus Session" || title == "25m Focus")
        default:
            XCTFail("Must parse as specific timer, got: \(parsedSpecificTimer)")
        }
        
        model.spotlightQuery = specificTimerQuery
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded, "Specific timer command MUST skip the larger UI!")
        XCTAssertTrue(model.pomodoro.isRunning, "Direct timer must start countdown immediately")
        XCTAssertEqual(model.compactHUDMode, .pomodoroOnly, "Direct timer must show extended pill HUD")
        
        // Reset state
        model.stopFocusTimer()
        model.isExpanded = false
        
        // 2. General request: "timer" -> MUST OPEN LARGER UI to Focus Timer page so user can pick
        let generalTimerQuery = "timer"
        XCTAssertEqual(MorphSpotlightCommandParser.detectType(from: generalTimerQuery), .timer)
        XCTAssertEqual(MorphSpotlightCommandParser.parse(generalTimerQuery), .navigation(tab: .timer))
        
        model.spotlightQuery = generalTimerQuery
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.isExpanded, "General 'timer' request MUST open the larger UI so user can pick options!")
        XCTAssertEqual(model.selectedTab, .timer, "Must open directly to Focus tab")
        
        // Reset state
        model.isExpanded = false
        
        // 3. General request: "focus" -> MUST OPEN LARGER UI
        let generalFocusQuery = "focus"
        XCTAssertEqual(MorphSpotlightCommandParser.parse(generalFocusQuery), .navigation(tab: .timer))
        model.spotlightQuery = generalFocusQuery
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.isExpanded, "General 'focus' request MUST open larger UI to pick duration")
        XCTAssertEqual(model.selectedTab, .timer)
        
        // Reset state
        model.isExpanded = false
        
        // --- B. Music Player ---
        // 1. Specific action: "play lofi" -> MUST SKIP LARGER UI & play directly
        let specificMusicQuery = "play lofi"
        model.spotlightQuery = specificMusicQuery
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded, "Direct 'play' command MUST skip larger UI!")
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertEqual(model.compactHUDMode, .mediaOnly, "Must show in compact media HUD")
        
        // Specific control: "pause" -> MUST SKIP LARGER UI
        model.spotlightQuery = "pause"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded, "Direct 'pause' command MUST skip larger UI!")
        XCTAssertFalse(model.media.isPlaying)
        
        // 2. General request: "music" -> MUST OPEN LARGER UI to Music page so user can pick
        let generalMusicQuery = "music"
        XCTAssertEqual(MorphSpotlightCommandParser.parse(generalMusicQuery), .music(action: .open))
        model.spotlightQuery = generalMusicQuery
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.isExpanded, "General 'music' request MUST open larger UI so user can pick songs/playlists!")
        XCTAssertEqual(model.selectedTab, .music)
        
        // Reset state
        model.isExpanded = false
        
        // --- C. Notes / Scratchpad ---
        // 1. Specific action: "note buy groceries and coffee" -> MUST SKIP LARGER UI & pin directly
        let specificNoteQuery = "note buy groceries and coffee"
        model.spotlightQuery = specificNoteQuery
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded, "Direct note addition MUST skip larger UI!")
        XCTAssertTrue(model.scratchpad.text.contains("buy groceries and coffee"))
        XCTAssertTrue(model.isNotePinnedToNotch)
        XCTAssertEqual(model.compactHUDMode, .notesPinned)
        
        // 2. General request: "notes" -> MUST OPEN LARGER UI to Notes page so user can pick & edit
        let generalNotesQuery = "notes"
        XCTAssertEqual(MorphSpotlightCommandParser.parse(generalNotesQuery), .note(action: .view))
        model.spotlightQuery = generalNotesQuery
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.isExpanded, "General 'notes' request MUST open larger UI so user can view/pick notes!")
        XCTAssertEqual(model.selectedTab, .notes)
        
        // Reset state
        model.isExpanded = false
        
        // --- D. Calendar ---
        // General request: "calendar" -> MUST OPEN LARGER UI to Calendar page
        let generalCalendarQuery = "calendar"
        XCTAssertEqual(MorphSpotlightCommandParser.parse(generalCalendarQuery), .calendar(action: .view))
        model.spotlightQuery = generalCalendarQuery
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.isExpanded, "General 'calendar' request MUST open larger UI so user can view schedule!")
        XCTAssertEqual(model.selectedTab, .calendar)
    }
}
