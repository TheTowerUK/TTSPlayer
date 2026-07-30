# Books Metadata Provider Evaluation (M7 Phase 7.2A)

**Status:** Complete — provider selected for controlled vertical slice
**Evaluation date:** 2026-07-30
**Milestone:** M7 — Metadata Enrichment and Library Experience
**Branch:** `m7-development`
**Decision:** **Open Library — Selected**

→ [M7 plan](../roadmap/m7-plan.md) · [Metadata enrichment](./metadata-enrichment.md) · [Phase 7.2 plan](../roadmap/m7-phase-7.2-plan.md) · [ADR-028](./decisions/ADR-028-external-metadata-enrichment-boundary.md)

---

## Purpose

Evaluate current books metadata providers using **official documentation and terms only**, and select one provider for the Phase 7.2 controlled books vertical slice. This document records facts, inferences, pass/fail gates, and scoring — not implementation.

**Research method:** Primary sources are provider official docs/terms dated below. Secondary blog/community sources were used only to identify follow-up questions, not as licensing authority.

---

## Official sources reviewed

| Provider | Primary sources | Date reviewed |
|---|---|---|
| **Open Library** | [APIs](https://openlibrary.org/developers/api) (edited 2026-05-05), [Search API](https://openlibrary.org/dev/docs/api/search), [Books API](https://openlibrary.org/dev/docs/api/books), [Covers API](https://openlibrary.org/dev/docs/api/covers) (2024-08-13), [Licensing](https://openlibrary.org/developers/licensing), [Using data FAQ](https://openlibrary.org/help/faq/using), [Bulk data](https://openlibrary.org/data) | 2026-07-30 |
| **Google Books API** | [Using the API](https://developers.google.com/books/docs/v1/using), [Books API Terms](https://developers.google.com/books/terms), [Branding](https://developers.google.com/books/branding), [Overview](https://developers.google.com/books/docs/overview), [Google APIs Terms of Service §5](https://developers.google.com/terms) (2021-11-09) | 2026-07-30 |
| **ISBNdb** | [API v2 documentation](https://isbndb.com/isbndb-api-documentation-v2), [Pricing](https://isbndb.com/isbn-database), [Terms and Conditions](https://isbndb.com/terms-and-conditions), [FAQ](https://isbndb.com/faq) | 2026-07-30 |
| **Library of Congress** | [JSON/YAML API](https://www.loc.gov/apis/json-and-yaml/), [Endpoints](https://www.loc.gov/apis/json-and-yaml/requests/endpoints/), [Search help (ISBN)](https://www.loc.gov/help/search) | 2026-07-30 |

**Not evaluated in depth:** WorldCat/OCLC APIs (institutional access model — rejected early). Crossref (scholarly DOI metadata — out of scope for consumer books).

---

## M7 pass/fail gates (legal / architectural)

| Gate | Open Library | Google Books | ISBNdb | LoC JSON API |
|---|---|---|---|---|
| Normalized metadata may be persisted locally | **Pass** — usage guidelines encourage caching; licensing page permissive for database content | **Fail** — Google APIs ToS §5 prohibits permanent copies / cache beyond HTTP cache headers | **Pass** — subscribers may store/cache while subscription active | **Pass** — US government/public metadata; verify per-item rights for digitized content |
| Provider optional without mandatory credentials | **Pass** — no API key | **Fail** — API key required for all public requests | **Fail** — `Authorization` header required | **Pass** — no API key |
| Full local paths need not be transmitted | **Pass** | **Pass** | **Pass** | **Pass** |
| Local browsing not network-dependent | **Pass** — enrichment overlay only | **Pass** | **Pass** | **Pass** |
| Cover usage terms understood | **Conditional** — hotlink + rate limits; bulk covers on archive.org; defer download to Phase 7.4 | **Conditional** — thumbnail URLs; strict storage/branding rules | **Conditional** — cover URL in API; URL format changes; cache while subscribed | **Partial** — thumbnails for digitized items only |
| No mandatory provider lock-in | **Pass** | **Pass** | **Pass** | **Pass** |

**Disqualifying issues:** Google Books fails persistence gate. ISBNdb fails optional-credentials gate for the default first slice.

---

## Provider summaries

### Open Library (Internet Archive)

**Ownership / longevity:** Internet Archive Open Library — long-running open book project; APIs actively documented (2025–2026 edits).

**Authentication:** No API key. Identified `User-Agent` with app name + contact email recommended for higher limits.

**Rate limits (confirmed):**
- General APIs: 1 req/s default; 3 req/s with identified `User-Agent` ([API usage guidelines](https://openlibrary.org/developers/api))
- Covers API (ISBN/OCLC/LCCN keys): 100 requests/IP per 5 minutes → 403 ([Covers API](https://openlibrary.org/dev/docs/api/covers))

**Usage intent (confirmed):** Low-volume, human-centered discovery; **not** bulk backend or high-traffic commercial infrastructure. Guidelines say: cache responses, identify app, do not harvest in bulk via API.

**Licensing (confirmed / inferred):**
- [Licensing page](https://openlibrary.org/developers/licensing): Internet Archive does not assert new copyright over Open Library database material; notes jurisdiction/legacy rights may exist.
- [Using data FAQ](https://openlibrary.org/help/faq/using): contributions requested under **CC0 1.0**; bulk download available.
- **Inference:** Factual bibliographic metadata persistence for personal enrichment aligns with stated mission; bulk API scraping is discouraged — use monthly dumps for bulk.

**APIs relevant to TTSPlayer:**
| API | Use |
|---|---|
| [Books API](https://openlibrary.org/dev/docs/api/books) | ISBN/OCLC/LCCN/OLID batch lookup (`/api/books?bibkeys=ISBN:…&format=json&jscmd=details`) |
| [Search API](https://openlibrary.org/dev/docs/api/search) | Title/author/ISBN search (`/search.json?q=…`) |
| Work/Edition JSON | `/works/OL….json`, `/books/OL….json` |
| [Covers API](https://openlibrary.org/dev/docs/api/covers) | Cover URLs by ISBN/OLID (Phase 7.4) |

**Work vs edition:** Search returns works by default; `editions` field can embed best-matching edition. Edition-level ISBN data available via Books API and edition records. **Ambiguity remains** for popular works with many editions — matching must prefer ISBN when present (Phase 7.3).

**Cover policy:** Public pages should hotlink `covers.openlibrary.org`; courtesy link to Open Library appreciated; bulk cover download via archive.org tar files — not via Covers API crawling.

**Privacy transmission:** ISBN, title, author search terms; client IP; optional contact in User-Agent. No local file paths required.

---

### Google Books API

**Authentication:** **API key mandatory** for public volume requests ([Using the API](https://developers.google.com/books/docs/v1/using)).

**Quotas:** Project-specific via Google Cloud Console — no universal published daily limit in Books docs (**unclear** without console access).

**Coverage:** Strong volume metadata — title, subtitle, authors, publisher, publishedDate, description, industryIdentifiers (ISBN), categories, language, pageCount, imageLinks.

**Licensing — disqualifying for TTSPlayer persistence model:**
- [Google APIs ToS §5](https://developers.google.com/terms): unless permitted by content owner or law, must not *"Scrape, build databases, or otherwise create permanent copies of such content, or keep cached copies longer than permitted by the cache header"*
- [Books Terms](https://developers.google.com/books/terms): no charging users without Google permission; content removal obligations
- [Branding](https://developers.google.com/books/branding): prominent Google attribution; restrictions on result modification

**Assessment:** Suitable for ephemeral search UIs, **not** for ADR-028/029 normalized enrichment persistence in `ttsplayer_metadata_enrichment_v1`. Would conflict with offline personal library enrichment.

---

### ISBNdb

**Authentication:** **Required** — `Authorization: YOUR_REST_KEY` header on every request ([API v2 docs](https://isbndb.com/isbndb-api-documentation-v2)). Query-string keys rejected.

**Cost (confirmed on pricing page, 2026-07-30):** Paid plans from **$14.99/month** (Basic: 5,000 daily searches, 1 req/s) through Enterprise tiers; 7-day trial advertised.

**Rate limits (confirmed):** Per-plan daily + per-second limits; `429` for quota; `ratelimit` / `ratelimit-policy` headers; daily reset 00:00 UTC.

**Fields (confirmed):** Up to ~19 data points including ISBN10/13, title, author, publisher, date, pages, synopsis, subjects, language, dimensions, cover image URL.

**Licensing (confirmed — [Terms](https://isbndb.com/terms-and-conditions)):**
- API subscribers may use data commercially and **store/cache locally while subscription is active**
- **Must delete cached data if subscription expires or is cancelled**
- Raw redistribution/republishing prohibited without permission

**Assessment:** Strong commercial metadata product, but **mandatory paid credential** makes it unsuitable as the **default** provider for an optional personal-media feature. Valid as a **future secondary/fallback** when user opts in and supplies credentials (Phase 7.7+).

---

### Library of Congress JSON/YAML API (additional comparison)

**Included because:** Public, no-auth JSON API; US-government metadata; complements open-ecosystem direction.

**Authentication:** None ([loc.gov APIs](https://www.loc.gov/apis/json-and-yaml/) — **inference** from official overview: public access, rate limiting applied).

**Coverage limitation (confirmed):** `/books/` format endpoint *"Does not provide all catalog information for books at the Library of Congress; best used for digitized books available from the Library website."* Full catalog via separate MARC/SRU systems.

**ISBN search (confirmed):** General `/search/?q={ISBN}&fo=json` supports ISBN without hyphens ([search help](https://www.loc.gov/help/search)).

**Assessment:** Useful for digitized/public-domain subset and institutional metadata, **insufficient** as primary provider for general consumer EPUB/PDF libraries. **Rejected as primary**; no Phase 7.2 implementation.

---

### WorldCat / OCLC (rejected early)

OCLC developer APIs typically require institutional/developer program registration and license agreements. Not aligned with optional personal-app integration without institutional relationship. **Not evaluated further.**

---

## Comparison matrix (summary)

| Criterion | Open Library | Google Books | ISBNdb | LoC JSON |
|---|---|---|---|---|
| API key required | No | **Yes** | **Yes** | No |
| Cost | Free | Free tier + quotas | **Paid** ($14.99+/mo) | Free |
| ISBN lookup | Yes (Books API, search) | Yes (`q=isbn:`) | Yes (primary) | Partial (search) |
| Title/author search | Yes | Yes | Yes | Yes (limited) |
| Edition vs work | Yes (complex) | Volume-oriented | Edition-oriented | Item-oriented |
| Description | Often present | Often present | Synopsis field | Variable |
| Series metadata | Inconsistent | Limited | Variable | Limited |
| Cover images | Covers API (rate limited) | `imageLinks` (restricted storage) | Cover URL in API | Digitized only |
| Local metadata persistence | **Encouraged (cache)** | **Prohibited (permanent)** | **Allowed while subscribed** | Public domain (subset) |
| Attribution | Courtesy link | **Required (Powered by Google)** | Per terms | LoC citation |
| Rate limits | 1–3 req/s; covers 100/5min | Cloud project quotas | Plan-based | Rate limited (unspecified) |
| Offline enrichment fit | **Strong** | **Poor** | Good (if subscribed) | Moderate (subset) |

---

## Weighted scoring (1–5)

| Area | Weight | Open Library | Google Books | ISBNdb | LoC JSON |
|---|---:|---:|---:|---:|---:|
| Licensing & persistence rights | 25% | 5 | **1** | 4 | 4 |
| Coverage & metadata quality | 20% | 4 | 4 | 5 | 2 |
| Matching & identifiers | 15% | 4 | 4 | 5 | 2 |
| Cost & access friction | 15% | 5 | 3 | 2 | 5 |
| Reliability & longevity | 10% | 4 | 5 | 4 | 4 |
| Privacy | 5% | 4 | 3 | 3 | 4 |
| Technical integration | 10% | 4 | 5 | 5 | 3 |
| **Weighted total** | 100% | **4.40** | 3.05 | 3.95 | 3.15 |

Scores are planning estimates from official docs — not live API quality benchmarks.

**Note:** Google Books' licensing score overrides its otherwise strong technical/coverage scores. ISBNdb's cost/access score reflects mandatory subscription for API access.

---

## Recommendation

### Preferred provider — **Open Library** (Selected)

**Why for Phase 7.2 books vertical slice:**

1. **Passes M7 persistence gates** — caching encouraged; compatible with client-side enrichment store (ADR-028)
2. **No API key** — aligns with optional enrichment default-off; Phase 7.2 requires no credential persistence
3. **ISBN + search paths** — Books API and Search API cover controlled slice inputs
4. **Mission alignment** — personal, human-centered lookup; low volume per user
5. **Deterministic testing** — fake HTTP fixtures without live keys

**Conditionally selected caveats:**
- Respect 1–3 req/s limits and User-Agent identification
- Do not use API as bulk backend; batch user-initiated lookups only
- Work/edition ambiguity handled in Phase 7.3 matching — not provider selection
- Cover **deferred to Phase 7.4** (Covers API rate limits; hotlink vs local cache policy)

### Fallback / future secondary — **ISBNdb** (Conditionally selected — credentials required)

For users who later opt in with a paid API key (Phase 7.7+): strong ISBN coverage, explicit cache-while-subscribed terms, commercial use permitted. Requires credential storage evaluation and subscription lifecycle (delete enrichment on cancel).

### Rejected providers

| Provider | Status | Reason |
|---|---|---|
| **Google Books API** | **Rejected** | Google APIs ToS prohibits permanent/local database copies beyond cache headers — conflicts with enrichment persistence |
| **Library of Congress JSON API** | **Rejected (primary)** | Incomplete consumer book catalogue; digitized-item focus |
| **WorldCat/OCLC** | **Rejected** | Institutional/commercial API access model |

---

## Phase 7.2 controlled vertical slice (proposed)

### Inputs (lookup keys)

| Input | Source | Priority |
|---|---|---|
| ISBN-13 / ISBN-10 | EPUB OPF, future embedded tags | Highest |
| Title + author | Catalogue `MediaItem` | Search fallback |
| Publication year | Catalogue `year` | Disambiguation only |

**Excluded Phase 7.2 inputs:** full file path, filename beyond basename policy, folder names.

### Normalized outputs (persisted in enrichment store)

| Field | Phase 7.2 |
|---|---|
| Canonical title | Yes |
| Subtitle | Yes (if present) |
| Authors | Yes |
| Description | Yes |
| Publisher | Yes |
| Publication date/year | Yes |
| Language | Yes (if present) |
| Subjects/genres | Yes (if present) |
| ISBN-10 / ISBN-13 | Yes |
| Provider record ID (OLID / edition key) | Yes |
| Provider provenance | Yes |
| Fetched timestamp | Yes |
| Series / volume | **Deferred** ( unreliable ) |
| Cover artwork | **Deferred → Phase 7.4** |
| Raw provider JSON | **No** |
| Ratings, reviews, purchase links | **No** |

### Lookup modes (Phase 7.2)

1. **ISBN identifier lookup** — Open Library Books API (`bibkeys=ISBN:…`, `jscmd=details`)
2. **Explicit search** — Open Library Search API (`/search.json?q=…`) — results returned to matching layer in Phase 7.3; **no auto-apply** in 7.2 adapter-only milestone

Phase 7.2 implements adapter + fake HTTP; live integration gated behind explicit refresh (Phase 7.2/7.3 boundary per plan).

---

## Cover art decision

**Defer cover download and Covers API integration to Phase 7.4.**

Rationale:
- Covers API rate limit (100/IP/5 min for ISBN) conflicts with library-wide artwork enrichment
- Usage guidelines prefer hotlinking for public display; local artwork cache needs explicit policy review
- Bulk cover tar archives on archive.org are not suitable for real-time per-item enrichment
- Phase 7.2 focuses on text metadata persistence proof

Phase 7.4 will evaluate: hotlink vs download, LRU disk cache, Open Library courtesy attribution, and rate-limit backoff.

---

## Authentication and quota model (Open Library)

| Item | Policy |
|---|---|
| API key | **Not required** |
| User-Agent | `TTSPlayer/0.8 (contact@…)` recommended — 3 req/s |
| OAuth | None |
| Quota | Soft limits; 403/429 possible on abuse |
| Phase 7.2 credentials | **None persisted** |
| Optional dev validation | Environment variable for contact email in User-Agent only — not a secret |

---

## Caching and persistence rights (Open Library)

| Data | Policy |
|---|---|
| Normalized enrichment fields | Persist in `ttsplayer_metadata_enrichment_v1` — aligned with cache-friendly API usage |
| Raw JSON responses | **Do not persist** (M7 policy + schema design) |
| Cover bytes | Phase 7.4 |
| Attribution | Courtesy link to Open Library on enriched surfaces (exact UI placement Phase 7.5) |
| Retention | Until user clears enrichment or record pruned on catalogue replace |
| Bulk dump alternative | Monthly dumps for future backend assist (ADR-028 deferral) — not Phase 7.2 |

---

## Privacy disclosure (Open Library)

When user initiates enrichment lookup, the app may transmit:

- ISBN (if known locally)
- Normalized title and author strings
- Optional publication year
- Client public IP (inherent to HTTP)
- Application name/contact in User-Agent

**Not transmitted:** full local file paths, credentials, catalogue tree, unrelated items.

ISBN/title searches are not highly sensitive but may reveal reading interests — disclose at opt-in (Phase 7.7 settings UI).

---

## Provider-neutral abstraction (minimum contract — design only)

Not implemented in Phase 7.2A. Minimum interface for Phase 7.2B:

```dart
// Illustrative design — not production code
abstract class BookMetadataProvider {
  String get providerId; // e.g. "open_library"
  Set<MediaKind> get supportedKinds; // { MediaKind.book }

  Future<BookMetadataSearchResult> search(BookMetadataQuery query, {CancelToken? cancel});
  Future<NormalizedBookMetadata?> lookupByIsbn(String isbn, {CancelToken? cancel});
}
```

**Provider-neutral types:**
- `BookMetadataQuery` — isbn, title, author, year (optional)
- `NormalizedBookMetadata` — fields listed in vertical slice
- `BookMetadataSearchResult` — list of `ProviderBookCandidate` + ambiguous flag
- `ProviderRequestOutcome` — success | empty | error category
- `ProviderAttribution` — text/URL requirements

**Adapter-internal (Open Library specific):** OLID keys, work/edition JSON shapes, `/api/books` vs `/search.json` endpoint selection, field name mapping.

---

## Error mapping (Open Library → enrichment taxonomy)

| HTTP / condition | `EnrichmentLastErrorCategory` | Notes |
|---|---|---|
| 200 + empty result | *(not an error)* — unmatched state | Normal |
| 200 + multiple close matches | *(not an error)* — ambiguous | Phase 7.3 |
| 400 / malformed request | `parseFailure` | Adapter bug |
| 401 / 403 | `providerUnavailable` | Often rate/abuse block for OL |
| 404 | *(not an error)* — unmatched | No edition found |
| 429 / 503 | `rateLimited` / `providerUnavailable` | Backoff |
| Timeout | `networkFailure` | Retry eligible |
| DNS/TLS failure | `networkFailure` | Offline |
| Invalid JSON | `parseFailure` | Skip record |
| Cancelled | `cancelled` | User/system cancel |

Authentication failures (`authenticationFailure`) reserved for keyed providers (ISBNdb future).

---

## Adapter test strategy (Phase 7.2 implementation)

Deterministic fake HTTP only in CI:

| Fixture | Expected |
|---|---|
| ISBN exact match → single edition | Normalized record |
| Title+author search → one result | Candidate list |
| Multiple search results | Ambiguous (no auto-apply) |
| Empty `{ "numFound": 0 }` | Unmatched |
| Malformed JSON | Parse failure category |
| Missing optional fields | Partial normalized record |
| HTTP 403 (rate limit) | `rateLimited` |
| HTTP 500 | `providerUnavailable` |
| Timeout | `networkFailure` |
| Cancel mid-request | `cancelled` |
| Unexpected content-type | `parseFailure` |

**Live Open Library tests:** optional, env-gated (`TTSPLAYER_LIVE_OPEN_LIBRARY=1`), excluded from CI, no committed credentials.

---

## ADR impact

**ADR-028 and ADR-029 remain Proposed.** Open Library selection **confirms** client-primary enrichment and normalized persistence without raw payloads. No ADR amendment required.

---

## Unresolved questions

1. **Open Library cover local cache** — hotlink-only vs downloaded bytes for offline artwork (Phase 7.4 legal review)
2. **Work vs edition default** — when ISBN maps to work with many editions, confirm Books API `jscmd=details` behaviour with live fixture sample (implementation-time)
3. **User-Agent contact address** — use settings/support email vs static project address (Phase 7.7)
4. **ISBNdb secondary provider** — user-supplied key UX and enrichment purge on subscription lapse (Phase 7.7+)
5. **Exact rate-limit response codes** from Open Library general API under sustained load — treat 403 as rate/abuse pending live optional test

---

## Related documents

- [Phase 7.2 plan](../roadmap/m7-phase-7.2-plan.md)
- [M7 plan](../roadmap/m7-plan.md)
- [Metadata enrichment architecture](./metadata-enrichment.md)
