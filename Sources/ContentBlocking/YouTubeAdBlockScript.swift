import Foundation

/// Injected when Oriel Shields are on — skips/hides YouTube *ads* without breaking the homepage feed.
enum YouTubeAdBlockScript {
    static let source = #"""
    (function () {
      function hostOK() {
        var h = (location.hostname || '').toLowerCase();
        return h === 'www.youtube.com' || h === 'youtube.com' || h === 'm.youtube.com'
          || h === 'youtube-nocookie.com' || h === 'www.youtube-nocookie.com'
          || h.endsWith('.youtube.com') || h.endsWith('.youtube-nocookie.com');
      }
      if (!hostOK()) return;
      window.__orielYouTubeAdBlockKill = false;
      if (window.__orielYouTubeAdBlockInstalled) return;
      window.__orielYouTubeAdBlockInstalled = true;

      function isWatchContext() {
        var p = location.pathname || '';
        return p.indexOf('/watch') === 0 || p.indexOf('/shorts/') === 0 || p.indexOf('/embed/') === 0;
      }

      function clickSkip() {
        var selectors = [
          '.ytp-ad-skip-button',
          '.ytp-ad-skip-button-modern',
          '.ytp-skip-ad-button',
          '.ytp-ad-skip-button-container button',
          'button.ytp-ad-skip-button-modern'
        ];
        for (var i = 0; i < selectors.length; i++) {
          var btn = document.querySelector(selectors[i]);
          if (!btn) continue;
          var style = window.getComputedStyle(btn);
          if (style && (style.display === 'none' || style.visibility === 'hidden')) continue;
          try { btn.click(); } catch (e) {}
        }
      }

      function nukeAdSlots() {
        var kill = document.querySelectorAll([
          'ytd-ad-slot-renderer',
          'ytd-promoted-sparkles-web-renderer',
          'ytd-player-legacy-desktop-watch-ads-renderer',
          'ytd-in-feed-ad-layout-renderer',
          'ytd-action-companion-ad-renderer',
          'ytd-display-ad-renderer',
          'ytd-banner-promo-renderer',
          '#player-ads',
          '#masthead-ad',
          '.ytp-ad-module',
          '.ytp-ad-overlay-container',
          '.ytp-ad-player-overlay',
          '.ytp-ad-action-interstitial',
          '.ytp-ad-image-overlay'
        ].join(','));
        for (var i = 0; i < kill.length; i++) {
          try { kill[i].remove(); } catch (e) {}
        }
      }

      function skipPlayerAd() {
        if (!isWatchContext()) return;
        var player = document.querySelector('.html5-video-player');
        var video = document.querySelector('video.html5-main-video');
        if (!player || !video) return;
        var adShowing = player.classList.contains('ad-showing')
          || player.classList.contains('ad-interrupting')
          || !!document.querySelector('.ytp-ad-player-overlay, .ytp-ad-preview-container');
        if (!adShowing) {
          try { if (video.playbackRate > 2) video.playbackRate = 1; } catch (e) {}
          return;
        }
        clickSkip();
        try {
          video.muted = true;
          if (video.duration && isFinite(video.duration) && video.duration > 0 && video.duration < 120) {
            video.playbackRate = 16;
            video.currentTime = Math.max(video.currentTime, video.duration - 0.05);
          }
        } catch (e) {}
        clickSkip();
      }

      function tick() {
        if (window.__orielYouTubeAdBlockKill) return;
        if (!hostOK()) return;
        nukeAdSlots();
        skipPlayerAd();
      }

      tick();
      setInterval(tick, isWatchContext() ? 500 : 1200);
      document.addEventListener('yt-navigate-finish', tick, true);
    })();
    """#

    static let disableSource = "window.__orielYouTubeAdBlockKill = true;"

    static func shouldInject(for url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return host == "youtube.com"
            || host == "www.youtube.com"
            || host == "m.youtube.com"
            || host == "youtube-nocookie.com"
            || host == "www.youtube-nocookie.com"
            || host.hasSuffix(".youtube.com")
            || host.hasSuffix(".youtube-nocookie.com")
    }
}
