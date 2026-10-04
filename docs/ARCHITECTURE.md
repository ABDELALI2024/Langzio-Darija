# Langzio Architecture

**Status:** Foundation architecture **approved** (2026-10-04) with required corrections in this revision. Phase 1 code starts only after this correction review.  
**Version:** 1.1  
**Date:** 2026-10-04  
**Hosting target:** Hostinger Business Web Hosting (PHP + MySQL, no VPS required)

---

## 1. Product definition

Langzio is a production SaaS for **Moroccan Darija with context, not just translation**.

Long-term positioning:

> **AI-powered cultural intelligence for Moroccan Darija.**

Langzio is not a generic translator landing page. The product combines:

- Verified Darija knowledge (terms, phrases, pronunciation, tone, usage)
- Cultural and situational explanation
- Learning and travel resources
- Diaspora-oriented features
- Authenticated tools (translator, chat, kids, saved content)
- Modular AI/RAG that **grounds answers in verified knowledge** and never presents unverified generation as authoritative

Audiences (priority order for v1 public SEO):

1. Diaspora learners (EN/FR primary)
2. Travelers who need situational Darija
3. Native speakers / heritage speakers who want structured explanations
4. Researchers and content partners (later)

---

## 2. Non-negotiable constraints

| Constraint | Implication |
|---|---|
| Hostinger Business Web Hosting | PHP 8.x, MySQL 8.x, Apache/LiteSpeed, `.htaccess`, cron, HTTPS. No mandatory Node, Docker, K8s, Redis, PostgreSQL, Python daemons. |
| SEO-first public layer | Server-rendered HTML. Public pages crawlable without login. Minimal JS. |
| Verified vs generated | Every AI-facing and public knowledge surface must distinguish verified knowledge from AI suggestion. |
| Modular monolith | One deployable PHP application with clear module boundaries. Replaceable internals later. |
| Secrets never in web root | Config, storage, logs, vendor, `.env` must not be publicly fetchable. |
| Quality > volume | No auto-generated SEO spam. |

---

## 3. Architectural principle: two layers, one application

```text
LANGZIO.COM
│
├── Public SEO Layer          (anonymous, crawlable, SSR HTML)
│   ├── Marketing & entity pages
│   ├── Knowledge base (dictionary, phrases, guides, culture, travel, learn, blog)
│   └── Thin public translator teaser (rate-limited, no full app JS)
│
└── Application Layer         (authenticated, /app/*)
    ├── Translator
    ├── Chat / AI assistant
    ├── Saved guides / kids / profile / settings
    └── Billing-aware features
```

Same codebase. Same database. Different:

- routers / middleware
- templates
- asset bundles
- cache policy
- robots policy (`/app` is noindex)
- auth requirements

**Rule:** Never load authenticated-app JavaScript on public SEO pages.

---

## 4. System diagram

```text
User / Crawler / LLM Bot
        │
        ▼
Cloudflare (optional but recommended)
  DNS, TLS edge, CDN cache, WAF, bot management, rate limits
        │
        ▼
Hostinger Business Web Hosting
  LiteSpeed/Apache + PHP-FPM/CGI + HTTPS
        │
        ▼
Front controller  (public/index.php)
        │
        ▼
PHP Modular Monolith
  ┌─────────────┬──────────────┬─────────────┬──────────────┐
  │ SEO         │ Content      │ Auth        │ Translator   │
  │ Router      │ Knowledge    │ Sessions    │ Public+App   │
  │ Metadata    │ CMS          │ CSRF        │ Rate limits  │
  │ Sitemaps    │ Linking      │ Users       │ Glossary     │
  ├─────────────┼──────────────┼─────────────┼──────────────┤
  │ Admin       │ Observability│ Billing     │ AI / RAG     │
  │ CMS         │ Logs         │ (later)     │ Providers    │
  └─────────────┴──────────────┴─────────────┴──────────────┘
        │
        ▼
MySQL 8.x
  users, knowledge, content, SEO, AI logs, embeddings (optional JSON/BLOB)
        │
        ▼
External AI Provider (HTTPS outbound)
  LLM + embeddings (keys in env, never in repo)
```

---

## 5. Why this stack for v1

### 5.1 PHP instead of Next.js (v1)

Hostinger Business Web Hosting runs PHP natively. Next.js requires a Node runtime, long-lived process, and usually VPS/serverless. Using Next.js on this host would force a mismatch (static export only, broken app routes, or a second paid runtime).

PHP gives:

- First-class SSR for SEO
- One process-per-request model that matches shared hosting
- Cheap, well-understood MySQL pairing
- Easy later extraction of modules to APIs on a VPS

Next.js remains a **future option** for the authenticated SPA shell after a VPS migration. Public SEO pages should stay SSR regardless of frontend fashion.

### 5.2 MySQL instead of PostgreSQL / vector DB

The host provides MySQL. Normalized relational data is the source of truth for Darija knowledge. Vector search is an **index**, not the system of record.

v1 retrieval = SQL + fulltext + structured filters. Embeddings stored for later, queried only if cheap enough; otherwise skipped until VPS.

### 5.3 Modular monolith, not microservices

One repo, one deploy, namespaced modules. Independent replacement later (AI providers, search, cache, billing) without network hops on shared hosting.

---

## 6. Directory structure (Hostinger-safe)

The Git repository is **not** identical to `public_html`. The web document root must be `public/` only.

```text
langzio/
├── public/                          ← Hostinger document root (or public_html contents)
│   ├── index.php                    ← front controller
│   ├── .htaccess
│   ├── robots.txt                   ← may be generated; keep a static fallback
│   ├── llms.txt
│   ├── assets/                      ← hashed/built CSS/JS/images (public only)
│   └── images/
│
├── app/
│   ├── Bootstrap.php
│   ├── Http/
│   │   ├── Router.php
│   │   ├── Request.php
│   │   ├── Response.php
│   │   ├── Kernel.php
│   │   └── Middleware/
│   │       ├── AuthMiddleware.php
│   │       ├── CsrfMiddleware.php
│   │       ├── RateLimitMiddleware.php
│   │       ├── LocaleMiddleware.php
│   │       ├── RedirectMiddleware.php
│   │       └── SecurityHeadersMiddleware.php
│   ├── Controllers/
│   │   ├── Public/
│   │   ├── App/                     ← /app/*
│   │   ├── Api/                     ← /api/v1/* (same origin)
│   │   └── Admin/
│   ├── Domain/                      ← entities / value objects
│   ├── Models/
│   ├── Repositories/
│   ├── Services/
│   │   ├── Seo/
│   │   │   ├── SeoService.php
│   │   │   └── SeoAuditService.php          ← publish gate (Phase 3+; interface in Phase 1)
│   │   ├── Content/
│   │   │   ├── RevisionService.php          ← append-only versions (Phase 2+)
│   │   │   └── ProvenanceService.php
│   │   ├── Linking/
│   │   ├── Redirect/
│   │   │   └── RedirectService.php          ← DB redirects + 410; chain-safe
│   │   ├── Auth/
│   │   ├── Translator/
│   │   └── Billing/
│   ├── AI/
│   │   ├── Contracts/
│   │   ├── Providers/
│   │   ├── Prompts/
│   │   ├── Safety/
│   │   └── RAG/
│   ├── SEO/
│   ├── Support/                     ← helpers, clock, slug, i18n
│   │   └── LocaleResolver.php       ← single locale/URL policy
│   └── Views/                       ← or resources/views
│
├── config/
│   ├── app.php
│   ├── database.php
│   ├── seo.php
│   ├── ai.php
│   ├── locales.php
│   └── security.php
│
├── database/
│   ├── migrations/
│   ├── seeders/
│   └── schema.sql                   ← Hostinger-friendly import
│
├── resources/
│   ├── views/
│   │   ├── layouts/
│   │   │   ├── public.php           ← SEO layout, tiny JS
│   │   │   ├── app.php              ← authenticated layout
│   │   │   └── admin.php
│   │   ├── public/
│   │   ├── app/
│   │   ├── admin/
│   │   └── emails/
│   ├── css/
│   └── js/
│       ├── public.js                ← never loaded on every page if unneeded
│       └── app.js
│
├── storage/
│   ├── cache/
│   ├── logs/
│   ├── rate_limits/                 ← file-based limiter if no Redis
│   └── uploads/                     ← not web-served directly
│
├── docs/
├── tests/                           ← PHPUnit when Phase 1 lands
├── .env.example
├── .gitignore
└── README.md
```

**If Hostinger cannot change document root:** deploy so that `public_html/` contains only the contents of `public/`, and place `app/`, `config/`, `storage/` **one level above** `public_html`. `index.php` bootstraps via `require __DIR__ . '/../app/Bootstrap.php';`.

**Never** place `.env`, `app/`, `config/`, or `storage/` inside a publicly listable directory without deny rules.

---

## 7. Runtime request flow

```text
HTTPS request
  → .htaccess (HTTPS, www/non-www, trailing slash, front controller, cache headers)
       [host/scheme/slash only — one hop; no locale logic here]
  → public/index.php
  → Bootstrap (env, config, error handler, PDO)
  → HTTP Kernel
       1. Security headers
       2. RedirectService (active DB redirects + 410; refuse chains)
       3. LocaleResolver (prefix policy; /en alias only if that alias exists)
       4. Rate limit (IP + route class)
       5. CSRF (state-changing)
       6. Auth (app/admin only)
  → Router (method + path + locale)
  → Controller
  → Service / Repository
  → View (public) or JSON (api)
  → Response (status, cache-control, self-canonical already in HTML)
```

PHP files are never exposed as canonical URLs.

---

## 8. Module map

| Module | Responsibility | Replaceable later? |
|---|---|---|
| Http / Router | Clean URLs | Yes (framework later) |
| LocaleResolver | Default EN at `/`, `/fr`, `/ar`; `/en` only as explicit 301 alias | Keep policy stable |
| RedirectService | DB 301/302/410, no chains, admin validation | Yes |
| SEO | Metadata, schema by page type, sitemaps, hreflang | Yes |
| SeoAuditService | Publish gate: PASS / WARNING / ERROR | Yes |
| Content / Knowledge | Verified Darija + provenance + revisions | Core (keep schema) |
| Linking | Hub + related + breadcrumbs; no auto-link-every-word | Yes |
| Auth | Sessions, users, roles | Yes (add OAuth later) |
| Translator | Glossary-first translation + optional LLM polish | Provider-swappable |
| AI | LLM/embedding contracts | Yes |
| RAG | Retrieve → prompt → validate | Retrieval backend swappable |
| Admin | Editorial + SEO + verification | UI replaceable |
| Observability | Logs | Ship to external later |
| Billing | Subscriptions (Phase 8+) | Stripe/Paddle later |

---

## 9. Caching strategy (no Redis required)

1. **HTTP cache:** `Cache-Control` on public knowledge pages (`public, max-age=300, s-maxage=3600` as a starting point; purge on publish).
2. **Cloudflare:** cache HTML for anonymous GET of dictionary/phrases/guides; bypass `/app`, `/admin`, `/api`.
3. **PHP file cache:** rendered metadata, sitemap fragments, related-link sets under `storage/cache/` with TTL + publish invalidation.
4. **MySQL:** query cache is not relied on; use indexes + prepared statements.
5. **OPcache:** enable in Hostinger PHP settings.

Invalidation: on content publish/unpublish, bump a `content_version` or delete cache keys by entity type + id.

---

## 10. Authentication model (high level)

- Public: no login.
- `/app/*`: session cookie, `HttpOnly`, `Secure`, `SameSite=Lax` (or Strict for admin).
- `/admin/*`: session + role `admin` or `editor`; separate cookie name optional.
- `/api/v1/*`: same-origin; CSRF for cookie-auth; later PAT for partners.
- Passwords: `password_hash` / `password_verify` (PASSWORD_ARGON2ID if available, else BCRYPT).
- Session regeneration on login and privilege change.
- Optional “remember me” via rotating hashed tokens in `user_sessions`.

Details: `docs/SECURITY.md`.

---

## 11. AI / RAG (high level)

AI is a **module**, not scattered `curl` calls.

```text
User
 → AI Controller
 → Intent Detection
 → Context Builder
 → RAG Service (verified knowledge + cultural notes)
 → Prompt Builder (includes provenance instructions)
 → LLM Provider (interface)
 → Response Validator (Safety + hallucination checks)
 → User (UI labels: Verified / Common usage / Regional / Uncertain / AI suggestion)
```

v1 retrieval: SQL + FULLTEXT. Embeddings table exists for migration. No mandatory Pinecone/Qdrant.

Details: `docs/AI_RAG_ARCHITECTURE.md`.

---

## 12. SEO (high level)

Every public HTML response is a complete document: unique title, description, canonical, robots, OG/Twitter, hreflang, JSON-LD that matches visible content, breadcrumbs, semantic headings.

Discovery:

- `robots.txt`
- XML sitemaps (index + per type + per locale)
- `llms.txt` / `llms-full.txt`
- Internal linking engine
- Organization entity consistency

Details: `docs/SEO_ARCHITECTURE.md`, `docs/URL_STRUCTURE.md`, `docs/CONTENT_ARCHITECTURE.md`.

---

## 13. Security (high level)

Defense in depth: PDO, CSRF, XSS escaping, headers, rate limits, upload deny-by-default, env secrets, authorization on every mutating route, logging without secrets.

Details: `docs/SECURITY.md`.

---

## 14. Observability

| Channel | Destination | Contains |
|---|---|---|
| `app.log` | `storage/logs/` | Errors, slow requests (>500ms configurable) |
| `security.log` | `storage/logs/` | Auth failures, CSRF, rate limits, admin actions |
| `ai.log` | `storage/logs/` | Provider, model, token estimates, latency, **no full PII dumps** |
| `api.log` | `storage/logs/` | 4xx/5xx, upstream failures |

Rotate daily via cron. Never log passwords, cookies, Authorization headers, or API keys.

---

## 15. Cost control

v1 spends money only on:

- Hostinger plan
- Domain + optional Cloudflare (free tier possible)
- AI API usage (strict caps, caching of identical prompts, cheaper models for classification)

No Kubernetes, Docker, Redis, Elasticsearch, dedicated vector DB, or microservice mesh.

---

## 16. Future VPS migration (no rewrite)

| Today (Hostinger) | Later (VPS) | How we avoid rewrite |
|---|---|---|
| File cache | Redis | `CacheInterface` |
| File rate limits | Redis / edge | `RateLimiterInterface` |
| MySQL FULLTEXT | OpenSearch / vector DB | `RetrievalInterface` |
| PHP sessions | Redis sessions | session handler swap |
| Monolith PHP | Same app behind nginx + php-fpm | already front-controller |
| Server-rendered public | Keep SSR; app can become API+SPA | `/app` already isolated |
| Single MySQL | Read replica / managed MySQL | repository layer |
| Cron PHP | Supervisor workers | job interface + cron adapter |

**Migration rule:** depend on interfaces in `app/AI/Contracts` and `app/Support` from day one.

---

## 17. Architecture review (explicit answers)

### 1. Why PHP instead of Next.js for the first production version?

Because the production host is PHP/MySQL shared-class hosting. Next.js SSR needs a Node server. A static Next export would cripple the authenticated app and dynamic SEO. PHP SSR is the native, cheapest, most crawlable fit. The module split (`/public` vs `/app`) still allows a later Node/SPA for the logged-in product without throwing away knowledge, SEO, or schema.

### 2. Why MySQL?

It is the database Hostinger provides, mature for CMS/knowledge graphs, and sufficient for normalized Darija data plus FULLTEXT. PostgreSQL/pgvector would improve vectors later but would force hosting we do not have. Schema stays portable (standard SQL types).

### 3. How can RAG work without a dedicated vector database?

Treat RAG as **retrieve then generate**. v1 retrieval:

1. Intent + language detection (rules + small LLM call if needed)
2. Exact slug / term match
3. MySQL `FULLTEXT` on latin, arabic, glosses
4. Structured filters (region, tone, category, verification status)
5. Related-entity graph (link tables)

Pass top-k **verified** rows into the prompt with IDs. The LLM may paraphrase but must cite verification status. Embeddings can be stored as BLOBs and ignored until a VPS vector index exists.

### 4. How can we migrate to a VPS later?

Keep a front controller, env-based config, and interfaces for cache, queue, retrieval, LLM, and storage. On VPS: nginx, php-fpm, Redis, queue worker, optional vector DB. Same Git repo. Document root still `public/`.

### 5. How will public SEO pages differ from the authenticated app?

| | Public | App |
|---|---|---|
| URL | `/`, `/dictionary/...` | `/app/...` |
| Auth | None | Required |
| Render | PHP templates, almost no JS | App JS bundle |
| Indexing | index,follow (when published) | noindex,nofollow |
| Cache | CDN + HTML cache | private, no-store |
| Purpose | Acquisition + knowledge | Product usage |

### 6. How will multilingual SEO work?

Default locale English at `/` (`x-default`). French `/fr/`, Arabic `/ar/` with translated **explanatory** content, not machine-duplicated Darija entries. Darija script appears on all locales; the **UI and explanations** change. **`/en/...` is not a first-class public locale** and is **not** blanket-redirected; an `/en/...` URL is 301’d to the unprefixed English canonical **only when that alias is explicitly registered**. Each localized page uses a **self-referencing canonical**. hreflang lists **only real, translated, indexable** equivalents. Policy lives in `LocaleResolver`. See `docs/URL_STRUCTURE.md`.

### 7. How will Google discover dictionary pages?

Published terms emit:

- Unique crawlable HTML at `/dictionary/{slug}`
- Sitemap entries in `sitemap-dictionary-{locale}.xml`
- Internal links from hub pages, related terms, phrases, guides
- Breadcrumbs + DefinedTerm schema when the page is a real definition

Unpublished/draft never enter sitemaps and are `noindex`.

### 8. How will AI crawlers discover Langzio?

- `robots.txt` allowing major search and documented AI crawlers (policy-configurable)
- `llms.txt` and `llms-full.txt` pointing to canonical knowledge hubs
- Factual, structured pages (not interstitial walls)
- Organization + DefinedTerm + FAQ JSON-LD matching visible text
- Stable permalinks

### 9. How do we prevent duplicate content?

- Single canonical host (non-www or www, pick one)
- Trailing-slash policy (no trailing slash except `/`)
- Locale prefixes only for real translations
- No blanket `/en/*` rewrite; explicit `/en` aliases only
- DB redirect table (301/302/410) with chain validation
- One entity → one primary slug; aliases 301
- Parameter URLs not used for content
- `hreflang` + unique titles per locale
- `/app` noindex

### 10. How do we prevent AI hallucinations about Darija?

- Prompt always includes retrieved snippets with stable knowledge IDs + provenance
- Output schema with claim level (`verified` | `common_usage` | `regional` | `uncertain` | `ai_suggestion`)
- Validator allows `verified` only if retrieved context status supports it
- AI suggestions never auto-become `verified` or `published`
- UI badges
- Admin review queue for high-traffic generations (later)
- Never auto-publish AI text as dictionary entries

### 11. How do we protect the AI API?

Same-origin `/api/v1`, session or CSRF, per-user and per-IP rate limits, daily token budget, model allowlist, prompt size caps, no key on the client, provider keys in env, abuse logging, optional Cloudflare challenge on burst.

### 12. How do we prevent abuse of the translator?

Anonymous public translator: strict IP rate limit, captcha after N requests, short max input, no batch API. Authenticated: plan quotas. Cache identical source+direction. Log hashed IP + user id, not full payloads when possible. Disable if upstream cost spikes.

### 13. How will the database scale?

Normalize, index slugs/status/locale, partition **hot logs** (ai_usage, rate_limit events) by date later. Knowledge tables grow slowly (quality editorial). Cache public reads. When needed: read replica, then search service. Avoid unbounded JSON blobs as the only query path.

### 14. Which components can later be replaced independently?

LLM provider, embedding provider, retrieval backend, cache, rate limiter, session store, CDN, billing provider, admin UI, authenticated frontend. **Do not replace** without migration: URL contracts, knowledge schema, verification semantics, Organization entity.

---

## 18. Implementation roadmap

Phase 1 begins only after the v1.1 correction review. Do not implement Phase 2+ until Phase 1 exists.

### Phase 1 — Foundation (strict)

Implement **only**: front controller, routing foundation, configuration, environment handling, PDO connection, error handling, structured logging, security headers, session foundation, `.htaccess`, public/private directory separation, basic public layout, 404 page, 410 handling, health check, README for local/Hostinger boot.

Stubs/interfaces allowed so later phases plug in: `LocaleResolver`, `RedirectService`, `SeoAuditService`, AI/RAG contracts (empty), no CMS.

**Do not implement:** translator, AI, RAG, chat, billing, complete authentication UI, CMS, full dictionary, large content system.

### Phase 2 — Database

- Migrations + `schema.sql`
- Seed regions, tones, categories, admin user (local only)
- Repository interfaces

### Phase 3 — Public SEO platform

- Router + LocaleResolver
- Home, about, pricing, darija hub
- Dictionary/phrase/guide/culture/travel/learn/blog shells
- Metadata, breadcrumbs, schema **by page type** (no global SoftwareApplication)
- SeoAuditService on publish
- robots, sitemaps, llms.txt
- Internal linking: hub + related + breadcrumbs (no auto-link-every-word)

### Phase 4 — Authentication

- Register/login/logout, sessions, email verify (or deferred), profile, password reset, rate limits

### Phase 5 — Translator

- Glossary-backed public teaser + `/app/translator`
- Quotas, caching, UI that shows tone/context when a verified match exists

### Phase 6 — Verified Darija knowledge

- Full editorial model, provenance, claim levels, lifecycle including `deprecated`
- Append-only `content_revisions` and revert
- Public knowledge pages only when lifecycle allows indexable publish **and** claim/verification rules pass

### Phase 7 — AI/RAG

- Contracts, one provider adapter, intent, retrieval, prompts, validator, `/app/chat`
- Usage logs and budgets

### Phase 8 — Admin

- CRUD for knowledge and SEO, redirect validation (no chains), users, verification workflow, revisions, AI documents, SEO audit results

### Phase 9 — Advanced SEO/GEO/AEO

- Image sitemap, FAQ expansion, entity pages, crawl budget hygiene, content quality audits, hreflang QA

### Phase 10 — Production hardening

- Backups, log rotation, WAF, cost alerts, load tests of public pages, security review, legal pages, uptime

---

## 19. Related documents

| File | Contents |
|---|---|
| [DATABASE.md](DATABASE.md) | Schema, ERD, indexes, RAG tables |
| [URL_STRUCTURE.md](URL_STRUCTURE.md) | URL map, rewrites, redirects |
| [SEO_ARCHITECTURE.md](SEO_ARCHITECTURE.md) | Metadata, schema, GEO/AEO |
| [CONTENT_ARCHITECTURE.md](CONTENT_ARCHITECTURE.md) | Content types, verification, linking |
| [AI_RAG_ARCHITECTURE.md](AI_RAG_ARCHITECTURE.md) | Providers, RAG, prompts, safety |
| [SECURITY.md](SECURITY.md) | Threat model, controls |
| [HOSTINGER_DEPLOYMENT.md](HOSTINGER_DEPLOYMENT.md) | Deploy, cron, document root |

---

## 20. Decision log (v1)

| Decision | Choice |
|---|---|
| App style | Modular PHP monolith |
| Public rendering | Server-rendered PHP views |
| URLs | Locale-aware, slug-based, no `.php` |
| Default language | English (`/` = en, `x-default`) |
| `/en` prefix | Not a public locale; 301 only if an explicit alias exists |
| Schema | By page/entity type; never global SoftwareApplication |
| Knowledge provenance | First-class fields on verified Darija entities |
| Claim vs lifecycle | Lifecycle status ≠ UI/RAG claim badge |
| Revisions | Append-only `content_revisions`; revert = restore snapshot |
| Redirects | DB-backed; single hop; 410 supported; admin validates |
| Auth | PHP sessions + hashed remember tokens |
| AI | Interface + one HTTP provider |
| Search | MySQL FULLTEXT + structured SQL |
| CSS | Modern CSS in `resources/css` (no mandatory Tailwind build) |
| JS | Vanilla; public pages optional tiny script |
| CDN | Cloudflare optional, designed-in |
| Admin | Same app, `/admin`, role-gated |
| Vector DB | Not required for v1 |

---

## 21. Approved corrections (v1.1)

These are **policy patches**, not a redesign.

1. **LocaleResolver** owns URL locale rules. English canonicals are unprefixed. `/en/...` is created only when needed as an alias and then 301s once to the canonical English path.
2. **JSON-LD** is selected per page type. `SoftwareApplication` / `WebApplication` only on a genuine product/app page.
3. **Provenance** is required on verified Darija knowledge (source, reviewer, method, confidence, regional scope).
4. **content_revisions** is an append-only snapshot log for listed entity types, with revert.
5. **redirects** is the single application redirect system; Hostinger `.htaccess` only does host/scheme/slash.
6. **SeoAuditService** gates publish with PASS / WARNING / ERROR; usefulness over word count.
7. **LinkingService** requires hub + related + breadcrumbs; no automatic every-token linking.
8. **RAG citations** use stable internal knowledge IDs in the prompt; user UI shows badges, not raw DB ids.
