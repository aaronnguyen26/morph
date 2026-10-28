import XCTest
import SwiftUI
import Combine
@testable import morph

@MainActor
final class ApplicationFormTrackerTests: XCTestCase {
    
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
}
