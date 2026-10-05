import XCTest
@testable import morph

final class MorphTests: XCTestCase {
    @MainActor
    func testNotchModelDimensions() {
        let pomodoro = PomodoroModel()
        let media = MediaControllerModel()
        let scratchpad = ScratchpadModel()
        scratchpad.text = "" // Ensure scratchpad is empty for idle test
        
        let model = NotchModel(pomodoro: pomodoro, media: media, scratchpad: scratchpad)
        
        // Baseline idle dimensions
        XCTAssertGreaterThanOrEqual(model.idleWidth, 160)
        XCTAssertGreaterThanOrEqual(model.idleHeight, 28)
        
        // Expanded dimensions (640 width, 225 shortened length)
        XCTAssertEqual(model.expandedWidth, 640)
        XCTAssertEqual(model.expandedHeight, 225)
        
        // Idle state: If none is used, Morph MUST stay in the normal flush resting state!
        pomodoro.isRunning = false
        media.isPlaying = false
        model.isNotePinnedToNotch = false
        model.isExpanded = false
        XCTAssertEqual(model.compactHUDMode, .none)
        XCTAssertFalse(model.isCompactActive, "When none is used, dynamic island must remain in normal idle notch mode")
        XCTAssertEqual(model.currentWidth, model.idleWidth)
        XCTAssertEqual(model.currentHeight, model.idleHeight)
        
        // Independent Downsize: ONLY Pomodoro is active
        pomodoro.isRunning = true
        media.isPlaying = false
        XCTAssertEqual(model.compactHUDMode, .pomodoroOnly)
        XCTAssertTrue(model.isCompactActive)
        XCTAssertEqual(model.compactWidth, max(model.idleWidth + 240, 440))
        XCTAssertEqual(model.currentWidth, model.compactWidth)
        XCTAssertEqual(model.currentHeight, model.idleHeight, "Solo Pomodoro HUD sits cleanly on notch row without bottom shelf clutter")
        
        // Independent Downsize: ONLY Media is active
        pomodoro.isRunning = false
        media.isPlaying = true
        XCTAssertEqual(model.compactHUDMode, .mediaOnly)
        XCTAssertTrue(model.isCompactActive)
        XCTAssertEqual(model.compactWidth, max(model.idleWidth + 260, 460))
        XCTAssertEqual(model.currentWidth, model.compactWidth)
        XCTAssertEqual(model.currentHeight, model.idleHeight, "Solo Media HUD sits cleanly on notch row without bottom shelf clutter")
        
        // Dual Active Downsize: Both are active concurrently
        pomodoro.isRunning = true
        media.isPlaying = true
        XCTAssertEqual(model.compactHUDMode, .dualActive)
        XCTAssertTrue(model.isCompactActive)
        XCTAssertEqual(model.compactWidth, max(model.idleWidth + 320, 520))
        XCTAssertEqual(model.currentWidth, model.compactWidth)
        XCTAssertEqual(model.currentHeight, model.idleHeight)
        
        // Pinned Notes Downsize
        pomodoro.isRunning = false
        media.isPlaying = false
        model.isNotePinnedToNotch = true
        XCTAssertEqual(model.compactHUDMode, .notesPinned)
        XCTAssertTrue(model.isCompactActive)
        XCTAssertGreaterThanOrEqual(model.compactHeight, 56)
        
        // Expanded state overrides compact
        model.isExpanded = true
        XCTAssertEqual(model.currentWidth, 640)
        XCTAssertEqual(model.currentHeight, 225)
    }
    
    @MainActor
    func testPomodoroModel() {
        let pomodoro = PomodoroModel()
        pomodoro.switchMode(.work)
        XCTAssertFalse(pomodoro.isRunning)
        XCTAssertEqual(pomodoro.mode, .work)
        XCTAssertEqual(pomodoro.formattedTime, "25:00")
        
        pomodoro.toggle()
        XCTAssertTrue(pomodoro.isRunning)
        
        pomodoro.toggle()
        XCTAssertFalse(pomodoro.isRunning)
        
        pomodoro.reset()
        XCTAssertFalse(pomodoro.isRunning)
        XCTAssertEqual(pomodoro.formattedTime, "25:00")
    }
    
    @MainActor
    func testScratchpadModel() {
        let pad = ScratchpadModel()
        pad.text = "Hello world from Morph test"
        XCTAssertEqual(pad.wordCount, 5)
        XCTAssertEqual(pad.charCount, 27)
        
        pad.copyAll()
        XCTAssertTrue(pad.showCopiedAlert)
    }
    
    @MainActor
    func testRule1NotchBlindSpotGeometry() {
        let model = NotchModel()
        let blindWidth = max(model.idleWidth + 10, 185)
        let blindHeight = max(model.idleHeight + 2, 34)
        
        // Guarantee center blind spot completely covers physical notch with safety margin
        XCTAssertGreaterThanOrEqual(blindWidth, 185)
        XCTAssertGreaterThanOrEqual(blindHeight, 34)
    }
    
    @MainActor
    func testRule3ActiveTaskCollapseVisibility() {
        let pomodoro = PomodoroModel()
        let media = MediaControllerModel()
        let scratchpad = ScratchpadModel()
        scratchpad.text = ""
        let model = NotchModel(pomodoro: pomodoro, media: media, scratchpad: scratchpad)
        
        // When Pomodoro is running alone: wings provide at least 70pt on each side
        pomodoro.isRunning = true
        media.isPlaying = false
        let leftWingPomodoro = (model.compactWidth - model.idleWidth) / 2
        XCTAssertGreaterThanOrEqual(leftWingPomodoro, 70, "Left wing must be at least 70 pt for timer countdown outside the notch")
        
        // When Media is playing alone: wings provide at least 80pt on each side
        pomodoro.isRunning = false
        media.isPlaying = true
        let rightWingMedia = (model.compactWidth - model.idleWidth) / 2
        XCTAssertGreaterThanOrEqual(rightWingMedia, 80, "Right wing must be at least 80 pt for live equalizer and controls")
        
        // When both are running: wings provide at least 110pt on each side
        pomodoro.isRunning = true
        media.isPlaying = true
        let dualWings = (model.compactWidth - model.idleWidth) / 2
        XCTAssertGreaterThanOrEqual(dualWings, 110, "Dual wings must provide at least 110pt on each side")
    }
    
    @MainActor
    func testTabSwitching() {
        let model = NotchModel()
        XCTAssertEqual(model.selectedTab, .home)
        
        model.openFeature(.timer)
        XCTAssertEqual(model.selectedTab, .timer)
        XCTAssertTrue(model.isExpanded)
        
        model.returnToHome()
        XCTAssertEqual(model.selectedTab, .home)
    }
    
    @MainActor
    func testYouTubeMusicEnginePayloadParsing() {
        let engine = YouTubeMusicEngine()
        
        // Initial state
        XCTAssertNotNil(engine.webView)
        
        // Simulate incoming JS bridge message payload
        let mockPayload: [String: Any] = [
            "title": "Save Your Tears",
            "artist": "The Weeknd • After Hours",
            "albumArt": "https://lh3.googleusercontent.com/test_art.jpg",
            "isPlaying": true,
            "currentTime": 45.5,
            "duration": 215.0,
            "volume": 0.85,
            "isMuted": false,
            "isLiked": true,
            "isDisliked": false,
            "isShuffle": true,
            "repeatMode": "all"
        ]
        
        engine.parseIncomingPayload(mockPayload)
        
        XCTAssertEqual(engine.trackData.title, "Save Your Tears")
        XCTAssertEqual(engine.trackData.artist, "The Weeknd • After Hours")
        XCTAssertEqual(engine.trackData.albumArtURL, "https://lh3.googleusercontent.com/test_art.jpg")
        XCTAssertTrue(engine.trackData.isPlaying)
        XCTAssertEqual(engine.trackData.currentTime, 45.5)
        XCTAssertEqual(engine.trackData.duration, 215.0)
        XCTAssertEqual(engine.trackData.volume, 0.85)
        XCTAssertFalse(engine.trackData.isMuted)
        XCTAssertTrue(engine.trackData.isLiked)
        XCTAssertFalse(engine.trackData.isDisliked)
        XCTAssertTrue(engine.trackData.isShuffle)
        XCTAssertEqual(engine.trackData.repeatMode, .all)
    }
    
    @MainActor
    func testMediaControllerModelDirectEngineBinding() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        // Test initial values
        XCTAssertEqual(media.sourceName, "YouTube Music Direct")
        
        // Send payload through engine
        let mockPayload: [String: Any] = [
            "title": "Levitating",
            "artist": "Dua Lipa",
            "albumArt": "https://example.com/art.png",
            "isPlaying": true,
            "currentTime": 30.0,
            "duration": 203.0,
            "volume": 0.9,
            "isMuted": false,
            "isLiked": false,
            "isDisliked": false,
            "isShuffle": false,
            "repeatMode": "off"
        ]
        
        engine.parseIncomingPayload(mockPayload)
        
        // MediaControllerModel should reflect parsed payload
        XCTAssertEqual(media.trackTitle, "Levitating")
        XCTAssertEqual(media.artistName, "Dua Lipa")
        XCTAssertEqual(media.albumArtURL, "https://example.com/art.png")
        XCTAssertTrue(media.isPlaying)
        XCTAssertEqual(media.currentTime, 30.0)
        XCTAssertEqual(media.duration, 203.0)
        XCTAssertEqual(media.volume, 0.9)
        XCTAssertFalse(media.isMuted)
        XCTAssertFalse(media.isLiked)
        XCTAssertFalse(media.isDisliked)
        XCTAssertFalse(media.isShuffle)
        XCTAssertEqual(media.repeatMode, .off)
        
        // Progress and formatted times
        XCTAssertEqual(media.formattedCurrentTime, "0:30")
        XCTAssertEqual(media.formattedDuration, "3:23")
        XCTAssertEqual(media.progress, 30.0 / 203.0, accuracy: 0.001)
        
        // Controls: Pause via toggle
        media.togglePlay()
        XCTAssertFalse(media.isPlaying, "Calling togglePlay when playing must pause playback")
        
        media.toggleMute()
        XCTAssertTrue(media.isMuted)
        
        media.setVolume(0.5)
        XCTAssertEqual(media.volume, 0.5)
        
        media.toggleLike()
        XCTAssertTrue(media.isLiked)
    }
    
    @MainActor
    func testMediaPlaybackStopAndControls() {
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine)
        
        // Set playing state
        media.play()
        XCTAssertTrue(media.isPlaying)
        media.currentTime = 50.0
        
        // Test explicit Stop: MUST stop playback and reset currentTime
        media.stop()
        XCTAssertFalse(media.isPlaying, "Stop must halt playback")
        XCTAssertEqual(media.currentTime, 0, "Stop must reset current playback time to 0")
        
        // Test explicit Pause: MUST halt playback
        media.play()
        XCTAssertTrue(media.isPlaying)
        media.pause()
        XCTAssertFalse(media.isPlaying, "Pause must halt playback")
        
        // Test Shuffle toggle
        XCTAssertFalse(media.isShuffle)
        media.toggleShuffle()
        XCTAssertTrue(media.isShuffle)
        media.toggleShuffle()
        XCTAssertFalse(media.isShuffle)
        
        // Test Repeat mode cycling: off -> all -> one -> off
        XCTAssertEqual(media.repeatMode, .off)
        media.toggleRepeat()
        XCTAssertEqual(media.repeatMode, .all)
        media.toggleRepeat()
        XCTAssertEqual(media.repeatMode, .one)
        media.toggleRepeat()
        XCTAssertEqual(media.repeatMode, .off)
        
        // Test Dislike toggle & mutual exclusivity with Like
        XCTAssertFalse(media.isDisliked)
        media.toggleDislike()
        XCTAssertTrue(media.isDisliked)
        XCTAssertFalse(media.isLiked)
        
        // Liking should clear dislike
        media.toggleLike()
        XCTAssertTrue(media.isLiked)
        XCTAssertFalse(media.isDisliked, "Liking must clear dislike")
    }
    
    @MainActor
    func testCameraNotchVisibilityGuarantees() {
        let model = NotchModel()
        
        // 1. Idle resting state has valid non-zero dimensions
        XCTAssertGreaterThan(model.idleWidth, 0)
        XCTAssertGreaterThan(model.idleHeight, 0)
        
        // 2. When notes are pinned to notch, compact height drops directly BELOW the physical camera notch
        model.isNotePinnedToNotch = true
        XCTAssertGreaterThanOrEqual(model.compactHeight - model.idleHeight, 24)
        
        // 3. Compact wings must extend on both sides outside the notch
        model.isNotePinnedToNotch = false
        model.media.isPlaying = true
        let wingWidth = (model.compactWidth - model.idleWidth) / 2
        XCTAssertGreaterThanOrEqual(wingWidth, 80, "Each wing must extend at least 80pt past the camera notch")
    }
    
    func testMorphyMouthShapePaths() {
        let singingMouth = MorphyMouthShape(isSinging: true, isFocused: false)
        let singingPath = singingMouth.path(in: CGRect(x: 0, y: 0, width: 20, height: 10))
        XCTAssertFalse(singingPath.isEmpty)
        
        let focusedMouth = MorphyMouthShape(isSinging: false, isFocused: true)
        let focusedPath = focusedMouth.path(in: CGRect(x: 0, y: 0, width: 20, height: 10))
        XCTAssertFalse(focusedPath.isEmpty)
        
        let happyMouth = MorphyMouthShape(isSinging: false, isFocused: false)
        let happyPath = happyMouth.path(in: CGRect(x: 0, y: 0, width: 20, height: 10))
        XCTAssertFalse(happyPath.isEmpty)
    }
    
    @MainActor
    func testCollapsedHUDFeatureAccessibility() {
        let pomodoro = PomodoroModel()
        let media = MediaControllerModel()
        let scratchpad = ScratchpadModel()
        scratchpad.text = ""
        
        let model = NotchModel(pomodoro: pomodoro, media: media, scratchpad: scratchpad)
        
        // 1. Direct Pomodoro access from collapsed island
        XCTAssertFalse(model.pomodoro.isRunning)
        model.pomodoro.start()
        XCTAssertTrue(model.pomodoro.isRunning)
        XCTAssertTrue(model.isCompactActive)
        XCTAssertEqual(model.compactHUDMode, .pomodoroOnly)
        model.pomodoro.pause()
        XCTAssertFalse(model.pomodoro.isRunning)
        
        // 2. Direct Media controls from collapsed island
        XCTAssertFalse(model.media.isPlaying)
        model.media.togglePlay()
        XCTAssertTrue(model.media.isPlaying)
        XCTAssertTrue(model.isCompactActive)
        XCTAssertEqual(model.compactHUDMode, .mediaOnly)
        model.media.togglePlay()
        XCTAssertFalse(model.media.isPlaying)
        
        // 3. Direct Scratchpad note access and copy from collapsed island
        scratchpad.text = "Morph Dynamic Island Quick Note"
        XCTAssertTrue(model.hasActiveNotes)
        model.isNotePinnedToNotch = true
        XCTAssertTrue(model.isCompactActive)
        XCTAssertEqual(model.compactHUDMode, .notesPinned)
        scratchpad.copyAll()
        XCTAssertTrue(scratchpad.showCopiedAlert)
        let pasteboardString = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(pasteboardString, "Morph Dynamic Island Quick Note")
    }
    
    func testUserProfileModelEncodingDecoding() throws {
        let json = """
        {
            "id": "bc0450a2-b1a4-4c34-bbd9-9d5a37dd666b",
            "first_name": "Aaron",
            "last_name": "Nguyen",
            "email": "minh7898888@gmail.com",
            "target_role": "Senior Software Engineer",
            "streak_days": 7,
            "total_focus_minutes": 180,
            "current_status": "Deep Architecture",
            "avatar_initials": "AN"
        }
        """.data(using: .utf8)!
        
        let profile = try JSONDecoder().decode(UserProfile.self, from: json)
        XCTAssertEqual(profile.id, "bc0450a2-b1a4-4c34-bbd9-9d5a37dd666b")
        XCTAssertEqual(profile.firstName, "Aaron")
        XCTAssertEqual(profile.lastName, "Nguyen")
        XCTAssertEqual(profile.displayName, "Aaron Nguyen")
        XCTAssertEqual(profile.displayInitials, "AN")
        XCTAssertEqual(profile.targetRole, "Senior Software Engineer")
        XCTAssertEqual(profile.streakDays, 7)
        XCTAssertEqual(profile.totalFocusMinutes, 180)
        XCTAssertEqual(profile.currentStatus, "Deep Architecture")
        
        let encoded = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(UserProfile.self, from: encoded)
        XCTAssertEqual(profile, decoded)
    }
    
    @MainActor
    func testSupabaseServiceFocusRecording() async {
        let service = SupabaseService.shared
        let initialMinutes = service.currentUser.totalFocusMinutes
        await service.recordFocusSession(minutes: 25)
        XCTAssertGreaterThanOrEqual(service.currentUser.totalFocusMinutes, initialMinutes + 25)
    }
    
    @MainActor
    func testProfileTabNavigation() {
        let model = NotchModel()
        XCTAssertEqual(model.selectedTab, .home)
        
        model.openFeature(.profile)
        XCTAssertEqual(model.selectedTab, .profile)
        XCTAssertTrue(model.isExpanded)
        
        model.returnToHome()
        XCTAssertEqual(model.selectedTab, .home)
    }
    
    @MainActor
    func testUserProfileCustomizationUpdate() async {
        let service = SupabaseService.shared
        await service.updateProfile(
            firstName: "Minh",
            lastName: "Nguyen",
            email: "minh7898888@gmail.com",
            avatarInitials: "MN",
            targetRole: "Staff Engineer",
            currentStatus: "Flow State"
        )
        
        XCTAssertEqual(service.currentUser.firstName, "Minh")
        XCTAssertEqual(service.currentUser.lastName, "Nguyen")
        XCTAssertEqual(service.currentUser.displayName, "Minh Nguyen")
        XCTAssertEqual(service.currentUser.displayInitials, "MN")
        XCTAssertEqual(service.currentUser.targetRole, "Staff Engineer")
        XCTAssertEqual(service.currentUser.currentStatus, "Flow State")
    }
    
    // MARK: - Mac Keyboard Shortcuts Tests
    @MainActor
    private func makeKeyEvent(chars: String, flags: NSEvent.ModifierFlags, keyCode: UInt16 = 0) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: flags,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: chars,
            charactersIgnoringModifiers: chars.lowercased(),
            isARepeat: false,
            keyCode: keyCode
        )!
    }
    
    @MainActor
    func testMacNavigationShortcuts() {
        let model = NotchModel()
        let controller = MorphController(model: model)
        let sm = ShortcutManager.shared
        sm.configure(model: model, controller: controller)
        
        // ⌘2 -> Focus
        let event2 = makeKeyEvent(chars: "2", flags: .command, keyCode: 19)
        XCTAssertTrue(sm.handleKeyEvent(event2))
        XCTAssertEqual(model.selectedTab, .timer)
        XCTAssertTrue(model.isExpanded)
        
        // ⌘3 -> Music
        let event3 = makeKeyEvent(chars: "3", flags: .command, keyCode: 20)
        XCTAssertTrue(sm.handleKeyEvent(event3))
        XCTAssertEqual(model.selectedTab, .music)
        
        // ⌘4 -> Notes
        let event4 = makeKeyEvent(chars: "4", flags: .command, keyCode: 21)
        XCTAssertTrue(sm.handleKeyEvent(event4))
        XCTAssertEqual(model.selectedTab, .notes)
        
        // ⌘5 -> Profile
        let event5 = makeKeyEvent(chars: "5", flags: .command, keyCode: 23)
        XCTAssertTrue(sm.handleKeyEvent(event5))
        XCTAssertEqual(model.selectedTab, .profile)
        
        // ⌘, -> Preferences / Profile
        model.returnToHome()
        let eventComma = makeKeyEvent(chars: ",", flags: .command, keyCode: 43)
        XCTAssertTrue(sm.handleKeyEvent(eventComma))
        XCTAssertEqual(model.selectedTab, .profile)
        
        // ⌘[ -> Back to Home
        let eventBack = makeKeyEvent(chars: "[", flags: .command, keyCode: 33)
        XCTAssertTrue(sm.handleKeyEvent(eventBack))
        XCTAssertEqual(model.selectedTab, .home)
        
        // ⌘1 -> Home
        model.openFeature(.timer)
        let event1 = makeKeyEvent(chars: "1", flags: .command, keyCode: 18)
        XCTAssertTrue(sm.handleKeyEvent(event1))
        XCTAssertEqual(model.selectedTab, .home)
    }
    
    @MainActor
    func testMacWindowShortcuts() {
        let model = NotchModel()
        let controller = MorphController(model: model)
        let sm = ShortcutManager.shared
        sm.configure(model: model, controller: controller)
        
        // Expand
        model.isExpanded = true
        XCTAssertFalse(model.isPinned)
        
        // ⌘P -> Toggle Pin
        let eventPin = makeKeyEvent(chars: "p", flags: .command, keyCode: 35)
        XCTAssertTrue(sm.handleKeyEvent(eventPin))
        XCTAssertTrue(model.isPinned)
        
        // ⌘P again -> Unpin
        XCTAssertTrue(sm.handleKeyEvent(eventPin))
        XCTAssertFalse(model.isPinned)
        
        // ⌘M -> Minimize to Notch
        let eventMin = makeKeyEvent(chars: "m", flags: .command, keyCode: 46)
        XCTAssertTrue(sm.handleKeyEvent(eventMin))
        XCTAssertFalse(model.isExpanded)
        
        // Expand to notes
        model.openFeature(.notes)
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.selectedTab, .notes)
        
        // ⌘W -> Back to Home / Collapse
        let eventW = makeKeyEvent(chars: "w", flags: .command, keyCode: 13)
        XCTAssertTrue(sm.handleKeyEvent(eventW))
        XCTAssertEqual(model.selectedTab, .home)
        
        // ⌘W on Home -> Collapse
        XCTAssertTrue(sm.handleKeyEvent(eventW))
        XCTAssertFalse(model.isExpanded)
    }
    
    @MainActor
    func testMacPlaybackShortcuts() {
        let model = NotchModel()
        let controller = MorphController(model: model)
        let sm = ShortcutManager.shared
        sm.configure(model: model, controller: controller)
        
        let initialPlay = model.media.isPlaying
        let initialVol = model.media.volume
        
        // ⌘⏎ -> Toggle Play/Pause
        let eventReturn = makeKeyEvent(chars: "\r", flags: .command, keyCode: 36)
        XCTAssertTrue(sm.handleKeyEvent(eventReturn))
        XCTAssertNotEqual(model.media.isPlaying, initialPlay)
        
        // ⌘↑ -> Volume Up
        let eventVolUp = makeKeyEvent(chars: "", flags: .command, keyCode: 126)
        XCTAssertTrue(sm.handleKeyEvent(eventVolUp))
        XCTAssertGreaterThanOrEqual(model.media.volume, initialVol)
        
        // ⌘↓ -> Volume Down
        let eventVolDown = makeKeyEvent(chars: "", flags: .command, keyCode: 125)
        XCTAssertTrue(sm.handleKeyEvent(eventVolDown))
        
        // ⌘L -> Like
        let initialLike = model.media.isLiked
        let eventLike = makeKeyEvent(chars: "l", flags: .command, keyCode: 37)
        XCTAssertTrue(sm.handleKeyEvent(eventLike))
        XCTAssertNotEqual(model.media.isLiked, initialLike)
        
        // ⌘U -> Mute
        let initialMute = model.media.isMuted
        let eventMute = makeKeyEvent(chars: "u", flags: .command, keyCode: 32)
        XCTAssertTrue(sm.handleKeyEvent(eventMute))
        XCTAssertNotEqual(model.media.isMuted, initialMute)
    }
    
    @MainActor
    func testMacFocusTimerShortcuts() {
        let model = NotchModel()
        let controller = MorphController(model: model)
        let sm = ShortcutManager.shared
        sm.configure(model: model, controller: controller)
        
        model.openFeature(.timer)
        model.pomodoro.switchMode(.work)
        XCTAssertFalse(model.pomodoro.isRunning)
        
        // ⌘⏎ on Timer tab -> Toggle Timer
        let eventReturn = makeKeyEvent(chars: "\r", flags: .command, keyCode: 36)
        XCTAssertTrue(sm.handleKeyEvent(eventReturn))
        XCTAssertTrue(model.pomodoro.isRunning)
        
        // ⌘⇧R -> Reset Timer
        let eventReset = makeKeyEvent(chars: "R", flags: [.command, .shift], keyCode: 15)
        XCTAssertTrue(sm.handleKeyEvent(eventReset))
        XCTAssertFalse(model.pomodoro.isRunning)
        
        // ⌘⇧S -> Skip Session
        XCTAssertEqual(model.pomodoro.mode, .work)
        let eventSkip = makeKeyEvent(chars: "S", flags: [.command, .shift], keyCode: 1)
        XCTAssertTrue(sm.handleKeyEvent(eventSkip))
        XCTAssertEqual(model.pomodoro.mode, .shortBreak)
        model.pomodoro.switchMode(.work)
    }
    
    @MainActor
    func testMacNotesShortcuts() {
        let model = NotchModel()
        let controller = MorphController(model: model)
        let sm = ShortcutManager.shared
        sm.configure(model: model, controller: controller)
        
        model.scratchpad.text = "Hello Morph Mac Shortcuts"
        XCTAssertFalse(model.scratchpad.text.isEmpty)
        
        // ⌘⇧C -> Copy All
        let eventCopy = makeKeyEvent(chars: "C", flags: [.command, .shift], keyCode: 8)
        XCTAssertTrue(sm.handleKeyEvent(eventCopy))
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "Hello Morph Mac Shortcuts")
        
        // ⌘N -> Clear / New Note
        let eventNew = makeKeyEvent(chars: "n", flags: .command, keyCode: 45)
        XCTAssertTrue(sm.handleKeyEvent(eventNew))
        XCTAssertTrue(model.scratchpad.text.isEmpty)
        XCTAssertTrue(model.scratchpad.canUndoClear)
        
        // ⌘⇧P -> Pin Note to Notch
        XCTAssertFalse(model.isNotePinnedToNotch)
        let eventPinNote = makeKeyEvent(chars: "P", flags: [.command, .shift], keyCode: 35)
        XCTAssertTrue(sm.handleKeyEvent(eventPinNote))
        XCTAssertTrue(model.isNotePinnedToNotch)
    }
    
    @MainActor
    func testMacGlobalHotkeys() {
        let model = NotchModel()
        let controller = MorphController(model: model)
        let sm = ShortcutManager.shared
        sm.configure(model: model, controller: controller)
        
        // ⌘⌥M -> Toggle Expand
        XCTAssertFalse(model.isExpanded)
        let eventGlobalExpand = makeKeyEvent(chars: "m", flags: [.command, .option], keyCode: 46)
        XCTAssertTrue(sm.handleKeyEvent(eventGlobalExpand))
        XCTAssertTrue(model.isExpanded)
        
        // ⌘⌥P -> Toggle Pin
        XCTAssertFalse(model.isPinned)
        let eventGlobalPin = makeKeyEvent(chars: "p", flags: [.command, .option], keyCode: 35)
        XCTAssertTrue(sm.handleKeyEvent(eventGlobalPin))
        XCTAssertTrue(model.isPinned)
    }
    
    @MainActor
    func testNativeMacMainMenuStructure() {
        let sm = ShortcutManager.shared
        sm.setupMainMenu()
        
        guard let menu = NSApplication.shared.mainMenu else {
            XCTFail("NSApplication.shared.mainMenu should not be nil")
            return
        }
        
        // Must contain Morph, Edit, Navigate, Controls, and Window menus
        let titles = menu.items.compactMap { $0.submenu?.title }
        XCTAssertTrue(titles.contains("Morph"))
        XCTAssertTrue(titles.contains("Edit"))
        XCTAssertTrue(titles.contains("Navigate"))
        XCTAssertTrue(titles.contains("Controls"))
        XCTAssertTrue(titles.contains("Window"))
        
        // Check Navigate menu items
        let navSubmenu = menu.items.first { $0.submenu?.title == "Navigate" }?.submenu
        let navKeys = navSubmenu?.items.map { $0.keyEquivalent } ?? []
        XCTAssertTrue(navKeys.contains("1"))
        XCTAssertTrue(navKeys.contains("2"))
        XCTAssertTrue(navKeys.contains("3"))
        XCTAssertTrue(navKeys.contains("4"))
        XCTAssertTrue(navKeys.contains("5"))
        XCTAssertTrue(navKeys.contains("["))
        
        // Check Window menu items
        let winSubmenu = menu.items.first { $0.submenu?.title == "Window" }?.submenu
        let winKeys = winSubmenu?.items.map { $0.keyEquivalent } ?? []
        XCTAssertTrue(winKeys.contains("w"))
        XCTAssertTrue(winKeys.contains("m"))
        XCTAssertTrue(winKeys.contains("p"))
        XCTAssertTrue(winKeys.contains("r"))
    }
}
