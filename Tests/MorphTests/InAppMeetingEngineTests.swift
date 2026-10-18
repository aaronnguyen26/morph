import XCTest
import SwiftUI
import Combine
@testable import morph

@MainActor
final class InAppMeetingEngineTests: XCTestCase {
    
    // MARK: - 1. Service Detection Tests
    
    func testMeetingServiceDetection() {
        let meetURL1 = URL(string: "https://meet.google.com/abc-defg-hij")!
        let meetURL2 = URL(string: "https://meet.google.com/new")!
        XCTAssertEqual(MeetingService.detect(url: meetURL1), .googleMeet)
        XCTAssertEqual(MeetingService.detect(url: meetURL2), .googleMeet)
        XCTAssertEqual(MeetingService.googleMeet.iconName, "video.fill")
        
        let zoomURL1 = URL(string: "https://zoom.us/j/1234567890?pwd=secretpassword")!
        let zoomURL2 = URL(string: "https://us02web.zoom.us/j/9876543210")!
        let zoomURL3 = URL(string: "https://app.zoom.us/wc/1234567890/join")!
        XCTAssertEqual(MeetingService.detect(url: zoomURL1), .zoom)
        XCTAssertEqual(MeetingService.detect(url: zoomURL2), .zoom)
        XCTAssertEqual(MeetingService.detect(url: zoomURL3), .zoom)
        XCTAssertEqual(MeetingService.zoom.iconName, "video.bubble.fill")
        
        let teamsURL = URL(string: "https://teams.microsoft.com/l/meetup-join/19%3ameeting...")!
        XCTAssertEqual(MeetingService.detect(url: teamsURL), .teams)
        
        let webexURL = URL(string: "https://acme.webex.com/meet/johndoe")!
        XCTAssertEqual(MeetingService.detect(url: webexURL), .webex)
        
        let otherURL = URL(string: "https://example.com/conference/room42")!
        XCTAssertEqual(MeetingService.detect(url: otherURL), .genericWeb)
    }
    
    // MARK: - 2. Zoom & Meet URL Normalization Tests
    
    func testZoomURLNormalizationToWebClient() {
        // Native Zoom invite link -> Web Client join URL
        let rawZoom1 = URL(string: "https://zoom.us/j/1234567890?pwd=secretpassword&uname=Alex")!
        let (norm1, svc1) = InAppMeetingEngine.normalizeMeetingURL(rawZoom1)
        XCTAssertEqual(svc1, .zoom)
        XCTAssertEqual(norm1.absoluteString, "https://app.zoom.us/wc/1234567890/join?pwd=secretpassword&uname=Alex")
        
        // Subdomain native Zoom invite link without query
        let rawZoom2 = URL(string: "https://us04web.zoom.us/j/9876543210")!
        let (norm2, svc2) = InAppMeetingEngine.normalizeMeetingURL(rawZoom2)
        XCTAssertEqual(svc2, .zoom)
        XCTAssertEqual(norm2.absoluteString, "https://app.zoom.us/wc/9876543210/join")
        
        // Link already formatted as Web Client
        let rawZoom3 = URL(string: "https://app.zoom.us/wc/555666777/join?pwd=abc")!
        let (norm3, svc3) = InAppMeetingEngine.normalizeMeetingURL(rawZoom3)
        XCTAssertEqual(svc3, .zoom)
        XCTAssertEqual(norm3.absoluteString, "https://app.zoom.us/wc/555666777/join?pwd=abc")
    }
    
    func testGoogleMeetURLNormalization() {
        let rawMeet = URL(string: "http://meet.google.com/xyz-uvw-rst")!
        let (norm, svc) = InAppMeetingEngine.normalizeMeetingURL(rawMeet)
        XCTAssertEqual(svc, .googleMeet)
        XCTAssertEqual(norm.scheme, "https")
        XCTAssertEqual(norm.host, "meet.google.com")
        XCTAssertEqual(norm.path, "/xyz-uvw-rst")
    }
    
    // MARK: - 3. InAppMeetingEngine Call Lifecycle & Teardown Tests
    
    func testInAppMeetingEngineCallStartAndTeardownLifecycle() {
        let engine = InAppMeetingEngine()
        XCTAssertFalse(engine.isInCall)
        XCTAssertEqual(engine.formattedCallDuration, "00:00")
        XCTAssertFalse(engine.isMuted)
        XCTAssertFalse(engine.isCameraOff)
        
        var callEndedTriggered = false
        engine.onCallEnded = {
            callEndedTriggered = true
        }
        
        var startedTitle: String? = nil
        var startedService: MeetingService? = nil
        engine.onCallStarted = { title, service in
            startedTitle = title
            startedService = service
        }
        
        // 1. Start Call
        let zoomURL = URL(string: "https://zoom.us/j/1234567890?pwd=xyz")!
        let started = engine.startCall(url: zoomURL, title: "Product Architecture Review")
        XCTAssertTrue(started)
        XCTAssertTrue(engine.isInCall)
        XCTAssertEqual(engine.activeCallTitle, "Product Architecture Review")
        XCTAssertEqual(engine.activeService, .zoom)
        XCTAssertEqual(startedTitle, "Product Architecture Review")
        XCTAssertEqual(startedService, .zoom)
        
        // 2. Timer Duration Ticking
        engine.tickDuration(seconds: 125)
        XCTAssertEqual(engine.formattedCallDuration, "02:05")
        
        engine.tickDuration(seconds: 3600) // 1 hour + 2 min + 5 sec
        XCTAssertEqual(engine.formattedCallDuration, "1:02:05")
        
        // 3. Mute & Camera Controls
        XCTAssertFalse(engine.isMuted)
        engine.toggleMute()
        XCTAssertTrue(engine.isMuted)
        
        XCTAssertFalse(engine.isCameraOff)
        engine.toggleCamera()
        XCTAssertTrue(engine.isCameraOff)
        
        // 4. Leave & Close Call
        engine.leaveAndCloseCall()
        XCTAssertFalse(engine.isInCall)
        XCTAssertNil(engine.activeCallTitle)
        XCTAssertNil(engine.callStartedAt)
        XCTAssertEqual(engine.formattedCallDuration, "00:00")
        XCTAssertFalse(engine.isMuted)
        XCTAssertTrue(callEndedTriggered, "onCallEnded should fire on teardown")
    }
    
    // MARK: - 4. MeetingFlightController Direct In-App Call Taking
    
    func testMeetingFlightControllerInAppCallTaking() {
        let engine = InAppMeetingEngine()
        let controller = MeetingFlightControllerModel(engine: engine)
        let scratchpad = ScratchpadModel()
        
        let now = Date()
        let googleMeetEvent = CalendarEvent(
            id: "evt-meet-1",
            title: "Sprint Sync",
            startTime: now.addingTimeInterval(120),
            endTime: now.addingTimeInterval(1920),
            meetLink: "https://meet.google.com/abc-defg-hij"
        )
        
        // 1. Open Google Meet Call in-app
        let opened = controller.openMeetLink(event: googleMeetEvent, inApp: true, scratchpad: scratchpad)
        XCTAssertTrue(opened)
        XCTAssertTrue(controller.isInCall)
        XCTAssertTrue(engine.isInCall)
        XCTAssertEqual(controller.activeCallTitle, "Sprint Sync")
        XCTAssertEqual(controller.activeService, .googleMeet)
        
        // Duration sync from engine
        engine.tickDuration(seconds: 45)
        XCTAssertEqual(controller.formattedCallDuration, "00:45")
        
        // Mute sync from controller to engine
        XCTAssertFalse(controller.isMuted)
        controller.toggleMute()
        XCTAssertTrue(controller.isMuted)
        XCTAssertTrue(engine.isMuted)
        
        // 2. End Call via controller
        controller.endCall()
        XCTAssertFalse(controller.isInCall)
        XCTAssertFalse(engine.isInCall)
        XCTAssertEqual(controller.formattedCallDuration, "00:00")
        XCTAssertNil(controller.activeCallTitle)
    }
    
    func testMeetingFlightControllerZoomCallTaking() {
        let engine = InAppMeetingEngine()
        let controller = MeetingFlightControllerModel(engine: engine)
        
        let now = Date()
        let zoomEvent = CalendarEvent(
            id: "evt-zoom-1",
            title: "Client Quarterly Review",
            startTime: now.addingTimeInterval(60),
            endTime: now.addingTimeInterval(3660),
            meetLink: "https://zoom.us/j/9988776655?pwd=clientpass"
        )
        
        let opened = controller.openMeetLink(event: zoomEvent, inApp: true)
        XCTAssertTrue(opened)
        XCTAssertTrue(controller.isInCall)
        XCTAssertEqual(controller.activeCallTitle, "Client Quarterly Review")
        XCTAssertEqual(controller.activeService, .zoom)
        XCTAssertEqual(engine.currentMeetingURL?.absoluteString, "https://app.zoom.us/wc/9988776655/join?pwd=clientpass")
        
        controller.endCall()
        XCTAssertFalse(controller.isInCall)
    }
    
    // MARK: - 5. Instant Meeting Launches
    
    func testInstantMeetingLaunches() {
        let engine = InAppMeetingEngine()
        let controller = MeetingFlightControllerModel(engine: engine)
        
        // Instant Google Meet
        controller.startInstantCall(service: .googleMeet)
        XCTAssertTrue(controller.isInCall)
        XCTAssertEqual(controller.activeService, .googleMeet)
        XCTAssertEqual(engine.currentMeetingURL?.absoluteString, "https://meet.google.com/new")
        controller.endCall()
        
        // Instant Zoom Meeting
        controller.startInstantCall(service: .zoom)
        XCTAssertTrue(controller.isInCall)
        XCTAssertEqual(controller.activeService, .zoom)
        XCTAssertTrue(engine.currentMeetingURL?.absoluteString.contains("zoom.us") == true)
        controller.endCall()
    }
    
    // MARK: - 6. Calendar URL Resolution from Location & Description
    
    func testMeetingURLResolutionFromLocationAndDescription() {
        let controller = MeetingFlightControllerModel()
        
        // 1. URL in meetLink
        let event1 = CalendarEvent(
            id: "e1",
            title: "Meet Link Event",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            meetLink: "https://meet.google.com/foo-bar-baz"
        )
        XCTAssertEqual(controller.resolvedMeetingURL(for: event1)?.absoluteString, "https://meet.google.com/foo-bar-baz")
        
        // 2. URL embedded in location field
        let event2 = CalendarEvent(
            id: "e2",
            title: "Location Zoom Event",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            location: "Virtual Room: https://zoom.us/j/12345678"
        )
        XCTAssertEqual(controller.resolvedMeetingURL(for: event2)?.absoluteString, "https://zoom.us/j/12345678")
        
        // 3. URL embedded in multi-line description
        let event3 = CalendarEvent(
            id: "e3",
            title: "Description Meet Event",
            description: "Agenda:\n1. Metrics\nJoin via: https://meet.google.com/one-two-three\nSee you there.",
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600)
        )
        XCTAssertEqual(controller.resolvedMeetingURL(for: event3)?.absoluteString, "https://meet.google.com/one-two-three")
    }
    
    // MARK: - 7. ShortcutManager Call Teardown & Mute Integration
    
    func testShortcutManagerCallControls() {
        let notch = NotchModel()
        let shortcuts = ShortcutManager()
        shortcuts.model = notch
        
        // Start a call
        notch.meetingController.startCall(title: "Architecture War Room")
        XCTAssertTrue(notch.meetingController.isInCall)
        
        // Toggle meeting mute
        XCTAssertFalse(notch.meetingController.isMuted)
        shortcuts.toggleMeetingMute()
        XCTAssertTrue(notch.meetingController.isMuted)
        XCTAssertEqual(shortcuts.lastTriggeredShortcut, "Mic Muted")
        shortcuts.toggleMeetingMute()
        XCTAssertFalse(notch.meetingController.isMuted)
        XCTAssertEqual(shortcuts.lastTriggeredShortcut, "Mic Live")
        
        // End call via shortcut
        shortcuts.endCall()
        XCTAssertFalse(notch.meetingController.isInCall)
        XCTAssertEqual(shortcuts.lastTriggeredShortcut, "⌘⇧E Call Ended")
    }
    
    // MARK: - 8. Notch Island View & Wings In-Call Controls
    
    func testNotchIslandWingsInCallControls() {
        let notch = NotchModel()
        notch.meetingController.startCall(title: "Weekly Standup")
        
        // Left Wing should display in-call timer and icon
        let leftWing = CompactMeetingWingLeft(controller: notch.meetingController, model: notch)
        XCTAssertNotNil(leftWing.body)
        
        // Right Wing should provide Mute and direct End Call
        let rightWing = CompactMeetingWingRight(controller: notch.meetingController, model: notch)
        XCTAssertNotNil(rightWing.body)
        
        // In-call stage view hierarchy
        let stageView = InAppMeetingStageView(engine: notch.meetingController.engine, scratchpad: notch.scratchpad)
        XCTAssertNotNil(stageView.body)
        
        // Ending call
        notch.meetingController.endCall()
        XCTAssertFalse(notch.meetingController.isInCall)
    }
}
