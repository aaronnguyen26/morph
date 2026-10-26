import XCTest
@testable import morph

@MainActor
final class SystemAudioVolumeTests: XCTestCase {
    
    func testInitialVolumeCorrelatesWithSystemAudio() {
        let mockAudio = MockSystemAudioService(initialVolume: 0.65, initialMuted: false)
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        XCTAssertEqual(media.volume, 0.65, accuracy: 0.001, "Initial volume must correlate with laptop system audio")
        XCTAssertFalse(media.isMuted, "Initial mute state must correlate with laptop system audio")
    }
    
    func testInitialMuteCorrelatesWithSystemAudio() {
        let mockAudio = MockSystemAudioService(initialVolume: 0.35, initialMuted: true)
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        XCTAssertEqual(media.volume, 0.35, accuracy: 0.001)
        XCTAssertTrue(media.isMuted, "Muted state must correlate on launch")
    }
    
    func testLaptopVolumeIncreaseAutoCorrectsYouTubeMusicAndAppUI() {
        let mockAudio = MockSystemAudioService(initialVolume: 0.30, initialMuted: false)
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        XCTAssertEqual(media.volume, 0.30, accuracy: 0.001)
        
        // Simulate user increasing volume on laptop hardware (e.g. keyboard F12 or Control Center)
        mockAudio.simulateLaptopVolumeChange(to: 0.85)
        
        XCTAssertEqual(media.volume, 0.85, accuracy: 0.001, "Morph volume must auto-correct when laptop volume increases")
        XCTAssertTrue(media.showVolumeHUD, "Morph Notch volume HUD must trigger when laptop volume changes")
    }
    
    func testLaptopVolumeDecreaseAutoCorrectsYouTubeMusicAndAppUI() {
        let mockAudio = MockSystemAudioService(initialVolume: 0.90, initialMuted: false)
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        XCTAssertEqual(media.volume, 0.90, accuracy: 0.001)
        
        // Simulate user decreasing volume on laptop hardware (e.g. keyboard F11)
        mockAudio.simulateLaptopVolumeChange(to: 0.15)
        
        XCTAssertEqual(media.volume, 0.15, accuracy: 0.001, "Morph volume must auto-correct when laptop volume decreases")
        XCTAssertTrue(media.showVolumeHUD, "Morph Notch volume HUD must trigger when laptop volume decreases")
    }
    
    func testLaptopMuteAndUnmuteAutoCorrectsYouTubeMusic() {
        let mockAudio = MockSystemAudioService(initialVolume: 0.50, initialMuted: false)
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        // Simulate user pressing Mute on laptop
        mockAudio.simulateLaptopMuteChange(to: true)
        XCTAssertTrue(media.isMuted, "MediaControllerModel must auto-correct to muted when laptop is muted")
        XCTAssertTrue(media.showVolumeHUD, "HUD must trigger on mute")
        
        // Simulate user pressing Unmute on laptop
        mockAudio.simulateLaptopMuteChange(to: false)
        XCTAssertFalse(media.isMuted, "MediaControllerModel must auto-correct to unmuted when laptop is unmuted")
        XCTAssertEqual(media.volume, 0.50, accuracy: 0.001, "Volume level must be preserved upon unmuting")
    }
    
    func testInAppVolumeAdjustmentUpdatesLaptopSystemAudio() {
        let mockAudio = MockSystemAudioService(initialVolume: 0.40, initialMuted: false)
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        // User adjusts volume slider in Morph
        media.setVolume(0.72)
        
        XCTAssertEqual(media.volume, 0.72, accuracy: 0.001)
        XCTAssertTrue(mockAudio.setSystemVolumeCalls.contains(where: { abs($0 - 0.72) < 0.001 }), "Adjusting in-app volume must update laptop system audio")
        XCTAssertEqual(mockAudio.volume, 0.72, accuracy: 0.001)
        XCTAssertTrue(media.showVolumeHUD)
    }
    
    func testInAppToggleMuteUpdatesLaptopSystemAudio() {
        let mockAudio = MockSystemAudioService(initialVolume: 0.50, initialMuted: false)
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        // User toggles mute in Morph
        media.toggleMute()
        XCTAssertTrue(media.isMuted)
        XCTAssertTrue(mockAudio.setMutedCalls.contains(true), "Toggling mute in Morph must update laptop system mute")
        
        // User toggles unmute in Morph
        media.toggleMute()
        XCTAssertFalse(media.isMuted)
        XCTAssertTrue(mockAudio.setMutedCalls.contains(false), "Toggling unmute in Morph must update laptop system mute")
    }
    
    func testYouTubeMusicWebPlayerVolumeDriftIsAutoCorrected() {
        let mockAudio = MockSystemAudioService(initialVolume: 0.55, initialMuted: false)
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        XCTAssertEqual(media.volume, 0.55, accuracy: 0.001)
        
        // Web player reports track data where internal web player volume is 1.0 (drift)
        let driftedTrackData = YTMTrackData(
            title: "Test Track",
            artist: "Test Artist",
            albumArtURL: nil,
            isPlaying: true,
            currentTime: 10,
            duration: 180,
            volume: 1.0, // Web player internal default
            isMuted: false
        )
        
        // Simulate engine sending track data
        engine.trackData = driftedTrackData
        
        // The authoritative app volume must remain correlated to the laptop (0.55), not overwritten by 1.0
        XCTAssertEqual(media.volume, 0.55, accuracy: 0.001, "Media volume must not be overwritten by drifted web player volume")
    }
    
    func testVolumeClampingBounds() {
        let mockAudio = MockSystemAudioService(initialVolume: 0.50, initialMuted: false)
        let engine = YouTubeMusicEngine()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio)
        
        media.setVolume(1.8)
        XCTAssertEqual(media.volume, 1.0, "Volume must clamp to 1.0 maximum")
        
        media.setVolume(-0.4)
        XCTAssertEqual(media.volume, 0.0, "Volume must clamp to 0.0 minimum")
        
        mockAudio.simulateLaptopVolumeChange(to: 3.5)
        XCTAssertEqual(media.volume, 1.0, "Laptop volume changes must clamp to 1.0")
        
        mockAudio.simulateLaptopVolumeChange(to: -2.0)
        XCTAssertEqual(media.volume, 0.0, "Laptop volume changes must clamp to 0.0")
    }
    
    func testSystemAudioServiceRealHardwareAccessors() {
        // Test real CoreAudio queries on developer machine
        let realService = SystemAudioService(isTestMode: false)
        let vol = realService.getVolume()
        let muted = realService.getMuted()
        
        XCTAssertGreaterThanOrEqual(vol, 0.0)
        XCTAssertLessThanOrEqual(vol, 1.0)
        XCTAssertTrue(muted == true || muted == false)
    }
}
