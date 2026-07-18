import Foundation

/// Network lists miss first-party placeholders and AdGuard exceptions (e.g. TheMoneytizer gen.js).
/// Document-start stubs + aggressive DOM cleanup for publisher stacks like Larousse/Prisma.
enum AdvancedPageCleanupScript {
    /// Runs before GTM / Hubvisor / consent SDKs.
    static let documentStartSource = #"""
    (function () {
      var h = (location.hostname || '').toLowerCase();
      var isLarousse = h === 'larousse.fr' || h.endsWith('.larousse.fr');
      if (!isLarousse) return;
      if (window.__orielLarousseKillInstalled) return;
      window.__orielLarousseKillInstalled = true;

      function stubFn() {
        var f = function () { return f; };
        f.cmd = { push: function (x) { try { if (typeof x === 'function') x(); } catch (e) {} } };
        f.que = f.cmd;
        f.push = f.cmd.push;
        return f;
      }

      try {
        Object.defineProperty(window, 'Hubvisor', { configurable: true, get: stubFn, set: function () {} });
      } catch (e) { window.Hubvisor = stubFn(); }

      try {
        var gt = window.googletag = window.googletag || {};
        gt.cmd = gt.cmd || [];
        var _push = Array.prototype.push;
        gt.cmd.push = function () { return 0; };
        gt.pubads = function () {
          return {
            enableSingleRequest: function () {},
            collapseEmptyDivs: function () {},
            setTargeting: function () {},
            addEventListener: function () {},
            getSlots: function () { return []; }
          };
        };
        gt.defineSlot = function () { return { addService: function () { return this; } }; };
        gt.display = function () {};
        gt.enableServices = function () {};
      } catch (e) {}

      // Starve postscribe document.write ad injection
      try {
        var _ps;
        Object.defineProperty(window, 'postscribe', {
          configurable: true,
          get: function () { return function () {}; },
          set: function (v) { _ps = function () {}; }
        });
      } catch (e) { window.postscribe = function () {}; }
    })();
    """#

    static let source = #"""
    (function () {
      if (window.__orielPageCleanup) return;
      window.__orielPageCleanup = true;
      window.__orielPageCleanupKill = false;

      var AD_HOST = /(doubleclick\.net|googlesyndication\.com|googleadservices\.com|adnxs\.com|adsrvr\.org|amazon-adsystem\.com|outbrain\.com|taboola\.com|criteo\.(com|net)|pubmatic\.com|rubiconproject\.com|openx\.net|casalemedia\.com|moatads\.com|teads\.tv|mgid\.com|revcontent\.com|scorecardresearch\.com|quantserve\.com|popads\.net|exoclick\.com|juicyads\.com|propellerads\.com|media\.net|3lift\.com|bidswitch\.net|viously\.com|getviously\.com|sascdn\.com|smartadserver\.com|poool\.fr|poool-subscribe\.fr|themoneytizer\.com|hubvisor\.io|seedtag\.com|ayads\.co|sprkly\.me)/i;

      var KILL_SEL = [
        'iframe[id*="google_ads" i]',
        'iframe[src*="doubleclick" i]',
        'iframe[src*="googlesyndication" i]',
        'iframe[src*="adnxs" i]',
        'iframe[src*="outbrain" i]',
        'iframe[src*="taboola" i]',
        'iframe[src*="viously" i]',
        'iframe[src*="sascdn" i]',
        'iframe[src*="smartadserver" i]',
        'iframe[src*="poool" i]',
        'iframe[src*="themoneytizer" i]',
        'iframe[src*="hubvisor" i]',
        'iframe[src*="seedtag" i]',
        'ins.adsbygoogle',
        'div[id^="div-gpt-ad"]',
        'div[id^="google_ads_"]',
        'div[class*="adsbygoogle" i]',
        '[data-ad-slot]',
        '[data-google-query-id]',
        '[data-ads-core]',
        '.ads-core-placer',
        '#top-pave_prisma',
        '.taboola-wrapper',
        '.OUTBRAIN',
        '#taboola-below-article-thumbnails',
        'div[id*="taboola" i]',
        'div[class*="taboola" i]',
        'div[id*="outbrain" i]',
        '#poool-widget',
        '#poool-widget-content',
        '.poool-widget',
        '.poool-overlay',
        '[id^="poool"]',
        '.viously',
        '.viously-player',
        '.viously-ui-container',
        '.viously-sticked',
        '[class*="viously" i]',
        'img[src*="encart_pub"]',
        'a[href*="encart_pub"]',
        'aside[class*="advert" i]',
        'div[aria-label*="advertisement" i]',
        '#onetrust-banner-sdk',
        '#onetrust-consent-sdk',
        '.onetrust-pc-dark-filter',
        '.ui-widget-overlay'
      ].join(',');

      function hostOK() {
        var h = (location.hostname || '').toLowerCase();
        if (!h) return false;
        if (/(^|\.)(accounts\.google|appleid\.apple|login\.live|paypal|stripe|bank|github)\./.test(h)) return false;
        return true;
      }

      function unlockPage() {
        try {
          var b = document.body;
          var de = document.documentElement;
          if (b) {
            b.style.setProperty('overflow', 'auto', 'important');
            b.classList.remove('ot-noscroll', 'onetrust-no-scroll');
          }
          if (de) de.style.setProperty('overflow', 'auto', 'important');
        } catch (e) {}
      }

      function nuke() {
        if (window.__orielPageCleanupKill || !hostOK()) return;
        var nodes = document.querySelectorAll(KILL_SEL);
        for (var i = 0; i < nodes.length; i++) {
          try { nodes[i].remove(); } catch (e) {}
        }
        var iframes = document.querySelectorAll('iframe[src]');
        for (var j = 0; j < iframes.length; j++) {
          var src = iframes[j].getAttribute('src') || '';
          if (AD_HOST.test(src)) {
            try { iframes[j].remove(); } catch (e) {}
          }
        }
        var placers = document.querySelectorAll('.ads-core-placer, [data-ads-core], #top-pave_prisma');
        for (var p = 0; p < placers.length; p++) {
          try { placers[p].remove(); } catch (e) {}
        }
        // First-party promo strip on Larousse
        var pubs = document.querySelectorAll('img[src*="encart_pub"], a[href*="encart_pub"]');
        for (var q = 0; q < pubs.length; q++) {
          try {
            var box = pubs[q].closest('div,aside,section,article') || pubs[q];
            box.remove();
          } catch (e) {}
        }
        unlockPage();
      }

      nuke();
      setInterval(nuke, 600);
      document.addEventListener('DOMContentLoaded', nuke, true);
      var scheduled = false;
      try {
        new MutationObserver(function () {
          if (scheduled) return;
          scheduled = true;
          setTimeout(function () { scheduled = false; nuke(); }, 250);
        }).observe(document.documentElement, { childList: true, subtree: true });
      } catch (e) {}
    })();
    """#

    static let disableSource = "window.__orielPageCleanupKill = true;"
}
