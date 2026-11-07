import XCTest
@testable import morph

@MainActor
final class TopBarFeaturesAndContextAwareTests: XCTestCase {
    
    override func setUp() async throws {
        // Clear UserDefaults keys before test
        UserDefaults.standard.removeObject(forKey: "com.morph.top_bar_slot_mode")
        UserDefaults.standard.removeObject(forKey: "com.morph.pinned_feature_slots")
        UserDefaults.standard.removeObject(forKey: "com.morph.feature_usage_counts")
        UserDefaults.standard.removeObject(forKey: "com.morph.drop_context_aware_enabled")
        UserDefaults.standard.removeObject(forKey: "com.morph.form_context_aware_enabled")
    }
    
    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "com.morph.top_bar_slot_mode")
        UserDefaults.standard.removeObject(forKey: "com.morph.pinned_feature_slots")
        UserDefaults.standard.removeObject(forKey: "com.morph.feature_usage_counts")
        UserDefaults.standard.removeObject(forKey: "com.morph.drop_context_aware_enabled")
        UserDefaults.standard.removeObject(forKey: "com.morph.form_context_aware_enabled")
    }
    
    func testTopBarFeaturesStrictlyCappedAtThree() {
        let model = NotchModel()
        
        // Ensure all features are enabled
        model.enabledFeatures = Set(MorphGlassFeature.allCases)
        
        // Auto mode
        model.setTopBarSlotMode(.auto)
        XCTAssertLessThanOrEqual(model.topBarFeatures.count, 3)
        XCTAssertEqual(model.topBarFeatures.count, 3)
        
        // activeOrTopBarFeatures should also never exceed 3
        XCTAssertLessThanOrEqual(model.activeOrTopBarFeatures.count, 3)
        XCTAssertEqual(model.activeOrTopBarFeatures.count, 3)
    }
    
    func testTopBarFeaturesRankingByUsageFrequency() {
        let model = NotchModel()
        model.enabledFeatures = Set(MorphGlassFeature.allCases)
        model.setTopBarSlotMode(.auto)
        
        // Default baselines: timer: 42, calendar: 28, music: 19, notes: 12, drops: 8, forms: 5
        let initialTop = model.topBarFeatures
        XCTAssertEqual(initialTop, [.timer, .calendar, .music])
        
        // Increase notes usage past music (e.g. up to 35 uses)
        for _ in 0..<25 {
            model.recordFeatureUsage(.notes)
        }
        XCTAssertGreaterThan(model.featureUsageCount(for: .notes), model.featureUsageCount(for: .music))
        
        // Notes should now be promoted into the top 3, displacing music
        let updatedTop = model.topBarFeatures
        XCTAssertEqual(updatedTop.count, 3)
        XCTAssertTrue(updatedTop.contains(.notes))
        XCTAssertFalse(updatedTop.contains(.music))
        XCTAssertEqual(updatedTop[0], .timer)
        XCTAssertEqual(updatedTop[1], .notes)
        XCTAssertEqual(updatedTop[2], .calendar)
    }
    
    func testCustomPinnedFeaturesMode() {
        let model = NotchModel()
        model.enabledFeatures = Set(MorphGlassFeature.allCases)
        
        model.setTopBarSlotMode(.customPinned)
        model.setPinnedFeatureSlots([.notes, .drops, .forms])
        
        XCTAssertEqual(model.topBarSlotMode, .customPinned)
        XCTAssertEqual(model.topBarFeatures, [.notes, .drops, .forms])
        
        // Toggle pinned feature slot: removing one and adding another
        model.togglePinnedFeatureSlot(.notes) // removes notes
        XCTAssertFalse(model.pinnedFeatureSlots.contains(.notes))
        
        model.togglePinnedFeatureSlot(.calendar) // adds calendar
        XCTAssertTrue(model.pinnedFeatureSlots.contains(.calendar))
        XCTAssertLessThanOrEqual(model.topBarFeatures.count, 3)
    }
    
    func testActiveOrTopBarFeaturesSurfacesActiveFeature() {
        let model = NotchModel()
        model.enabledFeatures = Set(MorphGlassFeature.allCases)
        model.setTopBarSlotMode(.auto)
        
        // Top 3 are [.timer, .calendar, .music]
        XCTAssertFalse(model.topBarFeatures.contains(.drops))
        
        // User opens drop shelf (e.g. via drag or context)
        model.setGlassIslandState(.drops)
        
        // activeOrTopBarFeatures should temporarily surface .drops in slot 3
        let activeBar = model.activeOrTopBarFeatures
        XCTAssertEqual(activeBar.count, 3)
        XCTAssertTrue(activeBar.contains(.drops))
        XCTAssertEqual(activeBar[2], .drops)
    }
    
    func testContextAwareDropShelfWorksWhenNotOnBar() {
        let model = NotchModel()
        model.enabledFeatures = Set(MorphGlassFeature.allCases)
        model.setTopBarSlotMode(.auto)
        
        // Drops is not in topBarFeatures
        XCTAssertFalse(model.topBarFeatures.contains(.drops))
        XCTAssertTrue(model.isDropContextAwareEnabled)
        
        // When user drags file over notch, drop shelf activates
        model.dropShelf.isDraggingOverNotch = true
        XCTAssertTrue(model.isBackgroundDropActive)
        
        // When context-aware drop is disabled, it does not activate
        model.setDropContextAwareEnabled(false)
        XCTAssertFalse(model.isDropContextAwareEnabled)
        XCTAssertFalse(model.isBackgroundDropActive)
    }
    
    func testContextAwareFormDetectionWorksWhenNotOnBar() {
        let model = NotchModel()
        model.enabledFeatures = Set(MorphGlassFeature.allCases)
        model.setTopBarSlotMode(.auto)
        
        // Forms is not in topBarFeatures
        XCTAssertFalse(model.topBarFeatures.contains(.forms))
        XCTAssertTrue(model.isFormContextAwareEnabled)
        
        // Simulate form detection
        model.formTracker.isFormDetected = true
        XCTAssertTrue(model.isBackgroundFormActive)
        
        // When context-aware form detection is disabled, it does not activate
        model.setFormContextAwareEnabled(false)
        XCTAssertFalse(model.isFormContextAwareEnabled)
        XCTAssertFalse(model.isBackgroundFormActive)
    }
    
    func testResetFeatureUsageStats() {
        let model = NotchModel()
        for _ in 0..<100 {
            model.recordFeatureUsage(.forms)
        }
        XCTAssertGreaterThan(model.featureUsageCount(for: .forms), 100)
        
        model.resetFeatureUsageStats()
        XCTAssertEqual(model.featureUsageCount(for: .forms), NotchModel.defaultFeatureUsageBaselines[.forms])
        XCTAssertEqual(model.featureUsageCount(for: .timer), NotchModel.defaultFeatureUsageBaselines[.timer])
    }
    
    func testAllFeaturesHaveDistinctDefaultColors() {
        let colors = MorphGlassFeature.allCases.map { $0.tintColorHex.lowercased() }
        let uniqueColors = Set(colors)
        
        // Every single feature must have a unique default color
        XCTAssertEqual(uniqueColors.count, MorphGlassFeature.allCases.count, "Each feature must have its own distinct default color without collision")
        
        // Drops must not collide with Calendar
        XCTAssertNotEqual(MorphGlassFeature.drops.tintColorHex.lowercased(), MorphGlassFeature.calendar.tintColorHex.lowercased())
    }
}
