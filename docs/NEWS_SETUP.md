# News digest setup for Cadence

Cadence **News** builds a daily slate of ~10 stories across world, science, tech, business, culture, and health — then optionally rewrites them into short AI digests you can open in Safari.

## What ships today (client prototype)

| Piece | Behavior |
|-------|----------|
| Sources | Public **RSS** feeds (BBC World, NPR, NASA, ScienceDaily, The Verge, CNBC, Smithsonian) |
| Selection | Diversify by topic, prefer recent, cap at 10 |
| Images | RSS `media:` / enclosure / `<img>` when present; Cadence charcoal gradient fallback |
| AI briefs | Optional via existing Settings → AI key (`NewsAIService`) |
| UI | Wheel **News** page, topic chips, hero + cards, OPEN ARTICLE |

No NewsAPI key is required for the first version.

## Optional AI digests

1. Settings → **AI** → add Anthropic or OpenAI key (Keychain).
2. Settings → **News digest** → keep **AI digests after refresh** on.
3. Tap refresh (FAB or header) on the News page.

Without a key, feed snippets still show; demo slate works offline.

## Stronger backend (later)

When you outgrow on-device RSS:

```
iOS Cadence  →  Cadence News API  →  licensed wire / NewsAPI / GDELT / scrapers
                      ↓
                 LLM summarize + image CDN
                      ↓
                 cached JSON for the day
```

Recommended server responsibilities:

- Rank “most important” with editorial or model scoring (not just feed order)
- Dedupe + cluster multi-source topics
- Normalize images (size, license, placeholder)
- Cache one briefing per user timezone day
- Respect publisher ToS / robots / paid licenses

Keep the iOS models (`NewsArticleEntity`, briefing fields) stable so the client only swaps `NewsClient` for `fetchViaBackend`.

## Architecture map

| Piece | Path |
|-------|------|
| Registry | `SubApps/CadenceSubApp.swift` (`news`) |
| Models | `Models/NewsModels.swift` |
| RSS client | `Services/NewsClient.swift` |
| AI | `Services/NewsAIService.swift` |
| Persistence | `Services/NewsStore.swift` |
| UI | `Views/News/*` |
| Prefs | `Services/NewsPreferences.swift` |

## App Review / product notes

- Digests are **summaries**, not republished full text.
- Always offer **OPEN ARTICLE** to the publisher URL.
- Demo URLs use `example.com` placeholders — live refresh uses real feed links.
- Don’t claim exclusivity or medical/investment advice in AI copy (prompt already constrains this).

## Feeds

Edit `NewsClient.defaultFeeds` to change the mix. Prefer HTTPS RSS/Atom.
