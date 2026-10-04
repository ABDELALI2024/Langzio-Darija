# Langzio URL Structure

Clean, permanent, rewrite-based URLs. **No `.php` in canonical URLs. No `?id=` content addressing.**

---

## 1. Canonical host and slash policy

**Decision (v1):**

| Rule | Value |
|---|---|
| Scheme | `https` only (HTTP 301 → HTTPS) |
| Host | `www.langzio.com` **or** `langzio.com` — pick one at deploy; the other 301s |
| Trailing slash | **None** except the homepage `/` |
| Case | Paths lowercased; 301 if mixed case |
| Default locale | English at `/` (no `/en/` prefix on canonicals) |
| Other locales | `/fr/...`, `/ar/...` |
| English `/en/` prefix | **Not** a public locale. Do **not** blanket-redirect every `/en/*` request. Create `/en/...` **only if explicitly needed** (legacy, inbound links). If such an alias exists, **one** 301 to the unprefixed English canonical. |

Avoid redirect chains: HTTP+www+slash is **one** hop in `.htaccess`. Application redirects (locale aliases, slugs, 410) are **one** hop in `RedirectService`. Never stack a host redirect and an app redirect into two hops when it can be one (prefer app paths already canonical).

---

## 2. Locale pattern (`LocaleResolver`)

All locale URL rules live in **one** class: `App\Support\LocaleResolver`. Middleware and SEO call it; templates do not invent prefixes.

```text
/{path}                 → locale = en (canonical English), hreflang x-default
/fr/{path}              → locale = fr (only if a real FR translation exists)
/ar/{path}              → locale = ar (only if a real AR translation exists)
/en/{path}              → not served as a document;
                          301 to /{path} IFF an explicit alias/redirect exists
```

`{path}` is identical across locales for the **same entity** when a translation exists.

If a French (or Arabic) translation is missing: **do not invent the URL**. Do not clone English. Do not 301 a never-published `/fr/...` unless that path was previously public and is now abandoned.

hreflang includes **only** URLs that are real, translated, and indexable.

Every localized page’s canonical is **self-referencing** (the FR page canonical is the FR URL).

---

## 3. Public URL map

### 3.1 Marketing and entity

| Path | Page | Index |
|---|---|---|
| `/` | Home | yes |
| `/darija` | What Darija is (hub) | yes |
| `/darija-translator` | Public translator landing + teaser | yes |
| `/translator` | 301 → `/darija-translator` | — |
| `/about` | Organization / about | yes |
| `/pricing` | Plans | yes |
| `/contact` | Contact (optional v1) | yes |
| `/privacy` | Privacy | yes |
| `/terms` | Terms | yes |

### 3.2 Knowledge hubs

| Path | Page |
|---|---|
| `/dictionary` | Dictionary index (paginated if needed: `/dictionary/page/2` **or** `?page=` only for pagination, rel next/prev; never for identity) |
| `/dictionary/{termSlug}` | Term |
| `/phrases` | Phrase index |
| `/phrases/{phraseSlug}` | Phrase |
| `/guides` | Guide index |
| `/guides/{guideSlug}` | Guide |
| `/culture` | Culture hub |
| `/culture/{slug}` | Culture article |
| `/travel` | Travel hub |
| `/travel/{slug}` | Travel article |
| `/learn` | Learning hub |
| `/learn/{slug}` | Lesson/path |
| `/blog` | Article index |
| `/blog/{slug}` | Article |
| `/faq` | Site FAQ (optional) |

### 3.3 Examples (English)

```text
/
/darija
/darija-translator
/dictionary
/dictionary/safi
/dictionary/3afak
/dictionary/bghit
/phrases
/phrases/thank-you-in-darija
/phrases/how-to-order-food-in-darija
/phrases/darija-for-taxi
/guides
/guides/moroccan-etiquette
/guides/moroccan-slang
/guides/darija-pronunciation
/travel
/travel/darija-for-tourists
/culture
/learn
/blog
/pricing
/about
```

French examples:

```text
/fr
/fr/darija
/fr/dictionary/safi
/fr/phrases/thank-you-in-darija
```

Arabic examples:

```text
/ar
/ar/darija
/ar/dictionary/safi
```

Dictionary **slugs stay Latin** in all locales so one entity has one slug key. Visible title/script is Arabic on the page.

---

## 4. Authenticated application

All noindex.

```text
/app
/app/translator
/app/chat
/app/guides
/app/kids
/app/profile
/app/settings
/app/login          → prefer /login for SEO-free but bookmarkable
```

Auth pages (noindex):

```text
/login
/register
/forgot-password
/reset-password/{token}     token in path is disposable; still noindex
```

Admin (noindex, extra authz):

```text
/admin
/admin/terms
/admin/phrases
/admin/guides
/admin/articles
/admin/categories
/admin/tags
/admin/redirects
/admin/users
/admin/seo
/admin/ai-documents
/admin/verification
```

---

## 5. API

```text
/api/v1/translate
/api/v1/chat
/api/v1/me
```

JSON only. Not in sitemaps. `robots: Disallow /api/`. Same origin. CSRF on cookie session.

---

## 6. Discovery files

| URL | Source |
|---|---|
| `/robots.txt` | static or generated |
| `/sitemap.xml` | sitemap index |
| `/sitemap-pages-en.xml` | etc. |
| `/llms.txt` | static + curated links |
| `/llms-full.txt` | expanded curated knowledge map |
| `/favicon.ico` | |
| `/.well-known/...` | only if needed |

---

## 7. Routing resolution

Example: `GET /dictionary/safi`

```text
.htaccess → public/index.php
RedirectService: match normalized path
  410 → gone template (no further routing)
  301/302 → Location: destination_path (single hop; destination must not itself be an active redirect)
LocaleResolver: locale + canonical path
Router: name=dictionary.show, slug=safi
DictionaryController::show
  404 if missing (never a soft 404)
SeoService::build(term, en)  → self canonical, hreflang of real locales only
LinkingService::related(term)
View: resources/views/public/dictionary/show.php
```

---

## 8. Rewrite rules (logical)

```apache
# All non-files to front controller
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^ index.php [L]
```

Static assets in `/assets` and `/images` are real files.

Reserved first path segments:

```text
darija, darija-translator, translator, dictionary, phrases, guides,
culture, travel, learn, blog, about, pricing, contact, privacy, terms,
faq, app, admin, api, login, register, forgot-password, reset-password,
fr, ar, en
```

---

## 9. Pagination

- Prefer `/dictionary` with `rel=next/prev`.
- If needed: `/dictionary/page/2` (indexable only if unique value; otherwise `noindex` page 2+).
- **v1 recommendation:** page 1 canonical; `page >= 2` `noindex,follow` to avoid thin duplicate hubs, unless each page is substantial.

---

## 10. Central redirect system

Application redirects are **database-backed** (`redirects` table). `.htaccess` does not encode a growing slug map.

| Use | Code | Notes |
|---|---|---|
| Old slug → new slug | 301 | Permanent |
| Old route → new route | 301 | e.g. `/translator` → `/darija-translator` |
| Deleted content → replacement | 301 | successor URL |
| Temporary (rare) | 302 | must have `reason`; default is 301 |
| Intentional removal, no successor | 410 | `destination_path` NULL |
| Explicit `/en/{path}` alias | 301 | only if that alias is created |

### 10.1 Chain prevention

`RedirectService` and admin validation:

1. Normalize `source_path` and `destination_path` (lowercase, no trailing slash except `/`, relative path starting with `/`, no `//` hosts).
2. `source_path` ≠ `destination_path`.
3. Destination of a 301/302 **must not** be another **active** redirect source (resolve/flatten at save time or reject).
4. Destination must not 410.
5. Cycles rejected.
6. At request time, **one** Location hop only. If data ever contains a chain, log ERROR and jump to the final destination in one response (repair), then fix the row.

### 10.2 Examples

| From | To | Code |
|---|---|---|
| `/translator` | `/darija-translator` | 301 |
| `/en/dictionary/safi` (if alias exists) | `/dictionary/safi` | 301 |
| `/dictionary/safi/` | `/dictionary/safi` | 301 (slash policy; `.htaccess` or app, not both) |
| Old slug | New slug | 301 |
| Removed URL, no successor | — | 410 |

Redirects run **before** the router 404. Admin must validate new rows (Phase 8). Phase 1: service stub that can return 410 for configured paths / empty table.

---

## 11. Query strings

Allowed:

- UTM (`utm_source`) — canonical **strips** them
- Pagination `?page=` only if not using path pagination

Forbidden as identity:

- `?id=45`
- `?page=phrase`

---

## 12. Full URL inventory (v1 build order)

**Phase 3 must ship:** `/`, `/darija`, `/dictionary`, at least one term, `/phrases`, at least one phrase, `/about`, `/pricing`, `/robots.txt`, `/sitemap.xml`.

**Later public:** guides, culture, travel, learn, blog, translator landing.

**App:** after Phase 4–5.

---

## 13. Orphan prevention

Every published entity must have ≥1 inbound link from:

- its hub index, **and**
- at least one related entity or editorial module on home/hub

Nightly job (cron): list published URLs with zero `entity_links` inbound + not linked from hubs → admin report.

---

## 14. Sitemap membership

Include if:

- `content_status = published`
- `robots` allows index
- locale version exists and is a real translation
- `published_at <= now`

Exclude `/app`, `/admin`, `/api`, auth pages, drafts, 410s.
