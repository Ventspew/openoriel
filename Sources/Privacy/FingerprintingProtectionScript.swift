import Foundation

/// Anti-fingerprinting script injected at document start (best-effort under WebKit).
enum FingerprintingProtectionScript {
    static let source = #"""
    (function() {
      if (window.__orielFPProtect) return;
      window.__orielFPProtect = true;

      function noise(value, salt) {
        var n = 0;
        for (var i = 0; i < salt.length; i++) n = (n + salt.charCodeAt(i) * (i + 1)) % 97;
        return value + (n % 3) * 0.0000001;
      }

      try {
        var toDataURL = HTMLCanvasElement.prototype.toDataURL;
        HTMLCanvasElement.prototype.toDataURL = function() {
          try {
            var ctx = this.getContext('2d');
            if (ctx) {
              var img = ctx.getImageData(0, 0, Math.min(this.width || 1, 16), Math.min(this.height || 1, 1));
              if (img && img.data && img.data.length) {
                img.data[0] = img.data[0] ^ 1;
                ctx.putImageData(img, 0, 0);
              }
            }
          } catch (e) {}
          return toDataURL.apply(this, arguments);
        };
      } catch (e) {}

      try {
        var getImageData = CanvasRenderingContext2D.prototype.getImageData;
        CanvasRenderingContext2D.prototype.getImageData = function() {
          var data = getImageData.apply(this, arguments);
          try {
            if (data && data.data && data.data.length > 4) {
              data.data[data.data.length - 1] = data.data[data.data.length - 1] ^ 1;
            }
          } catch (e) {}
          return data;
        };
      } catch (e) {}

      try {
        var getChannelData = AudioBuffer.prototype.getChannelData;
        AudioBuffer.prototype.getChannelData = function() {
          var arr = getChannelData.apply(this, arguments);
          try {
            if (arr && arr.length) {
              arr[0] = noise(arr[0], location.hostname || 'oriel');
            }
          } catch (e) {}
          return arr;
        };
      } catch (e) {}

      try {
        var getParameter = WebGLRenderingContext.prototype.getParameter;
        WebGLRenderingContext.prototype.getParameter = function(param) {
          var value = getParameter.apply(this, arguments);
          if (param === 37445) return 'Apple Inc.'; // UNMASKED_VENDOR_WEBGL
          if (param === 37446) return 'Apple GPU'; // UNMASKED_RENDERER_WEBGL
          return value;
        };
        if (window.WebGL2RenderingContext) {
          var getParameter2 = WebGL2RenderingContext.prototype.getParameter;
          WebGL2RenderingContext.prototype.getParameter = function(param) {
            var value = getParameter2.apply(this, arguments);
            if (param === 37445) return 'Apple Inc.';
            if (param === 37446) return 'Apple GPU';
            return value;
          };
        }
      } catch (e) {}

      try {
        Object.defineProperty(navigator, 'hardwareConcurrency', { get: function() { return 4; } });
      } catch (e) {}
      try {
        Object.defineProperty(navigator, 'deviceMemory', { get: function() { return 4; } });
      } catch (e) {}
    })();
    """#
}
