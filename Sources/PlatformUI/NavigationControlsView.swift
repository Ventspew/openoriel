import SwiftUI

/// Back / forward / reload / home, plus the Oriel Shields app-icon control (Brave-style).
struct NavigationControlsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var tab: BrowserTab
    /// Narrow chrome: back/forward + Oriel Shields only.
    var style: Style = .full

    enum Style {
        case full
        case compact
    }

    private var isStartPage: Bool {
        URLParser.isStartPage(tab.navigation.url)
    }

    private var buttonSize: CGFloat {
        style == .compact ? 32 : OrielLayout.navButtonSize
    }

    private var markSize: CGFloat {
        style == .compact ? 18 : 22
    }

    private var accent: Color {
        environment.settings.brandColor
    }

    var body: some View {
        HStack(spacing: style == .compact ? 4 : 6) {
            navButton(
                systemName: "chevron.backward",
                label: "Back",
                enabled: tab.navigation.canGoBack
            ) {
                tab.goBack()
            }

            navButton(
                systemName: "chevron.forward",
                label: "Forward",
                enabled: tab.navigation.canGoForward
            ) {
                tab.goForward()
            }

            if style == .full {
                navButton(
                    systemName: tab.navigation.isLoading ? "xmark" : "arrow.clockwise",
                    label: tab.navigation.isLoading ? "Stop" : "Reload",
                    enabled: !isStartPage || tab.navigation.isLoading,
                    emphasized: tab.navigation.isLoading
                ) {
                    if tab.navigation.isLoading {
                        tab.stopLoading()
                    } else {
                        tab.reload()
                    }
                }

                navButton(
                    systemName: "house",
                    label: "Home",
                    enabled: !isStartPage
                ) {
                    tab.goHome()
                }
            }

            // App-icon Shields toggle — sits with nav, next to Home (like Brave’s lion).
            OrielShieldButton(size: markSize)
        }
    }

    private func navButton(
        systemName: String,
        label: String,
        enabled: Bool,
        emphasized: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
        }
        .buttonStyle(
            OrielChromeButtonStyle(
                isEnabled: enabled,
                isEmphasized: emphasized,
                accent: accent,
                size: buttonSize
            )
        )
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityHint(enabled ? "" : "Unavailable")
        .help(label)
    }
}
