import Foundation

enum PageTranslator {
    enum Provider: String, CaseIterable, Identifiable, Codable, Sendable {
        case libreTranslate

        var id: String { rawValue }
        var displayName: String { "LibreTranslate" }
    }

    static let extractTextScript = #"""
    (function() {
      function walk(node, out) {
        if (!node) return;
        if (node.nodeType === Node.TEXT_NODE) {
          var t = node.nodeValue;
          if (t && t.trim().length > 0) out.push(t);
          return;
        }
        if (node.nodeType !== Node.ELEMENT_NODE) return;
        var tag = node.tagName;
        if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'NOSCRIPT' || tag === 'SVG') return;
        for (var i = 0; i < node.childNodes.length; i++) walk(node.childNodes[i], out);
      }
      var parts = [];
      walk(document.body, parts);
      return parts.slice(0, 250).join('\n<<<ORIEL>>>\n');
    })();
    """#

    static func applyTranslationScript(replacements: [String: String]) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: replacements)) ?? Data("{}".utf8)
        let json = String(data: data, encoding: .utf8) ?? "{}"
        return """
        (function() {
          var map = \(json);
          function replaceText(node) {
            if (!node) return;
            if (node.nodeType === Node.TEXT_NODE) {
              var key = node.nodeValue;
              if (key && map[key]) node.nodeValue = map[key];
              return;
            }
            if (node.nodeType !== Node.ELEMENT_NODE) return;
            var tag = node.tagName;
            if (tag === 'SCRIPT' || tag === 'STYLE' || tag === 'NOSCRIPT') return;
            for (var i = 0; i < node.childNodes.length; i++) replaceText(node.childNodes[i]);
          }
          replaceText(document.body);
          return true;
        })();
        """
    }

    static func translateChunks(_ chunks: [String], target: String) async -> [String: String] {
        var map: [String: String] = [:]
        // Batch to keep requests small.
        for chunk in chunks where chunk.trimmingCharacters(in: .whitespacesAndNewlines).count > 1 {
            if let translated = await translateOne(chunk, target: target) {
                map[chunk] = translated
            }
        }
        return map
    }

    private static func translateOne(_ text: String, target: String) async -> String? {
        var request = URLRequest(url: URL(string: "https://libretranslate.com/translate")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "q": String(text.prefix(4500)),
            "source": "auto",
            "target": target,
            "format": "text"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 25
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let translated = obj["translatedText"] as? String {
                return translated
            }
        } catch {
            return nil
        }
        return nil
    }
}
