import XCTest
@testable import Oriel

final class AuthAndJavaScriptTests: XCTestCase {
    func testAuthAllowlistIncludesGoogleAccounts() {
        let url = URL(string: "https://accounts.google.com/signin")!
        XCTAssertTrue(AuthHostAllowlist.shouldBypassContentBlocking(for: url))

        let nested = URL(string: "https://ssl.accounts.google.com/path")!
        XCTAssertTrue(AuthHostAllowlist.shouldBypassContentBlocking(for: nested))

        let ads = URL(string: "https://pagead2.googlesyndication.com/pagead/js")!
        XCTAssertFalse(AuthHostAllowlist.shouldBypassContentBlocking(for: ads))
    }

    @MainActor
    func testJavaScriptToggleFlipsTabState() {
        let tab = BrowserTab(searchEngine: .google)
        XCTAssertTrue(tab.javaScriptEnabled)
        tab.toggleJavaScript()
        XCTAssertFalse(tab.javaScriptEnabled)
        tab.toggleJavaScript()
        XCTAssertTrue(tab.javaScriptEnabled)
    }

    func testSettingsPersistJavaScriptDefault() async {
        await MainActor.run {
            let defaults = UserDefaults(suiteName: "oriel.tests.js.\(UUID().uuidString)")!
            let settings = BrowserSettings(defaults: defaults)
            settings.javaScriptEnabledByDefault = false
            let reloaded = BrowserSettings(defaults: defaults)
            XCTAssertFalse(reloaded.javaScriptEnabledByDefault)
        }
    }
}
