import XCTest
import WebKit
@testable import morph

@MainActor
final class RealtimeAndCompleteFormDetectionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: ApplicationFormModel.draftsStorageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ApplicationFormModel.draftsStorageKey)
        super.tearDown()
    }

    private func makeWebView(html: String, baseURL: String = "https://docs.google.com/forms/d/e/1FAIpQLSe_realtime_test/viewform") async throws -> WKWebView {
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 600, height: 800))
        final class Loader: NSObject, WKNavigationDelegate {
            var continuation: CheckedContinuation<Void, Error>?
            func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                continuation?.resume()
                continuation = nil
            }
            func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
                continuation?.resume(throwing: error)
                continuation = nil
            }
        }
        let loader = Loader()
        web.navigationDelegate = loader
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            loader.continuation = c
            web.loadHTMLString(html, baseURL: URL(string: baseURL))
        }
        objc_setAssociatedObject(web, "loader", loader, .OBJC_ASSOCIATION_RETAIN)
        return web
    }

    private func runExtractionItems(_ web: WKWebView) async throws -> [ExtractedInputItem] {
        let result = try await web.evaluateJavaScript(FormInputAutoTracker.domExtractionScript)
        let raw = try XCTUnwrap(result as? String, "domExtractionScript must return a string")
        return FormInputAutoTracker.parseDOMExtractionItems(raw)
    }

    private func buildSyntheticBlinkBuffer(formSig: String, controls: [(name: String, type: String, value: String)]) -> Data {
        var strings: [String] = ["Blink serialized form state version 10", formSig, String(controls.count)]
        for c in controls {
            strings.append(c.name)
            strings.append(c.type)
            strings.append("1")
            strings.append(c.value)
        }
        var data = Data()
        let mojoHeader = Data([0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                               0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        for s in strings {
            data.append(mojoHeader)
            let utf16 = s.data(using: .utf16LittleEndian) ?? Data()
            var charLen = UInt32(utf16.count / 2)
            var byteLen = UInt32(8 + utf16.count)
            withUnsafeBytes(of: &byteLen) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: &charLen) { data.append(contentsOf: $0) }
            data.append(utf16)
            let alignedTotal = (8 + utf16.count + 7) & ~7
            let pad = alignedTotal - (8 + utf16.count)
            if pad > 0 { data.append(Data(repeating: 0, count: pad)) }
        }
        return data
    }

    // MARK: - 1. Clean Reopen vs Live Browser State (Zero Stale Answer Leakage)

    func testReopeningFormViaCheckActiveAndStartTrackingClearsPreviousAnswersAndPreservesSchema() {
        let formAURL = "https://docs.google.com/forms/d/e/1FAIpQLSe_form_a/viewform"
        let formBURL = "https://docs.google.com/forms/d/e/1FAIpQLSe_form_b/viewform"

        let detector = MockApplicationFormDetector(
            detected: true,
            title: "Fellowship Intake",
            appName: "Google Chrome",
            url: formAURL
        )
        let model = ApplicationFormModel(detector: detector, dispatcher: MockEmailDispatcher())
        model.checkActiveApplication()

        model.activeSession?.fields = [
            FormInputField(label: "Full Name", value: "Alice Rivera", category: .personal, options: [], questionType: "shortAnswer", isRequired: true, entryKey: "entry.1"),
            FormInputField(label: "Track", value: "Systems", category: .question, options: ["Systems", "ML"], questionType: "multipleChoice", isRequired: true, entryKey: "entry.2"),
            FormInputField(label: "Portfolio URL", value: "https://alice.dev", category: .contact, questionType: "shortAnswer", entryKey: "entry.3")
        ]
        model.updateFieldByIndex(0, value: "Alice Rivera")

        // Navigate to Form B so Form A gets archived into historySessions
        model.detector = MockApplicationFormDetector(detected: true, title: "Other Form", appName: "Google Chrome", url: formBURL)
        model.checkActiveApplication()
        XCTAssertEqual(model.historySessions.count, 1)

        // Reopen Form A cleanly (simulates user opening Form A again with no data in the browser)
        model.detector = MockApplicationFormDetector(detected: true, title: "Fellowship Intake", appName: "Google Chrome", url: formAURL)
        model.checkActiveApplication()

        XCTAssertEqual(model.activeSession?.fields.count, 3, "Schema questions must be retained immediately on reopen")
        XCTAssertEqual(model.activeSession?.fields.map(\.value), ["", "", ""], "Previous version answers must NEVER display on reopen")
        XCTAssertEqual(model.activeSession?.answeredCount, 0)
        XCTAssertEqual(model.activeFieldIndex, 0)
        XCTAssertFalse(model.activeSession?.isSubmitted ?? true)

        // Now verify `startTracking` restoring from history also starts blank
        model.activeSession?.fields[0].value = "Temp Filled"
        model.stopTracking()
        model.startTracking(title: "Fellowship Intake", appName: "Safari", url: formAURL)

        XCTAssertEqual(model.activeSession?.fields.count, 3)
        XCTAssertEqual(model.activeSession?.fields.map(\.value), ["", "", ""], "startTracking must also reset stale archived values")

        // And live input in the newly opened session captures normally
        let captured = model.applyLiveItemsSnapshot([
            ExtractedInputItem(label: "Full Name", value: "Bob Chen", questionType: "shortAnswer"),
            ExtractedInputItem(label: "Track", value: "", questionType: "multipleChoice", options: ["Systems", "ML"]),
            ExtractedInputItem(label: "Portfolio URL", value: "", questionType: "shortAnswer")
        ])
        XCTAssertEqual(captured, 1)
        XCTAssertEqual(model.activeSession?.fields[0].value, "Bob Chen")
    }

    func testSuspendedSessionClearsEmptyFieldsOnMixedReopenEvenWithinClearGuardAndManualEdits() {
        let url = "https://docs.google.com/forms/d/e/1FAIpQLSe_suspended/viewform"
        let model = ApplicationFormModel(
            detector: MockApplicationFormDetector(detected: true, title: "Cohort Survey", appName: "Google Chrome", url: url),
            dispatcher: MockEmailDispatcher()
        )
        model.checkActiveApplication()
        model.activeSession?.fields = [
            FormInputField(label: "Email", value: "old@example.com", category: .contact, questionType: "shortAnswer", isRequired: true, entryKey: "entry.10"),
            FormInputField(label: "Full Name", value: "Old Manual Name", category: .personal, questionType: "shortAnswer", isRequired: true, entryKey: "entry.11"),
            FormInputField(label: "Comments", value: "Old comments", category: .question, questionType: "paragraph", entryKey: "entry.12")
        ]
        // Mark Full Name as manually edited right now (< 0.35s ago)
        model.updateFieldByIndex(1, value: "Old Manual Name")

        // Switch away to non-form app (suspends session)
        model.detector = MockApplicationFormDetector(detected: false, title: "Notes", appName: "Notes", url: nil)
        model.checkActiveApplication()
        XCTAssertNotNil(model.suspendedSession)

        // Return to the form, where Email is prefilled by account sign-in, while Full Name & Comments are blank
        model.detector = MockApplicationFormDetector(detected: true, title: "Cohort Survey", appName: "Google Chrome", url: url)
        model.checkActiveApplication()

        // First live snapshot arrives 0.00s later (< clearGuardInterval!)
        model.applyLiveItemsSnapshot([
            ExtractedInputItem(label: "Email", value: "signed.in@gmail.com", questionType: "shortAnswer"),
            ExtractedInputItem(label: "Full Name", value: "", questionType: "shortAnswer"),
            ExtractedInputItem(label: "Comments", value: "", questionType: "paragraph")
        ], now: Date())

        XCTAssertEqual(model.activeSession?.fields[0].value, "signed.in@gmail.com")
        XCTAssertEqual(model.activeSession?.fields[1].value, "", "Reopen snapshot must clear previously manually edited field when blank in browser")
        XCTAssertEqual(model.activeSession?.fields[2].value, "", "Reopen snapshot must clear stale comment even within clearGuardInterval")
    }

    func testSubmittedSessionTransitioningFromFormResponseToViewformResetsCleanly() {
        let submitURL = "https://docs.google.com/forms/d/e/1FAIpQLSe_sub/formResponse"
        let freshURL = "https://docs.google.com/forms/d/e/1FAIpQLSe_sub/viewform"

        let model = ApplicationFormModel(
            detector: MockApplicationFormDetector(detected: true, title: "Event RSVP", appName: "Safari", url: submitURL),
            dispatcher: MockEmailDispatcher()
        )
        model.checkActiveApplication()
        model.activeSession?.fields = [
            FormInputField(label: "Full Name", value: "Minh Nguyen", category: .personal, questionType: "shortAnswer", entryKey: "entry.1")
        ]
        model.markFormSubmitted()
        XCTAssertTrue(model.activeSession?.isSubmitted ?? false)

        // User clicks "Submit another response" -> browser URL transitions from /formResponse to /viewform
        model.detector = MockApplicationFormDetector(detected: true, title: "Event RSVP", appName: "Safari", url: freshURL)
        model.checkActiveApplication()

        XCTAssertFalse(model.activeSession?.isSubmitted ?? true)
        XCTAssertEqual(model.activeSession?.sourceURL, freshURL)
        XCTAssertEqual(model.activeSession?.fields.first?.value, "", "Transitioning from /formResponse back to /viewform must clear old answers")
    }

    // MARK: - 2. Post-Submit Confirmation vs Closed Form State

    func testFormResponseConfirmationHTMLNotMisclassifiedAsClosedAndDOMDistinguishesSubmittedVsClosed() async throws {
        let submittedHTML = """
        <html><body>
          <div class="freebirdFormviewerViewResponseConfirmationMessage">Your response has been recorded.</div>
          <a href="https://docs.google.com/forms/d/e/1FAIpQLSe_realtime_test/viewform">Submit another response</a>
        </body></html>
        """
        let closedState = FormContentRetriever.detectFormClosedState(html: submittedHTML)
        XCTAssertFalse(closedState.isClosed, "Confirmation screen after submitting must NOT be flagged as form-closed")

        let submittedWeb = try await makeWebView(html: submittedHTML, baseURL: "https://docs.google.com/forms/d/e/1FAIpQLSe_realtime_test/formResponse")
        let submittedItems = try await runExtractionItems(submittedWeb)
        XCTAssertEqual(submittedItems.first?.label, "__FORM_SUBMITTED__")
        XCTAssertEqual(submittedItems.first?.questionType, "submitted")

        let closedHTML = """
        <html><body>
          <div class="freebirdFormviewerViewResponseConfirmationMessage">The form Survey 2026 is no longer accepting responses.</div>
        </body></html>
        """
        let closedWeb = try await makeWebView(html: closedHTML)
        let closedItems = try await runExtractionItems(closedWeb)
        XCTAssertEqual(closedItems.first?.label, "__FORM_CLOSED__")
        XCTAssertEqual(closedItems.first?.questionType, "closed")
    }

    // MARK: - 3. Complete Schema & Complex Question Type Extraction (Grid, Linear Scale, File Upload, Other, Required, Partial Date/Time, Dedup)

    func testFBPublicLoadDataParsesGridFileUploadLinearScaleAndOtherOption() throws {
        let rawJSON = """
        [null, [
            "Complete Intake",
            [
                [null, "Department Matrix", null, 7, [
                    [201, [["Low"], ["Medium"], ["High"]], 1, ["Speed"]],
                    [202, [["Low"], ["Medium"], ["High"]], 1, ["Accuracy"]]
                ]],
                [null, "Upload Resume", null, 13, [[203, null, 0]]],
                [null, "Confidence Level", null, 5, [[204, [["1"], ["2"], ["3"], ["4"], ["5"]], 1, ["Low", "High"]]]],
                [null, "Referral Source", null, 2, [[205, [["Friend"], ["Search"], ["__other_option__"], [null, null, null, null, 1]], 0]]]
            ],
            null, null, null, null, null, null,
            "Complete Intake Form"
        ]]
        """
        let schema = try XCTUnwrap(FormContentRetriever.parseGoogleFormPublicLoadData(rawJSON))
        XCTAssertEqual(schema.fields.count, 5, "2-row grid should expand into 2 row fields + 3 remaining questions")

        XCTAssertEqual(schema.fields[0].label, "Department Matrix [Speed]")
        XCTAssertEqual(schema.fields[0].questionType, "grid")
        XCTAssertEqual(schema.fields[0].entryKey, "entry.201")
        XCTAssertTrue(schema.fields[0].isRequired)
        XCTAssertEqual(schema.fields[0].options, ["Low", "Medium", "High"])

        XCTAssertEqual(schema.fields[1].label, "Department Matrix [Accuracy]")
        XCTAssertEqual(schema.fields[1].questionType, "grid")
        XCTAssertEqual(schema.fields[1].entryKey, "entry.202")
        XCTAssertTrue(schema.fields[1].isRequired)

        XCTAssertEqual(schema.fields[2].label, "Upload Resume")
        XCTAssertEqual(schema.fields[2].questionType, "fileUpload")
        XCTAssertFalse(schema.fields[2].isRequired)

        XCTAssertEqual(schema.fields[3].label, "Confidence Level")
        XCTAssertEqual(schema.fields[3].questionType, "linearScale")
        XCTAssertTrue(schema.fields[3].questionDescription.contains("Low"))
        XCTAssertTrue(schema.fields[3].questionDescription.contains("High"))

        XCTAssertEqual(schema.fields[4].label, "Referral Source")
        XCTAssertEqual(schema.fields[4].options, ["Friend", "Search", "Other"])
        XCTAssertFalse(schema.fields[4].options.contains("__other_option__"))
    }

    func testWKWebViewDOMExtractionHandlesGridLinearScaleFileUploadOtherRequiredPartialDateTimeAndDedup() async throws {
        let html = """
        <html><body><div role="list">
          <div class="Qr7Oae" role="listitem">
            <div class="geS5n">
              <div role="heading">Full Name <span>*</span></div>
              <input type="text" class="whsOnd" value="Ada Lovelace">
            </div>
          </div>

          <div class="Qr7Oae" role="listitem">
            <div role="heading">Satisfaction <span aria-label="Required question">*</span></div>
            <div class="T5pZmf">1</div>
            <div role="radio" aria-label="1" data-value="1" aria-checked="false"></div>
            <div role="radio" aria-label="2" data-value="2" aria-checked="false"></div>
            <div role="radio" aria-label="3" data-value="3" aria-checked="false"></div>
            <div role="radio" aria-label="4" data-value="4" aria-checked="true"></div>
            <div role="radio" aria-label="5" data-value="5" aria-checked="false"></div>
          </div>

          <div class="Qr7Oae" role="listitem">
            <div role="heading">Primary Track</div>
            <div role="radiogroup">
              <div role="radio" data-value="Systems" aria-checked="false"></div>
              <div role="radio" data-value="__other_option__" aria-checked="true"></div>
              <input type="text" class="Hvn9fb" aria-label="Other response" value="Compilers & Runtime">
            </div>
          </div>

          <div class="Qr7Oae" role="listitem">
            <div role="heading">Availability Grid *</div>
            <div role="radiogroup" aria-label="Monday">
              <div role="radio" data-value="Morning" aria-checked="false"></div>
              <div role="radio" data-value="Evening" aria-checked="true"></div>
            </div>
            <div role="radiogroup" aria-label="Tuesday">
              <div role="radio" data-value="Morning" aria-checked="false"></div>
              <div role="radio" data-value="Evening" aria-checked="false"></div>
            </div>
          </div>

          <div class="Qr7Oae" role="listitem">
            <div role="heading">Portfolio PDF</div>
            <div role="button">Add file</div>
            <div class="Up87de" data-file-name="cv_ada_2026.pdf">cv_ada_2026.pdf</div>
          </div>

          <div class="Qr7Oae" role="listitem">
            <div role="heading">Start Date</div>
            <input type="text" aria-label="Month" value="04">
            <input type="text" aria-label="Day" value="">
            <input type="text" aria-label="Year" value="">
          </div>

          <div class="Qr7Oae" role="listitem">
            <div role="heading">Interview Time</div>
            <input type="text" aria-label="Hour" value="09">
            <input type="text" aria-label="Minute" value="">
            <div role="listbox"><div role="option" aria-selected="true">AM</div><div role="option" aria-selected="false">PM</div></div>
          </div>

          <div class="Qr7Oae" role="listitem">
            <div role="heading">Backup Time</div>
            <input type="text" aria-label="Hour" value="">
            <input type="text" aria-label="Minute" value="">
            <div role="listbox"><div role="option" aria-selected="true">AM</div><div role="option" aria-selected="false">PM</div></div>
          </div>

          <div class="Qr7Oae" role="listitem">
            <label for="nick-input">Nickname</label>
            <input id="nick-input" type="text" value="Ace">
          </div>
        </div></body></html>
        """

        let web = try await makeWebView(html: html)
        let items = try await runExtractionItems(web)
        let byLabel = Dictionary(items.map { ($0.label, $0) }, uniquingKeysWith: { _, last in last })

        // Deduplicated nested .Qr7Oae > .geS5n
        XCTAssertEqual(items.filter { $0.label == "Full Name" }.count, 1)
        XCTAssertEqual(byLabel["Full Name"]?.value, "Ada Lovelace")
        XCTAssertEqual(byLabel["Full Name"]?.isRequired, true)

        XCTAssertEqual(byLabel["Satisfaction"]?.questionType, "linearScale")
        XCTAssertEqual(byLabel["Satisfaction"]?.value, "4")
        XCTAssertEqual(byLabel["Satisfaction"]?.isRequired, true)

        XCTAssertEqual(byLabel["Primary Track"]?.questionType, "multipleChoice")
        XCTAssertEqual(byLabel["Primary Track"]?.value, "Compilers & Runtime")
        XCTAssertFalse(byLabel["Primary Track"]?.options.contains("__other_option__") ?? true)

        XCTAssertEqual(byLabel["Availability Grid [Monday]"]?.questionType, "grid")
        XCTAssertEqual(byLabel["Availability Grid [Monday]"]?.value, "Evening")
        XCTAssertEqual(byLabel["Availability Grid [Monday]"]?.isRequired, true)
        XCTAssertEqual(byLabel["Availability Grid [Tuesday]"]?.questionType, "grid")
        XCTAssertEqual(byLabel["Availability Grid [Tuesday]"]?.value, "")

        XCTAssertEqual(byLabel["Portfolio PDF"]?.questionType, "fileUpload")
        XCTAssertEqual(byLabel["Portfolio PDF"]?.value, "cv_ada_2026.pdf")

        XCTAssertEqual(byLabel["Start Date"]?.questionType, "date")
        XCTAssertEqual(byLabel["Start Date"]?.value, "04")

        XCTAssertEqual(byLabel["Interview Time"]?.questionType, "time")
        XCTAssertEqual(byLabel["Interview Time"]?.value, "09:__")

        XCTAssertEqual(byLabel["Backup Time"]?.questionType, "time")
        XCTAssertEqual(byLabel["Backup Time"]?.value, "", "Default AM/PM selector without Hour/Minute must stay unanswered")

        XCTAssertEqual(byLabel["Nickname"]?.value, "Ace")
    }

    // MARK: - 4. AppleScript Active-Tab Priority & Compilation

    func testAppleScriptPrioritizesActiveOrCurrentTabOfFrontWindowBeforeScanningWindows() throws {
        let targetURL = "https://docs.google.com/forms/d/e/1FAIpQLSe_tab_prio/viewform"
        let sampleFields = [FormInputField(label: "Full Name", value: "", entryKey: "entry.1")]

        for bundleID in ["com.google.Chrome", "com.apple.Safari"] {
            let scripts: [String] = [
                try XCTUnwrap(FormInputAutoTracker.buildDOMExtractionAppleScript(bundleID: bundleID, targetURL: targetURL)),
                try XCTUnwrap(FormInputAutoTracker.buildDOMInjectionAppleScript(bundleID: bundleID, answers: ["Full Name": "Ada"], fields: sampleFields, targetURL: targetURL)),
                try XCTUnwrap(FormInputAutoTracker.buildDOMFilledLabelsAppleScript(bundleID: bundleID, targetURL: targetURL))
            ]

            for src in scripts {
                let repeatIdx = try XCTUnwrap(src.range(of: "repeat with w in windows")?.lowerBound)
                if bundleID == "com.google.Chrome" {
                    let activeTabIdx = try XCTUnwrap(src.range(of: "tell front window to tell active tab")?.lowerBound)
                    XCTAssertLessThan(activeTabIdx, repeatIdx, "Chrome script must check front window's active tab BEFORE scanning all windows")
                } else {
                    let currentTabIdx = try XCTUnwrap(src.range(of: "current tab of front window")?.lowerBound)
                    XCTAssertLessThan(currentTabIdx, repeatIdx, "Safari script must check front window's current tab BEFORE scanning all windows")
                    let fallbackRange = try XCTUnwrap(src.range(of: "tell front window to tell current tab"))
                    let tail = String(src[fallbackRange.lowerBound...])
                    XCTAssertFalse(tail.contains(") in t") || tail.contains("\" in t"))
                }

                if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil {
                    var err: NSDictionary?
                    let ok = NSAppleScript(source: src)?.compileAndReturnError(&err) ?? false
                    XCTAssertTrue(ok, "Script for \(bundleID) must compile; err=\(String(describing: err))")
                }
            }
        }
    }

    // MARK: - 5. Synchronous Editing, Snapshot Race Protection, & Format Preservation

    func testSynchronousCmdBackspaceOptionBackspaceCmdZAndStaleSnapshotGuards() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Editing Test Form", appName: "Polar")
        model.isFormDetected = true
        model.isAutoCaptureEnabled = true

        model.activeSession?.fields = [
            FormInputField(label: "Full Name", value: "Aaron Nguyen", category: .personal, questionType: "shortAnswer", entryKey: "entry.1"),
            FormInputField(label: "Bio", value: "Line 1\nLine 2", category: .experience, questionType: "paragraph", entryKey: "entry.2"),
            FormInputField(label: "Rating", value: "", category: .question, options: ["1", "2", "3", "4", "5"], questionType: "linearScale", isRequired: false, entryKey: "entry.3")
        ]

        let tracker = FormInputAutoTracker(model: model)
        tracker.isHeadlessWebLayerMode = true
        let nameID = model.activeSession!.fields[0].id
        let bioID = model.activeSession!.fields[1].id

        // 1. Option+Backspace deletes last word synchronously
        tracker.confirmFocus(fieldID: nameID)
        tracker.handleKeyStroke(keyCode: 51, flags: .maskAlternate, characters: nil)
        XCTAssertEqual(model.activeSession?.fields[0].value, "Aaron ")

        // 2. Cmd+Backspace on shortAnswer clears value, and Cmd+Z restores it
        tracker.handleKeyStroke(keyCode: 51, flags: .maskCommand, characters: nil)
        XCTAssertEqual(model.activeSession?.fields[0].value, "")
        tracker.handleKeyStroke(keyCode: 6, flags: .maskCommand, characters: "z")
        XCTAssertEqual(model.activeSession?.fields[0].value, "Aaron ")

        // 3. Cmd+Backspace on multiline paragraph deletes current line ("Line 2"), keeping "Line 1\n",
        //    Cmd+Z restores "Line 1\nLine 2", and sequential Cmd+Backspace strips "\n" -> "Line 1"
        tracker.confirmFocus(fieldID: bioID)
        tracker.handleKeyStroke(keyCode: 51, flags: .maskCommand, characters: nil)
        XCTAssertEqual(model.activeSession?.fields[1].value, "Line 1\n")
        tracker.handleKeyStroke(keyCode: 6, flags: .maskCommand, characters: "z")
        XCTAssertEqual(model.activeSession?.fields[1].value, "Line 1\nLine 2")
        tracker.handleKeyStroke(keyCode: 51, flags: .maskCommand, characters: nil)
        tracker.handleKeyStroke(keyCode: 51, flags: .maskCommand, characters: nil)
        XCTAssertEqual(model.activeSession?.fields[1].value, "Line 1")

        // 4. Same-length correction from DOM ("Jonh" -> "John") must apply immediately
        tracker.confirmFocus(fieldID: nameID)
        model.activeSession?.fields[0].value = "Jonh"
        let sameLenApplied = model.applyExtractedInput(label: "Full Name", value: "John")
        XCTAssertTrue(sameLenApplied)
        XCTAssertEqual(model.activeSession?.fields[0].value, "John")

        // 5. Pre-keystroke snapshot started BEFORE lastKeystrokeAt must be dropped on focused field
        tracker.handleKeyStroke(keyCode: 0, flags: [], characters: "s")
        XCTAssertEqual(model.activeSession?.fields[0].value, "Johns")
        let keystrokeTime = model.lastKeystrokeAt ?? Date()
        let staleSnapshotStart = keystrokeTime.addingTimeInterval(-0.2)
        let rejected = model.applyExtractedInput(label: "Full Name", value: "John", snapshotStartedAt: staleSnapshotStart)
        XCTAssertFalse(rejected, "Snapshot started before latest keystroke on focused field must NOT overwrite newer keystroke buffer")
        XCTAssertEqual(model.activeSession?.fields[0].value, "Johns")

        let newerSnapshotStart = keystrokeTime.addingTimeInterval(0.05)
        let accepted = model.applyExtractedInput(label: "Full Name", value: "Johns Hopkins", snapshotStartedAt: newerSnapshotStart)
        XCTAssertTrue(accepted)
        XCTAssertEqual(model.activeSession?.fields[0].value, "Johns Hopkins")

        // 6. Generic AX type ("shortAnswer") must NOT downgrade "linearScale", while isRequired: true promotes
        _ = model.applyExtractedInput(label: "Rating", value: "5", detectedType: "shortAnswer", isRequired: true)
        XCTAssertEqual(model.activeSession?.fields[2].questionType, "linearScale")
        XCTAssertEqual(model.activeSession?.fields[2].isRequired, true)
        XCTAssertEqual(model.activeSession?.fields[2].value, "5")
    }

    // MARK: - 6. Polar Blink Signature & DOM Responder Email Retention

    func testPolarBlinkStateSignatureDetectsUnchangedVsUpdatedFormData() {
        let url = "https://docs.google.com/forms/d/e/1FAIpQLSe_blink_test/viewform"
        let sigKey = "https://docs.google.com/forms/d/e/1FAIpQLSe_blink_test/viewform [entry.100]"

        let buf1 = buildSyntheticBlinkBuffer(formSig: sigKey, controls: [
            (name: "entry.100", type: "text", value: "Old Answer")
        ])
        let buf2 = buildSyntheticBlinkBuffer(formSig: sigKey, controls: [
            (name: "entry.100", type: "text", value: "Old Answer")
        ])
        let buf3 = buildSyntheticBlinkBuffer(formSig: sigKey, controls: [
            (name: "entry.100", type: "text", value: "Fresh Answer")
        ])

        let s1 = FormInputAutoTracker.extractBlinkFormStateSignature(from: buf1, formURL: url)
        let s2 = FormInputAutoTracker.extractBlinkFormStateSignature(from: buf2, formURL: url)
        let s3 = FormInputAutoTracker.extractBlinkFormStateSignature(from: buf3, formURL: url)

        XCTAssertNotNil(s1)
        XCTAssertEqual(s1, s2, "Unchanged Polar Blink record must yield identical signature so reopened blank forms ignore stale Session_* records")
        XCTAssertNotEqual(s1, s3, "Updated Blink record must yield a different signature")
    }

    func testApplyRetrievedSchemaRetainsDOMCollectedResponderEmailQuestion() {
        let url = "https://docs.google.com/forms/d/e/1FAIpQLSe_email_retain/viewform"
        let model = ApplicationFormModel(
            detector: MockApplicationFormDetector(detected: true, title: "Org Application", appName: "Google Chrome", url: url),
            dispatcher: MockEmailDispatcher()
        )
        model.checkActiveApplication()

        // Existing DOM-detected Email field before authoritative HTTP schema arrives (which omits Google's Email collector)
        model.activeSession?.fields = [
            FormInputField(label: "Email", value: "user@domain.com", category: .contact, questionType: "shortAnswer", isRequired: true),
            FormInputField(label: "Full Name", value: "User Name", category: .personal, questionType: "shortAnswer", isRequired: true)
        ]

        let httpSchema = FormSchema(
            title: "Org Application",
            description: "Welcome",
            fields: [
                FormInputField(label: "Full Name", value: "", category: .personal, questionType: "shortAnswer", isRequired: true, entryKey: "entry.50"),
                FormInputField(label: "Why join?", value: "", category: .question, questionType: "paragraph", isRequired: false, entryKey: "entry.51")
            ]
        )

        model.applyRetrievedSchema(httpSchema, sourceURL: url, isAuthoritativeHTTP: true)

        let labels = model.activeSession?.fields.map(\.label) ?? []
        XCTAssertEqual(labels, ["Email", "Full Name", "Why join?"], "Responder Email field collected from DOM must not be wiped when HTTP schema omits it")
        XCTAssertEqual(model.activeSession?.fields.first?.value, "user@domain.com")
    }

    // MARK: - 7. Generic Bare <form> DOM Extraction & Zero // Comments

    func testDOMExtractionScriptHasNoSingleLineCommentsAndHandlesGenericBareForms() async throws {
        XCTAssertFalse(
            FormInputAutoTracker.domExtractionScript.contains("//"),
            "domExtractionScript must never contain // single-line comments because AppleScript flattens newlines"
        )

        let genericFormHTML = """
        <html><body>
          <input name="orphan_phone" value="">
          <form id="bare-application">
            <div>
              <label for="u-name">Full Name</label>
              <input id="u-name" type="text" value="">
            </div>
            <div>
              <input type="radio" name="plan" aria-label="Plan" value="Free">
              <input type="radio" name="plan" aria-label="Plan" value="Pro" checked>
            </div>
            <div>
              <input type="radio" name="billing" aria-label="Billing" value="Monthly">
              <input type="radio" name="billing" aria-label="Billing" value="Annual">
            </div>
            <div>
              <input type="checkbox" name="topics" aria-label="Topics" data-value="Swift" checked>
              <input type="checkbox" name="topics" aria-label="Topics" data-value="Systems" checked>
              <input type="checkbox" name="topics" aria-label="Topics" data-value="Design">
            </div>
            <div>
              <label for="role-sel">Role</label>
              <select id="role-sel">
                <option>Select an option</option>
                <option selected>Engineer</option>
              </select>
            </div>
            <div>
              <label for="loc-sel">Location</label>
              <select id="loc-sel">
                <option selected>Choose</option>
                <option>SF</option>
              </select>
            </div>
            <fieldset>
              <legend>Subscription Tier</legend>
              <input id="t1" type="radio" name="tier"><label for="t1">Starter</label>
              <input id="t2" type="radio" name="tier" checked><label for="t2">Team</label>
            </fieldset>
            <div>
              <input id="c1" type="radio" name="cadence"><label for="c1">Monthly</label>
              <input id="c2" type="radio" name="cadence" checked><label for="c2">Annual</label>
            </div>
          </form>
        </body></html>
        """

        let web = try await makeWebView(html: genericFormHTML, baseURL: "https://example.com/apply")
        let items = try await runExtractionItems(web)
        let byLabel = Dictionary(items.map { ($0.label, $0) }, uniquingKeysWith: { _, last in last })

        XCTAssertNil(byLabel["orphan_phone"], "Loose empty input outside <form> must remain ignored")
        XCTAssertEqual(byLabel["Full Name"]?.value, "", "Empty input inside <form> must be reported with empty value so stale/cleared state updates")
        XCTAssertEqual(byLabel["Plan"]?.questionType, "multipleChoice")
        XCTAssertEqual(byLabel["Plan"]?.value, "Pro")
        XCTAssertEqual(items.filter { $0.label == "Plan" }.count, 1)
        XCTAssertEqual(byLabel["Billing"]?.questionType, "multipleChoice")
        XCTAssertEqual(byLabel["Billing"]?.value, "", "Unchecked radio options must not report a filled value")
        XCTAssertEqual(byLabel["Topics"]?.questionType, "checkboxes")
        XCTAssertEqual(byLabel["Topics"]?.value, "Swift, Systems")
        XCTAssertEqual(byLabel["Role"]?.questionType, "dropdown")
        XCTAssertEqual(byLabel["Role"]?.value, "Engineer")
        XCTAssertEqual(byLabel["Location"]?.questionType, "dropdown")
        XCTAssertEqual(byLabel["Location"]?.value, "", "Placeholder option must not report as answered")
        XCTAssertEqual(byLabel["Subscription Tier"]?.questionType, "multipleChoice")
        XCTAssertEqual(byLabel["Subscription Tier"]?.value, "Team")
        XCTAssertEqual(byLabel["cadence"]?.questionType, "multipleChoice")
        XCTAssertEqual(byLabel["cadence"]?.value, "Annual")
    }

    // MARK: - 8. Time AM/PM & Multiple-Choice "Other" Consistency + Blink Mtime Filtering

    func testTimeAmPmAndMultipleChoiceOtherDoNotCorruptLiveValues() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Complex Fields", appName: "Google Chrome")
        model.isFormDetected = true
        model.isAutoCaptureEnabled = true

        model.activeSession?.fields = [
            FormInputField(label: "Interview Time", value: "09:30 AM", category: .question, questionType: "time", entryKey: "entry.1"),
            FormInputField(label: "Track", value: "Systems", category: .question, options: ["Systems", "ML", "Other"], questionType: "multipleChoice", entryKey: "entry.2"),
            FormInputField(label: "Interests", value: "AI, Other", category: .question, options: ["AI", "Web", "Other"], questionType: "checkboxes", entryKey: "entry.3")
        ]

        // 1. Live snapshot with composite time keeps formatted HH:MM AM/PM; empty time clears when cleared in DOM
        _ = model.applyLiveItemsSnapshot([
            ExtractedInputItem(label: "Interview Time", value: "09:30 PM", questionType: "time"),
            ExtractedInputItem(label: "Track", value: "Systems", questionType: "multipleChoice", options: ["Systems", "ML", "Other"]),
            ExtractedInputItem(label: "Interests", value: "AI, Robotics", questionType: "checkboxes", options: ["AI", "Web", "Other"])
        ])
        XCTAssertEqual(model.activeSession?.fields[0].value, "09:30 PM")
        XCTAssertEqual(model.activeSession?.fields[1].value, "Systems")
        XCTAssertEqual(model.activeSession?.fields[2].value, "AI, Robotics")
        XCTAssertEqual(model.activeSession?.fields[0].isAnswered, true)

        // 2. Whitespace-only values must treat `isAnswered` as false across model & counts
        model.activeSession?.fields[0].value = "   "
        XCTAssertFalse(model.activeSession!.fields[0].isAnswered)
        XCTAssertEqual(model.activeSession?.answeredCount, 2)

        // 3. Post-BFS "Other" reconciliation preserves multi-select checkboxes and handles "Other:" / unchecked stale text
        var fieldValues: [String: (val: String, type: String, options: [String])] = [
            "Interests": (val: "AI, Other:", type: "checkboxes", options: ["AI", "Web", "Other:"]),
            "Track": (val: "Other:", type: "multipleChoice", options: ["Systems", "ML", "Other:"]),
            "UncheckedGroup": (val: "", type: "multipleChoice", options: ["Alpha", "Other"]),
            "SelectedOtherExcluded": (val: "Systems", type: "multipleChoice", options: ["Systems", "Other"]),
            "CheckboxOtherExcluded": (val: "AI", type: "checkboxes", options: ["AI", "Other"])
        ]
        FormInputAutoTracker.reconcileOtherTypedText(
            fieldValues: &fieldValues,
            otherTypedTextByLabel: [
                "Interests": "Robotics",
                "Track": "Compilers",
                "UncheckedGroup": "StaleText",
                "SelectedOtherExcluded": "StaleText",
                "CheckboxOtherExcluded": "StaleText"
            ]
        )
        XCTAssertEqual(fieldValues["Interests"]?.val, "AI, Robotics", "Checkboxes must keep prior checked items when replacing Other:")
        XCTAssertEqual(fieldValues["Track"]?.val, "Compilers")
        XCTAssertEqual(fieldValues["UncheckedGroup"]?.val, "", "Stale text in unchecked Other response box must not fake an answer when options exist")
        XCTAssertEqual(fieldValues["SelectedOtherExcluded"]?.val, "Systems")
        XCTAssertEqual(fieldValues["CheckboxOtherExcluded"]?.val, "AI")
    }

    func testPolarBlinkMaxModificationDateFilteringAndStartTrackingBaselineQueue() throws {
        let formID = "1FAIpQLSe_blink_mtime_test"
        let url = "https://docs.google.com/forms/d/e/\(formID)/viewform"
        let sigKey = "\(url) [entry.900]"

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MorphBlinkTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let oldBuf = buildSyntheticBlinkBuffer(formSig: sigKey, controls: [
            (name: "entry.900", type: "text", value: "Stale Previous Answer")
        ])
        let newBuf = buildSyntheticBlinkBuffer(formSig: sigKey, controls: [
            (name: "entry.900", type: "text", value: "Live Fresh Answer")
        ])

        let baseTime = Date(timeIntervalSince1970: 1_760_000_000)
        let oldFile = tmpDir.appendingPathComponent("Session_old")
        let newFile = tmpDir.appendingPathComponent("Session_new")
        try oldBuf.write(to: oldFile)
        try newBuf.write(to: newFile)
        try FileManager.default.setAttributes([.modificationDate: baseTime.addingTimeInterval(-3.0)], ofItemAtPath: oldFile.path)
        try FileManager.default.setAttributes([.modificationDate: baseTime.addingTimeInterval(2.0)], ofItemAtPath: newFile.path)

        let baselineSig = FormInputAutoTracker.extractLatestPolarBlinkSignature(
            formURL: url,
            sessionStartedAt: .distantPast,
            maxModificationDate: baseTime,
            sessionDirectories: [tmpDir.path]
        )
        let latestState = FormInputAutoTracker.extractLatestPolarBlinkState(
            formURL: url,
            fields: [FormInputField(label: "Notes", value: "", entryKey: "entry.900")],
            sessionStartedAt: baseTime,
            useLookback: true,
            sessionDirectories: [tmpDir.path]
        )

        XCTAssertNotNil(baselineSig)
        XCTAssertNotNil(latestState.signature)
        XCTAssertNotEqual(baselineSig, latestState.signature, "maxModificationDate cap must pick pre-keystroke baseline instead of newer write")
        XCTAssertEqual(latestState.pairs.first?.value, "Live Fresh Answer")

        // Also verify only old file present before baseTime still matches baseline signature within 15s lookback
        try FileManager.default.removeItem(at: newFile)
        let reopenedOldState = FormInputAutoTracker.extractLatestPolarBlinkState(
            formURL: url,
            fields: [FormInputField(label: "Notes", value: "", entryKey: "entry.900")],
            sessionStartedAt: baseTime,
            useLookback: true,
            sessionDirectories: [tmpDir.path]
        )
        XCTAssertEqual(baselineSig, reopenedOldState.signature, "Lookback signature on unchanged Session_* file matches baseline so reopened blank form suppresses stale Blink answer")

        // Verify startTracking queues Blink baseline capture and strict window for new URL sessions
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Polar Form", appName: "Polar", url: url)
        XCTAssertTrue(model.pendingBlinkBaselineCapture.contains(formID))
        XCTAssertTrue(model.strictBlinkWindowByFormID.contains(formID))
    }
}
