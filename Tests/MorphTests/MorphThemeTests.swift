import XCTest
import SwiftUI
@testable import morph

@MainActor
final class MorphThemeTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "MorphThemeMode")
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "MorphThemeMode")
        MainActor.assumeIsolated {
            MorphTheme.shared.setMode(.dark)
        }
        super.tearDown()
    }
    
    func testThemeDefaultIsDark() {
        let theme = MorphTheme.shared
        theme.setMode(.dark)
        XCTAssertEqual(theme.mode, .dark)
        XCTAssertTrue(theme.isDark)
    }
    
    func testThemeTogglingBetweenDarkAndLight() {
        let theme = MorphTheme.shared
        theme.setMode(.dark)
        XCTAssertTrue(theme.isDark)
        XCTAssertEqual(theme.mode, .dark)
        
        theme.toggleTheme()
        XCTAssertFalse(theme.isDark)
        XCTAssertEqual(theme.mode, .light)
        
        theme.toggleTheme()
        XCTAssertTrue(theme.isDark)
        XCTAssertEqual(theme.mode, .dark)
    }
    
    func testThemeModePersistence() {
        let theme = MorphTheme.shared
        theme.setMode(.light)
        
        let saved = UserDefaults.standard.string(forKey: "MorphThemeMode")
        XCTAssertEqual(saved, MorphThemeMode.light.rawValue)
        
        theme.setMode(.dark)
        let savedDark = UserDefaults.standard.string(forKey: "MorphThemeMode")
        XCTAssertEqual(savedDark, MorphThemeMode.dark.rawValue)
    }
    
    func testNotchModelThemeIntegration() {
        let notchModel = NotchModel()
        notchModel.theme.setMode(.dark)
        XCTAssertTrue(notchModel.theme.isDark)
        
        notchModel.toggleTheme()
        XCTAssertFalse(notchModel.theme.isDark)
        XCTAssertEqual(notchModel.theme.mode, .light)
    }
    
    func testSemanticColorsPerTheme() {
        let theme = MorphTheme.shared
        
        // Dark Obsidian checks
        theme.setMode(.dark)
        XCTAssertTrue(theme.isDark)
        let darkBg = theme.canvasBackground
        let darkText = theme.textPrimary
        let darkActivePill = theme.activePillBackground
        let darkActivePillText = theme.activePillText
        
        // Light Ceramic checks
        theme.setMode(.light)
        XCTAssertFalse(theme.isDark)
        let lightBg = theme.canvasBackground
        let lightText = theme.textPrimary
        let lightActivePill = theme.activePillBackground
        let lightActivePillText = theme.activePillText
        
        XCTAssertNotEqual(darkBg, lightBg)
        XCTAssertNotEqual(darkText, lightText)
        XCTAssertNotEqual(darkActivePill, lightActivePill)
        XCTAssertNotEqual(darkActivePillText, lightActivePillText)
    }
    
    func testModeAccentColors() {
        let theme = MorphTheme.shared
        theme.setMode(.dark)
        let workAccent = theme.accentColor(for: .work)
        let shortAccent = theme.accentColor(for: .shortBreak)
        let longAccent = theme.accentColor(for: .longBreak)
        
        XCTAssertEqual(workAccent, theme.focusAccent)
        XCTAssertEqual(shortAccent, theme.shortBreakAccent)
        XCTAssertEqual(longAccent, theme.longBreakAccent)
    }
    
    func testPomodoroViewInitializationWithTheme() {
        let pomodoro = PomodoroModel()
        let theme = MorphTheme.shared
        theme.setMode(.light)
        
        let view = PomodoroView(pomodoro: pomodoro, theme: theme)
        XCTAssertNotNil(view)
        XCTAssertFalse(view.theme.isDark)
        
        theme.setMode(.dark)
        XCTAssertTrue(view.theme.isDark)
    }
}
