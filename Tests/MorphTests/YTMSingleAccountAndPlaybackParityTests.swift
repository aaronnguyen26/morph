import XCTest
@testable import morph

@MainActor
final class YTMSingleAccountAndPlaybackParityTests: XCTestCase {
    
    override func setUp() async throws {
        try await super.setUp()
        YTMProfileManager.shared.clearAllProfiles()
        YouTubeMusicEngine.shared.userPlaylists = []
    }
    
    override func tearDown() async throws {
        YTMProfileManager.shared.clearAllProfiles()
        YouTubeMusicEngine.shared.userPlaylists = []
        try await super.tearDown()
    }
    
    // MARK: - 1. Strict Single-Account Isolation Tests
    func testSingleAccountIsolationAndNoPhantomAccounts() {
        let manager = YTMProfileManager.shared
        manager.clearAllProfiles()
        
        XCTAssertEqual(manager.profiles.count, 0, "Initial profile count must be 0 without any dummy accounts")
        XCTAssertNil(manager.activeProfileId, "Active profile must be nil when signed out")
        
        // Sign in with first account
        manager.handleDetectedEmail("alice@gmail.com", avatarURL: "https://lh3.googleusercontent.com/alice", displayName: "Alice Smith", accountTier: .premium)
        
        XCTAssertEqual(manager.profiles.count, 1, "Only 1 account must be present in profiles")
        XCTAssertEqual(manager.profiles.first?.email, "alice@gmail.com")
        XCTAssertEqual(manager.profiles.first?.displayName, "Alice Smith")
        XCTAssertEqual(manager.profiles.first?.accountTier, .premium)
        XCTAssertEqual(manager.activeProfile?.email, "alice@gmail.com")
        
        // Sign in with another account: replaces rather than appends, ensuring single account guarantee
        manager.handleDetectedEmail("bob@gmail.com", avatarURL: "https://lh3.googleusercontent.com/bob", displayName: "Bob Jones", accountTier: .basic)
        
        XCTAssertEqual(manager.profiles.count, 1, "Morph must strictly keep only 1 account, never accumulating multiple Gmails")
        XCTAssertEqual(manager.profiles.first?.email, "bob@gmail.com")
        XCTAssertEqual(manager.profiles.first?.displayName, "Bob Jones")
        XCTAssertEqual(manager.activeProfile?.email, "bob@gmail.com")
        
        // Clear on sign out
        manager.clearAllProfiles()
        XCTAssertEqual(manager.profiles.count, 0, "After sign out, profiles must be completely empty")
        XCTAssertNil(manager.activeProfile)
    }
    
    // MARK: - 2. Progress Bar Resets to 0:00 on Track Change
    func testTrackSwitchResetsProgressToZero() {
        let model = NotchModel()
        model.media.duration = 210
        model.media.currentTime = 45.0
        model.glassTrackCurrentSeconds = 45
        
        XCTAssertEqual(model.formattedGlassTrackCurrentTime, "0:45")
        
        // Skip or next song
        model.skipGlassMusic(1)
        
        XCTAssertEqual(model.glassTrackCurrentSeconds, 0, "glassTrackCurrentSeconds must reset to 0 immediately")
        XCTAssertEqual(model.media.currentTime, 0.0, "media.currentTime must reset to 0.0 immediately")
        XCTAssertEqual(model.formattedGlassTrackCurrentTime, "0:00", "Current time display must return to 0:00 on next song")
    }
    
    // MARK: - 3. Progress Bar Tracking Starts Hand-in-Hand With Playback
    func testPlaybackTickerAdvancesEvenWithInitialZeroDuration() {
        let media = MediaControllerModel()
        media.isPlaying = true
        media.userIntentionallyPaused = false
        media.currentTime = 0.0
        media.duration = 0.0 // Duration not yet received from WebKit
        
        // Simulate startExactTrack
        let track = YTMPlaylistItem(id: "trk1", title: "Housewife", artist: "Tate McRae", duration: "")
        media.startExactTrack(track)
        
        // startExactTrack guarantees a non-zero fallback duration (180s) so ratio doesn't divide by zero
        XCTAssertGreaterThan(media.duration, 0, "Track duration must be greater than zero so progress bar can scrub and track")
        XCTAssertEqual(media.currentTime, 0.0, "New track starts at 0:00")
        XCTAssertTrue(media.isPlaying)
    }
    
    // MARK: - 4. Direct Engine Library Ground Truth Parity
    func testDirectEnginePlaylistsBecomeGroundTruthWhenSignedIn() async {
        let media = MediaControllerModel()
        media.isSignedIn = true
        
        let realPlaylists = [
            YTMPlaylist(id: "PL_real1", title: "My Favorites 2026", subtitle: "25 tracks", thumbnailURL: nil),
            YTMPlaylist(id: "LM", title: "Liked Music", subtitle: "Auto playlist", thumbnailURL: nil)
        ]
        YouTubeMusicEngine.shared.userPlaylists = realPlaylists
        
        // Refresh library playlists
        media.refreshPlaylists()
        
        // Yield to allow Task @MainActor to execute
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertEqual(media.playlists.count, 2, "MediaControllerModel must adopt the direct engine's authenticated playlists")
        XCTAssertTrue(media.playlists.contains(where: { $0.id == "PL_real1" }))
        XCTAssertTrue(media.playlists.contains(where: { $0.id == "LM" }))
    }
    
    // MARK: - 5. Direct In-Morph UI Sign-In & Single Page Verification
    func testUnauthenticatedMusicPlayerHasSingleUnnamedView() {
        let model = NotchModel()
        model.media.signOut()
        model.setGlassIslandState(.music)
        
        XCTAssertFalse(model.media.isSignedIn, "User must start in unauthenticated state")
        XCTAssertFalse(model.media.isInlineSignInActive, "Inline sign in must not be active before user clicks button")
        XCTAssertEqual(model.glassIslandHeight, 384, "Music island height in resting unauthenticated mode must be 384 pt")
    }
    
    func testClickingSignInWithGoogleActivatesInlineSignInDirectlyInMorphUI() {
        let model = NotchModel()
        model.media.signOut()
        model.setGlassIslandState(.music)
        
        // User clicks "Sign In with Google"
        model.media.openSignIn()
        
        XCTAssertTrue(model.media.isInlineSignInActive, "Clicking Sign In with Google must activate inline sign-in mode")
        XCTAssertFalse(YouTubeMusicEngine.shared.isPlayerWindowVisible, "Morph must NOT create or show any separate external window")
        XCTAssertEqual(model.glassIslandHeight, 480, "Glass island height must dynamically expand to 480 pt to host Google Sign-In directly inside Morph UI")
    }
    
    func testCancelingInlineSignInReturnsToStandardHeightAndSinglePage() {
        let model = NotchModel()
        model.media.signOut()
        model.setGlassIslandState(.music)
        
        model.media.openSignIn()
        XCTAssertTrue(model.media.isInlineSignInActive)
        XCTAssertEqual(model.glassIslandHeight, 480)
        
        // User clicks cancel ('X') button on the inline nav bar
        model.media.isInlineSignInActive = false
        XCTAssertFalse(model.media.isInlineSignInActive)
        XCTAssertEqual(model.glassIslandHeight, 384, "Canceling inline sign-in must smoothly restore the panel height to 384 pt")
    }
    
    func testSuccessfulSignInTransitionsFromInlineToAuthenticatedState() async {
        let model = NotchModel()
        model.media.signOut()
        model.setGlassIslandState(.music)
        
        model.media.openSignIn()
        XCTAssertTrue(model.media.isInlineSignInActive)
        
        // Simulate auth completion from engine
        YouTubeMusicEngine.shared.isSignedIn = true
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertTrue(model.media.isSignedIn, "Media model must update to signed in")
        XCTAssertFalse(model.media.isInlineSignInActive, "Inline sign in flag must reset upon successful auth")
        XCTAssertEqual(model.glassIslandHeight, 384, "Island height returns to 384 pt for standard music player with tabs")
    }
}
