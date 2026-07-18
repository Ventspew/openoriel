import Foundation

/// Detects Web App Manifest links and builds a lightweight “Install” record.
struct ProgressiveWebAppInfo: Equatable, Sendable {
    var name: String
    var startURL: URL
    var manifestURL: URL?
    var iconURL: URL?
}

enum ProgressiveWebAppDetector {
    static let detectScript = #"""
    (function() {
      var link = document.querySelector('link[rel="manifest"]');
      if (!link) return null;
      var icon = document.querySelector('link[rel="apple-touch-icon"], link[rel="icon"]');
      return {
        manifestHref: link.href || null,
        iconHref: icon ? icon.href : null,
        title: document.title || location.hostname
      };
    })();
    """#

    static func parseDetectResult(_ any: Any?, pageURL: URL) -> ProgressiveWebAppInfo? {
        guard let dict = any as? [String: Any] else { return nil }
        let title = (dict["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = (title?.isEmpty == false ? title! : (pageURL.host ?? "Web App"))
        let manifestHref = dict["manifestHref"] as? String
        let iconHref = dict["iconHref"] as? String
        return ProgressiveWebAppInfo(
            name: name,
            startURL: pageURL,
            manifestURL: manifestHref.flatMap(URL.init(string:)),
            iconURL: iconHref.flatMap(URL.init(string:))
        )
    }
}

@Observable
@MainActor
final class InstalledWebAppStore {
    private(set) var apps: [ProgressiveWebAppInfo] = []
    private let fileName = "installed-webapps.json"

    private struct Record: Codable {
        var name: String
        var startURL: String
        var manifestURL: String?
        var iconURL: String?
    }

    init() {
        if let loaded = try? JSONFileStore.load([Record].self, from: fileName) {
            apps = loaded.compactMap { row in
                guard let start = URL(string: row.startURL) else { return nil }
                return ProgressiveWebAppInfo(
                    name: row.name,
                    startURL: start,
                    manifestURL: row.manifestURL.flatMap(URL.init(string:)),
                    iconURL: row.iconURL.flatMap(URL.init(string:))
                )
            }
        }
    }

    func install(_ info: ProgressiveWebAppInfo) {
        apps.removeAll { $0.startURL == info.startURL }
        apps.insert(info, at: 0)
        persist()
    }

    func remove(startURL: URL) {
        apps.removeAll { $0.startURL == startURL }
        persist()
    }

    private func persist() {
        let rows = apps.map {
            Record(
                name: $0.name,
                startURL: $0.startURL.absoluteString,
                manifestURL: $0.manifestURL?.absoluteString,
                iconURL: $0.iconURL?.absoluteString
            )
        }
        try? JSONFileStore.save(rows, to: fileName)
    }
}
