# Oriel — Architecture

**Oriel** is a native multiplatform browser by [inveil.net](https://inveil.net), built on SwiftUI and WKWebView.

## Goals

1. Fully native Apple-platform UX  
2. Shared codebase where practical  
3. Safari-like simplicity without cloning Safari  
4. Brave-inspired privacy controls without cloning Brave  
5. Modular, testable, App Store–compatible design  

## Pattern

**MVVM + services**, with Observation (`@Observable`) where available.

- **Views** — SwiftUI only; no business logic beyond presentation  
- **View models** — thin; coordinate a single screen or chrome region  
- **Services / stores** — own persistence and side effects  
- **Models** — value types where possible  

Avoid: massive view models, massive SwiftUI views, global mutable singletons, force unwraps, unnecessary third-party deps.

## Module responsibilities

| Module | Responsibility |
|--------|----------------|
| **App** | `@main`, scene setup, dependency composition root |
| **BrowserCore** | `BrowserSession`, shared types, URL/search helpers |
| **WebView** | `BrowserWebView`, `WebViewCoordinator`, navigation policy |
| **Tabs** | `BrowserTab`, `TabManager`, overview, closed-tab stack |
| **Navigation** | Address field parsing, search engines, loading chrome state |
| **History** | `HistoryEntry`, `HistoryStore` (skip private) |
| **Bookmarks** | `Bookmark`, folders, `BookmarkStore` |
| **Downloads** | `DownloadManager`, progress, cancel/retry |
| **Privacy** | `PrivacySettings`, dashboard stats, per-site shields |
| **ContentBlocking** | `ContentBlockerManager`, rule compile / import pipeline |
| **Settings** | `BrowserSettings`, appearance, restore, search default |
| **Persistence** | SwiftData / files, Keychain wrappers |
| **PlatformUI** | iPhone / iPad / macOS adaptive chrome |

## Primary types (target)

```
BrowserSession
BrowserTab
TabManager
BrowserWebView
WebViewCoordinator
NavigationState
Bookmark / BookmarkStore
HistoryEntry / HistoryStore
DownloadManager
PrivacySettings
ContentBlockerManager
WebsitePermissionManager
BrowserSettings
```

## Data flow (Phase 1)

```
AddressBar → NavigationInput.resolve() → BrowserTab.load(url)
     ↑                                         ↓
NavigationChrome ←── NavigationState ←── WebViewCoordinator (WKNavigationDelegate)
```

## Platform adaptation

| Surface | iPhone | iPad | macOS |
|---------|--------|------|-------|
| Chrome | Bottom toolbar | Adaptive top / sidebar | Native toolbar + optional sidebar |
| Tabs | Full-screen overview | Adaptive | Tab bar or sidebar |
| Menus | Sheets | Sheets + keyboard | Menu bar + shortcuts |
| Windows | Single scene | Multitasking | Multi-window + restoration |

Use `#if os(macOS)` / `#if os(iOS)` only where UIKit/AppKit or API differences require it.

## Security boundaries

- All page content is untrusted  
- No arbitrary native bridges for page JS  
- Validate schemes before navigation  
- Private tabs use non-persistent `WKWebsiteDataStore`  
- Secrets only in Keychain  
- Document WebKit capability limits in `PRIVACY_LIMITATIONS.md`  

## Testing strategy

- Unit tests against pure helpers and stores via protocols  
- UI tests for critical flows (open site, tabs, bookmark, private, shields, clear data)  
- Dependency injection at the composition root  

## Future sync

Persistence interfaces should allow an encrypted sync backend later. No sync in MVP.
