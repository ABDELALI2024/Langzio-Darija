# Langzio Hostinger Deployment Architecture

**Target:** Hostinger Business Web Hosting (shared/business, not VPS).  
**Runtime:** PHP 8.x, MySQL 8.x, Apache or LiteSpeed, `.htaccess`, HTTPS, cron.

---

## 1. Principle

The Git repository’s `public/` directory is the **only** web-reachable tree. PHP code, env, logs, and uploads live **outside** the document root whenever the panel allows it.

```text
/home/<user>/
├── domains/langzio.com/           # example layout; names vary
│   ├── public_html/               # ← MUST be the contents of repo /public
│   │   ├── index.php
│   │   ├── .htaccess
│   │   ├── robots.txt
│   │   ├── assets/
│   │   └── images/
│   ├── app/
│   ├── config/
│   ├── resources/
│   ├── database/
│   ├── storage/
│   └── .env                       # chmod 600
```

`public/index.php` bootstraps:

```php
require dirname(__DIR__) . '/app/Bootstrap.php';
```

If Hostinger only allows files inside `public_html`, use a **two-folder deploy** on the same account: keep the project in `~/langzio/` and point the domain document root to `~/langzio/public` (hPanel → Advanced → Document Root, if available).

**Fallback (worse):** everything under `public_html` with `app/`, `config/`, `storage/` protected by `Deny from all` `.htaccess`. Still do this as defense in depth, but prefer moving them up one level.

---

## 2. Document root checklist

1. Domain `langzio.com` + chosen www policy.
2. Force HTTPS in hPanel + `.htaccess`.
3. PHP 8.2 or 8.3 selected.
4. `memory_limit` ≥ 256M if AI payloads need it; keep conservative.
5. `max_execution_time` 30–60s (AI calls).
6. OPcache On.
7. `display_errors` Off.
8. Default directory index: `index.php` only.

---

## 3. `.htaccess` responsibilities (public/)

Order to **avoid chains**:

1. HTTPS force
2. Canonical host (www or apex)
3. Trailing slash removal (except `/`)
4. Front controller
5. Cache headers for static assets (`assets/` hashed filenames when we build)
6. Deny dotfiles (`.env` should not be here at all)
7. Custom 404 → `index.php` or `404.php` that bootstraps app

Do not 301 twice (www then https). Combine conditions.

LiteSpeed understands common Apache rewrite flags used on Hostinger.

---

## 4. Environment

Create `.env` on the server (not in Git):

```text
APP_ENV=production
APP_URL=https://<canonical-host>
APP_KEY=<random>
DB_HOST=localhost
DB_NAME=...
DB_USER=...
DB_PASS=...
AI_API_KEY=...
CANONICAL_HOST=...
LOG_LEVEL=warning
```

hPanel MySQL: use the given host (often `localhost`), database name prefix, and user with least privilege (DML on app schema only).

---

## 5. Database deploy

Phase 2+:

1. Create MySQL database in hPanel.
2. Import `database/schema.sql` via phpMyAdmin **or** a one-time CLI if SSH exists.
3. Hostinger Business often includes SSH: use it for `mysql < schema.sql`.
4. Never expose phpMyAdmin to the world longer than needed.

Migrations: PHP scripts run from CLI (`php database/migrate.php`) via SSH or a **protected** admin action (IP allowlist + auth)—prefer CLI.

---

## 6. File permissions

| Path | Mode | Owner |
|---|---|---|
| `.env` | 600 | account |
| `storage/**` | 775 or 755 writable | account |
| `public/assets` | 644 files | |
| PHP files | 644 | |
| Directories | 755 | |

`storage/logs`, `storage/cache`, `storage/rate_limits`, `storage/uploads` must be writable by the PHP user.

---

## 7. Cron (hPanel)

Examples (once code exists):

```text
# every 5 minutes — job runner
php /home/<user>/.../cron/run.php

# daily 03:00 — sitemaps, log rotate, purge auth_attempts
php /home/<user>/.../cron/daily.php
```

Use full paths to `php` and the project. Cron is the **only** background mechanism in v1 (no Supervisor, no Redis queue).

Jobs: sitemap write, embedding enqueue (optional), cache GC, usage log purge.

---

## 8. TLS and CDN

- Hostinger SSL (Let’s Encrypt) on the origin.
- Optional Cloudflare: orange-cloud DNS, Full (strict) SSL when origin cert is valid.
- Cloudflare cache rules: cache GET HTML for public knowledge; **bypass** `/app`, `/admin`, `/api`, `/login`.
- Page Rules / Cache Rules: respect `Cache-Control` from origin.

`APP_URL` and canonical tags must match the public hostname (www vs apex) **after** Cloudflare.

---

## 9. Deploy process (v1, no Docker)

Recommended:

1. Local git on `main`.
2. SSH `git pull` in the project directory **or** SFTP of release folder.
3. Run migrations if any.
4. Clear `storage/cache`.
5. Hit `/` and a dictionary URL.

Atomic releases later: `releases/20261004/` + symlink `current` if the host allows symlinks (LiteSpeed usually does).

**Do not** SFTP `.env` from an old server blindly. **Do not** upload `storage/logs`.

Composer: if/when added, `composer install --no-dev --optimize-autoloader` over SSH. Vendor lives outside public.

---

## 10. What Hostinger will not do well

| Need | v1 workaround | Later VPS |
|---|---|---|
| Redis | file cache | Redis |
| Queue workers | cron every minute | systemd worker |
| Websockets | polling / no realtime | WS server |
| Node SSR | PHP SSR | optional Node |
| Vector search | SQL FULLTEXT | Qdrant/pgvector |
| Horizontal scale | one app + CDN | php-fpm pool + replica |

Design interfaces now; do not fake Redis on v1.

---

## 11. Backups

- hPanel weekly/daily DB backups enabled.
- Periodic export of `storage/uploads`.
- Off-site copy of `.env` in a password manager, not Git.

Test restore before public launch (Phase 10).

---

## 12. Monitoring

- Uptime on `/health` (JSON: `ok`, app version, **no** config dump).
- Disk: logs must rotate or Hostinger inode limits hurt.
- AI spend: dashboard of provider + `ai_usage_logs` admin view.

---

## 13. Local vs production parity

| | Local | Hostinger |
|---|---|---|
| Doc root | `public/` | `public_html` ← `public/` |
| HTTPS | optional | required |
| Mail | log driver | SMTP (Hostinger or transactional later) |
| AI | NullProvider or cheap model | production key + caps |

---

## 14. Go-live cutover (when product exists)

1. Set canonical host and 301s.
2. Submit sitemap in Search Console.
3. Verify `robots.txt` and `llms.txt` over HTTPS.
4. Confirm `.env` not fetchable (`https://host/.env` → 404).
5. Confirm `/app/` 302 to login and `noindex`.
6. Confirm directory listing disabled.
7. Enable HSTS only after HTTPS is stable.

---

## 15. Migration off Hostinger

1. Provision VPS (nginx + php-fpm 8.x + MySQL).
2. Copy code, `.env`, storage, dump DB.
3. Point DNS / Cloudflare origin.
4. Swap cache/rate-limit implementations.
5. Keep the same URLs.

No application rewrite required if Phase 1 honors `docs/ARCHITECTURE.md`.
