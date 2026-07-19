import SwiftUI
#if os(macOS)
import AppKit

/// Embeds Oriel Engine (CEF/Blink) for Native tabs.
struct CefWebHostView: NSViewRepresentable {
    @Bindable var tab: BrowserTab
    var onDownload: (URL, String?) -> Void

    @MainActor
    final class Coordinator: NSObject, OrielCEFHostDelegate {
        var parent: CefWebHostView
        var host: OrielCEFHost?
        var lastLoaded: URL?

        init(_ parent: CefWebHostView) {
            self.parent = parent
        }

        func bindHooks() {
            parent.tab.usesEmbeddedCEF = true
            parent.tab.cefGoBack = { [weak self] in self?.host?.goBack() }
            parent.tab.cefGoForward = { [weak self] in self?.host?.goForward() }
            parent.tab.cefReload = { [weak self] in self?.host?.reload() }
            parent.tab.cefStop = { [weak self] in self?.host?.stopLoading() }
        }

        func clearHooks() {
            parent.tab.usesEmbeddedCEF = false
            parent.tab.cefGoBack = nil
            parent.tab.cefGoForward = nil
            parent.tab.cefReload = nil
            parent.tab.cefStop = nil
        }

        func cefHostDidChangeState() {
            guard let host else { return }
            if let url = host.url {
                parent.tab.navigation.url = url
                parent.tab.navigation.syncAddressBarFromURL()
            }
            let title = host.title
            if !title.isEmpty {
                parent.tab.navigation.title = title
            }
            parent.tab.navigation.isLoading = host.isLoading
            parent.tab.navigation.canGoBack = host.canGoBack
            parent.tab.navigation.canGoForward = host.canGoForward
        }

        func cefHostDidStartDownload(_ url: URL, suggestedName name: String) {
            parent.onDownload(url, name)
        }
    }

    func makeCoordinator() -> Coordinator {
        MainActor.assumeIsolated {
            Coordinator(self)
        }
    }

    func makeNSView(context: Context) -> NSView {
        MainActor.assumeIsolated {
            let host = OrielCEFHost(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
            host.delegate = context.coordinator
            context.coordinator.host = host
            context.coordinator.bindHooks()
            sync(host: host, coordinator: context.coordinator)
            return host.view
        }
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        MainActor.assumeIsolated {
            guard let host = context.coordinator.host else { return }
            context.coordinator.bindHooks()
            sync(host: host, coordinator: context.coordinator)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        MainActor.assumeIsolated {
            coordinator.clearHooks()
        }
    }

    @MainActor
    private func sync(host: OrielCEFHost, coordinator: Coordinator) {
        guard let url = tab.navigation.url, !URLParser.isStartPage(url) else { return }
        if coordinator.lastLoaded != url {
            host.loadURL(url)
            coordinator.lastLoaded = url
        }
    }
}

#endif
