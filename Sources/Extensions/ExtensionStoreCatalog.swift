import Foundation

/// One installable item from Chrome Web Store or Firefox AMO, for Oriel’s native store UI.
struct ExtensionStoreItem: Identifiable, Hashable, Sendable {
    enum Source: String, Hashable, Sendable {
        case chrome
        case firefox
    }

    enum Kind: String, Hashable, Sendable {
        case `extension`
        case theme
    }

    /// Stable id: `chrome:<storeID>` or `firefox:<slug>`.
    var id: String { "\(source.rawValue):\(storeIdentifier)" }

    let source: Source
    let kind: Kind
    /// Chrome: 32-char a–p id. Firefox: AMO slug.
    let storeIdentifier: String
    let name: String
    let summary: String
    let iconURL: URL?
    let rating: Double?
    let storeURL: URL?
}

/// Fetches searchable catalogs for the native Oriel Store.
enum ExtensionStoreCatalog {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        config.httpAdditionalHeaders = [
            "Accept-Language": "en-US,en;q=0.9"
        ]
        return URLSession(configuration: config)
    }()

    // MARK: - Public

    static func search(
        query: String,
        source: ExtensionStoreItem.Source,
        kind: ExtensionStoreItem.Kind,
        limit: Int = 30
    ) async throws -> [ExtensionStoreItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        switch source {
        case .firefox:
            return try await searchFirefox(query: trimmed, kind: kind, limit: limit)
        case .chrome:
            return try await searchChrome(query: trimmed, kind: kind, limit: limit)
        }
    }

    // MARK: - Firefox AMO (official API v5)

    static func searchFirefox(
        query: String,
        kind: ExtensionStoreItem.Kind,
        limit: Int
    ) async throws -> [ExtensionStoreItem] {
        var components = URLComponents(string: "https://addons.mozilla.org/api/v5/addons/search/")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "app", value: "firefox"),
            URLQueryItem(name: "page_size", value: String(min(max(limit, 1), 50))),
            URLQueryItem(name: "type", value: kind == .theme ? "statictheme" : "extension")
        ]
        if query.isEmpty {
            items.append(URLQueryItem(name: "sort", value: "users"))
        } else {
            items.append(URLQueryItem(name: "q", value: query))
            items.append(URLQueryItem(name: "sort", value: "relevance"))
        }
        components.queryItems = items
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "Oriel/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (extension store)",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let parsed = parseAMOSearch(data: data, kind: kind)
        if parsed.isEmpty {
            throw URLError(.cannotParseResponse)
        }
        return parsed
    }

    static func parseAMOSearch(data: Data, kind: ExtensionStoreItem.Kind) -> [ExtensionStoreItem] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = root["results"] as? [[String: Any]] else {
            return []
        }
        return results.compactMap { row in
            guard let slug = row["slug"] as? String, !slug.isEmpty else { return nil }
            let name = localizedString(row["name"]) ?? slug
            let summary = localizedString(row["summary"]) ?? ""
            let icon: URL? = {
                if let s = row["icon_url"] as? String { return URL(string: s) }
                return nil
            }()
            let rating: Double? = {
                guard let ratings = row["ratings"] as? [String: Any] else { return nil }
                if let d = ratings["average"] as? Double { return d }
                if let n = ratings["average"] as? NSNumber { return n.doubleValue }
                return nil
            }()
            let storeURL = URL(string: "https://addons.mozilla.org/firefox/addon/\(slug)/")
            let resolvedKind: ExtensionStoreItem.Kind = {
                if let type = row["type"] as? String, type == "statictheme" { return .theme }
                return kind
            }()
            return ExtensionStoreItem(
                source: .firefox,
                kind: resolvedKind,
                storeIdentifier: slug,
                name: name,
                summary: summary,
                iconURL: icon,
                rating: rating,
                storeURL: storeURL
            )
        }
    }

    private static func localizedString(_ value: Any?) -> String? {
        if let s = value as? String, !s.isEmpty { return s }
        guard let map = value as? [String: Any] else { return nil }
        let preferred = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        if let s = map[preferred] as? String, !s.isEmpty { return s }
        let lang = Locale.current.language.languageCode?.identifier
        if let lang, let s = map[lang] as? String, !s.isEmpty { return s }
        if let s = map["en-US"] as? String, !s.isEmpty { return s }
        return map.values.compactMap { $0 as? String }.first { !$0.isEmpty }
    }

    // MARK: - Chrome Web Store (HTML catalog parse; no official public API)

    static func searchChrome(
        query: String,
        kind: ExtensionStoreItem.Kind,
        limit: Int
    ) async throws -> [ExtensionStoreItem] {
        let url: URL
        if query.isEmpty {
            let path = kind == .theme ? "category/themes" : "category/extensions"
            url = URL(string: "https://chromewebstore.google.com/\(path)")!
        } else {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
            var components = URLComponents(string: "https://chromewebstore.google.com/search/\(encoded)")!
            if kind == .theme {
                components.queryItems = [URLQueryItem(name: "itemTypes", value: "2")]
            }
            guard let built = components.url else { throw URLError(.badURL) }
            url = built
        }

        var request = URLRequest(url: url)
        request.setValue(UserAgentPolicy.chromeDesktop, forHTTPHeaderField: "User-Agent")
        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw URLError(.badServerResponse)
        }
        let items = parseChromeStoreHTML(html, kind: kind)
        if items.isEmpty {
            throw URLError(.cannotParseResponse)
        }
        return Array(items.prefix(limit))
    }

    /// Parses CWS search/category HTML cards.
    static func parseChromeStoreHTML(_ html: String, kind: ExtensionStoreItem.Kind) -> [ExtensionStoreItem] {
        var results: [ExtensionStoreItem] = []
        var seen = Set<String>()

        // Prefer data-item-id cards (richer title text nearby).
        // NOTE: do not use #"…\"…"# — in Swift raw strings that matches a literal backslash.
        let idPattern = "data-item-id=\"([a-p]{32})\""
        if let regex = try? NSRegularExpression(pattern: idPattern) {
            let ns = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                guard match.numberOfRanges >= 2,
                      let idRange = Range(match.range(at: 1), in: html) else { continue }
                let storeID = String(html[idRange])
                guard ChromeWebStoreAPI.isValidExtensionID(storeID), !seen.contains(storeID) else { continue }
                seen.insert(storeID)

                let start = match.range.location
                let end = min(ns.length, start + 2200)
                let chunk = ns.substring(with: NSRange(location: start, length: end - start))
                results.append(chromeItem(fromCardChunk: chunk, storeID: storeID, kind: kind))
            }
        }

        // Fallback: /detail/<slug>/<id> links (works even if card markup changes).
        if results.isEmpty {
            let detailPattern = "/detail/([A-Za-z0-9\\-]+)/([a-p]{32})"
            if let regex = try? NSRegularExpression(pattern: detailPattern) {
                let ns = html as NSString
                let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
                for match in matches {
                    guard match.numberOfRanges >= 3,
                          let slugRange = Range(match.range(at: 1), in: html),
                          let idRange = Range(match.range(at: 2), in: html) else { continue }
                    let slug = String(html[slugRange])
                    let storeID = String(html[idRange])
                    guard ChromeWebStoreAPI.isValidExtensionID(storeID), !seen.contains(storeID) else { continue }
                    seen.insert(storeID)
                    let name = slug
                        .replacingOccurrences(of: "-", with: " ")
                        .split(separator: " ")
                        .map(\.capitalized)
                        .joined(separator: " ")
                    results.append(
                        ExtensionStoreItem(
                            source: .chrome,
                            kind: kind,
                            storeIdentifier: storeID,
                            name: name,
                            summary: "",
                            iconURL: nil,
                            rating: nil,
                            storeURL: URL(string: "https://chromewebstore.google.com/detail/\(slug)/\(storeID)")
                        )
                    )
                }
            }
        }

        return results
    }

    private static func chromeItem(
        fromCardChunk chunk: String,
        storeID: String,
        kind: ExtensionStoreItem.Kind
    ) -> ExtensionStoreItem {
        let texts = chunk
            .replacingOccurrences(of: "<[^>]+>", with: "\n", options: .regularExpression)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let skip: Set<String> = [
            "Featured", "Remove", "Add to Chrome", "Toevoegen aan Chrome",
            "Verwijderen", "OK", "Sponsored", "Add to Oriel"
        ]
            let title = texts.first(where: { text in
            guard text.count >= 2, text.count <= 80 else { return false }
            if skip.contains(text) { return false }
            if Double(text) != nil { return false }
            if text.hasSuffix(".org") || text.hasSuffix(".com") || text.hasPrefix("www.") { return false }
            if text.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," || $0 == "+" }) { return false }
            return true
        }) ?? humanizeChromeSlug(from: chunk, storeID: storeID, kind: kind)

        let summary = texts.dropFirst().first(where: { text in
            text.count >= 12 && text.count <= 160
                && !skip.contains(text)
                && Double(text) == nil
                && text != title
        }) ?? ""

        let slug = chromeSlug(from: chunk, storeID: storeID)
        let storeURL: URL? = {
            if let slug, !slug.isEmpty {
                return URL(string: "https://chromewebstore.google.com/detail/\(slug)/\(storeID)")
            }
            return URL(string: "https://chromewebstore.google.com/detail/\(storeID)")
        }()

        return ExtensionStoreItem(
            source: .chrome,
            kind: kind,
            storeIdentifier: storeID,
            name: title,
            summary: summary,
            iconURL: nil,
            rating: nil,
            storeURL: storeURL
        )
    }

    private static func chromeSlug(from chunk: String, storeID: String) -> String? {
        let pattern = "/detail/([A-Za-z0-9\\-]+)/\(NSRegularExpression.escapedPattern(for: storeID))"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: chunk, range: NSRange(location: 0, length: (chunk as NSString).length)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: chunk) else {
            return nil
        }
        return String(chunk[range])
    }

    private static func humanizeChromeSlug(
        from chunk: String,
        storeID: String,
        kind: ExtensionStoreItem.Kind
    ) -> String {
        if let slug = chromeSlug(from: chunk, storeID: storeID) {
            return slug
                .replacingOccurrences(of: "-", with: " ")
                .split(separator: " ")
                .map(\.capitalized)
                .joined(separator: " ")
        }
        return kind == .theme ? "Chrome theme" : "Chrome extension"
    }
}
