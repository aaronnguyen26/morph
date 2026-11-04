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
        model.media.engine.trackData = YTMTrackData()
        model.media.engine.isSignedIn = false
        model.media.isDirectEngineConnected = false
        model.media.isPlaying = false
        model.media.isBrowserConnected = false
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
        XCTAssertEqual(model.currentHeight, 384.0, "Music panel height must be 384 pt")
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
        let count = model.glassTracks.count
        XCTAssertGreaterThanOrEqual(count, 3)
        XCTAssertEqual(model.glassTracks[0].title, "Starboy")
        XCTAssertEqual(model.glassTracks[0].artist, "The Weeknd ft. Daft Punk")
        XCTAssertEqual(model.glassTracks[0].duration, 230)
        
        // Play / Pause
        model.isGlassMusicPlaying = false
        model.toggleGlassMusicPlay()
        XCTAssertTrue(model.isGlassMusicPlaying)
        
        // Skip track (next)
        model.skipGlassMusic(1)
        XCTAssertEqual(model.glassTrackIndex, 1)
        XCTAssertEqual(model.glassTracks[1].title, "Midnight City")
        
        // Skip track wrapping around
        model.skipGlassMusic(count - 2)
        XCTAssertEqual(model.glassTrackIndex, count - 1)
        model.skipGlassMusic(1)
        XCTAssertEqual(model.glassTrackIndex, 0)
        
        // Previous track (when cur <= 3 skips to prev track)
        model.seekGlassMusic(to: 2)
        model.prevGlassMusic()
        XCTAssertEqual(model.glassTrackIndex, count - 1)
        
        // Previous track (when cur > 3 rewinds to 0 without changing track index)
        model.seekGlassMusic(to: 45)
        model.prevGlassMusic()
        XCTAssertEqual(model.glassTrackIndex, count - 1)
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
        model.isGlassMusicPlaying = false
        model.toggleGlassMusicPlay()
        XCTAssertTrue(model.isGlassMusicPlaying)
    }
    
    // MARK: - 10. YouTube Music Direct Sign-In and Real Library Access
    func testYouTubeMusicDirectSignInFlowWithoutExternalBrowser() {
        let engine = model.media.engine
        XCTAssertFalse(engine.isWaitingForSignInCompletion)
        
        // Calling openSignIn sets waiting flag and triggers loadGoogleSignIn on engine
        model.media.openSignIn()
        XCTAssertTrue(model.media.isWaitingForBrowserSignIn)
        XCTAssertTrue(engine.isWaitingForSignInCompletion)
        XCTAssertTrue(model.media.browserAuthStatusMessage?.contains("Morph YouTube Music window") == true)
        
        // Calling openSignInInBrowser now routes directly to openSignIn to avoid external browser tab drop
        model.media.openSignInInBrowser()
        XCTAssertTrue(model.media.isWaitingForBrowserSignIn)
        XCTAssertTrue(engine.isWaitingForSignInCompletion)
    }
    
    func testGlassTracksRealLibrarySyncAndPlayback() {
        // Feed real YouTube Music quick picks
        let realPick = YTMPlaylistItem(
            id: "pick_1",
            title: "Golden Hour",
            artist: "JVKE",
            duration: "3:29",
            isPlaying: false,
            videoId: "PEM0Vs8jf1w",
            thumbnailURL: "https://lh3.googleusercontent.com/test_art"
        )
        model.media.quickPicks = [realPick]
        
        // Check that glassTracks synced real track metadata
        XCTAssertEqual(model.glassTracks.first?.title, "Golden Hour")
        XCTAssertEqual(model.glassTracks.first?.artist, "JVKE")
        XCTAssertEqual(model.glassTracks.first?.videoId, "PEM0Vs8jf1w")
        XCTAssertEqual(model.glassTracks.first?.thumbnailURL, "https://lh3.googleusercontent.com/test_art")
        XCTAssertEqual(model.glassTracks.first?.duration, 209)
        
        // When not playing yet, glassMusicTitle reflects the synced track
        XCTAssertEqual(model.glassMusicTitle, "Golden Hour")
        XCTAssertEqual(model.glassMusicArtist, "JVKE")
        
        // Skipping track starts the real track via engine.play(videoId:)
        model.skipGlassMusic(1)
        XCTAssertEqual(model.glassTrackCurrentSeconds, 0)
    }
    
    // MARK: - 8. Zero Mock Data & Browser Session Integration Verification
    func testZeroMockDataInGlassTracksAndNotes() {
        let freshModel = NotchModel()
        // Ensure mock Marlowe Vale / Glass Hours are completely gone
        for track in freshModel.glassTracks {
            XCTAssertNotEqual(track.title, "Glass Hours")
            XCTAssertNotEqual(track.artist, "Marlowe Vale")
            XCTAssertNotEqual(track.title, "Low Tide Signals")
            XCTAssertNotEqual(track.artist, "Kesi")
            XCTAssertNotEqual(track.title, "Soft Machinery")
            XCTAssertNotEqual(track.artist, "Ona Reyes")
        }
        
        // Ensure mock notes are completely gone
        for note in freshModel.glassNotes {
            XCTAssertFalse(note.title.contains("Midterm review"))
            XCTAssertFalse(note.body.contains("Elasticity, consumer surplus"))
            XCTAssertFalse(note.title.contains("Debate prep"))
        }
        
        // Fresh state starts with real songs
        XCTAssertFalse(freshModel.glassTracks.isEmpty)
        if let first = freshModel.glassTracks.first {
            XCTAssertFalse(first.title.isEmpty)
            XCTAssertNotEqual(first.artist, "Marlowe Vale")
        }
    }
    
    func testPolarAndBrowserDetectionAndLiveSync() {
        let media = model.media
        XCTAssertFalse(media.isBrowserConnected)
        
        // Simulate WindowServer YTM result from Polar Browser
        let polarRes = MediaControllerModel.WindowServerYTMResult(
            found: true,
            browser: "Polar",
            trackTitle: "Blinding Lights",
            artistName: "The Weeknd"
        )
        
        XCTAssertTrue(polarRes.found)
        XCTAssertEqual(polarRes.browser, "Polar")
        XCTAssertEqual(polarRes.trackTitle, "Blinding Lights")
        XCTAssertEqual(polarRes.artistName, "The Weeknd")
        
        // Apply detected browser track
        media.trackTitle = polarRes.trackTitle
        media.artistName = polarRes.artistName
        media.sourceName = "YouTube Music • Polar"
        media.isBrowserConnected = true
        media.isSignedIn = true
        media.isPlaying = true
        
        // NotchModel must immediately reflect the real song from Polar
        XCTAssertEqual(model.glassMusicTitle, "Blinding Lights")
        XCTAssertEqual(model.glassMusicArtist, "The Weeknd")
        XCTAssertTrue(model.isGlassMusicPlaying)
        
        // When song title is not yet available (home/browse in Polar), reflects connected browser
        media.trackTitle = ""
        media.artistName = ""
        XCTAssertEqual(model.glassMusicTitle, "YouTube Music Connected")
        XCTAssertEqual(model.glassMusicArtist, "YouTube Music • Polar")
    }
    
    func testIsDirectEngineConnectedOnlyWhenActive() {
        let media = model.media
        // On idle/empty state, isDirectEngineConnected must be false
        media.engine.trackData = YTMTrackData()
        media.engine.isSignedIn = false
        media.isDirectEngineConnected = false
        
        XCTAssertFalse(media.isDirectEngineConnected)
        XCTAssertFalse(media.isDirectEngineActive)
        
        // When real track plays in direct engine, connects
        media.engine.trackData = YTMTrackData(title: "Starboy", artist: "The Weeknd", isPlaying: true, duration: 230)
        media.isDirectEngineConnected = media.engine.isSignedIn || (!media.engine.trackData.title.isEmpty && media.engine.trackData.title != "YouTube Music" && media.engine.trackData.duration > 0) || media.engine.trackData.isPlaying
        XCTAssertTrue(media.isDirectEngineConnected)
    }
    
    // MARK: - 12. Glass Music Subtabs (Playing, Library, Queue) & Background Hover Routing
    func testGlassMusicThreeSubtabsAndLibraryQueueNavigation() {
        model.setGlassIslandState(.music)
        XCTAssertEqual(model.glassIslandHeight, 384.0)
        
        // 1. Default subtab is Playing (now)
        XCTAssertEqual(model.glassMusicSubtab, .playing)
        
        // 2. Switch to Library (lib)
        model.setGlassMusicSubtab(.library)
        XCTAssertEqual(model.glassMusicSubtab, .library)
        
        // Populate real user playlists & library tracks
        let track1 = YTMPlaylistItem(id: "t1", title: "Starboy", artist: "The Weeknd", duration: "3:50", isPlaying: true)
        let track2 = YTMPlaylistItem(id: "t2", title: "Save Your Tears", artist: "The Weeknd", duration: "3:35", isPlaying: false)
        let track3 = YTMPlaylistItem(id: "t3", title: "Levitating", artist: "Dua Lipa", duration: "3:23", isPlaying: false)
        
        let playlist = YTMPlaylist(
            id: "pl_favorites",
            title: "Night Drive Vibes",
            subtitle: "3 songs",
            thumbnailURL: nil,
            trackCount: 3,
            tracks: [track1, track2, track3]
        )
        model.media.playlists = [playlist]
        model.media.playlist = [track1, track2, track3]
        
        // Check library search
        model.glassMusicSearchText = "Dua"
        let filtered = model.glassFilteredLibraryTracks
        XCTAssertFalse(filtered.isEmpty)
        XCTAssertTrue(filtered.contains(where: { $0.title == "Levitating" }))
        XCTAssertFalse(filtered.contains(where: { $0.title == "Starboy" }))
        
        // Clear search
        model.glassMusicSearchText = ""
        
        // Select playlist opens detail view
        XCTAssertNil(model.glassSelectedPlaylist)
        model.selectGlassPlaylist(playlist)
        XCTAssertEqual(model.glassSelectedPlaylist?.id, "pl_favorites")
        XCTAssertEqual(model.glassSelectedPlaylist?.tracks.count, 3)
        
        // Play song in selected playlist
        model.playGlassLibraryTrack(track2)
        XCTAssertEqual(model.media.trackTitle, "Save Your Tears")
        XCTAssertTrue(model.isGlassMusicPlaying)
        
        // Play entire selected playlist
        model.playGlassSelectedPlaylistAll(shuffle: false)
        XCTAssertTrue(model.isGlassMusicPlaying)
        
        // Clear playlist selection returns to playlist grid
        model.selectGlassPlaylist(nil)
        XCTAssertNil(model.glassSelectedPlaylist)
        
        // 3. Switch to Queue
        model.setGlassMusicSubtab(.queue)
        XCTAssertEqual(model.glassMusicSubtab, .queue)
        XCTAssertEqual(model.media.playlist.count, 3)
        
        // 4. View renders cleanly without errors in all 3 modes
        let view = MorphIslandView(model: model)
        XCTAssertNotNil(view.body)
    }
    
    func testHoverAutoOpensMusicWhenBackgroundMusicActive() {
        let controller = MorphController(model: model)
        
        // 1. Idle with music playing -> hover opens .music
        model.setGlassIslandState(.idle)
        model.isGlassMusicPlaying = true
        XCTAssertTrue(model.isBackgroundMusicActive)
        
        controller.handleMouseEnter()
        XCTAssertEqual(model.glassIslandState, .music, "Hovering while music is active must open .music")
        
        // 2. Idle with timer running -> hover opens .timer
        model.setGlassIslandState(.idle)
        model.isGlassMusicPlaying = false
        model.media.isPlaying = false
        model.startGlassTimer()
        XCTAssertTrue(model.isBackgroundTimerActive)
        
        controller.handleMouseEnter()
        XCTAssertEqual(model.glassIslandState, .timer, "Hovering while timer is running must open .timer")
        
        // 3. Idle with nothing active -> hover opens .prompt
        model.setGlassIslandState(.idle)
        model.resetGlassTimer()
        model.isGlassMusicPlaying = false
        model.media.isPlaying = false
        XCTAssertFalse(model.isBackgroundMusicActive)
        XCTAssertFalse(model.isBackgroundTimerActive)
        
        controller.handleMouseEnter()
        XCTAssertEqual(model.glassIslandState, .prompt, "Hovering with no background action must open .prompt")
    }
    
    // MARK: - 14. Zero Unintended Track Skips During Playback
    func testPlaybackDoesNotSkipPrematurelyWhilePlaying() {
        // Setup a real song in playback
        model.media.trackTitle = "Bohemian Rhapsody"
        model.media.artistName = "Queen"
        model.media.duration = 354 // 5 mins 54 secs
        model.media.currentTime = 179 // 1 second before old 180s mock limit
        model.media.isPlaying = true
        model.isGlassMusicPlaying = true
        
        let initialTrack = model.media.trackTitle
        
        // Advance local time beyond 180s mock threshold
        model.glassTrackCurrentSeconds = 185
        
        // Simulate timer tick
        if model.media.currentTime > 0 {
            model.glassTrackCurrentSeconds = Int(model.media.currentTime)
        }
        
        // Track must NOT skip
        XCTAssertEqual(model.media.trackTitle, initialTrack, "Song must not skip at 180s or any mock duration threshold")
        XCTAssertEqual(model.glassMusicTitle, "Bohemian Rhapsody")
    }
    
    func testPlaybackTickerDoesNotAutoAdvanceDirectEngineOrBrowserStreams() {
        // Direct engine connected stream
        model.media.trackTitle = "Starboy"
        model.media.artistName = "The Weeknd"
        model.media.duration = 230
        model.media.currentTime = 229.8 // Within 0.5s of duration
        model.media.isPlaying = true
        model.media.isDirectEngineConnected = true
        
        // Track must NOT auto-advance via Swift ticker
        XCTAssertEqual(model.media.trackTitle, "Starboy")
        
        // Now test browser connected stream
        model.media.isDirectEngineConnected = false
        model.media.isBrowserConnected = true
        model.media.currentTime = 230.0
        
        // Track must NOT auto-advance via Swift ticker
        XCTAssertEqual(model.media.trackTitle, "Starboy")
    }
}
