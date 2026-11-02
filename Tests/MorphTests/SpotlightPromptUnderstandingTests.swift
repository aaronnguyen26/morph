import XCTest
import SwiftUI
@testable import morph

@MainActor
final class SpotlightPromptUnderstandingTests: XCTestCase {
    
    var model: NotchModel!
    
    override func setUp() async throws {
        try await super.setUp()
        model = NotchModel()
    }
    
    override func tearDown() async throws {
        model = nil
        try await super.tearDown()
    }
    
    // MARK: - 1. Calendar Specific Fetch vs General Page
    
    func testCalendarSpecificTodayQueryDisplaysInLengthenedPillWithoutOpeningLargeUI() {
        let cal = Calendar.current
        let today = Date()
        let meetingStart = cal.date(byAdding: .minute, value: 45, to: today) ?? today
        let meetingEnd = cal.date(byAdding: .minute, value: 75, to: today) ?? today
        
        let testEvent = CalendarEvent(
            id: "test_team_sync",
            title: "Team Architecture Sync",
            startTime: meetingStart,
            endTime: meetingEnd,
            meetLink: "https://meet.google.com/xyz-uvw-rst"
        )
        model.calendar.events = [testEvent]
        
        // Specific fetchable prompt
        model.spotlightQuery = "what on their calendar for today"
        model.handleSpotlightSubmit()
        
        // Must NOT expand into the large UI dashboard
        XCTAssertFalse(model.isExpanded, "Specific calendar query for today must skip the large UI")
        
        // Must use lengthened spotlight pill (510x38pt)
        XCTAssertEqual(model.islandState, .spotlightBar, "Must display in lengthened spotlight pill state")
        XCTAssertEqual(model.currentWidth, 510.0, "Must have widened 510 pt spotlight width")
        XCTAssertEqual(model.currentHeight, 38.0, "Must have slim 38 pt spotlight height")
        
        // Background task pill must contain the fetched event details
        if case .calendar(let title, let timeText, let meetLink, let fullEvent) = model.activeBackgroundTaskPill {
            XCTAssertTrue(title.contains("Team Architecture Sync"), "Briefing must show meeting title")
            XCTAssertTrue(timeText.contains("in 4"), "Briefing must indicate remaining time")
            XCTAssertEqual(meetLink, "https://meet.google.com/xyz-uvw-rst", "Meet link must be attached for direct one-click Join")
            XCTAssertEqual(fullEvent?.id, "test_team_sync")
        } else {
            XCTFail("activeBackgroundTaskPill must be in .calendar state")
        }
        
        // User dismisses via xmark
        model.dismissBackgroundTaskPill()
        XCTAssertEqual(model.activeBackgroundTaskPill, .none)
    }
    
    func testCalendarVariationsOfSpecificQueryRouteToBackgroundPill() {
        let queries = [
            "what's on my calendar today",
            "calendar today",
            "what do i have today",
            "do i have meetings today",
            "my schedule today",
            "plan for today"
        ]
        
        for q in queries {
            model.resetTransientStateOnCollapse()
            model.spotlightQuery = q
            model.handleSpotlightSubmit()
            
            XCTAssertFalse(model.isExpanded, "Query '\(q)' must not open the large UI")
            if case .calendar = model.activeBackgroundTaskPill {
                // Success
            } else {
                XCTFail("Query '\(q)' must set activeBackgroundTaskPill to .calendar")
            }
        }
    }
    
    func testCalendarGeneralQueryOpensLargestUI() {
        let generalQueries = ["calendar", "open calendar", "show calendar", "view calendar", "my calendar"]
        
        for q in generalQueries {
            model.resetTransientStateOnCollapse()
            model.spotlightQuery = q
            model.handleSpotlightSubmit()
            
            XCTAssertTrue(model.isExpanded, "General query '\(q)' must open the largest UI")
            XCTAssertEqual(model.selectedTab, .calendar, "General query '\(q)' must select the Calendar tab")
        }
    }
    
    // MARK: - 2. Focus Timer Specific Fetch vs General Page
    
    func testFocusTimerSpecificQueryDisplaysInLengthenedPillAndAllowsDirectInteraction() {
        model.spotlightQuery = "put timer for 25 minute"
        model.handleSpotlightSubmit()
        
        XCTAssertFalse(model.isExpanded, "Specific timer request must skip large UI")
        XCTAssertEqual(model.islandState, .spotlightBar, "Must display in lengthened spotlight pill")
        XCTAssertEqual(model.currentWidth, 510.0)
        XCTAssertEqual(model.currentHeight, 38.0)
        XCTAssertTrue(model.pomodoro.isRunning, "Timer must be running in the background")
        XCTAssertEqual(model.requestedTimerMinutes, 25)
        
        if case .timer(let title, let mins) = model.activeBackgroundTaskPill {
            XCTAssertEqual(mins, 25)
            XCTAssertEqual(title, "Focus Session")
        } else {
            XCTFail("activeBackgroundTaskPill must be .timer")
        }
        
        // Direct Action 1: User clicks Pause directly on the pill
        model.pomodoro.toggle()
        XCTAssertFalse(model.pomodoro.isRunning, "User clicking pause directly on the pill must pause timer")
        
        // Direct Action 2: User clicks Play directly on the pill
        model.pomodoro.toggle()
        XCTAssertTrue(model.pomodoro.isRunning, "User clicking play directly on the pill must resume timer")
        
        // Direct Action 3: User clicks +5m directly on the pill
        let beforeAdd = model.pomodoro.timeRemaining
        model.addFiveMinutesToTimer()
        XCTAssertEqual(model.pomodoro.timeRemaining, beforeAdd + 300, "User clicking +5m must add 300 seconds directly")
        
        // Direct Action 4: User clicks -5m directly on the pill
        model.subtractFiveMinutesFromTimer()
        XCTAssertEqual(model.pomodoro.timeRemaining, beforeAdd, "User clicking -5m must subtract 300 seconds directly")
        
        // Direct Action 5: User clicks stop/x button on the pill
        model.stopFocusTimerFromPill()
        XCTAssertFalse(model.pomodoro.isRunning)
        XCTAssertEqual(model.activeBackgroundTaskPill, .none)
    }
    
    func testFocusTimerGeneralQueryOpensLargestUI() {
        let generalQueries = ["timer", "focus timer", "open timer", "pomodoro", "pomo"]
        
        for q in generalQueries {
            model.resetTransientStateOnCollapse()
            model.spotlightQuery = q
            model.handleSpotlightSubmit()
            
            XCTAssertTrue(model.isExpanded, "General query '\(q)' must open the largest UI")
            XCTAssertEqual(model.selectedTab, .timer, "General query '\(q)' must select Focus Timer tab")
        }
    }
    
    // MARK: - 3. Music Specific Action vs General Page
    
    func testMusicSpecificPlayCommandDisplaysInLengthenedPillAndAllowsDirectControls() {
        model.spotlightQuery = "play lofi beats"
        model.handleSpotlightSubmit()
        
        XCTAssertFalse(model.isExpanded, "Specific playback action must skip large UI")
        XCTAssertEqual(model.islandState, .spotlightBar, "Must display in lengthened spotlight pill")
        XCTAssertEqual(model.currentWidth, 510.0)
        XCTAssertEqual(model.currentHeight, 38.0)
        
        if case .media(let trackTitle, _) = model.activeBackgroundTaskPill {
            XCTAssertFalse(trackTitle.isEmpty, "Media pill must have track title")
        } else {
            XCTFail("activeBackgroundTaskPill must be .media")
        }
        
        // Direct controls on the pill
        model.media.togglePlayPause()
        model.media.nextTrack()
        model.media.previousTrack()
        
        // Dismiss
        model.dismissBackgroundTaskPill()
        XCTAssertEqual(model.activeBackgroundTaskPill, .none)
    }
    
    func testMusicGeneralQueryOpensLargestUI() {
        let generalQueries = ["music", "open music", "songs", "playlist", "spotify"]
        
        for q in generalQueries {
            model.resetTransientStateOnCollapse()
            model.spotlightQuery = q
            model.handleSpotlightSubmit()
            
            XCTAssertTrue(model.isExpanded, "General query '\(q)' must open largest UI")
            XCTAssertEqual(model.selectedTab, .music, "General query '\(q)' must select Music tab")
        }
    }
    
    // MARK: - 4. Notes Specific Capture vs General Page
    
    func testNotesSpecificCaptureDisplaysInLengthenedPill() {
        model.spotlightQuery = "note sociology reading response #4"
        model.handleSpotlightSubmit()
        
        XCTAssertFalse(model.isExpanded, "Note capture must skip large UI")
        XCTAssertEqual(model.islandState, .spotlightBar)
        XCTAssertTrue(model.scratchpad.text.contains("sociology reading response #4"))
        
        if case .note(let preview) = model.activeBackgroundTaskPill {
            XCTAssertEqual(preview, "sociology reading response #4")
        } else {
            XCTFail("activeBackgroundTaskPill must be .note")
        }
    }
    
    func testNotesGeneralQueryOpensLargestUI() {
        let generalQueries = ["notes", "open notes", "scratchpad", "my notes"]
        
        for q in generalQueries {
            model.resetTransientStateOnCollapse()
            model.spotlightQuery = q
            model.handleSpotlightSubmit()
            
            XCTAssertTrue(model.isExpanded, "General query '\(q)' must open largest UI")
            XCTAssertEqual(model.selectedTab, .notes, "General query '\(q)' must select Notes tab")
        }
    }
    
    // MARK: - 5. Direct Answers vs General AI Assistant
    
    func testDirectAnswerQuestionsDisplayInLengthenedPill() {
        let directQuestions = ["what time is it", "what is the date", "hello"]
        
        for q in directQuestions {
            model.resetTransientStateOnCollapse()
            model.spotlightQuery = q
            model.handleSpotlightSubmit()
            
            XCTAssertFalse(model.isExpanded, "Direct answer '\(q)' must skip large UI")
            XCTAssertEqual(model.islandState, .spotlightBar)
            XCTAssertEqual(model.currentWidth, 510.0)
            XCTAssertEqual(model.currentHeight, 38.0)
            XCTAssertFalse(model.directAnswerText.isEmpty)
        }
    }
    
    func testGeneralAIQuestionsOpenLargestUI() {
        let generalAIQueries = ["what can you do?", "help", "how to study for finals", "explain cross entropy"]
        
        for q in generalAIQueries {
            model.resetTransientStateOnCollapse()
            model.spotlightQuery = q
            model.handleSpotlightSubmit()
            
            XCTAssertTrue(model.isExpanded, "General AI query '\(q)' must open largest UI")
            XCTAssertNotNil(model.activeAIResponse)
        }
    }
}
