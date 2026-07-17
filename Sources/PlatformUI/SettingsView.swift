import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = environment.settings
        NavigationStack {
            Form {
                Section("Search") {
                    Picker("Default search engine", selection: $settings.searchEngine) {
                        ForEach(SearchEngine.allCases) { engine in
                            Text(engine.displayName).tag(engine)
                        }
                    }
                    .onChange(of: settings.searchEngine) { _, newValue in
                        for tab in environment.tabs.tabs {
                            tab.searchEngine = newValue
                        }
                    }
                }

                Section("Tabs") {
                    Toggle("Restore previous session", isOn: $settings.restorePreviousSession)
                }

                Section("About") {
                    LabeledContent("Product", value: BrowserConstants.productName)
                    LabeledContent("Website", value: BrowserConstants.productWebsiteHost)
                    LabeledContent("Publisher", value: BrowserConstants.publisherName)
                    Link("Open \(BrowserConstants.productWebsiteHost)", destination: BrowserConstants.productWebsiteURL)
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
