import Foundation
import Observation

@Observable
@MainActor
final class BrowserSettings {
    var searchEngine: SearchEngine {
        didSet { persist() }
    }

    private let defaults: UserDefaults
    private let searchEngineKey = "oriel.searchEngine"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: searchEngineKey),
           let engine = SearchEngine(rawValue: raw) {
            self.searchEngine = engine
        } else {
            self.searchEngine = .duckDuckGo
        }
    }

    private func persist() {
        defaults.set(searchEngine.rawValue, forKey: searchEngineKey)
    }
}
