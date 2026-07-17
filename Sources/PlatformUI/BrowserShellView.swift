import SwiftUI

struct BrowserShellView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        @Bindable var environment = environment
        let tab = environment.tab

        Group {
            #if os(macOS)
            macShell(tab: tab, environment: environment)
            #else
            iosShell(tab: tab, environment: environment)
            #endif
        }
        .sheet(isPresented: $environment.showAbout) {
            AboutOrielView()
                #if os(macOS)
                .frame(width: 420, height: 460)
                #endif
        }
    }

    // MARK: - iOS / iPadOS

    #if os(iOS)
    @ViewBuilder
    private func iosShell(tab: BrowserTab, environment: AppEnvironment) -> some View {
        VStack(spacing: 0) {
            progressBar(for: tab)

            content(for: tab)

            VStack(spacing: 8) {
                AddressBarView(tab: tab) {
                    tab.searchEngine = environment.settings.searchEngine
                    tab.submitAddressBar()
                    hideKeyboard()
                }

                HStack {
                    NavigationControlsView(tab: tab)
                    Spacer()
                    Button {
                        environment.showAbout = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("About Oriel")
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, OrielTheme.chromePadding)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(.bar)
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    #endif

    // MARK: - macOS

    #if os(macOS)
    @ViewBuilder
    private func macShell(tab: BrowserTab, environment: AppEnvironment) -> some View {
        VStack(spacing: 0) {
            progressBar(for: tab)
            content(for: tab)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                NavigationControlsView(tab: tab)
            }
            ToolbarItem(placement: .principal) {
                AddressBarView(tab: tab) {
                    tab.searchEngine = environment.settings.searchEngine
                    tab.submitAddressBar()
                }
                .frame(minWidth: 280, idealWidth: 520, maxWidth: 720)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    environment.showAbout = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .help("About Oriel — made by inveil.net")
            }
        }
    }
    #endif

    // MARK: - Shared

    @ViewBuilder
    private func content(for tab: BrowserTab) -> some View {
        ZStack {
            if URLParser.isStartPage(tab.navigation.url), tab.navigation.lastErrorMessage == nil {
                StartPageView(tab: tab) {
                    tab.openPublisherSite()
                }
            } else if let message = tab.navigation.lastErrorMessage {
                ErrorPageView(
                    message: message,
                    onRetry: { tab.reload() },
                    onHome: { tab.goHome() }
                )
            } else {
                BrowserWebView(tab: tab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func progressBar(for tab: BrowserTab) -> some View {
        if tab.navigation.isLoading && !URLParser.isStartPage(tab.navigation.url) {
            ProgressView(value: tab.navigation.estimatedProgress)
                .progressViewStyle(.linear)
                .tint(Color.accentColor)
                .frame(height: 2)
                .animation(.easeOut(duration: 0.15), value: tab.navigation.estimatedProgress)
        } else {
            Color.clear.frame(height: 2)
        }
    }
}
