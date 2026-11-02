import XCTest
@testable import morph

final class YTMTabRoutingTests: XCTestCase {
    @MainActor
    private func makeMedia() -> MediaControllerModel {
        let media = MediaControllerModel(engine: YouTubeMusicEngine())
        media.playlist = [YTMPlaylistItem(id: "0", title: "Queue Song", artist: "A", videoId: "q1")]
        return media
    }

    @MainActor
    func testQueueCardOpensQueueTabNotPlaylistsTab() {
        let media = makeMedia()
        media.selectPlaylist(media.nowPlayingQueuePlaylist)
        XCTAssertEqual(media.rightDeckSection, .queue)
    }

    @MainActor
    func testRealPlaylistOpensInPlaylistsTab() {
        let media = makeMedia()
        let pl = YTMPlaylist(id: "PL1", title: "Mine", subtitle: "",
                             tracks: [YTMPlaylistItem(id: "1", title: "P Song", artist: "B", videoId: "p1")],
                             browseId: "VLPL1", kind: .playlist)
        media.selectPlaylist(pl)
        XCTAssertEqual(media.rightDeckSection, .playlists)
        XCTAssertEqual(media.selectedPlaylist?.id, "PL1")
    }

    @MainActor
    func testSwitchingTabsClearsOpenedPlaylist() {
        let media = makeMedia()
        let pl = YTMPlaylist(id: "PL1", title: "Mine", subtitle: "",
                             tracks: [YTMPlaylistItem(id: "1", title: "P Song", artist: "B", videoId: "p1")],
                             browseId: "VLPL1", kind: .playlist)
        media.selectPlaylist(pl)
        media.switchRightDeck(to: .queue)
        XCTAssertEqual(media.selectedPlaylist?.id, "pl_queue")
        media.switchRightDeck(to: .playlists)
        XCTAssertNil(media.selectedPlaylist)
        XCTAssertEqual(media.rightDeckSection, .playlists)
        media.switchRightDeck(to: .search)
        XCTAssertNil(media.selectedPlaylist)
    }
}
