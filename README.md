# Langzio

**Darija with context, not just translation.**

Langzio is a production web platform for **Moroccan Darija**: verified phrases, natural pronunciation, tone, cultural context, situational usage, learning resources, and AI assistance that is grounded in editorial knowledge—not a generic translation website.

Long-term positioning:

> **AI-powered cultural intelligence for Moroccan Darija.**

This repository is the **modular PHP monolith** intended to run on **Hostinger Business Web Hosting** today and migrate to a VPS later without a rewrite.

**Current status:** architecture **approved with v1.1 corrections**. Phase 1 (foundation) starts after this correction review—not before.

---

## Documentation

| Document | Purpose |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design, constraints, review Q&A, roadmap |
| [docs/DATABASE.md](docs/DATABASE.md) | MySQL schema, ERD, indexes, RAG tables |
| [docs/URL_STRUCTURE.md](docs/URL_STRUCTURE.md) | Permanent URL map, locales, rewrites |
| [docs/SEO_ARCHITECTURE.md](docs/SEO_ARCHITECTURE.md) | SEO, GEO/AEO, schema, sitemaps, llms.txt |
| [docs/CONTENT_ARCHITECTURE.md](docs/CONTENT_ARCHITECTURE.md) | Content types, Verified Darija, linking |
| [docs/AI_RAG_ARCHITECTURE.md](docs/AI_RAG_ARCHITECTURE.md) | LLM/RAG module, safety, providers |
| [docs/SECURITY.md](docs/SECURITY.md) | Auth, CSRF, XSS, secrets, abuse |
| [docs/HOSTINGER_DEPLOYMENT.md](docs/HOSTINGER_DEPLOYMENT.md) | Document root, env, cron, TLS, deploy |

---

## Architecture in one page

```text
User / Google / AI crawlers
        ↓
Cloudflare (optional CDN/WAF)
        ↓
Hostinger (LiteSpeed/Apache + PHP 8 + HTTPS)
        ↓
PHP application (public/index.php)
 ├── Public SEO layer   (/ dictionary, phrases, guides, …)
 ├── Application layer  (/app/…)
 ├── Auth
 ├── Translator
 ├── AI + RAG module
 └── Admin
        ↓
MySQL 8
        ↓
External LLM provider (HTTPS; keys in env)
```

**Two layers, one app:** public pages are crawlable SSR HTML with almost no JavaScript. `/app` requires login and may load a separate JS bundle. `/app` is `noindex`.

---

## Stack (v1)

| Layer | Choice |
|---|---|
| Language | PHP 8.x |
| Database | MySQL 8.x, PDO |
| Web | Apache / LiteSpeed, `.htaccess` |
| Front | HTML5, CSS3, vanilla JS (no mandatory React/Vue/Next) |
| Auth | PHP sessions + hashed tokens |
| AI | Provider interface; one HTTP LLM |
| Search | MySQL FULLTEXT + SQL filters |
| Cache | HTTP/CDN + file cache (`storage/cache`) |

**Not required for v1:** Node server, Docker, Kubernetes, Redis, PostgreSQL, Python workers, dedicated vector database.

---

## Local development (planned)

When Phase 1 exists:

1. PHP 8.2+ and MySQL 8 locally (XAMPP, Laravel Herd, Docker-optional—not mandatory).
2. Copy `.env.example` → `.env` (never commit `.env`).
3. Point a vhost document root at `public/`.
4. Import `database/schema.sql` or run migrations.
5. `storage/` writable.

Until then, there is nothing to boot except this documentation.

---

## Environment variables

See `.env.example` (to be added in Phase 1). Expected groups:

- `APP_ENV`, `APP_URL`, `APP_KEY`
- `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASS`
- `SESSION_*`, `COOKIE_*`
- `AI_PROVIDER`, `AI_API_KEY`, `AI_MODEL`
- `CANONICAL_HOST`, `FORCE_HTTPS`
- `LOG_LEVEL`

Never expose `.env` via the web server.

---

## Database setup

Normalized InnoDB schema for users, verified Darija knowledge, content, SEO, redirects, and AI logs. Embeddings table is optional and unused for retrieval in v1.

Full design: [docs/DATABASE.md](docs/DATABASE.md).

---

## SEO system

Public routes emit unique metadata, canonicals, hreflang, Open Graph, Twitter tags, and honest JSON-LD. Sitemaps, `robots.txt`, `llms.txt`, and `llms-full.txt` are first-class.

Details: [docs/SEO_ARCHITECTURE.md](docs/SEO_ARCHITECTURE.md).

---

## AI system

Controllers call `AIService` / `RAGService`, never a hardcoded vendor SDK everywhere. Retrieval prefers **verified** rows. Responses must label verification level. Unverified generation cannot be stored as published dictionary content.

Details: [docs/AI_RAG_ARCHITECTURE.md](docs/AI_RAG_ARCHITECTURE.md).

---

## Security

PDO prepared statements, CSRF, output escaping, secure cookies, Argon2id/bcrypt, session regeneration, login and API rate limits, authorization on admin/app, secrets only in env.

Details: [docs/SECURITY.md](docs/SECURITY.md).

---

## Hostinger deployment

Document root = `public/` only. Application code lives **outside** the web root when the host allows it. Cron runs sitemap rebuild, log rotation, and the PHP job runner.

Details: [docs/HOSTINGER_DEPLOYMENT.md](docs/HOSTINGER_DEPLOYMENT.md).

---

## Future migration (VPS)

Swap implementations behind interfaces: cache, rate limiter, retrieval (vector DB), queue, sessions. Keep URLs, knowledge schema, and verification semantics stable.

---

## Roadmap

1. Foundation  
2. Database  
3. Public SEO platform  
4. Authentication  
5. Translator  
6. Verified Darija knowledge  
7. AI/RAG  
8. Admin  
9. Advanced SEO/GEO/AEO  
10. Production hardening  

**Do not implement Phase 2+ until the architecture is reviewed.**

---

## License / brand

Product name: **Langzio**. Website: **https://langzio.com** (canonical host to be locked at deploy).
