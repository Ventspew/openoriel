import XCTest
@testable import Oriel

@MainActor
final class ChromiumMacFeaturesTests: XCTestCase {
    func testAutoListMatchesMeet() {
        XCTAssertTrue(ChromiumAutoSiteList.matches("meet.google.com"))
        XCTAssertTrue(ChromiumAutoSiteList.matches("app.meet.google.com"))
        XCTAssertFalse(ChromiumAutoSiteList.matches("example.com"))
    }

    func testResolvePrefersTabOverride() {
        let policy = ChromiumSitePolicy()
        policy.autoChromiumForStubbornSites = true
        let engine = RenderingEnginePolicy.resolve(
            global: .webkit,
            tabOverride: .chromiumCompatibility,
            host: "example.com",
            policy: policy
        )
        #if os(macOS)
        XCTAssertEqual(engine, .chromiumCompatibility)
        #else
        XCTAssertEqual(engine, .webkit)
        #endif
    }

    func testResolveAutoStubbornWhenWebKitDefault() {
        let policy = ChromiumSitePolicy()
        policy.autoChromiumForStubbornSites = true
        let engine = RenderingEnginePolicy.resolve(
            global: .webkit,
            tabOverride: nil,
            host: "teams.microsoft.com",
            policy: policy
        )
        #if os(macOS)
        XCTAssertEqual(engine, .chromiumCompatibility)
        #else
        XCTAssertEqual(engine, .webkit)
        #endif
    }

    func testForceWebKitBeatsAutoList() {
        let policy = ChromiumSitePolicy()
        policy.autoChromiumForStubbornSites = true
        policy.setPreference(.forceWebKit, forHost: "meet.google.com")
        let engine = RenderingEnginePolicy.resolve(
            global: .webkit,
            tabOverride: nil,
            host: "meet.google.com",
            policy: policy
        )
        XCTAssertEqual(engine, .webkit)
    }

    func testIdentityScriptIsNonEmpty() {
        XCTAssertTrue(ChromiumIdentityScript.source.contains("userAgentData"))
        XCTAssertTrue(ChromiumIdentityScript.source.contains("Chromium"))
    }
}
