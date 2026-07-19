# Third-party notices — Oriel Engine

Oriel (Apache License 2.0) includes optional Mac support for **Oriel Engine**, which links against the Chromium Embedded Framework (CEF) at build / package time.

## Chromium Embedded Framework (CEF)

- Source / binaries: https://cef-builds.spotifycdn.com / https://bitbucket.org/chromiumembedded/cef
- License: BSD-style (see `LICENSE.txt` inside a fetched CEF Standard distribution)
- Chromium and its third-party components ship additional licenses inside the CEF tree (`LICENSE.txt`, `chrome://credits` equivalent notices)

Oriel does **not** re-license Chromium. The Oriel-authored bridge under `Sources/CEF/` is Apache 2.0.

Release Mac installers (`.dmg` / `.pkg`) may embed a prebuilt CEF framework and Oriel Helper apps built from `Sources/CEF/Helper/process_helper_mac.cc`.
