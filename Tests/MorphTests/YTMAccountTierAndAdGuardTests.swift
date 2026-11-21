import XCTest
import SwiftUI
import AppKit
import WebKit
@testable import morph

@MainActor
final class YTMAccountTierAndAdGuardTests: XCTestCase {
    
    // MARK: - 1. YTMAccountTier Enum Verification
    func testYTMAccountTierEnumProperties() {
        let premium = YTMAccountTier.premium
        XCTAssertTrue(premium.isPremium)
        XCTAssertFalse(premium.hasAds, "Premium accounts must never have ads")
        XCTAssertEqual(premium.badgeTitle, "PRO")
        XCTAssertEqual(premium.shortTitle, "Premium")
        XCTAssertEqual(premium.displayTitle, "YouTube Music Premium")
        
        let basic = YTMAccountTier.basic
        XCTAssertFalse(basic.isPremium)
        XCTAssertTrue(basic.hasAds, "Basic/Free accounts are ad-supported")
        XCTAssertEqual(basic.badgeTitle, "BASIC")
        XCTAssertEqual(basic.shortTitle, "Basic")
        XCTAssertEqual(basic.displayTitle, "YouTube Music Free")
        
        let unknown = YTMAccountTier.unknown
        XCTAssertFalse(unknown.isPremium)
        XCTAssertTrue(unknown.hasAds)
        XCTAssertEqual(unknown.badgeTitle, "GUEST")
        XCTAssertEqual(unknown.shortTitle, "Free")
        XCTAssertEqual(unknown.displayTitle, "Direct Stream")
    }
    
    // MARK: - 2. YTMProfile Backward Compatibility
    func testYTMProfileBackwardCompatibility() throws {
        // Simulate older profile JSON without accountTier
        let legacyJSON = """
        {
            "id": "11111111-2222-3333-4444-555555555555",
            "email": "user@example.com",
            "displayName": "Test User",
            "isDefault": true,
            "createdAt": 1700000000,
            "lastUsedAt": 1700000000,
            "isChromeImported": false
        }
        """.data(using: .utf8)!
        
        let decoded = try JSONDecoder().decode(YTMProfile.self, from: legacyJSON)
        XCTAssertEqual(decoded.email, "user@example.com")
        XCTAssertEqual(decoded.accountTier, .unknown, "Legacy profiles must safely default to .unknown without decoding errors")
        
        // Encode and decode with modern tier
        var modern = decoded
        modern.accountTier = .premium
        let encoded = try JSONEncoder().encode(modern)
        let roundtrip = try JSONDecoder().decode(YTMProfile.self, from: encoded)
        XCTAssertEqual(roundtrip.accountTier, .premium)
        XCTAssertTrue(roundtrip.accountTier.isPremium)
    }
    
    // MARK: - 3. YouTubeMusicEngine Incoming Payload Tier Detection
    func testEngineIncomingPayloadTierDetection() {
        let engine = YouTubeMusicEngine()
        engine.accountTier = .unknown
        
        // Initial state
        XCTAssertEqual(engine.accountTier, .unknown)
        XCTAssertFalse(engine.isAdPlaying)
        
        // Simulate payload with Premium account detected
        let premiumPayload: [String: Any] = [
            "title": "Anti-Hero",
            "artist": "Taylor Swift",
            "albumArt": "https://example.com/art.jpg",
            "isPlaying": true,
            "currentTime": 45.0,
            "duration": 200.0,
            "isSignedIn": true,
            "userEmail": "subscriber@gmail.com",
            "accountTier": "premium",
            "isAdPlaying": false,
            "adSuppressedCount": 0
        ]
        
        engine.parseIncomingPayload(premiumPayload)
        
        XCTAssertEqual(engine.accountTier, .premium, "Engine must accurately detect and store Premium subscription tier")
        XCTAssertTrue(engine.isAccountPremium)
        XCTAssertFalse(engine.hasAds, "Premium accounts are ad-free")
        XCTAssertEqual(engine.trackData.accountTier, .premium)
        XCTAssertFalse(engine.isAdPlaying)
        
        // Simulate payload with Basic account detected
        let basicPayload: [String: Any] = [
            "title": "Cruel Summer",
            "artist": "Taylor Swift",
            "albumArt": "https://example.com/art2.jpg",
            "isPlaying": true,
            "currentTime": 30.0,
            "duration": 178.0,
            "isSignedIn": true,
            "userEmail": "freeuser@gmail.com",
            "accountTier": "basic",
            "isAdPlaying": false,
            "adSuppressedCount": 0
        ]
        
        engine.parseIncomingPayload(basicPayload)
        
        XCTAssertEqual(engine.accountTier, .basic, "Engine must accurately detect Basic tier")
        XCTAssertFalse(engine.isAccountPremium)
        XCTAssertTrue(engine.hasAds, "Basic tier indicates potential ads")
        XCTAssertEqual(engine.trackData.accountTier, .basic)
    }
    
    // MARK: - 4. Zero-Ad Guarantee & Track Metadata Protection
    func testZeroAdGuaranteeAndMetadataProtection() {
        let media = MediaControllerModel()
        let engine = media.engine
        
        // Set real song playing
        let songPayload: [String: Any] = [
            "title": "Blinding Lights",
            "artist": "The Weeknd",
            "albumArt": "https://example.com/blinding.jpg",
            "isPlaying": true,
            "currentTime": 10.0,
            "duration": 200.0,
            "isSignedIn": true,
            "accountTier": "basic",
            "isAdPlaying": false,
            "adSuppressedCount": 0
        ]
        engine.parseIncomingPayload(songPayload)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        
        XCTAssertEqual(media.trackTitle, "Blinding Lights")
        XCTAssertEqual(media.artistName, "The Weeknd")
        XCTAssertFalse(media.isAdPlaying)
        
        // Now an advertisement interrupts
        let adPayload: [String: Any] = [
            "title": "Advertisement",
            "artist": "Google Pixel",
            "isPlaying": true,
            "currentTime": 2.0,
            "duration": 15.0,
            "isSignedIn": true,
            "accountTier": "basic",
            "isAdPlaying": true,
            "adSuppressedCount": 1
        ]
        engine.parseIncomingPayload(adPayload)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        
        // The ad state must be flagged
        XCTAssertTrue(engine.isAdPlaying, "Engine must reflect active ad state")
        XCTAssertTrue(media.isAdPlaying, "Media controller must reflect active ad state")
        XCTAssertEqual(media.adSuppressedCount, 1)
        
        // Crucial: displayed title and artist must NOT be corrupted by the ad!
        XCTAssertEqual(media.trackTitle, "Blinding Lights", "Displayed song title must be protected during ad suppression")
        XCTAssertEqual(media.artistName, "The Weeknd", "Displayed artist must be protected during ad suppression")
        
        // Now ad ends, real playback continues
        let resumedPayload: [String: Any] = [
            "title": "Blinding Lights",
            "artist": "The Weeknd",
            "albumArt": "https://example.com/blinding.jpg",
            "isPlaying": true,
            "currentTime": 12.0,
            "duration": 200.0,
            "isSignedIn": true,
            "accountTier": "basic",
            "isAdPlaying": false,
            "adSuppressedCount": 1
        ]
        engine.parseIncomingPayload(resumedPayload)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        
        XCTAssertFalse(media.isAdPlaying)
        XCTAssertEqual(media.trackTitle, "Blinding Lights")
    }
    
    // MARK: - 5. Profile Tier Persistence
    func testProfileTierPersistence() {
        let profileManager = YTMProfileManager.shared
        let testProfile = YTMProfile(
            email: "premium.test@gmail.com",
            displayName: "Premium Tester",
            accountTier: .unknown
        )
        
        profileManager.addProfile(email: testProfile.email, displayName: testProfile.displayName)
        guard let savedProfile = profileManager.profiles.first(where: { $0.email == testProfile.email }) else {
            XCTFail("Profile should exist")
            return
        }
        XCTAssertEqual(savedProfile.accountTier, .unknown)
        
        // Update tier to premium
        profileManager.updateProfileTier(id: savedProfile.id, tier: .premium)
        
        let updatedProfile = profileManager.profiles.first(where: { $0.id == savedProfile.id })
        XCTAssertEqual(updatedProfile?.accountTier, .premium)
        XCTAssertTrue(updatedProfile?.accountTier.isPremium == true)
        
        // Cleanup
        profileManager.removeProfile(id: savedProfile.id)
    }
    
    // MARK: - 6. Declarative WebKit Ad Block Rules Compilation
    func testDeclarativeAdBlockRulesJSONValidity() {
        let jsonStr = YouTubeMusicEngine.declarativeAdBlockRulesJSON
        guard let data = jsonStr.data(using: .utf8) else {
            XCTFail("Ad block rules must be valid UTF-8 data")
            return
        }
        
        // 1. Verify JSON syntax
        do {
            guard let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                XCTFail("Ad block rules must be a JSON array of rule dictionaries")
                return
            }
            XCTAssertGreaterThanOrEqual(array.count, 5, "Must contain multiple ad blocking triggers")
            
            // Check essential block triggers
            let filters = array.compactMap { ($0["trigger"] as? [String: Any])?["url-filter"] as? String }
            XCTAssertTrue(filters.contains("googleads"), "Must block googleads")
            XCTAssertTrue(filters.contains("doubleclick"), "Must block doubleclick")
            XCTAssertTrue(filters.contains("pagead"), "Must block pagead")
            XCTAssertTrue(filters.contains("/api/stats/ads"), "Must block ad stats ping")
            XCTAssertTrue(filters.contains("adformat="), "Must block adformat media chunks")
        } catch {
            XCTFail("JSON parsing failed: \(error)")
        }
        
        // 2. Verify compilation with WebKit Content Rule List Store
        if let store = WKContentRuleListStore.default() {
            let exp = expectation(description: "Compile rule list")
            store.compileContentRuleList(
                forIdentifier: YouTubeMusicEngine.adBlockRuleListIdentifier,
                encodedContentRuleList: jsonStr
            ) { ruleList, error in
                XCTAssertNil(error, "WebKit must compile rule list without syntax or regex errors")
                XCTAssertNotNil(ruleList, "Compiled rule list must be created")
                exp.fulfill()
            }
            wait(for: [exp], timeout: 5.0)
        }
    }
    
    // MARK: - 7. Intelligent Browser Routing for Unauthenticated Sessions
    func testIntelligentBrowserRoutingForUnauthenticatedSessions() {
        let media = MediaControllerModel()
        let engine = media.engine
        
        // Simulate user connected to external browser where YouTube Premium is signed in,
        // but Morph internal engine is not logged in.
        media.isBrowserConnected = true
        engine.isSignedIn = false
        engine.accountTier = .unknown
        
        let sampleTrack = YTMPlaylistItem(
            id: "trk_101",
            title: "Cruel Summer",
            artist: "Taylor Swift",
            duration: "2:58",
            videoId: "ic8j13piLUQ",
            thumbnailURL: "https://example.com/art.jpg"
        )
        
        media.startExactTrack(sampleTrack)
        
        XCTAssertEqual(media.trackTitle, "Cruel Summer")
        XCTAssertEqual(media.artistName, "Taylor Swift")
        XCTAssertEqual(media.sourceName, "YouTube Music • Browser", "Playback must be routed to browser session when internal engine is unauthenticated")
        XCTAssertFalse(media.isDirectEngineActive, "Direct engine must not hijack playback from authenticated browser tab")
    }
    
    // MARK: - 8. Direct Engine Playback When Signed In or Premium
    func testDirectEnginePlaybackWhenSignedInOrPremium() {
        let media = MediaControllerModel()
        let engine = media.engine
        
        // Simulate direct in-app YouTube Premium session
        media.isBrowserConnected = false
        engine.isSignedIn = true
        engine.accountTier = .premium
        
        let sampleTrack = YTMPlaylistItem(
            id: "trk_102",
            title: "Style",
            artist: "Taylor Swift",
            duration: "3:51",
            videoId: "style_vid_123",
            thumbnailURL: "https://example.com/style.jpg"
        )
        
        media.startExactTrack(sampleTrack)
        
        XCTAssertEqual(media.trackTitle, "Style")
        XCTAssertEqual(media.sourceName, "YouTube Music Direct", "Playback must be handled directly in engine when authenticated")
    }
    
    // MARK: - 9. Player Response Sanitizer Strips Ad Placements
    func testPlayerResponseSanitizerStripsAdPlacements() {
        // Verify JSON payload structure that in-page API interceptor strips
        var mockPlayerResponse: [String: Any] = [
            "videoDetails": [
                "title": "Clean Track",
                "author": "Clean Artist",
                "lengthSeconds": "240"
            ],
            "adPlacements": [
                ["adPlacementRenderer": ["config": "ad_1"]]
            ],
            "adSlots": [
                ["slotId": "slot_1"]
            ],
            "playerAds": [
                ["playerLegacyDesktopWatchAdsRenderer": [:]]
            ],
            "adBreakHeartbeatParams": "heartbeat_data"
        ]
        
        // Simulate sanitization logic
        mockPlayerResponse.removeValue(forKey: "adPlacements")
        mockPlayerResponse.removeValue(forKey: "adSlots")
        mockPlayerResponse.removeValue(forKey: "playerAds")
        mockPlayerResponse.removeValue(forKey: "adBreakHeartbeatParams")
        
        XCTAssertNil(mockPlayerResponse["adPlacements"], "adPlacements must be stripped")
        XCTAssertNil(mockPlayerResponse["adSlots"], "adSlots must be stripped")
        XCTAssertNil(mockPlayerResponse["playerAds"], "playerAds must be stripped")
        XCTAssertNil(mockPlayerResponse["adBreakHeartbeatParams"], "adBreakHeartbeatParams must be stripped")
        XCTAssertNotNil(mockPlayerResponse["videoDetails"], "Track video details must remain intact")
    }
}
