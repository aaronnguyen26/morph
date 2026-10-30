import XCTest
@testable import morph

/// Regression tests for "the answer showed up under the wrong question".
/// Mirrors the real Laguna Schools Google Form that exposed the bug: typing "Aaron Nguyen" into Full Name
/// was split across Full Name / a bogus "Tab Name" field / Institution / Contact Number.
@MainActor
final class FieldAttributionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: ApplicationFormModel.draftsStorageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ApplicationFormModel.draftsStorageKey)
        super.tearDown()
    }

    private func makeLagunaModel() -> (ApplicationFormModel, FormInputAutoTracker) {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Laguna Schools BP 2026: IA/SA Application Form", appName: "Polar")
        model.isFormDetected = true
        model.activeSession?.fields = [
            FormInputField(label: "PRIVACY NOTICE", value: "", questionType: "info"),
            FormInputField(label: "I consent to sharing the information in this form", value: "", options: ["Yes", "No"], questionType: "multipleChoice", isRequired: true, entryKey: "entry.1"),
            FormInputField(label: "Basic Information", value: "", questionType: "section"),
            FormInputField(label: "Full Name", value: "", category: .personal, questionType: "paragraph", isRequired: true, entryKey: "entry.2"),
            FormInputField(label: "Institution", value: "", category: .experience, questionType: "shortAnswer", isRequired: true, entryKey: "entry.3"),
            FormInputField(label: "Contact Number", value: "", category: .contact, questionType: "shortAnswer", isRequired: true, entryKey: "entry.4"),
            FormInputField(label: "Email", value: "", category: .contact, questionType: "shortAnswer", isRequired: true, entryKey: "entry.5"),
            FormInputField(label: "Alternative Contact", value: "", questionType: "paragraph", entryKey: "entry.6")
        ]
        let tracker = FormInputAutoTracker(model: model)
        return (model, tracker)
    }

    private func value(_ model: ApplicationFormModel, _ label: String) -> String? {
        model.activeSession?.fields.first { $0.label == label }?.value
    }

    private func id(_ model: ApplicationFormModel, _ label: String) -> UUID {
        model.activeSession!.fields.first { $0.label == label }!.id
    }

    private func type(_ tracker: FormInputAutoTracker, _ text: String, chunk: Int = 1) {
        var buf = ""
        for ch in text {
            buf.append(ch)
            if buf.count == chunk { tracker.handleKeyStroke(keyCode: 0, flags: [], characters: buf); buf = "" }
        }
        if !buf.isEmpty { tracker.handleKeyStroke(keyCode: 0, flags: [], characters: buf) }
    }

    // MARK: - The reported bug

    func testTypedNameStaysInFullNameAndNeverLeaksIntoOtherFields() {
        let (model, tracker) = makeLagunaModel()
        tracker.confirmFocus(fieldID: id(model, "Full Name"))
        type(tracker, "Aaron Nguyen")
        XCTAssertEqual(value(model, "Full Name"), "Aaron Nguyen")
        for other in ["Institution", "Contact Number", "Email", "Alternative Contact", "I consent to sharing the information in this form"] {
            XCTAssertEqual(value(model, other), "", "\(other) must stay empty")
        }
        XCTAssertEqual(model.activeSession?.fields.count, 8, "No bogus fields may be created")
    }

    func testFieldIndexDriftCannotMisdirectTyping() {
        let (model, tracker) = makeLagunaModel()
        tracker.confirmFocus(fieldID: id(model, "Full Name"))
        // Something (auto-advance, stale scan...) moves Morph's highlighted field while the browser stays on Full Name
        model.activeFieldIndex = 5
        type(tracker, "Aaron")
        XCTAssertEqual(value(model, "Full Name"), "Aaron", "Typing follows the browser-confirmed field, not Morph's highlighted index")
        XCTAssertEqual(value(model, "Email"), "")
    }

    func testTypingAfterTabIsHeldUntilFocusIsConfirmedThenLandsInRightField() {
        let (model, tracker) = makeLagunaModel()
        tracker.confirmFocus(fieldID: id(model, "Full Name"))
        type(tracker, "Aaron Nguyen")
        tracker.handleKeyStroke(keyCode: 48, flags: [], characters: "\t")
        type(tracker, "Laguna High")
        XCTAssertEqual(value(model, "Institution"), "", "Held until focus confirmed")
        XCTAssertEqual(value(model, "Full Name"), "Aaron Nguyen", "Previous answer untouched")
        tracker.confirmFocus(fieldID: id(model, "Institution"))
        XCTAssertEqual(value(model, "Institution"), "Laguna High")
        XCTAssertEqual(value(model, "Full Name"), "Aaron Nguyen")
    }

    func testClickDiscardsStrayTypingInsteadOfAssigningIt() {
        let (model, tracker) = makeLagunaModel()
        tracker.handleKeyStroke(keyCode: 0, flags: [], characters: "zzz")   // no confirmed focus
        XCTAssertEqual(tracker.pendingText, "zzz")
        tracker.invalidateFocus()                                              // focus moved (click/tab)
        XCTAssertEqual(tracker.pendingText, "")
        tracker.confirmFocus(fieldID: id(model, "Email"))
        XCTAssertEqual(value(model, "Email"), "", "Discarded text must not resurface")
    }

    func testBackspaceOnHeldTextEditsHeldTextOnly() {
        let (model, tracker) = makeLagunaModel()
        tracker.confirmFocus(fieldID: id(model, "Full Name"))
        type(tracker, "Keep")
        tracker.invalidateFocus()
        type(tracker, "ab")
        tracker.handleKeyStroke(keyCode: 51, flags: [], characters: nil)
        XCTAssertEqual(tracker.pendingText, "a")
        XCTAssertEqual(value(model, "Full Name"), "Keep")
    }

    func testBackspaceEditsOnlyTheConfirmedField() {
        let (model, tracker) = makeLagunaModel()
        tracker.confirmFocus(fieldID: id(model, "Full Name"))
        type(tracker, "Aaron")
        tracker.confirmFocus(fieldID: id(model, "Institution"))
        type(tracker, "UCLA")
        tracker.handleKeyStroke(keyCode: 51, flags: [], characters: nil)
        XCTAssertEqual(value(model, "Institution"), "UCL")
        XCTAssertEqual(value(model, "Full Name"), "Aaron")
    }

    func testLettersTypedNeverSelectChoiceAnswers() {
        let (model, tracker) = makeLagunaModel()
        tracker.confirmFocus(fieldID: id(model, "I consent to sharing the information in this form"))
        type(tracker, "a")
        XCTAssertEqual(value(model, "I consent to sharing the information in this form"), "")
    }

    // MARK: - Label matching never misattributes

    func testUnmatchedBrowserChromeLabelsCreateNoFieldsWhenSchemaIsLoaded() {
        let (model, _) = makeLagunaModel()
        XCTAssertFalse(model.applyExtractedInput(label: "Tab Name", value: "on Ng"))
        XCTAssertFalse(model.applyExtractedInput(label: "Rename tab", value: "x"))
        XCTAssertEqual(model.activeSession?.fields.count, 8)
    }

    func testHeadersAndSectionsNeverReceiveAnswers() {
        let (model, _) = makeLagunaModel()
        XCTAssertFalse(model.applyExtractedInput(label: "Basic Information", value: "x"))
        XCTAssertFalse(model.applyExtractedInput(label: "PRIVACY NOTICE", value: "x"))
        XCTAssertEqual(value(model, "Basic Information"), "")
        XCTAssertEqual(value(model, "PRIVACY NOTICE"), "")
    }

    func testSimilarLabelsGoToExactlyTheirOwnField() {
        let (model, _) = makeLagunaModel()
        XCTAssertTrue(model.applyExtractedInput(label: "Contact Number *", value: "555-0100"))
        XCTAssertTrue(model.applyExtractedInput(label: "Email", value: "aaron@laguna.edu"))
        XCTAssertTrue(model.applyExtractedInput(label: "Institution", value: "Laguna High"))
        XCTAssertEqual(value(model, "Contact Number"), "555-0100")
        XCTAssertEqual(value(model, "Email"), "aaron@laguna.edu")
        XCTAssertEqual(value(model, "Institution"), "Laguna High")
        XCTAssertEqual(value(model, "Alternative Contact"), "")
        XCTAssertEqual(value(model, "Full Name"), "")
    }

    func testUnrelatedLabelDoesNotFuzzyMatchIntoWrongField() {
        let (model, _) = makeLagunaModel()
        XCTAssertFalse(model.applyExtractedInput(label: "Parent Name", value: "Someone"))
        XCTAssertEqual(value(model, "Full Name"), "")
    }

    func testEntireFormSnapshotLandsEachAnswerOnItsOwnQuestion() {
        let (model, _) = makeLagunaModel()
        let changed = model.applyLiveSnapshot([
            (label: "Full Name", value: "Aaron Nguyen"),
            (label: "Institution", value: "Laguna High"),
            (label: "Contact Number", value: "555-0100"),
            (label: "Email", value: "aaron@laguna.edu"),
            (label: "Alternative Contact", value: "")
        ])
        XCTAssertEqual(changed, 4)
        XCTAssertEqual(model.activeSession?.fields.compactMap { $0.value.isEmpty ? nil : $0.label },
                       ["Full Name", "Institution", "Contact Number", "Email"])
        XCTAssertEqual(value(model, "Full Name"), "Aaron Nguyen")
        XCTAssertEqual(value(model, "Email"), "aaron@laguna.edu")
        XCTAssertEqual(model.recipientEmail, "aaron@laguna.edu")
    }

    func testStrictMatchingOnlyReturnsActionableIndices() {
        let (model, _) = makeLagunaModel()
        let fields = model.activeSession!.fields
        XCTAssertNil(ApplicationFormModel.strictMatchingFieldIndex(for: "Basic Information", in: fields))
        XCTAssertEqual(ApplicationFormModel.strictMatchingFieldIndex(for: "Full Name *", in: fields), 3)
        XCTAssertNil(ApplicationFormModel.strictMatchingFieldIndex(for: "Tab Name", in: fields))
    }

    func testSchemalessSessionStillDiscoversFieldsDynamically() {
        let model = ApplicationFormModel()
        model.startTracking(title: "Unknown Form", appName: "Polar")
        XCTAssertTrue(model.applyExtractedInput(label: "Company", value: "Morph"))
        XCTAssertEqual(model.activeSession?.fields.count, 1)
    }
}
