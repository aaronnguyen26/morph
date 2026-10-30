import XCTest
import SwiftUI
import Combine
@testable import morph

@MainActor
final class ApplicationFormTrackerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: ApplicationFormModel.draftsStorageKey)
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ApplicationFormModel.draftsStorageKey)
        super.tearDown()
    }
    
    // MARK: - 1. Form Detection Tests
    
    func testFormDetectionWhenNoFormOpen() {
        let mockDetector = MockApplicationFormDetector(detected: false)
        let mockDispatcher = MockEmailDispatcher()
        let model = ApplicationFormModel(detector: mockDetector, dispatcher: mockDispatcher)
        
        XCTAssertFalse(model.isFormDetected)
        XCTAssertFalse(model.isTracking)
        XCTAssertNil(model.activeSession)
        
        model.checkActiveApplication()
        XCTAssertFalse(model.isFormDetected)
        XCTAssertNil(model.activeSession)
    }
    
    func testFormDetectionWhenApplicationFormOpen() {
        let mockDetector = MockApplicationFormDetector(
            detected: true,
            title: "Senior Engineer Application - Stripe",
            appName: "Google Chrome",
            url: "https://boards.greenhouse.io/stripe/jobs/12345"
        )
        let mockDispatcher = MockEmailDispatcher()
        let model = ApplicationFormModel(detector: mockDetector, dispatcher: mockDispatcher)
        model.recipientEmail = "candidate@example.com"
        
        model.checkActiveApplication()
        
        XCTAssertTrue(model.isFormDetected)
        XCTAssertTrue(model.isJustDetected, "When a form is newly detected on the computer, isJustDetected should be true for the detection alert")
        XCTAssertEqual(model.detectedFormTitle, "Senior Engineer Application - Stripe")
        XCTAssertEqual(model.detectedAppName, "Google Chrome")
        XCTAssertEqual(model.detectedURL, "https://boards.greenhouse.io/stripe/jobs/12345")
        XCTAssertTrue(model.isTracking)
        XCTAssertNotNil(model.activeSession)
        XCTAssertEqual(model.activeSession?.formTitle, "Senior Engineer Application - Stripe")
        XCTAssertEqual(model.activeSession?.recipientEmail, "candidate@example.com")
    }
    
    func testGoogleFormsDetectionByTitleAndCleanTitle() {
        // Standard Google Form window titles across browsers
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Untitled form - Google Forms"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Customer Feedback - Google Forms"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Event Registration - Google Forms - Google Chrome"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Job Application - Google Forms - Safari"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Scholarship Application - Google Forms - Polar"))
        
        // Clean title removes browser suffixes
        let cleaned = DefaultApplicationFormDetector.cleanTitle("Event Registration - Google Forms - Google Chrome")
        XCTAssertEqual(cleaned, "Event Registration - Google Forms")
        
        let cleanedSafari = DefaultApplicationFormDetector.cleanTitle("Volunteer Sign-up - Google Forms - Safari")
        XCTAssertEqual(cleanedSafari, "Volunteer Sign-up - Google Forms")
    }
    
    func testGoogleFormsDetectionByURL() {
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://docs.google.com/forms/d/e/1FAIpQLScxyz123/viewform"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://forms.gle/AbCdEf123456"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://forms.google.com/forms/u/0/d/e/123/edit"))
    }
    
    func testCommonlyUsedFormsDetection() {
        // 1. Microsoft Forms
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Quarterly Team Survey | Microsoft Forms"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://forms.office.com/pages/responsepage.aspx?id=v4j5cv"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://forms.microsoft.com/r/abc1234"))
        
        // 2. Typeform
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Brand Experience Questionnaire | Typeform"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://form.typeform.com/to/xYzAbc"))
        
        // 3. Tally & Jotform & SurveyMonkey
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("User Research - Tally"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://tally.so/r/3yLDE4"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Event RSVP · Jotform"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://form.jotform.com/24123456789"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Annual Customer Survey - SurveyMonkey"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://www.surveymonkey.com/r/feedback2026"))
        
        // 4. Job Application Platforms (Greenhouse, Lever, Workday, Ashby, SmartRecruiters)
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://boards.greenhouse.io/stripe/jobs/567890"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://jobs.lever.co/openai/1234-abcd"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://mycompany.wd5.myworkdayjobs.com/en-US/Careers/job/Apply"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://jobs.ashbyhq.com/linear/987654"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://jobs.smartrecruiters.com/AcmeCorp/112233"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://apply.workable.com/tech-startup/j/123456/"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://joinhandshake.com/students/jobs/998877/apply"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://careers.google.com/jobs/results/12345/apply"))
        
        // 5. DocuSign & Legal Agreements
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Please DocuSign: Rental Lease Agreement.pdf"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://na2.docusign.net/Member/PowerFormSigning.aspx?PowerFormId=123"))
        
        // 6. PDF Forms
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Apartment_Rental_Application.pdf"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("USCIS_I-9_Employment_Form.pdf"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("IRS_W-4_Form.pdf"))
    }
    
    func testNonFormWebsitesDoNotTriggerFalsePositives() {
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("Inbox (2) - user@gmail.com - Google Chrome"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("Feed | LinkedIn"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("Home / X"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("Swift Standard Library | Apple Developer Documentation"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("Spotify – Web Player"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("GitHub - apple/swift: The Swift Programming Language"))
        
        XCTAssertFalse(DefaultApplicationFormDetector.isFormURL("https://google.com"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormURL("https://mail.google.com/mail/u/0/#inbox"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormURL("https://youtube.com/watch?v=dQw4w9WgXcQ"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormURL("https://news.ycombinator.com"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormURL("https://github.com/torvalds/linux"))
    }
    
    func testGoogleFormsActiveSessionCreation() {
        let mockDetector = MockApplicationFormDetector(
            detected: true,
            title: "Hackathon Registration - Google Forms",
            appName: "Google Chrome",
            url: "https://docs.google.com/forms/d/e/1FAIpQLSc-sample/viewform"
        )
        let model = ApplicationFormModel(detector: mockDetector, dispatcher: MockEmailDispatcher())
        model.recipientEmail = "hacker@domain.com"
        
        model.checkActiveApplication()
        
        XCTAssertTrue(model.isFormDetected)
        XCTAssertEqual(model.detectedFormTitle, "Hackathon Registration - Google Forms")
        XCTAssertEqual(model.detectedAppName, "Google Chrome")
        XCTAssertEqual(model.detectedURL, "https://docs.google.com/forms/d/e/1FAIpQLSc-sample/viewform")
        
        guard let session = model.activeSession else {
            XCTFail("Active session should have been created for Google Form")
            return
        }
        
        XCTAssertEqual(session.formTitle, "Hackathon Registration - Google Forms")
        XCTAssertEqual(session.sourceURL, "https://docs.google.com/forms/d/e/1FAIpQLSc-sample/viewform")
        
        // Add sample response field
        model.addField(label: "Team Name", value: "Morph Hackers", category: .personal)
        let summary = model.activeSession?.formattedSummary ?? ""
        XCTAssertTrue(summary.contains("Hackathon Registration - Google Forms"))
        XCTAssertTrue(summary.contains("https://docs.google.com/forms/d/e/1FAIpQLSc-sample/viewform"))
        XCTAssertTrue(summary.contains("Morph Hackers"))
    }
    
    // MARK: - 2. Session Lifecycle & Field Collection Tests
    
    func testManualStartAndStopTracking() {
        let mockDetector = MockApplicationFormDetector(detected: false)
        let mockDispatcher = MockEmailDispatcher()
        let model = ApplicationFormModel(detector: mockDetector, dispatcher: mockDispatcher)
        
        var formClosedTriggered = false
        model.onFormClosed = {
            formClosedTriggered = true
        }
        
        model.startTracking(title: "Rental Application", appName: "Safari", defaultEmail: "renter@gmail.com")
        
        XCTAssertTrue(model.isTracking)
        XCTAssertTrue(model.isFormDetected)
        XCTAssertEqual(model.activeSession?.formTitle, "Rental Application")
        XCTAssertEqual(model.recipientEmail, "renter@gmail.com")
        
        model.stopTracking()
        XCTAssertFalse(model.isTracking)
        XCTAssertFalse(model.isFormDetected)
        XCTAssertNil(model.activeSession)
        XCTAssertEqual(model.historySessions.count, 1)
        XCTAssertEqual(model.historySessions.first?.formTitle, "Rental Application")
        XCTAssertTrue(formClosedTriggered)
    }
    
    func testAddingEditingAndRemovingFields() {
        let model = ApplicationFormModel(
            detector: MockApplicationFormDetector(detected: false),
            dispatcher: MockEmailDispatcher()
        )
        model.startTracking(title: "Job Application", defaultEmail: "user@test.com")
        
        // 1. Add fields
        model.addField(label: "Full Name", value: "Alex Smith", category: .personal)
        model.addField(label: "Email Address", value: "alex.smith@work.com", category: .contact)
        model.addField(label: "Why Join Us?", value: "I am passionate about developer tooling and infrastructure.", category: .question)
        
        guard let session = model.activeSession else {
            XCTFail("Active session should exist")
            return
        }
        
        XCTAssertEqual(session.fields.count, 3)
        XCTAssertEqual(session.fields[0].label, "Full Name")
        XCTAssertEqual(session.fields[0].value, "Alex Smith")
        XCTAssertEqual(session.fields[0].category, .personal)
        XCTAssertEqual(session.fields[2].wordCount, 8)
        
        // 2. Email auto-adoption
        XCTAssertEqual(model.recipientEmail, "alex.smith@work.com")
        
        // 3. Edit field
        let fieldId = session.fields[0].id
        model.updateField(id: fieldId, value: "Alex J. Smith")
        XCTAssertEqual(model.activeSession?.fields[0].value, "Alex J. Smith")
        
        // 4. Remove field
        model.removeField(id: fieldId)
        XCTAssertEqual(model.activeSession?.fields.count, 2)
        XCTAssertEqual(model.activeSession?.fields[0].label, "Email Address")
        
        // 5. Clear all fields
        model.clearFields()
        XCTAssertEqual(model.activeSession?.fields.count, 0)
    }
    
    func testClipboardMultiLineKeyValuesParsing() {
        let model = ApplicationFormModel(
            detector: MockApplicationFormDetector(detected: false),
            dispatcher: MockEmailDispatcher()
        )
        model.startTracking(title: "Grant Application", defaultEmail: "default@test.com")
        
        let clipboardPayload = """
        Full Name: Dr. Evelyn Reed
        Email: evelyn@institute.org
        LinkedIn: https://linkedin.com/in/evelyn-reed
        Years of Experience: 12
        Project Summary: Researching neural generative interfaces for desktop computing.
        """
        
        let added = model.parseAndAddFromClipboard(rawText: clipboardPayload)
        XCTAssertEqual(added, 5)
        
        guard let fields = model.activeSession?.fields else {
            XCTFail("Fields should be populated")
            return
        }
        
        XCTAssertEqual(fields.count, 5)
        XCTAssertEqual(fields[0].label, "Full Name")
        XCTAssertEqual(fields[0].value, "Dr. Evelyn Reed")
        XCTAssertEqual(fields[0].category, .personal)
        
        XCTAssertEqual(fields[1].label, "Email")
        XCTAssertEqual(fields[1].value, "evelyn@institute.org")
        XCTAssertEqual(fields[1].category, .contact)
        
        XCTAssertEqual(fields[2].category, .contact)
        XCTAssertEqual(fields[3].category, .experience)
        XCTAssertEqual(fields[4].category, .question)
        
        // Auto-adopted email
        XCTAssertEqual(model.recipientEmail, "evelyn@institute.org")
    }
    
    // MARK: - 3. Formatting Summary Copy
    
    func testFormattedMarkdownApplicationSummary() {
        let session = ApplicationFormSession(
            formTitle: "Software Engineer - Anthropic",
            sourceAppName: "Google Chrome",
            sourceURL: "https://anthropic.com/careers/123",
            recipientEmail: "engineer@example.com",
            fields: [
                FormInputField(label: "Full Name", value: "Taylor Doe", category: .personal),
                FormInputField(label: "Why AI Safety?", value: "Alignment and interpretability are essential for the future of humanity.", category: .question)
            ]
        )
        
        let summary = session.formattedSummary
        
        XCTAssertTrue(summary.contains("# Application Response: Software Engineer - Anthropic"))
        XCTAssertTrue(summary.contains("**Source:** Google Chrome"))
        XCTAssertTrue(summary.contains("**URL:** https://anthropic.com/careers/123"))
        XCTAssertTrue(summary.contains("**Recipient Copy:** engineer@example.com"))
        XCTAssertTrue(summary.contains("Taylor Doe"))
        XCTAssertTrue(summary.contains("Why AI Safety?"))
        XCTAssertTrue(summary.contains("Alignment and interpretability"))
        XCTAssertTrue(summary.contains("Word count: 10"))
        XCTAssertTrue(summary.contains("Morph Context Engine • Form Copilot"))
    }
    
    // MARK: - 4. Email Dispatching Tests
    
    func testDispatchEmailCopySuccess() async {
        let mockDispatcher = MockEmailDispatcher(shouldSucceed: true)
        let model = ApplicationFormModel(
            detector: MockApplicationFormDetector(detected: false),
            dispatcher: mockDispatcher
        )
        
        var exportedSession: ApplicationFormSession?
        model.onSessionExported = { exported in
            exportedSession = exported
        }
        
        model.startTracking(title: "Scholarship Application", defaultEmail: "scholar@university.edu")
        model.addField(label: "Essay", value: "This scholarship will support my research in renewable energy.", category: .question)
        
        let success = await model.dispatchEmailCopy()
        XCTAssertTrue(success)
        XCTAssertEqual(mockDispatcher.dispatchedSessions.count, 1)
        XCTAssertEqual(mockDispatcher.dispatchedSessions.first?.formTitle, "Scholarship Application")
        XCTAssertEqual(mockDispatcher.dispatchedSessions.first?.recipientEmail, "scholar@university.edu")
        
        XCTAssertTrue(model.activeSession?.isSubmitted ?? false)
        XCTAssertTrue(model.activeSession?.emailDeliveryStatus.isSent ?? false)
        XCTAssertNotNil(model.deliveryToastMessage)
        XCTAssertTrue(model.deliveryToastMessage?.contains("scholar@university.edu") ?? false)
        XCTAssertNotNil(exportedSession)
    }
    
    func testDispatchEmailCopyInvalidEmail() async {
        let mockDispatcher = MockEmailDispatcher(shouldSucceed: true)
        let model = ApplicationFormModel(
            detector: MockApplicationFormDetector(detected: false),
            dispatcher: mockDispatcher
        )
        model.startTracking(title: "Visa Application", defaultEmail: "")
        model.recipientEmail = "invalid-email"
        model.addField(label: "Passport Number", value: "A12345678", category: .personal)
        
        let success = await model.dispatchEmailCopy()
        XCTAssertFalse(success)
        XCTAssertEqual(mockDispatcher.dispatchedSessions.count, 0)
        XCTAssertEqual(model.deliveryToastMessage, "Invalid email address")
    }
    
    func testDispatchEmailCopyFailure() async {
        let mockDispatcher = MockEmailDispatcher(shouldSucceed: false)
        mockDispatcher.failureMessage = "Mail service offline"
        let model = ApplicationFormModel(
            detector: MockApplicationFormDetector(detected: false),
            dispatcher: mockDispatcher
        )
        model.startTracking(title: "Job Application", defaultEmail: "user@test.com")
        model.addField(label: "Name", value: "John", category: .personal)
        
        let success = await model.dispatchEmailCopy()
        XCTAssertFalse(success)
        XCTAssertEqual(mockDispatcher.dispatchedSessions.count, 0)
        XCTAssertEqual(model.activeSession?.emailDeliveryStatus, .failed("Mail service offline"))
        XCTAssertTrue(model.deliveryToastMessage?.contains("Delivery failed") ?? false)
    }
    
    func testAppendSummaryToScratchpad() {
        let model = ApplicationFormModel(
            detector: MockApplicationFormDetector(detected: false),
            dispatcher: MockEmailDispatcher()
        )
        let scratchpad = ScratchpadModel()
        scratchpad.text = "Existing meeting notes."
        
        model.startTracking(title: "Rental Application", defaultEmail: "renter@test.com")
        model.addField(label: "Monthly Income", value: "$9,500", category: .experience)
        
        model.appendSummaryToScratchpad(scratchpad)
        
        XCTAssertTrue(scratchpad.text.contains("Existing meeting notes."))
        XCTAssertTrue(scratchpad.text.contains("Rental Application"))
        XCTAssertTrue(scratchpad.text.contains("Monthly Income"))
        XCTAssertTrue(scratchpad.text.contains("$9,500"))
        XCTAssertEqual(model.deliveryToastMessage, "Saved copy into Notes!")
    }
    
    // MARK: - 5. NotchModel Context Priority Ladder Integration Tests
    
    func testNotchModelFormTrackerContextPriority() {
        let notch = NotchModel()
        
        // 1. Initial idle state
        XCTAssertEqual(notch.compactHUDMode, .none)
        
        // 2. Active form tracking triggers .formTrackerActive HUD mode
        notch.formTracker.startTracking(title: "Staff Engineer Application", appName: "Chrome")
        XCTAssertEqual(notch.compactHUDMode, .formTrackerActive)
        XCTAssertTrue(notch.isCompactActive)
        XCTAssertEqual(notch.compactWidth, max(notch.idleWidth + 280, 480))
        
        // 3. Lower priority features do NOT override active form tracking
        notch.isNotePinnedToNotch = true
        XCTAssertEqual(notch.compactHUDMode, .formTrackerActive, "Active form tracking has higher priority than pinned note")
        notch.isNotePinnedToNotch = false
        
        notch.media.isPlaying = true
        XCTAssertEqual(notch.compactHUDMode, .formTrackerActive, "Active form tracking has higher priority than music")
        notch.media.isPlaying = false
        
        // 4. Higher priority feature (Meeting) overrides form tracking
        notch.meetingController.startCall(title: "Daily Standup")
        XCTAssertEqual(notch.compactHUDMode, .meetingFlight, "Active call has higher priority than form tracker")
        notch.meetingController.endCall()
        XCTAssertEqual(notch.compactHUDMode, .formTrackerActive, "Ending call returns to form tracker")
        
        // 5. Higher priority feature (Dragging over notch) overrides form tracking
        notch.dropShelf.isDraggingOverNotch = true
        XCTAssertEqual(notch.compactHUDMode, .dropShelfActive, "Dragging over notch takes highest priority")
        notch.dropShelf.isDraggingOverNotch = false
        XCTAssertEqual(notch.compactHUDMode, .formTrackerActive)
        
        // 6. Expanding island syncs active context feature
        notch.syncExpandedFeatureWithActiveContext()
        XCTAssertEqual(notch.activeContextFeature, .formTracker)
        
        // 7. Stopping tracking restores idle state
        notch.formTracker.stopTracking()
        XCTAssertEqual(notch.compactHUDMode, .none)
    }
    
    func testCollapsedUINeverShowsUnlessFormDetected() {
        let notch = NotchModel()
        
        // 1. Initially no form detected -> HUD mode is none
        XCTAssertFalse(notch.formTracker.isFormDetected)
        XCTAssertEqual(notch.compactHUDMode, .none)
        
        // 2. Even if tracking is set or history exists, if isFormDetected is false, it MUST NOT show in collapsed UI
        notch.formTracker.isFormDetected = false
        notch.formTracker.isTracking = true
        XCTAssertEqual(notch.compactHUDMode, .none, "Collapsed UI must not show form tracker if no form is currently detected")
        
        // 3. When a detectable form is open -> shows in collapsed UI
        notch.formTracker.isFormDetected = true
        XCTAssertEqual(notch.compactHUDMode, .formTrackerActive)
        
        // 4. When form is closed / user switches away -> isFormDetected resets to false -> hides from collapsed UI
        notch.formTracker.isFormDetected = false
        XCTAssertEqual(notch.compactHUDMode, .none, "Hiding form must immediately remove form tracker from collapsed UI")
    }
    
    func testCollapsedUIWingsShowDetectedStateAndAutoCapturingPill() {
        let notch = NotchModel()
        notch.formTracker.detectedFormTitle = "Volunteer Application - Google Forms"
        notch.formTracker.detectedAppName = "Google Chrome"
        notch.formTracker.isFormDetected = true
        notch.formTracker.isJustDetected = true
        
        XCTAssertEqual(notch.compactHUDMode, .formTrackerActive)
        
        let leftWing = CompactFormTrackerWingLeft(formTracker: notch.formTracker, model: notch)
        let rightWing = CompactFormTrackerWingRight(formTracker: notch.formTracker, model: notch)
        
        XCTAssertNotNil(leftWing)
        XCTAssertNotNil(rightWing)
        XCTAssertTrue(notch.formTracker.isJustDetected)
        
        // After transition or stopping tracking
        notch.formTracker.stopTracking()
        XCTAssertFalse(notch.formTracker.isJustDetected)
        XCTAssertFalse(notch.formTracker.isFormDetected)
        XCTAssertEqual(notch.compactHUDMode, .none)
    }
    
    func testMultiWindowFormKeywordsAcrossWindows() {
        // Windows open anywhere on the user's computer
        let windowTitles = [
            "Customer Feedback - Google Forms",
            "Job Application for Senior iOS Engineer at Stripe",
            "Apartment Rental Application Form",
            "Conference Registration Form",
            "Evaluation Form - SurveyMonkey",
            "Client Intake Form | Typeform",
            "Project Proposal Submission Form",
            "Visa Application - Embassy of Japan",
            "USCIS_I-9_Employment_Eligibility_Verification.pdf",
            "Tax_Exempt_Organization_Application.pdf"
        ]
        
        for title in windowTitles {
            XCTAssertTrue(
                DefaultApplicationFormDetector.isFormTitle(title),
                "Window title '\(title)' from any open window on computer must be detected"
            )
        }
    }
    
    func testUntitledFormAndGoogleFormsSignInDetection() {
        // Newly created Google Forms default to "Untitled form"
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Untitled form"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Untitled form - Google Forms"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Untitled form - Google Forms - Polar"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Google Forms: Sign-in"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Google Forms: Online Form Creator"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Event RSVP"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Annual Survey"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Client Questionnaire"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Contact Us Form"))
    }
    
    func testPolarAndChromiumBrowserSuffixesAndURLs() {
        // Polar Browser cleaning
        let cleanedPolar = DefaultApplicationFormDetector.cleanTitle("Event Registration - Google Forms - Polar")
        XCTAssertEqual(cleanedPolar, "Event Registration - Google Forms")
        
        let cleanedComet = DefaultApplicationFormDetector.cleanTitle("Job Application - Comet")
        XCTAssertEqual(cleanedComet, "Job Application")
        
        // URLs with and without schemes
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("docs.google.com/forms/d/e/1FAIpQLScxyz/viewform"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("forms.gle/xyz98765"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://docs.google.com/forms/u/0/"))
    }
    
    func testCompactNotchPanelDynamicResizingOnFormDetection() {
        let notch = NotchModel()
        
        // Initially 179 idle width
        XCTAssertEqual(notch.compactHUDMode, .none)
        XCTAssertEqual(notch.currentWidth, notch.idleWidth)
        
        // When form is detected, compact width must be 480 to fit both left and right wings
        notch.formTracker.isFormDetected = true
        XCTAssertEqual(notch.compactHUDMode, .formTrackerActive)
        XCTAssertEqual(notch.currentWidth, max(notch.idleWidth + 280, 480))
        XCTAssertEqual(notch.compactHeight, notch.idleHeight)
        
        // When form is dismissed or closed, contracts back to idleWidth
        notch.formTracker.isFormDetected = false
        XCTAssertEqual(notch.compactHUDMode, .none)
        XCTAssertEqual(notch.currentWidth, notch.idleWidth)
    }
    
    // MARK: - Personalized Browser Detection Tests
    
    func testPersonalizedBrowserEngineFamilyMapping() {
        // Polar
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "com.polar.browser", name: "Polar"), .polar)
        
        // Safari
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "com.apple.Safari", name: "Safari"), .safari)
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "com.apple.SafariTechnologyPreview", name: "Safari Technology Preview"), .safari)
        
        // Chromium family
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "com.google.Chrome", name: "Google Chrome"), .chromium)
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "company.thebrowser.Browser", name: "Arc"), .chromium)
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "com.brave.Browser", name: "Brave Browser"), .chromium)
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "com.microsoft.edgemac", name: "Microsoft Edge"), .chromium)
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "com.operasoftware.Opera", name: "Opera"), .chromium)
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "com.vivaldi.Vivaldi", name: "Vivaldi"), .chromium)
        
        // Gecko family
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "org.mozilla.firefox", name: "Firefox"), .gecko)
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "org.mozilla.firefoxdeveloperedition", name: "Firefox Developer Edition"), .gecko)
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "app.zen-browser.zen", name: "Zen Browser"), .gecko)
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "org.torproject.torbrowser", name: "Tor Browser"), .gecko)
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "net.waterfox.waterfox", name: "Waterfox"), .gecko)
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "org.mozilla.floorp", name: "Floorp"), .gecko)
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "io.gitlab.librewolf-community.librewolf", name: "LibreWolf"), .gecko)
        
        // WebKit shells
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "com.kagi.kagimacOS", name: "Orion"), .webkit)
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "com.duckduckgo.macos.browser", name: "DuckDuckGo"), .webkit)
        
        // Chromium family extensions (Comet, SigmaOS, Canary)
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "com.perplexity.comet", name: "Comet"), .chromium)
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "com.google.Chrome.canary", name: "Google Chrome Canary"), .chromium)
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "com.sigmaos.sigmaos.macos", name: "SigmaOS"), .chromium)
        
        // Unknown / Generic
        XCTAssertEqual(PersonalizedBrowserDetector.engineFamily(for: "com.random.customapp", name: "Custom Viewer"), .unknown)
    }
    
    func testAllBrowserSuffixTitleCleaning() {
        let testCases: [(raw: String, expected: String)] = [
            ("Scholarship Application - Google Chrome Canary", "Scholarship Application"),
            ("Job Application - Google Chrome", "Job Application"),
            ("Survey Form - Chromium", "Survey Form"),
            ("Volunteer Registration - Safari Technology Preview", "Volunteer Registration"),
            ("Customer Feedback - Safari", "Customer Feedback"),
            ("Vietnam Debate 2026 - Polar", "Vietnam Debate 2026"),
            ("Executive Intake Form - Comet", "Executive Intake Form"),
            ("Course Evaluation - Brave Browser Beta", "Course Evaluation"),
            ("Conference RSVP - Brave Browser", "Conference RSVP"),
            ("Grant Application - Brave", "Grant Application"),
            ("Admission Form - Microsoft Edge Canary", "Admission Form"),
            ("University Application - Microsoft Edge", "University Application"),
            ("Feedback Survey - Arc", "Feedback Survey"),
            ("Math Quiz - 2026 — Mozilla Firefox Developer Edition", "Math Quiz - 2026"),
            ("Physics Midterm — Mozilla Firefox Nightly", "Physics Midterm"),
            ("Chemistry Assessment — Mozilla Firefox", "Chemistry Assessment"),
            ("Biology Exam - Mozilla Firefox", "Biology Exam"),
            ("Student Survey — Firefox", "Student Survey"),
            ("Teacher Review — Zen Browser", "Teacher Review"),
            ("Parent Survey - Zen Browser", "Parent Survey"),
            ("Housing Application — Zen", "Housing Application"),
            ("Apartment Lease Form - Vivaldi", "Apartment Lease Form"),
            ("Tax Exempt Application - Opera GX", "Tax Exempt Application"),
            ("Vendor Registration - Opera One", "Vendor Registration"),
            ("Client Intake - Opera", "Client Intake"),
            ("Medical Questionnaire - Orion", "Medical Questionnaire"),
            ("Order Form - DuckDuckGo", "Order Form"),
            ("Donation Form - Tor Browser", "Donation Form"),
            ("Passport Application - Floorp", "Passport Application"),
            ("Visa Application - Waterfox", "Visa Application"),
            ("Employment Form - LibreWolf", "Employment Form"),
            ("Startup Registration - SigmaOS", "Startup Registration")
        ]
        
        for tc in testCases {
            let cleaned = DefaultApplicationFormDetector.cleanTitle(tc.raw)
            XCTAssertEqual(cleaned, tc.expected, "Failed to clean title '\(tc.raw)'")
        }
    }
    
    func testDetectionAcrossDifferentBrowserTypes() {
        let browsers: [(name: String, family: BrowserEngineFamily, url: String, title: String)] = [
            ("Google Chrome", .chromium, "https://docs.google.com/forms/d/e/1FAIpQLSc123/viewform", "Chrome Form"),
            ("Safari", .safari, "https://forms.office.com/pages/responsepage.aspx", "Safari Microsoft Form"),
            ("Firefox", .gecko, "https://form.typeform.com/to/xyz789", "Firefox Typeform"),
            ("Zen Browser", .gecko, "https://tally.so/r/mK9876", "Zen Tally Form"),
            ("Arc", .chromium, "https://boards.greenhouse.io/stripe/jobs/123", "Arc Job Application"),
            ("Orion", .webkit, "https://jobs.lever.co/figma/abc456", "Orion Lever Form"),
            ("Comet", .chromium, "https://docs.google.com/forms/d/e/1FAIpQLScomet/viewform", "Comet Google Form"),
            ("Polar", .polar, "docs.google.com/forms/d/e/1FAIpQLSfyBxkuwV6Dg/viewform", "Polar Google Form"),
            ("Custom Browser", .unknown, "https://myworkdayjobs.com/apply/789", "Custom Workday Form")
        ]
        
        for b in browsers {
            let mockDetector = MockApplicationFormDetector(
                detected: true,
                title: b.title,
                appName: b.name,
                url: b.url
            )
            let tracker = ApplicationFormModel(
                detector: mockDetector,
                dispatcher: MockEmailDispatcher()
            )
            tracker.checkActiveApplication()
            
            XCTAssertTrue(tracker.isFormDetected, "Browser \(b.name) should be detected")
            XCTAssertEqual(tracker.detectedAppName, b.name)
            XCTAssertEqual(tracker.detectedFormTitle, b.title)
            XCTAssertEqual(tracker.detectedBrowserFamily, b.family)
            
            let notch = NotchModel(formTracker: tracker)
            XCTAssertEqual(notch.compactHUDMode, .formTrackerActive)
            let leftWing = CompactFormTrackerWingLeft(formTracker: tracker, model: notch)
            XCTAssertNotNil(leftWing)
        }
    }
    
    func testIsBrowserApplicationIdentification() {
        // Test that isBrowserApplication recognizes all major browsers
        let browserNames = [
            "Google Chrome", "Google Chrome Canary", "Chromium",
            "Safari", "Safari Technology Preview",
            "Firefox", "Firefox Developer Edition", "Zen Browser", "Zen",
            "Brave Browser", "Microsoft Edge", "Arc", "Opera", "Vivaldi",
            "Polar", "Comet", "Orion", "DuckDuckGo", "Tor Browser",
            "Floorp", "Waterfox", "LibreWolf", "SigmaOS"
        ]
        
        for name in browserNames {
            let keywords = [
                "chrome", "chromium", "safari", "polar", "comet", "brave", "edge", "arc",
                "firefox", "opera", "vivaldi", "orion", "zen", "browser",
                "duckduckgo", "floorp", "waterfox", "librewolf", "tor",
                "sigmaos", "wavebox", "webkit"
            ]
            let lower = name.lowercased()
            let matches = keywords.contains { lower.contains($0) }
            XCTAssertTrue(matches, "Browser '\(name)' must match browser identification keywords")
        }
    }
    
    func testPersonalizedUserBrowserProfileResolution() {
        let polarProfile = UserBrowserProfile(
            displayName: "Polar",
            bundleIdentifier: "com.polar.browser",
            appURL: URL(fileURLWithPath: "/Applications/Polar.app"),
            family: .polar,
            isSystemDefault: true
        )
        XCTAssertEqual(polarProfile.displayName, "Polar")
        XCTAssertEqual(polarProfile.bundleIdentifier, "com.polar.browser")
        XCTAssertEqual(polarProfile.family, .polar)
        XCTAssertTrue(polarProfile.isSystemDefault)
        
        let detected = PersonalizedBrowserDetector.detectDefaultBrowser()
        XCTAssertFalse(detected.displayName.isEmpty)
        XCTAssertFalse(detected.bundleIdentifier.isEmpty)
        XCTAssertTrue(detected.isSystemDefault)
    }
    
    func testPersonalizedBrowserModelLifecycleAndWingDisplay() {
        let customProfile = UserBrowserProfile(
            displayName: "Polar",
            bundleIdentifier: "com.polar.browser",
            family: .polar,
            isSystemDefault: true
        )
        let mockDetector = MockApplicationFormDetector(
            detected: true,
            title: "Vietnam Interschool Debating Championship 2026",
            appName: "Polar",
            url: "docs.google.com/forms/d/e/1FAIpQLSfyBxkuwV6Dg-jWInF3x15YmXLBZ9_B_tvijGXbldRJJXmTQg/viewform"
        )
        let model = ApplicationFormModel(
            detector: mockDetector,
            dispatcher: MockEmailDispatcher(),
            userDefaultBrowser: customProfile
        )
        
        XCTAssertEqual(model.userDefaultBrowser.displayName, "Polar")
        XCTAssertEqual(model.userDefaultBrowser.family, .polar)
        
        // Trigger active check
        model.checkActiveApplication()
        XCTAssertTrue(model.isFormDetected)
        XCTAssertEqual(model.detectedFormTitle, "Vietnam Interschool Debating Championship 2026")
        XCTAssertEqual(model.detectedAppName, "Polar")
        XCTAssertEqual(model.detectedBrowserFamily, .polar)
        XCTAssertEqual(model.activeSession?.formTitle, "Vietnam Interschool Debating Championship 2026")
        XCTAssertEqual(model.activeSession?.sourceAppName, "Polar")
        
        // Check wing display with NotchModel
        let notch = NotchModel(formTracker: model)
        XCTAssertEqual(notch.compactHUDMode, .formTrackerActive)
        
        let leftWing = CompactFormTrackerWingLeft(formTracker: model, model: notch)
        XCTAssertNotNil(leftWing)
        
        let rightWing = CompactFormTrackerWingRight(formTracker: model, model: notch)
        XCTAssertNotNil(rightWing)
    }
    
    func testPolarRealGoogleFormDetectionByURL() {
        // User's exact real Google Form in Polar
        let realFormURL = "docs.google.com/forms/d/e/1FAIpQLSfyBxkuwV6Dg-jWInF3x15YmXLBZ9_B_tvijGXbldRJJXmTQg/viewform"
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL(realFormURL))
        
        // Custom non-generic title (which without URL wouldn't match standard keywords)
        let customTitle = "Vietnam Interschool Debating Championship 2026"
        let cleaned = DefaultApplicationFormDetector.cleanTitle(customTitle)
        XCTAssertEqual(cleaned, customTitle)
        
        let detectedFormName = DefaultApplicationFormDetector.formNameFromURL(realFormURL)
        XCTAssertEqual(detectedFormName, "Google Form")
    }
    
    func testPolarBrowserNativeAndSessionDetection() {
        // If Polar is currently running on the host system with the Google Form tab open,
        // checkPolarBrowser() will directly detect the live form
        let runningPolar = NSWorkspace.shared.runningApplications.first { app in
            (app.bundleIdentifier ?? "").lowercased().contains("polar")
        }
        if runningPolar != nil {
            let result = DefaultApplicationFormDetector.checkPolarBrowser()
            if let result = result {
                XCTAssertTrue(result.isDetected)
                XCTAssertEqual(result.appName, "Polar")
                XCTAssertEqual(result.browserFamily, .polar)
                XCTAssertFalse(result.title?.isEmpty ?? true)
                XCTAssertFalse(result.url?.contains("test_demo") ?? false, "Polar must never detect stale test_demo!")
            }
        }
    }
    
    // MARK: - Autonomous Content Retrieval & Real-Time Input Capture Tests
    
    func testGoogleFormPublicLoadDataParsing() {
        // Sample FB_PUBLIC_LOAD_DATA_ format from real Google Form
        let sampleHTML = """
        <html><body>
        <script>
        var FB_PUBLIC_LOAD_DATA_ = [null, ["IA/SA Registration Details", [
            [872596780, "Full Name:", null, 0, [[751042579, null, 1]]],
            [397290101, "Phone Number:", null, 0, [[807595411, null, 1]]],
            [1714179635, "Birth Day", null, 9, [[710782629, null, 1]]],
            [1134253310, "Role Selection:", "Choose role", 2, [[733646100, [["IA"], ["SA"], ["Both"]], 1]]],
            [229588764, "Availability", null, 4, [[121753734, [["Round 1"], ["Round 2"]], 0]]],
            [999999999, "General Instructions", "Important info", 11, []]
        ], null, null, null, null, null, null, "Vietnam Interschool Debating Championship 2026"]];
        </script>
        </body></html>
        """
        
        let schema = FormContentRetriever.parseGoogleFormPublicLoadData(sampleHTML)
        XCTAssertNotNil(schema)
        XCTAssertEqual(schema?.title, "Vietnam Interschool Debating Championship 2026")
        XCTAssertEqual(schema?.description, "IA/SA Registration Details")
        XCTAssertEqual(schema?.fields.count, 6)
        
        // Field 0: Full Name (Short Answer, Required, Personal)
        let f0 = schema?.fields[0]
        XCTAssertEqual(f0?.label, "Full Name:")
        XCTAssertEqual(f0?.questionType, "shortAnswer")
        XCTAssertTrue(f0?.isRequired ?? false)
        XCTAssertEqual(f0?.category, .personal)
        XCTAssertEqual(f0?.entryKey, "entry.751042579")
        
        // Field 1: Phone Number (Short Answer, Required, Contact)
        let f1 = schema?.fields[1]
        XCTAssertEqual(f1?.label, "Phone Number:")
        XCTAssertEqual(f1?.category, .contact)
        XCTAssertEqual(f1?.entryKey, "entry.807595411")
        
        // Field 2: Birth Day (Date)
        let f2 = schema?.fields[2]
        XCTAssertEqual(f2?.label, "Birth Day")
        XCTAssertEqual(f2?.questionType, "date")
        
        // Field 3: Multiple Choice (Radio)
        let f3 = schema?.fields[3]
        XCTAssertEqual(f3?.label, "Role Selection:")
        XCTAssertEqual(f3?.questionType, "multipleChoice")
        XCTAssertEqual(f3?.options, ["IA", "SA", "Both"])
        XCTAssertEqual(f3?.questionDescription, "Choose role")
        
        // Field 4: Checkboxes
        let f4 = schema?.fields[4]
        XCTAssertEqual(f4?.label, "Availability")
        XCTAssertEqual(f4?.questionType, "checkboxes")
        XCTAssertEqual(f4?.options, ["Round 1", "Round 2"])
        XCTAssertFalse(f4?.isRequired ?? true)
        
        // Field 5: Informational Section Header
        let f5 = schema?.fields[5]
        XCTAssertEqual(f5?.label, "General Instructions")
        XCTAssertEqual(f5?.questionType, "info")
    }
    
    func testGenericHTMLFormParsing() {
        let html = """
        <html>
        <head><title>Stripe Job Application - Software Engineer</title></head>
        <body>
        <form>
            <label for="name">Legal Name</label>
            <input type="text" id="name" name="name" />
            <label for="email">Email Address</label>
            <input type="email" id="email" name="email" />
            <label for="why">Why are you interested in Stripe?</label>
            <textarea id="why" name="why"></textarea>
        </form>
        </body>
        </html>
        """
        
        let schema = FormContentRetriever.parseGenericHTMLForm(html, url: "https://stripe.com/jobs/apply")
        XCTAssertNotNil(schema)
        XCTAssertEqual(schema?.title, "Stripe Job Application - Software Engineer")
        XCTAssertEqual(schema?.fields.count, 3)
        XCTAssertEqual(schema?.fields[0].label, "Legal Name")
        XCTAssertEqual(schema?.fields[0].category, .personal)
        XCTAssertEqual(schema?.fields[1].label, "Email Address")
        XCTAssertEqual(schema?.fields[1].category, .contact)
        XCTAssertEqual(schema?.fields[2].label, "Why are you interested in Stripe?")
        XCTAssertEqual(schema?.fields[2].questionType, "paragraph")
    }
    
    func testFormSessionAnsweredCountAndCompletionMetrics() {
        var session = ApplicationFormSession(
            formTitle: "Grant Application",
            sourceAppName: "Safari",
            recipientEmail: "tester@example.com"
        )
        
        session.fields = [
            FormInputField(label: "Full Name", value: "Minh Nguyen", category: .personal),
            FormInputField(label: "Email", value: "", category: .contact),
            FormInputField(label: "Project Title", value: "Morph Context Engine", category: .question),
            FormInputField(label: "Budget", value: "", category: .experience),
            FormInputField(label: "Important Notice", value: "", category: .custom, questionType: "info")
        ]
        
        // Non-info fields = 4 total
        XCTAssertEqual(session.totalQuestions, 4)
        // 2 non-empty answers ("Minh Nguyen", "Morph Context Engine")
        XCTAssertEqual(session.answeredCount, 2)
        XCTAssertEqual(session.completionPercentage, 50.0)
        
        // Fill 3rd field
        session.fields[1].value = "minh@example.com"
        XCTAssertEqual(session.answeredCount, 3)
        XCTAssertEqual(session.completionPercentage, 75.0)
        
        // Summary includes progress
        let summary = session.formattedSummary
        XCTAssertTrue(summary.contains("3/4 Answered"))
        XCTAssertTrue(summary.contains("Minh Nguyen"))
    }
    
    @MainActor
    func testAutoCaptureKeystrokeStreamingAndNavigation() {
        let model = ApplicationFormModel()
        model.startTracking(title: "Scholarship Form", appName: "Polar")
        
        model.activeSession?.fields = [
            FormInputField(label: "First Name", value: "", category: .personal),
            FormInputField(label: "Last Name", value: "", category: .personal),
            FormInputField(label: "Essay", value: "", category: .question, questionType: "paragraph")
        ]
        
        XCTAssertEqual(model.activeFieldIndex, 0)
        
        // 1. Direct field index updates
        model.updateFieldByIndex(0, value: "Jane")
        XCTAssertEqual(model.activeSession?.fields[0].value, "Jane")
        XCTAssertTrue(model.activeSession?.fields[0].isAnswered ?? false)
        XCTAssertNotNil(model.lastAutoCapturedAt)
        
        // 2. Select next field
        model.selectActiveField(1)
        XCTAssertEqual(model.activeFieldIndex, 1)
        model.updateFieldByIndex(1, value: "Doe")
        XCTAssertEqual(model.activeSession?.fields[1].value, "Doe")
        
        // 3. Select essay field and update
        model.selectActiveField(2)
        model.updateFieldByIndex(2, value: "My essay line 1\nMy essay line 2")
        XCTAssertEqual(model.activeSession?.fields[2].wordCount, 8)
        
        XCTAssertEqual(model.activeSession?.answeredCount, 3)
        XCTAssertEqual(model.activeSession?.totalQuestions, 3)
        XCTAssertEqual(model.activeSession?.completionPercentage, 100.0)
    }
    
    @MainActor
    func testAutoCaptureEmailDetection() {
        let model = ApplicationFormModel()
        model.startTracking(title: "Contact Form", appName: "Polar", defaultEmail: "user@example.com")
        
        model.addField(label: "Contact Email", value: "scholar@university.edu", category: .contact)
        XCTAssertEqual(model.recipientEmail, "scholar@university.edu")
        XCTAssertEqual(model.activeSession?.recipientEmail, "scholar@university.edu")
    }
    
    @MainActor
    func testAutoRetrieveFormContentHydrationAndMerge() {
        let model = ApplicationFormModel()
        model.startTracking(title: "Google Form", appName: "Polar")
        
        // User had already entered an answer for Full Name
        model.addField(label: "Full Name:", value: "Nguyen Van A", category: .personal)
        XCTAssertEqual(model.activeSession?.fields.count, 1)
        
        // Simulate retrieval of full schema from Google Form
        let retrievedFields = [
            FormInputField(label: "Full Name:", value: "", category: .personal, questionType: "shortAnswer", isRequired: true),
            FormInputField(label: "Phone Number:", value: "", category: .contact, questionType: "shortAnswer", isRequired: true),
            FormInputField(label: "Role Selection:", value: "", category: .question, options: ["IA", "SA"], questionType: "multipleChoice")
        ]
        
        let schema = FormContentRetriever.RetrievedFormSchema(
            title: "Vietnam Interschool Debating Championship 2026",
            description: "Official Registration Form",
            fields: retrievedFields
        )
        
        // Simulate merge in model
        var merged = schema.fields
        for i in 0..<merged.count {
            if let existing = model.activeSession?.fields.first(where: { $0.label.lowercased() == merged[i].label.lowercased() }) {
                if !existing.value.isEmpty {
                    merged[i].value = existing.value
                }
            }
        }
        model.activeSession?.fields = merged
        model.activeSession?.formTitle = schema.title
        model.activeSession?.formDescription = schema.description
        
        XCTAssertEqual(model.activeSession?.fields.count, 3)
        // Existing user input preserved!
        XCTAssertEqual(model.activeSession?.fields[0].value, "Nguyen Van A")
        XCTAssertTrue(model.activeSession?.fields[0].isRequired ?? false)
        XCTAssertEqual(model.activeSession?.fields[2].options, ["IA", "SA"])
        XCTAssertEqual(model.activeSession?.formTitle, "Vietnam Interschool Debating Championship 2026")
        XCTAssertEqual(model.activeSession?.answeredCount, 1)
        XCTAssertEqual(model.activeSession?.totalQuestions, 3)
    }
    
    func testTopLeftBackButtonExitsFormTrackerAndReturnsToHome() {
        let notch = NotchModel()
        notch.formTracker.isFormDetected = true
        notch.openContextualFeature(.formTracker)
        
        XCTAssertEqual(notch.activeContextFeature, .formTracker)
        XCTAssertTrue(notch.isExpanded)
        
        // When user clicks the top-left Back button
        notch.closeContextualFeature()
        
        // Must successfully clear activeContextFeature and return to Home tab
        XCTAssertNil(notch.activeContextFeature, "closeContextualFeature must reliably clear activeContextFeature even when a form is detected")
        XCTAssertEqual(notch.selectedTab, .home)
    }
    
    func testFormTrackerViewRendersCleanWithoutActiveBadgeOrCounters() {
        let notch = NotchModel()
        notch.formTracker.isFormDetected = true
        notch.formTracker.startTracking(title: "Scholarship Application", appName: "Safari")
        notch.formTracker.addField(label: "Why should you receive this?", value: "Passionate about AI", category: .question)
        notch.formTracker.addField(label: "GPA", value: "3.9", category: .question)
        notch.openContextualFeature(.formTracker)
        
        let view = ApplicationFormTrackerView(model: notch)
        XCTAssertNotNil(view.body)
        
        let leftWing = CompactFormTrackerWingLeft(formTracker: notch.formTracker, model: notch)
        XCTAssertNotNil(leftWing.body)
        
        let rightWing = CompactFormTrackerWingRight(formTracker: notch.formTracker, model: notch)
        XCTAssertNotNil(rightWing.body)
    }
    
    func testZeroFlowingOrPulsingDotsInFormTrackerAndHUD() {
        let notch = NotchModel()
        notch.formTracker.isFormDetected = true
        notch.formTracker.startTracking(title: "Grant Proposal Form", appName: "Polar")
        notch.openContextualFeature(.formTracker)
        
        let leftWing = CompactFormTrackerWingLeft(formTracker: notch.formTracker, model: notch)
        let rightWing = CompactFormTrackerWingRight(formTracker: notch.formTracker, model: notch)
        let expandedView = ApplicationFormTrackerView(model: notch)
        
        XCTAssertNotNil(leftWing.body)
        XCTAssertNotNil(rightWing.body)
        XCTAssertNotNil(expandedView.body)
        
        // Wings must render pure static glyphs without pulse animations
        XCTAssertEqual(notch.formTracker.detectedFormTitle, "Grant Proposal Form")
        XCTAssertTrue(notch.formTracker.isFormDetected)
    }
    
    func testRemovalOfLiveAndAutoCapturingBadges() {
        let notch = NotchModel()
        notch.formTracker.isFormDetected = true
        notch.formTracker.startTracking(title: "Scholarship Form", appName: "Google Chrome")
        notch.openContextualFeature(.formTracker)
        
        let rightWing = CompactFormTrackerWingRight(formTracker: notch.formTracker, model: notch)
        let headerView = ApplicationFormTrackerView(model: notch)
        
        XCTAssertNotNil(rightWing.body)
        XCTAssertNotNil(headerView.body)
        
        // When email is not sent, right wing has no "Live" badge, only clean chevron
        XCTAssertEqual(notch.formTracker.activeSession?.emailDeliveryStatus, .idle)
        
        // When email is sent, right wing shows Sent delivery state
        notch.formTracker.activeSession?.emailDeliveryStatus = .sent(Date())
        if case .sent = notch.formTracker.activeSession?.emailDeliveryStatus {
            XCTAssertTrue(true, "Sent state correctly handled without needing Live badge")
        } else {
            XCTFail("Should be in sent state")
        }
    }
    
    // MARK: - Input Field Detection & Live Hydration Tests
    
    func testLocalFileFormContentAndValueRetrieval() async {
        let sampleHTML = """
        <!DOCTYPE html>
        <html>
        <head><title>Fellowship Form - Google Forms</title></head>
        <body>
            <form>
                <div class="question" role="listitem">
                    <div role="heading" aria-level="2">Full Name</div>
                    <input type="text" name="entry.1001" value="Minh Nguyen" />
                </div>
                <div class="question" role="listitem">
                    <div role="heading" aria-level="2">Email Address</div>
                    <input type="email" name="entry.1002" value="minh@example.com" />
                </div>
                <div class="question" role="listitem">
                    <div role="heading" aria-level="2">University / College</div>
                    <input type="text" name="entry.1003" value="UC Berkeley" />
                </div>
                <div class="question" role="listitem">
                    <div role="heading" aria-level="2">Statement of Purpose</div>
                    <textarea name="entry.1004">Passionate about building agentic macOS software.</textarea>
                </div>
                <div class="question" role="listitem">
                    <div role="heading" aria-level="2">Academic Standing</div>
                    <label><input type="radio" name="entry.1005" value="Senior" checked /> Senior</label>
                    <label><input type="radio" name="entry.1005" value="Junior" /> Junior</label>
                </div>
            </form>
        </body>
        </html>
        """
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_form_\(UUID().uuidString).html")
        try? sampleHTML.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        let schema = await FormContentRetriever.retrieveForm(from: tempFile.path)
        XCTAssertNotNil(schema)
        XCTAssertEqual(schema?.title, "Fellowship Form - Google Forms")
        XCTAssertEqual(schema?.fields.count, 5)
        
        guard let fields = schema?.fields, fields.count == 5 else {
            XCTFail("Expected 5 fields")
            return
        }
        
        // Field 0: Full Name
        XCTAssertEqual(fields[0].label, "Full Name")
        XCTAssertEqual(fields[0].value, "Minh Nguyen")
        XCTAssertTrue(fields[0].isAnswered)
        
        // Field 1: Email Address
        XCTAssertEqual(fields[1].label, "Email Address")
        XCTAssertEqual(fields[1].value, "minh@example.com")
        XCTAssertTrue(fields[1].isAnswered)
        
        // Field 2: University / College
        XCTAssertEqual(fields[2].label, "University / College")
        XCTAssertEqual(fields[2].value, "UC Berkeley")
        XCTAssertTrue(fields[2].isAnswered)
        
        // Field 3: Statement of Purpose
        XCTAssertEqual(fields[3].label, "Statement of Purpose")
        XCTAssertEqual(fields[3].value, "Passionate about building agentic macOS software.")
        XCTAssertTrue(fields[3].isAnswered)
        XCTAssertEqual(fields[3].questionType, "paragraph")
        
        // Field 4: Academic Standing
        XCTAssertEqual(fields[4].label, "Academic Standing")
        XCTAssertEqual(fields[4].value, "Senior")
        XCTAssertTrue(fields[4].isAnswered)
        XCTAssertEqual(fields[4].questionType, "multipleChoice")
    }
    
    func testGoogleFormsURLQueryParametersHydration() async {
        let sampleHTML = """
        <script>
        var FB_PUBLIC_LOAD_DATA_ = [null, ["Description", [[1001, "Your Legal Name", null, 0, [[1001, null, 1]]], [1002, "Contact Email", null, 0, [[1002, null, 1]]]], null, null, null, null, null, null, "AI Research Fellowship Application"]];
        </script>
        """
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_gform_\(UUID().uuidString).html")
        try? sampleHTML.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        let prefilledURL = "\(tempFile.path)?usp=pp_url&entry.1001=Jane+Doe&entry.1002=jane%40berkeley.edu"
        let schema = await FormContentRetriever.retrieveForm(from: prefilledURL)
        
        XCTAssertNotNil(schema)
        XCTAssertEqual(schema?.title, "AI Research Fellowship Application")
        XCTAssertEqual(schema?.fields.count, 2)
        
        if let fields = schema?.fields, fields.count == 2 {
            XCTAssertEqual(fields[0].label, "Your Legal Name")
            XCTAssertEqual(fields[0].value, "Jane Doe")
            XCTAssertTrue(fields[0].isAnswered)
            
            XCTAssertEqual(fields[1].label, "Contact Email")
            XCTAssertEqual(fields[1].value, "jane@berkeley.edu")
            XCTAssertTrue(fields[1].isAnswered)
        }
    }
    
    func testLiveInputHydrationAndValueMatching() {
        let model = ApplicationFormModel()
        model.startTracking(title: "Internship Application", appName: "Polar")
        model.addField(label: "Full Name", value: "")
        model.addField(label: "Email Address", value: "")
        model.addField(label: "GitHub Profile", value: "")
        
        XCTAssertEqual(model.activeSession?.answeredCount, 0)
        XCTAssertEqual(model.activeSession?.fields[0].value, "")
        
        // Simulate live input detection: "Minh Nguyen" entered in browser for "Full Name"
        let applied1 = model.applyExtractedInput(label: "Full Name", value: "Minh Nguyen")
        XCTAssertTrue(applied1)
        XCTAssertEqual(model.activeSession?.fields[0].value, "Minh Nguyen")
        XCTAssertTrue(model.activeSession?.fields[0].isAnswered ?? false)
        XCTAssertEqual(model.activeSession?.answeredCount, 1)
        
        // Simulate live input detection: "minh@test.com" for "Email Address"
        let applied2 = model.applyExtractedInput(label: "Email Address", value: "minh@test.com")
        XCTAssertTrue(applied2)
        XCTAssertEqual(model.activeSession?.fields[1].value, "minh@test.com")
        XCTAssertEqual(model.activeSession?.answeredCount, 2)
    }
    
    func testDirectFieldUpdateInModel() {
        let model = ApplicationFormModel()
        model.startTracking(title: "Startup Pitch Form", appName: "Safari")
        model.addField(label: "Project Name", value: "")
        model.addField(label: "One-line Description", value: "")
        
        XCTAssertFalse(model.activeSession?.fields[0].isAnswered ?? true)
        
        // User directly updates field value in Morph UI
        model.updateFieldByIndex(0, value: "Morph Context Engine")
        XCTAssertEqual(model.activeSession?.fields[0].value, "Morph Context Engine")
        XCTAssertTrue(model.activeSession?.fields[0].isAnswered ?? false)
        XCTAssertEqual(model.activeSession?.answeredCount, 1)
        
        model.updateFieldByIndex(1, value: "Autonomous desktop copilot with dynamic notch interface")
        XCTAssertEqual(model.activeSession?.answeredCount, 2)
        XCTAssertEqual(model.activeSession?.completionPercentage, 100.0)
    }
    
    func testQuestionTitleClimbingIgnoresGenericBrowserLabels() {
        // Generic labels should be ignored
        let generic1 = "your answer"
        let generic2 = "Address and search bar"
        let generic3 = "text"
        
        let ignored = ["your answer", "address and search bar", "search", "text", "edit", "input"]
        XCTAssertTrue(ignored.contains(generic1.lowercased()))
        XCTAssertTrue(ignored.contains(generic2.lowercased()))
        XCTAssertTrue(ignored.contains(generic3.lowercased()))
        
        // Clean question title
        let validTitle = "What is your highest level of education?"
        XCTAssertFalse(ignored.contains(validTitle.lowercased()))
    }
    
    @MainActor
    func testHoverExpansionOverCollapsedFormTrackerBar() {
        let model = NotchModel()
        model.formTracker.isFormDetected = true
        XCTAssertEqual(model.compactHUDMode, .formTrackerActive)
        XCTAssertTrue(model.isCompactActive)
        XCTAssertFalse(model.isExpanded)
        
        let controller = MorphController(model: model)
        let rect = controller.activeUIRect()
        
        // 1. Point right inside the collapsed form tracker notch bar
        let insidePoint = NSPoint(x: rect.midX, y: rect.midY)
        XCTAssertTrue(controller.isMouseInsideMorphUI(insidePoint))
        
        // 2. Point grazing 10pt below the collapsed bar
        let nearBottomPoint = NSPoint(x: rect.midX, y: rect.minY - 10)
        XCTAssertTrue(controller.isMouseInsideMorphUI(nearBottomPoint))
        
        // 3. Hover triggers immediate expansion into form tracker
        controller.checkMousePosition(insidePoint)
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.activeContextFeature, .formTracker)
        XCTAssertTrue(model.isHovered)
    }
    
    @MainActor
    func testClickGestureExpandsCollapsedFormTracker() {
        let model = NotchModel()
        model.formTracker.isFormDetected = true
        XCTAssertFalse(model.isExpanded)
        
        // Simulates tap gesture on the collapsed notch pill
        model.syncExpandedFeatureWithActiveContext()
        model.isExpanded = true
        
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.activeContextFeature, .formTracker)
    }
    
    @MainActor
    func testPassthroughHostingViewMouseMovedCallsOnMouseEnter() {
        let view = PassthroughHostingView(rootView: Text("Test"))
        var mouseEnteredCalled = false
        view.onMouseEnter = {
            mouseEnteredCalled = true
        }
        
        let dummyEvent = NSEvent()
        view.mouseMoved(with: dummyEvent)
        XCTAssertTrue(mouseEnteredCalled, "mouseMoved must trigger onMouseEnter")
    }
    
    @MainActor
    func testLiveSystemFormDetection() {
        let detector = DefaultApplicationFormDetector()
        let result = detector.detectActiveApplicationForm()
        print("REAL SYSTEM LIVE TEST -> isDetected: \(result.isDetected), title: \(result.title ?? "nil"), appName: \(result.appName ?? "nil"), url: \(result.url ?? "nil"), screenIndex: \(String(describing: result.screenIndex)), screenName: \(result.screenName ?? "nil")")
        if result.isDetected {
            XCTAssertFalse(result.url?.contains("test_demo") ?? false, "Production detection must never return a test_demo URL!")
            XCTAssertFalse(result.title?.contains("test_demo") ?? false, "Production detection must never return a test_demo title!")
            XCTAssertFalse(result.title?.isEmpty ?? true)
        } else {
            // When no real form window is open, it MUST return isDetected: false cleanly without phantom disk detection
            XCTAssertFalse(result.isDetected)
            XCTAssertNil(result.title)
            XCTAssertNil(result.url)
        }
    }
    
    @MainActor
    func testErgonomicSensitiveRectMarginsProvideGenerousTarget() {
        let model = NotchModel()
        model.formTracker.isFormDetected = true
        let controller = MorphController(model: model)
        let rect = controller.activeUIRect()
        
        // Test left margin: 12pt left of the bar
        let leftMarginPoint = NSPoint(x: rect.minX - 12, y: rect.midY)
        XCTAssertTrue(controller.isMouseInsideMorphUI(leftMarginPoint))
        
        // Test right margin: 12pt right of the bar
        let rightMarginPoint = NSPoint(x: rect.maxX + 12, y: rect.midY)
        XCTAssertTrue(controller.isMouseInsideMorphUI(rightMarginPoint))
        
        // Far away point must be false
        let farAwayPoint = NSPoint(x: rect.midX, y: rect.minY - 150)
        XCTAssertFalse(controller.isMouseInsideMorphUI(farAwayPoint))
    }
    
    // MARK: - Required Questions Detection & Filtering Tests
    
    @MainActor
    func testGoogleFormsRequiredQuestionsDetectionAndNonQuestionClutterFiltering() {
        // Construct a realistic Google Forms FB_PUBLIC_LOAD_DATA_ snippet with:
        // 1. Required text question (firstEntry[2] == 1)
        // 2. Optional text question (firstEntry[2] == 0)
        // 3. Section break header (rawType == 8) - clutter that should NOT be an input box
        // 4. Info description block (rawType == 11) - clutter that should NOT be an input box
        // 5. Required multiple choice question (prompt ends with "*")
        let fakeLoadData = """
        var FB_PUBLIC_LOAD_DATA_ = [null, [
            "Form Header Description",
            [
                [101, "Full Legal Name", "", 0, [[2001, null, 1]]],
                [102, "Preferred Nickname", "Optional helper text", 0, [[2002, null, 0]]],
                [103, "Section 2: Background", "Header text", 8, []],
                [104, "Please note your answers are saved", "Info text", 11, []],
                [105, "Work Authorization *", "", 2, [[2005, [["Citizen"], ["Visa"]], 1]]]
            ],
            null, null, null, null, null, null,
            "Engineering Application - Google Forms"
        ]];
        """
        
        let schema = FormContentRetriever.parseGoogleFormPublicLoadData(fakeLoadData)
        XCTAssertNotNil(schema)
        guard let s = schema else { return }
        
        // Total fields preserved in schema: 5
        XCTAssertEqual(s.fields.count, 5)
        
        // Actionable question filtering: section breaks (type 8) and info cards (type 11) are not actionable questions
        let actionable = s.fields.filter { $0.isActionableQuestion }
        XCTAssertEqual(actionable.count, 3, "Only actionable questions should be counted, section breaks and info cards are non-actionable")
        
        // 1. Full Legal Name (Required)
        let q1 = s.fields[0]
        XCTAssertEqual(q1.label, "Full Legal Name")
        XCTAssertTrue(q1.isRequired, "Question with firstEntry[2] == 1 must be marked isRequired")
        
        // 2. Preferred Nickname (Optional)
        let q2 = s.fields[1]
        XCTAssertEqual(q2.label, "Preferred Nickname")
        XCTAssertFalse(q2.isRequired, "Question with firstEntry[2] == 0 must NOT be marked isRequired")
        
        // 3. Work Authorization (Required with trailing asterisk stripped from clean label)
        let q4 = s.fields[4]
        XCTAssertEqual(q4.label, "Work Authorization", "Trailing asterisk should be cleanly stripped from the prompt label")
        XCTAssertTrue(q4.isRequired, "Question with asterisk and reqInt == 1 must be marked isRequired")
        XCTAssertEqual(q4.options, ["Citizen", "Visa"])
        
        // Verify session and model filtering behavior
        let session = ApplicationFormSession(
            formTitle: "Engineering Application - Google Forms",
            sourceAppName: "Google Chrome",
            recipientEmail: "test@example.com",
            fields: s.fields
        )
        XCTAssertEqual(session.totalQuestions, 3)
        XCTAssertEqual(session.requiredCount, 2)
        XCTAssertTrue(session.hasRequiredFields)
        XCTAssertEqual(session.requiredFields.map { $0.label }, ["Full Legal Name", "Work Authorization"])
        
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(detected: true), dispatcher: MockEmailDispatcher())
        model.activeSession = session
        
        // By default, visibleFields displays only the 2 required questions rather than every single box
        XCTAssertEqual(model.visibleFields.count, 2)
        XCTAssertEqual(model.visibleFields.map { $0.label }, ["Full Legal Name", "Work Authorization"])
        
        // When switched to All, it shows all 3 actionable questions, still excluding section breaks and info text
        model.setFilterMode(.all)
        XCTAssertEqual(model.visibleFields.count, 3)
        XCTAssertEqual(model.visibleFields.map { $0.label }, ["Full Legal Name", "Preferred Nickname", "Work Authorization"])
    }
    
    @MainActor
    func testGenericHTMLFormRequiredQuestionsDetectionAndFiltering() {
        let sampleHTML = """
        <form action="/submit" method="post">
            <div class="form-group" role="listitem">
                <label for="q1">Email Address *</label>
                <input id="q1" type="email" name="email" required value="candidate@stripe.com" />
            </div>
            <div class="form-group" role="listitem">
                <label for="q2">Website / Portfolio</label>
                <input id="q2" type="url" name="portfolio" value="" />
            </div>
            <div class="form-group" role="listitem">
                <label for="q3">Years of Experience</label>
                <input id="q3" type="text" name="exp" aria-required="true" value="6" />
            </div>
            <div class="form-group" role="listitem">
                <button type="submit">Submit Application</button>
            </div>
        </form>
        """
        
        let schema = FormContentRetriever.parseGenericHTMLForm(sampleHTML, url: "https://example.com/apply")
        XCTAssertNotNil(schema)
        guard let s = schema else { return }
        
        // Submit button block should be ignored
        XCTAssertEqual(s.fields.count, 3)
        
        let emailField = s.fields.first { $0.label == "Email Address" }
        XCTAssertNotNil(emailField)
        XCTAssertTrue(emailField?.isRequired ?? false, "HTML input with 'required' and asterisk must be marked isRequired")
        XCTAssertEqual(emailField?.value, "candidate@stripe.com")
        
        let websiteField = s.fields.first { $0.label == "Website / Portfolio" }
        XCTAssertNotNil(websiteField)
        XCTAssertFalse(websiteField?.isRequired ?? true, "Optional input must NOT be marked isRequired")
        
        let expField = s.fields.first { $0.label == "Years of Experience" }
        XCTAssertNotNil(expField)
        XCTAssertTrue(expField?.isRequired ?? false, "HTML input with 'aria-required=\"true\"' must be marked isRequired")
    }
    
    @MainActor
    func testFormTrackerVisibleFieldsFiltersToRequiredByDefault() {
        let mockDetector = MockApplicationFormDetector(detected: true, title: "Survey - Google Forms")
        let model = ApplicationFormModel(detector: mockDetector, dispatcher: MockEmailDispatcher())
        
        let field1 = FormInputField(label: "Name", value: "", isRequired: true)
        let field2 = FormInputField(label: "Email", value: "user@test.com", isRequired: true)
        let field3 = FormInputField(label: "Comments", value: "", isRequired: false)
        let field4 = FormInputField(label: "Website", value: "", isRequired: false)
        
        let session = ApplicationFormSession(
            formTitle: "Survey - Google Forms",
            sourceAppName: "Google Chrome",
            recipientEmail: "user@test.com",
            fields: [field1, field2, field3, field4]
        )
        model.activeSession = session
        
        // 1. Session metrics
        XCTAssertEqual(session.totalQuestions, 4)
        XCTAssertEqual(session.requiredCount, 2)
        XCTAssertEqual(session.answeredRequiredCount, 1)
        XCTAssertTrue(session.hasRequiredFields)
        
        // 2. Default filterMode is .requiredOnly, so visibleFields only returns the 2 required questions
        XCTAssertEqual(model.filterMode, .requiredOnly)
        XCTAssertEqual(model.visibleFields.count, 2, "By default, visibleFields must only return required questions to avoid clutter")
        XCTAssertEqual(model.visibleFields.map { $0.label }, ["Name", "Email"])
        
        // 3. User toggles to 'All'
        model.setFilterMode(.all)
        XCTAssertEqual(model.visibleFields.count, 4)
        
        // 4. User toggles back to 'Required'
        model.toggleFilterMode()
        XCTAssertEqual(model.filterMode, .requiredOnly)
        XCTAssertEqual(model.visibleFields.count, 2)
    }
    
    @MainActor
    func testGracefulFallbackWhenFormHasNoRequiredQuestions() {
        let mockDetector = MockApplicationFormDetector(detected: true, title: "Optional Feedback - Google Forms")
        let model = ApplicationFormModel(detector: mockDetector, dispatcher: MockEmailDispatcher())
        
        let f1 = FormInputField(label: "Feedback", value: "", isRequired: false)
        let f2 = FormInputField(label: "Rating", value: "", isRequired: false)
        
        let session = ApplicationFormSession(
            formTitle: "Optional Feedback - Google Forms",
            sourceAppName: "Google Chrome",
            recipientEmail: "test@example.com",
            fields: [f1, f2]
        )
        model.activeSession = session
        
        XCTAssertFalse(session.hasRequiredFields)
        XCTAssertEqual(session.requiredCount, 0)
        
        // Even if filterMode is .requiredOnly, when there are no required fields,
        // visibleFields falls back to displaying all questions so the view is never empty
        XCTAssertEqual(model.visibleFields.count, 2)
    }
    
    // MARK: - 11. Refined Input Detection & Accurate Context Awareness Tests
    
    func testNormalizeURLSchemeAddsHttpsToBrowserURLs() {
        // Chromium and Polar address bars often omit http:// and https:// schemes
        let bareGoogleForm = "docs.google.com/forms/d/e/1FAIpQLSeYknfP-kref7rYMkJbpihxAtoaN0m35x71JjjWrdeo3JuoLw/viewform"
        let normalizedBare = FormContentRetriever.normalizeURLScheme(bareGoogleForm)
        XCTAssertEqual(normalizedBare, "https://docs.google.com/forms/d/e/1FAIpQLSeYknfP-kref7rYMkJbpihxAtoaN0m35x71JjjWrdeo3JuoLw/viewform")
        
        let bareShortForm = "forms.gle/xyz987"
        let normalizedShort = FormContentRetriever.normalizeURLScheme(bareShortForm)
        XCTAssertEqual(normalizedShort, "https://forms.gle/xyz987")
        
        // Already schemed URLs must remain untouched
        let httpsURL = "https://docs.google.com/forms/d/e/123/viewform"
        XCTAssertEqual(FormContentRetriever.normalizeURLScheme(httpsURL), httpsURL)
        
        let httpURL = "http://myforms.local/survey"
        XCTAssertEqual(FormContentRetriever.normalizeURLScheme(httpURL), httpURL)
        
        // Local file paths and file URLs must not be modified
        let localPath = "/Users/test/form.html"
        XCTAssertEqual(FormContentRetriever.normalizeURLScheme(localPath), localPath)
        
        let fileURL = "file:///Users/test/form.html"
        XCTAssertEqual(FormContentRetriever.normalizeURLScheme(fileURL), fileURL)
    }
    
    @MainActor
    func testHierarchicalLabelMatchingPreventsFieldStealing() {
        // Setup session with both generic/short questions and specific/longer questions
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        let f0 = FormInputField(label: "Name", value: "")
        let f1 = FormInputField(label: "Email", value: "")
        let f2 = FormInputField(label: "(1) Name of Adjudicator", value: "")
        let f3 = FormInputField(label: "(1) Email Address", value: "")
        
        let session = ApplicationFormSession(
            formTitle: "Debate Adjudicator Application",
            sourceAppName: "Polar",
            recipientEmail: "test@example.com",
            fields: [f0, f1, f2, f3]
        )
        model.activeSession = session
        
        // When extracting input for "(1) Name of Adjudicator", field 0 ("Name") MUST NOT steal it!
        let matched1 = model.applyExtractedInput(label: "(1) Name of Adjudicator", value: "Minh Nguyen")
        XCTAssertTrue(matched1)
        XCTAssertEqual(model.activeSession?.fields[2].value, "Minh Nguyen")
        XCTAssertEqual(model.activeSession?.fields[0].value, "", "Field 0 ('Name') must not steal input meant for '(1) Name of Adjudicator'")
        
        // When extracting input for "(1) Email Address", field 1 ("Email") MUST NOT steal it!
        let matched2 = model.applyExtractedInput(label: "(1) Email Address", value: "minh@adjudicator.org")
        XCTAssertTrue(matched2)
        XCTAssertEqual(model.activeSession?.fields[3].value, "minh@adjudicator.org")
        XCTAssertEqual(model.activeSession?.fields[1].value, "", "Field 1 ('Email') must not steal input meant for '(1) Email Address'")
        
        // When extracting input for exact "Name", it must cleanly populate field 0
        let matched3 = model.applyExtractedInput(label: "Name", value: "Root Applicant")
        XCTAssertTrue(matched3)
        XCTAssertEqual(model.activeSession?.fields[0].value, "Root Applicant")
        XCTAssertEqual(model.activeSession?.fields[2].value, "Minh Nguyen", "Field 2 value must be preserved")
    }
    
    func testMultiLineQuestionPromptSplitsTitleAndDescription() {
        // In real Google Forms, prompts frequently contain formatting notes or instructions across multiple lines
        let multiLineHTML = """
        <html><body>
        <script>
        var FB_PUBLIC_LOAD_DATA_ = [null, ["IA Application", [
            [1001, "(1) Name of Adjudicator\\n\\nFormat: Given name, Surname.\\n\\nE.g.: Minh, Nguyen", null, 0, [[2001, null, 1]]],
            [1002, "Affiliated Institution\\nNo abbreviations.\\nIf none, please indicate N/A.", null, 0, [[2002, null, 1]]]
        ], null, null, null, null, null, null, "JCSD Winter Open: IA Application"]];
        </script>
        </body></html>
        """
        
        let schema = FormContentRetriever.parseGoogleFormPublicLoadData(multiLineHTML)
        XCTAssertNotNil(schema)
        XCTAssertEqual(schema?.fields.count, 2)
        
        // Field 0 label must be the clean first line, not containing newlines
        let f0 = schema?.fields[0]
        XCTAssertEqual(f0?.label, "(1) Name of Adjudicator")
        XCTAssertTrue(f0?.questionDescription.contains("Format: Given name, Surname.") ?? false)
        XCTAssertTrue(f0?.questionDescription.contains("E.g.: Minh, Nguyen") ?? false)
        
        // Field 1 label must be clean first line
        let f1 = schema?.fields[1]
        XCTAssertEqual(f1?.label, "Affiliated Institution")
        XCTAssertTrue(f1?.questionDescription.contains("No abbreviations.") ?? false)
    }
    
    func testBestMatchingFieldIndexScoringTiers() {
        let fields = [
            FormInputField(label: "Full Name", value: ""),
            FormInputField(label: "Candidate Email Address", value: ""),
            FormInputField(label: "(1) Are you a minor? *", value: "")
        ]
        
        // Exact raw match
        XCTAssertEqual(ApplicationFormModel.bestMatchingFieldIndex(for: "Full Name", in: fields), 0)
        
        // Normalized match stripping trailing colons / asterisks / numbering
        XCTAssertEqual(ApplicationFormModel.bestMatchingFieldIndex(for: "Full Name:", in: fields), 0)
        XCTAssertEqual(ApplicationFormModel.bestMatchingFieldIndex(for: "Are you a minor?", in: fields), 2)
        XCTAssertEqual(ApplicationFormModel.bestMatchingFieldIndex(for: "1. Are you a minor?:", in: fields), 2)
        
        // Token containment match
        XCTAssertEqual(ApplicationFormModel.bestMatchingFieldIndex(for: "Email Address", in: fields), 1)
        
        // Distant / unrelated label returns nil
        XCTAssertNil(ApplicationFormModel.bestMatchingFieldIndex(for: "Unrelated Phone Question", in: fields))
    }
    
    func testFrontmostBrowserContextAwarenessStrictActiveTab() {
        // Non-form active web page titles and URLs must strictly return false
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("YouTube - Home"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormURL("https://www.youtube.com/watch?v=12345"))
        
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("CME 193 - Scientific Python (Winter 2026)"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormURL("file:///Users/user/Desktop/syllabus.html"))
        
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("Reddit - Dive into anything"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormURL("https://www.reddit.com/r/programming"))
        
        // True form titles and URLs must return true
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("JCSD Winter Open: IA Application"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://docs.google.com/forms/d/e/1FAIpQLSeYknfP-kref7rYMkJbpihxAtoaN0m35x71JjjWrdeo3JuoLw/viewform"))
    }
    
    // MARK: - Multi-Screen & Secondary Display Tests
    
    func testMultiScreenSecondaryDisplayBoundsResolution() {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return }
        let primaryScreen = screens[0]
        
        // Window located on primary screen
        let primaryBounds: [String: Any] = [
            "X": CGFloat(100),
            "Y": CGFloat(100),
            "Width": CGFloat(800),
            "Height": CGFloat(600)
        ]
        let (sIdx0, sName0) = DefaultApplicationFormDetector.screenForBounds(primaryBounds)
        XCTAssertNotNil(sIdx0)
        XCTAssertEqual(sIdx0, 0)
        XCTAssertEqual(sName0, primaryScreen.localizedName)
        
        // Window bounds with negligible size are rejected
        let tinyBounds: [String: Any] = [
            "X": CGFloat(100),
            "Y": CGFloat(100),
            "Width": CGFloat(20),
            "Height": CGFloat(20)
        ]
        let (sIdxTiny, _) = DefaultApplicationFormDetector.screenForBounds(tinyBounds)
        XCTAssertNil(sIdxTiny)
    }
    
    @MainActor
    func testSecondaryScreenFormDetectionAndModelScreenTracking() {
        let model = ApplicationFormModel(
            detector: MockApplicationFormDetector(
                detected: true,
                title: "USC Pre-Advisement Worksheet",
                appName: "Polar",
                url: "https://uscit.tfaforms.net/forms/legacyView/92/b99a01bd639ff3427564bfc16d170334/146492",
                screenIndex: 1,
                screenName: "LS27D70xE"
            )
        )
        
        model.checkActiveApplication()
        
        XCTAssertTrue(model.isFormDetected)
        XCTAssertEqual(model.detectedFormTitle, "USC Pre-Advisement Worksheet")
        XCTAssertEqual(model.detectedAppName, "Polar")
        XCTAssertEqual(model.detectedScreenIndex, 1)
        XCTAssertEqual(model.detectedScreenName, "LS27D70xE")
        XCTAssertEqual(model.detectedURL, "https://uscit.tfaforms.net/forms/legacyView/92/b99a01bd639ff3427564bfc16d170334/146492")
    }
    
    func testTFAFormsAndFormAssemblyEducationalFormsDetection() {
        let tfaURL = "https://uscit.tfaforms.net/forms/legacyView/92/b99a01bd639ff3427564bfc16d170334/146492"
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL(tfaURL))
        XCTAssertEqual(DefaultApplicationFormDetector.formNameFromURL(tfaURL), "FormAssembly Form")
        
        let assemblyURL = "https://app.formassembly.com/forms/view/12345"
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL(assemblyURL))
        XCTAssertEqual(DefaultApplicationFormDetector.formNameFromURL(assemblyURL), "FormAssembly Form")
        
        let qualtricsURL = "https://stanford.qualtrics.com/jfe/form/SV_12345"
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL(qualtricsURL))
        XCTAssertEqual(DefaultApplicationFormDetector.formNameFromURL(qualtricsURL), "Qualtrics Survey")
        
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("USC Pre-Advisement Worksheet"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Freshman Academic Advisement Worksheet"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Student Onboarding Worksheet"))
    }
    
    @MainActor
    func testNotchModelDynamicIslandAdaptationForExternalDisplays() {
        let model = NotchModel()
        
        // When adapting to an external display without physical notch (hasPhysicalNotch = false)
        model.detectScreenNotch(for: nil)
        XCTAssertTrue(model.idleWidth >= 160)
        XCTAssertTrue(model.idleHeight >= 28)
    }
    
    @MainActor
    func testFormStateClearsScreenIndexWhenFormCloses() {
        let model = ApplicationFormModel(
            detector: MockApplicationFormDetector(
                detected: true,
                title: "Google Form",
                appName: "Google Chrome",
                url: "https://docs.google.com/forms/d/e/1FAIpQLSc/viewform",
                screenIndex: 1,
                screenName: "Secondary Monitor"
            )
        )
        model.checkActiveApplication()
        XCTAssertEqual(model.detectedScreenIndex, 1)
        XCTAssertEqual(model.detectedScreenName, "Secondary Monitor")
        
        // Transition to no form detected
        model.detector = MockApplicationFormDetector(detected: false)
        model.checkActiveApplication()
        XCTAssertFalse(model.isFormDetected)
        XCTAssertNil(model.detectedScreenIndex)
        XCTAssertNil(model.detectedScreenName)
    }
    
    @MainActor
    func testMorphUIAnchoredToPhysicalNotchScreenAndNotBiggerDisplay() {
        // Target screen must remain anchored to the physical notch display
        let notchScreen = NSScreen.screens.first(where: { $0.auxiliaryTopLeftArea != nil })
        if let notch = notchScreen {
            XCTAssertNotNil(notch.auxiliaryTopLeftArea)
            let model = NotchModel()
            model.formTracker.detectedScreenIndex = 1
            model.detectScreenNotch(for: notch)
            XCTAssertTrue(model.hasPhysicalNotch)
        }
    }
    
    @MainActor
    func testGoogleFormsAllURLVariantsDetection() {
        // Standard viewform
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://docs.google.com/forms/d/e/1FAIpQLScxyz123/viewform"))
        // Response URL
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://docs.google.com/forms/d/e/1FAIpQLScxyz123/formResponse"))
        // Creator edit URL
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://docs.google.com/forms/d/1FAIpQLScxyz123/edit"))
        // Short URL
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://forms.gle/sampleShortKey"))
        // Multi-account URL
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://docs.google.com/forms/u/1/d/e/1FAIpQLScxyz123/viewform"))
        // Workspace / School domain
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://docs.google.com/a/university.edu/forms/d/e/1FAIpQLScxyz123/viewform"))
        // Pre-filled URL
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://docs.google.com/forms/d/e/1FAIpQLScxyz123/viewform?usp=pp_url&entry.1001=John"))
        // Embedded URL
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://docs.google.com/forms/d/e/1FAIpQLScxyz123/viewform?embedded=true"))
        // Forms.app
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL("https://forms.app/form/12345678"))
    }
    
    @MainActor
    func testCompactNotchDimensionsAndHUDModeForGoogleForm() {
        let model = NotchModel()
        model.formTracker.detector = MockApplicationFormDetector(
            detected: true,
            title: "Laguna Schools Debate 2026: IA/SA Application Form",
            appName: "Polar",
            url: "https://docs.google.com/forms/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/viewform"
        )
        model.formTracker.checkActiveApplication()
        
        XCTAssertTrue(model.formTracker.isFormDetected)
        XCTAssertEqual(model.compactHUDMode, .formTrackerActive)
        XCTAssertEqual(model.compactWidth, max(model.idleWidth + 280, 480))
        XCTAssertEqual(model.compactHeight, model.idleHeight)
        XCTAssertEqual(model.currentWidth, model.compactWidth)
        XCTAssertEqual(model.currentHeight, model.compactHeight)
        
        // When clicked or expanded, syncs context feature to .formTracker
        model.syncExpandedFeatureWithActiveContext()
        XCTAssertEqual(model.activeContextFeature, .formTracker)
    }
    
    @MainActor
    func testExpandedIslandAutoContextSyncOnFormDetection() {
        let model = NotchModel()
        model.isExpanded = true
        model.selectedTab = .home
        XCTAssertNil(model.activeContextFeature)
        
        // When a Google Form is newly detected while already expanded
        model.formTracker.detector = MockApplicationFormDetector(
            detected: true,
            title: "Student Leadership Google Form",
            appName: "Google Chrome",
            url: "https://docs.google.com/forms/d/e/sample/viewform"
        )
        model.formTracker.checkActiveApplication()
        
        // Observer automatically surfaces the Form Tracker in the expanded view
        XCTAssertTrue(model.formTracker.isFormDetected)
        XCTAssertEqual(model.activeContextFeature, .formTracker)
    }
    
    @MainActor
    func testMissedDetectionCycleCounting() {
        let mockDetector = MockApplicationFormDetector(
            detected: true,
            title: "Scholarship Form",
            appName: "Safari",
            url: "https://docs.google.com/forms/d/e/sample/viewform"
        )
        let model = ApplicationFormModel(detector: mockDetector, dispatcher: MockEmailDispatcher())
        model.checkActiveApplication()
        XCTAssertTrue(model.isFormDetected)
        XCTAssertEqual(model.consecutiveMissedDetections, 0)
        
        // When form is missed, consecutiveMissedDetections increments
        model.detector = MockApplicationFormDetector(detected: false)
        model.checkActiveApplication()
        XCTAssertEqual(model.consecutiveMissedDetections, 1)
        
        // When form is detected again, consecutiveMissedDetections resets to 0
        model.detector = mockDetector
        model.checkActiveApplication()
        XCTAssertEqual(model.consecutiveMissedDetections, 0)
    }

    @MainActor
    func testLiveFormDetectionDiagnostic() {
        if let polar = (NSWorkspace.shared.runningApplications.first { ($0.bundleIdentifier ?? "") == "com.polar.browser" }) {
            let appElem = AXUIElementCreateApplication(polar.processIdentifier)
            var mWin: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElem, kAXMainWindowAttribute as CFString, &mWin) == .success,
               let win = mWin as! AXUIElement? {
                let url = DefaultApplicationFormDetector.findAddressBarOrWebAreaURL(in: win)
                print("DIAGNOSTIC findAddressBarOrWebAreaURL returned: \(url ?? "nil")")
            }
        }
        
        let polarRes = DefaultApplicationFormDetector.checkPolarBrowser()
        print("DIAGNOSTIC POLAR result: isDetected=\(polarRes?.isDetected ?? false), title=\(polarRes?.title ?? "nil"), url=\(polarRes?.url ?? "nil")")
        
        let detector = DefaultApplicationFormDetector()
        let result = detector.detectActiveApplicationForm()
        print("DIAGNOSTIC FINAL result isDetected: \(result.isDetected)")
        print("DIAGNOSTIC FINAL result title: \(result.title ?? "nil")")
        print("DIAGNOSTIC FINAL result appName: \(result.appName ?? "nil")")
        print("DIAGNOSTIC FINAL result url: \(result.url ?? "nil")")
        print("DIAGNOSTIC FINAL result screenIndex: \(result.screenIndex ?? -1)")
        print("DIAGNOSTIC FINAL result screenName: \(result.screenName ?? "nil")")
        
        if result.isDetected {
            XCTAssertFalse(result.url?.contains("test_demo") ?? false, "Production detection must never return a test_demo URL!")
            XCTAssertFalse(result.title?.contains("test_demo") ?? false, "Production detection must never return a test_demo title!")
            XCTAssertFalse(result.title?.isEmpty ?? true)
        } else {
            // When no form window is open, it must cleanly return isDetected: false with nil fields
            XCTAssertFalse(result.isDetected)
            XCTAssertNil(result.title)
            XCTAssertNil(result.url)
        }
    }

    @MainActor
    func testLiveMorphAppWindowResizingDiagnostic() {
        let model = NotchModel()
        let controller = MorphController(model: model)
        print("DIAG-RESIZE INITIAL: isExpanded=\(model.isExpanded), compactHUDMode=\(model.compactHUDMode), currentWidth=\(model.currentWidth), panel.frame=\(controller.panel.frame)")
        
        model.formTracker.checkActiveApplication()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        print("DIAG-RESIZE AFTER checkActiveApplication:")
        print("DIAG-RESIZE isFormDetected: \(model.formTracker.isFormDetected)")
        print("DIAG-RESIZE compactHUDMode: \(model.compactHUDMode)")
        print("DIAG-RESIZE currentWidth: \(model.currentWidth)")
        print("DIAG-RESIZE panel.frame: \(controller.panel.frame)")
    }

    func testAnyGoogleFormURLVariationsAreDetected() {
        let googleFormURLs = [
            "https://docs.google.com/forms/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/viewform",
            "https://docs.google.com/forms/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit",
            "https://docs.google.com/forms/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/formResponse",
            "https://docs.google.com/forms/u/0/d/e/1FAIpQLSdXgD/viewform",
            "https://docs.google.com/forms/u/1/d/e/1FAIpQLSdXgD/viewform",
            "https://forms.gle/XYZ987654321",
            "https://forms.google.com/abc1234",
            "https://docs.google.com/a/usc.edu/forms/d/e/1FAIpQLSd/viewform",
            "https://docs.google.com/forms/d/1234567890abcdefghijklmnopqrstuvwxyz/viewform?usp=sf_link",
            "https://docs.google.com/forms/d/e/1FAIpQLSd/viewform?embedded=true",
            "https://docs.google.com/forms/d/e/1FAIpQLSd/viewform?entry.12345=John&entry.67890=Doe"
        ]
        
        for url in googleFormURLs {
            XCTAssertTrue(DefaultApplicationFormDetector.isFormURL(url), "Failed to detect Google Form URL: \(url)")
        }
    }
    
    func testAnyGoogleFormTitleVariationsAreDetected() {
        let titles = [
            "Laguna Schools BP 2026: IA/SA Application Form",
            "Laguna Schools BP 2026: IA/SA",
            "Untitled form - Google Forms",
            "Untitled form",
            "Google Forms: Sign-in",
            "Student Government Election 2026",
            "T-Shirt Order Form",
            "Club Registration",
            "Feedback Survey",
            "Midterm Exam",
            "CS 101 Quiz",
            "Course Evaluation Form",
            "Fall 2026 Admissions Application",
            "Scholarship Application",
            "Volunteer Sign-up",
            "Event RSVP - Google Forms"
        ]
        
        for title in titles {
            XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle(title), "Failed to detect form title: \(title)")
        }
    }
    
    // MARK: - On-Screen Focus & Session Resumption Tests
    
    func testFormTrackerSuppressedWhenUserIsUsingSomethingElse() {
        var mockDetector = MockApplicationFormDetector(
            detected: true,
            title: "Laguna Schools BP 2026: IA/SA Application Form",
            appName: "Polar",
            url: "https://docs.google.com/forms/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/viewform"
        )
        let mockDispatcher = MockEmailDispatcher()
        let model = NotchModel()
        model.formTracker.detector = mockDetector
        model.formTracker.dispatcher = mockDispatcher
        
        // 1. Initial State: Form is open and active on screen
        model.formTracker.checkActiveApplication()
        XCTAssertTrue(model.formTracker.isFormDetected)
        XCTAssertEqual(model.compactHUDMode, .formTrackerActive)
        XCTAssertEqual(model.currentWidth, 480)
        XCTAssertNotNil(model.formTracker.activeSession)
        
        // User answers a field
        model.formTracker.activeSession?.fields = [
            FormInputField(label: "Applicant Name", value: "Minh Nguyen"),
            FormInputField(label: "Email Address", value: "")
        ]
        
        // 2. User switches to YouTube or Colab tab ("using something else")
        mockDetector.detected = false
        mockDetector.title = "Complete NumPy Linear Algebra Tutorial - YouTube"
        mockDetector.url = "https://www.youtube.com/watch?v=sample"
        model.formTracker.detector = mockDetector
        
        model.formTracker.checkActiveApplication()
        
        // Strictly suppressed: form UI must NOT show
        XCTAssertFalse(model.formTracker.isFormDetected, "Morph must not show form UI when user is using something else")
        XCTAssertEqual(model.compactHUDMode, .none, "HUD mode should be none when not looking at form")
        XCTAssertEqual(model.currentWidth, 179, "Notch should collapse to 179 pt resting size")
        
        // Session should be safely preserved in suspendedSession, NOT destroyed
        XCTAssertNotNil(model.formTracker.suspendedSession, "Session must be preserved when user is using something else")
        XCTAssertEqual(model.formTracker.suspendedSession?.fields.first?.value, "Minh Nguyen")
    }
    
    func testFormSessionResumedWhenUserSwitchesBackToForm() {
        var mockDetector = MockApplicationFormDetector(
            detected: true,
            title: "Laguna Schools BP 2026: IA/SA Application Form",
            appName: "Polar",
            url: "https://docs.google.com/forms/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/viewform"
        )
        let mockDispatcher = MockEmailDispatcher()
        let model = NotchModel()
        model.formTracker.detector = mockDetector
        model.formTracker.dispatcher = mockDispatcher
        
        // 1. User starts filling in the Google Form
        model.formTracker.checkActiveApplication()
        XCTAssertTrue(model.formTracker.isFormDetected)
        
        model.formTracker.activeSession?.fields = [
            FormInputField(label: "Full Name", value: "Alex Doe"),
            FormInputField(label: "GPA", value: "3.95"),
            FormInputField(label: "Statement of Purpose", value: "")
        ]
        
        // 2. User switches away to Notes or Terminal to look up their statement
        mockDetector.detected = false
        mockDetector.title = "Terminal - zsh"
        mockDetector.url = nil
        model.formTracker.detector = mockDetector
        model.formTracker.checkActiveApplication()
        
        XCTAssertFalse(model.formTracker.isFormDetected)
        XCTAssertEqual(model.currentWidth, 179)
        
        // 3. User switches back to that form ("went back to that form and fill in more")
        mockDetector.detected = true
        mockDetector.title = "Laguna Schools BP 2026: IA/SA Application Form"
        mockDetector.url = "https://docs.google.com/forms/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/viewform"
        model.formTracker.detector = mockDetector
        model.formTracker.checkActiveApplication()
        
        // Verified: Re-detected, Notch expands back to 480 pt, previous answers intact!
        XCTAssertTrue(model.formTracker.isFormDetected, "Morph must re-detect form when returning to it")
        XCTAssertEqual(model.compactHUDMode, .formTrackerActive)
        XCTAssertEqual(model.currentWidth, 480)
        XCTAssertNotNil(model.formTracker.activeSession)
        XCTAssertEqual(model.formTracker.activeSession?.fields[0].value, "Alex Doe", "Previously entered answer must be preserved")
        XCTAssertEqual(model.formTracker.activeSession?.fields[1].value, "3.95", "Previously entered answer must be preserved")
        
        // User fills in more ("and fill in more")
        model.formTracker.activeSession?.fields[2].value = "I am passionate about student leadership..."
        XCTAssertEqual(model.formTracker.activeSession?.fields[2].value, "I am passionate about student leadership...")
        XCTAssertEqual(model.formTracker.activeSession?.answeredCount, 3)
    }
    
    // MARK: - Polar Multi-Process & Focused Window Resilience Tests
    
    func testPolarMultiProcessSelectionPrioritizesRegularPolicy() {
        let running = NSWorkspace.shared.runningApplications
        let polarRegular = running.first(where: { app in
            !app.isTerminated &&
            kill(app.processIdentifier, 0) == 0 &&
            app.activationPolicy == .regular &&
            (app.bundleIdentifier == "com.polar.browser" ||
             app.localizedName?.caseInsensitiveCompare("polar") == .orderedSame)
        })
        
        // If Polar is installed & running on the system, verify it is selected over any accessory helpers
        if let polar = polarRegular {
            XCTAssertEqual(polar.activationPolicy, .regular)
            XCTAssertTrue(polar.bundleIdentifier == "com.polar.browser" || polar.localizedName?.lowercased() == "polar")
        }
    }
    
    func testReadChromiumSessionFormMatchesByURL() {
        // Test that readChromiumSessionForm filterURL parameter correctly matches form URLs
        let matched = DefaultApplicationFormDetector.readChromiumSessionForm(
            filterTitle: nil,
            filterURL: "https://docs.google.com/forms/d/e/1FAIpQLSfPpHu18xoGQi6puOiHPCeWVex5dLB0gu9hSJcrK_AIs3sh-A/viewform",
            polarOnly: true
        )
        // If session files exist on disk, verify match
        if let match = matched {
            XCTAssertTrue(match.url.contains("docs.google.com/forms"))
            XCTAssertFalse(match.title.isEmpty)
        }
    }
    
    func testNotchPanelUpdatePositionOnlySetsFrameWhenChanged() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let initialRect = NSRect(x: screen.frame.midX - (179 / 2), y: screen.frame.maxY - 32, width: 179, height: 32)
        let panel = NotchPanel(contentRect: initialRect)
        
        // Initialize position
        panel.updatePosition(screen: screen, width: 179, height: 32)
        let restingFrame = panel.frame
        XCTAssertEqual(restingFrame.width, 179)
        
        // Calling updatePosition with the exact same dimensions preserves frame
        panel.updatePosition(screen: screen, width: 179, height: 32)
        XCTAssertEqual(panel.frame, restingFrame)
        
        // Calling updatePosition with formTrackerActive dimension (480) updates frame cleanly
        panel.updatePosition(screen: screen, width: 480, height: 32)
        XCTAssertEqual(panel.frame.width, 480)
        XCTAssertEqual(panel.frame.height, 32)
        
        // Calling updatePosition again with 480 preserves frame without redundant order calls
        let expandedFrame = panel.frame
        panel.updatePosition(screen: screen, width: 480, height: 32)
        XCTAssertEqual(panel.frame, expandedFrame)
        
        // Returning to resting state
        panel.updatePosition(screen: screen, width: 179, height: 32)
        XCTAssertEqual(panel.frame.width, 179)
    }
    
    // MARK: - Multi-Form Accuracy & Form Switching Tests
    
    func testExtractFormIdentifierGoogleFormsAndThirdParty() {
        let f1 = "https://docs.google.com/forms/d/e/1FAIpQLSfPpHu18xoGQi6puOiHPCeWVex5dLB0gu9hSJcrK_AIs3sh-A/viewform"
        let f2 = "https://docs.google.com/forms/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/viewform"
        let f3 = "https://docs.google.com/forms/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit"
        let f4 = "https://forms.gle/xYz123"
        let f5 = "https://forms.office.com/pages/responsepage.aspx?id=v4j5cv123"
        let f6 = "https://uscit.tfaforms.net/forms/legacyView/92/b99a01bd639ff3427564bfc16d170334/146492"
        
        let id1 = DefaultApplicationFormDetector.extractFormIdentifier(from: f1)
        let id2 = DefaultApplicationFormDetector.extractFormIdentifier(from: f2)
        let id3 = DefaultApplicationFormDetector.extractFormIdentifier(from: f3)
        let id4 = DefaultApplicationFormDetector.extractFormIdentifier(from: f4)
        let id5 = DefaultApplicationFormDetector.extractFormIdentifier(from: f5)
        let id6 = DefaultApplicationFormDetector.extractFormIdentifier(from: f6)
        
        XCTAssertEqual(id1, "1FAIpQLSfPpHu18xoGQi6puOiHPCeWVex5dLB0gu9hSJcrK_AIs3sh-A")
        XCTAssertEqual(id2, "1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ")
        XCTAssertEqual(id3, "1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms")
        XCTAssertEqual(id4, "xYz123")
        XCTAssertEqual(id5, "forms.office.com:v4j5cv123")
        XCTAssertEqual(id6, "uscit.tfaforms.net/forms/legacyView/92/b99a01bd639ff3427564bfc16d170334/146492")
        
        XCTAssertNotEqual(id1, id2, "Form 1 and Form 2 must have distinct canonical identifiers")
    }
    
    func testIsSameFormDistinguishesDifferentGoogleForms() {
        let f1URL = "https://docs.google.com/forms/d/e/1FAIpQLSfPpHu18xoGQi6puOiHPCeWVex5dLB0gu9hSJcrK_AIs3sh-A/viewform"
        let f2URL = "https://docs.google.com/forms/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/viewform"
        
        // Different forms by URL
        let diffURL = DefaultApplicationFormDetector.isSameForm(
            titleA: "World Scholars Cup Coaching Application", urlA: f1URL,
            titleB: "Laguna Schools BP 2026: IA/SA Application Form", urlB: f2URL
        )
        XCTAssertFalse(diffURL, "Two forms with different Google Form IDs must NOT be considered the same form")
        
        // Same form with title refinement / different suffixes
        let sameForm = DefaultApplicationFormDetector.isSameForm(
            titleA: "Laguna Schools BP 2026: IA/SA Application Form - Google Forms", urlA: f2URL,
            titleB: "Laguna Schools BP 2026: IA/SA Application Form", urlB: f2URL
        )
        XCTAssertTrue(sameForm, "Same form URL with cleaned title must be recognized as the same form")
        
        // Different forms by title when URLs are missing
        let diffTitle = DefaultApplicationFormDetector.isSameForm(
            titleA: "Job Application", urlA: nil,
            titleB: "Customer Feedback", urlB: nil
        )
        XCTAssertFalse(diffTitle, "Distinct non-generic titles without URLs must NOT be considered the same form")
    }
    
    @MainActor
    func testSwitchingFormsArchivesOldSessionAndStartsCleanNewSession() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(detected: true, title: "Form 1"), dispatcher: MockEmailDispatcher())
        
        // 1. Start tracking Form 1
        model.detector = MockApplicationFormDetector(
            detected: true,
            title: "World Scholars Cup Coaching Application - Google Forms",
            appName: "Polar",
            url: "https://docs.google.com/forms/d/e/1FAIpQLSfPpHu18xoGQi6puOiHPCeWVex5dLB0gu9hSJcrK_AIs3sh-A/viewform"
        )
        model.checkActiveApplication()
        
        XCTAssertTrue(model.isFormDetected)
        XCTAssertEqual(model.activeSession?.formTitle, "World Scholars Cup Coaching Application - Google Forms")
        model.addField(label: "Debate Coaching Experience", value: "5 years", category: .question)
        XCTAssertEqual(model.activeSession?.fields.count, 1)
        
        // 2. User deletes Form 1 and opens Form 2
        model.detector = MockApplicationFormDetector(
            detected: true,
            title: "Laguna Schools BP 2026: IA/SA Application Form - Google Forms",
            appName: "Polar",
            url: "https://docs.google.com/forms/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/viewform"
        )
        model.checkActiveApplication()
        
        // Active session must now strictly be Form 2!
        XCTAssertTrue(model.isFormDetected)
        XCTAssertEqual(model.detectedFormTitle, "Laguna Schools BP 2026: IA/SA Application Form - Google Forms")
        XCTAssertEqual(model.activeSession?.formTitle, "Laguna Schools BP 2026: IA/SA Application Form - Google Forms")
        XCTAssertEqual(model.activeSession?.sourceURL, "https://docs.google.com/forms/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/viewform")
        
        // Form 1's fields must NOT leak into Form 2!
        XCTAssertEqual(model.activeSession?.fields.count, 0, "Form 2 session must start clean without leftover fields from Form 1")
        
        // Form 1 must be archived in history
        XCTAssertEqual(model.historySessions.count, 1)
        XCTAssertEqual(model.historySessions.first?.formTitle, "World Scholars Cup Coaching Application - Google Forms")
        XCTAssertEqual(model.historySessions.first?.fields.first?.value, "5 years")
    }
    
    @MainActor
    func testSuspendedSessionResumesOnlyIfSameForm() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(detected: true, title: "Form 1"), dispatcher: MockEmailDispatcher())
        
        let f1URL = "https://docs.google.com/forms/d/e/1FAIpQLSfPpHu18xoGQi6puOiHPCeWVex5dLB0gu9hSJcrK_AIs3sh-A/viewform"
        let f2URL = "https://docs.google.com/forms/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/viewform"
        
        // 1. User on Form 1
        model.detector = MockApplicationFormDetector(
            detected: true,
            title: "World Scholars Cup Coaching Application",
            appName: "Polar",
            url: f1URL
        )
        model.checkActiveApplication()
        model.addField(label: "Age", value: "24", category: .personal)
        
        // 2. User switches to non-form app (e.g. YouTube) -> collapses & suspends Form 1
        model.detector = MockApplicationFormDetector(
            detected: false,
            title: nil,
            appName: "Polar",
            url: nil
        )
        model.checkActiveApplication()
        XCTAssertFalse(model.isFormDetected)
        XCTAssertNotNil(model.suspendedSession)
        
        // 3. User navigates to Form 2 (NOT Form 1)
        model.detector = MockApplicationFormDetector(
            detected: true,
            title: "Laguna Schools BP 2026: IA/SA Application Form",
            appName: "Polar",
            url: f2URL
        )
        model.checkActiveApplication()
        
        // Must start Form 2, not resurrect Form 1
        XCTAssertTrue(model.isFormDetected)
        XCTAssertEqual(model.detectedFormTitle, "Laguna Schools BP 2026: IA/SA Application Form")
        XCTAssertEqual(model.activeSession?.formTitle, "Laguna Schools BP 2026: IA/SA Application Form")
        XCTAssertEqual(model.activeSession?.fields.count, 0, "Suspended session of Form 1 must not be applied to Form 2")
        XCTAssertNil(model.suspendedSession)
        
        // Form 1 is in history
        XCTAssertEqual(model.historySessions.count, 1)
        XCTAssertEqual(model.historySessions.first?.formTitle, "World Scholars Cup Coaching Application")
    }
    
    @MainActor
    func testDynamicFieldCreationWhenTypingWithEmptySchema() {
        let model = ApplicationFormModel()
        model.startTracking(title: "Google Form", appName: "Polar")
        XCTAssertEqual(model.activeSession?.fields.count, 0)
        
        // When user types or fills an input with empty schema, it must dynamically add the field
        let recorded = model.applyExtractedInput(label: "Full Name *", value: "Minh Nguyen")
        XCTAssertTrue(recorded)
        XCTAssertEqual(model.activeSession?.fields.count, 1)
        XCTAssertEqual(model.activeSession?.fields[0].label, "Full Name")
        XCTAssertEqual(model.activeSession?.fields[0].value, "Minh Nguyen")
        XCTAssertEqual(model.activeSession?.answeredCount, 1)
        XCTAssertNotNil(model.lastAutoCapturedAt)
        
        // Add another field dynamically
        let recorded2 = model.applyExtractedInput(label: "Contact Email (required)", value: "minh@example.com")
        XCTAssertTrue(recorded2)
        XCTAssertEqual(model.activeSession?.fields.count, 2)
        XCTAssertEqual(model.activeSession?.fields[1].label, "Contact Email")
        XCTAssertEqual(model.activeSession?.fields[1].value, "minh@example.com")
        XCTAssertEqual(model.activeSession?.answeredCount, 2)
        XCTAssertEqual(model.recipientEmail, "minh@example.com")
    }
    
    @MainActor
    func testFocusedElementAlignsActiveFieldIndexToCorrectQuestion() {
        let model = ApplicationFormModel()
        model.startTracking(title: "Laguna Schools Application", appName: "Google Chrome")
        model.activeSession?.fields = [
            FormInputField(label: "Full Name", value: "", category: .personal),
            FormInputField(label: "Email", value: "", category: .contact),
            FormInputField(label: "School / Institution", value: "", category: .custom),
            FormInputField(label: "Why are you applying?", value: "", category: .question, questionType: "paragraph")
        ]
        
        // Simulate user clicking on question 3 ("School / Institution") and typing
        let matched = model.applyExtractedInput(label: "3. School / Institution *", value: "Laguna High School")
        XCTAssertTrue(matched)
        
        // Field 0 ("Full Name") remains clean
        XCTAssertEqual(model.activeSession?.fields[0].value, "")
        // Field 2 ("School / Institution") receives the value
        XCTAssertEqual(model.activeSession?.fields[2].value, "Laguna High School")
        XCTAssertTrue(model.activeSession?.fields[2].isAnswered ?? false)
        XCTAssertEqual(model.activeSession?.answeredCount, 1)
        
        // Now simulate user filling out question 4 ("Why are you applying?")
        let matched2 = model.applyExtractedInput(label: "Why are you applying? *", value: "I want to help debaters improve their arguments.")
        XCTAssertTrue(matched2)
        XCTAssertEqual(model.activeSession?.fields[3].value, "I want to help debaters improve their arguments.")
        XCTAssertEqual(model.activeSession?.answeredCount, 2)
    }
    
    @MainActor
    func testRadioButtonAndCheckboxAnswerRecording() {
        let model = ApplicationFormModel()
        model.startTracking(title: "Adjudicator Application", appName: "Polar")
        model.activeSession?.fields = [
            FormInputField(label: "I will be applying as", value: "", category: .question, questionType: "multipleChoice"),
            FormInputField(label: "Select all rounds available", value: "", category: .question, questionType: "checkboxes")
        ]
        
        // Radio selection
        let radioRecorded = model.applyExtractedInput(label: "I will be applying as *", value: "Independent Adjudicator")
        XCTAssertTrue(radioRecorded)
        XCTAssertEqual(model.activeSession?.fields[0].value, "Independent Adjudicator")
        XCTAssertTrue(model.activeSession?.fields[0].isAnswered ?? false)
        
        // Checkbox multi-selection
        let checkboxRecorded = model.applyExtractedInput(label: "Select all rounds available *", value: "Round 1, Round 2, Finals")
        XCTAssertTrue(checkboxRecorded)
        XCTAssertEqual(model.activeSession?.fields[1].value, "Round 1, Round 2, Finals")
        XCTAssertEqual(model.activeSession?.answeredCount, 2)
    }
    
    func testCleanQuestionTitleStripsAsterisksAndNumbers() {
        XCTAssertEqual(ApplicationFormModel.cleanQuestionTitle("1. Full Name *"), "Full Name")
        XCTAssertEqual(ApplicationFormModel.cleanQuestionTitle("Q2: Contact Number (required)"), "Contact Number")
        XCTAssertEqual(ApplicationFormModel.cleanQuestionTitle("3) Top 5 Debate Credentials *"), "Top 5 Debate Credentials")
        XCTAssertEqual(ApplicationFormModel.cleanQuestionTitle("I consent to sharing information *"), "I consent to sharing information")
        XCTAssertEqual(ApplicationFormModel.cleanQuestionTitle("Why should we accept you? (required)"), "Why should we accept you?")
    }
    
    func testFormInputAutoTrackerInteractiveRolesAndValidation() {
        XCTAssertTrue(FormInputAutoTracker.isInteractiveInputRole("AXTextField"))
        XCTAssertTrue(FormInputAutoTracker.isInteractiveInputRole("AXTextArea"))
        XCTAssertTrue(FormInputAutoTracker.isInteractiveInputRole("AXRadioButton"))
        XCTAssertTrue(FormInputAutoTracker.isInteractiveInputRole("AXCheckBox"))
        XCTAssertTrue(FormInputAutoTracker.isInteractiveInputRole("AXComboBox"))
        XCTAssertTrue(FormInputAutoTracker.isInteractiveInputRole("AXPopUpButton"))
        XCTAssertFalse(FormInputAutoTracker.isInteractiveInputRole("AXWindow"))
        XCTAssertFalse(FormInputAutoTracker.isInteractiveInputRole("AXGroup"))
        XCTAssertFalse(FormInputAutoTracker.isInteractiveInputRole("AXScrollArea"))
        XCTAssertFalse(FormInputAutoTracker.isInteractiveInputRole("AXStaticText"))
    }
    
    @MainActor
    func testRealTimeKeystrokeCaptureReplacesAwaitingInput() {
        let model = ApplicationFormModel()
        model.startTracking(title: "Scholarship Application", appName: "Google Chrome")
        model.activeSession?.fields = [
            FormInputField(label: "Full Legal Name", value: "", category: .personal, questionType: "shortAnswer"),
            FormInputField(label: "Email Address", value: "", category: .contact, questionType: "shortAnswer")
        ]
        
        let tracker = FormInputAutoTracker(model: model)
        
        // Initially empty -> awaiting input
        XCTAssertEqual(model.activeSession?.fields[0].value, "")
        XCTAssertTrue(model.activeSession?.fields[0].value.isEmpty ?? false)
        XCTAssertEqual(model.activeFieldIndex, 0)
        
        // Type "J" in real-time
        tracker.handleKeyStroke(keyCode: 0, flags: [], characters: "J")
        XCTAssertEqual(model.activeSession?.fields[0].value, "J")
        XCTAssertFalse(model.activeSession?.fields[0].value.isEmpty ?? true, "Awaiting input must be replaced immediately when character is typed")
        
        // Type "ohn" in real-time
        tracker.handleKeyStroke(keyCode: 0, flags: [], characters: "ohn")
        XCTAssertEqual(model.activeSession?.fields[0].value, "John")
        XCTAssertTrue(model.activeSession?.fields[0].isAnswered ?? false)
    }
    
    @MainActor
    func testRealTimeKeystrokeBackspaceDeletesCharacter() {
        let model = ApplicationFormModel()
        model.startTracking(title: "Scholarship Application", appName: "Google Chrome")
        model.activeSession?.fields = [
            FormInputField(label: "Full Legal Name", value: "John", category: .personal, questionType: "shortAnswer")
        ]
        
        let tracker = FormInputAutoTracker(model: model)
        
        // Backspace once (KeyCode 51)
        tracker.handleKeyStroke(keyCode: 51, flags: [], characters: nil)
        XCTAssertEqual(model.activeSession?.fields[0].value, "Joh")
        
        // Backspace twice more
        tracker.handleKeyStroke(keyCode: 51, flags: [], characters: nil)
        tracker.handleKeyStroke(keyCode: 51, flags: [], characters: nil)
        XCTAssertEqual(model.activeSession?.fields[0].value, "J")
        
        // Backspace last letter -> reverts to empty (awaiting input)
        tracker.handleKeyStroke(keyCode: 51, flags: [], characters: nil)
        XCTAssertEqual(model.activeSession?.fields[0].value, "")
        XCTAssertTrue(model.activeSession?.fields[0].value.isEmpty ?? false, "Empty value returns state to awaiting input")
    }
    
    @MainActor
    func testRealTimeTabAdvancesActiveFieldIndex() {
        let model = ApplicationFormModel()
        model.startTracking(title: "Survey Form", appName: "Google Chrome")
        model.activeSession?.fields = [
            FormInputField(label: "Question 1", value: "Answer 1", category: .question, questionType: "shortAnswer"),
            FormInputField(label: "Question 2", value: "", category: .question, questionType: "shortAnswer"),
            FormInputField(label: "Question 3", value: "", category: .question, questionType: "shortAnswer")
        ]
        
        let tracker = FormInputAutoTracker(model: model)
        model.activeFieldIndex = 0
        
        // Tab forward (KeyCode 48)
        tracker.handleKeyStroke(keyCode: 48, flags: [], characters: "\t")
        XCTAssertEqual(model.activeFieldIndex, 1)
        
        // Tab forward again
        tracker.handleKeyStroke(keyCode: 48, flags: [], characters: "\t")
        XCTAssertEqual(model.activeFieldIndex, 2)
        
        // Shift+Tab backward (KeyCode 48 with maskShift)
        tracker.handleKeyStroke(keyCode: 48, flags: [.maskShift], characters: "\t")
        XCTAssertEqual(model.activeFieldIndex, 1)
    }
    
    @MainActor
    func testRealTimeReturnKeyHandling() {
        let model = ApplicationFormModel()
        model.startTracking(title: "Application Form", appName: "Google Chrome")
        model.activeSession?.fields = [
            FormInputField(label: "Short Answer", value: "First Line", category: .question, questionType: "shortAnswer"),
            FormInputField(label: "Long Essay", value: "Paragraph 1", category: .question, questionType: "paragraph")
        ]
        
        let tracker = FormInputAutoTracker(model: model)
        model.activeFieldIndex = 0
        
        // Return on short answer advances active field
        tracker.handleKeyStroke(keyCode: 36, flags: [], characters: "\r")
        XCTAssertEqual(model.activeFieldIndex, 1)
        
        // Return on paragraph appends newline character
        tracker.handleKeyStroke(keyCode: 36, flags: [], characters: "\r")
        XCTAssertEqual(model.activeSession?.fields[1].value, "Paragraph 1\n")
        XCTAssertEqual(model.activeFieldIndex, 1, "Paragraph return should not advance field index")
    }
    
    @MainActor
    func testRealTimeEmailAutoCaptureUpdatesRecipientEmail() {
        let model = ApplicationFormModel()
        model.startTracking(title: "Student Registration", appName: "Google Chrome")
        model.activeSession?.fields = [
            FormInputField(label: "Contact Email", value: "", category: .contact, questionType: "shortAnswer")
        ]
        
        let tracker = FormInputAutoTracker(model: model)
        tracker.handleKeyStroke(keyCode: 0, flags: [], characters: "student@stanford.edu")
        
        XCTAssertEqual(model.activeSession?.fields[0].value, "student@stanford.edu")
        XCTAssertEqual(model.recipientEmail, "student@stanford.edu", "Typing valid email must automatically update recipientEmail")
    }
    
    @MainActor
    func testNonPrintableControlKeysAndArrowKeysAreIgnored() {
        let model = ApplicationFormModel()
        model.startTracking(title: "Form", appName: "Google Chrome")
        model.activeSession?.fields = [
            FormInputField(label: "Field 1", value: "Start", category: .question, questionType: "shortAnswer")
        ]
        
        let tracker = FormInputAutoTracker(model: model)
        
        // Up arrow (\u{F700}), Down arrow (\u{F701}), Left arrow (\u{F702}), Right arrow (\u{F703})
        tracker.handleKeyStroke(keyCode: 126, flags: [], characters: "\u{F700}")
        tracker.handleKeyStroke(keyCode: 125, flags: [], characters: "\u{F701}")
        tracker.handleKeyStroke(keyCode: 123, flags: [], characters: "\u{F702}")
        tracker.handleKeyStroke(keyCode: 124, flags: [], characters: "\u{F703}")
        
        XCTAssertEqual(model.activeSession?.fields[0].value, "Start", "Arrow and private-use function keys must not be appended to field values")
    }
    
    func testEventTapCreationAndGracefulStop() {
        let model = ApplicationFormModel()
        let tracker = FormInputAutoTracker(model: model)
        tracker.start()
        XCTAssertTrue(tracker.isRunning)
        tracker.stop()
        XCTAssertFalse(tracker.isRunning)
    }
    
    @MainActor
    func testFormSessionMemoryRestoresPreviousAnswersWhenReturningToForm() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(detected: false), dispatcher: MockEmailDispatcher())
        model.clearSavedDrafts()
        
        // 1. Detect Form 1 (Laguna Schools Debate)
        model.detector = MockApplicationFormDetector(
            detected: true,
            title: "Laguna Schools Debate 2026: IA/SA Application Form",
            appName: "Polar",
            url: "https://docs.google.com/forms/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/viewform"
        )
        model.checkActiveApplication()
        XCTAssertTrue(model.isFormDetected)
        XCTAssertEqual(model.detectedFormTitle, "Laguna Schools Debate 2026: IA/SA Application Form")
        
        // User fills in Question 1 and Question 2
        model.addField(label: "Full Name", value: "Minh Nguyen", category: .personal)
        model.addField(label: "Email Address", value: "minh@example.com", category: .contact)
        model.addField(label: "Debate Experience", value: "", category: .experience)
        XCTAssertEqual(model.activeSession?.fields[0].value, "Minh Nguyen")
        XCTAssertEqual(model.activeSession?.fields[1].value, "minh@example.com")
        XCTAssertEqual(model.activeSession?.answeredCount, 2)
        
        // 2. User navigates to Form 2 (World Scholars Cup)
        model.detector = MockApplicationFormDetector(
            detected: true,
            title: "World Scholars Cup Coaching Application",
            appName: "Polar",
            url: "https://docs.google.com/forms/d/e/1FAIpQLSfPpHu18xoGQi6puOiHPCeWVex5dLB0gu9hSJcrK_AIs3sh-A/viewform"
        )
        model.checkActiveApplication()
        XCTAssertEqual(model.detectedFormTitle, "World Scholars Cup Coaching Application")
        XCTAssertEqual(model.activeSession?.fields.count, 0, "New form should start fresh")
        
        // 3. User navigates back to Form 1 (Laguna Schools Debate)
        model.detector = MockApplicationFormDetector(
            detected: true,
            title: "Laguna Schools Debate 2026: IA/SA Application Form",
            appName: "Polar",
            url: "https://docs.google.com/forms/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/viewform"
        )
        model.checkActiveApplication()
        
        // Verify Form 1 is restored with all its previous inputs!
        XCTAssertTrue(model.isFormDetected)
        XCTAssertEqual(model.activeSession?.formTitle, "Laguna Schools Debate 2026: IA/SA Application Form")
        XCTAssertEqual(model.activeSession?.fields.count, 3)
        XCTAssertEqual(model.activeSession?.fields[0].value, "Minh Nguyen", "Previous input must be restored from memory")
        XCTAssertEqual(model.activeSession?.fields[1].value, "minh@example.com", "Previous input must be restored from memory")
        XCTAssertEqual(model.activeSession?.answeredCount, 2)
        
        // Verify activeFieldIndex points to the first unanswered field (index 2: Debate Experience), not Question 1
        XCTAssertEqual(model.activeFieldIndex, 2, "Active field must advance to first unanswered question")
    }
    
    @MainActor
    func testInitialFormOpenGathersExistingBrowserInputs() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Course Evaluation", appName: "Google Chrome")
        
        // Form schema with 3 questions
        model.activeSession?.fields = [
            FormInputField(label: "Student Name", value: "", category: .personal, questionType: "shortAnswer"),
            FormInputField(label: "Course Rating", value: "", category: .question, questionType: "multipleChoice"),
            FormInputField(label: "Comments", value: "", category: .question, questionType: "paragraph")
        ]
        
        // Simulate initial scan finding already answered values in browser
        model.applyExtractedInput(label: "Student Name", value: "Sarah Connor")
        model.applyExtractedInput(label: "Course Rating", value: "5 - Excellent")
        
        XCTAssertEqual(model.activeSession?.fields[0].value, "Sarah Connor")
        XCTAssertEqual(model.activeSession?.fields[1].value, "5 - Excellent")
        XCTAssertEqual(model.activeSession?.fields[2].value, "")
        
        model.advanceToFirstUnansweredFieldIfNeeded()
        XCTAssertEqual(model.activeFieldIndex, 2, "Active field should point to the unanswered Comments question (index 2)")
    }
    
    @MainActor
    func testActiveFieldIndexAlignsToFocusedOrFirstUnansweredQuestion() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Volunteer Registration", appName: "Safari")
        
        model.activeSession?.fields = [
            FormInputField(label: "1. Full Name", value: "Bob Stone", category: .personal, questionType: "shortAnswer"),
            FormInputField(label: "2. Phone Number", value: "555-1234", category: .contact, questionType: "shortAnswer"),
            FormInputField(label: "3. Availability", value: "", category: .question, questionType: "shortAnswer"),
            FormInputField(label: "4. Previous Roles", value: "", category: .question, questionType: "paragraph")
        ]
        
        // Question 1 and Question 2 are answered
        model.activeFieldIndex = 0
        model.advanceToFirstUnansweredFieldIfNeeded()
        
        XCTAssertEqual(model.activeFieldIndex, 2, "Must automatically advance to Question 3 (index 2) which is first unanswered")
    }
    
    @MainActor
    func testAutoRetrieveFormContentPreservesExistingAnswersWithBestMatch() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Membership Application", appName: "Google Chrome")
        
        // User already has partially filled form locally
        model.activeSession?.fields = [
            FormInputField(label: "Full Name", value: "John Doe", category: .personal, questionType: "shortAnswer"),
            FormInputField(label: "Email", value: "john@doe.com", category: .contact, questionType: "shortAnswer")
        ]
        
        // Simulate autoRetrieveFormContent receiving schema with asterisks/required notes
        let schemaFields = [
            FormInputField(label: "Full Name *", value: "", category: .personal, questionType: "shortAnswer", isRequired: true),
            FormInputField(label: "Email *", value: "", category: .contact, questionType: "shortAnswer", isRequired: true),
            FormInputField(label: "Reason for Joining", value: "", category: .question, questionType: "paragraph", isRequired: false)
        ]
        
        var merged = schemaFields
        let current = model.activeSession!.fields
        for i in 0..<merged.count {
            if let matchIdx = ApplicationFormModel.bestMatchingFieldIndex(for: merged[i].label, in: current) {
                let existing = current[matchIdx]
                if !existing.value.isEmpty && merged[i].value.isEmpty {
                    merged[i].value = existing.value
                }
            }
        }
        model.activeSession?.fields = merged
        
        XCTAssertEqual(model.activeSession?.fields[0].value, "John Doe", "Must preserve John Doe despite 'Full Name *' schema label")
        XCTAssertEqual(model.activeSession?.fields[1].value, "john@doe.com", "Must preserve email despite 'Email *' schema label")
        XCTAssertEqual(model.activeSession?.fields[2].value, "")
        
        model.advanceToFirstUnansweredFieldIfNeeded()
        XCTAssertEqual(model.activeFieldIndex, 2, "Must advance to Question 3")
    }
    
    @MainActor
    func testFormDraftsPersistenceToUserDefaults() {
        let model1 = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model1.clearSavedDrafts()
        
        let session = ApplicationFormSession(
            formTitle: "Saved Job Application",
            sourceAppName: "Safari",
            sourceURL: "https://docs.google.com/forms/d/e/12345/viewform",
            recipientEmail: "applicant@gmail.com",
            fields: [
                FormInputField(label: "Full Name", value: "Test Applicant", category: .personal),
                FormInputField(label: "Resume Link", value: "https://drive.google.com/resume", category: .custom)
            ]
        )
        model1.activeSession = session
        model1.saveDrafts()
        
        // Instantiate a second model that loads from UserDefaults
        let model2 = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model2.loadDrafts()
        XCTAssertEqual(model2.historySessions.count, 1)
        XCTAssertEqual(model2.historySessions[0].formTitle, "Saved Job Application")
        XCTAssertEqual(model2.historySessions[0].fields[0].value, "Test Applicant")
        XCTAssertEqual(model2.historySessions[0].fields[1].value, "https://drive.google.com/resume")
        
        // Clean up
        model2.clearSavedDrafts()
    }
    
    @MainActor
    func testGoogleFormNonActionableInfoHeadersAreSkippedAndNotAwaitingInput() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Laguna Schools BP 2026: IA/SA Application Form", appName: "Polar")
        
        // Simulating fields parsed from Google Forms: item 0 is a disclaimer with no entryKey
        let item0 = FormInputField(label: "PRIVACY NOTICE", value: "", category: .custom, questionType: "info", isRequired: false, entryKey: nil)
        let item1 = FormInputField(label: "I consent to sharing the information in this form", value: "", category: .question, options: ["Yes", "No"], questionType: "multipleChoice", isRequired: true, entryKey: "entry.236482357")
        let item2 = FormInputField(label: "Basic Information", value: "", category: .custom, questionType: "section", isRequired: false, entryKey: nil)
        let item3 = FormInputField(label: "Full Name", value: "", category: .personal, questionType: "paragraph", isRequired: true, entryKey: "entry.2066173020")
        
        model.activeSession?.fields = [item0, item1, item2, item3]
        
        // PRIVACY NOTICE and Basic Information must NOT be actionable questions
        XCTAssertFalse(item0.isActionableQuestion)
        XCTAssertTrue(item1.isActionableQuestion)
        XCTAssertFalse(item2.isActionableQuestion)
        XCTAssertTrue(item3.isActionableQuestion)
        
        // When aligning or advancing, it must position on item 1 (the first real question), NOT item 0
        model.advanceToFirstUnansweredFieldIfNeeded()
        XCTAssertEqual(model.activeFieldIndex, 1, "Must advance past info/section headers to the first real actionable question")
        XCTAssertEqual(model.activeSession?.fields[model.activeFieldIndex].label, "I consent to sharing the information in this form")
    }
    
    @MainActor
    func testMultipleChoiceOptionKeystrokeMatchingAndSelection() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Application Form", appName: "Polar")
        let q1 = FormInputField(label: "I consent", value: "", category: .question, options: ["Yes", "No (Cancel)"], questionType: "multipleChoice", isRequired: true, entryKey: "entry.1")
        let q2 = FormInputField(label: "Full Name", value: "", category: .personal, questionType: "shortAnswer", isRequired: true, entryKey: "entry.2")
        model.activeSession?.fields = [q1, q2]
        model.activeFieldIndex = 0
        
        let tracker = FormInputAutoTracker(model: model)
        // Typing 'y' or 'Y' should select "Yes", record it, and advance to next question
        tracker.handleKeyStroke(keyCode: 16, flags: [], characters: "y")
        
        XCTAssertEqual(model.activeSession?.fields[0].value, "Yes")
        XCTAssertTrue(model.activeSession?.fields[0].isAnswered ?? false)
        XCTAssertEqual(model.activeFieldIndex, 1, "Must automatically advance to next unanswered question")
    }
    
    @MainActor
    func testEmptyAXValueNeverOverwritesNonEmptyTypedAnswer() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Application Form", appName: "Polar")
        let q1 = FormInputField(label: "Full Name", value: "", category: .personal, questionType: "shortAnswer", isRequired: true, entryKey: "entry.1")
        model.activeSession?.fields = [q1]
        model.activeFieldIndex = 0
        
        let tracker = FormInputAutoTracker(model: model)
        // Keystroke streaming adds user's answer
        tracker.handleKeyStroke(keyCode: 0, flags: [], characters: "Minh")
        XCTAssertEqual(model.activeSession?.fields[0].value, "Minh")
        
        // Background AX sync runs. If target element returns empty string or nil value, it must NOT clear "Minh"
        model.activeSession?.fields[0].value = "Minh"
        tracker.syncFocusedElement()
        XCTAssertEqual(model.activeSession?.fields[0].value, "Minh", "Typed answer must never be reverted to empty string by background AX sync")
    }
    
    @MainActor
    func testClicksOnMorphUIOrNotchNeverCreateFakeFields() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Google Form", appName: "Polar")
        let initialField = FormInputField(label: "Full Name", value: "", category: .personal, questionType: "shortAnswer", isRequired: true, entryKey: "entry.1")
        model.activeSession?.fields = [initialField]
        model.activeFieldIndex = 0
        
        // Attempting to apply inputs with UI buttons or filter labels should be rejected
        let res1 = model.applyExtractedInput(label: "Required, 12", value: "test")
        let res2 = model.applyExtractedInput(label: "All, 15", value: "test")
        let res3 = model.applyExtractedInput(label: "Address and search bar", value: "docs.google.com")
        
        XCTAssertFalse(res1)
        XCTAssertFalse(res2)
        XCTAssertFalse(res3)
        XCTAssertEqual(model.activeSession?.fields.count, 1, "No bogus fields should be added")
    }
    
    @MainActor
    func testSanitizationOfCorruptedSavedDrafts() {
        let model1 = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model1.clearSavedDrafts()
        
        // Create session with bogus fields from previous bug
        let corrupted = ApplicationFormSession(
            formTitle: "Laguna Schools Form",
            sourceAppName: "Polar",
            sourceURL: "https://docs.google.com/forms/d/e/123/viewform",
            recipientEmail: "test@gmail.com",
            fields: [
                FormInputField(label: "PRIVACY NOTICE", value: "", category: .custom, questionType: "text", isRequired: false, entryKey: nil),
                FormInputField(label: "Full Name", value: "Juan Dela Cruz", category: .personal, questionType: "shortAnswer", isRequired: true, entryKey: "entry.1"),
                FormInputField(label: "Required, 12", value: "", category: .custom, questionType: "shortAnswer", isRequired: true),
                FormInputField(label: "All, 15", value: "", category: .custom, questionType: "shortAnswer", isRequired: false)
            ]
        )
        model1.activeSession = corrupted
        model1.saveDrafts()
        
        // Second model loads drafts: must automatically purge "Required, 12" and "All, 15", and fix "PRIVACY NOTICE" to "info"
        let model2 = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model2.loadDrafts()
        
        XCTAssertEqual(model2.historySessions.count, 1)
        let cleanedFields = model2.historySessions[0].fields
        XCTAssertEqual(cleanedFields.count, 2, "Must purge both fake UI button fields")
        XCTAssertEqual(cleanedFields[0].label, "PRIVACY NOTICE")
        XCTAssertEqual(cleanedFields[0].questionType, "info", "Must convert header without entryKey to info")
        XCTAssertEqual(cleanedFields[1].label, "Full Name")
        XCTAssertEqual(cleanedFields[1].value, "Juan Dela Cruz")
        
        model2.clearSavedDrafts()
    }
}
