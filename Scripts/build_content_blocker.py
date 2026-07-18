#!/usr/bin/env python3
"""Build Oriel WKContentRuleList JSON using AdGuard SafariConverterLib.

Requires ConverterTool (GPL-3.0 build tool — not linked into Oriel):

  git clone https://github.com/AdguardTeam/SafariConverterLib.git /tmp/SafariConverterLib
  cd /tmp/SafariConverterLib && swift build -c release --product ConverterTool
  export ORIEL_CONVERTER=/tmp/SafariConverterLib/.build/out/Products/Release/ConverterTool

Then:

  python3 Scripts/build_content_blocker.py

Also pulls DuckDuckGo Tracker Blocklists (apple-tds) domain data:
  https://github.com/duckduckgo/tracker-blocklists
"""

from __future__ import annotations

import json
import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "Resources" / "ContentBlocker"
MAX_RULES = 45_000
WORK = Path("/tmp/oriel-filters")

FILTER_URLS = {
    "easylist.txt": "https://easylist.to/easylist/easylist.txt",
    "easyprivacy.txt": "https://easylist.to/easylist/easyprivacy.txt",
    "fanboy-cookie.txt": "https://secure.fanboy.co.nz/fanboy-cookiemonster.txt",
    # Safari-oriented AdGuard snapshots (still Adblock/AdGuard syntax)
    "adguard-base.txt": "https://filters.adtidy.org/extension/safari/filters/2_optimized.txt",
    "adguard-tracking.txt": "https://filters.adtidy.org/extension/safari/filters/3_optimized.txt",
    "adguard-social.txt": "https://filters.adtidy.org/extension/safari/filters/4_optimized.txt",
    "adguard-annoyances.txt": "https://filters.adtidy.org/extension/safari/filters/14_optimized.txt",
    # French filter — covers Larousse `.pub`, Prisma Media placers, Hubvisor stacks
    "adguard-french.txt": "https://filters.adtidy.org/extension/safari/filters/16_optimized.txt",
}

# DuckDuckGo Tracker Blocklists (derived from Tracker Radar crawl data)
DDG_APPLE_TDS_URL = "https://staticcdn.duckduckgo.com/trackerblocking/v4/apple-tds.json"

GROUPS = {
    "ads": ["easylist.txt", "adguard-base.txt", "adguard-french.txt"],
    "privacy": ["easyprivacy.txt", "adguard-tracking.txt"],
    "annoyances": ["fanboy-cookie.txt", "adguard-annoyances.txt", "adguard-social.txt"],
}

ALLOWLIST_DOMAINS = [
    "*accounts.google.com",
    "*myaccount.google.com",
    "*accounts.youtube.com",
    "*oauth2.googleapis.com",
    "*appleid.apple.com",
    "*login.live.com",
    "*login.microsoftonline.com",
    "*github.com",
]

# Domains DDG sometimes marks "ignore" but that still serve ads (Larousse stack).
FORCE_BLOCK_HOSTS = [
    "themoneytizer.com",
    "ads.themoneytizer.com",
    "ayads.co",
    "hubvisor.io",
    "cdn.hubvisor.io",
    "viously.com",
    "cdn.viously.com",
    "getviously.com",
    "sonar.viously.com",
    "pmdstatic.net",
    "prismamedia.com",
    "prismamediadigital.com",
    "prismaconnect.fr",
    "googleadservices.com",
    "popads.net",
    "veinteractive.com",
    "imagino.com",
    "poool.fr",
    "poool-subscribe.fr",
    "sprkly.me",
    "seedtag.com",
    "pbstck.com",
    "videoplayerhub.com",
]

# Never turn these DDG "block" domains into WK rules (break sites / login / CDN).
DDG_SKIP_HOSTS = {
    "google.com",
    "google.ch",
    "google.com.au",
    "gstatic.com",
    "fonts.googleapis.com",
    "maps.googleapis.com",
    "www.googleapis.com",
    "storage.googleapis.com",
    "commondatastorage.googleapis.com",
    "ampproject.org",
    "youtube-nocookie.com",
    "facebook.com",
    "facebook.net",
    "cdninstagram.com",
    "amazon.com",
    "ssl-images-amazon.com",
    "twitch.tv",
    "apple.com",
}

YOUTUBE_RULES = [
    {"trigger": {"url-filter": r".*youtube\.com\/pagead\/"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*youtube\.com\/ptracking"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*youtube\.com\/api\/stats\/ads"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*youtube\.com\/get_midroll_"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*youtube\.com\/youtubei\/v1\/player\/ad_break"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*youtube\.com\/pcs\/activeview"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*ad\.youtube\.com"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*googlevideo\.com\/.*[&?]oad="}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*googlevideo\.com\/.*ctier=L"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*doubleclick\.net"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*googlesyndication\.com"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*googleadservices\.com"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": r".*adservice\.google\."}, "action": {"type": "block"}},
    {
        "trigger": {"url-filter": r".*youtube\.com"},
        "action": {
            "type": "css-display-none",
            "selector": (
                "ytd-ad-slot-renderer, ytd-promoted-sparkles-web-renderer, "
                "ytd-in-feed-ad-layout-renderer, ytd-action-companion-ad-renderer, "
                "ytd-display-ad-renderer, ytd-banner-promo-renderer, "
                "ytd-player-legacy-desktop-watch-ads-renderer, "
                "#player-ads, #masthead-ad, "
                ".ytp-ad-module, .ytp-ad-player-overlay, .ytp-ad-overlay-container, "
                ".ytp-ad-action-interstitial, .ytp-ad-image-overlay, .video-ads"
            ),
        },
    },
]

BASE_HOSTS = [
    "doubleclick.net",
    "googlesyndication.com",
    "googleadservices.com",
    "amazon-adsystem.com",
    "adnxs.com",
    "adsrvr.org",
    "outbrain.com",
    "taboola.com",
    "criteo.com",
    "criteo.net",
    "pubmatic.com",
    "rubiconproject.com",
    "openx.net",
    "casalemedia.com",
    "bidswitch.net",
    "scorecardresearch.com",
    "quantserve.com",
    "moatads.com",
    "3lift.com",
    "teads.tv",
    "smartadserver.com",
    "sascdn.com",
    "viously.com",
    "cdn.viously.com",
    "getviously.com",
    "media.net",
    "mgid.com",
    "revcontent.com",
    "carbonads.com",
    "buysellads.com",
    "propellerads.com",
    "popads.net",
    "exoclick.com",
    "juicyads.com",
    "googletagservices.com",
    "pagead2.googlesyndication.com",
    "googletagmanager.com",
]


def allowlist_rule() -> dict:
    return {
        "trigger": {"url-filter": ".*", "if-domain": ALLOWLIST_DOMAINS},
        "action": {"type": "ignore-previous-rules"},
    }


def download(name: str, url: str, *, force: bool = False) -> Path:
    WORK.mkdir(parents=True, exist_ok=True)
    path = WORK / name
    if not force and path.exists() and path.stat().st_size > 1000:
        print(f"Using cached {name}")
        return path
    print(f"Downloading {name}…")
    subprocess.check_call(
        ["curl", "-fsSL", "-A", "OrielFilterBuild/1.0", "-o", str(path), url]
    )
    return path


def converter_path() -> Path:
    env = os.environ.get("ORIEL_CONVERTER")
    candidates = [
        Path(env) if env else None,
        Path("/tmp/SafariConverterLib/.build/out/Products/Release/ConverterTool"),
        Path("/tmp/SafariConverterLib/.build/release/ConverterTool"),
    ]
    for c in candidates:
        if c and c.is_file():
            return c
    raise SystemExit(
        "ConverterTool not found. Build AdGuard SafariConverterLib and set ORIEL_CONVERTER.\n"
        "See Scripts/build_content_blocker.py docstring."
    )


def convert_group(name: str, files: list[str], converter: Path) -> Path:
    combined = WORK / f"group-{name}.txt"
    parts = []
    for f in files:
        parts.append((WORK / f).read_text(encoding="utf-8", errors="ignore"))
    combined.write_text("\n".join(parts), encoding="utf-8")
    out = WORK / f"safari-{name}.json"
    cmd = [
        str(converter),
        "convert",
        "--safari-version",
        "17.0",
        "--advanced-blocking",
        "false",
        "--input-path",
        str(combined),
        "--safari-rules-json-path",
        str(out),
    ]
    print(f"Converting {name} ({combined.stat().st_size // 1024} KB)…")
    subprocess.check_call(cmd)
    return out


# CDN / ad keywords that must never be re-allowed via ignore-previous-rules.
BAD_EXCEPTION_MARKERS = (
    "themoneytizer",
    "hubvisor",
    "viously",
    "getviously",
    "sascdn",
    "smartadserver",
    "ayads",
    "seedtag",
    "sprkly",
    "pmdstatic",
    "prismamedia",
    "poool",
    "teads",
    "taboola",
    "doubleclick",
    "googlesyndication",
    "googleadservices",
)


def should_drop(rule: dict) -> bool:
    if rule.get("action", {}).get("type") != "block":
        return False
    filt = rule.get("trigger", {}).get("url-filter", "")
    low = filt.lower()
    if "youtube" in low and "get_video" in low:
        return True
    return False


def should_drop_any(rule: dict) -> bool:
    """Drop bad exceptions that re-enable known ad CDNs."""
    act = rule.get("action", {}).get("type")
    filt = (rule.get("trigger", {}) or {}).get("url-filter", "").lower()
    if act == "ignore-previous-rules":
        if any(m in filt for m in BAD_EXCEPTION_MARKERS):
            return True
    return should_drop(rule) if act == "block" else False


def load_ddg_block_hosts(path: Path) -> list[str]:
    data = json.loads(path.read_text(encoding="utf-8"))
    trackers = data.get("trackers") or {}
    hosts: set[str] = set()
    for domain, info in trackers.items():
        if not isinstance(domain, str) or "." not in domain:
            continue
        low = domain.lower().strip(".")
        if low in DDG_SKIP_HOSTS:
            continue
        if (info or {}).get("default") == "block":
            hosts.add(low)
    for h in FORCE_BLOCK_HOSTS:
        hosts.add(h.lower())
    # Entity domains for Prisma / Moneytizer even when tracker default is ignore
    domains_map = data.get("domains") or {}
    for domain, entity in domains_map.items():
        ent = str(entity).lower()
        if any(
            x in ent
            for x in (
                "prisma media",
                "the moneytizer",
                "sublime skinz",
                "smartadserver",
                "teads",
                "seedtag",
            )
        ):
            hosts.add(domain.lower().strip("."))
    return sorted(hosts)


def host_block_rules(hosts: list[str]) -> list[dict]:
    rules = []
    for h in hosts:
        rules.append(
            {
                "trigger": {"url-filter": ".*" + re.escape(h)},
                "action": {"type": "block"},
            }
        )
    return rules


def write_chunked(prefix: str, rules: list[dict]) -> None:
    for old in OUT_DIR.glob(f"{prefix}*.json"):
        old.unlink()
    if not rules:
        return
    room = MAX_RULES - 1
    total = (len(rules) + room - 1) // room
    for i in range(0, len(rules), room):
        chunk = list(rules[i : i + room])
        chunk.append(allowlist_rule())
        idx = i // room
        name = prefix if total == 1 else f"{prefix}-{idx + 1}"
        path = OUT_DIR / f"{name}.json"
        path.write_text(json.dumps(chunk, separators=(",", ":")), encoding="utf-8")
        print(f"  Wrote {path.name}: {len(chunk)} rules ({path.stat().st_size // 1024} KB)")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    converter = converter_path()
    print("Using", converter)

    for name, url in FILTER_URLS.items():
        download(name, url)

    ddg_path = download("apple-tds.json", DDG_APPLE_TDS_URL, force=True)
    ddg_hosts = load_ddg_block_hosts(ddg_path)
    print(f"DuckDuckGo apple-tds: {len(ddg_hosts)} block hosts")

    # Clear previous generated lists (keep example-blocklist + hand-maintained site-fixes)
    for pattern in (
        "oriel-ads*.json",
        "oriel-privacy*.json",
        "oriel-annoyances*.json",
        "oriel-easylist*.json",
        "oriel-easyprivacy*.json",
        "oriel-cosmetic*.json",
        "oriel-base*.json",
        "oriel-ddg*.json",
        "oriel-youtube-ads*.json",
    ):
        for old in OUT_DIR.glob(pattern):
            old.unlink()

    merged_hosts = sorted(set(BASE_HOSTS) | set(ddg_hosts) | set(FORCE_BLOCK_HOSTS))
    print(f"oriel-base hosts: {len(merged_hosts)}")
    write_chunked("oriel-base", host_block_rules(merged_hosts))

    for group, files in GROUPS.items():
        path = convert_group(group, files, converter)
        rules = [
            r
            for r in json.loads(path.read_text(encoding="utf-8"))
            if not should_drop_any(r)
        ]
        print(f"{group}: {len(rules)} rules after sanitize")
        write_chunked(f"oriel-{group}", rules)

    yt = list(YOUTUBE_RULES) + [allowlist_rule()]
    (OUT_DIR / "oriel-youtube-ads.json").write_text(
        json.dumps(yt, separators=(",", ":")), encoding="utf-8"
    )
    print(f"Wrote oriel-youtube-ads.json: {len(yt)} rules")
    print("Done. Hand-maintained oriel-site-fixes.json was left untouched.")


if __name__ == "__main__":
    main()
