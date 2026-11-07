import XCTest
import SwiftUI
import PDFKit
import UniformTypeIdentifiers
@testable import morph

@MainActor
final class LiquidGlassDropShelfTests: XCTestCase {
    private var model: NotchModel!
    private nonisolated(unsafe) var tempDir: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: "com.morph.dropshelf.holdShelfOnDrop")
        UserDefaults.standard.removeObject(forKey: "com.morph.dropshelf.holdFilesAfterDrag")
        UserDefaults.standard.removeObject(forKey: "com.morph.custom_feature_colors")
        UserDefaults.standard.removeObject(forKey: "com.morph.enabled_features")
        
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        model = NotchModel()
        model.isGlassIslandEnabled = true
        model.setGlassIslandState(.idle)
    }
    
    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "com.morph.dropshelf.holdShelfOnDrop")
        UserDefaults.standard.removeObject(forKey: "com.morph.dropshelf.holdFilesAfterDrag")
        UserDefaults.standard.removeObject(forKey: "com.morph.custom_feature_colors")
        UserDefaults.standard.removeObject(forKey: "com.morph.enabled_features")
        
        if let dir = tempDir {
            try? FileManager.default.removeItem(at: dir)
        }
        model = nil
        try await super.tearDown()
    }
    
    private func createTestFile(name: String, content: String = "Test content") -> URL {
        let fileURL = tempDir.appendingPathComponent(name)
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
    
    private func createTestPDF(name: String, pages: Int = 3) -> URL {
        let pdfURL = tempDir.appendingPathComponent(name)
        let pdfDoc = PDFDocument()
        for _ in 0..<pages {
            pdfDoc.insert(PDFPage(), at: pdfDoc.pageCount)
        }
        pdfDoc.write(to: pdfURL)
        return pdfURL
    }
    
    // MARK: - 1. Liquid Glass State Metrics & Color Alignment
    func testGlassDropsStateDimensionsAndStyling() {
        model.setGlassIslandState(.drops)
        
        XCTAssertEqual(model.glassIslandState, .drops)
        XCTAssertEqual(model.currentWidth, 460.0, "Liquid Glass Drop Shelf width must be 460 pt")
        XCTAssertEqual(model.currentHeight, 284.0, "Liquid Glass Drop Shelf height must be 284 pt")
        XCTAssertEqual(model.glassIslandRadius, 34.0, "Liquid Glass Drop Shelf corner radius must be 34 pt")
        XCTAssertEqual(model.glassIslandTintHex, "#38bdf8", "Default tint must be electric cyan (#38bdf8)")
    }
    
    func testCustomColorForDropsFeature() {
        model.setCustomFeatureColor("#00d2ff", for: .drops)
        model.setGlassIslandState(.drops)
        XCTAssertEqual(model.glassIslandTintHex, "#00d2ff", "Custom color must override default tint")
        
        model.resetFeatureColor(for: .drops)
        XCTAssertEqual(model.glassIslandTintHex, "#38bdf8", "Resetting color must restore default electric cyan")
    }
    
    // MARK: - 2. Drag-In Over Notch Expands Resting Pill to Welcoming Drop Target
    func testDragOverNotchExpandsRestingPill() {
        model.setGlassIslandState(.idle)
        XCTAssertEqual(model.currentWidth, 176.0, "Idle resting width without active items is 176 pt")
        
        // When drag starts hovering over Morph notch
        model.dropShelf.isDraggingOverNotch = true
        XCTAssertEqual(model.currentWidth, 280.0, "Hovering with dragged file over Morph must expand resting pill to 280 pt drop target")
        
        // Drag leaves notch
        model.dropShelf.isDraggingOverNotch = false
        XCTAssertEqual(model.currentWidth, 176.0, "Leaving notch without dropping restores resting width")
    }
    
    // MARK: - 3. Dropping Files Staged in Shelf and Transitions to Liquid Glass View
    func testDroppingFileStagesAndTransitionsToDropsView() async throws {
        let pdfURL = createTestPDF(name: "Architecture_Spec.pdf", pages: 5)
        let controller = MorphController(model: model)
        defer { controller.teardown() }
        
        model.setGlassIslandState(.idle)
        XCTAssertFalse(model.dropShelf.hasItems)
        
        // Simulate dragging entered
        let dragEnterResult = controller.hostingView.onDraggingEntered?(createMockDraggingInfo(url: pdfURL))
        XCTAssertEqual(dragEnterResult, .copy)
        try await Task.sleep(nanoseconds: 30_000_000)
        XCTAssertTrue(model.dropShelf.isDraggingOverNotch)
        
        // Simulate perform drag operation
        let dropSuccess = controller.hostingView.onPerformDragOperation?(createMockDraggingInfo(url: pdfURL)) ?? false
        XCTAssertTrue(dropSuccess, "Drop operation must succeed")
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // File must be staged
        XCTAssertEqual(model.dropShelf.count, 1)
        XCTAssertEqual(model.dropShelf.stagedItems.first?.name, "Architecture_Spec.pdf")
        XCTAssertEqual(model.dropShelf.stagedItems.first?.pageCount, 5)
        
        // In glass island mode, drop must set glassIslandState to .drops
        XCTAssertEqual(model.glassIslandState, .drops, "Dropping file onto Morph must open .drops Liquid Glass view")
        XCTAssertFalse(model.dropShelf.isDraggingOverNotch)
    }
    
    func testDroppingMultipleFilesStagesAllWithDeduplication() {
        let file1 = createTestFile(name: "Token1.json")
        let file2 = createTestFile(name: "Token2.json")
        
        model.dropShelf.stageFiles(urls: [file1, file2, file1]) // include duplicate
        XCTAssertEqual(model.dropShelf.count, 2, "Duplicate file must be deduplicated")
        XCTAssertEqual(model.dropShelf.stagedItems[0].name, "Token1.json")
        XCTAssertEqual(model.dropShelf.stagedItems[1].name, "Token2.json")
    }
    
    // MARK: - 4. Resting Pill Staged Items Indicator
    func testRestingPillShowsStagedItemsIndicator() {
        let textURL = createTestFile(name: "readme.txt")
        model.dropShelf.stageFile(url: textURL)
        model.setGlassIslandState(.idle)
        
        XCTAssertTrue(model.isBackgroundDropActive)
        XCTAssertEqual(model.currentWidth, 220.0, "Resting pill with staged items must widen to 220 pt to display files indicator")
        
        // Contextual open destination when hovering Morph with staged files
        XCTAssertEqual(model.contextualOpenState, .drops, "Contextual destination when files staged is .drops")
    }
    
    // MARK: - 5. Prompt Bar & Spotlight Understanding for Drop Shelf
    func testPromptPeekRecognizesDropShelfCommands() {
        model.setGlassIslandState(.prompt)
        
        model.glassPromptText = "drop shelf"
        XCTAssertNotNil(model.promptPeekInfo)
        XCTAssertEqual(model.promptPeekInfo?.actionType, "drops")
        XCTAssertEqual(model.promptPeekInfo?.title, "Open Drop Shelf")
        
        model.glassPromptText = "files"
        XCTAssertNotNil(model.promptPeekInfo)
        XCTAssertEqual(model.promptPeekInfo?.actionType, "drops")
        
        model.glassPromptText = "stash"
        XCTAssertNotNil(model.promptPeekInfo)
        XCTAssertEqual(model.promptPeekInfo?.actionType, "drops")
    }
    
    func testSubmittingDropShelfPromptRoutesToDrops() {
        model.setGlassIslandState(.prompt)
        model.submitGlassIslandPrompt("open drop shelf")
        XCTAssertEqual(model.glassIslandState, .drops, "Prompting 'open drop shelf' must route to .drops")
        XCTAssertEqual(model.glassPromptText, "", "Prompt text must be consumed on submission")
    }
    
    // MARK: - 6. Toolbar Tab Toggle & Esc Dismissal
    func testTabToggleBetweenPromptAndDrops() {
        model.setGlassIslandState(.prompt)
        
        // Click drops tab
        model.toggleGlassIslandTab(.drops)
        XCTAssertEqual(model.glassIslandState, .drops)
        
        // Click drops tab again toggles back to prompt
        model.toggleGlassIslandTab(.drops)
        XCTAssertEqual(model.glassIslandState, .prompt)
    }
    
    func testEscapeDismissesToIdleStealth() {
        model.setGlassIslandState(.drops)
        let shortcut = ShortcutManager.shared
        shortcut.model = model
        
        let escEvent = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{1b}",
            charactersIgnoringModifiers: "\u{1b}",
            isARepeat: false,
            keyCode: 53 // Escape
        )!
        
        let handled = shortcut.handleKeyEvent(escEvent)
        XCTAssertTrue(handled)
        XCTAssertEqual(model.glassIslandState, .idle, "Escape must dismiss Liquid Glass Drop Shelf to idle stealth")
    }
    
    // MARK: - 7. Liquid Glass DropShelfView Hierarchy & Actions
    func testLiquidGlassDropShelfViewRendersCleanly() {
        let pdfURL = createTestPDF(name: "design_system.pdf", pages: 8)
        let txtURL = createTestFile(name: "build_spec.txt")
        model.dropShelf.stageFiles(urls: [pdfURL, txtURL])
        model.setGlassIslandState(.drops)
        
        let islandView = MorphIslandView(model: model)
        XCTAssertNotNil(islandView.body, "MorphIslandView with .drops active must evaluate body cleanly")
        
        let shelfView = DropShelfView(model: model)
        XCTAssertNotNil(shelfView.body, "DropShelfView must evaluate body cleanly")
    }
    
    func testEmptyDropZoneRendersWhenNoItems() {
        model.dropShelf.clearAll()
        model.setGlassIslandState(.drops)
        
        let shelfView = DropShelfView(model: model)
        XCTAssertNotNil(shelfView.body, "Empty DropShelfView must evaluate body cleanly")
        XCTAssertFalse(model.dropShelf.hasItems)
    }
    
    func testCopyPathsAndShareAllHelpers() {
        let f1 = createTestFile(name: "a.txt")
        let f2 = createTestFile(name: "b.txt")
        model.dropShelf.stageFiles(urls: [f1, f2])
        
        model.dropShelf.copyAllFilePaths()
        let copied = NSPasteboard.general.string(forType: .string)
        XCTAssertNotNil(copied)
        XCTAssertTrue(copied!.contains("a.txt"))
        XCTAssertTrue(copied!.contains("b.txt"))
        
        model.dropShelf.revealAllInFinder()
        XCTAssertEqual(model.dropShelf.lastActionMessage, "Revealed 2 files in Finder")
        
        model.dropShelf.clearAll()
        XCTAssertEqual(model.dropShelf.count, 0)
        XCTAssertFalse(model.dropShelf.hasItems)
    }
    
    // MARK: - Mock Dragging Info Helper
    private func createMockDraggingInfo(url: URL) -> NSDraggingInfo {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([url as NSURL])
        return MockDraggingInfo(pasteboard: pb)
    }
}

// Minimal NSDraggingInfo mock for headless unit tests
private final class MockDraggingInfo: NSObject, NSDraggingInfo, @unchecked Sendable {
    nonisolated(unsafe) let draggingPasteboard: NSPasteboard
    var draggingLocation: NSPoint = .zero
    var draggedImageLocation: NSPoint = .zero
    var draggedImage: NSImage? = nil
    var draggingSourceOperationMask: NSDragOperation = .copy
    var draggingDestinationWindow: NSWindow? = nil
    var draggingSource: Any? = nil
    var draggingSequenceNumber: Int = 1
    var numberOfValidItemsForDrop: Int = 1
    var animatesToDestination: Bool = false
    var draggingFormation: NSDraggingFormation = .default
    var springLoadingHighlight: NSSpringLoadingHighlight = .none
    
    init(pasteboard: NSPasteboard) {
        self.draggingPasteboard = pasteboard
        super.init()
    }
    
    func resetSpringLoading() {}
    func slideDraggedImage(to screenPoint: NSPoint) {}
    func enumerateDraggingItems(options: NSDraggingItemEnumerationOptions = [], for view: NSView?, classes: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey : Any] = [:], using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
}
