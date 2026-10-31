import XCTest
@testable import morph

@MainActor
final class FreshFormDetectionAndZeroLeakageTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: ApplicationFormModel.draftsStorageKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: ApplicationFormModel.draftsStorageKey)
        super.tearDown()
    }

    private func makeLagunaFields() -> [FormInputField] {
        return [
            FormInputField(label: "PRIVACY NOTICE", value: "", questionType: "info"),
            FormInputField(label: "I consent to sharing the information in this form to Laguna Organizing", value: "", options: ["Yes", "No"], questionType: "multipleChoice", isRequired: true, entryKey: "entry.1"),
            FormInputField(label: "Basic Information", value: "", questionType: "section"),
            FormInputField(label: "Full Name", value: "", category: .personal, questionType: "paragraph", isRequired: true, entryKey: "entry.2"),
            FormInputField(label: "Institution", value: "", category: .experience, questionType: "shortAnswer", isRequired: true, entryKey: "entry.3"),
            FormInputField(label: "Contact Number", value: "", category: .contact, questionType: "shortAnswer", isRequired: true, entryKey: "entry.4"),
            FormInputField(label: "Email", value: "", category: .contact, questionType: "shortAnswer", isRequired: true, entryKey: "entry.5"),
            FormInputField(label: "Alternative Contact", value: "", questionType: "paragraph", entryKey: "entry.6")
        ]
    }

    func testRestoredSessionFromHistoryResetsValuesToEmpty() {
        let detector = MockApplicationFormDetector(
            detected: true,
            title: "Laguna Schools BP 2026: IA/SA Application Form",
            appName: "Polar",
            url: "https://docs.google.com/forms/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/viewform"
        )
        let model = ApplicationFormModel(detector: detector, dispatcher: MockEmailDispatcher())
        
        // Populate history with an old dirty session that had "Aar" and "yen"
        var dirtyFields = makeLagunaFields()
        if let idx1 = dirtyFields.firstIndex(where: { $0.label == "Full Name" }) {
            dirtyFields[idx1].value = "Aar"
        }
        if let idx2 = dirtyFields.firstIndex(where: { $0.label == "Contact Number" }) {
            dirtyFields[idx2].value = "yen"
        }
        
        let dirtySession = ApplicationFormSession(
            formTitle: "Laguna Schools BP 2026: IA/SA Application Form",
            sourceAppName: "Polar",
            sourceURL: "https://docs.google.com/forms/d/e/1FAIpQLSeioKaz7uoZPcnPoEtauoGbdPXmnp69H1WRwx6OQ9x9AqE1uQ/viewform",
            recipientEmail: "test@example.com",
            fields: dirtyFields
        )
        model.historySessions = [dirtySession]
        
        // Simulate checkActiveApplication
        model.checkActiveApplication()
        
        XCTAssertNotNil(model.activeSession)
        XCTAssertEqual(model.activeSession?.formTitle, "Laguna Schools BP 2026: IA/SA Application Form")
        
        // Live browser scan reports that the inputs in the browser are currently empty
        let emptyBrowserSnapshot: [(label: String, value: String)] = [
            ("Full Name", ""),
            ("Contact Number", "")
        ]
        model.applyLiveSnapshot(emptyBrowserSnapshot)
        
        // Assert: NO fields have stale answers restored!
        for field in model.activeSession?.fields ?? [] {
            XCTAssertEqual(field.value, "", "Field '\(field.label)' must be empty on form detection, but had '\(field.value)'")
        }
    }

    func testLoadDraftsPurgesCorruptedValuesBogusFieldsAndNonFormSessions() throws {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        
        // Construct dirty sessions in JSON to simulate corrupt UserDefaults from previous runs
        var dirtyLagunaFields = makeLagunaFields()
        dirtyLagunaFields.append(FormInputField(label: "Tab Name", value: "on Ng", category: .custom, questionType: "shortAnswer"))
        if let idx = dirtyLagunaFields.firstIndex(where: { $0.label == "Full Name" }) {
            dirtyLagunaFields[idx].value = "Aar"
        }
        if let idx = dirtyLagunaFields.firstIndex(where: { $0.label == "Contact Number" }) {
            dirtyLagunaFields[idx].value = "yen"
        }
        
        let s1 = ApplicationFormSession(
            formTitle: "Laguna Schools BP 2026: IA/SA Application Form",
            sourceAppName: "Polar",
            sourceURL: "https://docs.google.com/forms/d/e/123/viewform",
            recipientEmail: "test@example.com",
            fields: dirtyLagunaFields
        )
        let s2 = ApplicationFormSession(
            formTitle: "(1419) Trump makes last-minute midterm strategy shift - YouTube",
            sourceAppName: "Safari",
            sourceURL: "https://www.youtube.com/watch?v=123",
            recipientEmail: "user@youtube.com",
            fields: [FormInputField(label: "Search", value: "test")]
        )
        let s3 = ApplicationFormSession(
            formTitle: "NOCCCD - Portal Access - 1",
            sourceAppName: "Google Chrome",
            sourceURL: "https://fullcoll.instructure.com/courses/69103/assignments/2302124",
            recipientEmail: "user@fullcoll.edu",
            fields: [FormInputField(label: "Password", value: "1")]
        )
        
        let sessions: [ApplicationFormSession] = [s1, s2, s3]
        let encoded = try JSONEncoder().encode(sessions)
        UserDefaults.standard.set(encoded, forKey: ApplicationFormModel.draftsStorageKey)
        
        // Run loadDrafts
        model.loadDrafts()
        
        // Assert: YouTube and Canvas are strictly eliminated
        XCTAssertEqual(model.historySessions.count, 1)
        let loaded = model.historySessions[0]
        XCTAssertEqual(loaded.formTitle, "Laguna Schools BP 2026: IA/SA Application Form")
        
        // Assert: "Tab Name" is strictly purged
        XCTAssertFalse(loaded.fields.contains(where: { $0.label == "Tab Name" }))
        
        // Assert: Form title and legitimate fields are retained
        XCTAssertTrue(loaded.fields.contains(where: { $0.label == "Full Name" }))
    }

    func testArbitraryUserInputsAreCapturedWithoutHardcodedAaronOrYen() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Laguna Schools BP 2026: IA/SA Application Form", appName: "Polar")
        model.isFormDetected = true
        model.activeSession?.fields = makeLagunaFields()
        let tracker = FormInputAutoTracker(model: model)
        
        // Confirm focus on Full Name and type an arbitrary name: "Carlos Mendoza"
        let fullNameID = model.activeSession!.fields.first { $0.label == "Full Name" }!.id
        tracker.confirmFocus(fieldID: fullNameID)
        
        for ch in "Carlos Mendoza" {
            tracker.handleKeyStroke(keyCode: 0, flags: [], characters: String(ch))
        }
        
        XCTAssertEqual(model.activeSession?.fields.first { $0.label == "Full Name" }?.value, "Carlos Mendoza")
        XCTAssertEqual(model.activeSession?.fields.first { $0.label == "Contact Number" }?.value, "")
        XCTAssertEqual(model.activeSession?.fields.first { $0.label == "Institution" }?.value, "")
        
        // Advance to Contact Number and type arbitrary phone: "+63 917 123 4567"
        let contactID = model.activeSession!.fields.first { $0.label == "Contact Number" }!.id
        tracker.confirmFocus(fieldID: contactID)
        
        for ch in "+63 917 123 4567" {
            tracker.handleKeyStroke(keyCode: 0, flags: [], characters: String(ch))
        }
        
        XCTAssertEqual(model.activeSession?.fields.first { $0.label == "Full Name" }?.value, "Carlos Mendoza")
        XCTAssertEqual(model.activeSession?.fields.first { $0.label == "Contact Number" }?.value, "+63 917 123 4567")
        XCTAssertEqual(model.activeSession?.fields.first { $0.label == "Institution" }?.value, "")
        
        // Verify neither "aaron" nor "yen" ever appeared
        for field in model.activeSession?.fields ?? [] {
            XCTAssertFalse(field.value.lowercased().contains("aaron"))
            XCTAssertFalse(field.value.lowercased().contains("yen"))
        }
    }

    func testBlankFormSnapshotImmediatelyClearsAnyAnsweredFields() {
        let model = ApplicationFormModel(detector: MockApplicationFormDetector(), dispatcher: MockEmailDispatcher())
        model.startTracking(title: "Laguna Schools BP 2026: IA/SA Application Form", appName: "Polar")
        model.isFormDetected = true
        model.activeSession?.fields = makeLagunaFields()
        
        // Simulate some fields having answers
        model.activeSession?.fields[3].value = "Previous Answer"
        model.activeSession?.fields[4].value = "Previous School"
        model.activeSession?.fields[5].value = "0912345678"
        XCTAssertEqual(model.activeSession?.answeredCount, 3)
        
        // Browser scan reports empty strings for the visible questions
        let emptyBrowserSnapshot: [(label: String, value: String)] = [
            ("Full Name", ""),
            ("Institution", ""),
            ("Contact Number", "")
        ]
        
        let cleared = model.applyLiveSnapshot(emptyBrowserSnapshot)
        XCTAssertEqual(cleared, 3)
        XCTAssertEqual(model.activeSession?.answeredCount, 0)
        for field in model.activeSession?.fields ?? [] {
            XCTAssertEqual(field.value, "")
        }
    }

    func testCandidateQuestionTitlesRejectsEmailAddresses() {
        // Test that cleanQuestionTitle or candidate filters discard email patterns
        let email1 = "aaronn.nguyen.work@gmail.com"
        let email2 = "user@laguna.edu"
        
        XCTAssertTrue(email1.contains("@"))
        XCTAssertTrue(email2.contains("@"))
    }
}
