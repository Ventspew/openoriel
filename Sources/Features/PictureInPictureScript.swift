import Foundation

enum PictureInPictureScript {
    /// Returns JSON: { "videos":[{ "index":0,"label":"…","playing":true,"w":1920,"h":1080 }], "active":null|number }
    static let inventory = #"""
    (function() {
      function labelFor(v, i) {
        var title = v.getAttribute('title') || v.getAttribute('aria-label') || '';
        if (!title && v.currentSrc) {
          try {
            var u = new URL(v.currentSrc, location.href);
            title = u.pathname.split('/').filter(Boolean).pop() || u.hostname;
          } catch (e) { title = ''; }
        }
        if (!title) title = 'Video ' + (i + 1);
        var w = Math.round(v.videoWidth || v.clientWidth || 0);
        var h = Math.round(v.videoHeight || v.clientHeight || 0);
        if (w && h) title += ' (' + w + '×' + h + ')';
        if (!v.paused && !v.ended) title += ' · playing';
        return title;
      }
      var videos = Array.prototype.slice.call(document.querySelectorAll('video'));
      var active = null;
      if (document.pictureInPictureElement) {
        active = videos.indexOf(document.pictureInPictureElement);
        if (active < 0) active = null;
      }
      return JSON.stringify({
        videos: videos.map(function(v, i) {
          return {
            index: i,
            label: labelFor(v, i),
            playing: !!(v && !v.paused && !v.ended),
            w: Math.round(v.videoWidth || 0),
            h: Math.round(v.videoHeight || 0)
          };
        }),
        active: active
      });
    })();
    """#

    static func toggle(at index: Int) -> String {
        """
        (function() {
          var videos = Array.prototype.slice.call(document.querySelectorAll('video'));
          var video = videos[\(index)];
          if (!video) return 'no-video';
          if (document.pictureInPictureElement === video) {
            document.exitPictureInPicture();
            return 'exit';
          }
          if (document.pictureInPictureElement) {
            try { document.exitPictureInPicture(); } catch (e) {}
          }
          if (video.disablePictureInPicture) video.disablePictureInPicture = false;
          video.setAttribute('playsinline', 'playsinline');
          return video.requestPictureInPicture().then(function(){ return 'on'; }).catch(function(err){
            return 'error:' + (err && err.message ? err.message : 'unknown');
          });
        })();
        """
    }

    /// Prefer playing video, else largest by area, else first.
    static let enableBest = #"""
    (function() {
      var videos = Array.prototype.slice.call(document.querySelectorAll('video'));
      if (!videos.length) return 'no-video';
      if (document.pictureInPictureElement) {
        document.exitPictureInPicture();
        return 'exit';
      }
      var best = videos.find(function(v){ return !v.paused && !v.ended; })
        || videos.slice().sort(function(a,b){
          return (b.videoWidth*b.videoHeight) - (a.videoWidth*a.videoHeight);
        })[0]
        || videos[0];
      if (best.disablePictureInPicture) best.disablePictureInPicture = false;
      best.setAttribute('playsinline', 'playsinline');
      return best.requestPictureInPicture().then(function(){ return 'on'; }).catch(function(err){
        return 'error:' + (err && err.message ? err.message : 'unknown');
      });
    })();
    """#

    static let mediaControls = #"""
    (function() {
      var videos = Array.prototype.slice.call(document.querySelectorAll('video'));
      if (!videos.length) return false;
      videos.forEach(function(v) {
        v.setAttribute('controls', 'controls');
        v.style.maxWidth = '100%';
        if (v.disablePictureInPicture) v.disablePictureInPicture = false;
      });
      return true;
    })();
    """#
}
