import Foundation

/// User-Agent selection. Prefer WebKit’s native Safari UA so sites (Google, Cloudflare)
/// don’t treat Oriel as a spoofed Chrome browser and trigger bot checks.
enum UserAgentPolicy {
    /// Used only for Chrome Web Store HTTP fetches (not for page browsing).
    static let chromeDesktop =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    static let safariDesktop = BrowserConstants.desktopUserAgent

    static func isGoogleHost(_ host: String?) -> Bool {
        guard var host = host?.lowercased(), !host.isEmpty else { return false }
        if host.hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        if host == "google.com" || host.hasSuffix(".google.com") {
            return true
        }
        if host.hasPrefix("google.") {
            return true
        }
        return false
    }

    /// `nil` means “use WebKit’s default Safari UA”.
    /// Only override when the user explicitly requests a desktop site on iPhone/iPad.
    static func customUserAgent(for url: URL?, requestsDesktopSite: Bool) -> String? {
        if requestsDesktopSite {
            return safariDesktop
        }
        return nil
    }
}
