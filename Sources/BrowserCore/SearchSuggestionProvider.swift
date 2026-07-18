import Foundation

struct SearchSuggestion: Identifiable, Equatable, Sendable {
    enum Source: String, Sendable {
        case history
        case bookmark
        case remote
    }

    let id: String
    let text: String
    let url: URL?
    let source: Source

    init(text: String, url: URL? = nil, source: Source) {
        self.text = text
        self.url = url
        self.source = source
        if let url {
            self.id = "\(source.rawValue):\(url.absoluteString)"
        } else {
            self.id = "\(source.rawValue):\(text.lowercased())"
        }
    }
}

/// Fetches address-bar suggestions from local history/bookmarks plus engine suggest APIs.
@MainActor
final class SearchSuggestionProvider {
    private var task: Task<[SearchSuggestion], Never>?
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    func suggestions(
        for rawQuery: String,
        engine: SearchEngine,
        history: HistoryStore,
        bookmarks: BookmarkStore,
        limit: Int = 8
    ) async -> [SearchSuggestion] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }

        task?.cancel()
        let work = Task { () -> [SearchSuggestion] in
            var merged: [SearchSuggestion] = []
            var seen = Set<String>()

            func append(_ item: SearchSuggestion) {
                let key = item.url?.absoluteString.lowercased() ?? item.text.lowercased()
                guard seen.insert(key).inserted else { return }
                merged.append(item)
            }

            for bookmark in bookmarks.search(query).prefix(3) {
                append(SearchSuggestion(text: bookmark.title, url: bookmark.url, source: .bookmark))
            }
            for entry in history.search(query).prefix(3) {
                append(SearchSuggestion(text: entry.title, url: entry.url, source: .history))
            }

            if Task.isCancelled { return Array(merged.prefix(limit)) }

            let remote = await Self.fetchRemote(query: query, engine: engine, session: session)
            for text in remote {
                if Task.isCancelled { break }
                append(SearchSuggestion(text: text, url: nil, source: .remote))
            }

            return Array(merged.prefix(limit))
        }
        task = work
        return await work.value
    }

    private static func fetchRemote(query: String, engine: SearchEngine, session: URLSession) async -> [String] {
        guard let url = engine.suggestionURL(for: query) else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 4
        request.setValue("Oriel/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1")", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return []
            }
            return parseSuggestionPayload(data, engine: engine)
        } catch {
            return []
        }
    }

    private static func parseSuggestionPayload(_ data: Data, engine: SearchEngine) -> [String] {
        // Most engines return JSON arrays: [query, [suggestions...], ...]
        if let array = try? JSONSerialization.jsonObject(with: data) as? [Any] {
            if let phrases = array.dropFirst().first as? [String] {
                return phrases.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            }
            if let phrases = array.dropFirst().first as? [Any] {
                return phrases.compactMap { item -> String? in
                    if let text = item as? String { return text }
                    if let pair = item as? [Any], let text = pair.first as? String { return text }
                    if let dict = item as? [String: Any], let phrase = dict["phrase"] as? String { return phrase }
                    return nil
                }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            }
        }
        // DuckDuckGo typed list: [{"phrase":"..."}]
        if engine == .duckDuckGo,
           let objects = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return objects.compactMap { $0["phrase"] as? String }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }
}

extension SearchEngine {
    func suggestionURL(for query: String) -> URL? {
        var components: URLComponents
        switch self {
        case .duckDuckGo:
            components = URLComponents(string: "https://duckduckgo.com/ac/")!
            components.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "type", value: "list")
            ]
        case .google:
            components = URLComponents(string: "https://suggestqueries.google.com/complete/search")!
            components.queryItems = [
                URLQueryItem(name: "client", value: "firefox"),
                URLQueryItem(name: "q", value: query)
            ]
        case .bing:
            components = URLComponents(string: "https://api.bing.com/osjson.aspx")!
            components.queryItems = [URLQueryItem(name: "query", value: query)]
        case .ecosia:
            components = URLComponents(string: "https://ac.ecosia.org/autocomplete")!
            components.queryItems = [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "type", value: "list")
            ]
        }
        return components.url
    }
}
