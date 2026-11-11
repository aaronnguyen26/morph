import XCTest
import SwiftUI
import AppKit
@testable import morph

@MainActor
final class MorphSmartFinderTests: XCTestCase {

    // MARK: - Deterministic Mock Provider

    final class MockFileSearchProvider: MorphFileSearchProviding, @unchecked Sendable {
        private let lock = NSLock()
        var stubbedResultsByQuery: [String: [MorphFoundFile]] = [:]
        var defaultResults: [MorphFoundFile] = []
        var artificialDelayNanoseconds: UInt64 = 0
        var partialBatchToEmit: [MorphFoundFile]? = nil
        private(set) var recordedQueries: [String] = []

        func search(
            query: String,
            limit: Int,
            onPartialResults: (@Sendable ([MorphFoundFile]) -> Void)?
        ) async throws -> [MorphFoundFile] {
            let (delay, partial, results) = lock.withLock { () -> (UInt64, [MorphFoundFile]?, [MorphFoundFile]) in
                recordedQueries.append(query)
                return (
                    artificialDelayNanoseconds,
                    partialBatchToEmit,
                    stubbedResultsByQuery[query] ?? defaultResults
                )
            }

            if let partial {
                onPartialResults?(Array(partial.prefix(limit)))
            }
            if delay > 0 {
                try await Task.sleep(nanoseconds: delay)
            }
            try Task.checkCancellation()
            return Array(results.prefix(limit))
        }
    }

    private func makeSampleFile(
        path: String,
        name: String? = nil,
        size: Int64 = 2048,
        modifiedDate: Date = Date(),
        isDirectory: Bool = false,
        isApplication: Bool = false,
        matchKind: MorphFoundFile.MatchKind = .prefixName,
        score: Double = 700
    ) -> MorphFoundFile {
        MorphFoundFile(
            url: URL(fileURLWithPath: path),
            name: name,
            fileSizeBytes: size,
            modifiedDate: modifiedDate,
            lastUsedDate: modifiedDate,
            isDirectory: isDirectory,
            isApplication: isApplication,
            matchKind: matchKind,
            relevanceScore: score
        )
    }

    // MARK: - 1. Query Parsing & Spotlight Escaping Safety

    func testQueryParserAndSpotlightEscaperSafety() {
        // Escaping special Spotlight syntax characters
        let dangerous = "report\"2026\\draft*v1?\n\0"
        let escaped = SmartFinderQueryParser.escapeSpotlightLiteral(dangerous)
        XCTAssertEqual(escaped, "report\\\"2026\\\\draft\\*v1\\?")
        XCTAssertFalse(escaped.contains("\n"))
        XCTAssertFalse(escaped.contains("\0"))

        // Predicate generation
        let pred = SmartFinderQueryParser.buildSpotlightPredicate(
            tokens: ["cs229", "notes"],
            substringMode: false,
            includeSystemAndLibrary: false
        )
        XCTAssertNotNil(pred)
        XCTAssertTrue(pred?.contains("kMDItemDisplayName == \"cs229*\"cdw") == true)
        XCTAssertTrue(pred?.contains("kMDItemDisplayName == \"notes*\"cdw") == true)
        XCTAssertTrue(pred?.contains("kMDItemPath != \"/System/Library/*\"") == true)
        XCTAssertTrue(pred?.contains("kMDItemPath != \"/Library/*\"") == true)

        // Parsing direct filename, explicit verbs, paths, short strings, and questions
        let plain = SmartFinderQueryParser.parse("Package.swift")
        XCTAssertTrue(plain.shouldTriggerLiveSearch)
        XCTAssertFalse(plain.isExplicitFileSearch)
        XCTAssertEqual(plain.tokens, ["Package.swift"])

        let explicit = SmartFinderQueryParser.parse("find cs229 notes")
        XCTAssertTrue(explicit.shouldTriggerLiveSearch)
        XCTAssertTrue(explicit.isExplicitFileSearch)
        XCTAssertEqual(explicit.searchTermsText, "cs229 notes")
        XCTAssertEqual(explicit.tokens, ["cs229", "notes"])

        let pathQuery = SmartFinderQueryParser.parse("~/Downloads")
        XCTAssertTrue(pathQuery.shouldTriggerLiveSearch)
        XCTAssertTrue(pathQuery.isPathQuery)
        XCTAssertTrue(pathQuery.isExplicitFileSearch)

        let tooShort = SmartFinderQueryParser.parse("a")
        XCTAssertFalse(tooShort.shouldTriggerLiveSearch)

        let question = SmartFinderQueryParser.parse("what is the capital of Australia?")
        XCTAssertFalse(question.shouldTriggerLiveSearch)

        let whereQuestion = SmartFinderQueryParser.parse("where is my next meeting")
        XCTAssertFalse(whereQuestion.shouldTriggerLiveSearch)

        let whereQuestionPunctuated = SmartFinderQueryParser.parse("where is my meeting?")
        XCTAssertFalse(whereQuestionPunctuated.shouldTriggerLiveSearch)

        let canYouQuestion = SmartFinderQueryParser.parse("can you summarize this")
        XCTAssertFalse(canYouQuestion.shouldTriggerLiveSearch)
    }

    // MARK: - 2. Path Normalization & Noise Filtering

    func testPathNormalizationAndNoiseFiltering() {
        let home = NSHomeDirectory()
        XCTAssertEqual(SpotlightSmartFinderProvider.shortenHomePath(home + "/Downloads/notes.pdf"), "~/Downloads/notes.pdf")
        XCTAssertEqual(SpotlightSmartFinderProvider.shortenHomePath("/Applications/Safari.app"), "/Applications/Safari.app")

        // Noise exclusions (files, segments, leaf folders, and Data-volume normalized /Library paths)
        XCTAssertTrue(SpotlightSmartFinderProvider.isNoisePath("/System/Library/Frameworks/AppKit.framework"))
        XCTAssertTrue(SpotlightSmartFinderProvider.isNoisePath("/System/Volumes/Data/Library/Preferences/com.apple.test.plist"))
        XCTAssertTrue(SpotlightSmartFinderProvider.isNoisePath("/Library/Caches/com.apple.iconservices.store"))
        XCTAssertTrue(SpotlightSmartFinderProvider.isNoisePath("/usr/share/terminfo/6d/morphos"))
        XCTAssertTrue(SpotlightSmartFinderProvider.isNoisePath("/var/log/system.log"))
        XCTAssertTrue(SpotlightSmartFinderProvider.isNoisePath("/tmp/morph_scratch.log"))
        XCTAssertTrue(SpotlightSmartFinderProvider.isNoisePath(home + "/Desktop/repo/.git/HEAD"))
        XCTAssertTrue(SpotlightSmartFinderProvider.isNoisePath(home + "/Desktop/repo/.git"))
        XCTAssertTrue(SpotlightSmartFinderProvider.isNoisePath(home + "/Desktop/app/node_modules/react/index.js"))
        XCTAssertTrue(SpotlightSmartFinderProvider.isNoisePath(home + "/Desktop/app/node_modules"))
        XCTAssertTrue(SpotlightSmartFinderProvider.isNoisePath(home + "/Desktop/morph/.build/debug/morph"))
        XCTAssertTrue(SpotlightSmartFinderProvider.isNoisePath(home + "/Library/Caches/com.apple.Safari/Cache.db"))
        XCTAssertTrue(SpotlightSmartFinderProvider.isNoisePath(home + "/Library/Group Containers/UBF8T346G9.Office/PackageResources"))

        // User-facing locations & iCloud Drive must remain visible
        XCTAssertFalse(SpotlightSmartFinderProvider.isNoisePath(home + "/Downloads/cs229 notes.pdf"))
        XCTAssertFalse(SpotlightSmartFinderProvider.isNoisePath("/Applications/Safari.app"))
        XCTAssertFalse(SpotlightSmartFinderProvider.isNoisePath(home + "/Library/Mobile Documents/com~apple~CloudDocs/Lecture.pdf"))

        // Explicit system/library query detection must not over-trigger on ".gitignore" or normal words containing "caches"
        let provider = SpotlightSmartFinderProvider()
        XCTAssertFalse(provider.isExplicitSystemOrLibraryQuery(".gitignore"))
        XCTAssertFalse(provider.isExplicitSystemOrLibraryQuery("CPU caches notes"))
        XCTAssertTrue(provider.isExplicitSystemOrLibraryQuery("/Library/Caches"))
        XCTAssertTrue(provider.isExplicitSystemOrLibraryQuery("~/.git/config"))

        // Explicit system/library query bypasses exclusion
        XCTAssertFalse(SpotlightSmartFinderProvider.isNoisePath(home + "/Library/Caches/test.db", explicitlyRequested: true))
    }

    // MARK: - 3. Relevance Ranking

    func testRelevanceRankingPrioritizesExactPrefixLocationAndRecency() {
        let provider = SpotlightSmartFinderProvider()
        let parsed = SmartFinderQueryParser.parse("cs229")
        let home = NSHomeDirectory()
        let now = Date()

        let exactScore = provider.computeRelevanceScore(
            name: "cs229.pdf",
            path: home + "/Downloads/cs229.pdf",
            isApplication: false,
            isDirectory: false,
            modifiedDate: now,
            lastUsedDate: now,
            matchKind: .exactName,
            parsed: parsed
        )
        let prefixScore = provider.computeRelevanceScore(
            name: "cs229 notes.pdf",
            path: home + "/Downloads/cs229 notes.pdf",
            isApplication: false,
            isDirectory: false,
            modifiedDate: now,
            lastUsedDate: now,
            matchKind: .prefixName,
            parsed: parsed
        )
        let deepSubstringScore = provider.computeRelevanceScore(
            name: "archive_cs229_backup_v2.pdf",
            path: home + "/Projects/archive/old/2023/term1/archive_cs229_backup_v2.pdf",
            isApplication: false,
            isDirectory: false,
            modifiedDate: now.addingTimeInterval(-365 * 86400),
            lastUsedDate: nil,
            matchKind: .substringName,
            parsed: parsed
        )

        XCTAssertGreaterThan(exactScore, prefixScore)
        XCTAssertGreaterThan(prefixScore, deepSubstringScore)
    }

    // MARK: - 4. Real Computer-Wide Spotlight Search Smoke Test

    func testRealComputerWideSpotlightProviderFindsFilesOnThisMac() async throws {
        let provider = SpotlightSmartFinderProvider()

        // Search for Package.swift across the computer
        let packageResults = try await provider.search(query: "Package.swift", limit: 15)
        XCTAssertFalse(packageResults.isEmpty, "Real computer-wide Spotlight provider must find Package.swift on this Mac")
        XCTAssertTrue(packageResults.contains(where: { $0.name == "Package.swift" }))

        if let first = packageResults.first {
            XCTAssertFalse(first.displayPath.isEmpty)
            XCTAssertEqual(first.badgeExtension, "SWIFT")
            XCTAssertFalse(first.metadataSummary.isEmpty)
        }

        // Direct path lookup on home directory
        let homeResults = try await provider.search(query: "~/", limit: 10)
        XCTAssertFalse(homeResults.isEmpty, "Direct path query ~/ must list user home entries")

        // Nonexistent direct path must return [] fast without falling back to computer-wide Spotlight stall
        let start = Date()
        let missingPathResults = try await provider.search(query: "/definitely_nonexistent_morph_path_xyz_987", limit: 10)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertTrue(missingPathResults.isEmpty)
        XCTAssertLessThan(elapsed, 0.25)

        // Mid-flight Spotlight task cancellation completes cleanly without hanging
        let cancelTask = Task {
            try await provider.search(query: "pdf", limit: 25)
        }
        try await Task.sleep(nanoseconds: 25_000_000)
        cancelTask.cancel()
        _ = try? await cancelTask.value
    }

    // MARK: - 5. Live Prompt Typing Populates Results Below Bar & Resizes Panel

    func testLivePromptTypingPopulatesResultsBelowBarAndResizesPanel() async throws {
        let mockProvider = MockFileSearchProvider()
        let home = NSHomeDirectory()
        mockProvider.stubbedResultsByQuery["budget"] = [
            makeSampleFile(path: home + "/Downloads/budget_2026.xlsx", size: 48_200, score: 900),
            makeSampleFile(path: home + "/Documents/Q4_budget_review.pdf", size: 120_500, score: 780)
        ]

        let model = NotchModel(fileSearchProvider: mockProvider)
        model.isGlassIslandEnabled = true
        model.finderDebounceNanoseconds = 15_000_000 // 15ms for fast deterministic testing
        let controller = MorphController(model: model)
        defer { controller.teardown() }

        model.setGlassIslandState(.prompt)
        XCTAssertEqual(model.glassIslandHeight, 56.0)
        XCTAssertFalse(model.isSmartFinderPanelVisible)

        // Type query into bar
        model.glassPromptText = "budget"
        // Synchronous height immediately after assignment stays 56pt
        XCTAssertEqual(model.glassIslandHeight, 56.0)

        // Wait for debounced search to populate results below bar & panel height to sync
        let deadline = Date().addingTimeInterval(2.0)
        while (model.finderResults.count < 2 || abs(controller.panel.frame.height - 229.0) > 1.0) && Date() < deadline {
            try await Task.sleep(nanoseconds: 15_000_000)
        }

        XCTAssertEqual(model.finderResults.count, 2)
        XCTAssertEqual(model.finderResults[0].name, "budget_2026.xlsx")
        XCTAssertTrue(model.isSmartFinderPanelVisible)

        // Expected height for 2 results without peek: 48 (top bar) + 89 (drawer chrome) + (2*44 + 4) = 229pt
        XCTAssertEqual(model.glassIslandHeight, 229.0, accuracy: 0.5)
        XCTAssertEqual(controller.panel.frame.height, 229.0, accuracy: 1.0)

        // Clearing prompt text immediately clears results & collapses height AND panel frame back to 56pt
        model.glassPromptText = ""
        XCTAssertTrue(model.finderResults.isEmpty)
        XCTAssertFalse(model.isSmartFinderPanelVisible)
        XCTAssertEqual(model.glassIslandHeight, 56.0)

        let shrinkDeadline = Date().addingTimeInterval(1.0)
        while controller.panel.frame.height > 57.0 && Date() < shrinkDeadline {
            try await Task.sleep(nanoseconds: 15_000_000)
        }
        XCTAssertEqual(controller.panel.frame.height, 56.0, accuracy: 1.0)
    }

    func testPromptPeekPlusSmartFinderUsesCompactThreeRowCapAndResetsExplicitSelectionOnType() async throws {
        let mockProvider = MockFileSearchProvider()
        let home = NSHomeDirectory()
        mockProvider.stubbedResultsByQuery["budget"] = [
            makeSampleFile(path: home + "/Downloads/budget_1.xlsx", score: 900),
            makeSampleFile(path: home + "/Downloads/budget_2.xlsx", score: 850),
            makeSampleFile(path: home + "/Downloads/budget_3.xlsx", score: 800),
            makeSampleFile(path: home + "/Downloads/budget_4.xlsx", score: 750)
        ]
        mockProvider.stubbedResultsByQuery["timer"] = [
            makeSampleFile(path: home + "/Downloads/timer_notes.md", score: 700)
        ]

        let model = NotchModel(fileSearchProvider: mockProvider)
        model.isGlassIslandEnabled = true
        model.finderDebounceNanoseconds = 15_000_000
        model.supabase.formReceipts = [
            FormReceiptRecord(id: "mem-1", formTitle: "Budget Form 2026", formattedSummary: "Tax filing fields")
        ]
        model.setGlassIslandState(.prompt)

        model.glassPromptText = "budget"
        await model.triggerSmartFinderSearchNow(for: "budget")

        XCTAssertTrue(model.isPromptPeekActive)
        XCTAssertEqual(model.smartFinderMaxVisibleRows, 3)
        // Top bar + Peek = 94pt, Drawer Chrome = 89pt, 3 rows = 3*44 + 2*4 = 140pt -> total = 323pt
        XCTAssertEqual(model.glassIslandHeight, 323.0, accuracy: 0.5)

        // Move selection down explicitly, then change query -> explicit selection must reset immediately
        model.moveFinderSelection(delta: 2)
        XCTAssertTrue(model.hasExplicitFinderSelection)
        XCTAssertEqual(model.finderSelectedIndex, 2)

        model.glassPromptText = "timer"
        XCTAssertFalse(model.hasExplicitFinderSelection, "Changing query text must clear previous ↑/↓ selection")
        XCTAssertEqual(model.finderSelectedIndex, 0)
    }

    // MARK: - 6. Debounce & Stale Generation Cancellation Protection

    func testDebounceAndStaleGenerationProtection() async throws {
        let mockProvider = MockFileSearchProvider()
        let home = NSHomeDirectory()
        mockProvider.artificialDelayNanoseconds = 60_000_000 // 60ms
        mockProvider.stubbedResultsByQuery["pa"] = [
            makeSampleFile(path: home + "/Desktop/stale_pa.txt", score: 500)
        ]
        mockProvider.stubbedResultsByQuery["package"] = [
            makeSampleFile(path: home + "/Desktop/coding/morph/Package.swift", score: 950)
        ]

        let model = NotchModel(fileSearchProvider: mockProvider)
        model.isGlassIslandEnabled = true
        model.finderDebounceNanoseconds = 20_000_000
        model.setGlassIslandState(.prompt)

        // Rapidly type "pa" then "package" before "pa" completes
        model.glassPromptText = "pa"
        try await Task.sleep(nanoseconds: 25_000_000)
        model.glassPromptText = "package"

        let deadline = Date().addingTimeInterval(2.0)
        while model.finderLastCompletedQuery != "package" && Date() < deadline {
            try await Task.sleep(nanoseconds: 15_000_000)
        }

        XCTAssertEqual(model.finderResults.count, 1)
        XCTAssertEqual(model.finderResults.first?.name, "Package.swift", "Stale query results must never overwrite the latest query")
    }

    // MARK: - 7. Keyboard Navigation, Open, Reveal in Finder & Stage to Drop Shelf

    func testKeyboardNavigationOpenRevealAndStageActions() async throws {
        let mockProvider = MockFileSearchProvider()
        let home = NSHomeDirectory()
        let file1 = makeSampleFile(path: home + "/Downloads/alpha.pdf", score: 900)
        let file2 = makeSampleFile(path: home + "/Downloads/beta.pdf", score: 800)
        let file3 = makeSampleFile(path: home + "/Downloads/gamma.pdf", score: 700)
        mockProvider.stubbedResultsByQuery["alpha"] = [file1, file2, file3]

        let model = NotchModel(fileSearchProvider: mockProvider)
        model.isGlassIslandEnabled = true
        model.setGlassIslandState(.prompt)
        model.glassPromptText = "alpha"
        await model.triggerSmartFinderSearchNow(for: "alpha")

        XCTAssertEqual(model.finderResults.count, 3)
        XCTAssertEqual(model.finderSelectedIndex, 0)

        let shortcut = ShortcutManager.shared
        shortcut.configure(model: model, controller: nil)

        // Down arrow moves selection from 0 -> 1 -> 2, clamping at 2
        let downEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 125
        )!
        XCTAssertTrue(shortcut.handleKeyEvent(downEvent))
        XCTAssertEqual(model.finderSelectedIndex, 1)
        XCTAssertTrue(model.hasExplicitFinderSelection)

        XCTAssertTrue(shortcut.handleKeyEvent(downEvent))
        XCTAssertEqual(model.finderSelectedIndex, 2)
        XCTAssertTrue(shortcut.handleKeyEvent(downEvent))
        XCTAssertEqual(model.finderSelectedIndex, 2, "Selection must clamp at last result")

        // Up arrow moves selection from 2 -> 1
        let upEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 126
        )!
        XCTAssertTrue(shortcut.handleKeyEvent(upEvent))
        XCTAssertEqual(model.finderSelectedIndex, 1)

        // Shift+Up / Shift+Down must NOT be hijacked so native text selection keeps working
        let shiftDown = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.shift],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 125
        )!
        XCTAssertFalse(shortcut.handleKeyEvent(shiftDown))
        XCTAssertEqual(model.finderSelectedIndex, 1)

        // Cmd+Return reveals selected file (beta.pdf) in Finder
        let cmdReturn = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )!
        XCTAssertTrue(shortcut.handleKeyEvent(cmdReturn))
        XCTAssertEqual(model.lastRevealedFoundFile?.name, "beta.pdf")

        // Numpad Cmd+Enter ("\u{3}", keyCode 76) also reveals selected file
        model.lastRevealedFoundFile = nil
        let cmdNumpadEnter = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: "\u{3}",
            charactersIgnoringModifiers: "\u{3}",
            isARepeat: false,
            keyCode: 76
        )!
        XCTAssertTrue(shortcut.handleKeyEvent(cmdNumpadEnter))
        XCTAssertEqual(model.lastRevealedFoundFile?.name, "beta.pdf")

        // Submitting prompt opens selected file (beta.pdf)
        model.submitGlassIslandPrompt("alpha")
        XCTAssertEqual(model.lastOpenedFoundFile?.name, "beta.pdf")

        // Staging a found file adds it to Drop Shelf
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("morph_finder_stage_\(UUID().uuidString).txt")
        try "hello".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let tempFound = MorphFoundFile(url: tempURL)
        model.stageFoundFileToDropShelf(tempFound)
        XCTAssertTrue(model.dropShelf.stagedItems.contains(where: { $0.url.standardizedFileURL == tempURL.standardizedFileURL }))

        // Opening via Cmd+1 (`openFeature(.home)`) + Escape clears BOTH glassIslandState and isExpanded
        model.openFeature(.home)
        XCTAssertTrue(model.isExpanded)
        XCTAssertEqual(model.glassIslandState, .prompt)
        let escapeEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: 53
        )!
        XCTAssertTrue(shortcut.handleKeyEvent(escapeEvent))
        XCTAssertEqual(model.glassIslandState, .idle)
        XCTAssertFalse(model.isExpanded)
        XCTAssertTrue(model.finderResults.isEmpty)
        XCTAssertEqual(model.glassPromptText, "")

        // Cmd+Return in .prompt with 0 results must not leak to music toggle
        model.setGlassIslandState(.prompt)
        model.glassPromptText = "find empty_nothing"
        model.finderResults = []
        let initialPlayState = model.isGlassMusicPlaying
        XCTAssertTrue(shortcut.handleKeyEvent(cmdReturn))
        XCTAssertEqual(model.isGlassMusicPlaying, initialPlayState)
    }

    // MARK: - 8. SwiftUI View Rendering Verification

    func testMorphIslandViewAndGlassSmartFinderViewRenderCleanly() async {
        let mockProvider = MockFileSearchProvider()
        let home = NSHomeDirectory()
        mockProvider.stubbedResultsByQuery["notes"] = [
            makeSampleFile(path: home + "/Downloads/cs229 notes.pdf", size: 1_450_000, score: 920),
            makeSampleFile(path: home + "/Downloads/Textbook Notes.pdf", size: 3_210_000, score: 850),
            makeSampleFile(path: "/System/Applications/Notes.app", isApplication: true, score: 810),
            makeSampleFile(path: home + "/Documents/Research", isDirectory: true, score: 740),
            makeSampleFile(path: home + "/Desktop/sprint_notes.md", size: 8_400, score: 700)
        ]

        let model = NotchModel(fileSearchProvider: mockProvider)
        model.isGlassIslandEnabled = true
        model.setGlassIslandState(.prompt)
        model.glassPromptText = "notes"
        await model.triggerSmartFinderSearchNow(for: "notes")

        XCTAssertTrue(model.isSmartFinderPanelVisible)

        let islandView = MorphIslandView(model: model)
        XCTAssertNotNil(islandView.body, "MorphIslandView with active Smart Finder results must evaluate body cleanly")

        let finderView = GlassSmartFinderView(model: model)
        XCTAssertNotNil(finderView.body, "GlassSmartFinderView must evaluate body cleanly")

        // Also test explicit empty state rendering ("find nonexistent_xyz_file")
        mockProvider.stubbedResultsByQuery["find nonexistent_xyz_file"] = []
        model.glassPromptText = "find nonexistent_xyz_file"
        await model.triggerSmartFinderSearchNow(for: "find nonexistent_xyz_file")
        XCTAssertTrue(model.isSmartFinderPanelVisible)
        XCTAssertNotNil(GlassSmartFinderView(model: model).body)
    }

    // MARK: - 9. Expanded Smart Finder Hit-Testing & Passthrough Verification

    func testSmartFinderExpandedDrawerIsCompletelyClickableAndNotClickThrough() async {
        let mockProvider = MockFileSearchProvider()
        let home = NSHomeDirectory()
        mockProvider.stubbedResultsByQuery["report"] = [
            makeSampleFile(path: home + "/Documents/report_q1.pdf", size: 42_000, score: 920),
            makeSampleFile(path: home + "/Documents/report_q2.pdf", size: 51_000, score: 860),
            makeSampleFile(path: home + "/Desktop/report_summary.md", size: 3_200, score: 810)
        ]

        let model = NotchModel(fileSearchProvider: mockProvider)
        model.isGlassIslandEnabled = true
        let controller = MorphController(model: model)
        defer { controller.teardown() }

        model.setGlassIslandState(.prompt)
        model.glassPromptText = "report"
        await model.triggerSmartFinderSearchNow(for: "report")
        controller.updatePanelGeometry(animate: false)

        // Height for 3 results: 48 + 89 + (3*44 + 2*4) = 277pt
        XCTAssertEqual(model.currentWidth, 460.0)
        XCTAssertEqual(model.currentHeight, 277.0, accuracy: 0.5)
        XCTAssertFalse(controller.shouldIgnoreMouseEvents)
        XCTAssertFalse(controller.panel.ignoresMouseEvents)

        let hostingView = controller.hostingView!
        hostingView.frame = NSRect(x: 0, y: 0, width: model.currentWidth, height: model.currentHeight)
        hostingView.layoutSubtreeIfNeeded()

        // Hit-test across prompt bar AND Smart Finder results drawer below the bar
        let clickablePoints: [NSPoint] = [
            NSPoint(x: 230, y: 250), // Top prompt bar
            NSPoint(x: 230, y: 170), // Row 1 area
            NSPoint(x: 230, y: 110), // Row 2 area
            NSPoint(x: 230, y: 40),  // Bottom row / footer hint area
            NSPoint(x: 420, y: 110)  // Trailing Reveal/Drop Shelf action zone
        ]
        for pt in clickablePoints {
            XCTAssertNotNil(hostingView.hitTest(pt), "Point \(pt) inside expanded Smart Finder panel must accept clicks")
        }

        // Points outside active bounds must still pass through
        XCTAssertNil(hostingView.hitTest(NSPoint(x: 600, y: 100)))
    }

    // MARK: - 10. File Extension & Explicit Search Take Priority Over Keyword Collision

    func testFileExtensionAndExplicitFindSubmitOpensFileOverKeywordCollision() async {
        let mockProvider = MockFileSearchProvider()
        let home = NSHomeDirectory()
        let pdfNotes = makeSampleFile(path: home + "/Downloads/cs229 notes.pdf", size: 2_400_000, score: 940)
        let exactNotesPDF = makeSampleFile(path: home + "/Documents/notes.pdf", size: 120_000, score: 980)
        let notesFolder = makeSampleFile(path: home + "/Documents/Notes", isDirectory: true, score: 990)
        let calendarFolder = makeSampleFile(path: home + "/Desktop/Calendar", isDirectory: true, score: 990)
        let debateFolder = makeSampleFile(path: home + "/Desktop/Debate", isDirectory: true, score: 990)
        mockProvider.stubbedResultsByQuery["find cs229 notes"] = [pdfNotes]
        mockProvider.stubbedResultsByQuery["notes.pdf"] = [exactNotesPDF]
        mockProvider.stubbedResultsByQuery["open notes"] = [notesFolder, exactNotesPDF]
        mockProvider.stubbedResultsByQuery["calendar"] = [calendarFolder]
        mockProvider.stubbedResultsByQuery["find note about project"] = [exactNotesPDF]
        mockProvider.stubbedResultsByQuery["debate"] = [debateFolder]

        let model = NotchModel(fileSearchProvider: mockProvider)
        model.isGlassIslandEnabled = true
        model.supabase.formReceipts = [
            FormReceiptRecord(id: "mem-debate", formTitle: "Debate", formattedSummary: "NSDA tournament form")
        ]
        model.glassNotes = [
            GlassNote(title: "Project", body: "Ship Smart Finder on Monday")
        ]
        model.setGlassIslandState(.prompt)

        // 1. Explicit "find cs229 notes" opens matched file instead of routing to .notes
        model.glassPromptText = "find cs229 notes"
        await model.triggerSmartFinderSearchNow(for: "find cs229 notes")
        model.submitGlassIslandPrompt("find cs229 notes")
        XCTAssertEqual(model.lastOpenedFoundFile?.name, "cs229 notes.pdf")
        XCTAssertEqual(model.glassIslandState, .prompt)

        // 2. Filename with extension "notes.pdf" opens matched file instead of routing to .notes
        model.lastOpenedFoundFile = nil
        model.glassPromptText = "notes.pdf"
        await model.triggerSmartFinderSearchNow(for: "notes.pdf")
        model.submitGlassIslandPrompt("notes.pdf")
        XCTAssertEqual(model.lastOpenedFoundFile?.name, "notes.pdf")
        XCTAssertEqual(model.glassIslandState, .prompt)

        // 3. Explicit "open notes" routes to .notes tab even if a folder named "Notes" matched, and clears results
        model.lastOpenedFoundFile = nil
        model.glassPromptText = "open notes"
        await model.triggerSmartFinderSearchNow(for: "open notes")
        model.submitGlassIslandPrompt("open notes")
        XCTAssertEqual(model.glassIslandState, .notes)
        XCTAssertNil(model.lastOpenedFoundFile)
        XCTAssertTrue(model.finderResults.isEmpty)

        // 4. Bare Morph command "calendar" routes to .calendar tab even if a folder named "Calendar" matched
        model.setGlassIslandState(.prompt)
        model.glassPromptText = "calendar"
        await model.triggerSmartFinderSearchNow(for: "calendar")
        model.submitGlassIslandPrompt("calendar")
        XCTAssertEqual(model.glassIslandState, .calendar)
        XCTAssertNil(model.lastOpenedFoundFile)

        // 5. Internal Morph Note Q&A ("find note about project") stays on Notes Q&A (.reply) unless explicitly selected
        model.setGlassIslandState(.prompt)
        model.glassPromptText = "find note about project"
        await model.triggerSmartFinderSearchNow(for: "find note about project")
        model.submitGlassIslandPrompt("find note about project")
        XCTAssertEqual(model.glassIslandState, .reply)
        XCTAssertEqual(model.glassReplyDomainTitle, "Notes")
        XCTAssertNil(model.lastOpenedFoundFile)

        // 6. Form Memory collision ("debate" folder vs Form Memory) opens .forms unless user explicitly arrow-selected the file
        model.setGlassIslandState(.prompt)
        model.glassPromptText = "debate"
        await model.triggerSmartFinderSearchNow(for: "debate")
        model.submitGlassIslandPrompt("debate")
        XCTAssertEqual(model.glassIslandState, .forms)
        XCTAssertNil(model.lastOpenedFoundFile)

        model.setGlassIslandState(.prompt)
        model.glassPromptText = "debate"
        await model.triggerSmartFinderSearchNow(for: "debate")
        model.moveFinderSelection(delta: 0)
        XCTAssertTrue(model.hasExplicitFinderSelection)
        model.submitGlassIslandPrompt("debate")
        XCTAssertEqual(model.lastOpenedFoundFile?.name, "Debate")
    }
}
