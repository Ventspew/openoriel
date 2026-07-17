# Oriel (openoriel)

**Oriel** is a privacy-minded native browser for iOS, iPadOS, and macOS — named after a bay window: a sheltered place to look out at the world.

- **Official website:** [openoriel.com](https://openoriel.com)
- **Made by:** [inveil.net](https://inveil.net)
- **GitHub:** [github.com/macdirtycow/openoriel](https://github.com/macdirtycow/openoriel)

Built with Swift, SwiftUI, and Apple’s WebKit (`WKWebView`). Original UI and branding — not a Safari or Brave clone.

## Requirements

- Xcode 16+
- iOS 17+ / iPadOS 17+ / macOS 14+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Setup

```bash
git clone https://github.com/macdirtycow/openoriel.git
cd openoriel
xcodegen generate
open Oriel.xcodeproj
```

## Build (CLI)

```bash
xcodegen generate
xcodebuild -scheme Oriel -destination 'platform=iOS Simulator,name=iPhone 16' build
xcodebuild -scheme Oriel -destination 'platform=macOS' build
```

## Docs

- [Implementation plan](docs/IMPLEMENTATION_PLAN.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Privacy limitations](docs/PRIVACY_LIMITATIONS.md)
- [Entitlements](docs/ENTITLEMENTS.md)

## Non-goals

No AI assistant, no Qadbak, no crypto/rewards/ads network, no custom browser engine.
