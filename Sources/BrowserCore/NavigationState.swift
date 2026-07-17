import Foundation

/// Snapshot of WebKit navigation UI state for a single tab.
struct NavigationState: Equatable, Sendable {
    var url: URL?
    var title: String = ""
    var estimatedProgress: Double = 0
    var isLoading = false
    var canGoBack = false
    var canGoForward = false
    var addressBarText: String = ""
    var lastErrorMessage: String?

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if URLParser.isStartPage(url) { return BrowserConstants.productName }
        return url?.host ?? BrowserConstants.productName
    }

    mutating func syncAddressBarFromURL() {
        if URLParser.isStartPage(url) {
            addressBarText = ""
        } else if let url {
            addressBarText = url.absoluteString
        }
    }
}
