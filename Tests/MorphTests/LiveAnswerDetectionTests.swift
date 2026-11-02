import XCTest
import WebKit
@testable import morph

/// Verifies that answers typed into a Google Form are detected automatically:
/// the DOM extraction script (run in a real WebKit engine against a mock Google Form),
/// the AppleScript bridge, and the model's live-snapshot reconciliation.
@MainActor
final class LiveAnswerDetectionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: ApplicationFormModel.draftsStorageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ApplicationFormModel.draftsStorageKey)
        super.tearDown()
    }

    // MARK: - Mock Google Form DOM

    private static let mockGoogleFormHTML = """
    <html><body>
    <div role="list">
      <div role="listitem" id="header"><div role="heading">Laguna Schools Application</div><div>Please read carefully.</div></div>
      <div role="listitem" id="name">
        <div role="heading">Full Name <span>*</span></div>
        <input type="text" class="whsOnd" aria-label="Full Name" value="">
      </div>
      <div role="listitem" id="email">
        <div role="heading">Email Address <span>*</span></div>
        <input type="email" class="whsOnd" value="">
      </div>
      <div role="listitem" id="why">
        <div role="heading">Why are you applying?</div>
        <textarea class="KHxj8b"></textarea>
      </div>
      <div role="listitem" id="role">
        <div role="heading">I will be applying as *</div>
        <div role="radiogroup">
          <div role="radio" aria-checked="false" data-value="Independent Adjudicator"></div>
          <div role="radio" aria-checked="false" data-value="Student Adjudicator"></div>
        </div>
      </div>
      <div role="listitem" id="rounds">
        <div role="heading">Select all rounds available</div>
        <div role="group">
          <div role="checkbox" aria-checked="false" data-answer-value="Round 1" aria-label="Round 1"></div>
          <div role="checkbox" aria-checked="false" data-answer-value="Round 2" aria-label="Round 2"></div>
          <div role="checkbox" aria-checked="false" data-answer-value="Finals" aria-label="Finals"></div>
        </div>
      </div>
      <div role="listitem" id="school">
        <div role="heading">Home campus</div>
        <div role="listbox">
          <div role="option" data-value="" aria-selected="true"><span>Choose</span></div>
          <div role="option" data-value="North" aria-selected="false"><span>North</span></div>
          <div role="option" data-value="South" aria-selected="false"><span>South</span></div>
        </div>
      </div>
      <div role="listitem" id="date">
        <div role="heading">Date of birth</div>
        <input type="date" value="">
      </div>
    </div>
    </body></html>
    """

    private func makeWebView(html: String) async throws -> WKWebView {
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        final class Loader: NSObject, WKNavigationDelegate {
            var continuation: CheckedContinuation<Void, Error>?
            func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { continuation?.resume(); continuation = nil }
            func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { continuation?.resume(throwing: error); continuation = nil }
        }
        let loader = Loader()
        web.navigationDelegate = loader
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in
            loader.continuation = c
            web.loadHTMLString(html, baseURL: URL(string: "https://docs.google.com/forms/d/e/mock/viewform"))
        }
        objc_setAssociatedObject(web, "loader", loader, .OBJC_ASSOCIATION_RETAIN)
        return web
    }

    private func runExtraction(_ web: WKWebView) async throws -> [(label: String, value: String)] {
        let result = try await web.evaluateJavaScript(FormInputAutoTracker.domExtractionScript)
        let output = try XCTUnwrap(result as? String, "Extraction script must return a string")
        return FormInputAutoTracker.parseDOMExtractionOutput(output)
    }

    private func dict(_ pairs: [(label: String, value: String)]) -> [String: String] {
        Dictionary(pairs.map { ($0.label, $0.value) }, uniquingKeysWith: { _, last in last })
    }

    // MARK: - DOM extraction in a real WebKit engine

    func testExtractionReportsEveryQuestionEmptyBeforeAnswering() async throws {
        let web = try await makeWebView(html: Self.mockGoogleFormHTML)
        let d = dict(try await runExtraction(web))
        XCTAssertEqual(d.count, 7, "Header/info items without inputs must be skipped: \(d)")
        for key in ["Full Name", "Email Address", "Why are you applying?", "I will be applying as",
                    "Select all rounds available", "Home campus", "Date of birth"] {
            XCTAssertEqual(d[key], "", "\(key) should be reported unanswered")
        }
        XCTAssertNil(d["Laguna Schools Application"])
    }

    func testExtractionDetectsAllAnswerTypes() async throws {
        let web = try await makeWebView(html: Self.mockGoogleFormHTML)
        _ = try await web.evaluateJavaScript("""
        document.querySelector('#name input').value = 'Minh Nguyen';
        document.querySelector('#email input').value = 'minh@laguna.edu';
        document.querySelector('#why textarea').value = 'I love debate.';
        document.querySelector('#role [data-value="Student Adjudicator"]').setAttribute('aria-checked','true');
        document.querySelector('#rounds [data-answer-value="Round 1"]').setAttribute('aria-checked','true');
        document.querySelector('#rounds [data-answer-value="Finals"]').setAttribute('aria-checked','true');
        var opts = document.querySelectorAll('#school [role=option]');
        opts[0].setAttribute('aria-selected','false'); opts[2].setAttribute('aria-selected','true');
        document.querySelector('#date input').value = '2008-04-02';
        true;
        """)
        let d = dict(try await runExtraction(web))
        XCTAssertEqual(d["Full Name"], "Minh Nguyen")
        XCTAssertEqual(d["Email Address"], "minh@laguna.edu")
        XCTAssertEqual(d["Why are you applying?"], "I love debate.")
        XCTAssertEqual(d["I will be applying as"], "Student Adjudicator")
        XCTAssertEqual(d["Select all rounds available"], "Round 1, Finals")
        XCTAssertEqual(d["Home campus"], "South")
        XCTAssertEqual(d["Date of birth"], "2008-04-02")
    }

    func testDropdownPlaceholderIsNeverCapturedAsAnAnswer() async throws {
        let web = try await makeWebView(html: Self.mockGoogleFormHTML)
        let d = dict(try await runExtraction(web))
        XCTAssertEqual(d["Home campus"], "", "'Choose' placeholder must not be treated as an answer")
    }

    func testExtractionFallbackForGenericForms() async throws {
        let html = "<html><body><input aria-label='Company' value='Morph Labs'><input name='phone' value=''><textarea aria-label='Notes'>hello</textarea></body></html>"
        let web = try await makeWebView(html: html)
        let d = dict(try await runExtraction(web))
        XCTAssertEqual(d["Company"], "Morph Labs")
        XCTAssertEqual(d["Notes"], "hello")
        XCTAssertNil(d["phone"], "Empty generic inputs are not reported")
    }

    // MARK: - AppleScript bridge

    func testAppleScriptEscapingRoundTripsScriptExactly() throws {
        let body = FormInputAutoTracker.appleScriptStringLiteralBody(FormInputAutoTracker.domExtractionScript)
        let source = "return \"\(body)\""
        var err: NSDictionary?
        let script = try XCTUnwrap(NSAppleScript(source: source))
        let desc = script.executeAndReturnError(&err)
        XCTAssertNil(err, "Escaped script literal must compile and run: \(String(describing: err))")
        let flattened = FormInputAutoTracker.domExtractionScript
            .replacingOccurrences(of: "\n", with: " ")
        XCTAssertEqual(desc.stringValue, flattened, "AppleScript string must reproduce the JS byte-for-byte")
    }

    func testEscapingHandlesBackslashesAndQuotes() throws {
        let raw = "a\\b \"q\" c\\n"
        let source = "return \"\(FormInputAutoTracker.appleScriptStringLiteralBody(raw))\""
        var err: NSDictionary?
        let desc = try XCTUnwrap(NSAppleScript(source: source)).executeAndReturnError(&err)
        XCTAssertNil(err)
        XCTAssertEqual(desc.stringValue, raw)
    }

    func testSafariAndChromeScriptsCompile() throws {
        for bundle in ["com.apple.Safari", "com.google.Chrome"] {
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) != nil else { continue }
            let source = try XCTUnwrap(FormInputAutoTracker.buildDOMExtractionAppleScript(bundleID: bundle))
            var err: NSDictionary?
            let ok = try XCTUnwrap(NSAppleScript(source: source)).compileAndReturnError(&err)
            XCTAssertTrue(ok, "\(bundle) AppleScript failed to compile: \(String(describing: err))")
        }
        XCTAssertNil(FormInputAutoTracker.buildDOMExtractionAppleScript(bundleID: "com.apple.finder"))
    }

    func testParseDOMOutputKeepsEmptyValuesAndColonsInValues() {
        let out = "Full Name:::Minh|||Home campus:::|||Website:::https://a.b/c:::d|||garbage|||:::orphan"
        let pairs = FormInputAutoTracker.parseDOMExtractionOutput(out)
        XCTAssertEqual(pairs.count, 3)
        XCTAssertEqual(pairs[0].label, "Full Name"); XCTAssertEqual(pairs[0].value, "Minh")
        XCTAssertEqual(pairs[1].label, "Home campus"); XCTAssertEqual(pairs[1].value, "")
        XCTAssertEqual(pairs[2].value, "https://a.b/c:::d")
    }

    // MARK: - Model reconciliation (end-to-end: DOM snapshot -> session fields)

    private func makeModel() -> ApplicationFormModel {
        let model = ApplicationFormModel()
        model.startTracking(title: "Laguna Schools Application", appName: "Google Chrome")
        model.isFormDetected = true
        model.isAutoCaptureEnabled = true
        model.addField(label: "Full Name", value: "")
        model.addField(label: "Email Address", value: "")
        return model
    }

    func testSnapshotFromMockFormPopulatesSession() async throws {
        let web = try await makeWebView(html: Self.mockGoogleFormHTML)
        _ = try await web.evaluateJavaScript("""
        document.querySelector('#name input').value = 'Minh Nguyen';
        document.querySelector('#email input').value = 'minh@laguna.edu'; true;
        """)
        let model = makeModel()
        let changed = model.applyLiveSnapshot(try await runExtraction(web))
        XCTAssertGreaterThanOrEqual(changed, 2)
        XCTAssertEqual(model.activeSession?.fields.first { $0.label == "Full Name" }?.value, "Minh Nguyen")
        XCTAssertEqual(model.activeSession?.fields.first { $0.label == "Email Address" }?.value, "minh@laguna.edu")
        XCTAssertEqual(model.recipientEmail, "minh@laguna.edu")
        // Unanswered questions must not create bogus answered fields
        XCTAssertFalse(model.activeSession?.fields.contains { $0.label == "Home campus" && !$0.value.isEmpty } ?? true)
    }

    func testClearedBrowserAnswerIsClearedInMorph() {
        let model = makeModel()
        model.applyLiveSnapshot([(label: "Full Name", value: "Minh")])
        XCTAssertEqual(model.activeSession?.fields[0].value, "Minh")
        // Quiet period elapsed, browser now reports empty
        let later = Date().addingTimeInterval(ApplicationFormModel.clearGuardInterval + 1)
        let changed = model.applyLiveSnapshot([(label: "Full Name", value: "")], now: later)
        XCTAssertEqual(changed, 1)
        XCTAssertEqual(model.activeSession?.fields[0].value, "")
    }

    func testStaleEmptyReadDoesNotWipeFreshCapture() {
        let model = makeModel()
        model.applyLiveSnapshot([(label: "Full Name", value: "Minh")])
        let changed = model.applyLiveSnapshot([(label: "Full Name", value: "")], now: Date())
        XCTAssertEqual(changed, 0)
        XCTAssertEqual(model.activeSession?.fields[0].value, "Minh", "Fresh capture is protected by the guard interval")
    }

    func testManuallyEnteredAnswersAreNeverClearedByBrowserScan() {
        let model = makeModel()
        model.updateFieldByIndex(0, value: "Typed in Morph")
        let later = Date().addingTimeInterval(ApplicationFormModel.clearGuardInterval + 1)
        let changed = model.applyLiveSnapshot([(label: "Full Name", value: "")], now: later)
        XCTAssertEqual(changed, 0)
        XCTAssertEqual(model.activeSession?.fields[0].value, "Typed in Morph")
    }

    func testManualEditOfBrowserCapturedFieldTransfersOwnership() {
        let model = makeModel()
        model.applyLiveSnapshot([(label: "Full Name", value: "Minh")])
        model.updateFieldByIndex(0, value: "Edited in Morph")
        let later = Date().addingTimeInterval(ApplicationFormModel.clearGuardInterval + 1)
        model.applyLiveSnapshot([(label: "Full Name", value: "")], now: later)
        XCTAssertEqual(model.activeSession?.fields[0].value, "Edited in Morph")
    }

    func testEmptyReadForUnknownOrFuzzyLabelNeverClears() {
        let model = makeModel()
        model.applyLiveSnapshot([(label: "Full Name", value: "Minh")])
        let later = Date().addingTimeInterval(ApplicationFormModel.clearGuardInterval + 1)
        let changed = model.applyLiveSnapshot([(label: "Name of parent", value: ""), (label: "Something else", value: "")], now: later)
        XCTAssertEqual(changed, 0)
        XCTAssertEqual(model.activeSession?.fields[0].value, "Minh")
    }

    func testSnapshotIgnoredWhenAutoCaptureDisabledOrNoForm() {
        let model = makeModel()
        model.isAutoCaptureEnabled = false
        XCTAssertEqual(model.applyLiveSnapshot([(label: "Full Name", value: "Minh")]), 0)
        XCTAssertEqual(model.activeSession?.fields[0].value, "")
        model.isAutoCaptureEnabled = true
        model.isFormDetected = false
        XCTAssertEqual(model.applyLiveSnapshot([(label: "Full Name", value: "Minh")]), 0)
    }
}
