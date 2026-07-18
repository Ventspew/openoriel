import Foundation

enum BookmarkHTMLExporter {
    /// Netscape Bookmark File Format — compatible with Chrome, Firefox, Safari, Brave, Opera.
    static func export(items: [Bookmark], rootTitle: String = "Oriel Bookmarks") -> String {
        var lines: [String] = [
            "<!DOCTYPE NETSCAPE-Bookmark-file-1>",
            "<!-- This is an automatically generated file.",
            "     It will be read and overwritten.",
            "     DO NOT EDIT! -->",
            "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">",
            "<TITLE>Bookmarks</TITLE>",
            "<H1>\(escape(rootTitle))</H1>",
            "<DL><p>"
        ]

        let rootItems = items
            .filter { $0.parentID == nil }
            .sorted(by: sort)

        for item in rootItems {
            append(item, all: items, into: &lines, depth: 1)
        }

        lines.append("</DL><p>")
        return lines.joined(separator: "\n")
    }

    private static func sort(_ lhs: Bookmark, _ rhs: Bookmark) -> Bool {
        if lhs.isFolder != rhs.isFolder { return lhs.isFolder && !rhs.isFolder }
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        return lhs.createdAt < rhs.createdAt
    }

    private static func append(_ item: Bookmark, all: [Bookmark], into lines: inout [String], depth: Int) {
        let indent = String(repeating: "    ", count: depth)
        if item.isFolder {
            lines.append("\(indent)<DT><H3>\(escape(item.title))</H3>")
            lines.append("\(indent)<DL><p>")
            let children = all.filter { $0.parentID == item.id }.sorted(by: sort)
            for child in children {
                append(child, all: all, into: &lines, depth: depth + 1)
            }
            lines.append("\(indent)</DL><p>")
        } else if let url = item.urlString {
            lines.append("\(indent)<DT><A HREF=\"\(escape(url))\">\(escape(item.title))</A>")
        }
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
