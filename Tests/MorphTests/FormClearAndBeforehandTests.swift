import XCTest
@testable import morph

@MainActor
final class FormClearAndBeforehandTests: XCTestCase {

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
        model.isAutoCaptureEnabled = true
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

    // MARK: - 1. Clear Form Detection Tests

    func testClearAllFormAnswersResetsAllFieldsAndAdvancesToFirstQuestion() {
        let (model, _) = makeLagunaModel()
        model.applyExtractedInput(label: "Full Name", value: "Minh Nguyen")
        model.applyExtractedInput(label: "Institution", value: "UC Berkeley")
        model.applyExtractedInput(label: "Email", value: "minh@berkeley.edu")
        XCTAssertEqual(model.activeSession?.answeredCount, 3)

        // Clear all answers
        model.clearAllFormAnswers()

        XCTAssertEqual(model.activeSession?.answeredCount, 0)
        XCTAssertEqual(value(model, "Full Name"), "")
        XCTAssertEqual(value(model, "Institution"), "")
        XCTAssertEqual(value(model, "Email"), "")
        XCTAssertTrue(model.browserCapturedFieldIDs.isEmpty)
        // Active field should advance past the info header to the first actionable question (consent)
        XCTAssertEqual(model.activeFieldIndex, 1)
    }

    func testSnapshotDetectingAllBrowserInputsEmptyClearsMorphAnswers() {
        let (model, _) = makeLagunaModel()
        // Simulate user filled in several questions
        model.applyLiveSnapshot([
            (label: "Full Name", value: "Minh Nguyen"),
            (label: "Institution", value: "UC Berkeley"),
            (label: "Contact Number", value: "555-1234"),
            (label: "Email", value: "minh@berkeley.edu")
        ])
        XCTAssertEqual(model.activeSession?.answeredCount, 4)

        // Now user clicks 'Clear form' on Google Form: all browser inputs are now empty!
        let emptySnapshot: [(label: String, value: String)] = [
            (label: "Full Name", value: ""),
            (label: "Institution", value: ""),
            (label: "Contact Number", value: ""),
            (label: "Email", value: "")
        ]
        let cleared = model.applyLiveSnapshot(emptySnapshot)

        XCTAssertEqual(cleared, 4, "Must clear all 4 answered fields when browser form is emptied")
        XCTAssertEqual(model.activeSession?.answeredCount, 0)
        XCTAssertEqual(value(model, "Full Name"), "")
        XCTAssertEqual(value(model, "Institution"), "")
        XCTAssertEqual(value(model, "Contact Number"), "")
        XCTAssertEqual(value(model, "Email"), "")
        XCTAssertEqual(model.activeFieldIndex, 1)
    }

    func testClearFormKeywordRecognition() {
        // Test various localizations and formats of 'Clear form'
        let english = "Clear form"
        let vietnamese = "Xóa câu trả lời"
        let spanish = "Borrar formulario"

        func matches(_ t: String) -> Bool {
            let keywords = ["clear form", "xóa câu trả lời", "effacer le formulaire", "borrar formulario", "formular leeren", "limpar formulário"]
            let lower = t.lowercased()
            return keywords.contains { lower == $0 || lower.hasPrefix($0) || lower.contains($0) }
        }

        XCTAssertTrue(matches(english))
        XCTAssertTrue(matches(vietnamese))
        XCTAssertTrue(matches(spanish))
        XCTAssertFalse(matches("Submit"))
        XCTAssertFalse(matches("Next"))
    }

    func testSingleFieldClearedInBrowserOnlyClearsThatField() {
        let (model, _) = makeLagunaModel()
        model.applyLiveSnapshot([
            (label: "Full Name", value: "Minh Nguyen"),
            (label: "Institution", value: "UC Berkeley")
        ])
        XCTAssertEqual(model.activeSession?.answeredCount, 2)

        // User deletes ONLY 'Institution' in the browser
        let later = Date().addingTimeInterval(ApplicationFormModel.clearGuardInterval + 1)
        let changed = model.applyLiveSnapshot([
            (label: "Full Name", value: "Minh Nguyen"),
            (label: "Institution", value: "")
        ], now: later)

        XCTAssertEqual(changed, 1)
        XCTAssertEqual(value(model, "Full Name"), "Minh Nguyen", "Unmodified field must remain intact")
        XCTAssertEqual(value(model, "Institution"), "", "Cleared field must be emptied")
        XCTAssertEqual(model.activeSession?.answeredCount, 1)
    }

    func testTypingAnewAfterClearFormCapturesFreshAnswers() {
        let (model, tracker) = makeLagunaModel()
        model.applyExtractedInput(label: "Full Name", value: "Old Name")
        XCTAssertEqual(value(model, "Full Name"), "Old Name")

        // User cleared the form
        model.clearAllFormAnswers()
        XCTAssertEqual(value(model, "Full Name"), "")

        // Now user starts typing fresh answer into Full Name
        let nameFieldId = model.activeSession!.fields.first { $0.label == "Full Name" }!.id
        tracker.confirmFocus(fieldID: nameFieldId)
        tracker.handleKeyStroke(keyCode: 0, flags: [], characters: "Minh")

        XCTAssertEqual(value(model, "Full Name"), "Minh", "Fresh typing after clear form must be captured correctly")
        XCTAssertEqual(model.activeSession?.answeredCount, 1)
    }

    // MARK: - 2. Beforehand Filled Answers Tests

    func testBeforehandFilledAnswersArePopulatedWhenFormDetectedLate() {
        let (model, _) = makeLagunaModel()
        XCTAssertEqual(model.activeSession?.answeredCount, 0)

        // User had already filled in 4 fields before Morph detected the form
        let beforehandSnapshot = [
            (label: "Full Name", value: "Sarah Connor"),
            (label: "Institution", value: "Stanford University"),
            (label: "Contact Number", value: "650-555-0199"),
            (label: "Email", value: "sarah@stanford.edu")
        ]

        let count = model.applyLiveSnapshot(beforehandSnapshot)

        XCTAssertEqual(count, 4, "Must apply all 4 beforehand answers")
        XCTAssertEqual(value(model, "Full Name"), "Sarah Connor")
        XCTAssertEqual(value(model, "Institution"), "Stanford University")
        XCTAssertEqual(value(model, "Contact Number"), "650-555-0199")
        XCTAssertEqual(value(model, "Email"), "sarah@stanford.edu")
        XCTAssertEqual(model.activeSession?.answeredCount, 4)
    }

    func testBeforehandFilledAnswersAdvanceActiveFieldToFirstUnanswered() {
        let (model, _) = makeLagunaModel()
        // Suppose user filled:
        // - "I consent..." (field 1)
        // - "Full Name" (field 3)
        // - "Institution" (field 4)
        // Leaving "Contact Number" (field 5) unanswered
        model.applyLiveSnapshot([
            (label: "I consent to sharing the information in this form", value: "Yes"),
            (label: "Full Name", value: "Sarah Connor"),
            (label: "Institution", value: "Stanford University")
        ])

        // advanceToFirstUnansweredFieldIfNeeded should move to Contact Number (field 5)
        model.advanceToFirstUnansweredFieldIfNeeded()
        XCTAssertEqual(model.activeFieldIndex, 5)
        XCTAssertEqual(model.activeSession?.fields[model.activeFieldIndex].label, "Contact Number")
    }

    func testBeforehandEmailUpdatesRecipientEmail() {
        let (model, _) = makeLagunaModel()
        XCTAssertEqual(model.recipientEmail, "user@example.com")

        // User filled in email beforehand
        model.applyLiveSnapshot([
            (label: "Email", value: "scholar@oxford.ac.uk")
        ])

        XCTAssertEqual(model.recipientEmail, "scholar@oxford.ac.uk", "Recipient email must be updated from beforehand answer")
        XCTAssertEqual(model.activeSession?.recipientEmail, "scholar@oxford.ac.uk")
    }

    func testBeforehandAnswersMergedWithAsyncRetrievedSchema() {
        let model = ApplicationFormModel()
        model.startTracking(title: "Scholarship Application", appName: "Polar")
        XCTAssertEqual(model.activeSession?.fields.count, 0)

        // 1. Before schema is retrieved, browser AX scan discovers beforehand answers:
        model.applyLiveSnapshot([
            (label: "Full Legal Name", value: "Jane Doe"),
            (label: "Contact Email", value: "jane@mit.edu")
        ])
        XCTAssertEqual(model.activeSession?.fields.count, 2)
        XCTAssertEqual(model.activeSession?.fields[0].value, "Jane Doe")
        XCTAssertEqual(model.activeSession?.fields[1].value, "jane@mit.edu")

        // 2. HTTP schema retrieval finishes with full 4-field schema (empty values):
        let fullSchema = FormContentRetriever.RetrievedFormSchema(
            title: "Scholarship Application",
            description: "Apply for 2026 funding",
            fields: [
                FormInputField(label: "Full Legal Name", value: "", questionType: "shortAnswer", entryKey: "entry.1"),
                FormInputField(label: "Contact Email", value: "", questionType: "shortAnswer", entryKey: "entry.2"),
                FormInputField(label: "Major", value: "", questionType: "shortAnswer", entryKey: "entry.3"),
                FormInputField(label: "GPA", value: "", questionType: "shortAnswer", entryKey: "entry.4")
            ]
        )

        // Simulate merge in autoRetrieveFormContent:
        var merged = fullSchema.fields
        let current = model.activeSession!.fields
        for i in 0..<merged.count {
            if let matchIdx = ApplicationFormModel.bestMatchingFieldIndex(for: merged[i].label, in: current) {
                let existing = current[matchIdx]
                if !existing.value.isEmpty && merged[i].value.isEmpty {
                    merged[i].value = existing.value
                    merged[i].id = existing.id
                    model.markBrowserCaptured(existing.id)
                }
            }
        }
        model.activeSession?.fields = merged
        model.advanceToFirstUnansweredFieldIfNeeded()

        XCTAssertEqual(model.activeSession?.fields.count, 4)
        XCTAssertEqual(model.activeSession?.fields[0].value, "Jane Doe", "Beforehand answer must be preserved in merged schema")
        XCTAssertEqual(model.activeSession?.fields[1].value, "jane@mit.edu", "Beforehand answer must be preserved in merged schema")
        XCTAssertEqual(model.activeSession?.fields[2].value, "")
        XCTAssertEqual(model.activeSession?.fields[3].value, "")
        XCTAssertEqual(model.activeSession?.answeredCount, 2)
        // Must point to first unanswered field: Major (index 2)
        XCTAssertEqual(model.activeFieldIndex, 2)
    }

    func testAllQuestionsFilledBeforehandResultsInCompleteForm() {
        let (model, _) = makeLagunaModel()

        // User filled in all actionable questions before Morph opened
        model.applyLiveSnapshot([
            (label: "I consent to sharing the information in this form", value: "Yes"),
            (label: "Full Name", value: "Sarah Connor"),
            (label: "Institution", value: "Stanford"),
            (label: "Contact Number", value: "1234567890"),
            (label: "Email", value: "sarah@stanford.edu"),
            (label: "Alternative Contact", value: "sarah.alt@stanford.edu")
        ])

        XCTAssertEqual(model.activeSession?.answeredCount, 6)
        XCTAssertEqual(model.activeSession?.totalQuestions, 6)
        XCTAssertEqual(model.activeSession?.completionPercentage, 100.0)
    }
}
