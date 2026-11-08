import XCTest
@testable import morph

@MainActor
final class CommandBarIntelligenceTests: XCTestCase {
    
    override func setUp() async throws {
        // Clear memories and form items for clean test baseline
        SupabaseService.shared.memoryItems.removeAll()
    }
    
    // MARK: - 1. Strict Memory Isolation & Clean Typing (Zero Duplicate Ask Box)
    
    func testPromptSubmissionNeverWritesToMemory() {
        let model = NotchModel()
        let initialMemoryCount = model.supabase.memoryItems.count
        
        let testPrompts = [
            "what is my next meeting?",
            "how many files are staged in drop shelf?",
            "open calendar",
            "is the timer running?",
            "who am i?",
            "what is the weather today?",
            "focus 25",
            "pause music"
        ]
        
        for prompt in testPrompts {
            model.submitGlassIslandPrompt(prompt)
        }
        
        XCTAssertEqual(
            model.supabase.memoryItems.count,
            initialMemoryCount,
            "Prompt submissions must NEVER add items to persistent memory"
        )
        
        for item in model.supabase.memoryItems {
            XCTAssertEqual(
                item.kind,
                "form",
                "Only form detection features are allowed to produce memory items"
            )
        }
    }
    
    func testPromptTypingDoesNotShowDuplicateAskPeekBox() {
        let model = NotchModel()
        model.setGlassIslandState(.prompt)
        
        // Typing general queries or questions must NEVER produce an 'Ask...' duplicate preview box
        model.glassPromptText = "hello world question"
        XCTAssertNil(
            model.promptPeekInfo,
            "Typing general text must not return an 'Ask...' peek preview"
        )
        XCTAssertFalse(
            model.isPromptPeekActive,
            "isPromptPeekActive must be false so the command bar stays compact at 56pt"
        )
        XCTAssertEqual(
            model.glassIslandHeight,
            56,
            "Island height must remain 56pt without redundant boxes below"
        )
        
        model.glassPromptText = "what is my next meeting?"
        XCTAssertNil(
            model.promptPeekInfo,
            "Typing questions must not return an 'Ask...' peek preview"
        )
        XCTAssertFalse(model.isPromptPeekActive)
        XCTAssertEqual(model.glassIslandHeight, 56)
        
        // Note shortcut preview is an actionable hint, but must not say 'Ask' or 'stored in Memory'
        model.glassPromptText = "note: important idea"
        XCTAssertNotNil(model.promptPeekInfo)
        XCTAssertFalse(
            model.promptPeekInfo?.title.lowercased().hasPrefix("ask ") ?? false,
            "Note peek title must not be an 'Ask' preview"
        )
        XCTAssertFalse(
            model.promptPeekInfo?.subtitle.contains("stored in Memory") ?? false,
            "Note peek subtitle must not say 'stored in Memory'"
        )
    }
    
    // MARK: - 2. Action Conduction System
    
    func testConductedTimerActionPauseResumeAndReset() {
        let model = NotchModel()
        model.setGlassTimerMinutes(25)
        model.startGlassTimer()
        XCTAssertTrue(model.isGlassTimerActive)
        
        // Action: "pause timer"
        model.submitGlassIslandPrompt("pause timer")
        XCTAssertEqual(model.glassTimerStatus, .paused)
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Focus Timer")
        XCTAssertTrue(model.glassReplyAnswer.contains("paused"))
        XCTAssertEqual(model.glassReplyActionTitle, "Resume Timer")
        
        // Action: "resume timer"
        model.submitGlassIslandPrompt("resume timer")
        XCTAssertEqual(model.glassTimerStatus, .running)
        XCTAssertTrue(model.glassReplyAnswer.contains("resumed"))
        
        // Action: "reset timer"
        model.submitGlassIslandPrompt("reset timer")
        XCTAssertEqual(model.glassTimerStatus, .ready)
        XCTAssertTrue(model.glassReplyAnswer.contains("reset"))
    }
    
    func testConductedMusicActionPausePlaySkipAndMute() {
        let model = NotchModel()
        model.media.trackTitle = "Midnight City"
        model.media.artistName = "M83"
        model.media.isPlaying = true
        
        // Action: "pause music"
        model.submitGlassIslandPrompt("pause music")
        XCTAssertFalse(model.media.isPlaying)
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Music Player")
        XCTAssertTrue(model.glassReplyAnswer.contains("paused"))
        
        // Action: "next song"
        model.submitGlassIslandPrompt("next song")
        XCTAssertTrue(model.glassReplyAnswer.contains("Skipped"))
        
        // Action: "mute music"
        model.submitGlassIslandPrompt("mute music")
        XCTAssertTrue(model.media.isMuted)
        XCTAssertTrue(model.glassReplyAnswer.contains("muted"))
    }
    
    func testConductedDropShelfActionClearAndCopy() {
        let model = NotchModel()
        let dummyURL = URL(fileURLWithPath: "/tmp/sample_presentation.pdf")
        let item = DropShelfItem(url: dummyURL, name: "sample_presentation.pdf")
        model.dropShelf.stagedItems = [item]
        XCTAssertEqual(model.dropShelf.count, 1)
        
        // Action: "copy paths"
        model.submitGlassIslandPrompt("copy paths")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Drop Shelf")
        XCTAssertTrue(model.glassReplyAnswer.contains("Copied 1 staged file path"))
        
        // Action: "clear shelf"
        model.submitGlassIslandPrompt("clear shelf")
        XCTAssertEqual(model.dropShelf.count, 0)
        XCTAssertTrue(model.glassReplyAnswer.contains("Drop Shelf cleared"))
    }
    
    func testConductedNotesActionCreateAndDelete() {
        let model = NotchModel()
        model.glassNotes.removeAll()
        
        // Action: "note: buy flight tickets"
        model.submitGlassIslandPrompt("note: buy flight tickets")
        XCTAssertEqual(model.glassNotes.count, 1)
        XCTAssertTrue(model.glassNotes[0].body.contains("buy flight tickets"))
        XCTAssertTrue(model.glassReplyAnswer.contains("Saved note"))
        
        // Action: "delete last note"
        model.submitGlassIslandPrompt("delete last note")
        XCTAssertEqual(model.glassNotes.count, 0)
        XCTAssertTrue(model.glassReplyAnswer.contains("Deleted latest note"))
    }
    
    func testConductedCalendarActionAddEvent() {
        let model = NotchModel()
        let initialEvents = model.calendar.events.count
        
        // Action: "add event Team Project Sync"
        model.submitGlassIslandPrompt("add event Team Project Sync")
        XCTAssertEqual(model.calendar.events.count, initialEvents + 1)
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Calendar")
        XCTAssertTrue(model.glassReplyAnswer.contains("Added event “Team Project Sync”"))
    }
    
    func testConductedProfileActionSetStatus() {
        let model = NotchModel()
        
        // Action: "set status to In The Zone"
        model.submitGlassIslandPrompt("set status to In The Zone")
        XCTAssertEqual(model.supabase.currentUser.currentStatus, "In The Zone")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Profile")
        XCTAssertTrue(model.glassReplyAnswer.contains("In The Zone"))
    }
    
    // MARK: - 3. General Questions / Navigational Commands
    
    func testGeneralCalendarCommandOpensCalendar() {
        let model = NotchModel()
        model.setGlassIslandState(.prompt)
        
        model.submitGlassIslandPrompt("open calendar")
        XCTAssertEqual(model.glassIslandState, .calendar)
    }
    
    func testGeneralTimerCommandOpensTimer() {
        let model = NotchModel()
        model.setGlassIslandState(.prompt)
        
        model.submitGlassIslandPrompt("open timer")
        XCTAssertEqual(model.glassIslandState, .timer)
        
        model.setGlassIslandState(.prompt)
        model.submitGlassIslandPrompt("focus 25")
        XCTAssertEqual(model.glassIslandState, .timer)
        XCTAssertTrue(model.isGlassTimerActive)
    }
    
    func testGeneralMusicCommandOpensMusic() {
        let model = NotchModel()
        model.setGlassIslandState(.prompt)
        
        model.submitGlassIslandPrompt("open music")
        XCTAssertEqual(model.glassIslandState, .music)
    }
    
    func testGeneralNotesCommandOpensNotes() {
        let model = NotchModel()
        model.setGlassIslandState(.prompt)
        
        model.submitGlassIslandPrompt("open notes")
        XCTAssertEqual(model.glassIslandState, .notes)
    }
    
    func testGeneralDropShelfCommandOpensDropShelf() {
        let model = NotchModel()
        model.setGlassIslandState(.prompt)
        
        model.submitGlassIslandPrompt("open drop shelf")
        XCTAssertEqual(model.glassIslandState, .drops)
    }
    
    func testGeneralProfileCommandOpensProfile() {
        let model = NotchModel()
        model.setGlassIslandState(.prompt)
        
        model.submitGlassIslandPrompt("open profile")
        XCTAssertEqual(model.glassIslandState, .profile)
    }
    
    // MARK: - 4. Specific Questions (Answering within Feature Boundary)
    
    func testSpecificCalendarQuestionAnswersInIsland() {
        let model = NotchModel()
        model.setGlassIslandState(.prompt)
        
        model.submitGlassIslandPrompt("what is my next meeting?")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Calendar")
        XCTAssertEqual(model.glassReplyDomainIcon, "calendar")
        XCTAssertFalse(model.glassReplyAnswer.isEmpty)
    }
    
    func testSpecificDropShelfQuestionAnswersInIsland() {
        let model = NotchModel()
        model.setGlassIslandState(.prompt)
        
        model.submitGlassIslandPrompt("how many files are staged in drop shelf?")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Drop Shelf")
        XCTAssertEqual(model.glassReplyDomainIcon, "tray.and.arrow.down")
        XCTAssertTrue(model.glassReplyAnswer.contains("Drop Shelf"))
    }
    
    func testSpecificTimerQuestionAnswersInIsland() {
        let model = NotchModel()
        model.setGlassIslandState(.prompt)
        
        model.submitGlassIslandPrompt("is the timer running?")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Focus Timer")
        XCTAssertEqual(model.glassReplyDomainIcon, "timer")
        XCTAssertTrue(model.glassReplyAnswer.contains("Focus timer"))
    }
    
    func testSpecificMusicQuestionAnswersInIsland() {
        let model = NotchModel()
        model.setGlassIslandState(.prompt)
        
        model.submitGlassIslandPrompt("what song is playing?")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Music Player")
        XCTAssertEqual(model.glassReplyDomainIcon, "music.note")
        XCTAssertFalse(model.glassReplyAnswer.isEmpty)
    }
    
    func testSpecificProfileQuestionAnswersInIsland() {
        let model = NotchModel()
        model.setGlassIslandState(.prompt)
        
        model.submitGlassIslandPrompt("who am i?")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Profile")
        XCTAssertEqual(model.glassReplyDomainIcon, "person.crop.circle")
        XCTAssertTrue(model.glassReplyAnswer.contains(model.supabase.currentUser.displayName))
    }
    
    func testSpecificFormQuestionAnswersInIsland() {
        let model = NotchModel()
        model.setGlassIslandState(.prompt)
        
        model.submitGlassIslandPrompt("how many form receipts do i have?")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Form Assistant")
        XCTAssertEqual(model.glassReplyDomainIcon, "list.bullet.clipboard")
    }
    
    func testMorphSystemCapabilityQuestionAnswersInIsland() {
        let model = NotchModel()
        model.setGlassIslandState(.prompt)
        
        model.submitGlassIslandPrompt("how does the drop shelf work?")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertTrue(model.glassReplyAnswer.contains("Drop Shelf"))
    }
    
    // MARK: - 5. Requirement 3: No Action Fallback (Zero "Morph Intelligence" Text)
    
    func testOutOfBoundaryPromptNeverReturnsMorphIntelligenceText() {
        let model = NotchModel()
        model.setGlassIslandState(.prompt)
        
        model.submitGlassIslandPrompt("what is the capital of Australia?")
        
        XCTAssertEqual(model.glassIslandState, .reply)
        // Zero "morph intelligence" boilerplate text
        XCTAssertFalse(
            model.glassReplyAnswer.lowercased().contains("morph intelligence"),
            "Fallback answer must never contain 'morph intelligence'"
        )
        XCTAssertFalse(
            model.glassReplyAnswer.lowercased().contains("island intelligence"),
            "Fallback answer must never contain 'island intelligence'"
        )
        XCTAssertFalse(
            model.glassReplyDomainTitle.lowercased().contains("intelligence"),
            "Fallback domain must never say 'intelligence'"
        )
        
        // Displays helpful quick action chips
        XCTAssertFalse(
            model.glassReplyQuickActions.isEmpty,
            "Fallback should provide interactive quick action suggestions"
        )
        XCTAssertTrue(
            model.glassReplyQuickActions.contains(where: { $0.title == "Focus 25" })
        )
        XCTAssertTrue(
            model.glassReplyQuickActions.contains(where: { $0.title == "Schedule" })
        )
        XCTAssertTrue(
            model.glassReplyQuickActions.contains(where: { $0.title == "Drop Shelf" })
        )
    }
    
    // MARK: - 6. Natural Language Understanding (NLU) Dynamic Freeform Tests
    
    func testNaturalLanguageUnderstandingFreeformActionsAndInquiries() {
        let model = NotchModel()
        
        // 1. Timer NLU Pause Action via "freeze the countdown"
        model.setGlassTimerMinutes(25)
        model.startGlassTimer()
        XCTAssertEqual(model.glassTimerStatus, .running)
        model.submitGlassIslandPrompt("freeze the countdown")
        XCTAssertEqual(model.glassTimerStatus, .paused, "NLU must understand 'freeze the countdown' as pausing the timer")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Focus Timer")
        
        // 2. Drop Shelf NLU Clear Action via "dump the staged files"
        let testFileURL = URL(fileURLWithPath: "/tmp/sample_doc.pdf")
        model.dropShelf.stageFile(url: testFileURL)
        XCTAssertGreaterThan(model.dropShelf.count, 0)
        model.submitGlassIslandPrompt("dump the staged files")
        XCTAssertEqual(model.dropShelf.count, 0, "NLU must understand 'dump the staged files' as clearing the shelf")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Drop Shelf")
        
        // 3. Calendar NLU Freeform Inquiry via "got any appointments today?"
        model.submitGlassIslandPrompt("got any appointments today?")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Calendar")
        XCTAssertFalse(model.glassReplyAnswer.isEmpty)
        
        // 4. Calendar NLU Freeform Inquiry via "am I free this afternoon?"
        model.submitGlassIslandPrompt("am I free this afternoon?")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Calendar")
        
        // 5. Music NLU Freeform Inquiry via "what track is currently playing?"
        model.submitGlassIslandPrompt("what track is currently playing?")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Music Player")
        XCTAssertEqual(model.glassReplyDomainIcon, "music.note")
        
        // 6. Profile NLU Freeform Inquiry via "who is currently signed in?"
        model.submitGlassIslandPrompt("who is currently signed in?")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Profile")
        XCTAssertTrue(model.glassReplyAnswer.contains(model.supabase.currentUser.displayName))
        
        // 7. Morph System NLU Inquiry via "what can morph do?"
        model.submitGlassIslandPrompt("what can morph do?")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Morph")
        XCTAssertTrue(model.glassReplyAnswer.contains("Morph"))
        
        // 8. Natural Language Dynamic Duration: "start a 45 minute focus session"
        model.submitGlassIslandPrompt("start a 45 minute focus session")
        XCTAssertEqual(model.glassTimerMins, 45, "NLU must extract 45 minute duration parameter")
        XCTAssertEqual(model.glassTimerStatus, .running, "Timer must be running")
        XCTAssertEqual(model.glassIslandState, .timer, "Should navigate directly to timer view")
    }
    
    // MARK: - 7. Siri AI Conversational Comprehension & Boundary Tests
    
    func testSiriAIConversationalComprehensionAndBoundaryGuidance() {
        let model = NotchModel()
        
        // 1. Politeness wrapper handling: "could you please pause the timer"
        model.setGlassTimerMinutes(25)
        model.startGlassTimer()
        XCTAssertEqual(model.glassTimerStatus, .running)
        model.submitGlassIslandPrompt("could you please pause the timer")
        XCTAssertEqual(model.glassTimerStatus, .paused, "Should strip politeness and pause timer")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Focus Timer")
        
        // 2. Colloquial Lock In: "let's lock in for an hour"
        model.submitGlassIslandPrompt("let's lock in for an hour")
        XCTAssertEqual(model.glassTimerMins, 60, "Must parse 'an hour' as 60 minutes")
        XCTAssertEqual(model.glassTimerStatus, .running)
        XCTAssertEqual(model.glassIslandState, .timer)
        
        // 3. Colloquial Break: "take five"
        model.submitGlassIslandPrompt("take five")
        XCTAssertEqual(model.glassTimerMins, 5, "Must parse 'take five' as 5 minutes")
        XCTAssertEqual(model.glassTimerStatus, .running)
        XCTAssertEqual(model.glassIslandState, .timer)
        
        // 4. Colloquial Music: "put on some tunes"
        model.media.isPlaying = false
        model.submitGlassIslandPrompt("put on some tunes")
        XCTAssertTrue(model.isGlassMusicPlaying, "Must understand 'put on some tunes' as playing music")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Music Player")
        
        // 5. Colloquial Silence: "silence the music"
        model.media.isMuted = false
        model.submitGlassIslandPrompt("silence the music")
        XCTAssertTrue(model.media.isMuted, "Must understand 'silence the music' as muting")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Music Player")
        
        // 6. Colloquial Shelf Cleanup: "clean up the clutter on my shelf"
        let testFile = URL(fileURLWithPath: "/tmp/clutter_file.txt")
        model.dropShelf.stageFile(url: testFile)
        XCTAssertGreaterThan(model.dropShelf.count, 0)
        model.submitGlassIslandPrompt("clean up the clutter on my shelf")
        XCTAssertEqual(model.dropShelf.count, 0, "Must understand 'clean up the clutter' as clearing shelf")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Drop Shelf")
        
        // 7. Colloquial Reminder/Note: "remind me to call the accountant"
        let initialNotes = model.glassNotes.count
        model.submitGlassIslandPrompt("remind me to call the accountant")
        XCTAssertEqual(model.glassNotes.count, initialNotes + 1)
        XCTAssertTrue(model.glassNotes.first?.body.contains("call the accountant") ?? false)
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Notes")
        
        // 8. Colloquial Status: "set my status to In The Zone"
        model.submitGlassIslandPrompt("set my status to In The Zone")
        XCTAssertEqual(model.supabase.currentUser.currentStatus, "In The Zone")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Profile")
        
        // 9. Conversational Form Autofill: "paste my info into this form"
        model.submitGlassIslandPrompt("paste my info into this form")
        XCTAssertEqual(model.glassIslandState, .idle, "Autofill action returns to idle resting state")
        
        // 10. Conversational Availability Inquiry: "how's my day looking?"
        model.submitGlassIslandPrompt("how's my day looking?")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Calendar")
        XCTAssertFalse(model.glassReplyAnswer.isEmpty)
        
        // 11. Conversational Timer Finish Time Inquiry: "when will my timer finish?"
        model.setGlassTimerMinutes(25)
        model.startGlassTimer()
        model.submitGlassIslandPrompt("when will my timer finish?")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Focus Timer")
        XCTAssertTrue(model.glassReplyAnswer.contains("finishing at") || model.glassReplyAnswer.contains("Focus timer"))
        
        // 12. Siri AI Feature Boundary Enforcement: "what is the distance to Mars?"
        model.submitGlassIslandPrompt("what is the distance to Mars?")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertFalse(model.glassReplyAnswer.lowercased().contains("morph intelligence"))
        XCTAssertTrue(model.glassReplyAnswer.contains("calendar") || model.glassReplyAnswer.contains("focus timer") || model.glassReplyAnswer.contains("music"))
        XCTAssertFalse(model.glassReplyQuickActions.isEmpty)
        XCTAssertTrue(model.glassReplyQuickActions.contains(where: { $0.title == "Focus 25" }))
    }
}
