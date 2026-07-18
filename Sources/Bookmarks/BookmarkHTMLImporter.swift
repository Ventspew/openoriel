import Foundation

enum BookmarkHTMLImporter {
    enum Node: Equatable {
        case folder(title: String, children: [Node])
        case bookmark(title: String, url: URL)
    }

    struct ImportedBookmark: Equatable {
        var title: String
        var url: URL
    }

    /// Flat parse kept for older call sites / tests.
    static func parse(_ html: String) -> [ImportedBookmark] {
        flatten(parseTree(html)).map { ImportedBookmark(title: $0.title, url: $0.url) }
    }

    private struct FlatItem {
        var title: String
        var url: URL
    }

    private static func flatten(_ nodes: [Node]) -> [FlatItem] {
        var out: [FlatItem] = []
        for node in nodes {
            switch node {
            case .bookmark(let title, let url):
                out.append(FlatItem(title: title, url: url))
            case .folder(_, let children):
                out.append(contentsOf: flatten(children))
            }
        }
        return out
    }

    /// Parses Netscape-bookmark HTML into a folder tree when possible.
    static func parseTree(_ html: String) -> [Node] {
        // Tokenize roughly on DT / DL / H3 / A tags.
        let pattern = #"(?is)(<DL\b[^>]*>|</DL\s*>|<DT\b[^>]*>|<H3\b[^>]*>(.*?)</H3>|<A\b[^>]*HREF\s*=\s*["']([^"']+)["'][^>]*>(.*?)</A>)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return parseFlatAsRoot(html)
        }

        struct Frame {
            var title: String?
            var children: [Node] = []
        }

        var stack: [Frame] = [Frame()]
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let matches = regex.matches(in: html, options: [], range: range)

        guard !matches.isEmpty else {
            return parseFlatAsRoot(html)
        }

        for match in matches {
            let full = String(html[Range(match.range, in: html)!]).trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = full.uppercased()

            if upper.hasPrefix("<DL") {
                continue
            }
            if upper.hasPrefix("</DL") {
                guard stack.count > 1 else { continue }
                let finished = stack.removeLast()
                let title = finished.title ?? "Folder"
                stack[stack.count - 1].children.append(.folder(title: title, children: finished.children))
                continue
            }
            if match.numberOfRanges >= 3, match.range(at: 2).location != NSNotFound,
               let titleRange = Range(match.range(at: 2), in: html) {
                // H3 folder title — open a new frame when next DL arrives; stash title on current pending.
                let title = decode(String(html[titleRange]))
                stack.append(Frame(title: title.isEmpty ? "Folder" : title, children: []))
                continue
            }
            if match.numberOfRanges >= 5,
               match.range(at: 3).location != NSNotFound,
               match.range(at: 4).location != NSNotFound,
               let urlRange = Range(match.range(at: 3), in: html),
               let titleRange = Range(match.range(at: 4), in: html),
               let url = URL(string: String(html[urlRange])),
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                let rawTitle = decode(String(html[titleRange]))
                let title = rawTitle.isEmpty ? (url.host ?? url.absoluteString) : rawTitle
                stack[stack.count - 1].children.append(.bookmark(title: title, url: url))
            }
        }

        // Collapse leftover nested frames.
        while stack.count > 1 {
            let finished = stack.removeLast()
            let title = finished.title ?? "Folder"
            stack[stack.count - 1].children.append(.folder(title: title, children: finished.children))
        }

        let root = stack[0].children
        return root.isEmpty ? parseFlatAsRoot(html) : root
    }

    private static func parseFlatAsRoot(_ html: String) -> [Node] {
        // <A HREF="url" ...>title</A>
        let pattern = #"<a[^>]*href=["']([^"']+)["'][^>]*>(.*?)</a>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        var results: [Node] = []
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        regex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
            guard let match,
                  let urlRange = Range(match.range(at: 1), in: html),
                  let titleRange = Range(match.range(at: 2), in: html),
                  let url = URL(string: String(html[urlRange])),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https"
            else { return }
            let rawTitle = decode(String(html[titleRange]))
            let title = rawTitle.isEmpty ? (url.host ?? url.absoluteString) : rawTitle
            results.append(.bookmark(title: title, url: url))
        }
        return results
    }

    private static func decode(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
