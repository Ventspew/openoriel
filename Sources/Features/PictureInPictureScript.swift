import Foundation

enum PictureInPictureScript {
    static let enable = #"""
    (function() {
      var video = document.querySelector('video');
      if (!video) return 'no-video';
      if (document.pictureInPictureElement) {
        document.exitPictureInPicture();
        return 'exit';
      }
      if (video.disablePictureInPicture) video.disablePictureInPicture = false;
      return video.requestPictureInPicture().then(function(){ return 'on'; }).catch(function(){ return 'error'; });
    })();
    """#

    static let mediaControls = #"""
    (function() {
      var v = document.querySelector('video');
      if (!v) return false;
      v.setAttribute('controls', 'controls');
      v.style.maxWidth = '100%';
      return true;
    })();
    """#
}
