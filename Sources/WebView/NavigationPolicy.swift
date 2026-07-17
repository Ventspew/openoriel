import Foundation
import WebKit

enum NavigationPolicy {
    /// Decides whether a navigation request may proceed.
    static func decision(for navigationAction: WKNavigationAction) -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else {
            return .cancel
        }

        guard let scheme = url.scheme?.lowercased() else {
            return .cancel
        }

        if URLParser.rejectedSchemes.contains(scheme) {
            return .cancel
        }

        // Allow http(s) and our internal start-page scheme (handled natively).
        if URLParser.allowedSchemes.contains(scheme) {
            if scheme == BrowserConstants.aboutScheme {
                // Native start page — cancel WebKit load; shell shows StartPageView.
                return .cancel
            }
            return .allow
        }

        // tel:, mailto:, etc. — cancel in-browser; OS handling can be added later.
        return .cancel
    }
}
