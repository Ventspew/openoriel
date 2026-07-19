import Foundation
import Observation

/// Remembers page zoom per host (Classic + Pulse).
@Observable
@MainActor
final class SiteZoomStore {
    private(set) var zooms: [String: Double] = [:]
    private let fileName = "site-zoom.json"

    init() {
        if let loaded = try? JSONFileStore.load([String: Double].self, from: fileName) {
            zooms = loaded.filter { $0.value >= 0.5 && $0.value <= 3.0 }
        }
    }

    func zoom(forHost host: String?) -> Double {
        guard let key = normalized(host) else { return 1.0 }
        return zooms[key] ?? 1.0
    }

    func setZoom(_ factor: Double, forHost host: String?) {
        guard let key = normalized(host) else { return }
        let clamped = min(3.0, max(0.5, (factor * 10).rounded() / 10))
        if abs(clamped - 1.0) < 0.01 {
            zooms.removeValue(forKey: key)
        } else {
            zooms[key] = clamped
        }
        persist()
    }

    private func normalized(_ host: String?) -> String? {
        guard let host else { return nil }
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    private func persist() {
        try? JSONFileStore.save(zooms, to: fileName, prettyPrinted: false)
    }
}
