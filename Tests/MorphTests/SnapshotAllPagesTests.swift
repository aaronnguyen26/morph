import XCTest
import SwiftUI
import AppKit
@testable import morph

@MainActor
final class SnapshotAllPagesTests: XCTestCase {
    
    private let outputDir = "/Users/minhnguyen/.gemini/antigravity/brain/602273c5-1d6a-47ed-b6c3-7ea34fec9ffd/current_ui"
    
    private func renderViewToPNG(view: some View, size: CGSize, scale: CGFloat = 2.0, filename: String) {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.layoutSubtreeIfNeeded()
        
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            XCTFail("Failed to allocate bitmap representation")
            return
        }
        rep.size = size
        
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current = context
        hosting.displayIgnoringOpacity(hosting.bounds, in: context!)
        NSGraphicsContext.restoreGraphicsState()
        
        guard let data = rep.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to encode PNG data")
            return
        }
        
        let fileURL = URL(fileURLWithPath: "\(outputDir)/\(filename)")
        do {
            try data.write(to: fileURL)
            print("Successfully rendered snapshot to: \(fileURL.path)")
        } catch {
            XCTFail("Error writing PNG file: \(error)")
        }
    }
    
    func testSnapshotEveryMorphPage() throws {
        try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        
        let notchModel = NotchModel()
        notchModel.theme.setMode(.dark)
        notchModel.isExpanded = true
        
        // 1. Setup Mock Calendar Data
        let now = Date()
        let event1 = CalendarEvent(
            id: "evt-1",
            title: "Apple Design Review",
            description: "Dynamic Island Architecture Sync",
            startTime: now.addingTimeInterval(1800),
            endTime: now.addingTimeInterval(5400),
            meetLink: "https://meet.google.com/xyz-appl-des",
            location: "Virtual Room A"
        )
        let event2 = CalendarEvent(
            id: "evt-2",
            title: "Dynamic Island Architecture",
            description: "Engineering Deep Dive",
            startTime: now.addingTimeInterval(7200),
            endTime: now.addingTimeInterval(10800),
            meetLink: "https://meet.google.com/not-harch-eng",
            location: "Cupertino Main"
        )
        notchModel.calendar.events = [event1, event2]
        
        // 2. Setup Mock Pomodoro Data
        notchModel.pomodoro.timeRemaining = 1425 // 23:45
        notchModel.pomodoro.totalDuration = 1500
        notchModel.pomodoro.isRunning = true
        
        // 3. Setup Mock Music Data
        notchModel.media.trackTitle = "Midnight City"
        notchModel.media.artistName = "M83"
        notchModel.media.isPlaying = true
        notchModel.media.currentTime = 142
        notchModel.media.duration = 244
        notchModel.media.volume = 0.8
        
        // 4. Setup Mock Notes Data
        notchModel.scratchpad.text = """
        # Apple Design Sprint — Morph Island
        - [x] Streamline hardware notch clearance
        - [x] Monochromatic obsidian surface
        - [ ] Fluid spring transitions
        - [ ] AirDrop Dynamic Shelf integration
        
        Key takeaway: Restraint over decoration.
        """
        
        // 5. Setup Mock Drop Shelf Data
        let temp1 = FileManager.default.temporaryDirectory.appendingPathComponent("Interface_Mockup.png")
        let temp2 = FileManager.default.temporaryDirectory.appendingPathComponent("Architecture_Spec.pdf")
        let temp3 = FileManager.default.temporaryDirectory.appendingPathComponent("Dynamic_Island_Tokens.json")
        try? "image mock".data(using: .utf8)?.write(to: temp1)
        try? "pdf mock".data(using: .utf8)?.write(to: temp2)
        try? "json mock".data(using: .utf8)?.write(to: temp3)
        notchModel.dropShelf.stageFile(url: temp1)
        notchModel.dropShelf.stageFile(url: temp2)
        notchModel.dropShelf.stageFile(url: temp3)
        
        // 6. Setup Mock Meeting Flight Data
        notchModel.meetingController.startCall(title: "Google Meet — Spatial Design Sync")
        notchModel.meetingController.isMuted = false
        notchModel.meetingController.detectedMeetingInfo = DetectedMeetingInfo(
            isDetected: true,
            service: .googleMeet,
            title: "Google Meet — Spatial Design Sync",
            browserName: "Google Chrome",
            isInCall: true
        )
        
        // 7. Setup Mock Application Form Data
        notchModel.formTracker.setRecipientEmail("aaron.design@apple.com")
        notchModel.formTracker.startTracking(
            title: "Apple Human Interface Design Intake",
            appName: "Google Chrome",
            url: "https://docs.google.com/forms/d/e/1FAIpQLSeAppleDesignUX/viewform"
        )
        let formFields = [
            FormInputField(
                label: "What is your primary design specialization?",
                value: "Spatial & Dynamic Island UX",
                category: .experience,
                options: ["Spatial & Dynamic Island UX", "System Typography & Layout", "Interactive Prototyping", "Motion & Haptics"],
                questionType: "multipleChoice",
                isRequired: true
            ),
            FormInputField(
                label: "Portfolio URL or Figma Link",
                value: "https://apple.com/design/spatial-hud",
                category: .contact,
                questionType: "shortAnswer",
                isRequired: true
            ),
            FormInputField(
                label: "Platforms designed for:",
                value: "macOS, visionOS",
                category: .experience,
                options: ["macOS", "visionOS", "iOS", "watchOS"],
                questionType: "checkboxes",
                isRequired: false
            ),
            FormInputField(
                label: "Core design philosophy on utility surfaces:",
                value: "High contrast typography and deliberate spatial rhythm replace arbitrary bounding boxes.",
                category: .question,
                questionType: "paragraph",
                isRequired: true
            )
        ]
        notchModel.formTracker.activeSession?.fields = formFields
        notchModel.formTracker.selectActiveField(0)
        
        let islandSize = CGSize(width: 640, height: 225)
        
        // ==========================================
        // RENDER EVERY PAGE
        // ==========================================
        
        // PAGE 1: HOME
        notchModel.activeContextFeature = nil
        notchModel.selectedTab = .home
        let homeView = MorphIslandView(model: notchModel, onMouseEnter: {}, onMouseExit: {})
        renderViewToPNG(view: homeView, size: islandSize, filename: "01_page_home_current.png")
        
        // PAGE 2: FOCUS TIMER
        notchModel.activeContextFeature = nil
        notchModel.selectedTab = .timer
        let timerView = MorphIslandView(model: notchModel, onMouseEnter: {}, onMouseExit: {})
        renderViewToPNG(view: timerView, size: islandSize, filename: "02_page_focus_timer_current.png")
        
        // PAGE 3: MUSIC PLAYER
        notchModel.activeContextFeature = nil
        notchModel.selectedTab = .music
        let musicView = MorphIslandView(model: notchModel, onMouseEnter: {}, onMouseExit: {})
        renderViewToPNG(view: musicView, size: islandSize, filename: "03_page_music_current.png")
        
        // PAGE 4: NOTES / SCRATCHPAD
        notchModel.activeContextFeature = nil
        notchModel.selectedTab = .notes
        let notesView = MorphIslandView(model: notchModel, onMouseEnter: {}, onMouseExit: {})
        renderViewToPNG(view: notesView, size: islandSize, filename: "04_page_notes_current.png")
        
        // PAGE 5: CALENDAR
        notchModel.activeContextFeature = nil
        notchModel.selectedTab = .calendar
        let calendarView = MorphIslandView(model: notchModel, onMouseEnter: {}, onMouseExit: {})
        renderViewToPNG(view: calendarView, size: islandSize, filename: "05_page_calendar_current.png")
        
        // PAGE 6: PROFILE
        notchModel.activeContextFeature = nil
        notchModel.selectedTab = .profile
        let profileView = MorphIslandView(model: notchModel, onMouseEnter: {}, onMouseExit: {})
        renderViewToPNG(view: profileView, size: islandSize, filename: "06_page_profile_current.png")
        
        // PAGE 7: MEETING COCKPIT
        notchModel.activeContextFeature = .meetingFlight
        let meetingView = MorphIslandView(model: notchModel, onMouseEnter: {}, onMouseExit: {})
        renderViewToPNG(view: meetingView, size: islandSize, filename: "07_page_meeting_cockpit_current.png")
        
        // PAGE 8: DROP SHELF
        notchModel.activeContextFeature = .dropShelf
        let dropShelfView = MorphIslandView(model: notchModel, onMouseEnter: {}, onMouseExit: {})
        renderViewToPNG(view: dropShelfView, size: islandSize, filename: "08_page_drop_shelf_current.png")
        
        // PAGE 9: APPLICATION FORM TRACKER
        notchModel.activeContextFeature = .formTracker
        let formView = MorphIslandView(model: notchModel, onMouseEnter: {}, onMouseExit: {})
        renderViewToPNG(view: formView, size: islandSize, filename: "09_page_form_tracker_current.png")
        
        // BONUS / COMPACT HUD: IDLE & COMPACT NOTCH
        notchModel.activeContextFeature = nil
        notchModel.isExpanded = false
        notchModel.isHovered = false
        let compactView = MorphIslandView(model: notchModel, onMouseEnter: {}, onMouseExit: {})
        renderViewToPNG(view: compactView, size: CGSize(width: notchModel.currentWidth, height: notchModel.currentHeight), filename: "10_page_compact_notch_current.png")
        
        print("Completed rendering all 10 current page snapshots!")
        
        // ==========================================
        // RENDER APPLE DYNAMIC ISLAND REDESIGNS
        // ==========================================
        renderViewToPNG(view: AppleDynamicIslandHomeRedesign(), size: islandSize, filename: "apple_redesign_01_home.png")
        renderViewToPNG(view: AppleDynamicIslandFocusTimerRedesign(), size: islandSize, filename: "apple_redesign_02_focus_timer.png")
        renderViewToPNG(view: AppleDynamicIslandMusicRedesign(), size: islandSize, filename: "apple_redesign_03_music.png")
        renderViewToPNG(view: AppleDynamicIslandNotesRedesign(), size: islandSize, filename: "apple_redesign_04_notes.png")
        renderViewToPNG(view: AppleDynamicIslandCalendarRedesign(), size: islandSize, filename: "apple_redesign_05_calendar.png")
        renderViewToPNG(view: AppleDynamicIslandProfileRedesign(), size: islandSize, filename: "apple_redesign_06_profile.png")
        renderViewToPNG(view: AppleDynamicIslandMeetingCockpitRedesign(), size: islandSize, filename: "apple_redesign_07_meeting_cockpit.png")
        renderViewToPNG(view: AppleDynamicIslandDropShelfRedesign(), size: islandSize, filename: "apple_redesign_08_drop_shelf.png")
        renderViewToPNG(view: AppleDynamicIslandFormTrackerRedesign(), size: islandSize, filename: "apple_redesign_09_form_tracker.png")
        renderViewToPNG(view: AppleDynamicIslandCompactHUD(), size: islandSize, filename: "apple_redesign_10_compact_hud.png")
        
        // RENDER INDIVIDUAL COMPACT FLOATING DYNAMIC ISLAND PILLS
        renderViewToPNG(view: AppleCompactPillHome(), size: CGSize(width: 280, height: 36), filename: "apple_pill_01_home.png")
        renderViewToPNG(view: AppleCompactPillTimer(), size: CGSize(width: 240, height: 36), filename: "apple_pill_02_timer.png")
        renderViewToPNG(view: AppleCompactPillMusic(), size: CGSize(width: 240, height: 36), filename: "apple_pill_03_music.png")
        renderViewToPNG(view: AppleCompactPillNotes(), size: CGSize(width: 240, height: 36), filename: "apple_pill_04_notes.png")
        renderViewToPNG(view: AppleCompactPillCalendar(), size: CGSize(width: 250, height: 36), filename: "apple_pill_05_calendar.png")
        renderViewToPNG(view: AppleCompactPillProfile(), size: CGSize(width: 240, height: 36), filename: "apple_pill_06_profile.png")
        renderViewToPNG(view: AppleCompactPillMeeting(), size: CGSize(width: 240, height: 36), filename: "apple_pill_07_meeting.png")
        renderViewToPNG(view: AppleCompactPillDropShelf(), size: CGSize(width: 250, height: 36), filename: "apple_pill_08_dropshelf.png")
        renderViewToPNG(view: AppleCompactPillForm(), size: CGSize(width: 240, height: 36), filename: "apple_pill_09_form.png")
        
        print("Completed rendering all 10 Apple Dynamic Island redesigns & compact pills!")
    }
}
