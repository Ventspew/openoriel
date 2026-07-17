# Oriel — Privacy Limitations

Oriel is made by [inveil.net](https://inveil.net). This document states what privacy protections WebKit / Apple platforms support, and what Oriel **cannot** fully guarantee. Do not overclaim in UI copy or marketing.

## What Oriel can do (within WebKit)

| Protection | Mechanism | Notes |
|------------|-----------|--------|
| Tracker / ad blocking | `WKContentRuleList` / Safari Content Blocker style JSON | Effectiveness depends on rule quality and WebKit matching |
| HTTPS upgrade | Navigate `http` → `https` when safe heuristics allow | May break sites that only speak HTTP; user can override |
| Third-party cookies | `WKWebpagePreferences` / data store configuration where available | Exact behavior varies by OS version |
| Clear site data | `WKWebsiteDataStore` remove APIs | Works for data WebKit stores |
| Private browsing | Non-persistent `WKWebsiteDataStore` | Separate from normal tabs; not stored in history |
| Per-site shields | Local settings + rule lists | Applied when WebView configuration is created/updated |
| Permission prompts | Camera, mic, location via WebKit / system | User must grant OS permissions; “Notifications” support is limited |
| Privacy dashboard | Counts from content-blocker / upgrade events Oriel observes | Counts only events Oriel can observe |

## What Oriel cannot fully control

| Limitation | Why |
|------------|-----|
| Full network-level firewall | Apps cannot intercept all system traffic; browsing goes through WebKit |
| Blocking all fingerprinting | WebKit exposes APIs pages can use; no complete fingerprint defense |
| Guaranteed tracker kill | Dynamic / first-party / CNAME trackers may evade static rules |
| Custom TLS / certificate pinning for all sites | Must not disable system certificate validation |
| Reading every blocked request payload | Content blockers report limited callback detail |
| Replacing WebKit privacy model | Apple does not allow alternative engines in App Store browsers on iOS |
| Full Chrome Web Store one-click install | Store install APIs are Chrome-only; Oriel loads packages via `WKWebExtension` on macOS |
| Cross-app tracking prevention outside WebKit | Other apps and system services are out of scope |
| Perfect “incognito” against the network | Destination sites and network operators still see traffic |
| Bypass publisher paywalls / DRM | Explicitly out of scope and not implemented |

## Honest UI language

Prefer:

- “Blocked *N* requests matching your filter lists”  
- “Upgraded this connection to HTTPS when possible”  
- “Private tabs don’t save history on this device”  

Avoid:

- “100% private”  
- “Invisible to trackers”  
- “Military-grade browsing”  
- Claims that imply a custom engine or VPN-level protection without shipping one  

## Content blocking pipeline (design)

1. Ship a **small bundled example ruleset** for MVP  
2. `ContentBlockerManager` validates → converts (if needed) → compiles → applies  
3. Later: import community lists with sanitization and size limits  
4. Never execute code from filter lists — JSON rules only  

## Platform restrictions (iOS especially)

- Must use WebKit on iOS for App Store distribution  
- Background networking and content blocker extension limits apply if using Safari Content Blocker extension targets later  
- Camera / mic / location require Info.plist usage strings and user consent  
- Download locations are sandboxed  

## Review checklist before shipping privacy copy

- [ ] Every shield claim maps to a documented WebKit API  
- [ ] Dashboard numbers are defined (what is counted)  
- [ ] Private mode behavior documented for history, cookies, downloads  
- [ ] No misleading comparisons to VPN or custom engines  
