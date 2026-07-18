import Foundation

/// Resolves address-bar input into a navigable URL or search query.
enum URLParser: Sendable {
    enum Resolution: Equatable, Sendable {
        case url(URL)
        case search(query: String)
    }

    /// Schemes that must never be opened from the address bar or page navigation policy.
    static let rejectedSchemes: Set<String> = [
        "javascript",
        "data",
        "file",
        "about",
        "blob",
        "ws",
        "wss",
        "ftp"
    ]

    static let allowedSchemes: Set<String> = [
        "http",
        "https",
        BrowserConstants.aboutScheme
    ]

    static func resolve(_ rawInput: String, searchEngine: SearchEngine) -> URL {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return startPageURL
        }

        switch classify(trimmed) {
        case .url(let url):
            return url
        case .search(let query):
            return searchEngine.searchURL(for: query)
        }
    }

    static func classify(_ rawInput: String) -> Resolution {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .url(startPageURL)
        }

        if trimmed.lowercased() == "oriel:home" || trimmed.lowercased() == "about:home" {
            return .url(startPageURL)
        }

        if looksLikeSearchQuery(trimmed) {
            return .search(query: trimmed)
        }

        if let url = urlFromAddress(trimmed) {
            return .url(url)
        }

        return .search(query: trimmed)
    }

    static var startPageURL: URL {
        URL(string: "\(BrowserConstants.aboutScheme)://\(BrowserConstants.startPageHost)")!
    }

    static func isStartPage(_ url: URL?) -> Bool {
        guard let url else { return true }
        return url.scheme?.lowercased() == BrowserConstants.aboutScheme
            && url.host?.lowercased() == BrowserConstants.startPageHost
    }

    static func isDuckPlayerPage(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.scheme?.lowercased() == BrowserConstants.aboutScheme
            && url.host?.lowercased() == "player"
    }

    static func duckPlayerVideoID(from url: URL) -> String? {
        guard isDuckPlayerPage(url) else { return nil }
        let id = url.path.split(separator: "/").first.map(String.init)
        return id?.isEmpty == false ? id : nil
    }

    static func isAllowedNavigation(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if rejectedSchemes.contains(scheme) { return false }
        return allowedSchemes.contains(scheme)
    }

    // MARK: - Private

    private static func looksLikeSearchQuery(_ input: String) -> Bool {
        if input.contains(" ") { return true }
        if input.contains("://") { return false }

        // Bare words without a dot are searches ("swift concurrency")
        if !input.contains(".") && !input.contains("localhost") {
            return true
        }

        // Question-like queries
        if input.hasSuffix("?") { return true }

        return false
    }

    private static func urlFromAddress(_ input: String) -> URL? {
        if let url = URL(string: input), url.scheme != nil, url.host != nil {
            guard isAllowedNavigation(url) else { return nil }
            return url
        }

        // Prefer https for host-like input
        let candidate = input.hasPrefix("//") ? "https:\(input)" : "https://\(input)"
        guard let url = URL(string: candidate),
              let host = url.host,
              isPlausibleHost(host),
              isAllowedNavigation(url) else {
            return nil
        }
        return url
    }

    private static func isPlausibleHost(_ host: String) -> Bool {
        if host.caseInsensitiveCompare("localhost") == .orderedSame { return true }
        if host.contains(":") { return false } // IPv6 etc. — keep simple for MVP
        // Must contain a dot (TLD) or be localhost
        return host.contains(".")
    }
}
