import Foundation
import Observation

/// Local settings mirror used for CloudKit/iCloud KVS sync of lightweight preferences + bookmarks.
@Observable
@MainActor
final class iCloudSyncService {
    private let defaults = NSUbiquitousKeyValueStore.default
    private let bookmarksKey = "oriel.sync.bookmarks.v1"
    private let settingsKey = "oriel.sync.settings.v1"
    private let queueKey = "oriel.sync.linkqueue.v1"
    private let enabledKey = "oriel.icloudSyncEnabled"

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
            if isEnabled {
                pushAll()
            }
        }
    }

    private weak var bookmarks: BookmarkStore?
    private weak var settings: BrowserSettings?
    private weak var linkQueue: LinkQueueStore?

    init() {
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            isEnabled = false
        } else {
            isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        }
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: defaults,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                self?.handleExternalChange(note)
            }
        }
        defaults.synchronize()
    }

    func attach(bookmarks: BookmarkStore, settings: BrowserSettings, linkQueue: LinkQueueStore) {
        self.bookmarks = bookmarks
        self.settings = settings
        self.linkQueue = linkQueue
        if isEnabled {
            pullAll()
            pushAll()
        }
    }

    func pushAll() {
        guard isEnabled else { return }
        if let bookmarks {
            if let data = try? JSONEncoder().encode(bookmarks.bookmarks) {
                defaults.set(data, forKey: bookmarksKey)
            }
        }
        if let settings {
            let payload: [String: String] = [
                "searchEngine": settings.searchEngine.rawValue,
                "appearance": settings.appearance.rawValue,
                "accentTheme": settings.accentTheme.rawValue,
                "backgroundTheme": settings.backgroundTheme.rawValue
            ]
            if let data = try? JSONEncoder().encode(payload) {
                defaults.set(data, forKey: settingsKey)
            }
        }
        if let linkQueue {
            if let data = try? JSONEncoder().encode(linkQueue.items) {
                defaults.set(data, forKey: queueKey)
            }
        }
        defaults.synchronize()
    }

    func pullAll() {
        guard isEnabled else { return }
        if let data = defaults.data(forKey: bookmarksKey),
           let remote = try? JSONDecoder().decode([Bookmark].self, from: data),
           let bookmarks {
            // Merge by URL / folder id — prefer union.
            var map = Dictionary(uniqueKeysWithValues: bookmarks.bookmarks.map { ($0.id, $0) })
            for item in remote {
                map[item.id] = item
            }
            // BookmarkStore has no bulk replace — use reflection via remove/add would be lossy.
            // Expose internal replace through a dedicated API.
            bookmarks.replaceAll(Array(map.values))
        }
        if let data = defaults.data(forKey: settingsKey),
           let payload = try? JSONDecoder().decode([String: String].self, from: data),
           let settings {
            if let raw = payload["searchEngine"], let engine = SearchEngine(rawValue: raw) {
                settings.searchEngine = engine
            }
            if let raw = payload["appearance"], let mode = AppAppearance(rawValue: raw) {
                settings.appearance = mode
            }
            if let raw = payload["accentTheme"], let theme = BrowserAccentTheme(rawValue: raw) {
                settings.accentTheme = theme
            }
            if let raw = payload["backgroundTheme"], let theme = BrowserBackgroundTheme(rawValue: raw) {
                settings.backgroundTheme = theme
            }
        }
        if let data = defaults.data(forKey: queueKey),
           let remote = try? JSONDecoder().decode([QueuedLink].self, from: data),
           let linkQueue {
            linkQueue.replaceAll(remote)
        }
    }

    private func handleExternalChange(_ note: Notification) {
        guard isEnabled else { return }
        pullAll()
    }
}
