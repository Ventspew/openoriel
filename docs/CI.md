# CI

## Workflows

| Workflow | Purpose |
|----------|---------|
| Build unsigned IPA | macOS 15 + recent Xcode → `build/ipa/*.ipa` on every `main` push that touches Sources |
| Release | Tag `v*` → macOS DMG attached to the GitHub Release |
| CodeQL | Manual Swift build + analyze |

## Xcode

Prefer **Xcode 16.4+** on runners. Older 16.2 SDKs lack `WKWebExtension` APIs that Oriel uses.

## CodeQL default setup conflict

If Actions show:

> CodeQL analyses from advanced configurations cannot be processed when the default setup is enabled

disable **Default setup** under GitHub → Settings → Code security and analysis → Code scanning, and keep the advanced `.github/workflows/codeql.yml` workflow.

ZIPFoundation is vendored under `Sources/ThirdParty/ZIPFoundation` (MIT) so builds no longer depend on SwiftPM resolution during CodeQL autobuild.
