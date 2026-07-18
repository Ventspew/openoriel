import Foundation
import AuthenticationServices
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// Bridges system password autofill (iCloud Keychain credential picker).
@MainActor
enum PasswordAutofillService {
    static func requestCredentials(for url: URL) async -> ASPasswordCredential? {
        guard let host = url.host, !host.isEmpty else { return nil }
        return await withCheckedContinuation { continuation in
            let provider = ASAuthorizationControllerCredentialProvider()
            provider.request(for: host) { credential in
                continuation.resume(returning: credential)
            }
        }
    }
}

@MainActor
private final class ASAuthorizationControllerCredentialProvider: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private var completion: ((ASPasswordCredential?) -> Void)?
    private var controller: ASAuthorizationController?

    func request(for host: String, completion: @escaping (ASPasswordCredential?) -> Void) {
        self.completion = completion
        let request = ASAuthorizationPasswordProvider().createRequest()
        let controller = ASAuthorizationController(authorizationRequests: [request])
        self.controller = controller
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
        _ = host
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(iOS)
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        if let window = windows.first(where: \.isKeyWindow) ?? windows.first {
            return window
        }
        return UIWindow(frame: UIScreen.main.bounds)
        #elseif os(macOS)
        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            return window
        }
        return NSWindow(contentRect: .init(x: 0, y: 0, width: 1, height: 1), styleMask: [.borderless], backing: .buffered, defer: false)
        #endif
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        let credential = authorization.credential as? ASPasswordCredential
        completion?(credential)
        completion = nil
        self.controller = nil
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion?(nil)
        completion = nil
        self.controller = nil
    }
}
