import Foundation
import Observation
import SwiftUI

struct InstalledExtensionTheme: Identifiable, Equatable, Codable, Sendable {
    var id: String
    var displayName: String
    var version: String
    var source: ExtensionThemeSource
    var directoryName: String
    var accentRGB: [Double]
    var backgroundRGB: [Double]
    var toolbarRGB: [Double]?
    var ntpImageRelativePath: String?
    var prefersDark: Bool
    /// Chrome Web Store id when installed from CWS (theme-only packages never enter the extension catalog).
    var chromeStoreID: String? = nil
    /// Firefox AMO slug when installed from addons.mozilla.org.
    var firefoxSlug: String? = nil

    var accentColor: Color {
        Color(red: accentRGB[0], green: accentRGB[1], blue: accentRGB[2])
    }

    var backgroundColor: Color {
        Color(red: backgroundRGB[0], green: backgroundRGB[1], blue: backgroundRGB[2])
    }

    var sourceLabel: String {
        switch source {
        case .chrome: "Chrome"
        case .firefox: "Firefox"
        case .safari: "Safari"
        case .file: "File"
        }
    }
}

/// Persists Chrome / Firefox / Safari static themes and applies them to `BrowserSettings`.
@Observable
@MainActor
final class ExtensionThemeStore {
    private(set) var themes: [InstalledExtensionTheme] = []
    private(set) var lastError: String?

    private let fileManager: FileManager
    private let catalogName = "extension-themes-catalog.json"
    private weak var settings: BrowserSettings?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        reloadFromDisk()
    }

    func attach(settings: BrowserSettings) {
        self.settings = settings
        // Re-apply active theme colors after relaunch.
        if let id = settings.activeExtensionThemeID {
            apply(id: id)
        }
    }

    var themesDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dir = base.appendingPathComponent("Oriel/ExtensionThemes", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func reloadFromDisk() {
        themes = loadCatalog().sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    /// Chrome Web Store IDs for themes (including theme-only installs).
    var installedChromeStoreIDs: [String] {
        Array(
            Set(
                themes.compactMap { theme -> String? in
                    if let storeID = theme.chromeStoreID?.lowercased(),
                       ChromeWebStoreAPI.isValidExtensionID(storeID) {
                        return storeID
                    }
                    let candidate = theme.id.lowercased()
                    if ChromeWebStoreAPI.isValidExtensionID(candidate) { return candidate }
                    return nil
                }
            )
        ).sorted()
    }

    /// Firefox AMO slugs for themes installed from the store.
    var installedFirefoxSlugs: [String] {
        Array(
            Set(
                themes.compactMap { theme -> String? in
                    if let slug = theme.firefoxSlug?.lowercased(), !slug.isEmpty { return slug }
                    if theme.source == .firefox {
                        let candidate = theme.id.lowercased()
                        // Prefer explicit slug; fall back to id when it was the AMO slug.
                        if !candidate.isEmpty, !ChromeWebStoreAPI.isValidExtensionID(candidate) {
                            return candidate
                        }
                    }
                    return nil
                }
            )
        ).sorted()
    }

    /// Import a staged WebExtension package that contains `theme`. Returns whether it was theme-only.
    @discardableResult
    func importStagedPackage(
        at staging: URL,
        source: ExtensionThemeSource,
        preferredID: String? = nil
    ) throws -> (theme: InstalledExtensionTheme, isThemeOnly: Bool) {
        let parsed = try ExtensionThemeParser.parse(packageRoot: staging, source: source)
        let isThemeOnly = ExtensionThemeParser.isThemeOnlyPackage(at: staging)
        let themeID = sanitizedID(preferredID ?? UUID().uuidString)
        let preferred = preferredID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let chromeID: String? = {
            if let preferred, ChromeWebStoreAPI.isValidExtensionID(preferred.lowercased()) {
                return preferred.lowercased()
            }
            if source == .chrome, ChromeWebStoreAPI.isValidExtensionID(themeID.lowercased()) {
                return themeID.lowercased()
            }
            return nil
        }()
        let firefoxSlug: String? = {
            guard source == .firefox else { return nil }
            if let preferred, !preferred.isEmpty, !ChromeWebStoreAPI.isValidExtensionID(preferred.lowercased()) {
                return preferred.lowercased()
            }
            if !ChromeWebStoreAPI.isValidExtensionID(themeID.lowercased()) {
                return themeID.lowercased()
            }
            return nil
        }()

        let destination = themesDirectory.appendingPathComponent(themeID, isDirectory: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        // Copy (not move) so functional extensions can still consume the staging folder.
        try fileManager.copyItem(at: staging, to: destination)

        let record = InstalledExtensionTheme(
            id: themeID,
            displayName: parsed.displayName,
            version: parsed.version,
            source: source,
            directoryName: themeID,
            accentRGB: parsed.accentRGB,
            backgroundRGB: parsed.backgroundRGB,
            toolbarRGB: parsed.toolbarRGB,
            ntpImageRelativePath: parsed.ntpImageRelativePath,
            prefersDark: parsed.prefersDark,
            chromeStoreID: chromeID,
            firefoxSlug: firefoxSlug
        )

        var catalog = loadCatalog()
        catalog.removeAll {
            $0.id == themeID
                || ($0.chromeStoreID != nil && $0.chromeStoreID == chromeID)
                || ($0.firefoxSlug != nil && $0.firefoxSlug == firefoxSlug)
                || ($0.displayName == record.displayName && $0.source == source)
        }
        catalog.append(record)
        saveCatalog(catalog)
        reloadFromDisk()
        apply(id: themeID)
        return (record, isThemeOnly)
    }

    func apply(id: String) {
        lastError = nil
        guard let theme = themes.first(where: { $0.id == id }) ?? loadCatalog().first(where: { $0.id == id }) else {
            lastError = "That theme is not installed."
            return
        }
        settings?.applyExtensionTheme(
            id: theme.id,
            accentRGB: theme.accentRGB,
            backgroundRGB: theme.backgroundRGB,
            prefersDark: theme.prefersDark
        )
    }

    func clearActive() {
        settings?.clearExtensionTheme()
    }

    func remove(id: String) {
        if settings?.activeExtensionThemeID == id {
            clearActive()
        }
        let folder = themesDirectory.appendingPathComponent(id, isDirectory: true)
        try? fileManager.removeItem(at: folder)
        var catalog = loadCatalog()
        catalog.removeAll { $0.id == id }
        saveCatalog(catalog)
        reloadFromDisk()
    }

    func ntpImageURL(for theme: InstalledExtensionTheme) -> URL? {
        guard let relative = theme.ntpImageRelativePath, !relative.isEmpty else { return nil }
        let root = themesDirectory.appendingPathComponent(theme.directoryName, isDirectory: true)
        let url = root.appendingPathComponent(relative)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Persistence

    private var catalogURL: URL {
        themesDirectory.appendingPathComponent(catalogName)
    }

    private func loadCatalog() -> [InstalledExtensionTheme] {
        guard let data = try? Data(contentsOf: catalogURL),
              let decoded = try? JSONDecoder().decode([InstalledExtensionTheme].self, from: data) else {
            return []
        }
        return decoded
    }

    private func saveCatalog(_ catalog: [InstalledExtensionTheme]) {
        guard let data = try? JSONEncoder().encode(catalog) else { return }
        try? data.write(to: catalogURL, options: .atomic)
    }

    private func sanitizedID(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let filtered = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let id = String(filtered)
        return id.isEmpty ? UUID().uuidString : id
    }
}
