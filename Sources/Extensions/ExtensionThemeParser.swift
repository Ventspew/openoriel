import Foundation
import SwiftUI

/// Where an installed theme package came from.
enum ExtensionThemeSource: String, Codable, Sendable {
    case chrome
    case firefox
    case safari
    case file
}

/// Parsed Chrome / Firefox / Safari WebExtension static theme.
struct ParsedExtensionTheme: Equatable, Sendable {
    var displayName: String
    var version: String
    var source: ExtensionThemeSource
    /// Toolbar / accent (0…1 RGB).
    var accentRGB: [Double]
    /// NTP / chrome wash base fill.
    var backgroundRGB: [Double]
    /// Optional toolbar surface.
    var toolbarRGB: [Double]?
    /// Relative path inside the package (e.g. `images/ntp.png`).
    var ntpImageRelativePath: String?
    /// Prefer dark chrome when background luminance is low.
    var prefersDark: Bool

    var accentColor: Color {
        Color(red: accentRGB[0], green: accentRGB[1], blue: accentRGB[2])
    }

    var backgroundColor: Color {
        Color(red: backgroundRGB[0], green: backgroundRGB[1], blue: backgroundRGB[2])
    }
}

enum ExtensionThemeParser {
    /// True when `manifest.json` declares a top-level `theme` dictionary.
    static func manifestContainsTheme(at packageRoot: URL, fileManager: FileManager = .default) -> Bool {
        guard let manifestURL = findManifest(in: packageRoot, fileManager: fileManager),
              let root = loadJSON(at: manifestURL) else { return false }
        return root["theme"] is [String: Any]
    }

    /// Theme-only packages have `theme` and no background / content scripts / action.
    static func isThemeOnlyPackage(at packageRoot: URL, fileManager: FileManager = .default) -> Bool {
        guard let manifestURL = findManifest(in: packageRoot, fileManager: fileManager),
              let root = loadJSON(at: manifestURL),
              root["theme"] is [String: Any] else { return false }
        if root["background"] != nil { return false }
        if root["content_scripts"] != nil { return false }
        if root["action"] != nil || root["browser_action"] != nil || root["page_action"] != nil {
            return false
        }
        return true
    }

    static func parse(
        packageRoot: URL,
        source: ExtensionThemeSource,
        fileManager: FileManager = .default
    ) throws -> ParsedExtensionTheme {
        guard let manifestURL = findManifest(in: packageRoot, fileManager: fileManager),
              let root = loadJSON(at: manifestURL),
              let theme = root["theme"] as? [String: Any] else {
            throw ExtensionThemeError.missingTheme
        }

        let name = (root["name"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let version = (root["version"] as? String) ?? "—"
        let colors = theme["colors"] as? [String: Any] ?? [:]
        let images = theme["images"] as? [String: Any] ?? [:]

        let toolbar = colorRGB(from: colors["toolbar"])
            ?? colorRGB(from: colors["frame"])
            ?? colorRGB(from: colors["bookmark_text"])
        let frame = colorRGB(from: colors["frame"])
            ?? colorRGB(from: colors["frame_inactive"])
        let ntp = colorRGB(from: colors["ntp_background"])
            ?? colorRGB(from: colors["ntp_background_color"])
            ?? frame
            ?? toolbar
        let accent = colorRGB(from: colors["toolbar_field"])
            ?? colorRGB(from: colors["button_background"])
            ?? colorRGB(from: colors["tab_background_text"])
            ?? toolbar
            ?? frame
            ?? [0.18, 0.38, 0.42]

        let background = ntp ?? frame ?? [0.96, 0.95, 0.92]
        let prefersDark = luminance(background) < 0.45

        let ntpImage = firstString(
            in: images,
            keys: ["theme_ntp_background", "ntp_background", "additional_backgrounds"]
        )

        return ParsedExtensionTheme(
            displayName: (name?.isEmpty == false ? name! : "Extension theme"),
            version: version,
            source: source,
            accentRGB: accent,
            backgroundRGB: background,
            toolbarRGB: toolbar,
            ntpImageRelativePath: ntpImage,
            prefersDark: prefersDark
        )
    }

    static func findManifest(in root: URL, fileManager: FileManager = .default) -> URL? {
        let preferred = [
            root.appendingPathComponent("manifest.json"),
            root.appendingPathComponent("Contents/Resources/manifest.json"),
            root.appendingPathComponent("Resources/manifest.json")
        ]
        for url in preferred where fileManager.fileExists(atPath: url.path) {
            return url
        }
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "manifest.json" {
            return fileURL
        }
        return nil
    }

    // MARK: - Color parsing (Chrome RGB arrays + Firefox CSS colors)

    static func colorRGB(from value: Any?) -> [Double]? {
        if let arr = value as? [Any], arr.count >= 3 {
            let r = doubleValue(arr[0])
            let g = doubleValue(arr[1])
            let b = doubleValue(arr[2])
            // Chrome themes use 0…255 ints; tolerate 0…1 floats.
            if r > 1 || g > 1 || b > 1 {
                return [clamp01(r / 255), clamp01(g / 255), clamp01(b / 255)]
            }
            return [clamp01(r), clamp01(g), clamp01(b)]
        }
        if let str = value as? String {
            return parseCSSColor(str)
        }
        return nil
    }

    static func parseCSSColor(_ raw: String) -> [Double]? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.hasPrefix("#") {
            let hex = String(s.dropFirst())
            if hex.count == 3,
               let r = Int(String(hex[hex.startIndex]), radix: 16),
               let g = Int(String(hex[hex.index(hex.startIndex, offsetBy: 1)]), radix: 16),
               let b = Int(String(hex[hex.index(hex.startIndex, offsetBy: 2)]), radix: 16) {
                return [Double(r * 17) / 255, Double(g * 17) / 255, Double(b * 17) / 255]
            }
            if hex.count == 6 || hex.count == 8,
               let r = Int(hex.prefix(2), radix: 16),
               let g = Int(hex.dropFirst(2).prefix(2), radix: 16),
               let b = Int(hex.dropFirst(4).prefix(2), radix: 16) {
                return [Double(r) / 255, Double(g) / 255, Double(b) / 255]
            }
        }
        if s.hasPrefix("rgb") {
            let nums = s
                .replacingOccurrences(of: "rgba(", with: "")
                .replacingOccurrences(of: "rgb(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .split(separator: ",")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard nums.count >= 3 else { return nil }
            return [clamp01(nums[0] / 255), clamp01(nums[1] / 255), clamp01(nums[2] / 255)]
        }
        return nil
    }

    static func luminance(_ rgb: [Double]) -> Double {
        guard rgb.count >= 3 else { return 0.5 }
        return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]
    }

    private static func loadJSON(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    private static func doubleValue(_ any: Any) -> Double {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String, let d = Double(s) { return d }
        return 0
    }

    private static func clamp01(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    private static func firstString(in dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let s = dict[key] as? String, !s.isEmpty { return s }
            if let arr = dict[key] as? [Any], let s = arr.first as? String, !s.isEmpty { return s }
        }
        return nil
    }
}

enum ExtensionThemeError: LocalizedError {
    case missingTheme
    case packageNotFound

    var errorDescription: String? {
        switch self {
        case .missingTheme:
            return "This package does not contain a Chrome/Firefox theme definition."
        case .packageNotFound:
            return "Theme package could not be found."
        }
    }
}
