import XCTest
@testable import Oriel

final class Phase2AndBeyondTests: XCTestCase {
    func testDuckPlayerVideoID() {
        let watch = URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!
        XCTAssertEqual(DuckPlayer.videoID(from: watch), "dQw4w9WgXcQ")
        let short = URL(string: "https://youtu.be/dQw4w9WgXcQ")!
        XCTAssertEqual(DuckPlayer.videoID(from: short), "dQw4w9WgXcQ")
        let player = DuckPlayer.playerURL(forVideoID: "dQw4w9WgXcQ")
        XCTAssertTrue(URLParser.isDuckPlayerPage(player))
        XCTAssertEqual(URLParser.duckPlayerVideoID(from: player), "dQw4w9WgXcQ")
    }

    func testHTTPSOnlyBlocksPlainHTTP() {
        let http = URL(string: "http://example.com/insecure")!
        let upgraded = HTTPSUpgrade.upgradeIfNeeded(http, enabled: true)
        XCTAssertTrue(upgraded.didUpgrade)
        XCTAssertEqual(upgraded.url.scheme, "https")
    }

    func testElementHidePersistence() async {
        await MainActor.run {
            let store = ElementHideStore()
            store.clear(host: "example.com")
            store.add(host: "example.com", cssSelector: ".cookie-banner")
            XCTAssertFalse(store.rules(forHost: "example.com").isEmpty)
            let script = store.injectionScript(forHost: "example.com")
            XCTAssertTrue(script.contains("cookie-banner"))
            store.clear(host: "example.com")
        }
    }

    func testProfilesCreateAndSelect() async {
        await MainActor.run {
            let store = ProfileStore()
            let before = store.profiles.count
            let created = store.create(name: "Work")
            XCTAssertEqual(store.profiles.count, before + 1)
            store.select(id: created.id)
            XCTAssertEqual(store.activeProfileID, created.id)
        }
    }

    func testSuggestionURLsExist() {
        XCTAssertNotNil(SearchEngine.duckDuckGo.suggestionURL(for: "test"))
        XCTAssertNotNil(SearchEngine.google.suggestionURL(for: "test"))
    }
}
