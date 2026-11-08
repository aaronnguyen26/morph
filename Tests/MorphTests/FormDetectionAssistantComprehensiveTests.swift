import XCTest
import SwiftUI
import WebKit
@testable import morph

@MainActor
final class FormDetectionAssistantComprehensiveTests: XCTestCase {

    var model: NotchModel!
    var formTracker: ApplicationFormModel!
    var supabase: SupabaseService!

    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: ApplicationFormModel.draftsStorageKey)
        UserDefaults.standard.removeObject(forKey: "com.morph.form.saved_copies")
        UserDefaults.standard.removeObject(forKey: "com.morph.form.profile_answers")
        UserDefaults.standard.removeObject(forKey: "com.morph.supabase.cached_memory_items")
        UserDefaults.standard.removeObject(forKey: "com.morph.supabase.form_receipts_cache")

        supabase = SupabaseService.shared
        supabase.memoryItems.removeAll()
        supabase.formReceipts.removeAll()

        formTracker = ApplicationFormModel()
        formTracker.savedFormCopies.removeAll()
        formTracker.historySessions.removeAll()
        formTracker.profileAnswers = [
            "Full Name": "Alex Morgan",
            "Email Address": "alex.morgan@fellowship.ai",
            "GitHub / Portfolio": "https://github.com/alexmorgan",
            "Primary Track": "Computer Vision & Generative Interfaces",
            "Bio / Statement of Purpose": "Passionate about spatial computing, ambient HUDs, and real-time interaction design."
        ]

        model = NotchModel(supabase: supabase, formTracker: formTracker)
        model.isGlassIslandEnabled = true
        model.setGlassIslandState(.idle)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: ApplicationFormModel.draftsStorageKey)
        UserDefaults.standard.removeObject(forKey: "com.morph.form.saved_copies")
        UserDefaults.standard.removeObject(forKey: "com.morph.form.profile_answers")
        UserDefaults.standard.removeObject(forKey: "com.morph.supabase.cached_memory_items")
        UserDefaults.standard.removeObject(forKey: "com.morph.supabase.form_receipts_cache")

        model = nil
        formTracker = nil
        supabase = nil
        try await super.tearDown()
    }

    // MARK: - Mock Application Form HTML
    // Synthesizes a realistic, comprehensive multi-type web application form without relying on external network
    private static let mockFellowshipFormHTML = """
    <!DOCTYPE html>
    <html>
    <head>
      <title>2026 AI Innovators Fellowship Application - Google Forms</title>
    </head>
    <body>
      <div role="list">
        <!-- Section Header / Description (Non-actionable info) -->
        <div role="listitem" id="header">
          <div role="heading">2026 AI Innovators Fellowship Application</div>
          <div>Please fill out all required fields before the priority deadline.</div>
        </div>

        <!-- 1. Text Field: Applicant Full Name -->
        <div role="listitem" id="q_name">
          <div role="heading">Full Name <span>*</span></div>
          <input type="text" class="whsOnd" aria-label="Full Name" value="">
        </div>

        <!-- 2. Email Field: Contact Email -->
        <div role="listitem" id="q_email">
          <div role="heading">Email Address <span>*</span></div>
          <input type="email" class="whsOnd" aria-label="Email Address" value="">
        </div>

        <!-- 3. Radio Group / Multiple Choice: Track -->
        <div role="listitem" id="q_track">
          <div role="heading">Primary Track *</div>
          <div role="radiogroup">
            <div role="radio" aria-checked="false" data-value="Computer Vision & Generative Interfaces">Computer Vision & Generative Interfaces</div>
            <div role="radio" aria-checked="false" data-value="Large Language Models & Reasoning">Large Language Models & Reasoning</div>
            <div role="radio" aria-checked="false" data-value="Robotics & Embodied AI">Robotics & Embodied AI</div>
          </div>
        </div>

        <!-- 4. Checkboxes: Programming Languages -->
        <div role="listitem" id="q_skills">
          <div role="heading">Core Languages Known</div>
          <div role="group">
            <div role="checkbox" aria-checked="false" data-answer-value="Swift" aria-label="Swift">Swift</div>
            <div role="checkbox" aria-checked="false" data-answer-value="Python" aria-label="Python">Python</div>
            <div role="checkbox" aria-checked="false" data-answer-value="Rust" aria-label="Rust">Rust</div>
            <div role="checkbox" aria-checked="false" data-answer-value="TypeScript" aria-label="TypeScript">TypeScript</div>
          </div>
        </div>

        <!-- 5. Dropdown / Listbox: Graduation Year -->
        <div role="listitem" id="q_grad">
          <div role="heading">Anticipated Graduation Year</div>
          <div role="listbox">
            <div role="option" data-value="" aria-selected="true"><span>Choose</span></div>
            <div role="option" data-value="2026" aria-selected="false"><span>2026</span></div>
            <div role="option" data-value="2027" aria-selected="false"><span>2027</span></div>
            <div role="option" data-value="Alumni / Professional" aria-selected="false"><span>Alumni / Professional</span></div>
          </div>
        </div>

        <!-- 6. Textarea: Statement of Purpose -->
        <div role="listitem" id="q_statement">
          <div role="heading">Bio / Statement of Purpose</div>
          <textarea class="KHxj8b" aria-label="Bio / Statement of Purpose"></textarea>
        </div>

        <!-- 7. Date Input: Available Start Date -->
        <div role="listitem" id="q_date">
          <div role="heading">Earliest Available Start Date</div>
          <input type="date" aria-label="Earliest Available Start Date" value="">
        </div>
      </div>
    </body>
    </html>
    """

    private func makeWebView(html: String) async throws -> WKWebView {
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 600, height: 800))
        final class Loader: NSObject, WKNavigationDelegate {
            var continuation: CheckedContinuation<Void, Error>?
            func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { continuation?.resume(); continuation = nil }
            func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { continuation?.resume(throwing: error); continuation = nil }
        }
        let loader = Loader()
        web.navigationDelegate = loader
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            loader.continuation = c
            web.loadHTMLString(html, baseURL: URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSe-mock-fellowship/viewform"))
        }
        objc_setAssociatedObject(web, "loader", loader, .OBJC_ASSOCIATION_RETAIN)
        return web
    }

    // MARK: - Comprehensive End-to-End Test Case

    func testFormDetectionAssistantCompleteEndToEndFlow() async throws {
        let formTitle = "2026 AI Innovators Fellowship Application - Google Forms"
        let formURL = "https://docs.google.com/forms/d/e/1FAIpQLSe-mock-fellowship/viewform"

        // ---------------------------------------------------------------------
        // STEP 1: DETECTION & PLATFORM CLASSIFICATION
        // Verify Morph recognizes the active browser window as an application form,
        // cleans the title, and rejects developer IDE noise.
        // ---------------------------------------------------------------------
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle(formTitle))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormURL(formURL))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("ApplicationFormModel.swift - morph"))
        XCTAssertFalse(DefaultApplicationFormDetector.isNonFormApplication(bundleID: "com.google.Chrome", appName: "Google Chrome"))

        let cleanedTitle = DefaultApplicationFormDetector.cleanTitle(formTitle)
        XCTAssertEqual(cleanedTitle, "2026 AI Innovators Fellowship Application - Google Forms")

        // Trigger detection on the model
        formTracker.startTracking(title: formTitle, appName: "Google Chrome", url: formURL)
        XCTAssertTrue(formTracker.isFormDetected)
        XCTAssertEqual(formTracker.detectedFormTitle, formTitle)
        XCTAssertEqual(formTracker.detectedAppName, "Google Chrome")
        XCTAssertEqual(formTracker.detectedURL, formURL)

        // Verify Dynamic Island HUD adopts form context
        XCTAssertTrue(model.isBackgroundFormActive)
        XCTAssertEqual(model.compactHUDMode, .formTrackerActive)

        // ---------------------------------------------------------------------
        // STEP 2: DOM EXTRACTION VIA WEBKIT INJECTED SCRIPT
        // Run FormInputAutoTracker.domExtractionScript against our mock DOM.
        // Confirm all 7 actionable question types are extracted with empty answers initially.
        // ---------------------------------------------------------------------
        let webView = try await makeWebView(html: Self.mockFellowshipFormHTML)
        let rawExtraction = try await webView.evaluateJavaScript(FormInputAutoTracker.domExtractionScript)
        let extractionOutput = try XCTUnwrap(rawExtraction as? String)
        let parsedPairs = FormInputAutoTracker.parseDOMExtractionOutput(extractionOutput)

        let initialDict = Dictionary(parsedPairs.map { ($0.label, $0.value) }, uniquingKeysWith: { _, last in last })
        XCTAssertEqual(initialDict.count, 7, "All 7 actionable questions must be parsed from DOM")
        XCTAssertEqual(initialDict["Full Name"], "")
        XCTAssertEqual(initialDict["Email Address"], "")
        XCTAssertEqual(initialDict["Primary Track"], "")
        XCTAssertEqual(initialDict["Core Languages Known"], "")
        XCTAssertEqual(initialDict["Anticipated Graduation Year"], "")
        XCTAssertEqual(initialDict["Bio / Statement of Purpose"], "")
        XCTAssertEqual(initialDict["Earliest Available Start Date"], "")

        // Non-actionable header was excluded from input items
        XCTAssertNil(initialDict["2026 AI Innovators Fellowship Application"])

        // Apply DOM schema to Morph's active session
        for pair in parsedPairs {
            formTracker.addField(label: pair.label, value: pair.value)
        }
        XCTAssertEqual(formTracker.activeSession?.fields.count, 7)
        XCTAssertEqual(formTracker.activeSession?.answeredCount, 0)

        // ---------------------------------------------------------------------
        // STEP 3: LIVE USER TYPING & SYNCHRONOUS INGESTION
        // Simulate user interacting with the web form in the browser:
        // typing name, selecting radio, checking skills, picking dropdown, setting date.
        // ---------------------------------------------------------------------
        _ = try await webView.evaluateJavaScript("""
        document.querySelector('#q_name input').value = 'Alex Morgan';
        document.querySelector('#q_email input').value = 'alex.morgan@fellowship.ai';
        document.querySelector('#q_track [data-value="Computer Vision & Generative Interfaces"]').setAttribute('aria-checked', 'true');
        document.querySelector('#q_skills [data-answer-value="Swift"]').setAttribute('aria-checked', 'true');
        document.querySelector('#q_skills [data-answer-value="Python"]').setAttribute('aria-checked', 'true');
        var gradOpts = document.querySelectorAll('#q_grad [role=option]');
        gradOpts[0].setAttribute('aria-selected', 'false');
        gradOpts[1].setAttribute('aria-selected', 'true');
        document.querySelector('#q_statement textarea').value = 'Building seamless desktop ambient interfaces.';
        document.querySelector('#q_date input').value = '2026-06-01';
        true;
        """)

        let liveExtraction = try await webView.evaluateJavaScript(FormInputAutoTracker.domExtractionScript)
        let livePairs = FormInputAutoTracker.parseDOMExtractionOutput(try XCTUnwrap(liveExtraction as? String))
        let changed = formTracker.applyLiveSnapshot(livePairs)

        XCTAssertGreaterThanOrEqual(changed, 7)
        guard let session = formTracker.activeSession else {
            XCTFail("Active session must exist")
            return
        }

        XCTAssertEqual(session.fields.first { $0.label == "Full Name" }?.value, "Alex Morgan")
        XCTAssertEqual(session.fields.first { $0.label == "Email Address" }?.value, "alex.morgan@fellowship.ai")
        XCTAssertEqual(session.fields.first { $0.label == "Primary Track" }?.value, "Computer Vision & Generative Interfaces")
        XCTAssertEqual(session.fields.first { $0.label == "Core Languages Known" }?.value, "Swift, Python")
        XCTAssertEqual(session.fields.first { $0.label == "Anticipated Graduation Year" }?.value, "2026")
        XCTAssertEqual(session.fields.first { $0.label == "Bio / Statement of Purpose" }?.value, "Building seamless desktop ambient interfaces.")
        XCTAssertEqual(session.fields.first { $0.label == "Earliest Available Start Date" }?.value, "2026-06-01")
        XCTAssertEqual(session.answeredCount, 7)
        XCTAssertEqual(session.completionPercentage, 100)

        // ---------------------------------------------------------------------
        // STEP 4: STEALTH CAPSULE HOVER & HUD QUESTIONS INSPECTION
        // Hovering onto Morph routes into the live forms view (.live)
        // ---------------------------------------------------------------------
        XCTAssertEqual(model.contextualOpenState, .forms)
        model.setGlassIslandState(model.contextualOpenState)
        XCTAssertEqual(model.glassIslandState, .forms)
        XCTAssertEqual(model.glassFormMode, .live)

        // In live view, all questions and user answers are displayed
        let liveFields = model.formTracker.activeSession?.fields ?? []
        XCTAssertEqual(liveFields.count, 7)
        XCTAssertEqual(liveFields[0].value, "Alex Morgan")

        // ---------------------------------------------------------------------
        // STEP 5: AUTOFILL MEMORY RESOLUTION
        // Verify resolveSavedInput accurately resolves answers from user profile memory
        // ---------------------------------------------------------------------
        let nameField = FormInputField(label: "Full Name", value: "")
        let resolvedName = formTracker.resolveSavedInput(for: nameField)
        XCTAssertEqual(resolvedName, "Alex Morgan")

        let trackField = FormInputField(label: "Primary Track", value: "")
        let resolvedTrack = formTracker.resolveSavedInput(for: trackField)
        XCTAssertEqual(resolvedTrack, "Computer Vision & Generative Interfaces")

        // ---------------------------------------------------------------------
        // STEP 6: SNAPSHOT CAPTURE, RECEIPT GENERATION & SUPABASE ARCHIVAL
        // Click Save Snapshot: generates Markdown receipt, stores locally, and syncs to Supabase.
        // ---------------------------------------------------------------------
        let savedRecord = formTracker.saveFormSnapshot(flashLabel: true)
        XCTAssertNotNil(savedRecord)
        XCTAssertEqual(savedRecord?.formTitle, formTitle)
        XCTAssertEqual(savedRecord?.answers["Full Name"], "Alex Morgan")
        XCTAssertEqual(savedRecord?.answers["Email Address"], "alex.morgan@fellowship.ai")
        XCTAssertEqual(savedRecord?.answers["Core Languages Known"], "Swift, Python")

        // Check Markdown receipt formatting
        let markdownSummary = formTracker.activeSession?.formattedSummary ?? ""
        XCTAssertTrue(markdownSummary.contains("2026 AI Innovators Fellowship Application"))
        XCTAssertTrue(markdownSummary.contains("Alex Morgan"))
        XCTAssertTrue(markdownSummary.contains("alex.morgan@fellowship.ai"))
        XCTAssertTrue(markdownSummary.contains("Computer Vision & Generative Interfaces"))

        // Check archival to Supabase Memory Store
        let memory = supabase.memoryItems.first(where: { $0.id == savedRecord?.id })
        XCTAssertNotNil(memory)
        XCTAssertEqual(memory?.kind, "form")
        XCTAssertEqual(memory?.title, formTitle)
        XCTAssertTrue(memory?.body.contains("Alex Morgan") ?? false)
        XCTAssertTrue(memory?.body.contains("alex.morgan@fellowship.ai") ?? false)

        // ---------------------------------------------------------------------
        // STEP 7: RETRIEVAL FROM PROMPT BAR & COPIES TAB
        // Search for the saved application form in the prompt bar
        // ---------------------------------------------------------------------
        model.submitGlassIslandPrompt("Fellowship Application")
        XCTAssertEqual(model.glassIslandState, .forms)
        XCTAssertEqual(model.glassFormMode, .copies)
        XCTAssertTrue(model.isFormCopyDetailOpen)
        XCTAssertEqual(model.selectedFormCopyId, savedRecord?.id)

        // Confirm copy detail contains all answers
        let selectedCopy = model.formTracker.savedFormCopies.first(where: { $0.id == model.selectedFormCopyId })
        XCTAssertNotNil(selectedCopy)
        XCTAssertEqual(selectedCopy?.answers["Primary Track"], "Computer Vision & Generative Interfaces")
        XCTAssertEqual(selectedCopy?.answers["Anticipated Graduation Year"], "2026")
    }
}
