import Foundation

enum FirefoxAddonsAPI {
    static let installURLScheme = "oriel-firefox-addon"

    /// Slug from `https://addons.mozilla.org/.../firefox/addon/<slug>/`
    static func slug(fromStoreURL url: URL) -> String? {
        let parts = url.path.split(separator: "/").map(String.init)
        guard let addonIndex = parts.firstIndex(of: "addon"),
              addonIndex + 1 < parts.count else { return nil }
        let slug = parts[addonIndex + 1]
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !slug.isEmpty, slug != "null" else { return nil }
        return slug
    }

    static func slug(fromInstallURL url: URL) -> String? {
        guard url.scheme?.lowercased() == installURLScheme else { return nil }
        if url.host?.lowercased() == "manage" { return nil }
        if let host = url.host, !host.isEmpty, host.lowercased() != "install" {
            return host
        }
        let parts = url.path.split(separator: "/").map(String.init)
        return parts.last(where: { !$0.isEmpty && $0.lowercased() != "install" })
    }

    static func isManageExtensionsURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == installURLScheme else { return false }
        return url.host?.lowercased() == "manage"
    }

    static func installURL(forSlug slug: String) -> URL? {
        let trimmed = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "\(installURLScheme)://install/\(trimmed)")
    }

    /// AMO API v5 addon detail → current signed XPI URL.
    static func detailURL(forSlugOrID slugOrID: String) -> URL? {
        let encoded = slugOrID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slugOrID
        return URL(string: "https://addons.mozilla.org/api/v5/addons/addon/\(encoded)/")
    }

    static func xpiURL(fromDetailJSON data: Data) -> URL? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let current = root["current_version"] as? [String: Any] {
            if let file = current["file"] as? [String: Any],
               let urlString = file["url"] as? String,
               let url = URL(string: urlString) {
                return url
            }
            // Older AMO payloads used `files: [{url}]`.
            if let files = current["files"] as? [[String: Any]],
               let urlString = files.first?["url"] as? String,
               let url = URL(string: urlString) {
                return url
            }
        }
        return nil
    }

    static func displayName(fromDetailJSON data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = root["name"] as? [String: Any] else { return nil }
        return (name["en-US"] as? String) ?? (name.values.first as? String)
    }
}

/// Injected into addons.mozilla.org so “Add to Firefox” becomes installable in Oriel.
enum FirefoxAddonsBridge {
    static let handlerName = "orielInstallFirefoxAddon"

    static let userScriptSource = #"""
    (function () {
      if (window.__orielFirefoxAddonsBridge) return;
      window.__orielFirefoxAddonsBridge = true;
      var h = location.hostname;
      if (h !== 'addons.mozilla.org' && h !== 'addons-dev.allizom.org') return;

      function slugFromPath() {
        var parts = location.pathname.split('/').filter(Boolean);
        var idx = parts.indexOf('addon');
        if (idx >= 0 && parts[idx + 1]) return parts[idx + 1];
        return null;
      }

      function postInstall(slug) {
        if (!slug) return;
        try {
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.orielInstallFirefoxAddon) {
            window.webkit.messageHandlers.orielInstallFirefoxAddon.postMessage(String(slug));
            return;
          }
        } catch (e) {}
        try {
          var a = document.createElement('a');
          a.href = 'oriel-firefox-addon://install/' + encodeURIComponent(slug);
          a.rel = 'noreferrer';
          a.style.display = 'none';
          document.documentElement.appendChild(a);
          a.click();
          a.remove();
        } catch (e2) {}
      }
      window.__orielPostFirefoxInstall = postInstall;

      function relabel() {
        var slug = slugFromPath();
        if (!slug) return;
        var buttons = document.querySelectorAll(
          'button, a, .InstallButtonWrapper a, .AMInstallButton-button, [class*="InstallButton"]'
        );
        buttons.forEach(function (el) {
          var text = (el.textContent || '').trim();
          if (!/add to firefox|download file|install theme|add theme/i.test(text)) return;
          if (el.dataset.orielFirefoxBound === '1') return;
          el.dataset.orielFirefoxBound = '1';
          try {
            el.textContent = /theme/i.test(text) ? 'Add theme to Oriel' : 'Add to Oriel';
          } catch (e) {}
          el.addEventListener('click', function (ev) {
            ev.preventDefault();
            ev.stopPropagation();
            postInstall(slug);
          }, true);
        });
      }

      relabel();
      var obs = new MutationObserver(function () { relabel(); });
      obs.observe(document.documentElement, { childList: true, subtree: true });
    })();
    """#
}
