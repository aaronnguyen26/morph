import XCTest
import SwiftUI
import AppKit
@testable import morph

@MainActor
final class AppleUXEnhancementsTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            MorphHaptics.resetTestCounter()
            MorphTheme.shared.setMode(.dark)
        }
    }
    
    override func tearDown() {
        MainActor.assumeIsolated {
            MorphTheme.shared.setMode(.dark)
            MorphHaptics.resetTestCounter()
        }
        super.tearDown()
    }
    
    // MARK: - 1. Tactile Haptic Engine Verification
    
    func testMorphHapticsEngineTracksEventsSafelyInTestEnvironment() {
        XCTAssertTrue(MorphEnvironment.isTestingEnvironment)
        MorphHaptics.resetTestCounter()
        XCTAssertEqual(MorphHaptics.lastPerformedFeedbackCount, 0)
        
        MorphHaptics.alignment()
        XCTAssertEqual(MorphHaptics.lastPerformedFeedbackCount, 1)
        
        MorphHaptics.levelChange()
        XCTAssertEqual(MorphHaptics.lastPerformedFeedbackCount, 2)
        
        MorphHaptics.generic()
        XCTAssertEqual(MorphHaptics.lastPerformedFeedbackCount, 3)
        
        MorphHaptics.resetTestCounter()
        XCTAssertEqual(MorphHaptics.lastPerformedFeedbackCount, 0)
    }
    
    // MARK: - 2. Monochromatic Design System Semantic Tokens
    
    func testMorphThemeMonochromaticSemanticTokensInDarkAndLightModes() {
        let theme = MorphTheme.shared
        
        theme.setMode(.dark)
        XCTAssertTrue(theme.isDark)
        let darkDropBorder = theme.dropTargetBorder
        let darkDropGlow = theme.dropTargetGlow
        let darkBadgeBg = theme.badgeBackground
        let darkBadgeText = theme.badgeText
        let darkHoverBg = theme.elevatedHoverBackground
        let darkFocusRing = theme.focusRingBorder
        let darkInset = theme.surfaceInset
        
        theme.setMode(.light)
        XCTAssertFalse(theme.isDark)
        let lightDropBorder = theme.dropTargetBorder
        let lightDropGlow = theme.dropTargetGlow
        let lightBadgeBg = theme.badgeBackground
        let lightBadgeText = theme.badgeText
        let lightHoverBg = theme.elevatedHoverBackground
        let lightFocusRing = theme.focusRingBorder
        let lightInset = theme.surfaceInset
        
        XCTAssertNotEqual(darkDropBorder, lightDropBorder)
        XCTAssertNotEqual(darkDropGlow, lightDropGlow)
        XCTAssertNotEqual(darkBadgeBg, lightBadgeBg)
        XCTAssertNotEqual(darkBadgeText, lightBadgeText)
        XCTAssertNotEqual(darkHoverBg, lightHoverBg)
        XCTAssertNotEqual(darkFocusRing, lightFocusRing)
        XCTAssertNotEqual(darkInset, lightInset)
    }
    
    // MARK: - 3. Quick Command Bar (⌘K) & Tab Cycling
    
    func testQuickCommandBarToggleAndDismissalPriority() {
        let model = NotchModel()
        let controller = MorphController(model: model)
        ShortcutManager.shared.configure(model: model, controller: controller)
        
        XCTAssertFalse(model.isExpanded)
        XCTAssertFalse(model.isCommandBarPresented)
        
        // Toggling Command Bar when collapsed expands island and presents Command Bar
        ShortcutManager.shared.toggleCommandBar()
        XCTAssertTrue(model.isExpanded)
        XCTAssertTrue(model.isCommandBarPresented)
        XCTAssertEqual(ShortcutManager.shared.lastTriggeredShortcut, "⌘K Command Bar")
        
        // Pressing navBack (⌘[) or closeOrCollapse (⌘W) while Command Bar is open dismisses Command Bar first without collapsing island
        ShortcutManager.shared.navBack()
        XCTAssertFalse(model.isCommandBarPresented)
        XCTAssertTrue(model.isExpanded)
        
        // Open Command Bar again and test closeOrCollapse (⌘W)
        model.toggleCommandBar()
        XCTAssertTrue(model.isCommandBarPresented)
        ShortcutManager.shared.closeOrCollapse()
        XCTAssertFalse(model.isCommandBarPresented)
        XCTAssertTrue(model.isExpanded)
        
        // Navigating to a feature automatically closes Command Bar
        model.toggleCommandBar()
        XCTAssertTrue(model.isCommandBarPresented)
        model.openFeature(.timer)
        XCTAssertFalse(model.isCommandBarPresented)
        XCTAssertEqual(model.selectedTab, .timer)
    }
    
    func testTabCyclingForwardAndBackwardWrapsCleanly() {
        let model = NotchModel()
        let controller = MorphController(model: model)
        ShortcutManager.shared.configure(model: model, controller: controller)
        
        model.openFeature(.home)
        let allTabs = MorphTab.allCases
        XCTAssertEqual(model.selectedTab, allTabs[0])
        
        // Cycle forward through all tabs and wrap around to .home
        for i in 1...allTabs.count {
            ShortcutManager.shared.cycleNextTab()
            let expectedTab = allTabs[i % allTabs.count]
            XCTAssertEqual(model.selectedTab, expectedTab)
        }
        
        // Cycle backward from .home wraps to the last tab (.profile)
        ShortcutManager.shared.cyclePreviousTab()
        XCTAssertEqual(model.selectedTab, allTabs.last)
    }
    
    func testContextualOverlayDismissesBeforeIslandCollapseOnCloseOrBack() {
        let model = NotchModel()
        let controller = MorphController(model: model)
        ShortcutManager.shared.configure(model: model, controller: controller)
        
        model.openFeature(.home)
        model.openContextualFeature(.dropShelf)
        XCTAssertEqual(model.activeContextFeature, .dropShelf)
        XCTAssertTrue(model.isExpanded)
        
        // Calling navBack while a contextual feature is active on .home closes the contextual feature first
        ShortcutManager.shared.navBack()
        XCTAssertNil(model.activeContextFeature)
        XCTAssertTrue(model.isExpanded)
    }
    
    // MARK: - 4. Pomodoro Haptics & Authentic Telemetry
    
    func testPomodoroHapticsAndLifecycle() {
        let pomodoro = PomodoroModel()
        MorphHaptics.resetTestCounter()
        
        pomodoro.start()
        XCTAssertTrue(pomodoro.isRunning)
        XCTAssertGreaterThan(MorphHaptics.lastPerformedFeedbackCount, 0)
        
        let countAfterStart = MorphHaptics.lastPerformedFeedbackCount
        pomodoro.pause()
        XCTAssertFalse(pomodoro.isRunning)
        XCTAssertGreaterThan(MorphHaptics.lastPerformedFeedbackCount, countAfterStart)
        
        let countAfterPause = MorphHaptics.lastPerformedFeedbackCount
        pomodoro.switchMode(.shortBreak)
        XCTAssertEqual(pomodoro.mode, .shortBreak)
        XCTAssertGreaterThan(MorphHaptics.lastPerformedFeedbackCount, countAfterPause)
    }
    
    // MARK: - 5. Scratchpad Formatting Actions & Extended Undo
    
    func testScratchpadBulletAndTimestampInsertionAndExtendedUndo() {
        let scratchpad = ScratchpadModel()
        scratchpad.text = ""
        
        scratchpad.insertBulletItem()
        XCTAssertTrue(scratchpad.text.hasPrefix("• "))
        
        scratchpad.text = "First item"
        scratchpad.insertBulletItem()
        XCTAssertEqual(scratchpad.text, "First item\n• ")
        
        scratchpad.insertTimestamp()
        XCTAssertTrue(scratchpad.text.contains("["))
        XCTAssertTrue(scratchpad.text.contains("] "))
        
        // Clear & verify undo state
        let savedContent = scratchpad.text
        scratchpad.clear()
        XCTAssertEqual(scratchpad.text, "")
        XCTAssertTrue(scratchpad.canUndoClear)
        
        scratchpad.undoClear()
        XCTAssertEqual(scratchpad.text, savedContent)
        XCTAssertFalse(scratchpad.canUndoClear)
    }
    
    // MARK: - 6. Drop Shelf Total Size Telemetry
    
    func testDropShelfFormattedTotalSizeAndSafeOpen() throws {
        let shelf = DropShelfModel()
        shelf.clearAll()
        XCTAssertEqual(shelf.formattedTotalSize, "0 B")
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("morph_ux_test_\(UUID().uuidString).txt")
        let data = Data(repeating: 0x41, count: 4096) // 4 KB
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        shelf.stageFile(url: tempURL)
        XCTAssertEqual(shelf.count, 1)
        XCTAssertFalse(shelf.formattedTotalSize.isEmpty)
        XCTAssertNotEqual(shelf.formattedTotalSize, "0 B")
        
        // Safe openItem in test environment must not crash or launch external app
        if let first = shelf.stagedItems.first {
            shelf.openItem(first)
        }
        shelf.clearAll()
    }
    
    // MARK: - 7. Full Light & Dark Mode Rendering Including Command Bar & Connected Views
    
    func testAllViewsAndCommandBarRenderCleanlyInDarkAndLightModes() {
        let model = NotchModel()
        model.isExpanded = true
        model.isCommandBarPresented = true
        
        for mode in [MorphThemeMode.dark, MorphThemeMode.light] {
            model.theme.setMode(mode)
            
            let islandHosting = NSHostingView(rootView: MorphIslandView(model: model, onMouseEnter: {}, onMouseExit: {}))
            islandHosting.frame = NSRect(x: 0, y: 0, width: 640, height: 225)
            islandHosting.layoutSubtreeIfNeeded()
            XCTAssertEqual(islandHosting.frame.width, 640)
            
            let scratchpadHosting = NSHostingView(rootView: ScratchpadView(scratchpad: model.scratchpad, theme: model.theme, model: model))
            scratchpadHosting.frame = NSRect(x: 0, y: 0, width: 640, height: 225)
            scratchpadHosting.layoutSubtreeIfNeeded()
            XCTAssertNotNil(scratchpadHosting.rootView.model)
            
            let dropShelfHosting = NSHostingView(rootView: DropShelfView(model: model))
            dropShelfHosting.frame = NSRect(x: 0, y: 0, width: 640, height: 225)
            dropShelfHosting.layoutSubtreeIfNeeded()
            
            let formHosting = NSHostingView(rootView: ApplicationFormTrackerView(model: model))
            formHosting.frame = NSRect(x: 0, y: 0, width: 640, height: 225)
            formHosting.layoutSubtreeIfNeeded()
            
            let meetingHosting = NSHostingView(rootView: MeetingFlightControllerView(model: model))
            meetingHosting.frame = NSRect(x: 0, y: 0, width: 640, height: 225)
            meetingHosting.layoutSubtreeIfNeeded()
        }
    }
}
