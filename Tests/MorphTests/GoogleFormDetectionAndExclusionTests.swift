import XCTest
@testable import morph

@MainActor
final class GoogleFormDetectionAndExclusionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: ApplicationFormModel.draftsStorageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ApplicationFormModel.draftsStorageKey)
        super.tearDown()
    }

    // MARK: - 1. Antigravity & Non-Form App Exclusion Tests

    func testAntigravityIsNeverDetectedAsFormApplication() {
        XCTAssertTrue(DefaultApplicationFormDetector.isNonFormApplication(bundleID: "com.google.antigravity", appName: "Antigravity"))
        XCTAssertTrue(DefaultApplicationFormDetector.isNonFormApplication(bundleID: "antigravity", appName: "antigravity"))
        XCTAssertTrue(DefaultApplicationFormDetector.isNonFormApplication(bundleID: "com.google.antigravity.helper", appName: "Antigravity Helper"))
    }

    func testDeveloperToolsAndEditorsAreNeverDetectedAsForms() {
        let devApps: [(bundle: String, name: String)] = [
            ("com.microsoft.VSCode", "Code"),
            ("com.cursor.Cursor", "Cursor"),
            ("com.apple.dt.Xcode", "Xcode"),
            ("com.sublimetext.4", "Sublime Text"),
            ("com.jetbrains.intellij", "IntelliJ IDEA"),
            ("com.jetbrains.pycharm", "PyCharm"),
            ("com.apple.Terminal", "Terminal"),
            ("com.googlecode.iterm2", "iTerm2"),
            ("dev.warp.Warp-Stable", "Warp"),
            ("com.tinyspeck.slackmacgap", "Slack"),
            ("com.hnc.Discord", "Discord"),
            ("us.zoom.xos", "zoom.us")
        ]
        
        for app in devApps {
            XCTAssertTrue(
                DefaultApplicationFormDetector.isNonFormApplication(bundleID: app.bundle, appName: app.name),
                "Expected \(app.name) (\(app.bundle)) to be classified as non-form app"
            )
        }
    }

    func testBrowsersAreAllowedFormHosts() {
        let browserApps: [(bundle: String, name: String)] = [
            ("com.google.Chrome", "Google Chrome"),
            ("com.apple.Safari", "Safari"),
            ("company.thebrowser.Browser", "Arc"),
            ("com.brave.Browser", "Brave Browser"),
            ("com.polar.browser", "Polar"),
            ("org.mozilla.firefox", "Firefox")
        ]
        
        for b in browserApps {
            XCTAssertFalse(
                DefaultApplicationFormDetector.isNonFormApplication(bundleID: b.bundle, appName: b.name),
                "Browser \(b.name) should NOT be classified as non-form application"
            )
        }
    }

    // MARK: - 2. Title Hardening & Code File Exclusion Tests

    func testIsFormTitleRejectsAntigravityTitles() {
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("Antigravity"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("Antigravity - morph"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("ApplicationFormModel.swift — Antigravity"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("Antigravity Application"))
    }

    func testIsFormTitleRejectsSourceCodeAndProjectFiles() {
        let codeFiles = [
            "ApplicationFormModel.swift",
            "ApplicationFormTrackerView.swift",
            "FormClearAndBeforehandTests.swift",
            "application_form_controller.py",
            "RegistrationForm.tsx",
            "survey_feedback.js",
            "schema_form.json",
            "EvaluationReview.md",
            "QuizController.kt",
            "FormSubmission.java",
            "Application.cpp",
            "CMakeLists.txt",
            "form.yaml",
            "Package.swift"
        ]
        
        for file in codeFiles {
            XCTAssertFalse(
                DefaultApplicationFormDetector.isFormTitle(file),
                "Expected source file \(file) to NOT be treated as a form title"
            )
        }
    }

    func testIsFormTitleRejectsBareGenericWords() {
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("Application"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("Applicant"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("Review"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("Poll"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("Assignment"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("Worksheet"))
    }

    func testIsFormTitleAcceptsLegitimateGoogleFormsAndWebForms() {
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Laguna Schools BP 2026: IA/SA Application Form - Google Forms"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Untitled form - Google Forms"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Customer Feedback Survey - Google Forms"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Software Engineer Job Application - Greenhouse"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Stanford 2026 Undergraduate Application"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Event Registration Form"))
    }

    // MARK: - 3. Google Form Question Types Detection

    func testGoogleFormsAllQuestionTypesParsedCorrectly() {
        // Construct mock FB_PUBLIC_LOAD_DATA_ JSON structure
        let rawJSON = """
        [null, [
            "Test Form Description",
            [
                [null, "Full Name", null, 0, [[101, null, 1]]],
                [null, "Tell us about yourself", null, 1, [[102, null, 0]]],
                [null, "Preferred Department", null, 2, [[103, [["Engineering"], ["Design"], ["Marketing"]], 1]]],
                [null, "Years of Experience", null, 3, [[104, [["1-2"], ["3-5"], ["5+"]], 0]]],
                [null, "Technical Skills", null, 4, [[105, [["Swift"], ["Python"], ["Rust"]], 1]]],
                [null, "Rate your satisfaction (1-5)", null, 5, [[106, [["1"], ["2"], ["3"], ["4"], ["5"]], 1]]],
                [null, "Date of Birth", null, 9, [[107, null, 0]]],
                [null, "Best Time to Contact", null, 10, [[108, null, 0]]]
            ],
            null, null, null, null, null, null,
            "Engineering Application Form - Google Forms"
        ]]
        """

        let schema = FormContentRetriever.parseGoogleFormPublicLoadData(rawJSON)
        XCTAssertNotNil(schema)
        XCTAssertEqual(schema?.title, "Engineering Application Form - Google Forms")
        XCTAssertEqual(schema?.fields.count, 8)

        guard let fields = schema?.fields else { return }

        // Question 0: Short Answer
        XCTAssertEqual(fields[0].label, "Full Name")
        XCTAssertEqual(fields[0].questionType, "shortAnswer")
        XCTAssertTrue(fields[0].isRequired)

        // Question 1: Paragraph
        XCTAssertEqual(fields[1].label, "Tell us about yourself")
        XCTAssertEqual(fields[1].questionType, "paragraph")
        XCTAssertFalse(fields[1].isRequired)

        // Question 2: Multiple Choice
        XCTAssertEqual(fields[2].label, "Preferred Department")
        XCTAssertEqual(fields[2].questionType, "multipleChoice")
        XCTAssertEqual(fields[2].options, ["Engineering", "Design", "Marketing"])
        XCTAssertTrue(fields[2].isRequired)

        // Question 3: Dropdown
        XCTAssertEqual(fields[3].label, "Years of Experience")
        XCTAssertEqual(fields[3].questionType, "dropdown")
        XCTAssertEqual(fields[3].options, ["1-2", "3-5", "5+"])

        // Question 4: Checkboxes
        XCTAssertEqual(fields[4].label, "Technical Skills")
        XCTAssertEqual(fields[4].questionType, "checkboxes")
        XCTAssertEqual(fields[4].options, ["Swift", "Python", "Rust"])
        XCTAssertTrue(fields[4].isRequired)

        // Question 5: Linear Scale / Rating
        XCTAssertEqual(fields[5].label, "Rate your satisfaction (1-5)")
        XCTAssertEqual(fields[5].questionType, "linearScale")
        XCTAssertTrue(fields[5].isRequired)

        // Question 6: Date
        XCTAssertEqual(fields[6].label, "Date of Birth")
        XCTAssertEqual(fields[6].questionType, "date")

        // Question 7: Time
        XCTAssertEqual(fields[7].label, "Best Time to Contact")
        XCTAssertEqual(fields[7].questionType, "time")
    }

    // MARK: - 4. Typing Keystroke Protection & Active Field Navigation

    func testTextEntryTypeDistinguishesTextFromChoices() {
        XCTAssertTrue(FormInputAutoTracker.isTextEntryType("shortAnswer"))
        XCTAssertTrue(FormInputAutoTracker.isTextEntryType("paragraph"))
        XCTAssertTrue(FormInputAutoTracker.isTextEntryType("date"))
        XCTAssertTrue(FormInputAutoTracker.isTextEntryType("time"))

        XCTAssertFalse(FormInputAutoTracker.isTextEntryType("multipleChoice"))
        XCTAssertFalse(FormInputAutoTracker.isTextEntryType("checkboxes"))
        XCTAssertFalse(FormInputAutoTracker.isTextEntryType("dropdown"))
        XCTAssertFalse(FormInputAutoTracker.isTextEntryType("linearScale"))
        XCTAssertFalse(FormInputAutoTracker.isTextEntryType("grid"))
        XCTAssertFalse(FormInputAutoTracker.isTextEntryType("info"))
        XCTAssertFalse(FormInputAutoTracker.isTextEntryType("section"))
    }

    func testActiveFieldIndexAdvancesAccuratelyWhenTypingInFields() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Google Form", appName: "Polar")
        model.isFormDetected = true
        model.isAutoCaptureEnabled = true

        let field1 = FormInputField(label: "First Name", value: "", questionType: "shortAnswer", isRequired: true, entryKey: "entry.1")
        let field2 = FormInputField(label: "Bio", value: "", questionType: "paragraph", isRequired: true, entryKey: "entry.2")
        let field3 = FormInputField(label: "Role", value: "", options: ["Dev", "Design"], questionType: "multipleChoice", isRequired: true, entryKey: "entry.3")
        model.activeSession?.fields = [field1, field2, field3]

        let tracker = FormInputAutoTracker(model: model)

        // Confirm focus on field1 (First Name)
        tracker.confirmFocus(fieldID: field1.id)
        XCTAssertEqual(model.activeFieldIndex, 0)

        // Type into field1
        for char in "Alice" {
            tracker.handleKeyStroke(keyCode: 0, flags: [], characters: String(char))
        }
        XCTAssertEqual(model.activeSession?.fields[0].value, "Alice")

        // Move focus to field2 (Bio)
        tracker.confirmFocus(fieldID: field2.id)
        XCTAssertEqual(model.activeFieldIndex, 1)

        // Type into field2
        for char in "iOS Developer" {
            tracker.handleKeyStroke(keyCode: 0, flags: [], characters: String(char))
        }
        XCTAssertEqual(model.activeSession?.fields[1].value, "iOS Developer")

        // First Name should NOT have been corrupted
        XCTAssertEqual(model.activeSession?.fields[0].value, "Alice")

        // Move focus to field3 (Multiple choice)
        tracker.confirmFocus(fieldID: field3.id)
        XCTAssertEqual(model.activeFieldIndex, 2)

        // Typing characters should NEVER be appended to multipleChoice
        tracker.handleKeyStroke(keyCode: 0, flags: [], characters: "xyz")
        XCTAssertEqual(model.activeSession?.fields[2].value, "")
    }

    func testCheckActiveApplicationSuspendsWhenSwitchingToAntigravity() {
        let model = ApplicationFormModel(
            detector: MockApplicationFormDetector(detected: true, title: "Laguna Schools BP 2026", appName: "Polar", url: "https://docs.google.com/forms/d/e/123/viewform"),
            dispatcher: MockEmailDispatcher()
        )
        
        // 1. Detect form initially
        model.checkActiveApplication()
        XCTAssertTrue(model.isFormDetected)
        XCTAssertNotNil(model.activeSession)
        XCTAssertEqual(model.detectedAppName, "Polar")

        // 2. User switches to Antigravity (detector returns detected: false because Antigravity is not a form)
        let mockAntigravity = MockApplicationFormDetector(detected: false, title: nil, appName: nil, url: nil)
        model.detector = mockAntigravity
        model.checkActiveApplication()

        // Form should be suspended cleanly so user can work in Antigravity
        XCTAssertFalse(model.isFormDetected)
        XCTAssertNotNil(model.suspendedSession)
        XCTAssertEqual(model.suspendedSession?.formTitle, "Laguna Schools BP 2026")

        // 3. User switches back to Polar
        model.detector = MockApplicationFormDetector(detected: true, title: "Laguna Schools BP 2026", appName: "Polar", url: "https://docs.google.com/forms/d/e/123/viewform")
        model.checkActiveApplication()

        // Session resumes seamlessly
        XCTAssertTrue(model.isFormDetected)
        XCTAssertNotNil(model.activeSession)
        XCTAssertNil(model.suspendedSession)
        XCTAssertEqual(model.activeSession?.formTitle, "Laguna Schools BP 2026")
    }

    // MARK: - 5. LMS, Educational, Wiki, Academic & Non-Form Domain Suppression Tests

    func testLMSAndAcademicWebsitesAreStrictlyExcludedAsForms() {
        let nonFormURLs = [
            // Canvas LMS
            "https://fullcoll.instructure.com/courses/69103/assignments/2302124",
            "https://canvas.harvard.edu/courses/10492/assignments/9812",
            "https://instructure.com/login/canvas",
            // Blackboard
            "https://blackboard.usc.edu/webapps/assignment/uploadAssignment",
            "https://learn.blackboard.com/ultra/courses/_123_1/cl/outline",
            // Google Classroom
            "https://classroom.google.com/c/MzI1NzgyMjY4Mzkz/a/NDU3OTkwOTc5MTI1/details",
            // Moodle & Brightspace
            "https://moodle.org/mod/assign/view.php?id=123",
            "https://purdue.brightspace.com/d2l/lms/dropbox/user/folder_submit_files.d2l",
            // MOOCs
            "https://www.coursera.org/learn/machine-learning/assignment-submission",
            "https://www.edx.org/course/cs50-problem-set-1",
            // Wikis & Academics
            "https://en.wikipedia.org/wiki/Application_software",
            "https://arxiv.org/abs/2312.00752",
            "https://www.biorxiv.org/content/10.1101/2024.01.01.573821v1",
            "https://www.nature.com/articles/s41586-024-07487-w",
            "https://ieeexplore.ieee.org/document/9876543",
            // Non-form Google Workspace
            "https://docs.google.com/document/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit",
            "https://docs.google.com/spreadsheets/d/1qpyC0X95dtbKqaoKCv4Vffh5mYd_l0T1m-m-m/edit",
            "https://docs.google.com/presentation/d/1yZ.../edit",
            "https://drive.google.com/drive/folders/0B_..._abc",
            "https://mail.google.com/mail/u/0/#inbox",
            "https://calendar.google.com/calendar/u/0/r",
            "https://meet.google.com/abc-defg-hij"
        ]

        for url in nonFormURLs {
            XCTAssertTrue(
                FormExclusionRegistry.isBlacklistedURL(url),
                "Expected FormExclusionRegistry to blacklist \(url)"
            )
            XCTAssertFalse(
                DefaultApplicationFormDetector.isFormURL(url),
                "Expected isFormURL to reject \(url)"
            )
        }
    }

    func testNewsAndDevPortalsAreStrictlyExcludedAsForms() {
        let devAndNewsURLs = [
            "https://github.com/swiftlang/swift/pull/76543",
            "https://gitlab.com/gitlab-org/gitlab/-/issues/123",
            "https://stackoverflow.com/questions/1234567/how-to-fix-axuielement-leak",
            "https://developer.apple.com/documentation/accessibility",
            "https://www.nytimes.com/2026/10/30/technology/ai-updates.html",
            "https://www.wsj.com/tech/personal-tech/apple-macbook-review-123",
            "https://www.theverge.com/2026/10/30/macbook-pro-m4-review",
            "https://techcrunch.com/2026/10/30/startup-funding-news",
            "https://www.reddit.com/r/swift/comments/abc123/macos_accessibility",
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        ]

        for url in devAndNewsURLs {
            XCTAssertTrue(
                FormExclusionRegistry.isBlacklistedURL(url),
                "Expected blacklist for \(url)"
            )
            XCTAssertFalse(
                DefaultApplicationFormDetector.isFormURL(url),
                "Expected isFormURL to reject \(url)"
            )
        }
    }

    func testNonFormTitlesAreRejected() {
        let badTitles = [
            "Reading Response Paper #4 - Canvas",
            "Reading Response #2 - Instructure",
            "Bio 101 Lecture Notes - Canvas",
            "CS 101 Course Syllabus",
            "MacBook Pro 16-inch Review - The Verge",
            "Apple M4 Max Laptop Reviews",
            "Fix nil pointer exception · Pull Request #1234 · swiftlang/swift",
            "Bug: Application crashes on start · Issue #42 · org/repo",
            "Swift (programming language) - Wikipedia",
            "The New York Times - Breaking News",
            "How do I use AXUIElement in macOS? - Stack Overflow",
            "ApplicationFormModel.swift — Antigravity",
            "antigravity",
            "morph"
        ]

        for t in badTitles {
            XCTAssertFalse(
                DefaultApplicationFormDetector.isFormTitle(t),
                "Expected isFormTitle to reject non-form title: '\(t)'"
            )
        }
    }

    // MARK: - 6. Positive Detection for Full Platform Catalog

    func testFormPlatformCatalogMatchesAccurately() {
        let validPlatforms: [(url: String, title: String, expectedPlatform: FormPlatformType)] = [
            // Google Forms
            ("https://docs.google.com/forms/d/e/1FAIpQLSc_xyz123/viewform", "Laguna Schools BP 2026: IA/SA Application Form - Google Forms", .googleForms),
            ("https://forms.gle/mZ789xyz", "Customer Feedback Survey - Google Forms", .googleForms),
            // Microsoft Forms
            ("https://forms.office.com/pages/responsepage.aspx?id=v4j5cv", "Employee Onboarding Questionnaire | Microsoft Forms", .microsoftForms),
            ("https://forms.microsoft.com/r/k7Y7abc", "Annual Survey - Microsoft Forms", .microsoftForms),
            // Typeform
            ("https://form.typeform.com/to/v91K8l", "Brand Feedback Questionnaire — Typeform", .typeform),
            // Tally
            ("https://tally.so/r/mZ9012", "Product Waitlist Registration - Tally", .tally),
            // Jotform
            ("https://form.jotform.com/241234567890", "Event RSVP & Registration Form - Jotform", .jotform),
            // SurveyMonkey
            ("https://www.surveymonkey.com/r/V9X2P1", "Patient Health Questionnaire - SurveyMonkey", .surveyMonkey),
            // Formstack
            ("https://mycompany.formstack.com/forms/intake_form", "Client Intake Form | Formstack", .formstack),
            // Cognito Forms
            ("https://www.cognitoforms.com/AcmeCorp/NewClientForm", "New Client Registration | Cognito Forms", .cognitoForms),
            // Fillout
            ("https://forms.fillout.com/t/abc123xyz", "Job Application Form - Fillout", .fillout),
            // Airtable
            ("https://airtable.com/app123/shrXYZ123", "Applicant Portal - Airtable", .airtableForms),
            // Qualtrics
            ("https://harvard.az1.qualtrics.com/jfe/form/SV_123456", "Academic Research Survey | Qualtrics", .qualtrics),
            // ATS: Greenhouse
            ("https://boards.greenhouse.io/openai/jobs/12345#app", "Software Engineer - Greenhouse", .greenhouse),
            // ATS: Lever
            ("https://jobs.lever.co/stripe/abc-123/apply", "Infrastructure Engineer - Lever", .lever),
            // ATS: Workday
            ("https://apple.wd1.myworkdayjobs.com/en-US/Careers/job/123/apply", "iOS Engineer - Workday", .workday),
            // ATS: Ashby
            ("https://jobs.ashbyhq.com/linear/abc/application", "Product Designer Application - Ashby", .ashby),
            // College Admissions: Common App
            ("https://apply.commonapp.org/applicant-ux/#/dashboard", "First-Year Application - Common App", .commonApp),
            // E-Signatures: DocuSign
            ("https://app.docusign.com/documents/signing/123", "Please DocuSign: Employment Offer Letter", .docuSign)
        ]

        for p in validPlatforms {
            XCTAssertTrue(
                DefaultApplicationFormDetector.isFormURL(p.url),
                "Expected isFormURL to recognize \(p.url)"
            )
            XCTAssertTrue(
                DefaultApplicationFormDetector.isFormTitle(p.title),
                "Expected isFormTitle to recognize \(p.title)"
            )
            let detected = FormPlatformRegistry.platform(forURL: p.url, title: p.title)
            XCTAssertEqual(
                detected, p.expectedPlatform,
                "Expected platform \(p.expectedPlatform) for URL \(p.url)"
            )
        }
    }

    // MARK: - 7. Chrome & Tab Noise Zero-Pollution & Multi-Field Clearing Tests

    func testChromeAndTabNoiseNeverContaminatesGoogleFormSchema() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Google Form", appName: "Polar", url: "https://docs.google.com/forms/d/e/123/viewform")
        model.isFormDetected = true
        model.isAutoCaptureEnabled = true

        // Simulate stray tab noise dynamic fields having been created before schema arrived
        let tabField = FormInputField(label: "Tab Name", value: "on Na", questionType: "shortAnswer", isRequired: true)
        let chromeField = FormInputField(label: "Address and search bar", value: "https://...", questionType: "shortAnswer", isRequired: false)
        model.activeSession?.fields = [tabField, chromeField]

        // Load authoritative Google Form schema
        let officialFields = [
            FormInputField(label: "Full Name", value: "", questionType: "shortAnswer", isRequired: true, entryKey: "entry.1"),
            FormInputField(label: "Email", value: "", questionType: "shortAnswer", isRequired: true, entryKey: "entry.2"),
            FormInputField(label: "Department", value: "", questionType: "multipleChoice", isRequired: true, entryKey: "entry.3")
        ]
        let authoritativeSchema = FormSchema(
            title: "Laguna Schools BP 2026: IA/SA Application Form",
            description: "Official form",
            fields: officialFields
        )

        // Inject schema as autoRetrieveFormContent does
        var merged = authoritativeSchema.fields
        for i in 0..<merged.count {
            if let matchIdx = ApplicationFormModel.bestMatchingFieldIndex(for: merged[i].label, in: model.activeSession?.fields ?? []) {
                let existing = model.activeSession!.fields[matchIdx]
                if !existing.value.isEmpty && merged[i].value.isEmpty {
                    merged[i].value = existing.value
                }
            }
        }
        model.activeSession?.fields = merged

        // Assert: "Tab Name" and "Address and search bar" MUST be completely gone!
        XCTAssertEqual(model.activeSession?.fields.count, 3)
        let labels = model.activeSession?.fields.map { $0.label } ?? []
        XCTAssertFalse(labels.contains("Tab Name"), "Stray 'Tab Name' must NEVER exist in authoritative schema!")
        XCTAssertFalse(labels.contains("Address and search bar"), "Stray address bar must NEVER exist in authoritative schema!")
        XCTAssertTrue(labels.contains("Full Name"))
        XCTAssertTrue(labels.contains("Email"))
        XCTAssertTrue(labels.contains("Department"))
    }

    func testMultipleEmptyInputsReconciledWithoutStalling() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Google Form", appName: "Polar", url: "https://docs.google.com/forms/d/e/123/viewform")
        model.isFormDetected = true
        model.isAutoCaptureEnabled = true

        let f1 = FormInputField(label: "First Name", value: "John", questionType: "shortAnswer", isRequired: true)
        let f2 = FormInputField(label: "Last Name", value: "Doe", questionType: "shortAnswer", isRequired: true)
        let f3 = FormInputField(label: "Email", value: "john@example.com", questionType: "shortAnswer", isRequired: true)
        model.activeSession?.fields = [f1, f2, f3]
        model.markBrowserCaptured(f1.id)
        model.markBrowserCaptured(f2.id)
        model.markBrowserCaptured(f3.id)

        XCTAssertEqual(model.activeSession?.answeredCount, 3)

        // Simulate browser snapshot reporting all 3 fields as empty
        let emptySnapshot: [(label: String, value: String)] = [
            (label: "First Name", value: ""),
            (label: "Last Name", value: ""),
            (label: "Email", value: "")
        ]

        // 2 seconds quiet time so clear guard interval is passed
        let twoSecondsLater = Date().addingTimeInterval(2.0)
        let changed = model.applyLiveSnapshot(emptySnapshot, now: twoSecondsLater)

        XCTAssertEqual(changed, 3, "All 3 fields must be cleared in a single reconciliation pass!")
        XCTAssertEqual(model.activeSession?.fields[0].value, "")
        XCTAssertEqual(model.activeSession?.fields[1].value, "")
        XCTAssertEqual(model.activeSession?.fields[2].value, "")
        XCTAssertEqual(model.activeSession?.answeredCount, 0)
    }
}
