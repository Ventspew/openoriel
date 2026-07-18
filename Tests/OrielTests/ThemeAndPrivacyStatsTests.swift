import XCTest
@testable import Oriel

final class ThemeAndPrivacyStatsTests: XCTestCase {
    func testAccentAndBackgroundThemesPersist() async {
        await MainActor.run {
            let defaults = UserDefaults(suiteName: "oriel.tests.theme.\(UUID().uuidString)")!
            let settings = BrowserSettings(defaults: defaults)
            settings.accentTheme = .ocean
            settings.backgroundTheme = .aurora
            let reloaded = BrowserSettings(defaults: defaults)
            XCTAssertEqual(reloaded.accentTheme, .ocean)
            XCTAssertEqual(reloaded.backgroundTheme, .aurora)
        }
    }

    func testCookieRelatedHostClassification() {
        XCTAssertTrue(
            PrivacyStats.looksCookieRelated(URL(string: "https://www.googleadservices.com/pagead/cookie")!)
        )
        XCTAssertTrue(
            PrivacyStats.looksCookieRelated(URL(string: "https://cdn.cookiebot.com/uc.js")!)
        )
        XCTAssertFalse(
            PrivacyStats.looksCookieRelated(URL(string: "https://example.com/about")!)
        )
    }

    func testBlockedRequestIncrementsCookieCounter() async {
        await MainActor.run {
            let stats = PrivacyStats()
            let beforeTrackers = stats.blockedRequestsSession
            let beforeCookies = stats.cookiesBlockedSession
            stats.recordBlockedRequest(url: URL(string: "https://doubleclick.net/pixel"))
            XCTAssertEqual(stats.blockedRequestsSession, beforeTrackers + 1)
            XCTAssertEqual(stats.cookiesBlockedSession, beforeCookies + 1)
            stats.recordBlockedRequest(url: URL(string: "https://cdn.example.com/script.js"))
            XCTAssertEqual(stats.blockedRequestsSession, beforeTrackers + 2)
            XCTAssertEqual(stats.cookiesBlockedSession, beforeCookies + 1)
        }
    }
}
