import XCTest
import AppKit
@testable import morph

@MainActor
final class YTMProfileAndUniversalF8Tests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    func testInitialProfileIsFirstGmailAccount() {
        let manager = YTMProfileManager()
        manager.loadProfiles()
        
        let initialProfile = manager.profiles.first
        XCTAssertNotNil(initialProfile, "Initial profile should be created")
        XCTAssertFalse(initialProfile?.email.isEmpty ?? true, "Initial profile email must not be empty")
        XCTAssertTrue(initialProfile?.isDefault ?? false, "Initial profile should be default")
    }
    
    func testChromeProfilesDetection() {
        let detected = YTMProfileManager.shared.detectAvailableBrowserProfiles()
        print("Detected Chrome profiles count: \(detected.count)")
        for profile in detected {
            XCTAssertFalse(profile.email.isEmpty, "Detected profile must have email")
            XCTAssertFalse(profile.name.isEmpty, "Detected profile must have name")
        }
    }
    
    func testAddNewProfileAndSwitchBetweenProfiles() {
        let manager = YTMProfileManager()
        let initialCount = manager.profiles.count
        
        let newEmail = "unique_secondary_user@gmail.com"
        let newProfile = manager.addProfile(email: newEmail, displayName: "Cabdi Second")
        
        XCTAssertEqual(manager.profiles.count, initialCount + 1)
        XCTAssertEqual(manager.activeProfileId, newProfile.id)
        XCTAssertEqual(manager.activeProfile?.email, newEmail)
        
        if let firstProfile = manager.profiles.first {
            manager.switchProfile(to: firstProfile.id)
            XCTAssertEqual(manager.activeProfileId, firstProfile.id)
        }
        
        // Clean up
        manager.removeProfile(id: newProfile.id)
    }
    
    func testHandleDetectedEmailUpdatesProfile() {
        let manager = YTMProfileManager()
        let detectedEmail = "test_detected_user@gmail.com"
        
        manager.handleDetectedEmail(detectedEmail, avatarURL: "https://example.com/avatar.png", displayName: "Detected User")
        
        XCTAssertEqual(manager.activeProfile?.email, detectedEmail)
        XCTAssertEqual(manager.activeProfile?.displayName, "Detected User")
        XCTAssertEqual(manager.activeProfile?.avatarURL, "https://example.com/avatar.png")
    }
    
    func testMediaControllerModelProfileIntegration() {
        let media = MediaControllerModel()
        XCTAssertNotNil(media.activeProfile, "Media model must have an active profile")
        XCTAssertFalse(media.profiles.isEmpty, "Media model must expose profiles")
        
        let initialActiveId = media.activeProfile?.id
        let newProfile = YTMProfile(
            email: "switch_test@gmail.com",
            displayName: "Switch Test",
            avatarLocalPath: nil,
            avatarURL: nil
        )
        media.profiles.append(newProfile)
        media.switchProfile(to: newProfile)
        
        XCTAssertEqual(media.activeProfile?.email, "switch_test@gmail.com")
        XCTAssertEqual(media.userEmail, "switch_test@gmail.com")
        
        if let prevId = initialActiveId, let prev = media.profiles.first(where: { $0.id == prevId }) {
            media.switchProfile(to: prev)
        }
    }
    
    func testUniversalBrowserToggleJSContainsMoviePlayerAndHTML5Video() {
        let js = UniversalMediaController.universalBrowserToggleJS
        XCTAssertTrue(js.contains("movie_player"), "Universal JS must check movie_player for YouTube tabs")
        XCTAssertTrue(js.contains("playVideo"), "Universal JS must toggle playVideo")
        XCTAssertTrue(js.contains("pauseVideo"), "Universal JS must toggle pauseVideo")
        XCTAssertTrue(js.contains("video, audio"), "Universal JS must check standard HTML5 videos")
    }
    
    func testUniversalTogglePlaybackWhenMorphIsPlaying() {
        let model = NotchModel()
        model.media.isPlaying = true
        
        var completed = false
        UniversalMediaController.shared.toggleUniversalPlayback(for: model) { handledByBrowser in
            XCTAssertFalse(handledByBrowser, "When Morph is playing, it should not be handled by browser; Morph itself should pause")
            completed = true
        }
        XCTAssertTrue(completed)
    }
    
    func testYouTubeMusicIndependentEmailDoesNotAffectSupabaseUser() {
        let supabase = SupabaseService.shared
        let originalSupabaseEmail = supabase.currentUser.email
        
        let ytmManager = YTMProfileManager.shared
        let ytmActiveEmail = ytmManager.activeProfile?.email
        
        ytmManager.handleDetectedEmail("another_independent_email@gmail.com", avatarURL: nil, displayName: "Independent")
        
        XCTAssertEqual(supabase.currentUser.email, originalSupabaseEmail, "YouTube Music email must NOT change or pollute Supabase Morph account email")
        
        if let originalYTM = ytmActiveEmail, let profile = ytmManager.profiles.first(where: { $0.email == originalYTM }) {
            ytmManager.switchProfile(to: profile.id)
        }
    }
    
    func testClosureMenuItemTriggerAndCheckedState() {
        var triggered = false
        let item = ClosureMenuItem(title: "Test Item", isChecked: true) {
            triggered = true
        }
        XCTAssertEqual(item.title, "Test Item")
        XCTAssertEqual(item.state, .on)
        
        _ = item.target?.perform(item.action)
        XCTAssertTrue(triggered)
    }
    
    func testNSImageCircularThumbnailGeneration() {
        let size = NSSize(width: 64, height: 64)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        img.unlockFocus()
        
        let thumb = img.circularThumbnail(size: 16)
        XCTAssertEqual(thumb.size.width, 16)
        XCTAssertEqual(thumb.size.height, 16)
    }
}
