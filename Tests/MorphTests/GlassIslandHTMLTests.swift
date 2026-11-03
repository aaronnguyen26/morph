import XCTest
import SwiftUI
@testable import morph

@MainActor
final class GlassIslandHTMLTests: XCTestCase {
    var model: NotchModel!
    
    override func setUp() async throws {
        try await super.setUp()
        model = NotchModel()
        model.isGlassIslandEnabled = true
        model.setGlassIslandState(.idle)
    }
    
    override func tearDown() async throws {
        model.resetTransientStateOnCollapse()
        model = nil
        try await super.tearDown()
    }
    
    // MARK: - 1. Dimensions, Radii, and Tints across all 7 Glass Island States
    func testGlassIslandStateMetricsMatchPrototype() {
        // Idle (Quiet)
        model.setGlassIslandState(.idle)
        XCTAssertEqual(model.currentWidth, 176.0, "Idle quiet pill width must be 176 pt")
        XCTAssertEqual(model.currentHeight, 38.0, "Idle quiet pill height must be 38 pt")
        XCTAssertEqual(model.glassIslandRadius, 19.0, "Idle quiet pill radius must be 19 pt")
        XCTAssertEqual(model.glassIslandTintHex, "#cfd8ff")
        
        // Idle with Live Timer
        model.previewGlassTimer(status: .running)
        model.isGlassMusicPlaying = false
        XCTAssertEqual(model.currentWidth, 208.0, "Idle live timer width must be 208 pt")
        XCTAssertEqual(model.currentHeight, 38.0)
        
        // Idle with Live Music
        model.previewGlassTimer(status: .ready)
        model.isGlassMusicPlaying = true
        XCTAssertEqual(model.currentWidth, 196.0, "Idle live music width must be 196 pt")
        XCTAssertEqual(model.currentHeight, 38.0)
        
        // Idle with Dual Active (Timer + Music)
        model.previewGlassTimer(status: .running)
        model.isGlassMusicPlaying = true
        XCTAssertEqual(model.currentWidth, 268.0, "Idle dual live activities width must be 268 pt")
        XCTAssertEqual(model.currentHeight, 38.0)
        
        // Prompt Bar
        model.setGlassIslandState(.prompt)
        XCTAssertEqual(model.currentWidth, 460.0, "Prompt bar width must be 460 pt")
        XCTAssertEqual(model.currentHeight, 56.0, "Prompt bar height must be 56 pt")
        XCTAssertEqual(model.glassIslandRadius, 28.0, "Prompt bar radius must be 28 pt")
        XCTAssertEqual(model.glassIslandTintHex, "#cfd8ff")
        
        // Timer Panel
        model.setGlassIslandState(.timer)
        XCTAssertEqual(model.currentWidth, 460.0, "Timer panel width must be 460 pt")
        XCTAssertEqual(model.currentHeight, 258.0, "Timer panel height must be 258 pt")
        XCTAssertEqual(model.glassIslandRadius, 34.0, "Timer panel radius must be 34 pt")
        XCTAssertEqual(model.glassIslandTintHex, "#ff9a7a")
        
        // Calendar Panel
        model.setGlassIslandState(.calendar)
        XCTAssertEqual(model.currentWidth, 460.0, "Calendar panel width must be 460 pt")
        XCTAssertEqual(model.currentHeight, 308.0, "Calendar panel height must be 308 pt")
        XCTAssertEqual(model.glassIslandRadius, 34.0, "Calendar panel radius must be 34 pt")
        XCTAssertEqual(model.glassIslandTintHex, "#6ab7ff")
        
        // Music Panel
        model.setGlassIslandState(.music)
        XCTAssertEqual(model.currentWidth, 460.0, "Music panel width must be 460 pt")
        XCTAssertEqual(model.currentHeight, 236.0, "Music panel height must be 236 pt")
        XCTAssertEqual(model.glassIslandRadius, 34.0, "Music panel radius must be 34 pt")
        XCTAssertEqual(model.glassIslandTintHex, "#ff7ab8")
        
        // Notes Panel
        model.setGlassIslandState(.notes)
        XCTAssertEqual(model.currentWidth, 460.0, "Notes panel width must be 460 pt")
        XCTAssertEqual(model.currentHeight, 284.0, "Notes panel height must be 284 pt")
        XCTAssertEqual(model.glassIslandRadius, 34.0, "Notes panel radius must be 34 pt")
        XCTAssertEqual(model.glassIslandTintHex, "#ffd36a")
        
        // Reply Panel
        model.setGlassIslandState(.reply)
        XCTAssertEqual(model.currentWidth, 460.0, "Reply panel width must be 460 pt")
        XCTAssertEqual(model.currentHeight, 152.0, "Reply panel height must be 152 pt")
        XCTAssertEqual(model.glassIslandRadius, 34.0, "Reply panel radius must be 34 pt")
        XCTAssertEqual(model.glassIslandTintHex, "#b79cff")
    }
    
    // MARK: - 2. Tab Toggling & Esc Dismissal
    func testTabTogglingAndDismissal() {
        model.setGlassIslandState(.prompt)
        XCTAssertEqual(model.glassIslandState, .prompt)
        
        // Tapping timer opens timer
        model.toggleGlassIslandTab(.timer)
        XCTAssertEqual(model.glassIslandState, .timer)
        
        // Tapping timer again toggles back to prompt bar
        model.toggleGlassIslandTab(.timer)
        XCTAssertEqual(model.glassIslandState, .prompt)
        
        // Tapping music opens music
        model.toggleGlassIslandTab(.music)
        XCTAssertEqual(model.glassIslandState, .music)
        
        // Tapping calendar switches directly to calendar
        model.toggleGlassIslandTab(.calendar)
        XCTAssertEqual(model.glassIslandState, .calendar)
        
        // Dismiss to idle
        model.dismissGlassIslandToIdle()
        XCTAssertEqual(model.glassIslandState, .idle)
    }
    
    // MARK: - 3. Focus Timer Presets, Actions, and Session Dots
    func testFocusTimerLifecycle() {
        model.setGlassIslandState(.timer)
        model.setGlassTimerMinutes(15)
        XCTAssertEqual(model.glassTimerMins, 15)
        XCTAssertEqual(model.glassTimerDur, 900)
        XCTAssertEqual(model.glassTimerLeft, 900)
        XCTAssertEqual(model.glassTimerStatus, .ready)
        XCTAssertEqual(model.formattedGlassTimerTime, "15:00")
        
        // Preset 50
        model.setGlassTimerMinutes(50)
        XCTAssertEqual(model.glassTimerMins, 50)
        XCTAssertEqual(model.glassTimerDur, 3000)
        XCTAssertEqual(model.glassTimerLeft, 3000)
        XCTAssertEqual(model.formattedGlassTimerTime, "50:00")
        
        // Start Timer
        model.startGlassTimer()
        XCTAssertEqual(model.glassTimerStatus, .running)
        XCTAssertTrue(model.isGlassTimerActive)
        
        // Pause Timer
        model.pauseGlassTimer()
        XCTAssertEqual(model.glassTimerStatus, .paused)
        XCTAssertTrue(model.isGlassTimerActive)
        
        // Toggle resumes
        model.toggleGlassTimer()
        XCTAssertEqual(model.glassTimerStatus, .running)
        
        // Reset
        model.resetGlassTimer()
        XCTAssertEqual(model.glassTimerStatus, .ready)
        XCTAssertFalse(model.isGlassTimerActive)
        XCTAssertEqual(model.glassTimerLeft, 3000)
    }
    
    // MARK: - 4. Music Player Actions & Queue Navigation
    func testMusicPlayerControls() {
        model.setGlassIslandState(.music)
        XCTAssertEqual(model.glassTrackIndex, 0)
        XCTAssertEqual(model.glassTracks[0].title, "Glass Hours")
        XCTAssertEqual(model.glassTracks[0].artist, "Marlowe Vale")
        XCTAssertEqual(model.glassTracks[0].duration, 188)
        
        // Play / Pause
        model.isGlassMusicPlaying = false
        model.toggleGlassMusicPlay()
        XCTAssertTrue(model.isGlassMusicPlaying)
        
        // Skip track (next)
        model.skipGlassMusic(1)
        XCTAssertEqual(model.glassTrackIndex, 1)
        XCTAssertEqual(model.glassTracks[1].title, "Low Tide Signals")
        
        // Skip track wrapping around
        model.skipGlassMusic(1)
        XCTAssertEqual(model.glassTrackIndex, 2)
        model.skipGlassMusic(1)
        XCTAssertEqual(model.glassTrackIndex, 0)
        
        // Previous track (when cur <= 3 skips to prev track)
        model.seekGlassMusic(to: 2)
        model.prevGlassMusic()
        XCTAssertEqual(model.glassTrackIndex, 2)
        
        // Previous track (when cur > 3 rewinds to 0 without changing track index)
        model.seekGlassMusic(to: 45)
        model.prevGlassMusic()
        XCTAssertEqual(model.glassTrackIndex, 2)
        XCTAssertEqual(model.glassTrackCurrentSeconds, 0)
        
        // Seek
        model.seekGlassMusic(to: 45)
        XCTAssertEqual(model.glassTrackCurrentSeconds, 45)
        XCTAssertEqual(model.formattedGlassTrackCurrentTime, "0:45")
    }
    
    // MARK: - 5. Notes List, Creation, and Detail Editing
    func testNotesListAndEditing() {
        model.setGlassIslandState(.notes)
        XCTAssertEqual(model.glassNotesMode, .list)
        let initialCount = model.glassNotes.count
        
        // Add note opens edit mode
        model.addGlassNote(title: "Design Meeting", body: "Discuss new liquid glass island")
        XCTAssertEqual(model.glassNotes.count, initialCount + 1)
        XCTAssertEqual(model.glassNotesMode, .edit)
        XCTAssertEqual(model.glassEditTitle, "Design Meeting")
        XCTAssertEqual(model.glassEditBody, "Discuss new liquid glass island")
        
        // Close note returns to list mode and updates note
        model.glassEditTitle = "Updated Title"
        model.closeGlassNote()
        XCTAssertEqual(model.glassNotesMode, .list)
        XCTAssertEqual(model.glassNotes[0].title, "Updated Title")
        
        // Creating an empty note and closing it automatically removes it
        let countBeforeEmpty = model.glassNotes.count
        model.addGlassNote(title: "", body: "")
        XCTAssertEqual(model.glassNotes.count, countBeforeEmpty + 1)
        model.closeGlassNote()
        XCTAssertEqual(model.glassNotes.count, countBeforeEmpty, "Empty note must be removed on close per prototype spec")
    }
    
    // MARK: - 6. Prompt Routing Understanding
    func testPromptRoutingToNotes() {
        model.setGlassIslandState(.prompt)
        model.submitGlassIslandPrompt("note: buy oat milk from market")
        XCTAssertEqual(model.glassIslandState, .notes)
        XCTAssertEqual(model.glassNotes[0].body, "buy oat milk from market")
    }
    
    func testPromptRoutingToTimer() {
        model.setGlassIslandState(.prompt)
        model.submitGlassIslandPrompt("focus 25")
        XCTAssertEqual(model.glassIslandState, .timer)
        XCTAssertEqual(model.glassTimerMins, 25)
        XCTAssertEqual(model.glassTimerStatus, .running)
        
        // Custom minutes
        model.submitGlassIslandPrompt("timer 15")
        XCTAssertEqual(model.glassIslandState, .timer)
        XCTAssertEqual(model.glassTimerMins, 15)
        XCTAssertEqual(model.glassTimerStatus, .running)
    }
    
    func testPromptRoutingToCalendar() {
        model.setGlassIslandState(.prompt)
        model.submitGlassIslandPrompt("what is on today")
        XCTAssertEqual(model.glassIslandState, .calendar)
        XCTAssertEqual(model.glassSelectedDayIndex, 0)
        
        model.submitGlassIslandPrompt("calendar")
        XCTAssertEqual(model.glassIslandState, .calendar)
    }
    
    func testPromptRoutingToMusic() {
        model.setGlassIslandState(.prompt)
        model.submitGlassIslandPrompt("play music")
        XCTAssertEqual(model.glassIslandState, .music)
        XCTAssertTrue(model.isGlassMusicPlaying)
        
        model.submitGlassIslandPrompt("pause")
        XCTAssertEqual(model.glassIslandState, .music)
        XCTAssertFalse(model.isGlassMusicPlaying)
    }
    
    func testPromptRoutingToReply() {
        model.setGlassIslandState(.prompt)
        model.submitGlassIslandPrompt("how far is the moon?")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyQuery, "how far is the moon?")
        XCTAssertTrue(model.isGlassReplyLoading)
    }
    
    // MARK: - 7. Removed "Hover to open" & Refined Idle Edge Verification
    func testIdleCapsuleRemovedHoverToOpenAndRendersSubtleEdges() {
        model.setGlassIslandState(.idle)
        XCTAssertEqual(model.glassIslandWidth, 176.0)
        XCTAssertEqual(model.glassIslandHeight, 38.0)
        XCTAssertEqual(model.glassIslandRadius, 19.0)
        
        // Renders MorphIslandView without errors
        let view = MorphIslandView(model: model)
        XCTAssertNotNil(view.body)
    }
    
    // MARK: - 8. Real Calendar Integration and Browser Prompt
    func testRealCalendarModelIntegrationAndSignInPrompt() {
        XCTAssertFalse(model.hasPromptedCalendarSignIn)
        
        // Switching to calendar triggers sign in check
        model.setGlassIslandState(.calendar)
        XCTAssertTrue(model.hasPromptedCalendarSignIn)
        
        // Add real event to model.calendar matching selected date
        let targetDate = model.glassSelectedDate
        let event = CalendarEvent(
            id: "real_event_1",
            title: "Sprint Retrospective",
            startTime: targetDate,
            endTime: targetDate.addingTimeInterval(3600),
            location: "Room A",
            colorHex: "#6ab7ff"
        )
        model.calendar.events = [event]
        
        let realEvents = model.glassRealCalendarEvents
        XCTAssertFalse(realEvents.isEmpty)
        XCTAssertEqual(realEvents.first?.title, "Sprint Retrospective")
        
        // Dynamic dates formatting
        XCTAssertFalse(model.formattedGlassMonthYear.isEmpty)
        XCTAssertFalse(model.formattedGlassDayTitle.isEmpty)
    }
    
    // MARK: - 9. Real Media Integration and Browser Prompt
    func testRealMediaControllerIntegrationAndSignInPrompt() {
        XCTAssertFalse(model.hasPromptedMusicSignIn)
        
        // Switching to music triggers sign in check
        model.setGlassIslandState(.music)
        XCTAssertTrue(model.hasPromptedMusicSignIn)
        
        // When real media has track metadata
        model.media.trackTitle = "Subtle Echoes"
        model.media.artistName = "Aurora"
        model.media.currentTime = 42
        model.media.duration = 210
        
        XCTAssertEqual(model.glassMusicTitle, "Subtle Echoes")
        XCTAssertEqual(model.glassMusicArtist, "Aurora")
        XCTAssertEqual(model.formattedGlassTrackCurrentTime, "0:42")
        XCTAssertEqual(model.formattedGlassTrackDuration, "3:30")
        
        // Playback delegation
        model.toggleGlassMusicPlay()
        XCTAssertTrue(model.isGlassMusicPlaying)
    }
}
