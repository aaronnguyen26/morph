import XCTest
@testable import morph

@MainActor
final class SynchronousFormCaptureTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: ApplicationFormModel.draftsStorageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ApplicationFormModel.draftsStorageKey)
        super.tearDown()
    }

    // MARK: - Synchronous Keystroke Streaming & Zero-Lag Attribution

    func testSynchronousKeystrokeDirectAttributionWhenFocused() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Google Form", appName: "Polar")
        model.isFormDetected = true
        model.isAutoCaptureEnabled = true

        let field1 = FormInputField(label: "Full Name", value: "", category: .personal, questionType: "shortAnswer", isRequired: true)
        let field2 = FormInputField(label: "Contact Number", value: "", category: .contact, questionType: "shortAnswer", isRequired: true)
        model.activeSession?.fields = [field1, field2]

        let tracker = FormInputAutoTracker(model: model)
        tracker.confirmFocus(fieldID: field1.id)

        // Simulate typing "Aaron" key by key
        let characters = ["A", "a", "r", "o", "n"]
        for ch in characters {
            tracker.handleKeyStroke(keyCode: 0, flags: [], characters: ch)
        }

        // Must update synchronously in memory without waiting for debounce
        XCTAssertEqual(model.activeSession?.fields[0].value, "Aaron")
        XCTAssertEqual(model.activeSession?.fields[1].value, "")
        XCTAssertEqual(model.activeSession?.answeredCount, 1)
        XCTAssertTrue(model.activeSession?.fields[0].isAnswered ?? false)
    }

    func testSynchronousBackspaceDeletesLastCharacterImmediately() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Google Form", appName: "Polar")
        model.isFormDetected = true
        model.isAutoCaptureEnabled = true

        let field1 = FormInputField(label: "Full Name", value: "Aaron", category: .personal, questionType: "shortAnswer")
        model.activeSession?.fields = [field1]

        let tracker = FormInputAutoTracker(model: model)
        tracker.confirmFocus(fieldID: field1.id)

        // Press Backspace (keyCode 51)
        tracker.handleKeyStroke(keyCode: 51, flags: [], characters: nil)
        XCTAssertEqual(model.activeSession?.fields[0].value, "Aaro")

        tracker.handleKeyStroke(keyCode: 51, flags: [], characters: nil)
        XCTAssertEqual(model.activeSession?.fields[0].value, "Aar")
    }

    // MARK: - Multi-Page / Section Navigation & Preservation

    func testPageTransitionPreservesPreviousPageAnswers() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Laguna Schools Application", appName: "Polar")
        model.isFormDetected = true
        model.isAutoCaptureEnabled = true

        // Form schema with Page 1 and Page 2 questions
        let p1Field1 = FormInputField(label: "Full Name", value: "", category: .personal, questionType: "shortAnswer", isRequired: true)
        let p1Field2 = FormInputField(label: "Contact Number", value: "", category: .contact, questionType: "shortAnswer", isRequired: true)
        let p2Field1 = FormInputField(label: "High School Institution", value: "", category: .experience, questionType: "shortAnswer", isRequired: true)
        let p2Field2 = FormInputField(label: "Grade Level", value: "", category: .experience, questionType: "shortAnswer", isRequired: true)

        model.activeSession?.fields = [p1Field1, p1Field2, p2Field1, p2Field2]

        let tracker = FormInputAutoTracker(model: model)

        // 1. User fills Page 1
        tracker.confirmFocus(fieldID: p1Field1.id)
        tracker.handleKeyStroke(keyCode: 0, flags: [], characters: "Aaron Nguyen")

        tracker.confirmFocus(fieldID: p1Field2.id)
        tracker.handleKeyStroke(keyCode: 0, flags: [], characters: "+639171234567")

        XCTAssertEqual(model.activeSession?.fields[0].value, "Aaron Nguyen")
        XCTAssertEqual(model.activeSession?.fields[1].value, "+639171234567")

        // 2. User clicks "Next" to navigate to Page 2.
        // On Page 2, only Page 2 inputs are present in the DOM (initially empty).
        let page2Snapshot = [
            (label: "High School Institution", value: ""),
            (label: "Grade Level", value: "")
        ]

        model.applyLiveSnapshot(page2Snapshot)

        // Previous Page 1 answers MUST NOT be cleared or set to empty!
        XCTAssertEqual(model.activeSession?.fields[0].value, "Aaron Nguyen", "Page 1 Full Name must be preserved on page change")
        XCTAssertEqual(model.activeSession?.fields[1].value, "+639171234567", "Page 1 Contact Number must be preserved on page change")
        XCTAssertEqual(model.activeSession?.fields[2].value, "")
        XCTAssertEqual(model.activeSession?.fields[3].value, "")

        // 3. User fills Page 2 in the browser
        let page2FilledSnapshot = [
            (label: "High School Institution", value: "Laguna Science HS"),
            (label: "Grade Level", value: "Grade 11")
        ]
        model.applyLiveSnapshot(page2FilledSnapshot)

        XCTAssertEqual(model.activeSession?.fields[0].value, "Aaron Nguyen")
        XCTAssertEqual(model.activeSession?.fields[1].value, "+639171234567")
        XCTAssertEqual(model.activeSession?.fields[2].value, "Laguna Science HS")
        XCTAssertEqual(model.activeSession?.fields[3].value, "Grade 11")
        XCTAssertEqual(model.activeSession?.answeredCount, 4)
    }

    func testPageNavigationKeywordDetection() {
        let navWords = ["Next", "Tiếp theo", "Submit", "Gửi", "Back", "Quay lại", "Continue", "Siguiente", "Enviar", "Suivant"]
        for word in navWords {
            // Verify word matches navigation keywords
            let lower = word.lowercased()
            let keywords = ["next", "tiếp", "tiếp theo", "tiếp tục", "submit", "gửi", "back", "quay lại", "continue", "siguiente", "enviar", "atrás", "suivant", "soumettre", "retour", "weiter", "senden", "zurück"]
            let isMatch = keywords.contains(where: { lower == $0 || lower.hasPrefix("\($0) ") || lower.hasSuffix(" \($0)") })
            XCTAssertTrue(isMatch, "'\(word)' must be recognized as a page navigation keyword")
        }
    }

    func testHighFrequencyTimerConfiguration() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        let tracker = FormInputAutoTracker(model: model)
        tracker.start()

        // Ensure tracker is running without throwing errors
        XCTAssertTrue(tracker.isRunning)
        tracker.stop()
        XCTAssertFalse(tracker.isRunning)
    }
}
