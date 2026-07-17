import SwiftUI

struct NavigationControlsView: View {
    let tab: BrowserTab

    var body: some View {
        HStack(spacing: 18) {
            Button {
                tab.goBack()
            } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(!tab.navigation.canGoBack)
            .accessibilityLabel("Back")

            Button {
                tab.goForward()
            } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(!tab.navigation.canGoForward)
            .accessibilityLabel("Forward")

            Button {
                if tab.navigation.isLoading {
                    tab.stopLoading()
                } else {
                    tab.reload()
                }
            } label: {
                Image(systemName: tab.navigation.isLoading ? "xmark" : "arrow.clockwise")
            }
            .accessibilityLabel(tab.navigation.isLoading ? "Stop" : "Reload")

            Button {
                tab.goHome()
            } label: {
                Image(systemName: "house")
            }
            .accessibilityLabel("Home")
        }
        .buttonStyle(.plain)
        .font(.body.weight(.semibold))
    }
}
