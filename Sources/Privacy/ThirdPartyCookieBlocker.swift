import Foundation
import WebKit

/// Compiles and caches a WebKit content-rule list that blocks cookies on third-party loads.
enum ThirdPartyCookieBlocker {
    static let identifier = "OrielThirdPartyCookieBlocker"

    private static let ruleJSON = """
    [
      {
        "trigger": {
          "url-filter": ".*",
          "load-type": ["third-party"]
        },
        "action": {
          "type": "block-cookies"
        }
      }
    ]
    """

    @MainActor
    private static var cachedList: WKContentRuleList?
    @MainActor
    private static var compileTask: Task<WKContentRuleList?, Never>?

    @MainActor
    static func ruleList() async -> WKContentRuleList? {
        if let cachedList { return cachedList }
        if let compileTask {
            return await compileTask.value
        }
        let task = Task<WKContentRuleList?, Never> {
            do {
                guard let store = WKContentRuleListStore.default() else { return nil }
                if let existing = try await store.contentRuleList(forIdentifier: identifier) {
                    return existing
                }
                return try await store.compileContentRuleList(
                    forIdentifier: identifier,
                    encodedContentRuleList: ruleJSON
                )
            } catch {
                return nil
            }
        }
        compileTask = task
        let list = await task.value
        cachedList = list
        compileTask = nil
        return list
    }

    @MainActor
    static func apply(to webView: WKWebView, enabled: Bool) async {
        let ucc = webView.configuration.userContentController
        // Remove any previous attachment, then re-add when enabled.
        if let list = cachedList {
            ucc.remove(list)
        } else if let store = WKContentRuleListStore.default(),
                  let existing = try? await store.contentRuleList(forIdentifier: identifier) {
            ucc.remove(existing)
            cachedList = existing
        }

        guard enabled, let list = await ruleList() else { return }
        ucc.add(list)
    }
}
