import Foundation

/// User-Agent selection. Prefer WebKit’s native Safari UA so sites (Google, Cloudflare)
/// don’t treat Oriel as a spoofed Chrome browser and trigger bot checks.
///
/// Chrome Web Store / Firefox AMO **page browsing** no longer forces a desktop UA —
/// use the native **Oriel Store** for catalogs. `chromeDesktop` remains for CRX downloads
/// and Oriel Store’s own Chrome catalog fetch.
enum UserAgentPolicy {
    /// Chrome desktop UA — CRX downloads + Oriel Store Chrome catalog fetch only.
    static let chromeDesktop =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    /// Firefox desktop UA — reserved; AMO website install spoof is JS-side if the user keeps browsing.
    static let firefoxDesktop =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:133.0) Gecko/20100101 Firefox/133.0"

    static let safariDesktop = BrowserConstants.desktopUserAgent

    /// Google Search / SERP hosts only — not Gmail, Docs, Meet, Accounts, etc.
    /// Spoofing Chrome on these triggers “unusual traffic” / robot checks.
    static func isGoogleSearchHost(_ host: String?) -> Bool {
        guard var host = host?.lowercased(), !host.isEmpty else { return false }
        if host.hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        // google.com / google.nl / google.co.uk / google.com.au
        if Self.googleSearchApexPattern.firstMatch(
            in: host,
            range: NSRange(host.startIndex..., in: host)
        ) != nil {
            return true
        }
        // Search-adjacent properties that share the same bot checks
        switch host {
        case "images.google.com",
             "news.google.com",
             "scholar.google.com",
             "books.google.com",
             "video.google.com",
             "encrypted.google.com":
            return true
        default:
            return false
        }
    }

    /// Apex Google Search domains only (not mail.google.com / docs.google.com).
    private static let googleSearchApexPattern: NSRegularExpression = {
        // google.com | google.nl | google.co.uk | google.com.au
        try! NSRegularExpression(
            pattern: #"^google\.(com|[a-z]{2}|co\.[a-z]{2}|com\.[a-z]{2})$"#
        )
    }()

    /// Broader Google property check (legacy). Prefer ``isGoogleSearchHost`` for CAPTCHA policy.
    static func isGoogleHost(_ host: String?) -> Bool {
        if isGoogleSearchHost(host) { return true }
        guard var host = host?.lowercased(), !host.isEmpty else { return false }
        if host.hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        return host == "google.com" || host.hasSuffix(".google.com")
    }

    /// Host-only helper (tests / simple checks). Prefer ``isChromeWebStoreURL(_:)`` for policy.
    static func isChromeWebStoreHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased(), !host.isEmpty else { return false }
        return host == "chromewebstore.google.com"
            || host == "chrome.google.com"
            || host.hasSuffix(".chrome.google.com")
    }

    /// Narrow: only real Web Store URLs — not every `chrome.google.com` page.
    static func isChromeWebStoreURL(_ url: URL?) -> Bool {
        guard let url, let host = url.host?.lowercased(), !host.isEmpty else { return false }
        if host == "chromewebstore.google.com" { return true }
        if host == "chrome.google.com" || host.hasSuffix(".chrome.google.com") {
            let path = url.path.lowercased()
            return path.contains("webstore") || path.contains("/web-store")
        }
        return false
    }

    static func isFirefoxAddonsHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased(), !host.isEmpty else { return false }
        return host == "addons.mozilla.org"
            || host == "addons-dev.allizom.org"
            || host.hasSuffix(".addons.mozilla.org")
    }

    static func isFirefoxAddonsURL(_ url: URL?) -> Bool {
        isFirefoxAddonsHost(url?.host)
    }

    /// Chrome Web Store / Firefox Add-ons website URLs (tip → Oriel Store).
    static func isExtensionStoreURL(_ url: URL?) -> Bool {
        isChromeWebStoreURL(url) || isFirefoxAddonsURL(url)
    }

    /// Host convenience used by older call sites — prefers being conservative.
    static func isExtensionStoreHost(_ host: String?) -> Bool {
        guard let host else { return false }
        if host == "chromewebstore.google.com" { return true }
        return isFirefoxAddonsHost(host)
    }

    /// `nil` means “use WebKit’s default Safari UA”.
    /// Never auto-desktop store websites — Oriel Store is the catalog UI.
    /// Only an explicit Request Desktop Website changes the UA.
    @MainActor
    static func customUserAgent(
        for url: URL?,
        requestsDesktopSite: Bool,
        preferredEngine: BrowserEngineKind = .webkit
    ) -> String? {
        // Google Search must never get a Chrome UA — WebKit + Chrome identity → robot checks.
        if isGoogleSearchHost(url?.host) {
            return requestsDesktopSite ? safariDesktop : nil
        }
        if RenderingEnginePolicy.usesChromeDesktopUserAgent(preferredEngine) {
            return chromeDesktop
        }
        if requestsDesktopSite {
            return safariDesktop
        }
        return nil
    }
}
