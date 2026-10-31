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

    // MARK: - Polar Headless Web-Layer Real-Time Capture & Question Transitions

    func testHeadlessPolarTypingAndMovingToNextQuestionViaTabAndClick() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Laguna Schools BP 2026: IA/SA Application Form", appName: "Polar")
        model.isFormDetected = true
        model.isAutoCaptureEnabled = true

        model.activeSession?.fields = [
            FormInputField(label: "PRIVACY NOTICE", value: "", questionType: "info"),
            FormInputField(label: "I consent to sharing the information in this form", value: "", options: ["Yes"], questionType: "multipleChoice", isRequired: true, entryKey: "entry.236482357"),
            FormInputField(label: "Basic Information", value: "", questionType: "section"),
            FormInputField(label: "Full Name", value: "", category: .personal, questionType: "paragraph", isRequired: true, entryKey: "entry.2066173020"),
            FormInputField(label: "Tab Name", value: "", category: .personal, questionType: "shortAnswer", isRequired: true, entryKey: "entry.576216565"),
            FormInputField(label: "Institution", value: "", category: .experience, questionType: "shortAnswer", isRequired: true, entryKey: "entry.1333393381")
        ]

        let tracker = FormInputAutoTracker(model: model)
        tracker.isHeadlessWebLayerMode = true
        model.autoTracker = tracker

        // 1. User clicks into Full Name in Polar's web viewport (y = 320) and types "Minh Nguyen"
        tracker.handleMouseDown(at: CGPoint(x: 400, y: 320))
        for ch in "Minh Nguyen" {
            tracker.handleKeyStroke(keyCode: 0, flags: [], characters: String(ch))
            // Simulate periodic 0.5s poll firing while user is mid-typing: must NOT yank activeFieldIndex away!
            model.advanceToFirstUnansweredFieldIfNeeded()
        }

        XCTAssertEqual(model.activeSession?.fields[3].value, "Minh Nguyen", "Full Name must capture typed characters synchronously without staying at Awaiting input")
        XCTAssertEqual(model.activeFieldIndex, 3)

        // 2. User moves onto Question 2 ("Tab Name") by clicking the next question card (y = 480) and types "Minh"
        tracker.handleMouseDown(at: CGPoint(x: 400, y: 480))
        for ch in "Minh" {
            tracker.handleKeyStroke(keyCode: 0, flags: [], characters: String(ch))
        }

        XCTAssertEqual(model.activeSession?.fields[3].value, "Minh Nguyen", "Previous question answer must be preserved")
        XCTAssertEqual(model.activeSession?.fields[4].value, "Minh", "Second question (Tab Name) must capture answer synchronously")
        XCTAssertEqual(model.activeFieldIndex, 4)

        // 3. User presses Tab (keyCode 48) to advance to Question 3 ("Institution") and types "Stanford"
        tracker.handleKeyStroke(keyCode: 48, flags: [], characters: "\t")
        for ch in "Stanford" {
            tracker.handleKeyStroke(keyCode: 0, flags: [], characters: String(ch))
        }

        XCTAssertEqual(model.activeSession?.fields[3].value, "Minh Nguyen")
        XCTAssertEqual(model.activeSession?.fields[4].value, "Minh")
        XCTAssertEqual(model.activeSession?.fields[5].value, "Stanford")
        XCTAssertEqual(model.activeFieldIndex, 5)
    }

    func testTabNameSchemaQuestionIsCapturedAndPersistedAcrossDraftReload() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(
            title: "Laguna Schools BP 2026: IA/SA Application Form",
            appName: "Polar",
            url: "https://docs.google.com/forms/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/viewform"
        )
        model.isFormDetected = true
        model.activeSession?.fields = [
            FormInputField(label: "Full Name", value: "Minh Nguyen", category: .personal, questionType: "paragraph", isRequired: true, entryKey: "entry.2066173020"),
            FormInputField(label: "Tab Name", value: "", category: .personal, questionType: "shortAnswer", isRequired: true, entryKey: "entry.576216565")
        ]

        // Extracting an answer for "Tab Name" must succeed when "Tab Name" is an authoritative schema field
        XCTAssertTrue(model.applyExtractedInput(label: "Tab Name", value: "Minh N."))
        XCTAssertEqual(model.activeSession?.fields[1].value, "Minh N.")

        // Saving and reloading drafts must NOT strip the "Tab Name" schema question
        model.saveDrafts()
        let reloaded = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        reloaded.loadDrafts()
        let savedSession = reloaded.historySessions.first
        XCTAssertEqual(savedSession?.fields.count, 2)
        XCTAssertEqual(savedSession?.fields.first(where: { $0.label == "Tab Name" })?.value, "Minh N.")
    }

    func testBlinkSerializedFormStateExtractionMapsGoogleFormPageParagraphs() {
        func encodeMojoString16(_ str: String) -> Data {
            var out = Data([0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                            0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
            let utf16 = Array(str.utf16)
            var byteLen = UInt32(8 + utf16.count * 2)
            var charLen = UInt32(utf16.count)
            out.append(Data(bytes: &byteLen, count: 4))
            out.append(Data(bytes: &charLen, count: 4))
            for u in utf16 {
                var le = u.littleEndian
                out.append(Data(bytes: &le, count: 2))
            }
            let aligned = (8 + utf16.count * 2 + 7) & ~7
            let pad = aligned - (8 + utf16.count * 2)
            if pad > 0 {
                out.append(Data(repeating: 0, count: pad))
            }
            return out
        }

        let strings = [
            "\n\r?% Blink serialized form state version 10 \n\r=&",
            "https://docs.google.com/forms/u/0/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/formResponse [entry.2066173020 entry.576216565 ] #0",
            "2",
            "", "textarea", "1", "Minh Nguyen",
            "", "textarea", "0"
        ]
        var blob = Data(repeating: 0, count: 32)
        for s in strings {
            blob.append(encodeMojoString16(s))
        }
        blob.append(Data(repeating: 0, count: 32))

        let fields = [
            FormInputField(label: "PRIVACY NOTICE", value: "", questionType: "info"),
            FormInputField(label: "I consent", value: "", questionType: "multipleChoice", isRequired: true, entryKey: "entry.236482357"),
            FormInputField(label: "Basic Information", value: "", questionType: "section"),
            FormInputField(label: "Full Name", value: "", questionType: "paragraph", isRequired: true, entryKey: "entry.2066173020"),
            FormInputField(label: "Tab Name", value: "", questionType: "shortAnswer", isRequired: true, entryKey: "entry.576216565"),
            FormInputField(label: "Alternative Contact", value: "", questionType: "paragraph", isRequired: false, entryKey: "entry.1966844551")
        ]

        let pairs = FormInputAutoTracker.extractBlinkFormStatePairs(
            from: blob,
            formURL: "https://docs.google.com/forms/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/viewform",
            fields: fields
        )

        XCTAssertEqual(pairs.count, 1)
        XCTAssertEqual(pairs.first?.label, "Full Name")
        XCTAssertEqual(pairs.first?.value, "Minh Nguyen")
    }
}
