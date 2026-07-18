# Content blocker lists

Bundled under `Resources/ContentBlocker/`:

| File | Source |
|------|--------|
| `oriel-base.json` | High-signal ad/tracker networks |
| `oriel-easylist-*.json` | [EasyList](https://easylist.to/) network rules |
| `oriel-easyprivacy-*.json` | [EasyPrivacy](https://easylist.to/) network rules |
| `oriel-cosmetic.json` | Element-hiding (`##`) → `css-display-none` |
| `oriel-youtube-ads.json` | Curated YouTube ad endpoints + CSS hide |
| `example-blocklist.json` | Tiny fallback |

Protected first-party hosts (YouTube, `googleapis`, `gstatic`, …) are never blocked as a bare domain — that previously blanked the YouTube homepage.

Each compiled list ends with an OAuth/login allowlist (`ignore-previous-rules` only applies inside that list).

## Regenerate

```bash
curl -fsSL -o /tmp/easylist.txt https://easylist.to/easylist/easylist.txt
curl -fsSL -o /tmp/easyprivacy.txt https://easylist.to/easylist/easyprivacy.txt
python3 Scripts/convert_easylist_to_webkit.py
```

Attribution: see repo `NOTICE` and https://easylist.to/pages/licence.html

`WKContentRuleList` is not Brave’s engine. Some first-party YouTube streams can still play; Oriel also injects a skip/hide script when Shields are on.
