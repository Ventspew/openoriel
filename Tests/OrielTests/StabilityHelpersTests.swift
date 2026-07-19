import XCTest
@testable import Oriel

final class StabilityHelpersTests: XCTestCase {
    func testJSONFileStoreCompactSaveRoundTrip() throws {
        struct Sample: Codable, Equatable {
            var value: Int
            var label: String
        }
        let name = "stability-compact-\(UUID().uuidString).json"
        let sample = Sample(value: 42, label: "oriel")
        try JSONFileStore.save(sample, to: name, prettyPrinted: false)
        let loaded = try JSONFileStore.load(Sample.self, from: name)
        XCTAssertEqual(loaded, sample)
    }

    func testPrivacyStatsDebouncedPersistFlushes() async {
        await MainActor.run {
            let fileName = "privacy-stats-debounce-\(UUID().uuidString).json"
            let stats = PrivacyStats(fileName: fileName)
            stats.recordBlockedRequest(url: URL(string: "https://doubleclick.net/pixel")!)
            stats.recordHTTPSUpgrade()
            // Before flush, a brand-new instance may still see zeros if debounce hasn't fired.
            stats.flush()
            let reloaded = PrivacyStats(fileName: fileName)
            XCTAssertGreaterThanOrEqual(reloaded.blockedRequestsSession, 1)
            XCTAssertGreaterThanOrEqual(reloaded.httpsUpgradesSession, 1)
        }
    }
}
