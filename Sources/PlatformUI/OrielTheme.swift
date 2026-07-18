import SwiftUI

/// User-selectable accent colors for chrome, start page, and tint.
enum BrowserAccentTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case teal
    case ocean
    case forest
    case dusk
    case rose
    case slate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .teal: "Teal"
        case .ocean: "Ocean"
        case .forest: "Forest"
        case .dusk: "Dusk"
        case .rose: "Rose"
        case .slate: "Slate"
        }
    }

    var color: Color {
        switch self {
        case .teal: Color(red: 0.18, green: 0.38, blue: 0.42)
        case .ocean: Color(red: 0.14, green: 0.42, blue: 0.62)
        case .forest: Color(red: 0.20, green: 0.42, blue: 0.30)
        case .dusk: Color(red: 0.36, green: 0.28, blue: 0.55)
        case .rose: Color(red: 0.55, green: 0.28, blue: 0.36)
        case .slate: Color(red: 0.30, green: 0.34, blue: 0.40)
        }
    }

    var softColor: Color {
        switch self {
        case .teal: Color(red: 0.52, green: 0.72, blue: 0.78)
        case .ocean: Color(red: 0.45, green: 0.70, blue: 0.88)
        case .forest: Color(red: 0.55, green: 0.78, blue: 0.62)
        case .dusk: Color(red: 0.72, green: 0.62, blue: 0.90)
        case .rose: Color(red: 0.90, green: 0.62, blue: 0.70)
        case .slate: Color(red: 0.70, green: 0.74, blue: 0.80)
        }
    }
}

/// Start-page / chrome background treatments.
enum BrowserBackgroundTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case soft
    case paper
    case mist
    case sand
    case aurora
    case midnight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .soft: "Soft"
        case .paper: "Paper"
        case .mist: "Mist"
        case .sand: "Sand"
        case .aurora: "Aurora"
        case .midnight: "Midnight"
        }
    }

    /// When set, forces light/dark for the start page wash (nil = follow appearance).
    var preferredScheme: ColorScheme? {
        switch self {
        case .midnight: .dark
        case .paper, .sand: .light
        default: nil
        }
    }
}

enum OrielTheme {
    static let chromePadding: CGFloat = 10
    static let controlRadius: CGFloat = 12
    static let searchFieldRadius: CGFloat = 16
    static let searchFieldHeight: CGFloat = 54
    static let sectionRadius: CGFloat = 16
    static let hairlineOpacity: Double = 0.10
    static let chromeButtonRadius: CGFloat = 10

    /// Deep teal used when AccentColor asset is unavailable (previews / fallbacks).
    static let brandTeal = BrowserAccentTheme.teal.color
    static let brandTealSoft = BrowserAccentTheme.teal.softColor

    /// Resolves to the selected accent, falling back to the asset catalog color.
    static func brandPrimary(accent: BrowserAccentTheme = .teal) -> Color {
        accent == .teal ? Color("AccentColor") : accent.color
    }

    @ViewBuilder
    static func startPageBackground(
        accent: BrowserAccentTheme,
        background: BrowserBackgroundTheme,
        scheme: ColorScheme
    ) -> some View {
        let effectiveScheme = background.preferredScheme ?? scheme
        ZStack {
            baseFill(for: background, scheme: effectiveScheme)
            bloom(accent: accent, background: background, scheme: effectiveScheme)
            LinearGradient(
                colors: veilColors(scheme: effectiveScheme),
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    /// Legacy helpers — default teal / soft so About and older call sites keep compiling.
    static var startPageBackground: some View {
        startPageBackground(accent: .teal, background: .soft, scheme: .light)
    }

    static var startPageBackgroundDark: some View {
        startPageBackground(accent: .teal, background: .midnight, scheme: .dark)
    }

    static func surfaceFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.72)
    }

    static func hairline(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(hairlineOpacity)
    }

    private static func baseFill(for background: BrowserBackgroundTheme, scheme: ColorScheme) -> Color {
        switch background {
        case .soft:
            return scheme == .dark
                ? Color(red: 0.10, green: 0.11, blue: 0.12)
                : Color(red: 0.965, green: 0.953, blue: 0.935)
        case .paper:
            return Color(red: 0.98, green: 0.96, blue: 0.93)
        case .mist:
            return scheme == .dark
                ? Color(red: 0.09, green: 0.11, blue: 0.14)
                : Color(red: 0.93, green: 0.95, blue: 0.97)
        case .sand:
            return Color(red: 0.96, green: 0.93, blue: 0.86)
        case .aurora:
            return scheme == .dark
                ? Color(red: 0.08, green: 0.10, blue: 0.14)
                : Color(red: 0.94, green: 0.95, blue: 0.98)
        case .midnight:
            return Color(red: 0.07, green: 0.08, blue: 0.10)
        }
    }

    @ViewBuilder
    private static func bloom(
        accent: BrowserAccentTheme,
        background: BrowserBackgroundTheme,
        scheme: ColorScheme
    ) -> some View {
        let soft = accent.softColor
        let strong = accent.color
        switch background {
        case .aurora:
            RadialGradient(
                colors: [soft.opacity(scheme == .dark ? 0.35 : 0.22), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 380
            )
            RadialGradient(
                colors: [strong.opacity(scheme == .dark ? 0.22 : 0.12), Color.clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 420
            )
        case .midnight:
            RadialGradient(
                colors: [strong.opacity(0.32), Color.clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 400
            )
        default:
            RadialGradient(
                colors: [
                    soft.opacity(scheme == .dark ? 0.28 : 0.14),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
        }
    }

    private static func veilColors(scheme: ColorScheme) -> [Color] {
        if scheme == .dark {
            return [Color.white.opacity(0.05), Color.clear]
        }
        return [Color.black.opacity(0.025), Color.clear, Color.black.opacity(0.03)]
    }
}

/// Filled chrome control so back/forward/settings read clearly on light and dark bars.
struct OrielChromeButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    var isEmphasized: Bool = false
    var accent: Color = OrielTheme.brandTeal
    var size: CGFloat = OrielLayout.navButtonSize
    var expandsHorizontally: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(
                minWidth: size,
                idealWidth: expandsHorizontally ? nil : size,
                maxWidth: expandsHorizontally ? .infinity : size,
                minHeight: size,
                maxHeight: size
            )
            .padding(.horizontal, expandsHorizontally ? 8 : 0)
            .foregroundStyle(
                isEnabled
                    ? (isEmphasized ? accent : Color.primary.opacity(0.9))
                    : Color.secondary.opacity(0.45)
            )
            .background(
                RoundedRectangle(cornerRadius: OrielTheme.chromeButtonRadius, style: .continuous)
                    .fill(fillColor(pressed: configuration.isPressed))
            )
            .overlay {
                RoundedRectangle(cornerRadius: OrielTheme.chromeButtonRadius, style: .continuous)
                    .strokeBorder(
                        isEmphasized && isEnabled
                            ? accent.opacity(0.35)
                            : Color.primary.opacity(configuration.isPressed ? 0.14 : 0.08),
                        lineWidth: 1
                    )
            }
            .scaleEffect(configuration.isPressed && isEnabled ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: OrielTheme.chromeButtonRadius, style: .continuous))
            .opacity(isEnabled ? 1 : 0.7)
            .fixedSize(horizontal: expandsHorizontally, vertical: true)
    }

    private func fillColor(pressed: Bool) -> Color {
        if isEmphasized && isEnabled {
            return accent.opacity(pressed ? 0.28 : 0.16)
        }
        return Color.primary.opacity(pressed ? 0.12 : 0.06)
    }
}
