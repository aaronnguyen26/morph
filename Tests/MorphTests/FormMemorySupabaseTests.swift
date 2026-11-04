import XCTest
import SwiftUI
@testable import morph

@MainActor
final class FormMemorySupabaseTests: XCTestCase {
    var model: NotchModel!
    var formTracker: ApplicationFormModel!
    var supabase: SupabaseService!
    
    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: "com.morph.form.saved_copies")
        UserDefaults.standard.removeObject(forKey: "com.morph.form.profile_answers")
        UserDefaults.standard.removeObject(forKey: "com.morph.supabase.cached_memory_items")
        
        supabase = SupabaseService.shared
        supabase.memoryItems.removeAll()
        
        formTracker = ApplicationFormModel()
        formTracker.savedFormCopies.removeAll()
        
        model = NotchModel(supabase: supabase, formTracker: formTracker)
        model.isGlassIslandEnabled = true
        model.setGlassIslandState(.idle)
    }
    
    override func tearDown() async throws {
        model = nil
        formTracker = nil
        supabase = nil
        try await super.tearDown()
    }
    
    // MARK: - 1. Form Detection Harvesting & Zero Email Receipt
    func testFormDetectionHarvestingAndZeroEmailReceipt() async {
        // Start a detected form session matching Glass Island (2).html
        formTracker.startTracking(
            title: "2026 Spring Debate Invitational — Judge Signup",
            appName: "Google Chrome",
            url: "https://docs.google.com/forms/d/e/1FAIpQLSe-spring-judge/viewform"
        )
        
        XCTAssertTrue(formTracker.isFormDetected)
        XCTAssertEqual(formTracker.activeSession?.formTitle, "2026 Spring Debate Invitational — Judge Signup")
        
        // Harvest inputs without user pasting into Morph
        formTracker.addField(label: "Full Name", value: "John Chen", category: .personal)
        formTracker.addField(label: "Email Address", value: "jchen.debate@tabroom.org", category: .contact)
        formTracker.addField(label: "Institutional Conflicts", value: "St. Marks School of Texas", category: .experience)
        formTracker.addField(label: "Judging Paradigm", value: "Tabula rasa, tech > truth", category: .question)
        
        XCTAssertEqual(formTracker.activeSession?.fields.count, 4)
        XCTAssertFalse(formTracker.activeSession?.isSubmitted ?? true)
        
        // Submit the form: saves a copy to local island and to Supabase memory store without emailing
        formTracker.markFormSubmitted()
        
        XCTAssertTrue(formTracker.activeSession?.isSubmitted ?? false)
        XCTAssertEqual(formTracker.savedFormCopies.count, 1)
        
        let copy = formTracker.savedFormCopies.first!
        XCTAssertEqual(copy.formTitle, "2026 Spring Debate Invitational — Judge Signup")
        XCTAssertEqual(copy.answers["Full Name"], "John Chen")
        XCTAssertEqual(copy.answers["Email Address"], "jchen.debate@tabroom.org")
        XCTAssertEqual(copy.answers["Judging Paradigm"], "Tabula rasa, tech > truth")
        
        // Verify saved to Supabase memory store
        let memory = supabase.memoryItems.first(where: { $0.id == copy.id })
        XCTAssertNotNil(memory)
        XCTAssertEqual(memory?.kind, "form")
        XCTAssertEqual(memory?.title, "2026 Spring Debate Invitational — Judge Signup")
        XCTAssertTrue(memory?.body.contains("John Chen") ?? false)
        XCTAssertTrue(memory?.body.contains("jchen.debate@tabroom.org") ?? false)
        
        // Verify dispatchEmailCopy does NOT send email, but safely saves to memory
        let countBefore = formTracker.savedFormCopies.count
        let dispatchResult = await formTracker.dispatchEmailCopy()
        XCTAssertTrue(dispatchResult)
        XCTAssertGreaterThanOrEqual(formTracker.savedFormCopies.count, countBefore)
    }
    
    // MARK: - 2. Supabase Memory Storage & Scored Search
    func testSupabaseMemoryStorageAndScoredSearch() async {
        let mem1 = GlassMemoryItem(
            id: UUID().uuidString,
            kind: "form",
            title: "2026 Spring Debate Invitational — Judge Signup",
            body: "Full Name: John Chen\nEmail Address: jchen.debate@tabroom.org\nJudging Paradigm: Tabula rasa",
            metaJSON: "{\"answers\":{\"Full Name\":\"John Chen\"}}"
        )
        
        let mem2 = GlassMemoryItem(
            id: UUID().uuidString,
            kind: "form",
            title: "State Finals Speech Registration",
            body: "Student: Alice Walker\nEvent: Extemporaneous Speaking",
            metaJSON: "{\"answers\":{\"Student\":\"Alice Walker\"}}"
        )
        
        await supabase.saveMemoryItem(mem1)
        await supabase.saveMemoryItem(mem2)
        
        // Search by title keywords
        let debateResults = supabase.searchMemories(query: "debate")
        XCTAssertFalse(debateResults.isEmpty)
        XCTAssertEqual(debateResults.first?.id, mem1.id)
        
        // Search by answer text
        let emailResults = supabase.searchMemories(query: "tabroom.org")
        XCTAssertFalse(emailResults.isEmpty)
        XCTAssertEqual(emailResults.first?.id, mem1.id)
        
        let paradigmResults = supabase.searchMemories(query: "tabula rasa")
        XCTAssertFalse(paradigmResults.isEmpty)
        XCTAssertEqual(paradigmResults.first?.id, mem1.id)
        
        // Search for speech form
        let speechResults = supabase.searchMemories(query: "Alice Walker")
        XCTAssertFalse(speechResults.isEmpty)
        XCTAssertEqual(speechResults.first?.id, mem2.id)
    }
    
    // MARK: - 3. Lengthened UI Memory Retrieval & Peek Expansion
    func testLengthenedUIMemoryRetrievalAndPeekExpansion() async {
        // Seed saved form memory
        let savedCopy = SavedFormCopyRecord(
            id: "debate-copy-1",
            formTitle: "2026 Spring Debate Invitational — Judge Signup",
            savedAt: Date(),
            answers: [
                "Full Name": "John Chen",
                "Email Address": "jchen.debate@tabroom.org",
                "Judging Paradigm": "Tabula rasa, tech > truth"
            ]
        )
        formTracker.savedFormCopies.append(savedCopy)
        
        let mem = GlassMemoryItem(
            id: savedCopy.id,
            kind: "form",
            title: savedCopy.formTitle,
            body: "Full Name: John Chen\nEmail Address: jchen.debate@tabroom.org\nJudging Paradigm: Tabula rasa, tech > truth",
            metaJSON: savedCopy.answersJSONString
        )
        await supabase.saveMemoryItem(mem)
        
        // Open Lengthened UI
        model.setGlassIslandState(.prompt)
        XCTAssertEqual(model.glassIslandState, .prompt)
        XCTAssertFalse(model.isPromptPeekActive)
        XCTAssertEqual(model.glassIslandHeight, 56)
        
        // Write query matching saved form memory in the lengthened UI
        model.glassPromptText = "debate"
        XCTAssertTrue(model.isPromptPeekActive)
        XCTAssertEqual(model.glassIslandHeight, 108) // Height expands to 108 pt for peek preview
        
        let peek = model.promptPeekInfo
        XCTAssertNotNil(peek)
        XCTAssertEqual(peek?.icon, "doc.plaintext.fill")
        XCTAssertTrue(peek?.title.contains("Form Memory") ?? false)
        XCTAssertTrue(peek?.subtitle.contains("John Chen") ?? false)
        XCTAssertEqual(peek?.actionType, "memory")
        
        // Press Enter / Submit prompt: immediately retrieves the saved form memory in the island
        model.submitGlassIslandPrompt("debate")
        
        XCTAssertEqual(model.glassIslandState, .forms)
        XCTAssertEqual(model.glassFormMode, .copies)
        XCTAssertTrue(model.isFormCopyDetailOpen)
        XCTAssertEqual(model.selectedFormCopyId, savedCopy.id)
    }
    
    // MARK: - 4. Autofill Command and Routing
    func testAutofillCommandAndRouting() {
        formTracker.startTracking(title: "Form #2", appName: "Google Chrome")
        formTracker.addField(label: "Full Name", value: "", category: .personal)
        formTracker.addField(label: "Email Address", value: "", category: .contact)
        
        model.setGlassIslandState(.prompt)
        model.glassPromptText = "autofill"
        
        XCTAssertTrue(model.isPromptPeekActive)
        XCTAssertEqual(model.promptPeekInfo?.actionType, "autofill")
        
        // Submitting autofill executes autofill and returns to idle
        model.submitGlassIslandPrompt("autofill")
        
        XCTAssertEqual(model.glassIslandState, .idle)
        XCTAssertEqual(formTracker.activeSession?.fields.first?.value, "John Chen")
        XCTAssertEqual(formTracker.activeSession?.fields[1].value, "jchen.debate@tabroom.org")
    }
    
    // MARK: - 5. Form Assistant Three Panes & Profile Editing
    func testFormAssistantThreePanesAndProfileEditing() {
        // Toggle Forms tab
        model.toggleGlassIslandTab(.forms)
        XCTAssertEqual(model.glassIslandState, .forms)
        XCTAssertEqual(model.glassIslandWidth, 460)
        XCTAssertEqual(model.glassIslandHeight, 284)
        XCTAssertEqual(model.glassIslandTintHex, "#8ff0b4")
        
        // Live Mode
        model.glassFormMode = .live
        XCTAssertEqual(model.glassFormMode, .live)
        
        // Copies Mode
        model.glassFormMode = .copies
        XCTAssertEqual(model.glassFormMode, .copies)
        
        // Profile Mode & In-Place Editing
        model.glassFormMode = .profile
        XCTAssertEqual(model.glassFormMode, .profile)
        
        formTracker.saveProfileAnswer(key: "Judging Paradigm", value: "Policy judge, highly technical")
        XCTAssertEqual(formTracker.profileAnswers["Judging Paradigm"], "Policy judge, highly technical")
        
        // Form snapshot
        formTracker.startTracking(title: "Invitational Signup", appName: "Google Chrome")
        formTracker.addField(label: "Judging Paradigm", value: "", category: .question)
        
        let copy = formTracker.saveFormSnapshot(flashLabel: true)
        XCTAssertNotNil(copy)
        XCTAssertEqual(copy?.answers["Judging Paradigm"], "Policy judge, highly technical")
    }
    
    // MARK: - 6. Idle Capsule Live Form Pill
    func testIdleCapsuleLiveFormPill() {
        model.setGlassIslandState(.idle)
        XCTAssertFalse(formTracker.isFormDetected)
        XCTAssertEqual(model.glassIslandWidth, 176)
        
        // When Google Form is detected, idle capsule expands to 280 pt with live form pill
        formTracker.isFormDetected = true
        XCTAssertEqual(model.glassIslandWidth, 280)
    }
}
