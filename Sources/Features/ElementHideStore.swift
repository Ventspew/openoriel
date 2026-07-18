import Foundation
import Observation

struct HiddenElementRule: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var host: String
    var cssSelector: String
    var createdAt: Date

    init(id: UUID = UUID(), host: String, cssSelector: String, createdAt: Date = .now) {
        self.id = id
        self.host = host.lowercased()
        self.cssSelector = cssSelector
        self.createdAt = createdAt
    }
}

@Observable
@MainActor
final class ElementHideStore {
    private(set) var rules: [HiddenElementRule] = []
    private let fileName = "element-hide.json"

    init() {
        if let loaded = try? JSONFileStore.load([HiddenElementRule].self, from: fileName) {
            rules = loaded
        }
    }

    func rules(forHost host: String?) -> [HiddenElementRule] {
        guard let host else { return [] }
        let key = host.lowercased()
        return rules.filter { key == $0.host || key.hasSuffix(".\($0.host)") }
    }

    func add(host: String, cssSelector: String) {
        let trimmed = cssSelector.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let key = host.lowercased()
        rules.removeAll { $0.host == key && $0.cssSelector == trimmed }
        rules.insert(HiddenElementRule(host: key, cssSelector: trimmed), at: 0)
        persist()
    }

    func remove(id: UUID) {
        rules.removeAll { $0.id == id }
        persist()
    }

    func clear(host: String?) {
        guard let host else {
            rules = []
            persist()
            return
        }
        let key = host.lowercased()
        rules.removeAll { $0.host == key }
        persist()
    }

    func injectionScript(forHost host: String?) -> String {
        let selectors = rules(forHost: host).map(\.cssSelector)
        guard !selectors.isEmpty else { return "" }
        let encoded = selectors
            .map { $0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'") }
        let list = encoded.map { "'\($0)'" }.joined(separator: ",")
        return """
        (function(){
          var sels = [\(list)];
          function apply(){
            sels.forEach(function(sel){
              try { document.querySelectorAll(sel).forEach(function(el){ el.style.setProperty('display','none','important'); }); } catch(e) {}
            });
          }
          apply();
          if (!window.__orielHideObs) {
            window.__orielHideObs = new MutationObserver(apply);
            window.__orielHideObs.observe(document.documentElement,{childList:true,subtree:true});
          }
        })();
        """
    }

    /// Interactive picker: click an element to hide it and post the selector to Oriel.
    static let pickerSource = #"""
    (function() {
      if (window.__orielPickerOn) return 'already';
      window.__orielPickerOn = true;
      function cssPath(el) {
        if (!el || el.nodeType !== 1) return '';
        if (el.id) return '#' + CSS.escape(el.id);
        var parts = [];
        while (el && el.nodeType === 1 && parts.length < 5) {
          var part = el.tagName.toLowerCase();
          if (el.classList && el.classList.length) {
            part += '.' + Array.from(el.classList).slice(0,2).map(function(c){return CSS.escape(c)}).join('.');
          }
          var parent = el.parentElement;
          if (parent) {
            var siblings = Array.from(parent.children).filter(function(n){return n.tagName===el.tagName});
            if (siblings.length > 1) {
              part += ':nth-of-type(' + (siblings.indexOf(el)+1) + ')';
            }
          }
          parts.unshift(part);
          el = parent;
          if (el && el.tagName === 'BODY') break;
        }
        return parts.join(' > ');
      }
      function highlight(el) {
        if (window.__orielPickPrev) window.__orielPickPrev.style.outline = window.__orielPickPrevOutline || '';
        window.__orielPickPrev = el;
        window.__orielPickPrevOutline = el.style.outline;
        el.style.outline = '2px solid #e85d4c';
      }
      function onMove(e) {
        var el = document.elementFromPoint(e.clientX, e.clientY);
        if (el) highlight(el);
      }
      function onClick(e) {
        e.preventDefault(); e.stopPropagation();
        var el = window.__orielPickPrev || e.target;
        var sel = cssPath(el);
        try { el.style.setProperty('display','none','important'); } catch (err) {}
        cleanup();
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.orielHideElement) {
          window.webkit.messageHandlers.orielHideElement.postMessage({ selector: sel, host: location.hostname });
        }
        return false;
      }
      function cleanup() {
        window.__orielPickerOn = false;
        document.removeEventListener('mousemove', onMove, true);
        document.removeEventListener('click', onClick, true);
        if (window.__orielPickPrev) window.__orielPickPrev.style.outline = window.__orielPickPrevOutline || '';
      }
      document.addEventListener('mousemove', onMove, true);
      document.addEventListener('click', onClick, true);
      window.__orielCancelPicker = cleanup;
      return 'on';
    })();
    """#

    static let cancelPickerSource = #"""
    (function(){ if (window.__orielCancelPicker) window.__orielCancelPicker(); return true; })();
    """#

    private func persist() {
        try? JSONFileStore.save(rules, to: fileName)
    }
}
