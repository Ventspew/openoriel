# Dual engine strategy (WebKit + Chromium)

Oriel’s goal: **best of both worlds** without breaking Apple rules or pretending Chromium runs on iPhone.

The page-engine preference is **edition-agnostic**: it works in **Classic Oriel** and **Oriel Pulse** the same way.

## Platform rules

| Platform | Allowed engines | Oriel behavior |
|----------|-----------------|----------------|
| **iPhone / iPad** | **WebKit only** (App Store / BrowserEngineKit policy) | Always WebKit. Chromium Native is unavailable. |
| **Mac** | WebKit and/or Chromium | WebKit default. Optional **Chromium Compatible** (Chrome UA + Client Hints on WebKit) now. **Chromium Native** (CEF) when a framework is linked later. |

## Modes in Settings → Appearance → Page engine

Available whether you are on Classic or Pulse:

1. **WebKit** — system integration, Shields, `WKWebExtension`, Private tabs, Keychain.
2. **Chromium Compatible** (Mac) — still WebKit rendering, but Chrome desktop User-Agent, `navigator.userAgentData` Client Hints, and a thin `window.chrome` stub.
3. **Chromium Native** (Mac, future) — real Chromium/CEF process when `OrielChromium.framework` / CEF is linked into the Mac target. Until then Oriel falls back to Compatible and can **Open in system Chrome**.

## Mac Chromium features (shipped)

| Feature | Where |
|---------|--------|
| Default engine picker | Settings → Appearance → Page engine |
| Auto Chromium Compatible for stubborn sites | Chromium features panel (Meet, Teams, Discord, Docs, …) |
| Per-site engine / hand-off to system Chrome | Shields → This site · Chromium features · Page → Page Engine |
| Per-tab engine override | Page → Page Engine |
| Chrome Client Hints inject | Toggle in Chromium features (on by default) |
| Open in Chrome / Arc / Brave / Edge | Page menu, Shields, Pulse Corner |

Priority when resolving an engine: **tab override → site preference → auto list → global Settings**.

## Why not Chromium on iOS?

Apple requires browsers that navigate the open web on iOS/iPadOS to use WebKit. Shipping CEF or Blink there is not App Store–viable for a general browser.

## Roadmap for Native Chromium (Mac)

1. Add an optional Xcode target / SPM binary that embeds CEF or a thin Chromium shell.
2. Implement `PageRenderingEngine` with a CEF-backed Mac view beside `WKWebView`.
3. Keep Shields/content blockers WebKit-side; map what is possible under Chromium separately.

## Honesty

“Chromium Compatible” is **not** Blink. It is the practical bridge today: Chrome identity on Apple’s engine, plus hand-off to a real Chromium browser when a site still needs one.
