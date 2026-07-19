# Chrome / Firefox extensions on iOS & iPadOS

## Verdict

**Yes — with WebKit’s built-in host, not a Chromium/Gecko engine.**

From **iOS / iPadOS 18.4** (and macOS 15.4), Apple’s `WKWebExtension` API lets any WebKit browser load standard WebExtension packages (`manifest.json` + resources). Oriel already uses that host on iPhone, iPad, and Mac.

A full “run Chromium extensions exactly like Chrome” or “run Gecko add-ons exactly like Firefox” converter is **not possible** inside an App Store WebKit app: you cannot ship Chromium or Gecko, and you cannot polyfill every privileged API. What *is* possible — and what Oriel ships — is a **built-in packaging/manifest compat layer** plus theme import.

## What works today in Oriel

| Path | iOS / iPadOS 18.4+ | Notes |
|------|--------------------|--------|
| `.zip` WebExtension | Yes | File importer |
| Chrome `.crx` | Yes | Header stripped → ZIP |
| Firefox `.xpi` | Yes | ZIP |
| Chrome Web Store | Yes | Download + stage |
| Firefox AMO | Yes | “Add to Oriel” bridge |
| Safari Web Extension `.appex` | Yes | Peel `Resources/` tree |
| Scan `/Applications` for Safari | macOS only | No Applications scan on iOS |
| Extension themes (`theme` in manifest) | Yes | Colors + optional NTP image |

## Chrome Web Store on iPhone / iPad

The store often shows **“not compatible with a phone”** when it sees a mobile Safari UA. Oriel counters that **without** forcing a tiny desktop layout on every site:

1. **Desktop Chrome UA + desktop content mode on CWS only** — a mobile Safari UA makes Google serve a marketing landing page (“boost your desktop browser”) with **no** extension/theme catalog. Other sites stay mobile unless the user requests desktop.
2. **Readable layout** (`StoreReadableLayout`) on CWS/AMO — kills CWS’s `.IqBfM { min-width: 1249px/1280px }` shell so the real catalog stays phone-readable.
3. **JS spoof** of `navigator.userAgent` / `userAgentData` / `platform` / `maxTouchPoints` so install UI stays available.
4. **CRX downloads** also use the desktop Chrome UA in `WebExtensionManager`.
5. **Hide** phone-incompatibility / “desktop only” banners (multilingual).
6. **Sticky Install bar** on extension detail pages (**Add to Oriel**) when the mobile-width store hides Chrome’s native install CTA — plus rewrite any native CTA that does appear. Install is handled in-app (CRX download); no Python proxy.
7. **Multilingual** (`StoreBridgeI18n`): 60+ locales for CTA detection and Oriel labels.
8. **Installed state**: inject Chrome store IDs + Firefox AMO slugs on **macOS, iOS, and iPadOS** — including **theme-only** packages.

## Firefox Add-ons (AMO) on iPhone / iPad

AMO often shows **“You’ll need Firefox…”** / Download Firefox when it does not see desktop Firefox. Same readable-mobile approach:

1. **Mobile Safari UA** for AMO browsing; XPI download keeps its own request headers.
2. **Mobile content mode** unless the user requests desktop.
3. **JS spoof** + `InstallTrigger` stub at document-start.
4. **Hide** download-Firefox banners; relabel the native install control to **Add to Oriel** / **Remove from Oriel**.
5. Same shared **`StoreBridgeI18n`** catalog for localized Firefox CTAs and Oriel labels.

## Built-in compat (`ManifestCompatNormalizer`)

Runs on every staged package (CRX / XPI / zip / Safari extract):

- `browser_action` / `page_action` → `action`
- Force non-persistent backgrounds; prefer `service_worker` when both shapes exist
- MV3 `scripts` → `service_worker` when needed
- Drop Safari `browser_specific_settings.safari` and legacy Firefox `applications`
- Strip permissions WebKit cannot host (`debugger`, `proxy`, `nativeMessaging`, …)
- Drop `options_ui.chrome_style`

This improves **load acceptance**. It does **not** invent missing APIs.

## Hard limits (Apple / WebKit)

1. **WebKit ≠ Chromium ≠ Gecko** — APIs and permissions differ; many Chrome/Firefox-only features stay unsupported.
2. **No alternate browser engine** — on iOS, browsers must use WebKit; Chrome and Firefox for iOS are also WebKit-based and cannot host full desktop-extension engines either.
3. **OS floor** — Oriel’s extension host requires **18.4+** at runtime (app deployment target may be lower; UI shows unsupported below that).
4. **Themes** — Oriel maps colors / NTP images into its own chrome; it does not emulate Chrome’s full theme engine.

## Sources

- [WebKit Features in Safari 18.4 — Web Extensions](https://webkit.org/blog/16574/webkit-features-in-safari-18-4/)
- [Safari 18.4 Release Notes — WKWebExtension](https://developer.apple.com/documentation/safari-release-notes/safari-18_4-release-notes)
- [WKWebExtension](https://developer.apple.com/documentation/webkit/wkwebextension)
