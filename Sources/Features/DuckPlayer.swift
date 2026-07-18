import Foundation

/// YouTube “Duck Player” style clean watch experience using youtube-nocookie embeds.
enum DuckPlayer {
    static func videoID(from url: URL) -> String? {
        let host = (url.host ?? "").lowercased()
        guard host.contains("youtube.com") || host == "youtu.be" || host.contains("youtube-nocookie.com") else {
            return nil
        }
        if host == "youtu.be" {
            let id = url.path.split(separator: "/").first.map(String.init)
            return validID(id)
        }
        if url.path.hasPrefix("/embed/") || url.path.hasPrefix("/shorts/") {
            let id = url.path.split(separator: "/").dropFirst().first.map(String.init)
            return validID(id)
        }
        if let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let v = items.first(where: { $0.name == "v" })?.value {
            return validID(v)
        }
        return nil
    }

    static func isYouTubeWatchURL(_ url: URL) -> Bool {
        videoID(from: url) != nil && !(url.host ?? "").contains("youtube-nocookie.com")
    }

    static func playerURL(forVideoID id: String) -> URL {
        var components = URLComponents()
        components.scheme = BrowserConstants.aboutScheme
        components.host = "player"
        components.path = "/\(id)"
        return components.url ?? URL(string: "\(BrowserConstants.aboutScheme)://player/\(id)")!
    }

    static func embedHTML(videoID: String) -> String {
        let safe = videoID.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        return """
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
          <title>Oriel Player</title>
          <style>
            :root { color-scheme: light dark; }
            html, body { margin: 0; height: 100%; background: #0d0d0f; color: #f2f2f2; font: 16px/1.4 -apple-system, BlinkMacSystemFont, sans-serif; }
            .wrap { min-height: 100%; display: flex; flex-direction: column; }
            header { padding: 14px 18px; display: flex; gap: 12px; align-items: center; justify-content: space-between; background: rgba(255,255,255,0.04); }
            header a { color: #8ec8ff; text-decoration: none; font-weight: 600; }
            .frame { flex: 1; display: flex; }
            iframe { border: 0; width: 100%; height: 100%; min-height: 70vh; background: #000; }
            .note { padding: 10px 18px 18px; color: #a7a7ad; font-size: 13px; }
          </style>
        </head>
        <body>
          <div class="wrap">
            <header>
              <strong>Oriel Player</strong>
              <a href="https://www.youtube-nocookie.com/embed/\(safe)?rel=0&modestbranding=1">Open embed</a>
            </header>
            <div class="frame">
              <iframe
                src="https://www.youtube-nocookie.com/embed/\(safe)?rel=0&modestbranding=1&playsinline=1"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                allowfullscreen
                referrerpolicy="strict-origin-when-cross-origin"
                title="Oriel Player"></iframe>
            </div>
            <p class="note">Playing via youtube-nocookie without the full YouTube browsing chrome.</p>
          </div>
        </body>
        </html>
        """
    }

    private static func validID(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let cleaned = raw.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
        guard (8...20).contains(cleaned.count) else { return nil }
        return cleaned
    }
}
