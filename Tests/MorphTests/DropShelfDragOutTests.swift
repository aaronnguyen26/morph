import XCTest
import SwiftUI
import PDFKit
import UniformTypeIdentifiers
@testable import morph

@MainActor
final class DropShelfDragOutTests: XCTestCase {
    
    private nonisolated(unsafe) var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "com.morph.dropshelf.holdShelfOnDrop")
        UserDefaults.standard.removeObject(forKey: "com.morph.dropshelf.holdFilesAfterDrag")
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "com.morph.dropshelf.holdShelfOnDrop")
        UserDefaults.standard.removeObject(forKey: "com.morph.dropshelf.holdFilesAfterDrag")
        if let dir = tempDirectory {
            try? FileManager.default.removeItem(at: dir)
        }
        super.tearDown()
    }
    
    private func createTestPDF(name: String, pageCount: Int) -> URL {
        let pdfURL = tempDirectory.appendingPathComponent(name)
        let pdfDoc = PDFDocument()
        for _ in 0..<pageCount {
            let page = PDFPage()
            pdfDoc.insert(page, at: pdfDoc.pageCount)
        }
        pdfDoc.write(to: pdfURL)
        return pdfURL
    }
    
    // MARK: - 1. PDF Staging & Metadata Generation
    
    func testPDFItemCreationAndThumbnail() {
        let pdfURL = createTestPDF(name: "quarterly_financial_report.pdf", pageCount: 4)
        let shelf = DropShelfModel(holdShelfOnDrop: false, holdFilesAfterDrag: false)
        
        let item = shelf.stageFile(url: pdfURL)
        
        XCTAssertTrue(item.isPDF, "Item should be identified as a PDF")
        XCTAssertEqual(item.pageCount, 4, "PDF page count should be accurately extracted via PDFKit")
        XCTAssertNotNil(item.icon, "PDFKit should generate a thumbnail preview")
        XCTAssertTrue(item.subtitle.contains("4 pgs"), "Subtitle should include formatted page count: \(item.subtitle)")
        XCTAssertEqual(item.pathExtension, "PDF")
        XCTAssertEqual(shelf.count, 1)
        XCTAssertTrue(shelf.hasItems)
    }
    
    func testNonPDFItemHandling() {
        let textURL = tempDirectory.appendingPathComponent("notes.txt")
        try? "Sample content for testing".write(to: textURL, atomically: true, encoding: .utf8)
        
        let shelf = DropShelfModel(holdShelfOnDrop: false, holdFilesAfterDrag: false)
        let item = shelf.stageFile(url: textURL)
        
        XCTAssertFalse(item.isPDF, "Text file should not be flagged as a PDF")
        XCTAssertNil(item.pageCount, "Non-PDF file should not have a page count")
        XCTAssertEqual(item.subtitle, item.formattedSize, "Subtitle should default to formatted size")
        XCTAssertEqual(item.pathExtension, "TXT")
    }
    
    // MARK: - 2. Drag-Out Lifecycle & State Machine
    
    func testDragOutLifecycleAndHUDMode() {
        let pdfURL = createTestPDF(name: "design_system_spec.pdf", pageCount: 2)
        let shelf = DropShelfModel(holdShelfOnDrop: false, holdFilesAfterDrag: true)
        let notchModel = NotchModel(dropShelf: shelf)
        
        let item = shelf.stageFile(url: pdfURL)
        XCTAssertFalse(shelf.isDraggingOut)
        XCTAssertNil(shelf.activeDraggedItem)
        
        // 1. Initiate drag-out
        shelf.startDragOut(for: item)
        XCTAssertTrue(shelf.isDraggingOut, "isDraggingOut flag should be true during drag operation")
        XCTAssertEqual(shelf.activeDraggedItem?.id, item.id)
        XCTAssertEqual(shelf.lastActionMessage, "Dragging \(item.name)...")
        
        // Notch compactHUDMode must remain .dropShelfActive during drag out
        XCTAssertEqual(notchModel.compactHUDMode, .dropShelfActive)
        
        // 2. Conclude drag-out with holdFilesAfterDrag enabled
        shelf.endDragOut(successful: true)
        XCTAssertFalse(shelf.isDraggingOut, "isDraggingOut should reset to false after drag ends")
        XCTAssertNil(shelf.activeDraggedItem)
        XCTAssertEqual(shelf.lastActionMessage, "Exported: \(item.name) (Held)")
        XCTAssertTrue(shelf.hasItems, "File must remain on shelf when Hold Files option is enabled")
    }
    
    // MARK: - 3. Hold Mode Options (Hold on Drop & Hold on Drag Out)
    
    func testHoldModeToggle() {
        let shelf = DropShelfModel(holdShelfOnDrop: true, holdFilesAfterDrag: true)
        XCTAssertTrue(shelf.isHoldModeActive)
        
        shelf.toggleHoldMode()
        XCTAssertFalse(shelf.isHoldModeActive)
        XCTAssertFalse(shelf.holdShelfOnDrop)
        XCTAssertFalse(shelf.holdFilesAfterDrag)
        
        shelf.toggleHoldMode()
        XCTAssertTrue(shelf.isHoldModeActive)
        XCTAssertTrue(shelf.holdShelfOnDrop)
        XCTAssertTrue(shelf.holdFilesAfterDrag)
    }
    
    func testDropFileWithHoldModeKeepsShelfHeldOpen() {
        let pdfURL = createTestPDF(name: "held_spec.pdf", pageCount: 1)
        let shelf = DropShelfModel(holdShelfOnDrop: true, holdFilesAfterDrag: true)
        let notchModel = NotchModel(dropShelf: shelf)
        let controller = MorphController(model: notchModel)
        
        notchModel.isExpanded = true
        XCTAssertFalse(shelf.isHeldOpen)
        
        // Dropping file in with Hold option ON must set isHeldOpen = true
        _ = shelf.stageFile(url: pdfURL)
        XCTAssertTrue(shelf.isHeldOpen, "Shelf must be held open when holdShelfOnDrop is enabled")
        XCTAssertEqual(notchModel.compactHUDMode, .dropShelfActive)
        
        // When mouse leaves notch bounds, isHeldOpen prevents collapse
        let outsidePoint = NSPoint(x: 500, y: 100)
        XCTAssertFalse(controller.isMouseInsideMorphUI(outsidePoint))
        controller.checkMousePosition(outsidePoint)
        XCTAssertTrue(notchModel.isExpanded, "Shelf must hold open and not collapse when cursor moves away")
        
        // Releasing hold allows collapse
        shelf.releaseHold()
        XCTAssertFalse(shelf.isHeldOpen)
    }
    
    func testDragOutWithHoldDisabledConsumesFile() {
        let pdfURL = createTestPDF(name: "transient_file.pdf", pageCount: 1)
        let shelf = DropShelfModel(holdShelfOnDrop: true, holdFilesAfterDrag: false)
        let item = shelf.stageFile(url: pdfURL)
        XCTAssertEqual(shelf.count, 1)
        XCTAssertTrue(shelf.isHeldOpen)
        
        // Drag out with holdFilesAfterDrag == false
        shelf.startDragOut(for: item)
        shelf.endDragOut(successful: true)
        
        // File must be removed from shelf
        XCTAssertEqual(shelf.count, 0, "File should be removed from shelf when Hold Files option is disabled")
        XCTAssertFalse(shelf.hasItems)
        XCTAssertFalse(shelf.isHeldOpen, "Empty shelf should release held open state")
        XCTAssertEqual(shelf.lastActionMessage, "Exported: \(item.name)")
    }
    
    func testClearAllReleasesHold() {
        let pdfURL = createTestPDF(name: "to_clear.pdf", pageCount: 1)
        let shelf = DropShelfModel(holdShelfOnDrop: true, holdFilesAfterDrag: true)
        _ = shelf.stageFile(url: pdfURL)
        XCTAssertTrue(shelf.isHeldOpen)
        
        shelf.clearAll()
        XCTAssertFalse(shelf.isHeldOpen)
        XCTAssertEqual(shelf.count, 0)
    }
    
    // MARK: - 4. ItemProvider & Pasteboard Export Compatibility
    
    func testItemProviderAndPasteboardPayload() {
        let pdfURL = createTestPDF(name: "contract_signed.pdf", pageCount: 1)
        let shelf = DropShelfModel()
        let item = shelf.stageFile(url: pdfURL)
        
        let provider = NSItemProvider(object: item.url as NSURL)
        provider.suggestedName = item.name
        
        // Check registered types for Finder & desktop drag destinations
        XCTAssertTrue(provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
        XCTAssertEqual(provider.suggestedName, "contract_signed.pdf")
        
        // Verify pasteboard writing capabilities
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("morph.test.dragout.\(UUID().uuidString)"))
        pasteboard.clearContents()
        let writeSuccess = pasteboard.writeObjects([item.url as NSURL])
        XCTAssertTrue(writeSuccess, "NSURL should write cleanly to drag pasteboard")
        
        let readURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL]
        XCTAssertEqual(readURLs?.first?.path, pdfURL.path)
    }
    
    // MARK: - 5. UI View Hierarchies With Drag Modifiers
    
    func testDropShelfViewAndCardDraggableHierarchy() {
        let pdfURL = createTestPDF(name: "executive_presentation.pdf", pageCount: 10)
        let notchModel = NotchModel()
        let stagedItem = notchModel.dropShelf.stageFile(url: pdfURL)
        
        // DropShelfView hierarchy
        let shelfView = DropShelfView(model: notchModel)
        XCTAssertNotNil(shelfView.body)
        
        // DropShelfCardView hierarchy
        let cardView = DropShelfCardView(item: stagedItem, shelf: notchModel.dropShelf)
        XCTAssertNotNil(cardView.body)
        
        // Compact Notch Wing hierarchy with draggable first item
        let leftWing = CompactDropShelfWingLeft(shelf: notchModel.dropShelf, model: notchModel)
        XCTAssertNotNil(leftWing.body)
        
        let rightWing = CompactDropShelfWingRight(shelf: notchModel.dropShelf, model: notchModel)
        XCTAssertNotNil(rightWing.body)
    }
    
    // MARK: - 6. MorphController Window Shrink Protection
    
    func testMorphControllerDragOutCollapseGuard() {
        let notchModel = NotchModel()
        let controller = MorphController(model: notchModel)
        
        // Expand Morph
        notchModel.isExpanded = true
        XCTAssertTrue(notchModel.isExpanded)
        
        // Stage PDF and mark dragging out active
        let pdfURL = createTestPDF(name: "report.pdf", pageCount: 1)
        let item = notchModel.dropShelf.stageFile(url: pdfURL)
        notchModel.dropShelf.startDragOut(for: item)
        
        // Simulate mouse position far below the notch (e.g. at the bottom of the screen dragging into Finder)
        let screenPointOutside = NSPoint(x: 500, y: 100)
        XCTAssertFalse(controller.isMouseInsideMorphUI(screenPointOutside))
        
        // Calling checkMousePosition while dragging out must NOT trigger collapse
        controller.checkMousePosition(screenPointOutside)
        XCTAssertTrue(notchModel.isExpanded, "Morph must stay expanded while a file is being dragged out across the screen")
        
        // Now end drag out
        notchModel.dropShelf.endDragOut()
        XCTAssertFalse(notchModel.dropShelf.isDraggingOut)
    }
    
    // MARK: - 7. Context-Aware UI Closing & Feature Restoration on Drag Out
    
    func testDragOutPDFClosesDropShelfAndRestoresHome() {
        let pdfURL = createTestPDF(name: "annual_report.pdf", pageCount: 5)
        let notchModel = NotchModel()
        notchModel.selectedTab = .home
        notchModel.openContextualFeature(.dropShelf)
        
        XCTAssertEqual(notchModel.activeContextFeature, .dropShelf)
        
        let item = notchModel.dropShelf.stageFile(url: pdfURL)
        XCTAssertEqual(notchModel.dropShelf.count, 1)
        
        // Drag out PDF
        notchModel.dropShelf.startDragOut(for: item)
        notchModel.dropShelf.endDragOut(successful: true)
        
        // 1. Drop Shelf UI must be closed
        XCTAssertNil(notchModel.activeContextFeature, "Drop Shelf contextual UI must close after drag out")
        XCTAssertFalse(notchModel.dropShelf.isHeldOpen, "Drop Shelf hold state must be released")
        XCTAssertEqual(notchModel.dropShelf.count, 0, "PDF item must be removed from Drop Shelf")
        
        // 2. Switched back to home UI
        XCTAssertEqual(notchModel.selectedTab, .home, "Must switch back to Home tab when home was previous UI")
    }
    
    func testDragOutPDFClosesDropShelfAndRestoresLatestFeatureUsed() {
        let pdfURL = createTestPDF(name: "architecture_whitepaper.pdf", pageCount: 8)
        let notchModel = NotchModel()
        
        // User was in Notes feature
        notchModel.openFeature(.notes)
        XCTAssertEqual(notchModel.selectedTab, .notes)
        XCTAssertEqual(notchModel.lastUsedFeatureTab, .notes)
        
        // Drop Shelf opens
        notchModel.openContextualFeature(.dropShelf)
        XCTAssertEqual(notchModel.activeContextFeature, .dropShelf)
        
        let item = notchModel.dropShelf.stageFile(url: pdfURL)
        
        // User takes the PDF out of Drop Shelf
        notchModel.dropShelf.startDragOut(for: item)
        notchModel.dropShelf.endDragOut(successful: true)
        
        // Drop Shelf UI must close and restore Notes feature
        XCTAssertNil(notchModel.activeContextFeature, "Drop Shelf contextual UI must close after drag out")
        XCTAssertEqual(notchModel.selectedTab, .notes, "Must restore the latest feature used (.notes)")
    }
    
    func testDragOutPDFContextAwareRestoresMusicPlaying() {
        let pdfURL = createTestPDF(name: "track_lyrics.pdf", pageCount: 2)
        let notchModel = NotchModel()
        
        notchModel.selectedTab = .home
        notchModel.media.isPlaying = true
        
        notchModel.openContextualFeature(.dropShelf)
        XCTAssertEqual(notchModel.activeContextFeature, .dropShelf)
        
        let item = notchModel.dropShelf.stageFile(url: pdfURL)
        
        // Take PDF out
        notchModel.dropShelf.startDragOut(for: item)
        notchModel.dropShelf.endDragOut(successful: true)
        
        // Context-aware: music is actively playing, so restore music tab
        XCTAssertNil(notchModel.activeContextFeature)
        XCTAssertEqual(notchModel.selectedTab, .music, "Must switch back to .music when audio is playing")
    }
    
    func testDragOutPDFContextAwareRestoresTimerRunning() {
        let pdfURL = createTestPDF(name: "study_guide.pdf", pageCount: 12)
        let notchModel = NotchModel()
        
        notchModel.selectedTab = .home
        notchModel.pomodoro.isRunning = true
        
        notchModel.openContextualFeature(.dropShelf)
        XCTAssertEqual(notchModel.activeContextFeature, .dropShelf)
        
        let item = notchModel.dropShelf.stageFile(url: pdfURL)
        
        // Take PDF out
        notchModel.dropShelf.startDragOut(for: item)
        notchModel.dropShelf.endDragOut(successful: true)
        
        // Context-aware: timer is running, so restore timer tab
        XCTAssertNil(notchModel.activeContextFeature)
        XCTAssertEqual(notchModel.selectedTab, .timer, "Must switch back to .timer when pomodoro is running")
    }
    
    func testDragOutPDFContextAwareRestoresMeetingFlight() {
        let pdfURL = createTestPDF(name: "meeting_agenda.pdf", pageCount: 1)
        let notchModel = NotchModel()
        
        notchModel.selectedTab = .calendar
        notchModel.meetingController.isInCall = true
        
        notchModel.openContextualFeature(.dropShelf)
        XCTAssertEqual(notchModel.activeContextFeature, .dropShelf)
        
        let item = notchModel.dropShelf.stageFile(url: pdfURL)
        
        // Take PDF out
        notchModel.dropShelf.startDragOut(for: item)
        notchModel.dropShelf.endDragOut(successful: true)
        
        // Context-aware: in call, so restore meeting flight
        XCTAssertEqual(notchModel.activeContextFeature, .meetingFlight, "Must restore .meetingFlight when user is in a call")
    }
    
    func testDragOutPDFContextAwareRestoresPinnedNote() {
        let pdfURL = createTestPDF(name: "memo.pdf", pageCount: 1)
        let notchModel = NotchModel()
        
        notchModel.selectedTab = .home
        notchModel.isNotePinnedToNotch = true
        
        notchModel.openContextualFeature(.dropShelf)
        XCTAssertEqual(notchModel.activeContextFeature, .dropShelf)
        
        let item = notchModel.dropShelf.stageFile(url: pdfURL)
        
        // Take PDF out
        notchModel.dropShelf.startDragOut(for: item)
        notchModel.dropShelf.endDragOut(successful: true)
        
        // Context-aware: note is pinned to notch, so restore notes tab
        XCTAssertNil(notchModel.activeContextFeature)
        XCTAssertEqual(notchModel.selectedTab, .notes, "Must switch back to .notes when note is pinned to notch")
    }
    
    func testDragOutPDFContextAwareRestoresCalendarAlert() {
        let pdfURL = createTestPDF(name: "brief.pdf", pageCount: 1)
        let notchModel = NotchModel()
        
        notchModel.selectedTab = .home
        notchModel.calendar.showNotchAlert = true
        
        notchModel.openContextualFeature(.dropShelf)
        XCTAssertEqual(notchModel.activeContextFeature, .dropShelf)
        
        let item = notchModel.dropShelf.stageFile(url: pdfURL)
        
        // Take PDF out
        notchModel.dropShelf.startDragOut(for: item)
        notchModel.dropShelf.endDragOut(successful: true)
        
        // Context-aware: calendar alert active, so restore calendar tab
        XCTAssertNil(notchModel.activeContextFeature)
        XCTAssertEqual(notchModel.selectedTab, .calendar, "Must switch back to .calendar when calendar alert is active")
    }
    
    func testRemovingLastPDFViaXMarkClosesDropShelfAndRestoresContext() {
        let pdfURL = createTestPDF(name: "single_doc.pdf", pageCount: 1)
        let notchModel = NotchModel()
        
        notchModel.openFeature(.calendar)
        notchModel.openContextualFeature(.dropShelf)
        XCTAssertEqual(notchModel.activeContextFeature, .dropShelf)
        
        let item = notchModel.dropShelf.stageFile(url: pdfURL)
        XCTAssertEqual(notchModel.dropShelf.count, 1)
        
        // User clicks the xmark / remove button on the single item
        notchModel.dropShelf.removeItem(id: item.id)
        
        XCTAssertNil(notchModel.activeContextFeature, "Emptying the drop shelf via removeItem must close the drop shelf UI")
        XCTAssertEqual(notchModel.selectedTab, .calendar, "Must restore the previously open .calendar tab")
    }
    
    func testClearAllClosesDropShelfAndRestoresContext() {
        let pdfURL1 = createTestPDF(name: "doc1.pdf", pageCount: 1)
        let pdfURL2 = createTestPDF(name: "doc2.pdf", pageCount: 2)
        let notchModel = NotchModel()
        
        notchModel.openFeature(.profile)
        notchModel.openContextualFeature(.dropShelf)
        XCTAssertEqual(notchModel.activeContextFeature, .dropShelf)
        
        _ = notchModel.dropShelf.stageFile(url: pdfURL1)
        _ = notchModel.dropShelf.stageFile(url: pdfURL2)
        XCTAssertEqual(notchModel.dropShelf.count, 2)
        
        // User clicks Clear All
        notchModel.dropShelf.clearAll()
        
        XCTAssertNil(notchModel.activeContextFeature, "Clearing all items must close the drop shelf UI")
        XCTAssertEqual(notchModel.selectedTab, .profile, "Must restore the previously open .profile tab")
    }
    
    func testDragOutOneOfMultiplePDFsClosesDropShelfUIAndRetainsRemainingFile() {
        let pdfURL1 = createTestPDF(name: "export_me.pdf", pageCount: 1)
        let pdfURL2 = createTestPDF(name: "keep_me.pdf", pageCount: 2)
        let notchModel = NotchModel()
        
        notchModel.openFeature(.notes)
        notchModel.openContextualFeature(.dropShelf)
        XCTAssertEqual(notchModel.activeContextFeature, .dropShelf)
        
        let item1 = notchModel.dropShelf.stageFile(url: pdfURL1)
        let item2 = notchModel.dropShelf.stageFile(url: pdfURL2)
        XCTAssertEqual(notchModel.dropShelf.count, 2)
        
        // Drag out only item1
        notchModel.dropShelf.startDragOut(for: item1)
        notchModel.dropShelf.endDragOut(successful: true)
        
        // Drop Shelf UI closes and restores Notes
        XCTAssertNil(notchModel.activeContextFeature, "Drop shelf UI must close when a file is dragged out")
        XCTAssertEqual(notchModel.selectedTab, .notes, "Must switch back to latest feature used")
        
        // Item 1 was removed, Item 2 remains on shelf
        XCTAssertEqual(notchModel.dropShelf.count, 1)
        XCTAssertEqual(notchModel.dropShelf.stagedItems.first?.id, item2.id)
    }
}
