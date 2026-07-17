# Oriel — Web Extensions

Oriel can load **Chrome/Firefox-style WebExtensions** on **macOS 15.4+** using Apple’s `WKWebExtension` APIs (the same family Safari uses). This is **not** a full Chrome browser and **not** one-click Chrome Web Store install.

## What works

| Capability | Notes |
|------------|--------|
| Install unpacked folder | Choose a directory that contains `manifest.json` |
| Install `.zip` | Standard extension archive |
| Install `.crx` | Header is stripped; remaining zip is extracted |
| Enable / disable / remove | Managed in **Extensions** (⌘⇧E) |
| Browse Chrome Web Store | Opens [chromewebstore.google.com](https://chromewebstore.google.com/) in a tab so you can find packages |

## What does not work

| Limitation | Why |
|------------|-----|
| One-click “Add to Chrome” | Chrome Web Store install APIs are Chrome-only |
| Every Chrome extension | Manifest / API differences (MV3 service workers, `chrome.*` quirks) |
| Chrome Apps (packaged apps) | Deprecated by Google; not supported |
| Full extension UI parity | Action popups / options pages / native messaging need more work over time |
| iPhone / iPad | Oriel on iOS cannot offer the same extension runtime under App Store WebKit rules |

## Honest workflow

1. Open **Extensions** or **Settings → Extensions**
2. Optionally **Browse Chrome Web Store** and download a `.zip` / source package when the developer provides one
3. In Oriel, **Install…** and select the folder, `.zip`, or `.crx`
4. Reload tabs if a content script does not appear immediately

## Privacy

Extensions run with the permissions in their manifest. Oriel grants requested host permissions at install time (Chrome-like). Only install extensions you trust.
