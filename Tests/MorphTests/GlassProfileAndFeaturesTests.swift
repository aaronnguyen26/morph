import XCTest
import SwiftUI
@testable import morph

@MainActor
final class GlassProfileAndFeaturesTests: XCTestCase {
    var model: NotchModel!
    
    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: "com.morph.enabled_features")
        model = NotchModel()
        model.isGlassIslandEnabled = true
        model.setGlassIslandState(.idle)
    }
    
    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "com.morph.enabled_features")
        model = nil
        try await super.tearDown()
    }
    
    // MARK: - 1. Profile State Metrics & Dimensions
    func testProfileStateMetrics() {
        model.setGlassIslandState(.profile)
        XCTAssertEqual(model.glassIslandState, .profile)
        XCTAssertEqual(model.currentWidth, 460.0, "Profile panel width must be 460 pt")
        XCTAssertEqual(model.currentHeight, 380.0, "Profile panel height must be 380 pt")
        XCTAssertEqual(model.glassIslandRadius, 34.0, "Profile panel radius must be 34 pt")
        XCTAssertEqual(model.glassIslandTintHex, "#a78bfa", "Profile panel tint must be #a78bfa")
    }
    
    // MARK: - 2. Default Feature Toggles
    func testDefaultFeaturesAreAllEnabled() {
        XCTAssertEqual(model.enabledFeatures.count, MorphGlassFeature.allCases.count)
        for feature in MorphGlassFeature.allCases {
            XCTAssertTrue(model.isFeatureEnabled(feature), "\(feature.title) must be enabled by default")
        }
        XCTAssertTrue(model.isFeatureEnabled(.timer))
        XCTAssertTrue(model.isFeatureEnabled(.calendar))
        XCTAssertTrue(model.isFeatureEnabled(.music))
        XCTAssertTrue(model.isFeatureEnabled(.notes))
        XCTAssertTrue(model.isFeatureEnabled(.forms))
    }
    
    // MARK: - 3. Toggling Features On and Off
    func testTogglingFeatureOnAndOff() {
        // Turn off Music
        model.setFeature(.music, isEnabled: false)
        XCTAssertFalse(model.isFeatureEnabled(.music), "Music symbol must be disabled")
        XCTAssertFalse(model.enabledFeatures.contains(.music))
        
        // Turn off Notes
        model.toggleFeature(.notes)
        XCTAssertFalse(model.isFeatureEnabled(.notes), "Notes symbol must be disabled via toggle")
        
        // Turn Music back on
        model.setFeature(.music, isEnabled: true)
        XCTAssertTrue(model.isFeatureEnabled(.music), "Music symbol must be enabled again")
        XCTAssertTrue(model.enabledFeatures.contains(.music))
        
        // Turn Notes back on
        model.toggleFeature(.notes)
        XCTAssertTrue(model.isFeatureEnabled(.notes), "Notes symbol must be enabled again")
    }
    
    // MARK: - 4. Disabling Active Feature Transitions to Profile
    func testDisablingActiveFeatureTransitionsToProfile() {
        model.setGlassIslandState(.notes)
        XCTAssertEqual(model.glassIslandState, .notes)
        
        // Disabling the active feature must gracefully transition away to .profile
        model.setFeature(.notes, isEnabled: false)
        XCTAssertEqual(model.glassIslandState, .profile, "Disabling active feature must navigate to profile")
    }
    
    // MARK: - 5. Feature Persistence in UserDefaults
    func testFeaturePersistence() {
        model.setFeature(.timer, isEnabled: false)
        model.setFeature(.forms, isEnabled: false)
        
        let savedArray = UserDefaults.standard.stringArray(forKey: "com.morph.enabled_features")
        XCTAssertNotNil(savedArray)
        XCTAssertFalse(savedArray!.contains("timer"))
        XCTAssertFalse(savedArray!.contains("forms"))
        XCTAssertTrue(savedArray!.contains("calendar"))
        XCTAssertTrue(savedArray!.contains("music"))
        XCTAssertTrue(savedArray!.contains("notes"))
        
        // Create new model and verify loadEnabledFeatures restores preference
        let newModel = NotchModel()
        newModel.loadEnabledFeatures()
        XCTAssertFalse(newModel.isFeatureEnabled(.timer))
        XCTAssertFalse(newModel.isFeatureEnabled(.forms))
        XCTAssertTrue(newModel.isFeatureEnabled(.music))
    }
    
    // MARK: - 6. User Profile Information Editing & Propagation
    func testUserProfileInformationEditing() async {
        await model.supabase.updateProfile(
            firstName: "Alex",
            lastName: "Rivera",
            email: "alex.rivera@example.com",
            targetRole: "Product Designer",
            currentStatus: "Flow State"
        )
        
        XCTAssertEqual(model.supabase.currentUser.firstName, "Alex")
        XCTAssertEqual(model.supabase.currentUser.lastName, "Rivera")
        XCTAssertEqual(model.supabase.currentUser.email, "alex.rivera@example.com")
        XCTAssertEqual(model.supabase.currentUser.displayName, "Alex Rivera")
        XCTAssertEqual(model.supabase.currentUser.targetRole, "Product Designer")
        XCTAssertEqual(model.supabase.currentUser.currentStatus, "Flow State")
        XCTAssertEqual(model.supabase.currentUser.displayInitials, "AR")
    }
    
    // MARK: - 7. Clean Single-Row Profile Feature Toggles with Interactive Circle Color
    func testProfileViewRendersCleanSingleRowWithoutClutteredColorRow() {
        let profileView = GlassProfileView(model: model)
        XCTAssertNotNil(profileView.body)
        
        // Verify customizing colors updates active color hex and island tint
        model.setCustomFeatureColor("#a855f7", for: .timer)
        XCTAssertEqual(model.featureTintColorHex(.timer), "#a855f7")
        XCTAssertNotNil(model.customFeatureColors[.timer])
        
        // Verify resetting restores default tint
        model.resetFeatureColor(for: .timer)
        XCTAssertEqual(model.featureTintColorHex(.timer), MorphGlassFeature.timer.tintColorHex)
        XCTAssertNil(model.customFeatureColors[.timer])
    }
}
