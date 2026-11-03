import XCTest
import SwiftUI
@testable import morph

@MainActor
final class SpotlightPromptUnderstandingTests: XCTestCase {
    
    var model: NotchModel!
    
    override func setUp() async throws {
        try await super.setUp()
        model = NotchModel()
        model.interactionMode = .spotlightBar
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
    
    // MARK: - 6. Live Timer Controls From Prompt
    
    func testLiveTimerControlsFromPrompt() {
        // Start a 25m timer
        model.spotlightQuery = "25m"
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.pomodoro.isRunning)
        XCTAssertFalse(model.isExpanded)
        
        // 1. "pause timer"
        model.spotlightQuery = "pause timer"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.pomodoro.isRunning, "'pause timer' must pause pomodoro")
        XCTAssertFalse(model.isExpanded)
        if case .timer(let title, _) = model.activeBackgroundTaskPill {
            XCTAssertEqual(title, "Paused")
        } else {
            XCTFail("activeBackgroundTaskPill must be .timer")
        }
        
        // 2. "resume timer"
        model.spotlightQuery = "resume timer"
        model.handleSpotlightSubmit()
        XCTAssertTrue(model.pomodoro.isRunning, "'resume timer' must resume pomodoro")
        XCTAssertFalse(model.isExpanded)
        
        // 3. "+5m" adjustment
        let beforeAdd = model.pomodoro.timeRemaining
        model.spotlightQuery = "+5m"
        model.handleSpotlightSubmit()
        XCTAssertEqual(model.pomodoro.timeRemaining, beforeAdd + 300, "'+5m' must add 300s")
        XCTAssertFalse(model.isExpanded)
        
        // 4. "-5m" adjustment
        model.spotlightQuery = "-5m"
        model.handleSpotlightSubmit()
        XCTAssertEqual(model.pomodoro.timeRemaining, beforeAdd, "'-5m' must subtract 300s")
        XCTAssertFalse(model.isExpanded)
        
        // 5. "time left" status query
        model.spotlightQuery = "time left"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded)
        if case .timer(let title, _) = model.activeBackgroundTaskPill {
            XCTAssertTrue(title.contains("Remaining"))
        } else {
            XCTFail("activeBackgroundTaskPill must be .timer")
        }
        
        // 6. "stop timer"
        model.spotlightQuery = "stop timer"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.pomodoro.isRunning, "'stop timer' must stop pomodoro")
        XCTAssertEqual(model.activeBackgroundTaskPill, .none)
    }
    
    // MARK: - 7. Natural Verbal Durations From Prompt
    
    func testNaturalVerbalDurationsFromPrompt() {
        // "half an hour on math" -> 30 mins
        model.resetTransientStateOnCollapse()
        model.spotlightQuery = "half an hour on math"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded)
        XCTAssertEqual(model.requestedTimerMinutes, 30)
        XCTAssertTrue(model.customTimerTitle.contains("Math"))
        
        // "an hour and a half on physics" -> 90 mins
        model.resetTransientStateOnCollapse()
        model.spotlightQuery = "an hour and a half on physics"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded)
        XCTAssertEqual(model.requestedTimerMinutes, 90)
        XCTAssertTrue(model.customTimerTitle.contains("Physics"))
        
        // "an hour on swiftui" -> 60 mins
        model.resetTransientStateOnCollapse()
        model.spotlightQuery = "an hour on swiftui"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded)
        XCTAssertEqual(model.requestedTimerMinutes, 60)
        XCTAssertTrue(model.customTimerTitle.contains("Swiftui"))
        
        // "two hours on thesis" -> 120 mins
        model.resetTransientStateOnCollapse()
        model.spotlightQuery = "two hours on thesis"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded)
        XCTAssertEqual(model.requestedTimerMinutes, 120)
        XCTAssertTrue(model.customTimerTitle.contains("Thesis"))
    }
    
    // MARK: - 8. Live Music Controls From Prompt
    
    func testLiveMusicControlsFromPrompt() {
        model.resetTransientStateOnCollapse()
        
        // 1. "volume up"
        let initialVol = model.media.volume
        model.spotlightQuery = "volume up"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded)
        XCTAssertGreaterThanOrEqual(model.media.volume, initialVol)
        if case .media(let title, _) = model.activeBackgroundTaskPill {
            XCTAssertTrue(title.contains("Volume"))
        } else {
            XCTFail("Must set media pill with volume text")
        }
        
        // 2. "volume down"
        model.spotlightQuery = "volume down"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded)
        if case .media(let title, _) = model.activeBackgroundTaskPill {
            XCTAssertTrue(title.contains("Volume"))
        } else {
            XCTFail("Must set media pill with volume text")
        }
        
        // 3. "mute"
        model.spotlightQuery = "mute"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded)
        if case .media(let title, _) = model.activeBackgroundTaskPill {
            XCTAssertTrue(title == "Muted" || title == "Unmuted")
        } else {
            XCTFail("Must set media pill with mute status")
        }
        
        // 4. "what's playing"
        model.spotlightQuery = "what's playing"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded)
        if case .media = model.activeBackgroundTaskPill {
            // Success
        } else {
            XCTFail("Must show media pill for 'what's playing'")
        }
    }
    
    // MARK: - 9. Live Notes Inspection & Clipboard
    
    func testLiveNotesInspectionAndClipboardFromPrompt() {
        model.resetTransientStateOnCollapse()
        model.scratchpad.text = "Call architect at 4pm\nSubmit pull request"
        
        // 1. "read notes"
        model.spotlightQuery = "read notes"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded, "'read notes' must display preview in pill without opening large UI")
        if case .note(let preview) = model.activeBackgroundTaskPill {
            XCTAssertTrue(preview.contains("Call architect"))
        } else {
            XCTFail("activeBackgroundTaskPill must be .note with preview")
        }
        
        // 2. "copy notes"
        model.spotlightQuery = "copy notes"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded, "'copy notes' must display confirmation in pill")
        if case .note(let preview) = model.activeBackgroundTaskPill {
            XCTAssertTrue(preview.contains("Copied"))
        } else {
            XCTFail("activeBackgroundTaskPill must be .note with copied confirmation")
        }
        
        // 3. "clear notes"
        model.spotlightQuery = "clear notes"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded)
        XCTAssertEqual(model.scratchpad.text, "")
        if case .note(let preview) = model.activeBackgroundTaskPill {
            XCTAssertTrue(preview.contains("cleared"))
        } else {
            XCTFail("activeBackgroundTaskPill must confirm cleared")
        }
    }
    
    // MARK: - 10. Rich Calendar Natural Language
    
    func testRichCalendarNaturalLanguageAndEventCreation() {
        model.resetTransientStateOnCollapse()
        
        // 1. Next meeting inquiry
        model.spotlightQuery = "when is my next meeting"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded, "Schedule query must fulfill in background pill")
        if case .calendar = model.activeBackgroundTaskPill {
            // Success
        } else {
            XCTFail("Must route to calendar briefing pill")
        }
        
        // 2. Quick schedule meeting with time & duration
        model.resetTransientStateOnCollapse()
        model.spotlightQuery = "schedule 1:1 with Alex at 3pm for 45m"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded, "Event addition must fulfill in background pill")
        if case .calendar(let title, _, _, _) = model.activeBackgroundTaskPill {
            XCTAssertTrue(title.contains("1:1 With Alex") || title.contains("Alex"))
        } else {
            XCTFail("Must route to calendar pill with created event title")
        }
    }
    
    // MARK: - 11. Typo Resilience Across All 4 Domains
    
    func testTypoResilienceAcrossAllFourDomains() {
        // Focus Timer typo: "timr 25"
        model.resetTransientStateOnCollapse()
        model.spotlightQuery = "timr 25"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded)
        XCTAssertTrue(model.pomodoro.isRunning)
        XCTAssertEqual(model.requestedTimerMinutes, 25)
        
        // Calendar typo: "calender today"
        model.resetTransientStateOnCollapse()
        model.spotlightQuery = "calender today"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded)
        if case .calendar = model.activeBackgroundTaskPill {
            // Success
        } else {
            XCTFail("Typo 'calender today' must route to calendar briefing")
        }
        
        // Notes typo: "notepadd buy sourdough"
        model.resetTransientStateOnCollapse()
        model.spotlightQuery = "notepadd buy sourdough"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded)
        XCTAssertTrue(model.scratchpad.text.contains("buy sourdough"))
        
        // Music typo: "paly lofi"
        model.resetTransientStateOnCollapse()
        model.spotlightQuery = "paly lofi"
        model.handleSpotlightSubmit()
        XCTAssertFalse(model.isExpanded)
        if case .media(let track, _) = model.activeBackgroundTaskPill {
            XCTAssertTrue(track.lowercased().contains("lofi"))
        } else {
            XCTFail("Typo 'paly lofi' must route to music playback")
        }
    }
    
    // MARK: - 12. Contained Guidance For Morph 4 Features
    
    func testContainedGuidanceForMorphFourFeatures() {
        let helpQueries = ["help", "what can you do", "commands", "features"]
        
        for q in helpQueries {
            model.resetTransientStateOnCollapse()
            model.spotlightQuery = q
            model.handleSpotlightSubmit()
            
            XCTAssertTrue(model.isExpanded, "'\(q)' must open large UI guide")
            guard let ai = model.activeAIResponse else {
                XCTFail("activeAIResponse must not be nil for '\(q)'")
                continue
            }
            // Verify guidance contains all 4 features:
            XCTAssertTrue(ai.detailedContent.contains("Focus Timer"), "Guide must detail Focus Timer")
            XCTAssertTrue(ai.detailedContent.contains("Notes"), "Guide must detail Notes")
            XCTAssertTrue(ai.detailedContent.contains("Calendar"), "Guide must detail Calendar")
            XCTAssertTrue(ai.detailedContent.contains("Music"), "Guide must detail Music")
        }
    }
}
