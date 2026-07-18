#!/usr/bin/env python3
"""Convert EasyList / EasyPrivacy into WKContentRuleList JSON for Oriel.

Produces multiple chunks (WebKit max 50k rules per list):
  oriel-easylist-1.json / oriel-easylist-2.json
  oriel-easyprivacy-1.json / oriel-easyprivacy-2.json
  oriel-cosmetic.json
  oriel-youtube-ads.json

Each chunk ends with an OAuth/login allowlist (ignore-previous-rules only
applies within the same compiled list).
"""

from __future__ import annotations

import json
import re
from pathlib import Path

MAX_RULES_PER_FILE = 45_000
OUT_DIR = Path(__file__).resolve().parents[1] / "Resources" / "ContentBlocker"

RESOURCE_MAP = {
    "script": "script",
    "image": "image",
    "stylesheet": "style-sheet",
    "object": "media",
    "xmlhttprequest": "raw",
    "ping": "raw",
    "media": "media",
    "font": "font",
    "subdocument": "document",
    "other": "raw",
    "fetch": "raw",
    "websocket": "raw",
}

DOMAIN_RULE = re.compile(r"^\|\|([a-z0-9._*-]+)(?:\^|\/|\||$)(.*)$", re.I)
COSMETIC = re.compile(r"^([^#]*)##(.+)$")
COSMETIC_EXC = re.compile(r"^([^#]*)#@#(.+)$")
# Simple path / keyword network rules: /ads.js$script
PATH_CONTAINS = re.compile(r"^\/([a-z0-9_\-./%]{3,80})\/?(?:\$.*)?$", re.I)

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

# Never emit a bare host block for these — path was dropped → blank homepage / broken APIs.
PROTECTED_HOST_SUFFIXES = (
    "youtube.com",
    "youtube-nocookie.com",
    "youtu.be",
    "googlevideo.com",
    "ytimg.com",
    "ggpht.com",
    "googleapis.com",
    "gstatic.com",
    "google.com",
    "googleusercontent.com",
    "gvt1.com",
    "gvt2.com",
)


def allowlist_rule() -> dict:
    return {
        "trigger": {"url-filter": ".*", "if-domain": ALLOWLIST_DOMAINS},
        "action": {"type": "ignore-previous-rules"},
    }


def escape_regex(s: str) -> str:
    return re.escape(s).replace(r"\*", ".*")


def host_is_protected(domain: str) -> bool:
    d = domain.strip().lower().lstrip("*.").rstrip(".")
    if not d:
        return False
    for suffix in PROTECTED_HOST_SUFFIXES:
        if d == suffix or d.endswith("." + suffix):
            return True
    return False


def safe_path_fragment(path: str) -> bool:
    if not path.startswith("/") or len(path) < 2 or len(path) > 100:
        return False
    return all(c.isalnum() or c in "/._-%" for c in path)


def extend_filter_with_rest(filt: str, rest: str) -> str | None:
    """Attach EasyList path/query after ||domain. None = cannot convert safely."""
    rest = (rest or "").strip()
    if not rest:
        return filt
    while rest.startswith("^"):
        rest = rest[1:]
    if rest.startswith("*"):
        rest = rest[1:]
    if not rest:
        return filt

    if rest.startswith("/"):
        path = rest.split("$")[0]
        if "?" in path:
            path, query = path.split("?", 1)
            if safe_path_fragment(path):
                return filt + escape_regex(path)
            key = query.split("&")[0].split("=")[0]
            if key and re.match(r"^[A-Za-z0-9_-]{3,40}$", key):
                return filt + ".*" + escape_regex(key)
            return None
        if "*" in path:
            path = path.split("*", 1)[0]
        if not safe_path_fragment(path):
            return None
        return filt + escape_regex(path[:100])

    # e.g. rest left as `*/gen_204?` already stripped leading *
    if "/" in rest or rest[0].isalnum():
        token = rest.split("?")[0].split("*")[0].split("$")[0]
        token = "/" + token.lstrip("/")
        if safe_path_fragment(token) and len(token) >= 4:
            return filt + ".*" + escape_regex(token)
    return None


def is_bare_host_filter(filt: str, domain: str) -> bool:
    base = domain_to_filter(domain)
    return base is not None and filt == base


def block_is_safe(rule: dict | None, domain: str, path_intended: bool) -> bool:
    """Drop rules that would block all of YouTube / Google APIs."""
    if rule is None:
        return False
    trigger = rule["trigger"]
    filt = trigger["url-filter"]
    bare = is_bare_host_filter(filt, domain)
    if not bare:
        return True
    if not host_is_protected(domain):
        return True
    # Protected bare host: only allow narrowly scoped cases (e.g. YT embed on one site).
    if trigger.get("if-domain"):
        return True
    if trigger.get("load-type") == ["third-party"] and domain.lower().endswith("youtube.com"):
        return True
    # Path was in the EasyList line but we failed to encode it — never fall back to bare.
    if path_intended:
        return False
    return False

def parse_options(opts: str) -> dict:
    result = {
        "third_party": None,
        "resource_types": [],
        "domains": [],
        "unless_domains": [],
        "skip": False,
    }
    if not opts:
        return result
    for part in opts.split(","):
        part = part.strip()
        if not part:
            continue
        low = part.lower()
        if low in ("third-party", "3p"):
            result["third_party"] = True
        elif low in ("~third-party", "first-party", "1p"):
            result["third_party"] = False
        elif low.startswith("domain="):
            for d in part.split("=", 1)[1].split("|"):
                d = d.strip().lower()
                if not d:
                    continue
                if d.startswith("~"):
                    result["unless_domains"].append(d[1:])
                else:
                    result["domains"].append(d)
        elif low.startswith("~"):
            continue
        elif low in RESOURCE_MAP:
            result["resource_types"].append(RESOURCE_MAP[low])
        elif low in (
            "popup",
            "document",
            "elemhide",
            "generichide",
            "genericblock",
            "csp",
            "rewrite",
            "mp4",
            "empty",
            "important",
        ):
            # Unsupported or unsafe for WK network block path
            if low in ("popup", "document", "csp", "rewrite", "mp4", "empty"):
                result["skip"] = True
        elif low.startswith("rewrite=") or low.startswith("csp="):
            result["skip"] = True
    return result


def domain_to_filter(domain: str) -> str | None:
    domain = domain.strip().lower()
    if not domain or domain.startswith("/") or "=" in domain:
        return None
    if domain.count("*") > 2:
        return None
    domain = domain.lstrip(".")
    if domain.startswith("*."):
        domain = domain[2:]
    if "*" in domain:
        if domain.startswith("*") or domain.endswith("*"):
            domain = domain.strip("*")
        else:
            return None
    if not domain or "." not in domain:
        return None
    if len(domain) > 120:
        return None
    return f".*{escape_regex(domain)}"


def make_block(url_filter: str, options: dict) -> dict | None:
    if options.get("skip"):
        return None
    trigger: dict = {"url-filter": url_filter}
    if options.get("third_party") is True:
        trigger["load-type"] = ["third-party"]
    elif options.get("third_party") is False:
        trigger["load-type"] = ["first-party"]
    if options.get("resource_types"):
        trigger["resource-type"] = sorted(set(options["resource_types"]))
    if options.get("domains"):
        trigger["if-domain"] = [
            f"*{d}" if not d.startswith("*") else d for d in options["domains"][:40]
        ]
    if options.get("unless_domains"):
        trigger["unless-domain"] = [
            f"*{d}" if not d.startswith("*") else d for d in options["unless_domains"][:40]
        ]
    return {"trigger": trigger, "action": {"type": "block"}}


def make_ignore(url_filter: str, options: dict) -> dict:
    trigger: dict = {"url-filter": url_filter}
    if options.get("domains"):
        trigger["if-domain"] = [
            f"*{d}" if not d.startswith("*") else d for d in options["domains"][:40]
        ]
    return {"trigger": trigger, "action": {"type": "ignore-previous-rules"}}


def convert_network_line(line: str) -> list[dict]:
    line = line.strip()
    if not line or line.startswith("!") or line.startswith("["):
        return []
    if "##" in line or "#@#" in line or "#?#" in line or "#$#" in line or "#%#" in line:
        return []

    if line.startswith("@@"):
        raw = line[2:]
        opts = ""
        if "$" in raw:
            raw, opts = raw.split("$", 1)
        options = parse_options(opts)
        if raw.startswith("||"):
            m = DOMAIN_RULE.match(raw)
            if not m:
                return []
            filt = domain_to_filter(m.group(1))
            if not filt:
                return []
            return [make_ignore(filt, options)]
        return []

    opts = ""
    body = line
    if "$" in line:
        body, opts = line.split("$", 1)
    options = parse_options(opts)

    if body.startswith("||"):
        m = DOMAIN_RULE.match(body)
        if not m:
            return []
        domain = m.group(1)
        rest = m.group(2) or ""
        filt = domain_to_filter(domain)
        if not filt:
            return []
        path_intended = bool(rest.strip().lstrip("^"))
        extended = extend_filter_with_rest(filt, rest)
        if extended is None:
            # Had a path/query we cannot encode — skip (do NOT fall back to bare host).
            return []
        filt = extended
        rule = make_block(filt, options)
        if not block_is_safe(rule, domain, path_intended):
            return []
        return [rule] if rule else []

    # Anchored URL prefix |http://… or |https://…
    if body.startswith("|http://") or body.startswith("|https://"):
        raw = body[1:]
        raw = raw.rstrip("|").rstrip("^")
        if len(raw) < 12 or len(raw) > 180:
            return []
        if any(c in raw for c in "*?()+[]{}"):
            return []
        filt = escape_regex(raw)
        rule = make_block(filt, options)
        return [rule] if rule else []

    # Path / keyword rules that look like ads (third-party only)
    if body.startswith("/") and body.count("/") >= 2:
        core = body.split("$")[0].strip("/")
        low = core.lower()
        keywords = (
            "advert",
            "banner",
            "sponsor",
            "tracking",
            "tracker",
            "pixel",
            "analytics",
            "doubleclick",
            "pagead",
            "popunder",
            "prebid",
            "taboola",
            "outbrain",
            "/ads/",
            "/ad/",
            "ads.js",
            "ad.js",
        )
        # Avoid ultra-generic "ad" substring matches that break sites
        if any(k.strip("/") in low or k in f"/{low}/" or low.startswith(k.strip("/")) for k in keywords):
            if 3 <= len(core) <= 60 and all(c.isalnum() or c in "/._-%" for c in core):
                filt = f".*{escape_regex('/' + core)}"
                if options.get("third_party") is None:
                    options = dict(options)
                    options["third_party"] = True
                rule = make_block(filt, options)
                return [rule] if rule else []

    return []


def sanitize_selector(sel: str) -> str | None:
    sel = sel.strip()
    if not sel or len(sel) > 300:
        return None
    # Skip procedural / scriptlet-like cosmetics
    bad = (":has(", ":xpath(", "+js(", ":style(", "abort-", "trusted-")
    low = sel.lower()
    if any(b in low for b in bad):
        return None
    if any(c in sel for c in ("{", "}", '"', "\\")):
        return None
    # Avoid nuking video players / YouTube chrome
    if any(
        x in low
        for x in (
            "ytd-",
            "ytp-",
            "html5-video",
            "video-player",
            "videoplayer",
            "rich-grid",
            "rich-item",
            "thumbnail",
        )
    ):
        # Allow only explicit ad renderers
        if "ad" not in low and "sponsor" not in low and "promo" not in low:
            return None
    return sel


def convert_cosmetic_line(line: str) -> list[tuple[tuple[str, ...], str]]:
    """Return list of (domains_tuple, selector). Empty domains = generic."""
    line = line.strip()
    if not line or line.startswith("!") or line.startswith("["):
        return []
    if "#@#" in line:
        return []  # exceptions not expressible cleanly in WK
    m = COSMETIC.match(line)
    if not m:
        return []
    domains_raw, selector = m.group(1), m.group(2)
    sel = sanitize_selector(selector)
    if not sel:
        return []
    if not domains_raw:
        return [(tuple(), sel)]
    domains: list[str] = []
    for d in domains_raw.split(","):
        d = d.strip().lower()
        if not d or d.startswith("~"):
            continue
        if not re.match(r"^[a-z0-9.-]+$", d):
            continue
        domains.append(d)
    if not domains:
        return []
    return [(tuple(domains[:20]), sel)]


def batch_cosmetics(items: list[tuple[tuple[str, ...], str]], batch_size: int = 25) -> list[dict]:
    """Group selectors that share the same domain set."""
    from collections import defaultdict

    groups: dict[tuple[str, ...], list[str]] = defaultdict(list)
    seen: set[str] = set()
    for domains, sel in items:
        key = f"{domains}::{sel}"
        if key in seen:
            continue
        seen.add(key)
        groups[domains].append(sel)

    rules: list[dict] = []
    for domains, sels in groups.items():
        for i in range(0, len(sels), batch_size):
            chunk = sels[i : i + batch_size]
            trigger: dict = {"url-filter": ".*"}
            if domains:
                trigger["if-domain"] = [f"*{d}" if not d.startswith("*") else d for d in domains]
            rules.append(
                {
                    "trigger": trigger,
                    "action": {"type": "css-display-none", "selector": ", ".join(chunk)},
                }
            )
    return rules


YOUTUBE_RULES = [
    {"trigger": {"url-filter": ".*youtube\\.com\\/pagead\\/"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/ptracking"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/api\\/stats\\/ads"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/get_midroll_"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/youtubei\\/v1\\/player\\/ad_break"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*youtube\\.com\\/pcs\\/activeview"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*ad\\.youtube\\.com"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*googlevideo\\.com\\/.*[&?]oad="}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*googlevideo\\.com\\/.*ctier=L"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*doubleclick\\.net"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*googleads\\.g\\.doubleclick\\.net"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*pagead2\\.googlesyndication\\.com"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*googlesyndication\\.com"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*googleadservices\\.com"}, "action": {"type": "block"}},
    {"trigger": {"url-filter": ".*adservice\\.google\\."}, "action": {"type": "block"}},
    {
        "trigger": {"url-filter": ".*youtube\\.com"},
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
    {
        "trigger": {"url-filter": ".*youtube-nocookie\\.com"},
        "action": {
            "type": "css-display-none",
            "selector": (
                ".ytp-ad-module, .ytp-ad-player-overlay, .video-ads, "
                ".ytp-ad-overlay-container, .ytp-ad-action-interstitial"
            ),
        },
    },
]

BASE_AD_NETWORKS = [
    "doubleclick.net",
    "googlesyndication.com",
    "googleadservices.com",
    "adservice.google.com",
    "pagead2.googlesyndication.com",
    "amazon-adsystem.com",
    "adnxs.com",
    "adsrvr.org",
    "adform.net",
    "advertising.com",
    "adsafeprotected.com",
    "ads-twitter.com",
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
    "hotjar.com",
    "fullstory.com",
    "clarity.ms",
    "moatads.com",
    "3lift.com",
    "teads.tv",
    "smartadserver.com",
    "media.net",
    "mgid.com",
    "revcontent.com",
    "carbonads.com",
    "carbonads.net",
    "buysellads.com",
    "propellerads.com",
    "popads.net",
    "exoclick.com",
    "juicyads.com",
    "googletagservices.com",
]


def base_ad_rules() -> list[dict]:
    rules: list[dict] = []
    seen: set[str] = set()
    for host in BASE_AD_NETWORKS:
        filt = ".*" + re.escape(host)
        if filt in seen:
            continue
        seen.add(filt)
        rules.append({"trigger": {"url-filter": filt}, "action": {"type": "block"}})
    return rules


def convert_network_file(path: Path) -> list[dict]:
    rules: list[dict] = []
    seen: set[str] = set()
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        for rule in convert_network_line(line):
            key = json.dumps(rule, sort_keys=True)
            if key in seen:
                continue
            seen.add(key)
            rules.append(rule)
    return rules


def convert_cosmetics(paths: list[Path], max_rules: int = 40_000) -> list[dict]:
    items: list[tuple[tuple[str, ...], str]] = []
    for path in paths:
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            items.extend(convert_cosmetic_line(line))
    items.sort(key=lambda x: (0 if not x[0] else 1, x[0], x[1]))
    rules = batch_cosmetics(items)
    return rules[:max_rules]


def write_chunked(prefix: str, rules: list[dict]) -> list[Path]:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for old in OUT_DIR.glob(f"{prefix}*.json"):
        old.unlink()

    paths: list[Path] = []
    if not rules:
        return paths

    room = MAX_RULES_PER_FILE - 1
    total_chunks = (len(rules) + room - 1) // room
    for i in range(0, len(rules), room):
        chunk = list(rules[i : i + room])
        chunk.append(allowlist_rule())
        idx = i // room
        name = prefix if total_chunks == 1 else f"{prefix}-{idx + 1}"
        out = OUT_DIR / f"{name}.json"
        out.write_text(json.dumps(chunk, separators=(",", ":")), encoding="utf-8")
        paths.append(out)
        print(f"Wrote {out.name}: {len(chunk)} rules ({out.stat().st_size // 1024} KB)")
    return paths


def main() -> None:
    easylist = Path("/tmp/easylist.txt")
    easyprivacy = Path("/tmp/easyprivacy.txt")
    if not easylist.exists() or not easyprivacy.exists():
        raise SystemExit("Download EasyList + EasyPrivacy to /tmp first (see README).")

    for pattern in (
        "oriel-easylist*.json",
        "oriel-easyprivacy*.json",
        "oriel-cosmetic*.json",
        "oriel-youtube-ads*.json",
        "oriel-base*.json",
    ):
        for old in OUT_DIR.glob(pattern):
            old.unlink()

    base = base_ad_rules()
    print(f"Base ad networks: {len(base)}")
    write_chunked("oriel-base", base)

    el = convert_network_file(easylist)
    ep = convert_network_file(easyprivacy)
    print(f"EasyList network: {len(el)}")
    print(f"EasyPrivacy network: {len(ep)}")
    write_chunked("oriel-easylist", el)
    write_chunked("oriel-easyprivacy", ep)

    cosmetics = convert_cosmetics([easylist, easyprivacy], max_rules=40_000)
    print(f"Cosmetic rules (batched): {len(cosmetics)}")
    write_chunked("oriel-cosmetic", cosmetics)

    yt_out = OUT_DIR / "oriel-youtube-ads.json"
    yt_rules = list(YOUTUBE_RULES) + [allowlist_rule()]
    yt_out.write_text(json.dumps(yt_rules, separators=(",", ":")), encoding="utf-8")
    print(f"Wrote {yt_out.name}: {len(yt_rules)} rules ({yt_out.stat().st_size // 1024} KB)")
    print("Done.")


if __name__ == "__main__":
    main()
