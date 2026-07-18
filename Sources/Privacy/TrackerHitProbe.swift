import Foundation

/// Document-start probe that counts tracker URL loads WebKit’s content blocker won’t report.
enum TrackerHitProbe {
    static let handlerName = "orielTrackerHit"

    /// High-signal tracker / ad / analytics hosts used when rule-list hints aren’t ready yet.
    static let seedHosts: [String] = [
        "doubleclick.net", "googlesyndication.com", "googleadservices.com", "google-analytics.com",
        "googletagmanager.com", "googletagservices.com", "googleoptimize.com", "adservice.google.com",
        "pagead2.googlesyndication.com", "fundingchoicesmessages.google.com",
        "facebook.net", "facebook.com", "fbcdn.net", "connect.facebook.net",
        "scorecardresearch.com", "quantserve.com", "outbrain.com", "taboola.com", "criteo.com",
        "adsrvr.org", "adnxs.com", "ads-twitter.com", "analytics.twitter.com", "t.co",
        "hotjar.com", "fullstory.com", "mouseflow.com", "clarity.ms",
        "segment.io", "segment.com", "mixpanel.com", "amplitude.com", "newrelic.com",
        "nr-data.net", "sentry.io", "bugsnag.com",
        "cookiebot.com", "cookielaw.org", "onetrust.com", "trustarc.com", "consensu.org",
        "moatads.com", "amazon-adsystem.com", "media.net", "openx.net", "pubmatic.com",
        "rubiconproject.com", "casalemedia.com", "bidswitch.net", "smartadserver.com",
        "yieldmo.com", "sharethrough.com", "3lift.com", "liadm.com", "tapad.com",
        "branch.io", "appsflyer.com", "adjust.com", "kochava.com",
        "yandex.ru", "mc.yandex.ru", "an.yandex.ru",
        "bat.bing.com", "bing.com", "ads.linkedin.com", "snap.licdn.com",
        "tiktok.com", "analytics.tiktok.com", "byteoversea.com",
        "pinterest.com", "pinimg.com", "ads.pinterest.com",
        "chartbeat.com", "parse.ly", "parsely.com", "permutive.com",
        "bluekai.com", "exelator.com", "krxd.net", "demdex.net", "omtrdc.net",
        "2mdn.net", "adsafeprotected.com", "serving-sys.com", "innovid.com"
    ]

    static func userScriptSource(hosts: [String]) -> String {
        let unique = Array(Set(hosts.map { $0.lowercased() }.filter { !$0.isEmpty })).sorted()
        let payload: String
        if let data = try? JSONSerialization.data(withJSONObject: unique),
           let json = String(data: data, encoding: .utf8) {
            payload = json
        } else {
            payload = "[]"
        }

        return """
        (function() {
          if (window.__orielTrackerProbe) return;
          window.__orielTrackerProbe = true;
          var hosts = \(payload);
          var seen = Object.create(null);
          var hostSet = Object.create(null);
          for (var i = 0; i < hosts.length; i++) hostSet[hosts[i]] = true;

          function hostnameOf(raw) {
            try { return new URL(String(raw), location.href).hostname.toLowerCase(); }
            catch (e) { return ''; }
          }

          function isTrackerHost(hostname) {
            if (!hostname) return false;
            if (hostSet[hostname]) return true;
            var parts = hostname.split('.');
            for (var i = 0; i < parts.length - 1; i++) {
              var suffix = parts.slice(i).join('.');
              if (hostSet[suffix]) return true;
            }
            return false;
          }

          function report(raw, kind) {
            try {
              var abs = new URL(String(raw), location.href);
              var host = abs.hostname.toLowerCase();
              if (!isTrackerHost(host)) return;
              if (host === location.hostname.toLowerCase()) return;
              var key = abs.origin + abs.pathname;
              if (seen[key]) return;
              seen[key] = 1;
              if (window.webkit && webkit.messageHandlers && webkit.messageHandlers.\(handlerName)) {
                webkit.messageHandlers.\(handlerName).postMessage({
                  u: abs.href,
                  h: host,
                  k: kind || 'tracker'
                });
              }
            } catch (e) {}
          }

          var _fetch = window.fetch;
          if (typeof _fetch === 'function') {
            window.fetch = function(input, init) {
              try {
                var url = (typeof input === 'string') ? input : (input && input.url);
                if (url) report(url, 'fetch');
              } catch (e) {}
              return _fetch.apply(this, arguments);
            };
          }

          var XO = XMLHttpRequest.prototype.open;
          XMLHttpRequest.prototype.open = function(method, url) {
            try { if (url) report(url, 'xhr'); } catch (e) {}
            return XO.apply(this, arguments);
          };

          function hookSrc(proto) {
            var desc = Object.getOwnPropertyDescriptor(proto, 'src');
            if (!desc || !desc.set) return;
            var original = desc.set;
            Object.defineProperty(proto, 'src', {
              configurable: true,
              enumerable: desc.enumerable,
              get: desc.get,
              set: function(v) {
                try { if (v) report(v, 'src'); } catch (e) {}
                return original.call(this, v);
              }
            });
          }
          try { hookSrc(HTMLImageElement.prototype); } catch (e) {}
          try { hookSrc(HTMLScriptElement.prototype); } catch (e) {}
          try { hookSrc(HTMLIFrameElement.prototype); } catch (e) {}
          try { hookSrc(HTMLSourceElement.prototype); } catch (e) {}

          var SA = Element.prototype.setAttribute;
          Element.prototype.setAttribute = function(name, value) {
            try {
              var n = String(name || '').toLowerCase();
              if ((n === 'src' || n === 'href' || n === 'data-src') && value) report(value, 'attr');
            } catch (e) {}
            return SA.apply(this, arguments);
          };

          try {
            new MutationObserver(function(muts) {
              for (var i = 0; i < muts.length; i++) {
                var nodes = muts[i].addedNodes;
                for (var j = 0; j < nodes.length; j++) {
                  var n = nodes[j];
                  if (!n || n.nodeType !== 1) continue;
                  var src = n.src || n.href || (n.getAttribute && (n.getAttribute('src') || n.getAttribute('data-src')));
                  if (src) report(src, 'dom');
                  if (n.querySelectorAll) {
                    var nested = n.querySelectorAll('[src],[href],[data-src]');
                    for (var k = 0; k < nested.length; k++) {
                      var el = nested[k];
                      var u = el.src || el.href || el.getAttribute('data-src');
                      if (u) report(u, 'dom');
                    }
                  }
                }
              }
            }).observe(document.documentElement || document, { childList: true, subtree: true });
          } catch (e) {}
        })();
        """
    }
}
