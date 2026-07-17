import SwiftUI

@main
struct OrielApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            BrowserShellView()
                .environment(environment)
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 760)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Oriel") {
                    environment.showAbout = true
                }
            }
            CommandGroup(after: .sidebar) {
                Button("Reload") {
                    environment.activeTab?.reload()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Stop") {
                    environment.activeTab?.stopLoading()
                }
                .keyboardShortcut(".", modifiers: .command)
            }
        }
        #endif
    }
}
