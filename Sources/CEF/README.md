# Oriel Engine (Mac Blink / CEF)

This folder is **open source** (Apache 2.0, same as the rest of Oriel). It is the Mac-only bridge that hosts real Blink inside Oriel tabs via the Chromium Embedded Framework (CEF).

## What lives here (in git)

| File | Role |
|------|------|
| `OrielCEFBridge.h` / `.mm` | ObjC++ bridge: create/load CEF browser, wire cookies / navigation |
| `OrielCEFSupport.swift` | Swift helpers / availability |
| `CefWebHostView.swift` | SwiftUI / AppKit host view for in-tab Engine |
| `Oriel-Bridging-Header.h` | Bridging header |
| `Helper/process_helper_mac.cc` | CEF helper process entry (GPU / Renderer / Plugin / Alerts) |

## What does **not** live in git

The Chromium / CEF **binaries** (~250–320 MB) are third-party and too large to vendor. They are fetched once by:

```bash
bash Scripts/fetch-cef-macos.sh
bash Scripts/build-oriel-engine-macos.sh
```

into `~/Library/Application Support/Oriel/CEF/` (symlink `Vendor/CEF`). Release **DMG / PKG** installers already embed the built Engine — end users never run these scripts.

See [`docs/CEF_NATIVE.md`](../../docs/CEF_NATIVE.md) and [`docs/DUAL_ENGINE.md`](../../docs/DUAL_ENGINE.md).

CEF / Chromium remain under their upstream licenses (BSD-style + third-party notices inside the CEF distribution). Oriel’s glue in this folder is Apache 2.0.
