import Foundation
import Observation

/// Session and lifetime privacy counters. Blocked-request totals are best-effort
/// (WebKit does not expose a full content-blocker hit stream for in-app rule lists).
@Observable
@MainActor
final class PrivacyStats {
    private(set) var blockedRequestsSession: Int = 0
    private(set) var httpsUpgradesSession: Int = 0
    private(set) var cookiesBlockedSession: Int = 0
    private(set) var blockedRequestsLifetime: Int = 0
    private(set) var httpsUpgradesLifetime: Int = 0
    private(set) var cookiesBlockedLifetime: Int = 0

    private let fileName = "privacy-stats.json"

    init() {
        if let loaded = try? JSONFileStore.load(Persisted.self, from: fileName) {
            blockedRequestsLifetime = loaded.blockedRequestsLifetime
            httpsUpgradesLifetime = loaded.httpsUpgradesLifetime
            cookiesBlockedLifetime = loaded.cookiesBlockedLifetime
        }
    }

    func recordBlockedRequest(count: Int = 1, url: URL? = nil) {
        guard count > 0 else { return }
        blockedRequestsSession += count
        blockedRequestsLifetime += count
        if let url, Self.looksCookieRelated(url) {
            cookiesBlockedSession += count
            cookiesBlockedLifetime += count
        }
        persist()
    }

    func recordHTTPSUpgrade() {
        httpsUpgradesSession += 1
        httpsUpgradesLifetime += 1
        persist()
    }

    func resetSessionCounters() {
        blockedRequestsSession = 0
        httpsUpgradesSession = 0
        cookiesBlockedSession = 0
    }

    /// Hosts / paths commonly used for cookie sync, consent pixels, and identity trackers.
    nonisolated static func looksCookieRelated(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        let haystack = host + path

        let hostHints = [
            "doubleclick", "googlesyndication", "googleadservices",
            "facebook.com", "facebook.net", "fbcdn",
            "adservice", "scorecardresearch", "quantserve",
            "hotjar", "fullstory", "mouseflow",
            "segment.io", "segment.com", "mixpanel", "amplitude",
            "criteo", "taboola", "outbrain",
            "cookiebot", "cookielaw", "onetrust", "trustarc",
            "consent", "privacymanager"
        ]
        if hostHints.contains(where: { host.contains($0) }) {
            return true
        }

        let pathHints = [
            "/cookie", "cookiebot", "onetrust", "consent",
            "/track", "/pixel", "/beacon", "collect?"
        ]
        return pathHints.contains(where: { haystack.contains($0) })
    }

    private struct Persisted: Codable {
        var blockedRequestsLifetime: Int
        var httpsUpgradesLifetime: Int
        var cookiesBlockedLifetime: Int

        enum CodingKeys: String, CodingKey {
            case blockedRequestsLifetime
            case httpsUpgradesLifetime
            case cookiesBlockedLifetime
        }

        init(
            blockedRequestsLifetime: Int,
            httpsUpgradesLifetime: Int,
            cookiesBlockedLifetime: Int
        ) {
            self.blockedRequestsLifetime = blockedRequestsLifetime
            self.httpsUpgradesLifetime = httpsUpgradesLifetime
            self.cookiesBlockedLifetime = cookiesBlockedLifetime
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            blockedRequestsLifetime = try container.decode(Int.self, forKey: .blockedRequestsLifetime)
            httpsUpgradesLifetime = try container.decode(Int.self, forKey: .httpsUpgradesLifetime)
            cookiesBlockedLifetime = try container.decodeIfPresent(Int.self, forKey: .cookiesBlockedLifetime) ?? 0
        }
    }

    private func persist() {
        let data = Persisted(
            blockedRequestsLifetime: blockedRequestsLifetime,
            httpsUpgradesLifetime: httpsUpgradesLifetime,
            cookiesBlockedLifetime: cookiesBlockedLifetime
        )
        try? JSONFileStore.save(data, to: fileName)
    }
}
