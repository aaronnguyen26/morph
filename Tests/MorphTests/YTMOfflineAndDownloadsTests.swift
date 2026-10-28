import XCTest
@testable import morph

@MainActor
final class YTMOfflineAndDownloadsTests: XCTestCase {
    
    override func setUp() async throws {
        YTMUserOfflineStore.shared.clear()
    }
    
    override func tearDown() async throws {
        YTMUserOfflineStore.shared.clear()
    }
    
    func testNetworkMonitorConnectionToggle() {
        let monitor = NetworkMonitor()
        XCTAssertTrue(monitor.isConnected, "NetworkMonitor should default to connected")
        XCTAssertTrue(monitor.isWifiConnected, "NetworkMonitor should default to wifi connected")
        
        monitor.setConnectedForTesting(false)
        XCTAssertFalse(monitor.isConnected, "NetworkMonitor should be disconnected when set to false")
        XCTAssertFalse(monitor.isWifiConnected, "NetworkMonitor should be wifi disconnected when set to false")
        
        monitor.setConnectedForTesting(true)
        XCTAssertTrue(monitor.isConnected, "NetworkMonitor should be reconnected when set to true")
        XCTAssertTrue(monitor.isWifiConnected, "NetworkMonitor should be wifi connected when set to true")
    }
    
    func testRightDeckDownloadsSectionProperties() {
        let section = YTMRightDeckSection.downloads
        XCTAssertEqual(section.rawValue, "Downloads")
        XCTAssertEqual(section.title, "Downloads")
        XCTAssertEqual(section.iconName, "arrow.down.circle.fill")
    }
    
    func testNormalUIAvailableSectionsExcludesDownloads() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let networkMonitor = NetworkMonitor()
        networkMonitor.setConnectedForTesting(true)
        
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio, networkMonitor: networkMonitor)
        
        // When online, available right deck sections MUST be the normal UI: Home, Playlists, Queue, Search
        // Downloads tab must NOT be shown in the normal tab bar when online!
        XCTAssertFalse(media.isOffline, "User is online")
        XCTAssertEqual(media.availableRightDeckSections, [.home, .playlists, .queue, .search])
        XCTAssertFalse(media.availableRightDeckSections.contains(.downloads), "Downloads must not be visible when online")
        XCTAssertEqual(media.rightDeckSection, .home, "Default deck section must be .home")
    }
    
    func testUserYouTubeMusicOfflineStoreCaching() {
        let store = YTMUserOfflineStore.shared
        store.clear()
        XCTAssertTrue(store.getOfflineTracks().isEmpty)
        
        // Simulate playing an actual YouTube Music track from the user's library
        let userTrack = YTMPlaylistItem(
            id: "ytm_user_song_1",
            title: "Cruel Summer",
            artist: "Taylor Swift",
            duration: "2:58",
            isPlaying: false,
            videoId: "ic8j13piLuA",
            thumbnailURL: "https://i.ytimg.com/vi/ic8j13piLuA/hqdefault.jpg"
        )
        
        store.recordTrack(userTrack)
        
        let cached = store.getOfflineTracks()
        XCTAssertEqual(cached.count, 1)
        XCTAssertEqual(cached.first?.title, "Cruel Summer")
        XCTAssertEqual(cached.first?.artist, "Taylor Swift")
        XCTAssertEqual(cached.first?.videoId, "ic8j13piLuA")
    }
    
    func testOfflineHandlingTakesDownloadsFromUserYouTubeMusic() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let networkMonitor = NetworkMonitor()
        networkMonitor.setConnectedForTesting(true)
        
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio, networkMonitor: networkMonitor)
        
        // Seed user's actual YouTube Music tracks into cache
        let myYTMTrack = YTMPlaylistItem(
            id: "ytm_liked_1",
            title: "Blinding Lights",
            artist: "The Weeknd",
            duration: "3:20",
            isPlaying: false,
            videoId: "4NRXx6U8ABQ",
            thumbnailURL: "https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg"
        )
        YTMUserOfflineStore.shared.recordTrack(myYTMTrack)
        
        // Initially online on normal UI
        XCTAssertFalse(media.isOffline)
        XCTAssertEqual(media.rightDeckSection, .home)
        
        // Simulate user disconnecting from Wi-Fi
        networkMonitor.setConnectedForTesting(false)
        XCTAssertTrue(media.isOffline, "MediaControllerModel must detect offline state")
        
        // Trigger offline handling
        media.triggerOfflineHandling(for: "Random Song")
        
        // Verifications:
        // 1. Must be in .downloads right deck
        // 2. Must only show .downloads in availableRightDeckSections
        // 3. Downloaded tracks MUST come from the user's YouTube Music
        XCTAssertEqual(media.rightDeckSection, .downloads)
        XCTAssertEqual(media.availableRightDeckSections, [.downloads])
        XCTAssertTrue(media.downloadedTracks.contains(where: { $0.title == "Blinding Lights" && $0.artist == "The Weeknd" }),
                      "Downloaded tracks must include the user's YouTube Music tracks")
        
        // Verify Wi-Fi reconnection restores the normal UI
        networkMonitor.setConnectedForTesting(true)
        XCTAssertFalse(media.isOffline, "MediaControllerModel must detect Wi-Fi reconnection")
        XCTAssertEqual(media.rightDeckSection, .home, "Reconnecting Wi-Fi must automatically restore normal UI (.home)")
        XCTAssertEqual(media.availableRightDeckSections, [.home, .playlists, .queue, .search], "Normal tabs must be restored")
    }
    
    func testOfflineHandlingSwitchesToDownloadsAndShowsHUD() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let networkMonitor = NetworkMonitor()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio, networkMonitor: networkMonitor)
        
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
        // 1. Must display offline HUD
        // 2. Must automatically switch right deck to .downloads
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
        
        // Populate offline tracks with real YouTube Music item
        let offlineTrack = YTMPlaylistItem(
            id: "ytm_offline_hit",
            title: "Get Lucky",
            artist: "Daft Punk",
            duration: "4:08",
            isPlaying: false,
            videoId: "5NV6Rdv1a3I",
            thumbnailURL: "https://i.ytimg.com/vi/5NV6Rdv1a3I/hqdefault.jpg"
        )
        media.downloadedTracks = [offlineTrack]
        
        // Set offline
        networkMonitor.setConnectedForTesting(false)
        XCTAssertTrue(media.isOffline)
        
        // Play downloaded track
        media.playDownloadedTrack(offlineTrack)
        
        XCTAssertEqual(media.trackTitle, offlineTrack.title)
        XCTAssertEqual(media.artistName, offlineTrack.artist)
        XCTAssertTrue(media.isPlaying)
        XCTAssertEqual(media.currentTime, 0)
        XCTAssertEqual(media.sourceName, "YouTube Music Offline")
        
        // Now test playing a downloaded track through playQueueTrack:
        media.showOfflineHUD = false
        media.playQueueTrack(offlineTrack)
        XCTAssertFalse(media.showOfflineHUD, "Playing downloaded queue track while offline should NOT trigger offline alert")
        XCTAssertEqual(media.trackTitle, offlineTrack.title)
        
        // Now test playing downloaded track through playSongInSelectedPlaylist with pl_downloads:
        let downloadsPlaylist = YTMPlaylist(
            id: "pl_downloads",
            title: "YouTube Music Offline",
            subtitle: "Offline Cache",
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
    
    func testOpenDownloadsSectionWhenOffline() {
        let mockAudio = MockSystemAudioService()
        let engine = YouTubeMusicEngine()
        let networkMonitor = NetworkMonitor()
        let media = MediaControllerModel(engine: engine, systemAudio: mockAudio, networkMonitor: networkMonitor)
        
        networkMonitor.setConnectedForTesting(false)
        XCTAssertTrue(media.isOffline)
        media.openDownloadsSection()
        XCTAssertEqual(media.rightDeckSection, .downloads)
    }
}
