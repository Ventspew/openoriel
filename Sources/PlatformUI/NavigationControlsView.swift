import SwiftUI

/// Back / forward / reload / home controls with clear disabled states and hit targets.
struct NavigationControlsView: View {
    @Bindable var tab: BrowserTab
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isStartPage: Bool {
        URLParser.isStartPage(tab.navigation.url)
    }

    private var buttonSize: CGFloat {
        horizontalSizeClass == .compact ? OrielLayout.compactNavButtonSize : OrielLayout.navButtonSize
    }

    var body: some View {
        HStack(spacing: horizontalSizeClass == .compact ? 2 : 6) {
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

            navButton(
                systemName: tab.navigation.isLoading ? "xmark" : "arrow.clockwise",
                label: tab.navigation.isLoading ? "Stop" : "Reload",
                enabled: !isStartPage || tab.navigation.isLoading
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
    }

    private func navButton(
        systemName: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .frame(width: buttonSize, height: buttonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
        .accessibilityHint(enabled ? "" : "Unavailable")
        .help(label)
    }
}
