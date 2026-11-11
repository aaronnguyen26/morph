import XCTest
import WebKit
import AppKit
import SwiftUI
@testable import morph

@MainActor
final class FormAdaptiveAndInjectionTests: XCTestCase {
    var model: NotchModel!
    var formTracker: ApplicationFormModel!
    var supabase: SupabaseService!
    
    override func setUp() async throws {
        try await super.setUp()
        clearAllFormStorage()
        
        supabase = SupabaseService.shared
        supabase.memoryItems.removeAll()
        supabase.formReceipts.removeAll()
        supabase.clearDeletionTombstones()
        
        formTracker = ApplicationFormModel()
        formTracker.savedFormCopies.removeAll()
        formTracker.historySessions.removeAll()
        formTracker.profileAnswers.removeAll()
        formTracker.dismissedAdaptiveProfileKeys.removeAll()
        
        model = NotchModel(supabase: supabase, formTracker: formTracker)
        model.isGlassIslandEnabled = true
        model.setGlassIslandState(.idle)
    }
    
    override func tearDown() async throws {
        clearAllFormStorage()
        supabase.memoryItems.removeAll()
        supabase.formReceipts.removeAll()
        supabase.clearDeletionTombstones()
        model = nil
        formTracker = nil
        supabase = nil
        try await super.tearDown()
    }
    
    private func clearAllFormStorage() {
        let keys = [
            "com.morph.form.saved_copies",
            "com.morph.form.profile_answers",
            "com.morph.form.dismissed_adaptive_keys",
            "com.morph.form_context_aware_enabled",
            "com.morph.supabase.cached_memory_items",
            "com.morph.supabase.cached_form_receipts",
            SupabaseService.deletedFormReceiptIDsKey,
            SupabaseService.deletedMemoryItemIDsKey,
            ApplicationFormModel.draftsStorageKey
        ]
        for k in keys {
            UserDefaults.standard.removeObject(forKey: k)
        }
    }
    
    // MARK: - WebKit & AppleScript Helpers
    
    private func makeWebView(html: String) async throws -> WKWebView {
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 640, height: 900))
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
            web.loadHTMLString(html, baseURL: URL(string: "https://docs.google.com/forms/d/e/1FAIpQLSf-test-form/viewform"))
        }
        objc_setAssociatedObject(web, "loader", loader, .OBJC_ASSOCIATION_RETAIN)
        return web
    }
    
    /// Extracts the exact AppleScript-escaped JS payload passed to `execute javascript "..."` or `do JavaScript "..."`
    /// and unescapes AppleScript string escaping back to executable JavaScript.
    private func extractExecutableJS(fromAppleScript script: String) throws -> String {
        let markers = ["execute javascript \"", "do JavaScript \""]
        var startIndex: String.Index? = nil
        for marker in markers {
            if let range = script.range(of: marker) {
                startIndex = range.upperBound
                break
            }
        }
        let idxStart = try XCTUnwrap(startIndex, "AppleScript must contain a JavaScript invocation")
        var unescaped = ""
        var i = idxStart
        var terminated = false
        while i < script.endIndex {
            let ch = script[i]
            if ch == "\\" {
                let next = script.index(after: i)
                guard next < script.endIndex else {
                    XCTFail("Dangling backslash at end of AppleScript string literal")
                    break
                }
                let esc = script[next]
                if esc == "\\" || esc == "\"" {
                    unescaped.append(esc)
                } else {
                    unescaped.append(ch)
                    unescaped.append(esc)
                }
                i = script.index(after: next)
            } else if ch == "\"" {
                terminated = true
                break
            } else {
                unescaped.append(ch)
                i = script.index(after: i)
            }
        }
        XCTAssertTrue(terminated, "AppleScript string literal must be properly terminated")
        return unescaped
    }
    
    private static let googleFormWithWizPortalHTML = #"""
    <!doctype html>
    <html>
    <body>
    <form>
      <div role="listitem" id="q-name" data-params="%.@.[1001,&quot;Legal Full Name&quot;,null,0]">
        <div role="heading">Full Name *</div>
        <div class="rFrNMe"><input type="text" name="entry.1001" aria-label="Full Name" value=""></div>
      </div>

      <div role="listitem" id="q-parent">
        <div role="heading">Name of Parent or Guardian</div>
        <div class="rFrNMe"><input type="text" name="entry.1002" aria-label="Name of Parent or Guardian" value=""></div>
      </div>

      <div role="listitem" id="q-essay">
        <div role="heading">Why are you interested?</div>
        <textarea name="entry.1003" aria-label="Why are you interested?"></textarea>
      </div>

      <div role="listitem" id="q-bio">
        <div role="heading">Short Biography</div>
        <div contenteditable="true" role="textbox" aria-label="Short Biography"></div>
      </div>

      <div role="listitem" id="q-track">
        <div role="heading">Preferred Track</div>
        <div role="radiogroup">
          <div role="radio" data-value="AI & Systems" aria-checked="false">AI &amp; Systems</div>
          <div role="radio" data-value="Product Design" aria-checked="false">Product Design</div>
        </div>
      </div>

      <div role="listitem" id="q-days">
        <div role="heading">Available Days</div>
        <div role="group">
          <div role="checkbox" data-answer-value="Monday" aria-checked="false">Monday</div>
          <div role="checkbox" data-answer-value="Tuesday" aria-checked="true">Tuesday</div>
          <div role="checkbox" data-answer-value="Thursday" aria-checked="false">Thursday</div>
        </div>
      </div>

      <div role="listitem" id="q-shirt">
        <div role="heading">T-Shirt Size</div>
        <div role="listbox" id="shirt-lb" tabindex="0">
          <span class="vRMGwf">Choose</span>
        </div>
        <input type="hidden" name="entry.1007" value="">
      </div>

      <div role="listitem" id="q-grad">
        <div role="heading">Graduation Year</div>
        <select name="entry.1008">
          <option value="">-- Select --</option>
          <option value="2026">2026</option>
          <option value="2027">2027</option>
        </select>
      </div>

      <div role="listitem" id="q-start-date">
        <div role="heading">Start Date</div>
        <input type="date" name="entry.1009" value="">
      </div>

      <div role="listitem" id="q-birth-split">
        <div role="heading">Birth Date</div>
        <input type="text" aria-label="Month" value="">
        <input type="text" aria-label="Day" value="">
        <input type="text" aria-label="Year" value="">
      </div>

      <div role="listitem" id="q-arrival">
        <div role="heading">Arrival Time</div>
        <input type="time" name="entry.1011" value="">
      </div>

      <div role="listitem" id="q-campus" data-params="%.@.[2099,&quot;Site Selection&quot;,null,3]]">
        <div role="heading">Site Selection</div>
        <div role="listbox" tabindex="0">
          <div role="option" data-value="North Campus" aria-selected="false">North Campus</div>
          <div role="option" data-value="South Campus" aria-selected="false">South Campus</div>
        </div>
      </div>
    </form>

    <script>
      document.getElementById('shirt-lb').addEventListener('click', function() {
        if (!document.getElementById('wiz-portal')) {
          var menu = document.createElement('div');
          menu.id = 'wiz-portal';
          menu.className = 'OA0qNb ncFHed';
          ['Small', 'Medium (M)', 'Large'].forEach(function(lbl) {
            var opt = document.createElement('div');
            opt.setAttribute('role', 'option');
            opt.className = 'MocG8c';
            opt.setAttribute('data-value', lbl);
            opt.textContent = lbl;
            opt.addEventListener('click', function() {
              menu.remove();
            });
            menu.appendChild(opt);
          });
          document.body.appendChild(menu);
        }
      });
    </script>
    </body>
    </html>
    """#
    
    // MARK: - 1. WebKit DOM Injection & Extraction AppleScript Roundtrip
    
    func testAppleScriptDOMInjectionAndExtractionAcrossAllGoogleFormControls() async throws {
        let web = try await makeWebView(html: Self.googleFormWithWizPortalHTML)
        
        let answers: [String: String] = [
            "Full Name": #"Ada "Lovelace" O'Connor"#,
            "Why are you interested?": "Line 1: Builders\nLine 2: Systems",
            "Short Biography": "Research engineer in macOS.",
            "Preferred Track": "AI & Systems",
            "Available Days": "Tuesday, Thursday",
            "T-Shirt Size": "Medium",
            "Graduation Year": "2027",
            "Start Date": "11/10/2026",
            "Birth Date": "04/05/1999",
            "Arrival Time": "2:30 PM",
            "Preferred Campus": "South Campus"
        ]
        
        let schemaFields: [FormInputField] = [
            FormInputField(label: "Full Name", value: "", questionType: "shortAnswer", entryKey: "entry.1001"),
            FormInputField(label: "Why are you interested?", value: "", questionType: "paragraph", entryKey: "entry.1003"),
            FormInputField(label: "Short Biography", value: "", questionType: "paragraph"),
            FormInputField(label: "Preferred Track", value: "", options: ["AI & Systems", "Product Design"], questionType: "multipleChoice"),
            FormInputField(label: "Available Days", value: "", options: ["Monday", "Tuesday", "Thursday"], questionType: "checkboxes"),
            FormInputField(label: "T-Shirt Size", value: "", options: ["Small", "Medium (M)", "Large"], questionType: "dropdown", entryKey: "entry.1007"),
            FormInputField(label: "Graduation Year", value: "", options: ["2026", "2027"], questionType: "dropdown", entryKey: "entry.1008"),
            FormInputField(label: "Start Date", value: "", questionType: "date", entryKey: "entry.1009"),
            FormInputField(label: "Birth Date", value: "", questionType: "date"),
            FormInputField(label: "Arrival Time", value: "", questionType: "time", entryKey: "entry.1011"),
            FormInputField(label: "Preferred Campus", value: "", options: ["North Campus", "South Campus"], questionType: "dropdown", entryKey: "entry.2099")
        ]
        
        // 1. Build Chrome AppleScript targeting the specific form URL and verify executable JS has zero // truncation
        let injectionScript = try XCTUnwrap(
            FormInputAutoTracker.buildDOMInjectionAppleScript(
                bundleID: "com.google.Chrome",
                answers: answers,
                fields: schemaFields,
                targetURL: "https://docs.google.com/forms/d/e/1FAIpQLSf-test-form/viewform"
            )
        )
        XCTAssertTrue(injectionScript.contains("1FAIpQLSf-test-form"), "AppleScript should prioritize tab matching form identifier")
        XCTAssertTrue(injectionScript.contains("__JS_ERROR__:"), "AppleScript must surface JS errors cleanly")
        XCTAssertFalse(injectionScript.hasSuffix("`"), "Must not have any trailing syntax characters")
        
        let executableInjectJS = try extractExecutableJS(fromAppleScript: injectionScript)
        XCTAssertFalse(executableInjectJS.contains("// "), "Flattened JS must never include single-line // comments")
        
        let injectResultAny = try await web.evaluateJavaScript(executableInjectJS)
        let injectCountStr = try XCTUnwrap(injectResultAny as? String)
        XCTAssertEqual(Int(injectCountStr), 11, "All 11 target fields (including Wiz .OA0qNb portal, inline listbox via data-params, & contenteditable) must inject cleanly")
        
        // 2. Verify Parent Name remained untouched (qualifier conflict guard)
        let parentVal = try await web.evaluateJavaScript("document.querySelector('#q-parent input').value") as? String
        XCTAssertEqual(parentVal, "", "Full Name must never overwrite Name of Parent or Guardian in DOM")
        
        // 3. Verify T-Shirt Size Wiz portal rendered value and CDELXb class was added to text wrapper
        let shirtDisplay = try await web.evaluateJavaScript("document.querySelector('#shirt-lb .vRMGwf').textContent") as? String
        XCTAssertEqual(shirtDisplay, "Medium (M)")
        let hasCDELXb = try await web.evaluateJavaScript("document.querySelector('#q-name .rFrNMe').classList.contains('CDELXb')") as? Bool
        XCTAssertEqual(hasCDELXb, true)
        
        // 4. Verify Wednesday/Tuesday checkbox wasn't untoggled when already checked!
        let availableChecked = try await web.evaluateJavaScript("""
        Array.from(document.querySelectorAll('#q-days [role=checkbox][aria-checked=true]')).map(function(e){return e.getAttribute('data-answer-value');}).join(', ')
        """) as? String
        XCTAssertEqual(availableChecked, "Tuesday, Thursday")
        
        // 5. Run the exact AppleScript extraction JS back out and verify complete fidelity
        let extractionScript = try XCTUnwrap(
            FormInputAutoTracker.buildDOMExtractionAppleScript(
                bundleID: "com.apple.Safari",
                targetURL: "https://docs.google.com/forms/d/e/1FAIpQLSf-test-form/viewform"
            )
        )
        XCTAssertTrue(extractionScript.contains("com.apple.Safari"))
        XCTAssertTrue(extractionScript.contains("1FAIpQLSf-test-form"))
        
        let executableExtractJS = try extractExecutableJS(fromAppleScript: extractionScript)
        let rawExtractOut = try await web.evaluateJavaScript(executableExtractJS)
        let extractOut = try XCTUnwrap(rawExtractOut as? String)
        let items = FormInputAutoTracker.parseDOMExtractionItems(extractOut)
        let byLabel = Dictionary(items.map { ($0.label, $0.value) }, uniquingKeysWith: { _, last in last })
        
        XCTAssertEqual(byLabel["Full Name"], #"Ada "Lovelace" O'Connor"#)
        XCTAssertEqual(byLabel["Name of Parent or Guardian"], "")
        XCTAssertEqual(byLabel["Short Biography"], "Research engineer in macOS.")
        XCTAssertEqual(byLabel["Preferred Track"], "AI & Systems")
        XCTAssertEqual(byLabel["Available Days"], "Tuesday, Thursday")
        XCTAssertEqual(byLabel["T-Shirt Size"], "Medium (M)")
        XCTAssertEqual(byLabel["Graduation Year"], "2027")
        XCTAssertEqual(byLabel["Start Date"], "2026-11-10")
        XCTAssertEqual(byLabel["Birth Date"], "1999-04-05")
        XCTAssertEqual(byLabel["Arrival Time"], "14:30")
        XCTAssertEqual(byLabel["Site Selection"], "South Campus")
    }
    
    func testAppleScriptSyntaxCompilesForChromeAndSafari() throws {
        for bundleID in ["com.google.Chrome", "com.apple.Safari"] {
            for targetURL in ["https://docs.google.com/forms/d/e/abc123/viewform", nil] as [String?] {
                let scriptSource = try XCTUnwrap(
                    FormInputAutoTracker.buildDOMInjectionAppleScript(
                        bundleID: bundleID,
                        answers: ["Full Name": #"Jane "Q" Doe"#],
                        fields: [FormInputField(label: "Full Name", value: "", entryKey: "entry.42")],
                        targetURL: targetURL
                    )
                )
                var errorDict: NSDictionary? = nil
                let appleScript = NSAppleScript(source: scriptSource)
                let compiled = appleScript?.compileAndReturnError(&errorDict) ?? false
                XCTAssertTrue(compiled, "AppleScript for \(bundleID) must compile cleanly; error: \(String(describing: errorDict))")
                if bundleID == "com.apple.Safari",
                   let range = scriptSource.range(of: "tell front window to tell current tab") {
                    let tail = String(scriptSource[range.lowerBound...])
                    XCTAssertFalse(tail.contains(") in t") || tail.contains("\" in t"), "Safari current tab fallback must not reference loop variable t")
                }
            }
        }
    }
    
    // MARK: - 2. Delete Saved Form Copy & Cache Persistence
    
    func testDeleteSavedFormCopyRemovesFromAllStoresAndReloadPersistence() async {
        formTracker.startTracking(title: "Fellowship Application 2026", appName: "Google Chrome", url: "https://docs.google.com/forms/d/e/fellow/viewform")
        formTracker.addField(label: "Full Name", value: "Maya Lin", category: .personal)
        formTracker.addField(label: "Email Address", value: "maya@studio.org", category: .contact)
        formTracker.addField(label: "Portfolio URL", value: "https://mayalin.design", category: .contact)
        
        let copy = formTracker.saveFormSnapshot(flashLabel: false)
        XCTAssertNotNil(copy)
        guard let savedCopy = copy else { return }
        
        model.selectedFormCopyId = savedCopy.id
        model.isFormCopyDetailOpen = true
        
        // Ensure synced into Supabase caches as well
        formTracker.syncToSupabase()
        try? await Task.sleep(nanoseconds: 50_000_000)
        
        XCTAssertTrue(formTracker.savedFormCopies.contains(where: { $0.id == savedCopy.id }))
        XCTAssertTrue(supabase.memoryItems.contains(where: { $0.id == savedCopy.id }))
        XCTAssertFalse(formTracker.adaptiveProfileEntries.isEmpty)
        
        // Delete copy
        formTracker.deleteSavedFormCopy(id: savedCopy.id)
        
        XCTAssertFalse(formTracker.savedFormCopies.contains(where: { $0.id == savedCopy.id }))
        XCTAssertFalse(supabase.memoryItems.contains(where: { $0.id == savedCopy.id }))
        XCTAssertEqual(formTracker.deliveryToastMessage, "Deleted saved form copy")
        XCTAssertTrue(formTracker.adaptiveProfileEntries.isEmpty, "Adaptive profile learned solely from deleted copy must clear")
        
        // Verify persistence across brand-new ApplicationFormModel instance
        let reloadedTracker = ApplicationFormModel()
        XCTAssertFalse(reloadedTracker.savedFormCopies.contains(where: { $0.id == savedCopy.id }))
        XCTAssertFalse(SupabaseService.shared.memoryItems.contains(where: { $0.id == savedCopy.id }))
    }
    
    func testDeleteFormReceiptRemovesReceiptAndMatchingCopy() {
        let receiptID = UUID().uuidString
        let copy = SavedFormCopyRecord(
            id: receiptID,
            formTitle: "Seed Grant Form",
            savedAt: Date(),
            answers: ["Organization Name": "Asterisk Labs", "Email Address": "grants@asterisk.io"],
            sourceURL: "https://docs.google.com/forms/d/e/grant1/viewform"
        )
        formTracker.savedFormCopies.append(copy)
        formTracker.saveSavedFormCopies()
        
        let receipt = FormReceiptRecord(
            id: receiptID,
            userId: "u1",
            userEmail: "grants@asterisk.io",
            formTitle: "Seed Grant Form",
            sourceURL: "https://docs.google.com/forms/d/e/grant1/viewform",
            sourceAppName: "Safari",
            recipientEmail: "grants@asterisk.io",
            totalQuestions: 2,
            answeredCount: 2,
            fieldsJSON: "[]",
            formattedSummary: "Summary"
        )
        supabase.formReceipts.insert(receipt, at: 0)
        
        formTracker.deleteFormReceipt(id: receiptID)
        
        XCTAssertFalse(supabase.formReceipts.contains(where: { $0.id == receiptID }))
        XCTAssertFalse(formTracker.savedFormCopies.contains(where: { $0.id == receiptID }))
    }
    
    // MARK: - 3. Adaptive Profile Learning, Frequency Ranking, Editing & Dismissal
    
    func testAdaptiveProfileHasZeroHardcodedDefaultsOrLegacyDummySeed() {
        XCTAssertTrue(formTracker.profileAnswers.isEmpty, "Fresh profile must have zero hardcoded debate/dummy defaults")
        XCTAssertTrue(formTracker.adaptiveProfileEntries.isEmpty)
        
        // Even if old legacy UserDefaults seed exists, loader must skip it
        let legacySeed: [String: String] = [
            "Full Name": "John Chen",
            "Email Address": "jchen.debate@tabroom.org",
            "Institutional Conflicts": "St. Marks School of Texas",
            "Division Preference": "Policy / CX",
            "Availability": "Saturday all rounds, Sunday elims",
            "Judging Paradigm": "Tabula rasa, tech > truth, speed fine if clear"
        ]
        if let data = try? JSONEncoder().encode(legacySeed) {
            UserDefaults.standard.set(data, forKey: "com.morph.form.profile_answers")
        }
        let freshTracker = ApplicationFormModel()
        XCTAssertTrue(freshTracker.profileAnswers.isEmpty, "Legacy hardcoded dummy seed must not resurrect into clean Adaptive Profile")
    }
    
    func testAdaptiveProfileLearnsAndClustersAcrossDiverseSavedCopies() {
        let now = Date()
        let copyOldest = SavedFormCopyRecord(
            id: "c1",
            formTitle: "Startup Demo Day Signup",
            savedAt: now.addingTimeInterval(-3600),
            answers: [
                "Your Name": "Elena Rostova",
                "Email Address": "old@startup.dev",
                "GitHub Profile": "https://github.com/erostova",
                "T-Shirt Size": "Medium"
            ]
        )
        let copyMiddle = SavedFormCopyRecord(
            id: "c2",
            formTitle: "Cloud Grant Application",
            savedAt: now.addingTimeInterval(-1800),
            answers: [
                "Legal Full Name": "Elena Rostova",
                "Work Email": "elena@rostova.ai",
                "Company / Organization": "Vector Systems",
                "LinkedIn URL": "https://linkedin.com/in/erostova"
            ]
        )
        let copyNewest = SavedFormCopyRecord(
            id: "c3",
            formTitle: "Systems Fellowship Application",
            savedAt: now,
            answers: [
                "Full Name *": "Elena M. Rostova",
                "Primary Email": "elena@rostova.ai",
                "GitHub Handle": "https://github.com/erostova",
                "Why are you applying?": "Building low-latency macOS tools."
            ]
        )
        // Newest first convention
        formTracker.savedFormCopies = [copyNewest, copyMiddle, copyOldest]
        
        XCTAssertEqual(formTracker.adaptiveSourceCount, 3)
        let entries = formTracker.adaptiveProfileEntries
        XCTAssertFalse(entries.isEmpty)
        
        // Name & Email appeared in all 3 copies -> frequency 3, ranked ahead of 1x items
        let nameEntry = entries.first(where: { $0.canonicalKey == "concept:full_name" })
        let emailEntry = entries.first(where: { $0.canonicalKey == "concept:email" })
        let githubEntry = entries.first(where: { $0.canonicalKey == "concept:github" })
        let shirtEntry = entries.first(where: { $0.aliases.contains("T-Shirt Size") || $0.question.contains("T-Shirt") })
        
        XCTAssertEqual(nameEntry?.frequency, 3)
        XCTAssertEqual(nameEntry?.answer, "Elena M. Rostova", "Newest copy answer should take precedence automatically")
        XCTAssertEqual(emailEntry?.frequency, 3)
        XCTAssertEqual(emailEntry?.answer, "elena@rostova.ai")
        XCTAssertEqual(githubEntry?.frequency, 2)
        XCTAssertEqual(shirtEntry?.frequency, 1)
        
        let topTwoKeys = entries.prefix(2).map { $0.canonicalKey }
        XCTAssertTrue(topTwoKeys.contains("concept:full_name") && topTwoKeys.contains("concept:email"), "Highest frequency questions should rank at top: \(entries.map { ($0.question, $0.frequency) })")
        
        // Resolves cleanly on a brand new form with slightly varied phrasing
        formTracker.startTracking(title: "New Accelerator Form", appName: "Google Chrome")
        formTracker.addField(label: "Applicant Full Name", value: "", category: .personal)
        formTracker.addField(label: "Contact Email", value: "", category: .contact)
        formTracker.addField(label: "Your GitHub", value: "", category: .contact)
        let filled = formTracker.autofillActiveForm()
        XCTAssertEqual(filled, 3)
        XCTAssertEqual(formTracker.activeSession?.fields[0].value, "Elena M. Rostova")
        XCTAssertEqual(formTracker.activeSession?.fields[1].value, "elena@rostova.ai")
        XCTAssertEqual(formTracker.activeSession?.fields[2].value, "https://github.com/erostova")
    }
    
    func testAdaptiveProfileEditingAdditionAndDismissalPersistence() {
        let copy = SavedFormCopyRecord(
            id: "c-edit",
            formTitle: "Volunteer Intake",
            savedAt: Date(),
            answers: [
                "Full Name": "Marcus Vance",
                "Phone Number": "555-0199",
                "Favorite Color": "Cobalt"
            ]
        )
        formTracker.savedFormCopies = [copy]
        
        // 1. User overrides learned value inline
        guard let phoneEntry = formTracker.adaptiveProfileEntries.first(where: { $0.canonicalKey == "concept:phone" }) else {
            return XCTFail("Expected phone entry in adaptive profile")
        }
        formTracker.saveProfileAnswer(key: phoneEntry.question, value: "415-888-0100", canonicalKey: phoneEntry.canonicalKey)
        XCTAssertEqual(formTracker.resolveSavedInput(forQuestionLabel: "Mobile Phone"), "415-888-0100")
        
        // 2. User adds custom question via "+ Add"
        formTracker.addCustomProfileEntry(question: "Diet Preference", answer: "Vegetarian")
        XCTAssertEqual(formTracker.resolveSavedInput(forQuestionLabel: "Diet Preference"), "Vegetarian")
        
        // 3. User deletes an adaptive entry -> stays dismissed across rebuilds & reloads
        guard let colorEntry = formTracker.adaptiveProfileEntries.first(where: { $0.question.contains("Color") }) else {
            return XCTFail("Expected Favorite Color entry")
        }
        formTracker.deleteAdaptiveProfileEntry(id: colorEntry.id)
        XCTAssertFalse(formTracker.adaptiveProfileEntries.contains(where: { $0.id == colorEntry.id }))
        
        formTracker.rebuildAdaptiveProfile()
        XCTAssertFalse(formTracker.adaptiveProfileEntries.contains(where: { $0.id == colorEntry.id }), "Dismissed adaptive entry must stay excluded across rebuilds")
        
        let reloaded = ApplicationFormModel()
        XCTAssertFalse(reloaded.adaptiveProfileEntries.contains(where: { $0.id == colorEntry.id }), "Dismissed adaptive entry must persist in UserDefaults")
        XCTAssertEqual(reloaded.resolveSavedInput(forQuestionLabel: "Mobile Phone"), "415-888-0100")
        XCTAssertEqual(reloaded.resolveSavedInput(forQuestionLabel: "Diet Preference"), "Vegetarian")
    }
    
    func testQualifierIsolationPreventsCrossPollination() {
        formTracker.addCustomProfileEntry(question: "Full Name", answer: "Jordan Avery")
        
        XCTAssertNil(formTracker.resolveSavedInput(forQuestionLabel: "Name of parent"))
        XCTAssertNil(formTracker.resolveSavedInput(forQuestionLabel: "Emergency Contact Name"))
        XCTAssertNil(formTracker.resolveSavedInput(forQuestionLabel: "First Name"))
        XCTAssertNil(formTracker.resolveSavedInput(forQuestionLabel: "Company Name"))
        XCTAssertEqual(formTracker.resolveSavedInput(forQuestionLabel: "Your Full Name"), "Jordan Avery")
        
        let parentField = FormInputField(label: "Name of parent", value: "", questionType: "shortAnswer")
        XCTAssertNil(ApplicationFormModel.bestMatchingFieldIndex(for: "Full Name", in: [parentField]))
        XCTAssertFalse(formTracker.matchQuestionTitles("Full Name", "Emergency Contact Name"))
    }
    
    // MARK: - 4. Small Capsule Clickability & History Negative Cache
    
    func testSmallActiveFormCapsuleRemainsClickableAcrossUnderlyingClicksAndSweeps() {
        let controller = MorphController(model: model)
        controller.hoverDwellDelay = 0.32
        defer { controller.teardown() }
        
        // Activate compact active capsule for detected form
        formTracker.startTracking(title: "Product Feedback Survey", appName: "Google Chrome")
        formTracker.isFormDetected = true
        model.setGlassIslandState(.idle)
        
        XCTAssertTrue(model.isCompactActive)
        XCTAssertEqual(model.glassIslandWidth, 300)
        
        controller.updatePanelGeometry(animate: false)
        XCTAssertFalse(controller.shouldIgnoreMouseEvents, "Compact active form capsule must accept clicks")
        XCTAssertFalse(controller.panel.ignoresMouseEvents)
        
        let uiRect = controller.activeUIRect()
        let insidePt1 = NSPoint(x: uiRect.minX + 30, y: uiRect.midY)
        let insidePt2 = NSPoint(x: uiRect.maxX - 30, y: uiRect.midY)
        
        // Even after underlying app interaction or fast mouse movement, compact active capsule must stay clickable!
        controller.registerUnderlyingAppInteraction()
        controller.checkMousePosition(insidePt1)
        XCTAssertFalse(controller.panel.ignoresMouseEvents, "Compact active capsule must remain clickable immediately after browser click")
        
        controller.checkMousePosition(insidePt2)
        XCTAssertFalse(controller.panel.ignoresMouseEvents, "Compact active capsule must stay clickable on fast cursor movement toward Autofill button")
        
        // Collapsing form back to resting idle must restore click-through
        formTracker.isFormDetected = false
        controller.checkMousePosition(insidePt1)
        XCTAssertFalse(model.isCompactActive)
        XCTAssertTrue(controller.panel.ignoresMouseEvents, "Resting idle notch must remain click-through")
    }
    
    func testHistoryLookupNegativeCacheReturnsFastWithoutError() {
        let fakeURL = "https://docs.google.com/forms/d/e/nonexistent-\(UUID().uuidString)/viewform"
        let first = DefaultApplicationFormDetector.titleFromHistory(url: fakeURL, preferredBrowserName: "Google Chrome")
        XCTAssertNil(first)
        let second = DefaultApplicationFormDetector.titleFromHistory(url: fakeURL, preferredBrowserName: "Google Chrome")
        XCTAssertNil(second)
    }
    
    // MARK: - 5. Regression Coverage for Async Portals, 12h Time, Aged Receipts & Cleared Answers
    
    func testAsyncPortalDropdownQueue12HourTimeDDMMYYDateAndEntryKeyIsolation() async throws {
        let html = """
        <!doctype html><html><body>
        <form id="gf-async">
          <div role="listitem" class="Qr7Oae" data-params="[100]">
            <div role="heading" class="M7eMe">Country *</div>
            <div role="listbox" id="lb-country" tabindex="0">
              <div class="vRMGwf">Choose</div>
            </div>
            <input type="hidden" name="entry.100" id="h-country" value="" />
          </div>
          <div role="listitem" class="Qr7Oae" data-params="[200]">
            <div role="heading" class="M7eMe">Role Track *</div>
            <div role="listbox" id="lb-role" tabindex="0">
              <div class="vRMGwf">Choose</div>
            </div>
            <input type="hidden" name="entry.200" id="h-role" value="" />
          </div>
          <div role="listitem" class="Qr7Oae">
            <div role="heading" class="M7eMe">Session Time</div>
            <input type="text" aria-label="Hour" id="tm-h" />
            <input type="text" aria-label="Minute" id="tm-m" />
            <select id="tm-ampm"><option value="AM">AM</option><option value="PM">PM</option></select>
          </div>
          <div role="listitem" class="Qr7Oae">
            <div role="heading" class="M7eMe">Deadline Date</div>
            <input type="date" id="dt-dmy" />
          </div>
          <div role="listitem" class="Qr7Oae" data-params="[1001]">
            <div role="heading" class="M7eMe">Dietary Preference</div>
            <input type="text" name="entry.1001" id="inp-decoy" value="" />
          </div>
          <div id="portal-host"></div>
          <script>
            document.getElementById('lb-country').addEventListener('click', function() {
              var host = document.getElementById('portal-host');
              host.innerHTML = '';
              setTimeout(function() {
                host.innerHTML = '<div class="OA0qNb"><div role="option" data-value="Canada">Canada</div><div role="option" data-value="United States">United States</div></div>';
              }, 35);
            });
            document.getElementById('lb-role').addEventListener('click', function() {
              var host = document.getElementById('portal-host');
              host.innerHTML = '';
              setTimeout(function() {
                host.innerHTML = '<div class="OA0qNb"><div role="option" data-value="Systems Engineer">Systems Engineer</div><div role="option" data-value="Designer">Designer</div></div>';
              }, 35);
            });
          </script>
        </form>
        </body></html>
        """
        
        let web = try await makeWebView(html: html)
        let fields: [FormInputField] = [
            FormInputField(label: "Country", value: "", questionType: "dropdown", entryKey: "entry.100"),
            FormInputField(label: "Role Track", value: "", questionType: "dropdown", entryKey: "entry.200"),
            FormInputField(label: "Session Time", value: "", questionType: "time"),
            FormInputField(label: "Deadline Date", value: "", questionType: "date"),
            // Unmatchable radio/text or exact entryKey that must NOT overwrite Dietary Preference
            FormInputField(label: "Dietary Preference", value: "", questionType: "shortAnswer", entryKey: "entry.9999")
        ]
        // Note: Country & Role are async portals; Session Time is 14:45 -> 02:45 PM; Date is 15/04/2026 -> 2026-04-15
        // entry.9999 does NOT exist, while entry.100 & entry.1001 verify numeric word boundary matching doesn't collide
        let answers: [String: String] = [
            "Country": "United States",
            "Role Track": "Systems Engineer",
            "Session Time": "14:45",
            "Deadline Date": "15/04/2026"
        ]
        
        let script = try XCTUnwrap(
            FormInputAutoTracker.buildDOMInjectionAppleScript(
                bundleID: "com.google.Chrome",
                answers: answers,
                fields: fields,
                targetURL: "https://docs.google.com/forms/d/e/1FAIpQLSf-test-form/viewform"
            )
        )
        let js = try extractExecutableJS(fromAppleScript: script)
        let initialOut = try await web.evaluateJavaScript(js) as? String
        let initialStr = try XCTUnwrap(initialOut)
        XCTAssertTrue(initialStr.hasPrefix("__PENDING__:"), "Async Wiz portal dropdowns must return __PENDING__ prefix while queue executes; got \(initialStr)")
        
        // Wait for serialized queue (2 dropdowns * ~(95 + 35)ms)
        try await Task.sleep(nanoseconds: 450_000_000)
        
        let doneState = try await web.evaluateJavaScript("JSON.stringify(window.__morphAsyncState)") as? String
        let doneStr = try XCTUnwrap(doneState)
        XCTAssertTrue(doneStr.contains("\"done\":true"), "Async portal queue must complete: \(doneStr)")
        XCTAssertTrue(doneStr.contains("\"total\":4"), "All 4 synchronous + async controls must succeed: \(doneStr)")
        
        let countryVal = try await web.evaluateJavaScript("document.getElementById('h-country').value") as? String
        let roleVal = try await web.evaluateJavaScript("document.getElementById('h-role').value") as? String
        let tmH = try await web.evaluateJavaScript("document.getElementById('tm-h').value") as? String
        let tmM = try await web.evaluateJavaScript("document.getElementById('tm-m').value") as? String
        let tmAmPm = try await web.evaluateJavaScript("document.getElementById('tm-ampm').value") as? String
        let dtVal = try await web.evaluateJavaScript("document.getElementById('dt-dmy').value") as? String
        let decoyVal = try await web.evaluateJavaScript("document.getElementById('inp-decoy').value") as? String
        
        XCTAssertEqual(countryVal, "United States")
        XCTAssertEqual(roleVal, "Systems Engineer")
        XCTAssertEqual(tmH, "02")
        XCTAssertEqual(tmM, "45")
        XCTAssertEqual(tmAmPm, "PM")
        XCTAssertEqual(dtVal, "2026-04-15")
        XCTAssertEqual(decoyVal, "", "entry.100 must NOT substring-match data-params=\"[1001]\"")
    }
    
    func testFailedExactEntryKeyDoesNotFallThroughToFuzzyMatchAnotherQuestion() async throws {
        let html = """
        <!doctype html><html><body>
        <div role="listitem" class="Qr7Oae" data-params="[555]">
          <div role="heading" class="M7eMe">Preferred Track</div>
          <div role="radio" data-value="Frontend">Frontend</div>
          <div role="radio" data-value="Systems">Systems</div>
        </div>
        <div role="listitem" class="Qr7Oae">
          <div role="heading" class="M7eMe">Preferred Track Backup</div>
          <input type="text" id="backup-inp" value="" />
        </div>
        </body></html>
        """
        let web = try await makeWebView(html: html)
        let fields = [FormInputField(label: "Preferred Track", value: "", questionType: "multipleChoice", entryKey: "entry.555")]
        // Value "Design" does not exist in radio options of entry.555 -> must NOT fall through to text box "Preferred Track Backup"
        let script = try XCTUnwrap(
            FormInputAutoTracker.buildDOMInjectionAppleScript(
                bundleID: "com.google.Chrome",
                answers: ["Preferred Track": "Design"],
                fields: fields,
                targetURL: nil
            )
        )
        let js = try extractExecutableJS(fromAppleScript: script)
        let out = try await web.evaluateJavaScript(js) as? String
        XCTAssertEqual(out, "0")
        let backupVal = try await web.evaluateJavaScript("document.getElementById('backup-inp').value") as? String
        XCTAssertEqual(backupVal, "", "Unmatchable value on exact entryKey question must not fuzzily write into another field")
    }
    
    func testDeleteCopyRemovesAgedReceiptAndHistorySessionsWithTombstone() {
        let url = "https://docs.google.com/forms/d/e/aged-copy-123/viewform"
        let started2HoursAgo = Date().addingTimeInterval(-7200)
        var oldSession = ApplicationFormSession(
            formTitle: "Long Application",
            sourceAppName: "Google Chrome",
            sourceURL: url,
            recipientEmail: "sora@takahashi.dev",
            startedAt: started2HoursAgo,
            fields: [
                FormInputField(label: "Full Name", value: "Sora Takahashi", category: .personal),
                FormInputField(label: "Email Address", value: "sora@takahashi.dev", category: .contact)
            ]
        )
        oldSession.completedAt = Date()
        formTracker.historySessions.append(oldSession)
        formTracker.activeSession = oldSession
        
        guard let saved = formTracker.saveFormSnapshot(flashLabel: false) else {
            return XCTFail("Expected saved copy")
        }
        XCTAssertEqual(saved.sessionId, oldSession.id.uuidString)
        
        // Simulate receipt whose createdAt was 2 hours before savedAt
        let receipt = FormReceiptRecord(
            id: oldSession.id.uuidString,
            userId: "u1",
            userEmail: "sora@takahashi.dev",
            formTitle: "Long Application",
            sourceURL: url,
            sourceAppName: "Google Chrome",
            recipientEmail: "sora@takahashi.dev",
            totalQuestions: 2,
            answeredCount: 2,
            fieldsJSON: "[]",
            formattedSummary: "Summary",
            createdAt: started2HoursAgo
        )
        supabase.formReceipts = [receipt]
        
        formTracker.deleteSavedFormCopy(id: saved.id)
        
        XCTAssertTrue(formTracker.savedFormCopies.isEmpty)
        XCTAssertTrue(supabase.formReceipts.isEmpty, "Aged receipt (>120s diff) linked to copy must also be deleted")
        XCTAssertTrue(formTracker.historySessions.isEmpty, "Linked history session must be deleted so Adaptive Profile cannot resurrect answers")
        XCTAssertTrue(formTracker.adaptiveProfileEntries.isEmpty, "Deleted copy answers must not resurrect from aged receipt or history")
        
        // Verify tombstone survives reload
        let persistedTombstones = UserDefaults.standard.stringArray(forKey: SupabaseService.deletedFormReceiptIDsKey) ?? []
        XCTAssertTrue(persistedTombstones.contains(receipt.id))
    }
    
    func testAdaptiveProfileClearedAnswerBlocksFallbackAndEmptyNewerCopyDoesNotPoison() {
        let tOld = Date().addingTimeInterval(-3600)
        let tNew = Date()
        let copyOld = SavedFormCopyRecord(
            id: "c-old",
            formTitle: "Form 1",
            savedAt: tOld,
            answers: ["Phone Number": "415-555-0101", "City": "San Francisco"]
        )
        let copyNewWithEmptyPhone = SavedFormCopyRecord(
            id: "c-new",
            formTitle: "Form 2",
            savedAt: tNew,
            answers: ["Phone Number": "", "City": "New York"]
        )
        formTracker.savedFormCopies = [copyNewWithEmptyPhone, copyOld]
        
        let phoneEntry = formTracker.adaptiveProfileEntries.first(where: { $0.canonicalKey == "concept:phone" })
        XCTAssertEqual(phoneEntry?.answer, "415-555-0101", "Empty answer in newer copy must NOT block learning older valid answer")
        XCTAssertEqual(formTracker.resolveSavedInput(forQuestionLabel: "City"), "New York")
        
        // Clearing an answer in Profile explicitly prevents falling back to old copies
        if let p = phoneEntry {
            formTracker.saveProfileAnswer(key: p.question, value: "", canonicalKey: p.canonicalKey)
        }
        XCTAssertNil(formTracker.resolveSavedInput(forQuestionLabel: "Mobile Phone"), "Explicitly cleared Profile answer must NOT fall back to old saved copies")
        
        formTracker.startTracking(title: "Next Form", appName: "Safari")
        formTracker.addField(label: "Phone Number", value: "", category: .contact)
        formTracker.addField(label: "City", value: "", category: .personal)
        let filled = formTracker.autofillActiveForm()
        XCTAssertEqual(filled, 1, "Only non-cleared City should autofill")
        XCTAssertEqual(formTracker.activeSession?.fields[0].value, "")
        XCTAssertEqual(formTracker.activeSession?.fields[1].value, "New York")
    }
    
    func testPluralQualifiersAndSymmetricTopicClusteringPrecision() {
        formTracker.savedFormCopies = [
            SavedFormCopyRecord(
                id: "c-plural-2",
                formTitle: "Youth Camp",
                savedAt: Date(),
                answers: [
                    "Full Name": "Alex Rivera",
                    "Preferred Track": "Hardware",
                    "Preferred Track Backup": "Embedded"
                ]
            )
        ]
        XCTAssertNil(formTracker.resolveSavedInput(forQuestionLabel: "Parents' Full Name"), "Plural 'Parents' qualifier must stay isolated from Full Name")
        XCTAssertNil(formTracker.resolveSavedInput(forQuestionLabel: "Companies Name"), "Plural 'Companies' qualifier must stay isolated from Full Name")
        
        let trackClusters = formTracker.adaptiveProfileEntries.filter { $0.question.contains("Preferred Track") }
        XCTAssertEqual(trackClusters.count, 2, "Preferred Track and Preferred Track Backup must remain distinct clusters")
    }
    
    func testCompactPillClickabilityWithContextAwareDisabledAndPausedGlassTimer() {
        let controller = MorphController(model: model)
        defer { controller.teardown() }
        
        // Case 1: Form detected while isFormContextAwareEnabled == false -> compactHUDMode & panel must stay resting click-through
        formTracker.isFormDetected = true
        model.setFormContextAwareEnabled(false)
        XCTAssertFalse(model.isBackgroundFormActive)
        XCTAssertEqual(model.compactHUDMode, .none)
        XCTAssertEqual(model.glassIslandWidth, 176)
        controller.updatePanelGeometry(animate: false)
        XCTAssertTrue(controller.shouldIgnoreMouseEvents, "When form context awareness is disabled, resting notch must stay click-through")
        XCTAssertTrue(controller.panel.ignoresMouseEvents)
        
        // Case 2: Paused glass timer widens idle pill to 208 -> must be clickable!
        formTracker.isFormDetected = false
        model.glassTimerStatus = .paused
        XCTAssertEqual(model.glassIslandWidth, 208)
        controller.updatePanelGeometry(animate: false)
        XCTAssertFalse(controller.shouldIgnoreMouseEvents, "Paused glass timer pill must be clickable")
        XCTAssertFalse(controller.panel.ignoresMouseEvents)
        // Restore default context-aware setting for subsequent tests
        model.setFormContextAwareEnabled(true)
    }
    
    // MARK: - 6. Right-Side Display Priority, Honest Browser Injection & Filled Labels Readback
    
    func testRightSideDisplayStrictlyPrioritizesLiveUserInputOverAutofill() {
        formTracker.savedFormCopies = [
            SavedFormCopyRecord(
                id: "c-prio",
                formTitle: "Past Application",
                savedAt: Date(),
                answers: [
                    "Full Name": "Elena Rostova",
                    "Email Address": "elena@rostova.ai"
                ]
            )
        ]
        
        formTracker.startTracking(title: "Live Survey", appName: "Polar")
        formTracker.isFormDetected = true
        formTracker.isAutoCaptureEnabled = true
        let nameField = FormInputField(label: "Full Name", value: "", category: .personal, questionType: "shortAnswer", isRequired: true)
        let emailField = FormInputField(label: "Email Address", value: "", category: .contact, questionType: "shortAnswer", isRequired: true)
        let noteField = FormInputField(label: "Custom Note", value: "", category: .question, questionType: "shortAnswer", isRequired: false)
        formTracker.activeSession?.fields = [nameField, emailField, noteField]
        
        // Before user types anything: green Autofill cue appears when a saved answer exists; empty otherwise
        XCTAssertEqual(formTracker.rightSideDisplay(for: formTracker.activeSession!.fields[0]), .autofillSuggestion("Elena Rostova"))
        XCTAssertEqual(formTracker.rightSideDisplay(for: formTracker.activeSession!.fields[1]), .autofillSuggestion("elena@rostova.ai"))
        XCTAssertEqual(formTracker.rightSideDisplay(for: formTracker.activeSession!.fields[2]), .empty)
        
        // User types into Full Name synchronously -> live user input immediately overrides Autofill on right side
        let tracker = FormInputAutoTracker(model: formTracker)
        tracker.isHeadlessWebLayerMode = true
        formTracker.autoTracker = tracker
        tracker.confirmFocus(fieldID: nameField.id)
        for ch in "Minh" {
            tracker.handleKeyStroke(keyCode: 0, flags: [], characters: String(ch))
        }
        
        XCTAssertEqual(formTracker.rightSideDisplay(for: formTracker.activeSession!.fields[0]), .userInput("Minh"))
        XCTAssertEqual(formTracker.rightSideDisplay(for: formTracker.activeSession!.fields[1]), .autofillSuggestion("elena@rostova.ai"))
        XCTAssertEqual(formTracker.rightSideDisplay(for: formTracker.activeSession!.fields[2]), .empty)
        
        // User clears Full Name via Cmd+A + Backspace -> Autofill suggestion cleanly reappears
        tracker.handleKeyStroke(keyCode: 0, flags: [.maskCommand], characters: "a")
        tracker.handleKeyStroke(keyCode: 51, flags: [], characters: nil)
        XCTAssertEqual(formTracker.rightSideDisplay(for: formTracker.activeSession!.fields[0]), .autofillSuggestion("Elena Rostova"))
    }
    
    func testAutofillAndSingleQuestionHonestyWhenBrowserInjectionFailsOrPartiallySucceeds() {
        formTracker.savedFormCopies = [
            SavedFormCopyRecord(
                id: "c-honest",
                formTitle: "Prior Form",
                savedAt: Date(),
                answers: [
                    "Full Name": "Elena Rostova",
                    "Email Address": "elena@rostova.ai"
                ]
            )
        ]
        
        formTracker.startTracking(title: "Target Browser Form", appName: "Polar")
        let nameField = FormInputField(label: "Full Name", value: "", category: .personal, questionType: "shortAnswer", isRequired: true)
        let emailField = FormInputField(label: "Email Address", value: "", category: .contact, questionType: "shortAnswer", isRequired: true)
        formTracker.activeSession?.fields = [nameField, emailField]
        
        // 1. Browser injection fails (0 written) -> MUST NOT mutate Morph's local fields
        formTracker.testBrowserInjectionOverride = { _ in
            BrowserInjectionResult(
                injectedCount: 0,
                injectedLabels: [],
                errorMessage: "Polar blocks multi-field autofill — tap each question to paste, or use Chrome/Safari"
            )
        }
        let batchFail = formTracker.autofillActiveForm()
        XCTAssertEqual(batchFail, 0)
        XCTAssertEqual(formTracker.activeSession?.fields[0].value, "", "Uninjected field must not pretend to be filled")
        XCTAssertEqual(formTracker.activeSession?.fields[1].value, "", "Uninjected field must not pretend to be filled")
        XCTAssertTrue(formTracker.deliveryToastMessage?.contains("Polar blocks multi-field autofill") ?? false)
        
        let singleFail = formTracker.inputAnswerIntoActiveQuestion(fieldID: nameField.id)
        XCTAssertFalse(singleFail)
        XCTAssertEqual(formTracker.activeSession?.fields[0].value, "")
        
        // 2. Partial injection (only Full Name actually written into DOM) -> ONLY Full Name updates in Morph
        formTracker.testBrowserInjectionOverride = { _ in
            BrowserInjectionResult(injectedCount: 1, injectedLabels: ["Full Name"], errorMessage: nil)
        }
        let partialCount = formTracker.autofillActiveForm()
        XCTAssertEqual(partialCount, 1)
        XCTAssertEqual(formTracker.activeSession?.fields[0].value, "Elena Rostova")
        XCTAssertEqual(formTracker.activeSession?.fields[1].value, "", "Failed Email Address must stay empty")
        XCTAssertEqual(formTracker.deliveryToastMessage, "Autofilled 1/2 fields into form")
        
        // 3. Single-row click succeeds for remaining field -> updates that field
        formTracker.testBrowserInjectionOverride = { answers in
            BrowserInjectionResult(injectedCount: answers.count, injectedLabels: Set(answers.keys), errorMessage: nil)
        }
        let singleOK = formTracker.inputAnswerIntoActiveQuestion(fieldID: emailField.id)
        XCTAssertTrue(singleOK)
        XCTAssertEqual(formTracker.activeSession?.fields[1].value, "elena@rostova.ai")
    }
    
    func testAppleScriptFillTrackingRecordsFilledLabelsAndDOMInjectionIncludesEmailAddress() async throws {
        let html = #"""
        <!doctype html>
        <html><body>
        <form>
          <div role="listitem" class="Qr7Oae">
            <div role="heading" class="M7eMe">Email Address *</div>
            <div class="rFrNMe"><input type="email" id="inp-email" aria-label="Email Address" value=""></div>
          </div>
          <div role="listitem" class="Qr7Oae">
            <div role="heading" class="M7eMe">Home Address</div>
            <div class="rFrNMe"><input type="text" id="inp-home" aria-label="Home Address" value=""></div>
          </div>
          <div role="listitem" class="Qr7Oae">
            <div role="heading" class="M7eMe">Meal Choice</div>
            <div role="radio" data-value="Vegetarian" aria-checked="false">Vegetarian</div>
            <div role="radio" data-value="Standard" aria-checked="false">Standard</div>
          </div>
        </form>
        </body></html>
        """#
        let web = try await makeWebView(html: html)
        let fields = [
            FormInputField(label: "Email Address", value: "", category: .contact, questionType: "shortAnswer", isRequired: true),
            FormInputField(label: "Home Address", value: "", category: .contact, questionType: "shortAnswer"),
            FormInputField(label: "Meal Choice", value: "", options: ["Vegetarian", "Standard"], questionType: "multipleChoice")
        ]
        let answers: [String: String] = [
            "Email Address": "ada@lovelace.dev",
            "Home Address": "123 Computing Way",
            "Meal Choice": "Vegan" // Intentional mismatch
        ]
        
        let injectScript = try XCTUnwrap(
            FormInputAutoTracker.buildDOMInjectionAppleScript(
                bundleID: "com.google.Chrome",
                answers: answers,
                fields: fields,
                targetURL: "https://docs.google.com/forms/d/e/1FAIpQLSf-test-form/viewform"
            )
        )
        let injectJS = try extractExecutableJS(fromAppleScript: injectScript)
        let outCount = try await web.evaluateJavaScript(injectJS) as? String
        XCTAssertEqual(outCount, "2")
        
        for bundleID in ["com.google.Chrome", "com.apple.Safari"] {
            let filledScript = try XCTUnwrap(
                FormInputAutoTracker.buildDOMFilledLabelsAppleScript(
                    bundleID: bundleID,
                    targetURL: "https://docs.google.com/forms/d/e/1FAIpQLSf-test-form/viewform"
                )
            )
            var compileErr: NSDictionary? = nil
            XCTAssertTrue(NSAppleScript(source: filledScript)?.compileAndReturnError(&compileErr) ?? false, "Filled-labels script for \(bundleID) must compile; error: \(String(describing: compileErr))")
            
            let readJS = try extractExecutableJS(fromAppleScript: filledScript)
            let rawJsonOut = try await web.evaluateJavaScript(readJS)
            let jsonOut = try XCTUnwrap(rawJsonOut as? String)
            let decoded = try JSONDecoder().decode([String].self, from: Data(jsonOut.utf8))
            XCTAssertEqual(Set(decoded), ["Email Address", "Home Address"], "Only genuinely filled labels should be recorded")
            XCTAssertFalse(decoded.contains("Meal Choice"))
        }
        
        let emailVal = try await web.evaluateJavaScript("document.getElementById('inp-email').value") as? String
        let homeVal = try await web.evaluateJavaScript("document.getElementById('inp-home').value") as? String
        XCTAssertEqual(emailVal, "ada@lovelace.dev")
        XCTAssertEqual(homeVal, "123 Computing Way")
    }
    
    func testSplit12HourTimeWithAsyncListboxAMPMDoesNotDoubleCountAndExtractsAMPM() async throws {
        let html = #"""
        <!doctype html><html><body>
        <form>
          <div role="listitem" class="Qr7Oae">
            <div role="heading" class="M7eMe">Interview Slot</div>
            <input type="text" id="t-h" aria-label="Hour" value="" />
            <input type="text" id="t-m" aria-label="Minute" value="" />
            <div role="listbox" id="lb-ampm"><span class="vRMGwf">AM</span></div>
          </div>
          <div id="portal-host"></div>
          <script>
            document.getElementById('lb-ampm').addEventListener('click', function() {
              var host = document.getElementById('portal-host');
              host.innerHTML = '';
              setTimeout(function() {
                host.innerHTML = '<div class="OA0qNb"><div role="option" data-value="AM" aria-selected="false">AM</div><div role="option" data-value="PM" aria-selected="false">PM</div></div>';
              }, 30);
            });
          </script>
        </form>
        </body></html>
        """#
        
        let web = try await makeWebView(html: html)
        let field = FormInputField(label: "Interview Slot", value: "", questionType: "time")
        let injectScript = try XCTUnwrap(
            FormInputAutoTracker.buildDOMInjectionAppleScript(
                bundleID: "com.google.Chrome",
                answers: ["Interview Slot": "14:45"],
                fields: [field],
                targetURL: "https://docs.google.com/forms/d/e/1FAIpQLSf-time-test/viewform"
            )
        )
        let injectJS = try extractExecutableJS(fromAppleScript: injectScript)
        let out = try await web.evaluateJavaScript(injectJS) as? String
        XCTAssertEqual(out, "__PENDING__:1")
        
        try await Task.sleep(nanoseconds: 280_000_000)
        
        let rawState = try await web.evaluateJavaScript("JSON.stringify(window.__morphAsyncState)")
        let stateStr = try XCTUnwrap(rawState as? String)
        XCTAssertTrue(stateStr.contains("\"done\":true"), "Async AM/PM portal must finish: \(stateStr)")
        XCTAssertTrue(stateStr.contains("\"total\":1"), "Split 12h Time must count as 1 (never double-counted as 2): \(stateStr)")
        XCTAssertTrue(stateStr.contains("\"Interview Slot\""), "Filled label must include Interview Slot: \(stateStr)")
        
        let rawExtracted = try await web.evaluateJavaScript(FormInputAutoTracker.domExtractionScript)
        let extractedStr = try XCTUnwrap(rawExtracted as? String)
        let items = FormInputAutoTracker.parseDOMExtractionOutput(extractedStr)
        XCTAssertEqual(items.first(where: { $0.label == "Interview Slot" })?.value, "02:45 PM")
    }
}
