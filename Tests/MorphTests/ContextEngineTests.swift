import XCTest
import Combine
@testable import morph

@MainActor
final class ContextEngineTests: XCTestCase {
    
    // MARK: - 1. DropShelfModel Tests
    
    func testDropShelfStagingAndManagement() {
        let model = DropShelfModel()
        XCTAssertFalse(model.hasItems)
        XCTAssertEqual(model.count, 0)
        XCTAssertFalse(model.isDraggingOverNotch)
        
        let tempURL1 = URL(fileURLWithPath: "/tmp/morph_test_1.txt")
        let tempURL2 = URL(fileURLWithPath: "/tmp/morph_test_2.pdf")
        
        // Stage single file
        let item1 = model.stageFile(url: tempURL1)
        XCTAssertTrue(model.hasItems)
        XCTAssertEqual(model.count, 1)
        XCTAssertEqual(item1.name, "morph_test_1.txt")
        XCTAssertEqual(item1.pathExtension, "TXT")
        
        // Staging duplicate file does not duplicate
        let item1Duplicate = model.stageFile(url: tempURL1)
        XCTAssertEqual(item1Duplicate.id, item1.id)
        XCTAssertEqual(model.count, 1)
        
        // Stage multiple files
        model.stageFiles(urls: [tempURL1, tempURL2])
        XCTAssertEqual(model.count, 2)
        
        // Dragging state
        model.isDraggingOverNotch = true
        XCTAssertTrue(model.isDraggingOverNotch)
        model.isDraggingOverNotch = false
        XCTAssertFalse(model.isDraggingOverNotch)
        
        // Copy path actions
        model.copyFilePath(item: item1)
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), tempURL1.path)
        XCTAssertNotNil(model.lastActionMessage)
        
        model.copyAllFilePaths()
        let expectedAllPaths = "\(tempURL1.path)\n\(tempURL2.path)"
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), expectedAllPaths)
        
        // Remove item by ID
        model.removeItem(id: item1.id)
        XCTAssertEqual(model.count, 1)
        
        // Clear all
        model.clearAll()
        XCTAssertFalse(model.hasItems)
        XCTAssertEqual(model.count, 0)
    }
    
    func testDropShelfItemFormatting() {
        let url = URL(fileURLWithPath: "/tmp/test.png")
        let item = DropShelfItem(url: url, fileSize: 1048576) // 1 MB
        XCTAssertEqual(item.name, "test.png")
        XCTAssertFalse(item.formattedSize.isEmpty)
        XCTAssertEqual(item.pathExtension, "PNG")
    }
    
    // MARK: - 2. MeetingFlightControllerModel Tests
    
    struct MockMeetingDetector: MeetingAppDetector {
        var running: Bool
        var name: String?
        func detectRunningMeetingApp() -> (isRunning: Bool, appName: String?) {
            return (running, name)
        }
    }
    
    func testMeetingFlightControllerUpcomingMeetingDetection() {
        let mockDetector = MockMeetingDetector(running: false, name: nil)
        var openedURLs = [URL]()
        let controller = MeetingFlightControllerModel(detector: mockDetector) { url in
            openedURLs.append(url)
            return true
        }
        
        let now = Date()
        
        // Event 1: Starting in 4 minutes with Google Meet link (within 10-min and 5-min pre-meeting window)
        let meetEvent = CalendarEvent(
            id: "call-1",
            title: "Sprint Standup",
            startTime: now.addingTimeInterval(240), // 4 mins
            endTime: now.addingTimeInterval(2040),
            meetLink: "https://meet.google.com/abc-defg-hij"
        )
        
        // Event 2: Starting in 45 minutes
        let farEvent = CalendarEvent(
            id: "call-2",
            title: "Later Call",
            startTime: now.addingTimeInterval(2700),
            endTime: now.addingTimeInterval(4500),
            meetLink: "https://zoom.us/j/123456789"
        )
        
        controller.updateFromCalendar(events: [meetEvent, farEvent], now: now)
        
        XCTAssertNotNil(controller.upcomingMeeting)
        XCTAssertEqual(controller.upcomingMeeting?.title, "Sprint Standup")
        XCTAssertTrue(controller.isPreMeetingWindow, "Event starting in 4 minutes should trigger 5-min pre-meeting window")
        
        // Join meeting
        let opened = controller.openMeetLink()
        XCTAssertTrue(opened)
        XCTAssertEqual(openedURLs.count, 1)
        XCTAssertEqual(openedURLs.first?.absoluteString, "https://meet.google.com/abc-defg-hij")
        XCTAssertTrue(controller.isInCall)
        XCTAssertEqual(controller.activeCallTitle, "Sprint Standup")
        
        // Timer ticking
        controller.tickCallTimer(seconds: 65)
        XCTAssertEqual(controller.formattedCallDuration, "01:05")
        
        // Mute toggle
        XCTAssertFalse(controller.isMuted)
        controller.toggleMute()
        XCTAssertTrue(controller.isMuted)
        
        // Quick notes binding to scratchpad
        let scratchpad = ScratchpadModel()
        scratchpad.clear()
        controller.quickNotes = "Discussed Q4 roadmap items."
        controller.appendNoteToScratchpad(scratchpad)
        XCTAssertTrue(scratchpad.text.contains("Sprint Standup"))
        XCTAssertTrue(scratchpad.text.contains("Discussed Q4 roadmap items."))
        XCTAssertEqual(controller.quickNotes, "")
        
        // End call
        controller.endCall()
        XCTAssertFalse(controller.isInCall)
        XCTAssertEqual(controller.formattedCallDuration, "00:00")
    }
    
    func testMeetingAppProcessDetection() {
        let runningDetector = MockMeetingDetector(running: true, name: "Zoom")
        let controller = MeetingFlightControllerModel(detector: runningDetector)
        
        controller.checkRunningMeetingApps()
        XCTAssertTrue(controller.isInCall)
        XCTAssertEqual(controller.activeCallTitle, "Zoom")
        XCTAssertEqual(controller.detectedAppName, "Zoom")
    }
    
    // MARK: - 3. NotchModel Integration & Priority Ladder Tests
    
    func testNotchModelContextPriorityLadder() {
        let notch = NotchModel()
        
        // Default state: all idle -> none
        XCTAssertEqual(notch.compactHUDMode, .none)
        
        // Priority 1: Dragging over notch takes priority
        notch.dropShelf.isDraggingOverNotch = true
        XCTAssertEqual(notch.compactHUDMode, .dropShelfActive)
        
        // Priority 2: Meeting Flight Controller (in call or pre-meeting)
        notch.meetingController.startCall(title: "Design Review")
        // Even with meeting in call, active drag still beats it
        XCTAssertEqual(notch.compactHUDMode, .dropShelfActive)
        
        // Release drag -> shows meeting flight
        notch.dropShelf.isDraggingOverNotch = false
        XCTAssertEqual(notch.compactHUDMode, .meetingFlight)
        
        // End call
        notch.meetingController.endCall()
        XCTAssertEqual(notch.compactHUDMode, .none)
        
        // Priority 3: Note pinned to notch
        notch.isNotePinnedToNotch = true
        XCTAssertEqual(notch.compactHUDMode, .notesPinned)
        notch.isNotePinnedToNotch = false
        
        // Priority 4: Focus Timer + Music Dual Active
        notch.pomodoro.start()
        notch.media.isPlaying = true
        XCTAssertEqual(notch.compactHUDMode, .dualActive)
        
        notch.media.isPlaying = false
        XCTAssertEqual(notch.compactHUDMode, .pomodoroOnly)
        notch.pomodoro.pause()
        
        notch.media.isPlaying = true
        XCTAssertEqual(notch.compactHUDMode, .mediaOnly)
        notch.media.isPlaying = false
        
        // Priority 5: Calendar Alert
        notch.calendar.showNotchAlert = true
        XCTAssertEqual(notch.compactHUDMode, .calendarAlert)
        notch.calendar.showNotchAlert = false
        
        // Priority 6: Drop shelf with staged items
        _ = notch.dropShelf.stageFile(url: URL(fileURLWithPath: "/tmp/sample.zip"))
        XCTAssertEqual(notch.compactHUDMode, .dropShelfActive)
        notch.dropShelf.clearAll()
        
        // Finally idle again
        XCTAssertEqual(notch.compactHUDMode, .none)
    }
}
