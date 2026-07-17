import Foundation
import Observation

/// Composition root for Oriel. Created once at app launch.
@Observable
@MainActor
final class AppEnvironment {
    let settings: BrowserSettings
    let tab: BrowserTab
    var showAbout = false

    /// Phase 1: single active tab. TabManager lands in Phase 2.
    var activeTab: BrowserTab? { tab }

    init(settings: BrowserSettings? = nil) {
        let resolved = settings ?? BrowserSettings()
        self.settings = resolved
        self.tab = BrowserTab(
            isPrivate: false,
            searchEngine: resolved.searchEngine
        )
    }
}
