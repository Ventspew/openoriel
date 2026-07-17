import Foundation

/// Hosts where sign-in / OAuth must not be interrupted by content blocking.
enum AuthHostAllowlist {
    private static let hosts: Set<String> = [
        "accounts.google.com",
        "myaccount.google.com",
        "oauthaccountmanager.googleapis.com",
        "oauth2.googleapis.com",
        "accounts.youtube.com",
        "appleid.apple.com",
        "login.live.com",
        "login.microsoftonline.com",
        "github.com",
        "account.live.com"
    ]

    static func shouldBypassContentBlocking(for url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        if hosts.contains(host) { return true }
        return hosts.contains { host.hasSuffix(".\($0)") }
    }
}
