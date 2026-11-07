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
        UserDefaults.standard.removeObject(forKey: "com.morph.supabase.form_receipts_cache")
        UserDefaults.standard.removeObject(forKey: ApplicationFormModel.draftsStorageKey)
        
        supabase = SupabaseService.shared
        supabase.memoryItems.removeAll()
        supabase.formReceipts.removeAll()
        
        formTracker = ApplicationFormModel()
        formTracker.savedFormCopies.removeAll()
        formTracker.historySessions.removeAll()
        formTracker.profileAnswers = [
            "Full Name": "John Chen",
            "Email Address": "jchen.debate@tabroom.org",
            "Institutional Conflicts": "St. Marks School of Texas",
            "Division Preference": "Policy / CX",
            "Availability": "Saturday all rounds, Sunday elims",
            "Judging Paradigm": "Tabula rasa, tech > truth, speed fine if clear"
        ]
        
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
    
    // MARK: - 6. Idle Capsule Live Form Pill & Stealth Indicator
    func testIdleCapsuleLiveFormPill() {
        model.setGlassIslandState(.idle)
        XCTAssertFalse(formTracker.isFormDetected)
        XCTAssertEqual(model.glassIslandWidth, 176)
        
        // When Google Form is detected, idle capsule expands to 300 pt with live form sign
        formTracker.isFormDetected = true
        XCTAssertEqual(model.glassIslandWidth, 300)
        
        // When music is playing simultaneously, dual capsule is 380 pt
        model.media.isPlaying = true
        XCTAssertEqual(model.glassIslandWidth, 380)
        
        // When timer is active simultaneously, dual capsule is 370 pt
        model.media.isPlaying = false
        model.glassTimerStatus = .running
        XCTAssertEqual(model.glassIslandWidth, 370)
        
        model.glassTimerStatus = .ready
        XCTAssertEqual(model.glassIslandWidth, 300)
    }
    
    // MARK: - 7. Screen-Wide Form Title Recognition & Tab Switch Retraction
    func testScreenWideFormTitleRecognition() {
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("JCSD Winter Open: IA Application"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Laguna Schools IA/SA Application"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Job Application Form - Google Forms"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Volunteer Sign-Up Questionnaire"))
        XCTAssertTrue(DefaultApplicationFormDetector.isFormTitle("Course Evaluation Survey"))
        
        // Negative test cases (code files, developer tools, non-forms, normal search and chat tabs)
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("ApplicationFormModel.swift"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("Antigravity - Main"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("README.md"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("Your first chat with Claude - Claude"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("midterm - Google Search"))
        XCTAssertFalse(DefaultApplicationFormDetector.isFormTitle("YouTube Music"))
    }
    
    // MARK: - 8. Tab Switch Collapses to Transparent Resting State
    func testTabSwitchCollapsesToTransparentRestingState() {
        model.setGlassIslandState(.idle)
        
        // 1. User on form tab: form detected, capsule expands to 300 pt
        formTracker.isFormDetected = true
        formTracker.detectedFormTitle = "JCSD Winter Open: IA Application"
        XCTAssertEqual(model.glassIslandWidth, 300)
        
        // 2. User switches to another tab (e.g. Claude or Google Search):
        // Morph immediately collapses back to the 176 pt resting transparent state
        formTracker.isFormDetected = false
        XCTAssertEqual(model.glassIslandWidth, 176)
        XCTAssertFalse(formTracker.isFormDetected)
    }
    
    // MARK: - 9. Contextual Hover on Stealth Capsule Opens Active Activity Page
    func testStealthCapsuleHoverOpensBackgroundActivityPageInsteadOfNormalPrompt() {
        model.setGlassIslandState(.idle)
        
        // A. Idle with no background activity -> opens the normal way (.prompt)
        formTracker.isFormDetected = false
        model.media.isPlaying = false
        model.glassTimerStatus = .ready
        model.calendar.showNotchAlert = false
        XCTAssertEqual(model.contextualOpenState, .prompt)
        
        // B. Background Form Active -> hover opens .forms
        formTracker.isFormDetected = true
        formTracker.detectedFormTitle = "Laguna Schools Application"
        XCTAssertTrue(model.isBackgroundFormActive)
        XCTAssertEqual(model.contextualOpenState, .forms)
        
        // C. Background Music Playing -> hover opens .music
        formTracker.isFormDetected = false
        model.media.isPlaying = true
        XCTAssertTrue(model.isBackgroundMusicActive)
        XCTAssertEqual(model.contextualOpenState, .music)
        
        // D. Background Timer Active -> hover opens .timer
        model.media.isPlaying = false
        model.glassTimerStatus = .running
        XCTAssertTrue(model.isBackgroundTimerActive)
        XCTAssertEqual(model.contextualOpenState, .timer)
        
        // E. Running Music/Timer takes precedence when both form and music are active on stealth capsule
        formTracker.isFormDetected = true
        model.media.isPlaying = true
        XCTAssertEqual(model.contextualOpenState, .music)
    }
    
    // MARK: - 10. Ability for Morph to Input Saved Input for That Question
    func testResolveSavedInputFromAllSources() async {
        formTracker.savedFormCopies.removeAll()
        formTracker.profileAnswers.removeAll()
        
        // Source A: Saved Form Copy
        let copy = SavedFormCopyRecord(
            formTitle: "Form #1 — Judge Signup",
            answers: [
                "Full Name": "Jane Doe",
                "Institutional Conflicts": "Stanford University",
                "Judging Paradigm": "Policy centric, open to kritiks"
            ]
        )
        formTracker.savedFormCopies.append(copy)
        
        // Source B: Supabase Form Receipt
        let receiptFields = [
            FormInputField(label: "Preferred Event Division", value: "Varsity CX"),
            FormInputField(label: "Contact Phone Number", value: "555-0199")
        ]
        let receiptData = try! JSONEncoder().encode(receiptFields)
        let receiptJSON = String(data: receiptData, encoding: .utf8)!
        let receipt = FormReceiptRecord(
            formTitle: "Form #0 — Fall Debate",
            fieldsJSON: receiptJSON
        )
        supabase.formReceipts = [receipt]
        
        // Source C: Profile Answers
        formTracker.profileAnswers["Email Address"] = "jane.doe@stanford.edu"
        
        // Start Form #2
        formTracker.startTracking(
            title: "Form #2 — State Championship",
            appName: "Google Chrome",
            url: "https://docs.google.com/forms/d/e/1FAIpQLSe-state-champ/viewform"
        )
        formTracker.addField(label: "Full Name *", value: "", category: .personal)
        formTracker.addField(label: "Institutional Conflicts", value: "", category: .experience)
        formTracker.addField(label: "Judging Paradigm", value: "", category: .question)
        formTracker.addField(label: "Preferred Event Division", value: "", category: .question)
        formTracker.addField(label: "Email Address", value: "", category: .contact)
        
        let session = formTracker.activeSession!
        XCTAssertEqual(session.fields.count, 5)
        
        // 1. Resolve for each question:
        let nameAnswer = formTracker.resolveSavedInput(for: session.fields[0])
        XCTAssertEqual(nameAnswer, "Jane Doe")
        
        let conflictAnswer = formTracker.resolveSavedInput(for: session.fields[1])
        XCTAssertEqual(conflictAnswer, "Stanford University")
        
        let paradigmAnswer = formTracker.resolveSavedInput(for: session.fields[2])
        XCTAssertEqual(paradigmAnswer, "Policy centric, open to kritiks")
        
        let divisionAnswer = formTracker.resolveSavedInput(for: session.fields[3])
        XCTAssertEqual(divisionAnswer, "Varsity CX")
        
        let emailAnswer = formTracker.resolveSavedInput(for: session.fields[4])
        XCTAssertEqual(emailAnswer, "jane.doe@stanford.edu")
        
        // Ready to autofill count should be 5
        XCTAssertEqual(formTracker.readyToAutofillCount, 5)
    }
    
    func testInputAnswerIntoActiveQuestion() {
        formTracker.savedFormCopies.removeAll()
        formTracker.profileAnswers["Judging Paradigm"] = "Tabula rasa, tech over truth"
        
        formTracker.startTracking(
            title: "Debate Form",
            appName: "Google Chrome",
            url: "https://docs.google.com/forms/d/e/1FAIpQLSe-test/viewform"
        )
        formTracker.addField(label: "Full Name", value: "Alice Wonderland", category: .personal)
        formTracker.addField(label: "Judging Paradigm", value: "", category: .question)
        
        let paradigmField = formTracker.activeSession!.fields[1]
        XCTAssertTrue(paradigmField.value.isEmpty)
        
        // User inputs answer for "Judging Paradigm" question
        let success = formTracker.inputAnswerIntoActiveQuestion(fieldID: paradigmField.id)
        XCTAssertTrue(success)
        
        let updatedField = formTracker.activeSession!.fields[1]
        XCTAssertEqual(updatedField.value, "Tabula rasa, tech over truth")
        
        // Active field index aligns
        XCTAssertEqual(formTracker.activeFieldIndex, 1)
    }
    
    func testAutofillActiveFormBatchInput() {
        formTracker.savedFormCopies.removeAll()
        formTracker.profileAnswers.removeAll()
        formTracker.savedFormCopies.append(
            SavedFormCopyRecord(
                formTitle: "Previous Form",
                answers: [
                    "Full Name": "Bob Smith",
                    "Email Address": "bob@debate.org"
                ]
            )
        )
        
        formTracker.startTracking(
            title: "New Form",
            appName: "Google Chrome",
            url: "https://docs.google.com/forms/d/e/1FAIpQLSe-new/viewform"
        )
        formTracker.addField(label: "Full Name", value: "", category: .personal)
        formTracker.addField(label: "Email Address", value: "", category: .contact)
        
        XCTAssertEqual(formTracker.readyToAutofillCount, 2)
        
        let filledCount = formTracker.autofillActiveForm()
        XCTAssertEqual(filledCount, 2)
        
        XCTAssertEqual(formTracker.activeSession?.fields[0].value, "Bob Smith")
        XCTAssertEqual(formTracker.activeSession?.fields[1].value, "bob@debate.org")
        XCTAssertEqual(formTracker.readyToAutofillCount, 0)
    }
    
    func testPromptCommandInputSavedAnswer() {
        formTracker.savedFormCopies.removeAll()
        formTracker.profileAnswers["Full Name"] = "Charlie Parker"
        
        formTracker.startTracking(
            title: "Music Application",
            appName: "Google Chrome",
            url: "https://docs.google.com/forms/d/e/1FAIpQLSe-music/viewform"
        )
        formTracker.addField(label: "Full Name", value: "", category: .personal)
        
        XCTAssertEqual(formTracker.activeSession?.fields[0].value, "")
        
        // User submits prompt "input answer"
        model.submitGlassIslandPrompt("input answer")
        
        XCTAssertEqual(formTracker.activeSession?.fields[0].value, "Charlie Parker")
    }
    
    // MARK: - 8. End-to-End 6-Step Workflow Verification
    func testEndToEndSixStepFormWorkflow() async {
        // Clear caches
        formTracker.savedFormCopies.removeAll()
        supabase.memoryItems.removeAll()
        supabase.formReceipts.removeAll()
        
        // --- STEP 1: Form opened, detected, personalized name shown, questions fetched ---
        // Simulating user opening "Robotics Tournament Registration"
        let formTitle = "2026 Robotics Championship Registration"
        let formURL = "https://docs.google.com/forms/d/e/1FAIpQLSc-robotics/viewform"
        
        formTracker.startTracking(
            title: formTitle,
            appName: "Google Chrome",
            url: formURL
        )
        
        // Form questions are fetched dynamically (completely unique, non-rigid questions)
        formTracker.addField(label: "Team Number", value: "", category: .custom, questionType: "shortAnswer")
        formTracker.addField(label: "Robot Weight Class", value: "", category: .custom, options: ["Featherweight (30 lbs)", "Lightweight (60 lbs)", "Heavyweight (250 lbs)"], questionType: "multipleChoice")
        formTracker.addField(label: "Drive Train Architecture", value: "", category: .custom, questionType: "paragraph")
        formTracker.addField(label: "Safety Officer Name", value: "", category: .personal, questionType: "shortAnswer")
        formTracker.addField(label: "Safety Contact Number", value: "", category: .contact, questionType: "shortAnswer")
        
        XCTAssertTrue(formTracker.isFormDetected)
        XCTAssertEqual(formTracker.detectedFormTitle, formTitle)
        XCTAssertEqual(formTracker.activeSession?.fields.count, 5)
        XCTAssertTrue(model.isBackgroundFormActive)
        
        // Verify personalized name is on stealth capsule
        XCTAssertEqual(model.compactHUDMode, .formTrackerActive)
        XCTAssertTrue(model.isBackgroundFormActive)
        XCTAssertEqual(formTracker.activeSession?.formTitle, formTitle)
        
        // --- STEP 2: When user is inputting into form, Morph fetches all user input ---
        let items: [ExtractedInputItem] = [
            ExtractedInputItem(label: "Team Number", value: "FRC-9042", questionType: "shortAnswer"),
            ExtractedInputItem(label: "Robot Weight Class", value: "Heavyweight (250 lbs)", questionType: "multipleChoice"),
            ExtractedInputItem(label: "Drive Train Architecture", value: "Swerve drive with 4x Falcon 500 brushless motors and CANcoder feedback.", questionType: "paragraph")
        ]
        formTracker.applyLiveItemsSnapshot(items)
        
        XCTAssertEqual(formTracker.activeSession?.fields[0].value, "FRC-9042")
        XCTAssertEqual(formTracker.activeSession?.fields[1].value, "Heavyweight (250 lbs)")
        XCTAssertEqual(formTracker.activeSession?.fields[2].value, "Swerve drive with 4x Falcon 500 brushless motors and CANcoder feedback.")
        
        // Additional keystroke input into active field (Safety Officer Name)
        let tracker = FormInputAutoTracker(model: formTracker)
        formTracker.autoTracker = tracker
        formTracker.selectActiveField(3)
        tracker.confirmFocus(fieldID: formTracker.activeSession!.fields[3].id)
        for char in "Dr. Evelyn Reed" {
            tracker.handleKeyStroke(keyCode: 0, flags: [], characters: String(char))
        }
        XCTAssertEqual(formTracker.activeSession?.fields[3].value, "Dr. Evelyn Reed")
        
        // --- STEP 3: Dynamic non-rigid schema & Supabase sync verification ---
        // Ensure that form fields are strictly dependent on this specific form (not rigid standard names)
        let fieldLabels = formTracker.activeSession?.fields.map { $0.label } ?? []
        XCTAssertTrue(fieldLabels.contains("Team Number"))
        XCTAssertTrue(fieldLabels.contains("Robot Weight Class"))
        XCTAssertTrue(fieldLabels.contains("Drive Train Architecture"))
        
        // --- STEP 4: Hovering onto Morph shows the data inputted in that question ---
        // When user hovers onto stealth capsule, contextual open state routes to .forms
        XCTAssertEqual(model.contextualOpenState, .forms)
        model.setGlassIslandState(model.contextualOpenState)
        XCTAssertEqual(model.glassIslandState, .forms)
        XCTAssertEqual(model.glassFormMode, .live)
        
        // In the live view, all questions and user input are visible
        let liveFields = model.formTracker.activeSession?.fields ?? []
        XCTAssertEqual(liveFields[0].label, "Team Number")
        XCTAssertEqual(liveFields[0].value, "FRC-9042")
        XCTAssertEqual(liveFields[1].label, "Robot Weight Class")
        XCTAssertEqual(liveFields[1].value, "Heavyweight (250 lbs)")
        XCTAssertEqual(liveFields[2].label, "Drive Train Architecture")
        XCTAssertEqual(liveFields[2].value, "Swerve drive with 4x Falcon 500 brushless motors and CANcoder feedback.")
        XCTAssertEqual(liveFields[3].label, "Safety Officer Name")
        XCTAssertEqual(liveFields[3].value, "Dr. Evelyn Reed")
        
        // --- STEP 5: User finishes and clicks Save on Morph -> straight into Supabase ---
        let savedRecord = formTracker.saveFormSnapshot(flashLabel: true)
        XCTAssertNotNil(savedRecord)
        XCTAssertEqual(savedRecord?.formTitle, formTitle)
        XCTAssertEqual(savedRecord?.answers["Team Number"], "FRC-9042")
        XCTAssertEqual(savedRecord?.answers["Robot Weight Class"], "Heavyweight (250 lbs)")
        XCTAssertEqual(savedRecord?.answers["Safety Officer Name"], "Dr. Evelyn Reed")
        
        // Give asynchronous Supabase background Task time to finish recording
        try? await Task.sleep(nanoseconds: 60_000_000)
        
        // Check local Supabase store has it immediately
        let savedMemory = supabase.memoryItems.first(where: { $0.id == savedRecord?.id })
        XCTAssertNotNil(savedMemory)
        XCTAssertEqual(savedMemory?.title, formTitle)
        XCTAssertTrue(savedMemory?.body.contains("FRC-9042") ?? false)
        XCTAssertTrue(savedMemory?.body.contains("Heavyweight (250 lbs)") ?? false)
        
        // Check Form Receipts in Supabase
        let receipt = supabase.formReceipts.first(where: { $0.formTitle == formTitle })
        XCTAssertNotNil(receipt)
        XCTAssertEqual(receipt?.answeredCount, 4)
        
        // --- STEP 6: User accesses form answers again by typing form name in lengthened bar ---
        // Reset state to prompt (lengthened bar)
        model.setGlassIslandState(.prompt)
        XCTAssertEqual(model.glassIslandState, .prompt)
        
        // User types the form name
        model.glassPromptText = "Robotics Championship"
        XCTAssertTrue(model.isPromptPeekActive)
        
        let peekInfo = model.promptPeekInfo
        XCTAssertNotNil(peekInfo)
        XCTAssertEqual(peekInfo?.icon, "doc.plaintext.fill")
        XCTAssertTrue(peekInfo?.title.contains("Robotics Championship") ?? false)
        XCTAssertEqual(peekInfo?.actionType, "memory")
        
        // User presses Enter / clicks peek
        model.submitGlassIslandPrompt("Robotics Championship")
        
        // Morph opens straight into the saved form answers detail view!
        XCTAssertEqual(model.glassIslandState, .forms)
        XCTAssertEqual(model.glassFormMode, .copies)
        XCTAssertTrue(model.isFormCopyDetailOpen)
        XCTAssertEqual(model.selectedFormCopyId, savedRecord?.id)
    }
}
