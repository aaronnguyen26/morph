import XCTest
import SwiftUI
import AppKit
@testable import morph

@MainActor
final class BackgroundEfficiencyAndZeroLagTests: XCTestCase {
    
    // MARK: - 1. Media Controller Visualizer On-Demand Gating
    func testVisualizerTimerOnlyRunsWhenVisualizerActiveAndPlaying() {
        let media = MediaControllerModel()
        
        // Initial state: visualizer inactive, not playing
        XCTAssertFalse(media.isVisualizerActive, "Visualizer should be inactive by default to save CPU")
        XCTAssertFalse(media.isVisualizerTimerRunning, "Visualizer timer must be inactive initially")
        
        // Playing music, but Morph is collapsed (isVisualizerActive == false)
        media.isPlaying = true
        media.isMuted = false
        media.syncVisualizerTimer()
        XCTAssertFalse(media.isVisualizerTimerRunning, "Visualizer timer must NOT run when UI is not visible even if music is playing")
        
        // Morph opens music view (isVisualizerActive == true)
        media.isVisualizerActive = true
        media.syncVisualizerTimer()
        XCTAssertTrue(media.isVisualizerTimerRunning, "Visualizer timer MUST run when visualizer is active, playing, and unmuted")
        
        // User pauses music
        media.isPlaying = false
        media.syncVisualizerTimer()
        XCTAssertFalse(media.isVisualizerTimerRunning, "Visualizer timer must stop immediately when playback pauses")
        
        // User plays music again, but mutes
        media.isPlaying = true
        media.isMuted = true
        media.syncVisualizerTimer()
        XCTAssertFalse(media.isVisualizerTimerRunning, "Visualizer timer must stop immediately when muted")
        
        // Unmute
        media.isMuted = false
        media.syncVisualizerTimer()
        XCTAssertTrue(media.isVisualizerTimerRunning, "Visualizer timer must resume when unmuted and active")
        
        // Morph collapses
        media.isVisualizerActive = false
        media.syncVisualizerTimer()
        XCTAssertFalse(media.isVisualizerTimerRunning, "Visualizer timer must stop immediately when Morph collapses")
    }
    
    // MARK: - 2. NotchModel Synchronizes Visualizer Activity with Island UI
    func testNotchModelSyncsVisualizerActiveWithUIState() {
        let media = MediaControllerModel()
        let notch = NotchModel(media: media)
        
        // Collapsed state
        notch.isExpanded = false
        notch.selectedTab = .notes
        XCTAssertFalse(media.isVisualizerActive, "Collapsed island must keep visualizer inactive")
        
        // Expanded to Notes tab
        notch.isExpanded = true
        notch.selectedTab = .notes
        // Give runloop a tick for Combine publisher
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertFalse(media.isVisualizerActive, "Notes tab must not activate audio visualizer")
        
        // Switch to Music tab
        notch.selectedTab = .music
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertTrue(media.isVisualizerActive, "Music tab in expanded island must activate visualizer")
        
        // Collapse island
        notch.isExpanded = false
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertFalse(media.isVisualizerActive, "Collapsing island must deactivate visualizer")
    }
    
    // MARK: - 3. Form Input Auto Tracker Fast-Exit When Inactive
    func testFormTrackerEventTapFastExitWhenInactive() {
        let formModel = ApplicationFormModel()
        let tracker = FormInputAutoTracker(model: formModel)
        
        // Default state: no form active
        XCTAssertFalse(tracker.isFormActive, "Form active flag must be false when no form is detected")
        XCTAssertNil(tracker.axSyncTimer, "AX sync timer must not run in the background when no form is active")
        XCTAssertNil(tracker.fullScanTimer, "Full scan timer must not run in the background when no form is active")
        
        // Start tracker
        tracker.start()
        
        // When form is detected
        formModel.isFormDetected = true
        formModel.isAutoCaptureEnabled = true
        tracker.updateAXSyncState()
        XCTAssertTrue(tracker.isFormActive, "isFormActive must be true when a form is detected")
        XCTAssertNotNil(tracker.axSyncTimer, "AX sync timer should start when form is detected")
        XCTAssertNotNil(tracker.fullScanTimer, "Full scan timer should start when form is detected")
        
        // Reset when form closes
        formModel.isFormDetected = false
        tracker.updateAXSyncState()
        XCTAssertFalse(tracker.isFormActive, "isFormActive must return to false when form closes")
        XCTAssertNil(tracker.axSyncTimer, "AX sync timer must stop immediately when form closes")
        XCTAssertNil(tracker.fullScanTimer, "Full scan timer must stop immediately when form closes")
        
        tracker.stop()
    }
    
    // MARK: - 4. Shortcut Manager Standard Keystroke Fast-Path Bypass
    func testShortcutManagerNormalKeystrokeFastBypass() {
        let media = MediaControllerModel()
        let notch = NotchModel(media: media)
        let shortcutManager = ShortcutManager.shared
        shortcutManager.configure(model: notch, controller: nil)
        
        // Regular typing keys: 'A' (0), 'S' (1), Space (49), Return (36)
        let standardKeys: [CGKeyCode] = [0, 1, 2, 49, 36, 12, 13]
        for keyCode in standardKeys {
            if let cgEvent = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
                let dummyProxy = unsafeBitCast(shortcutManager, to: CGEventTapProxy.self)
                let result = shortcutManager.handleBackgroundTapEvent(proxy: dummyProxy, type: .keyDown, event: cgEvent)
                // Fast-path MUST pass through the event unmodified (non-nil result)
                XCTAssertNotNil(result, "Standard typing key \(keyCode) must pass through immediately without being swallowed or delayed")
            }
        }
    }
    
    // MARK: - 5. Glass Island Countdown Timer Frequency
    func testGlassTimerIntervalEfficiency() {
        let notch = NotchModel()
        
        XCTAssertFalse(notch.isGlassTimerRunning, "Timer should not be running initially")
        
        notch.startGlassTimer()
        XCTAssertTrue(notch.isGlassTimerRunning, "Timer should be running after startGlassTimer")
        
        if let timer = notch.glassTimerTimer {
            XCTAssertEqual(timer.timeInterval, 1.0, accuracy: 0.01, "Timer interval should be 1.0 second to eliminate unnecessary CPU wakeups")
        }
        
        notch.pauseGlassTimer()
        XCTAssertFalse(notch.isGlassTimerRunning, "Timer must be cleaned up when paused")
        
        notch.resetGlassTimer()
        XCTAssertFalse(notch.isGlassTimerRunning, "Timer must stay cleaned up when reset")
    }
}
