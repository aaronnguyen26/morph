import XCTest
@testable import morph

@MainActor
final class FocusCustomTimeTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Clean test environment
        UserDefaults.standard.removeObject(forKey: PomodoroMode.work.preferenceKey)
        UserDefaults.standard.removeObject(forKey: PomodoroMode.shortBreak.preferenceKey)
        UserDefaults.standard.removeObject(forKey: PomodoroMode.longBreak.preferenceKey)
        UserDefaults.standard.removeObject(forKey: "MorphPomodoroTotalDuration")
        UserDefaults.standard.removeObject(forKey: "MorphPomodoroTimeRemaining")
        UserDefaults.standard.removeObject(forKey: "MorphPomodoroMode")
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: PomodoroMode.work.preferenceKey)
        UserDefaults.standard.removeObject(forKey: PomodoroMode.shortBreak.preferenceKey)
        UserDefaults.standard.removeObject(forKey: PomodoroMode.longBreak.preferenceKey)
        UserDefaults.standard.removeObject(forKey: "MorphPomodoroTotalDuration")
        UserDefaults.standard.removeObject(forKey: "MorphPomodoroTimeRemaining")
        UserDefaults.standard.removeObject(forKey: "MorphPomodoroMode")
        super.tearDown()
    }
    
    func testDefaultPreferredDurations() {
        let pomodoro = PomodoroModel()
        
        XCTAssertEqual(pomodoro.preferredDuration(for: .work), 25 * 60, "Work default must be 25 minutes.")
        XCTAssertEqual(pomodoro.preferredDuration(for: .shortBreak), 5 * 60, "Short break default must be 5 minutes.")
        XCTAssertEqual(pomodoro.preferredDuration(for: .longBreak), 15 * 60, "Long break default must be 15 minutes.")
        XCTAssertFalse(pomodoro.isUsingCustomPreference(for: .work))
        XCTAssertFalse(pomodoro.isUsingCustomPreference(for: .shortBreak))
        XCTAssertFalse(pomodoro.isUsingCustomPreference(for: .longBreak))
    }
    
    func testSetCustomDurationPerMode() {
        let pomodoro = PomodoroModel()
        
        // Customize Work to 50 minutes and save as preference
        pomodoro.setPreferredDuration(minutes: 50, for: .work)
        XCTAssertEqual(pomodoro.preferredDuration(for: .work), 50 * 60)
        XCTAssertEqual(pomodoro.totalDuration, 50 * 60)
        XCTAssertEqual(pomodoro.timeRemaining, 50 * 60)
        XCTAssertEqual(pomodoro.currentMinutes, 50)
        XCTAssertTrue(pomodoro.isUsingCustomPreference(for: .work))
        
        // Customize Short Break to 10 minutes and save as preference
        pomodoro.setPreferredDuration(minutes: 10, for: .shortBreak)
        XCTAssertEqual(pomodoro.preferredDuration(for: .shortBreak), 10 * 60)
        XCTAssertTrue(pomodoro.isUsingCustomPreference(for: .shortBreak))
        
        // Customize Long Break to 30 minutes and save as preference
        pomodoro.setPreferredDuration(minutes: 30, for: .longBreak)
        XCTAssertEqual(pomodoro.preferredDuration(for: .longBreak), 30 * 60)
        XCTAssertTrue(pomodoro.isUsingCustomPreference(for: .longBreak))
        
        // Switching to Short Break must load the custom 10m preference
        pomodoro.switchMode(.shortBreak)
        XCTAssertEqual(pomodoro.mode, .shortBreak)
        XCTAssertEqual(pomodoro.totalDuration, 10 * 60)
        XCTAssertEqual(pomodoro.timeRemaining, 10 * 60)
        XCTAssertEqual(pomodoro.formattedTime, "10:00")
        
        // Switching to Long Break must load the custom 30m preference
        pomodoro.switchMode(.longBreak)
        XCTAssertEqual(pomodoro.mode, .longBreak)
        XCTAssertEqual(pomodoro.totalDuration, 30 * 60)
        XCTAssertEqual(pomodoro.timeRemaining, 30 * 60)
        XCTAssertEqual(pomodoro.formattedTime, "30:00")
        
        // Switching back to Work must restore the custom 50m preference
        pomodoro.switchMode(.work)
        XCTAssertEqual(pomodoro.mode, .work)
        XCTAssertEqual(pomodoro.totalDuration, 50 * 60)
        XCTAssertEqual(pomodoro.timeRemaining, 50 * 60)
        XCTAssertEqual(pomodoro.formattedTime, "50:00")
    }
    
    func testRestoreDefaultDuration() {
        let pomodoro = PomodoroModel()
        
        pomodoro.setPreferredDuration(minutes: 45, for: .work)
        XCTAssertTrue(pomodoro.isUsingCustomPreference(for: .work))
        XCTAssertEqual(pomodoro.currentMinutes, 45)
        
        pomodoro.restoreDefaultDuration(for: .work)
        XCTAssertFalse(pomodoro.isUsingCustomPreference(for: .work))
        XCTAssertEqual(pomodoro.preferredDuration(for: .work), 25 * 60)
        XCTAssertEqual(pomodoro.totalDuration, 25 * 60)
        XCTAssertEqual(pomodoro.timeRemaining, 25 * 60)
        XCTAssertEqual(pomodoro.formattedTime, "25:00")
    }
    
    func testSetCustomDurationWithoutOverwritingPreference() {
        let pomodoro = PomodoroModel()
        
        // Standard preference is 25m
        XCTAssertEqual(pomodoro.preferredDuration(for: .work), 25 * 60)
        
        // Temporarily set custom duration to 15m without saving preference
        pomodoro.setCustomDuration(minutes: 15, saveAsPreference: false)
        XCTAssertEqual(pomodoro.totalDuration, 15 * 60)
        XCTAssertEqual(pomodoro.timeRemaining, 15 * 60)
        XCTAssertEqual(pomodoro.currentMinutes, 15)
        
        // Saved preference should still be 25m
        XCTAssertEqual(pomodoro.preferredDuration(for: .work), 25 * 60)
    }
    
    func testAdjustTimeDelta() {
        let pomodoro = PomodoroModel()
        pomodoro.setCustomDuration(minutes: 25, saveAsPreference: false)
        XCTAssertEqual(pomodoro.timeRemaining, 25 * 60)
        
        // Add 5 minutes
        pomodoro.adjustTime(deltaMinutes: 5)
        XCTAssertEqual(pomodoro.timeRemaining, 30 * 60)
        XCTAssertEqual(pomodoro.totalDuration, 30 * 60)
        
        // Subtract 1 minute
        pomodoro.adjustTime(deltaMinutes: -1)
        XCTAssertEqual(pomodoro.timeRemaining, 29 * 60)
        
        // Subtract 5 minutes
        pomodoro.adjustTime(deltaMinutes: -5)
        XCTAssertEqual(pomodoro.timeRemaining, 24 * 60)
        
        // Clamping check: subtracting excessive minutes clamps to 10s minimum
        pomodoro.adjustTime(deltaMinutes: -100)
        XCTAssertEqual(pomodoro.timeRemaining, 10)
    }
    
    func testModeSpecificPresets() {
        let pomodoro = PomodoroModel()
        
        pomodoro.switchMode(.work)
        XCTAssertEqual(pomodoro.currentPresets, [25, 45, 50, 60])
        
        pomodoro.switchMode(.shortBreak)
        XCTAssertEqual(pomodoro.currentPresets, [3, 5, 10, 15])
        
        pomodoro.switchMode(.longBreak)
        XCTAssertEqual(pomodoro.currentPresets, [15, 20, 30, 45])
    }
    
    func testProgressCalculation() {
        let pomodoro = PomodoroModel()
        pomodoro.setCustomDuration(minutes: 10, saveAsPreference: false)
        XCTAssertEqual(pomodoro.progress, 0.0, accuracy: 0.001)
        
        // Adjust remaining time to half
        pomodoro.adjustTime(deltaMinutes: -5)
        XCTAssertEqual(pomodoro.progress, 0.5, accuracy: 0.01)
    }
}
