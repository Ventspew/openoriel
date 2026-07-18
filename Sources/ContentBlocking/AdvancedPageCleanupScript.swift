import Foundation

/// Page cleanup for leftovers that slip past `WKContentRuleList` (Prisma/Larousse placers,
/// Viously players, OneTrust walls that AdGuard intentionally leaves on some sites).
enum AdvancedPageCleanupScript {
    static let source = #"""
    (function () {
      if (window.__orielPageCleanup) return;
      window.__orielPageCleanup = true;
      window.__orielPageCleanupKill = false;

      var AD_HOST = /(doubleclick\.net|googlesyndication\.com|googleadservices\.com|adnxs\.com|adsrvr\.org|amazon-adsystem\.com|outbrain\.com|taboola\.com|criteo\.(com|net)|pubmatic\.com|rubiconproject\.com|openx\.net|casalemedia\.com|moatads\.com|teads\.tv|mgid\.com|revcontent\.com|scorecardresearch\.com|quantserve\.com|popads\.net|exoclick\.com|juicyads\.com|propellerads\.com|media\.net|3lift\.com|bidswitch\.net|viously\.com|getviously\.com|sascdn\.com|smartadserver\.com|poool\.fr|poool-subscribe\.fr)/i;

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
        'ins.adsbygoogle',
        'div[id^="div-gpt-ad"]',
        'div[id^="google_ads_"]',
        'div[class*="adsbygoogle" i]',
        '[data-ad-slot]',
        '[data-google-query-id]',
        '[data-ads-core]',
        '.ads-core-placer',
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
        'aside[class*="advert" i]',
        'div[aria-label*="advertisement" i]',
        'div[aria-label*="Advertisement" i]',
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
            b.style.removeProperty('overflow');
            b.classList.remove('ot-noscroll', 'onetrust-no-scroll');
          }
          if (de) de.style.removeProperty('overflow');
        } catch (e) {}
      }

      function dismissConsentIfStuck() {
        // Prefer reject; otherwise strip the wall so the page is usable without accepting trackers.
        var reject = document.querySelector(
          '#onetrust-reject-all-handler, button[id*="reject" i], button[aria-label*="Refuse" i], button[aria-label*="Reject" i]'
        );
        if (reject) {
          try { reject.click(); } catch (e) {}
        }
      }

      function nuke() {
        if (window.__orielPageCleanupKill || !hostOK()) return;
        dismissConsentIfStuck();
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
        // Empty Prisma / Lagardère placers that keep reserved ad height
        var placers = document.querySelectorAll('.ads-core-placer, [data-ads-core]');
        for (var p = 0; p < placers.length; p++) {
          try {
            placers[p].style.setProperty('display', 'none', 'important');
            placers[p].style.setProperty('height', '0', 'important');
            placers[p].style.setProperty('min-height', '0', 'important');
            placers[p].remove();
          } catch (e) {}
        }
        unlockPage();
      }

      nuke();
      setInterval(nuke, 800);
      document.addEventListener('DOMContentLoaded', nuke, true);
    })();
    """#

    static let disableSource = "window.__orielPageCleanupKill = true;"
}
