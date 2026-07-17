import SwiftUI
import WebKit

@Observable
@MainActor
final class WebAuthPopupState: Identifiable {
    let id = UUID()
    let webView: WKWebView
    var title: String

    init(webView: WKWebView, title: String = "Sign in") {
        self.webView = webView
        self.title = title
    }
}

/// Presents a WKWebView created by `WKUIDelegate.createWebViewWith` (needed for Google account OAuth).
struct AuthPopupView: View {
    @Environment(AppEnvironment.self) private var environment
    let state: WebAuthPopupState

    var body: some View {
        NavigationStack {
            AuthPopupWebView(webView: state.webView)
                .navigationTitle(state.title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            environment.dismissAuthPopup()
                        }
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 480, idealWidth: 640, minHeight: 560, idealHeight: 720)
        #endif
    }
}

#if os(iOS)
private struct AuthPopupWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#elseif os(macOS)
private struct AuthPopupWebView: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView { webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
#endif
