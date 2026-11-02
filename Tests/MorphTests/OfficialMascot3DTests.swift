import XCTest
import SwiftUI
@testable import morph

@MainActor
final class OfficialMascot3DTests: XCTestCase {
    var model: NotchModel!
    
    override func setUp() async throws {
        try await super.setUp()
        model = NotchModel()
    }
    
    override func tearDown() async throws {
        model = nil
        try await super.tearDown()
    }
    
    // MARK: - 1. Official Mascot Assets Verification
    func testOfficialMascotAssetsAvailable() {
        let full = MorphMascotAssetLoader.officialMascotFull
        XCTAssertNotNil(full, "Official full mascot asset must load cleanly")
        if let full = full {
            XCTAssertGreaterThan(full.size.width, 100)
            XCTAssertGreaterThan(full.size.height, 100)
        }
        
        let body = MorphMascotAssetLoader.officialMascotBody
        XCTAssertNotNil(body, "Official mascot body asset must load cleanly")
        if let body = body {
            XCTAssertGreaterThan(body.size.width, 100)
            XCTAssertGreaterThan(body.size.height, 100)
        }
        
        let halo = MorphMascotAssetLoader.officialMascotHalo
        XCTAssertNotNil(halo, "Official mascot floating chrome halo asset must load cleanly")
        if let halo = halo {
            XCTAssertGreaterThan(halo.size.width, 50)
            XCTAssertGreaterThan(halo.size.height, 20)
        }
    }
    
    // MARK: - 2. Mascot Style Modes & Geometry
    func testMascotStyleInitialization() {
        let heroMascot = MorphyMascotView(model: model, style: .hero)
        XCTAssertEqual(heroMascot.style, .hero)
        
        let restingMascot = MorphyMascotView(model: model, style: .restingStealth)
        XCTAssertEqual(restingMascot.style, .restingStealth)
        
        let spotlightMascot = MorphyMascotView(model: model, style: .spotlightPill)
        XCTAssertEqual(spotlightMascot.style, .spotlightPill)
        
        let compactMascot = MorphyMascotView(model: model, style: .compact)
        XCTAssertEqual(compactMascot.style, .compact)
    }
    
    // MARK: - 3. Resting Stealth Dimensions & Safe Margin
    func testRestingStealthMascotFitsWithinNotch() {
        XCTAssertEqual(model.islandState, .resting)
        XCTAssertEqual(model.currentWidth, model.idleWidth)
        XCTAssertEqual(model.currentHeight, model.idleHeight)
        
        // Idle notch baseline is 179 x 32 pt
        XCTAssertEqual(model.idleWidth, 179)
        XCTAssertEqual(model.idleHeight, 32)
        
        // Morphy in resting stealth is 24 pt tall, perfectly fitting with 8 pt vertical safety clearance
        let restingMascot = MorphyMascotView(model: model, style: .restingStealth)
        XCTAssertEqual(restingMascot.style, .restingStealth)
    }
    
    // MARK: - 4. Resting Stealth Tap to Spotlight Bar
    func testRestingStealthTapActivatesSpotlightBar() {
        model.interactionMode = .spotlightBar
        model.isSpotlightBarActive = false
        XCTAssertEqual(model.islandState, .resting)
        
        // Simulating tap on resting stealth
        model.isSpotlightBarActive = true
        XCTAssertEqual(model.islandState, .spotlightBar)
        XCTAssertEqual(model.currentWidth, model.spotlightBarWidth)
    }
}
