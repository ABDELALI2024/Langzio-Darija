# Langzio SEO, GEO, and AEO Architecture

SEO is a first-class subsystem, not a plugin added after launch. Public pages must work for Google, Bing, AI search, answer engines, and human readers **without login**.

---

## 1. Goals

- Rank for intent around Moroccan Darija, not generic “translator” spam.
- Earn entity understanding: **Langzio** = Darija cultural intelligence.
- Be extractable by LLMs: factual, structured, dated, sourced where possible.
- Protect crawl budget: quality pages only.
- International: EN (default), FR, AR.

---

## 2. Every public HTML page must emit

| Element | Rule |
|---|---|
| `<title>` | Unique, intent-matched, ≤ ~60 chars when possible |
| `meta name="description"` | Unique, 140–160 chars, no keyword stuffing |
| `link rel="canonical"` | Absolute HTTPS URL, slash/host normalized |
| `meta name="robots"` | Default `index,follow`; drafts/auth `noindex` |
| Open Graph | `og:title`, `og:description`, `og:url`, `og:type`, `og:image`, `og:locale`, `og:site_name=Langzio` |
| Twitter/X | `summary_large_image` when a real image exists |
| `hreflang` | Only locales that exist + `x-default` |
| JSON-LD | Types that **match visible content only** |
| Canonical breadcrumbs | Visible + `BreadcrumbList` |
| Semantic HTML | One `h1`, article/main, lists for examples |
| Image `alt` | Descriptive; Darija terms named |
| Internal links | Hub + related entities |
| `lang` on `<html>` | `en`, `fr`, or `ar`; `dir="rtl"` on Arabic UI |

Implemented by `SeoService` + view layout `resources/views/layouts/public.php`. Controllers pass a `SeoDocument` DTO. No ad-hoc tags in random templates.

---

## 3. Entity identity (Organization)

Consistent everywhere (about, footer, JSON-LD, social):

| Field | Value |
|---|---|
| Name | Langzio |
| URL | Canonical site origin |
| Description | AI-powered cultural intelligence for Moroccan Darija. Darija with context, not just translation. |
| Logo | Absolute URL to a stable PNG/SVG in `/images/brand/` |
| sameAs | Official profiles only when they exist (do not invent) |

`WebSite` schema includes `name`, `url`, optional `SearchAction` **only if a working public search URL exists**.

Do not emit fake ratings or fake `AggregateRating`. Do not emit `SoftwareApplication` / `WebApplication` except on a page that actually describes the product.

---

## 4. Schema.org policy

**Allowed when accurate:**

| Type | Where |
|---|---|
| `Organization` | Home, about, and other pages that present the organization — not a junk add-on on every thin URL |
| `WebSite` | Homepage only |
| `WebPage` | Ordinary public pages |
| `DefinedTerm` | Dictionary term pages **where the page actually defines the term** |
| `Article` | Articles and guides that are genuinely article-like |
| `FAQPage` | Only if FAQ is visible on that page and qualifies |
| `BreadcrumbList` | Pages that **show** breadcrumbs |
| `SoftwareApplication` or `WebApplication` | The actual product/application page (e.g. pricing or product), never global |

**Forbidden:** schema that is not on-page; scraped author markup; stacked junk types.

JSON-LD is generated from the same DTO as visible fields (`headline` = `h1`, etc.). Tests later should diff schema vs DOM.

`SoftwareApplication` / `WebApplication` is **never** emitted site-wide (not in the layout, not on dictionary/phrase/guide pages). It belongs only on a page whose **visible content** is the Langzio product (for example `/` product section if the homepage honestly describes the app, `/pricing`, or a dedicated product URL). Prefer `WebApplication` if we describe a web app rather than installable software. If the page does not describe the application, omit both.

`Organization` may appear where entity identity is appropriate (home, about, global footer JSON-LD **only if** the page presents the organization). `WebSite` is for the homepage. `WebPage` for ordinary public pages. `DefinedTerm` only when the dictionary page actually defines the term on-screen. `Article` for articles/guides that are articles. `FAQPage` only when a visible FAQ exists and qualifies. `BreadcrumbList` only when breadcrumbs are visible.

---

## 5. GEO / AEO (answer engines)

Answer engines prefer:

1. Direct definition near the top (“Safi in Darija means…”)
2. Pronunciation and tone in short facts
3. When to use / when not to use
4. Examples as `<li>` or `<figure>`
5. FAQ in visible Q/A
6. Last reviewed date for YMYL-adjacent cultural claims
7. Clear distinction: verified vs regional vs uncertain

Page template pattern for `/dictionary/{slug}`:

```text
h1: term + “in Moroccan Darija”
Lead: natural meaning (1–2 sentences)
Facts: pronunciation, tone, formality, region
When to use / when not
Examples
Cultural note
Related terms / phrases / guides
FAQ
Sources / last reviewed
```

This is **editorial**, not spun AI.

---

## 6. Crawler files

### robots.txt (logical)

```text
User-agent: *
Allow: /
Disallow: /app
Disallow: /admin
Disallow: /api
Disallow: /login
Disallow: /register
Disallow: /forgot-password
Disallow: /reset-password

Sitemap: https://www.example-canonical/sitemap.xml
```

AI crawler allow/deny is a **policy decision** in `config/seo.php` (GPTBot, ClaudeBot, Perplexity, Google-Extended, etc.). Default v1: allow reputable search + documented LLM bots on public content; keep `/app` disallowed.

### sitemap.xml

Index of:

- `sitemap-pages-{locale}.xml`
- `sitemap-dictionary-{locale}.xml`
- `sitemap-phrases-{locale}.xml`
- `sitemap-guides-{locale}.xml`
- `sitemap-blog-{locale}.xml`
- `sitemap-images.xml` (Phase 9, only useful images)

`<lastmod>` from `updated_at` / `last_reviewed_at`. Cron regenerates files to avoid timeout.

### llms.txt

Short, curated:

- What Langzio is
- Canonical URLs for hubs
- How to cite verification
- Contact / about

### llms-full.txt

Expanded map of **published** hubs and representative high-quality pages (not a dump of every thin URL). Must stay accurate; regenerate from DB.

---

## 7. Multilingual SEO

```text
<html lang="en">  /
<html lang="fr">  /fr/...
<html lang="ar" dir="rtl">  /ar/...
```

hreflang example for a term that exists in three locales:

```html
<link rel="alternate" hreflang="en" href="https://host/dictionary/safi" />
<link rel="alternate" hreflang="fr" href="https://host/fr/dictionary/safi" />
<link rel="alternate" hreflang="ar" href="https://host/ar/dictionary/safi" />
<link rel="alternate" hreflang="x-default" href="https://host/dictionary/safi" />
```

Canonical is **self** for that locale (FR page canonical is the FR URL, not EN). That is correct for true translations.

`LocaleResolver` decides prefixes. **Do not** blanket-redirect all `/en/*`. An `/en/...` alias 301 exists only when explicitly registered. hreflang lists **only** real, translated, indexable alternates (plus `x-default` pointing at the English canonical).

**Do not** auto-translate entire dictionary with an LLM and publish. FR/AR pages require human (or verified) explanatory copy.

Darija **examples** may stay identical across locales; surrounding explanation changes.

---

## 8. Duplicate content controls

1. One host, HTTPS, slash, case policy (URL doc).
2. Parameter-stripped canonicals.
3. Alias slugs 301.
4. Pagination `noindex` for thin lists (v1).
5. No printer/AMP clones.
6. Tag archives only if substantial; otherwise noindex.
7. `/en/{path}` is **not** a default public URL; 301 only when that alias is explicitly in `redirects`.
8. Unpublished = 404 (never soft 404 empty 200).
9. Redirect chains forbidden (see URL_STRUCTURE).

---

## 9. Title/description formulas (editorial, not spam)

Dictionary:

- Title: `{Latin} / {Arabic} in Darija: meaning, tone, usage | Langzio`
- Description: `{Natural meaning}. Pronunciation, when to use, examples in Moroccan Darija.`

Phrase:

- Title: `{English intent} in Moroccan Darija | Langzio`
- Description: situational + tone warning if informal.

Guides:

- Title: outcome-based (`Moroccan etiquette: Darija you actually use`)

Always unique; `SeoService` checks collision in admin.

---

## 10. Internal linking (SEO view)

See also `CONTENT_ARCHITECTURE.md`. Every **published knowledge page** should include:

- **Parent hub** (dictionary index, phrases index, etc.)
- **Related content** (semantically relevant; capped)
- **Contextual internal links** in body where an editor (or a conservative, allowlisted linker) has a real reason
- **Visible breadcrumbs**

Do **not** auto-link every occurrence of a Darija word. Automatic suggestions may be proposed in admin; live HTML stays limited and useful.

Related module caps (starting point): related terms 3–8, related phrases 3–8, related guides 1–3. Anchor text is descriptive.

---

## 11. Performance as SEO

Public layout budget:

- Critical CSS inlined or one small `public.css`
- No app.js
- Fonts: 1–2 weights, `font-display: swap`, self-host if possible
- Images: WebP/AVIF, width/height, lazy below fold, LCP image `fetchpriority=high`
- No third-party tags on v1 public pages (defer analytics until needed)

Targets: LCP < 2.5s, INP < 200ms, CLS < 0.1.

---

## 12. Indexing and SEO audit workflow

```text
Editor requests publish
  → lifecycle + provenance rules
  → SeoAuditService
       title, meta description, canonical (self), robots,
       H1, heading hierarchy, usefulness/intent (not raw word count),
       internal links, breadcrumbs, structured data vs page type,
       slug, indexability, language, hreflang (real locales only),
       orphan status (hub inbound)
  → PASS | WARNING | ERROR
  → ERROR blocks publish
  → WARNING can publish with acknowledgement (admin)
  → PASS publishes
  → cache purge + sitemap dirty
cron
  → rewrite sitemap files
```

`SeoAuditService` is specified here; implemented in Phase 3/8. Phase 1 may stub the interface.

Usefulness and search intent outrank arbitrary word-count thresholds. A short, complete definition page can PASS. A long thin page can ERROR.

---

## 13. 404 / 410 / 301

| Situation | Status | Page |
|---|---|---|
| Unknown path | 404 | Helpful HTML + links to hubs |
| Soft-deleted with successor | 301 | `redirects` |
| Deliberately removed | 410 | Short gone page; remove from sitemap |
| Unpublished draft URL guess | 404 | Do not leak titles |

Custom error documents via `.htaccess` still go through PHP when possible so chrome/nav remains.

---

## 14. Open Graph images

Default brand card; dictionary pages may use a simple generated card later. v1: shared branded OG image + unique titles (do not generate thousands of spam images).

---

## 15. Measurement (Phase 9+)

- Search Console (sitemaps, coverage, hreflang)
- Crawl logs (Hostinger / Cloudflare)
- Orphan report
- Duplicate title report in admin

No SEO spam KPIs (page count). KPIs: indexed **useful** URLs, impressions for Darija intents, CTR, conversion to `/app`.
