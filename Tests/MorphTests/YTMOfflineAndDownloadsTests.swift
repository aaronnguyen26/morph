import XCTest
@testable import morph

@MainActor
final class YTMOfflineAndDownloadsTests: XCTestCase {
    
    func testNetworkMonitorConnectionToggle() {
        let monitor = NetworkMonitor()
        XCTAssertTrue(monitor.isConnected, "NetworkMonitor should default to connected")
        
        monitor.setConnectedForTesting(false)
        XCTAssertFalse(monitor.isConnected, "NetworkMonitor should be disconnected when set to false")
        
        monitor.setConnectedForTesting(true)
        XCTAssertTrue(monitor.isConnected, "NetworkMonitor should be reconnected when set to true")
    }
    
    func testRightDeckDownloadsSectionProperties() {
        let section = YTMRightDeckSection.downloads
        XCTAssertEqual(section.rawValue, "Downloads")
        XCTAssertEqual(section.title, "Downloads")
        XCTAssertEqual(section.iconName, "arrow.down.circle.fill")
        XCTAssertTrue(YTMRightDeckSection.allCases.contains(.downloads))
    }
    
    func testOfflineHandlingSwitchesToDownloadsAndShowsHUD() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let networkMonitor = NetworkMonitor()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio, networkMonitor: networkMonitor)
        
        // Initially online and on home deck
        XCTAssertFalse(media.isOffline)
        XCTAssertEqual(media.rightDeckSection, .home)
        XCTAssertFalse(media.showOfflineHUD)
        
        // Simulate going offline
        networkMonitor.setConnectedForTesting(false)
        XCTAssertTrue(media.isOffline, "MediaControllerModel should observe NetworkMonitor offline state")
        
        // Attempt to play a quick pick while offline
        let dummyTrack = YTMPlaylistItem(
            id: "track_1",
            title: "Online Stream Hit",
            artist: "Global Artist",
            duration: "3:45",
            isPlaying: false,
            videoId: "v12345",
            thumbnailURL: nil
        )
        
        media.playQuickPick(dummyTrack)
        
        // Verifications:
        // 1. Must NOT play on engine
        // 2. Must display offline HUD
        // 3. Must automatically switch right deck to .downloads
        XCTAssertTrue(media.showOfflineHUD, "HUD should trigger when attempting to stream while offline")
        XCTAssertTrue(media.offlineHUDMessage.contains("Offline"), "HUD message should indicate offline")
        XCTAssertEqual(media.rightDeckSection, .downloads, "Right deck should automatically switch to .downloads")
    }
    
    func testRapidClickDebouncePreventsLag() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let networkMonitor = NetworkMonitor()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio, networkMonitor: networkMonitor)
        
        networkMonitor.setConnectedForTesting(false)
        XCTAssertTrue(media.isOffline)
        
        let trackA = YTMPlaylistItem(id: "a", title: "Song A", artist: "Artist", duration: "3:00", isPlaying: false, videoId: "va", thumbnailURL: nil)
        let trackB = YTMPlaylistItem(id: "b", title: "Song B", artist: "Artist", duration: "3:10", isPlaying: false, videoId: "vb", thumbnailURL: nil)
        
        // 1st click: sets offline handling and lastOfflineAttemptTime
        media.playQuickPick(trackA)
        XCTAssertTrue(media.showOfflineHUD)
        XCTAssertEqual(media.rightDeckSection, .downloads)
        
        // Immediate repeat click (user spam-clicking):
        // Debounce should swallow it gracefully without resetting timers or throwing errors
        media.playQuickPick(trackB)
        XCTAssertTrue(media.showOfflineHUD)
        XCTAssertEqual(media.rightDeckSection, .downloads)
    }
    
    func testOfflineGuardsOnPlaylistsAndQueue() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let networkMonitor = NetworkMonitor()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio, networkMonitor: networkMonitor)
        
        networkMonitor.setConnectedForTesting(false)
        
        let onlineTrack = YTMPlaylistItem(
            id: "online_track",
            title: "Streaming Track",
            artist: "Streamer",
            duration: "4:00",
            isPlaying: false,
            videoId: "xyz987",
            thumbnailURL: nil
        )
        
        // Test playSongInSelectedPlaylist guard
        media.switchRightDeck(to: .home)
        media.playSongInSelectedPlaylist(onlineTrack)
        XCTAssertEqual(media.rightDeckSection, .downloads)
        XCTAssertTrue(media.showOfflineHUD)
        
        // Test playEntireSelectedPlaylist guard
        let dummyPlaylist = YTMPlaylist(
            id: "online_pl",
            title: "Top 50 Hits",
            subtitle: "Global",
            thumbnailURL: nil,
            trackCount: 1,
            tracks: [onlineTrack],
            browseId: "VL123"
        )
        media.selectPlaylist(dummyPlaylist)
        media.playEntireSelectedPlaylist()
        XCTAssertEqual(media.rightDeckSection, .downloads)
        XCTAssertTrue(media.showOfflineHUD)
        
        // Test playQueueTrack guard
        media.switchRightDeck(to: .home)
        media.playQueueTrack(onlineTrack)
        XCTAssertEqual(media.rightDeckSection, .downloads)
        XCTAssertTrue(media.showOfflineHUD)
        
        // Test openSearchResult guard
        let searchResult = YTMSearchResult(
            id: "sr_1",
            kind: .song,
            title: "Search Hit",
            subtitle: "Artist",
            thumbnailURL: nil,
            videoId: "vid_sr"
        )
        media.switchRightDeck(to: .search)
        media.openSearchResult(searchResult)
        XCTAssertEqual(media.rightDeckSection, .downloads)
        XCTAssertTrue(media.showOfflineHUD)
    }
    
    func testDownloadedTrackPlaybackWorksOffline() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let networkMonitor = NetworkMonitor()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio, networkMonitor: networkMonitor)
        
        // Populate offline tracks
        XCTAssertFalse(media.downloadedTracks.isEmpty, "MediaControllerModel should have default offline tracks or scanned tracks")
        guard let offlineTrack = media.downloadedTracks.first else {
            XCTFail("No downloaded tracks found")
            return
        }
        
        // Set offline
        networkMonitor.setConnectedForTesting(false)
        XCTAssertTrue(media.isOffline)
        
        // Play downloaded track
        media.playDownloadedTrack(offlineTrack)
        
        XCTAssertEqual(media.trackTitle, offlineTrack.title)
        XCTAssertEqual(media.artistName, offlineTrack.artist)
        XCTAssertTrue(media.isPlaying)
        XCTAssertEqual(media.currentTime, 0)
        
        // Now test playing a downloaded track through playQueueTrack:
        // Even when offline, queue items matching downloadedTracks should play without triggering offline guard
        media.showOfflineHUD = false
        media.playQueueTrack(offlineTrack)
        XCTAssertFalse(media.showOfflineHUD, "Playing downloaded queue track while offline should NOT trigger offline alert")
        XCTAssertEqual(media.trackTitle, offlineTrack.title)
        
        // Now test playing downloaded track through playSongInSelectedPlaylist with pl_downloads:
        let downloadsPlaylist = YTMPlaylist(
            id: "pl_downloads",
            title: "Downloads & Offline",
            subtitle: "Local",
            thumbnailURL: nil,
            trackCount: media.downloadedTracks.count,
            tracks: media.downloadedTracks,
            browseId: nil
        )
        media.selectPlaylist(downloadsPlaylist)
        media.showOfflineHUD = false
        media.playSongInSelectedPlaylist(offlineTrack)
        XCTAssertFalse(media.showOfflineHUD, "Playing from pl_downloads should play directly offline")
        XCTAssertEqual(media.trackTitle, offlineTrack.title)
    }
    
    func testOpenDownloadsSectionAndFolder() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let networkMonitor = NetworkMonitor()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio, networkMonitor: networkMonitor)
        
        media.openDownloadsSection()
        XCTAssertEqual(media.rightDeckSection, .downloads)
    }
}
