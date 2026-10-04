# Langzio Security Architecture

Security is designed before feature code. Shared hosting increases the need for **boring, strict** controls: the filesystem is the attack surface as much as the app.

---

## 1. Threat model (v1)

| Threat | Example | Severity |
|---|---|---|
| SQL injection | Search/slug params | High — PDO always |
| XSS | Examples, admin HTML, AI markdown | High |
| CSRF | Translate? less; account email change | High |
| Auth brute force | /login | High |
| Session theft | Cookie over HTTP, XSS | High |
| Secret leak | `.env` in web root, Git | Critical |
| AI cost abuse | Bot chat | High |
| Prompt injection | “ignore previous” | Medium |
| Privilege escalation | user hits /admin | High |
| Upload malware | future audio/images | High |
| Path traversal | cache/log viewers | High |
| Open redirect | `redirects.to_path` | Medium |
| Enumeration | unpublished slugs | Low–Med |

Out of scope for v1 host: kernel exploits, other tenants on shared host (assume hostile neighborhood → treat filesystem permissions and public root carefully).

---

## 2. Secrets

- `.env` **never** committed; `.env.example` has empty values.
- `.env` **never** inside document root.
- `APP_KEY` used for cookie/HMAC; rotate = invalidate sessions.
- `AI_API_KEY`, DB password: env only.
- Config PHP files return arrays; they may read env, not hardcode production secrets.
- Admin UI never displays full keys.

If a secret leaks: rotate Hostinger DB password, AI key, `APP_KEY`, sessions.

---

## 3. HTTP security headers

Applied globally via middleware:

```text
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
Content-Security-Policy: default-src 'self'; img-src 'self' data: https:; media-src 'self';
  style-src 'self'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'
```

Tighten CSP as features land. Avoid `unsafe-inline` on public pages; if inline critical CSS is used, prefer hashes.

`Cross-Origin-Opener-Policy` / `Cross-Origin-Resource-Policy` as compatible.

---

## 4. Cookies and sessions

| Attribute | Value |
|---|---|
| Name | `__Host-langzio_session` if path=/ and HTTPS (prefix requires Secure and Path=/) |
| HttpOnly | true |
| Secure | true |
| SameSite | Lax for app; Strict for admin cookie if split |
| Path | `/` |
| Lifetime | short session; remember-me separate hashed token |

PHP: `session.use_strict_mode=1`, `session.cookie_httponly=1`, regenerate id on login, logout, and role change.

Remember-me: store **only hash** in `user_sessions`; rotate on use.

---

## 5. Passwords

- `password_hash($pass, PASSWORD_ARGON2ID)` if available, else `PASSWORD_BCRYPT`.
- `password_verify` + `password_needs_rehash`.
- Min length 10+; reject leaked common passwords list (small local list v1).
- Reset tokens: random 32+ bytes, hashed in DB, short TTL, single use.

---

## 6. CSRF

- Token in session; hidden field on all POST forms.
- Same-origin `fetch`: header `X-CSRF-Token`.
- Safe methods GET/HEAD/OPTIONS do not mutate.
- Compare `hash_equals`.

---

## 7. XSS and HTML

- Default: `htmlspecialchars(..., ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8')` in views.
- Guide `body_html`: allowlist sanitizer (tags: p, h2–h3, ul, ol, li, a, em, strong, blockquote). No `script`, `iframe`, `style`, `on*`.
- AI markdown: render with a conservative converter + sanitizer; no raw HTML from the model.
- JSON responses: `Content-Type: application/json; charset=utf-8`.

---

## 8. SQL

- PDO `ERRMODE_EXCEPTION`, `EMULATE_PREPARES` off when possible.
- Prepared statements for every variable.
- Identifiers (ORDER BY) allowlisted, never concatenated from input.
- Slugs validated: `^[a-z0-9]+(?:-[a-z0-9]+)*$` plus leading digit allowed (`3afak`).

---

## 9. Authorization

```text
Public routes: no auth
App routes: authenticated + is_active
Admin routes: role admin or editor (capability matrix)
Verification publish: reviewer or admin
User A cannot load user B conversations (check user_id)
```

Every controller action checks; do not rely on hidden UI.

---

## 10. Rate limiting

`RateLimiterInterface`:

- Key: `ip_hash + route_class` and `user_id + route_class`
- Store: files under `storage/rate_limits/` or `rate_limit_counters` table
- Login: e.g. 5 / 15 min then exponential delay / lock
- Register: tighter
- API translate/chat: see AI doc
- Generic POST: burst cap

Behind Cloudflare: still enforce app-level limits (edge is bypassable).

`auth_attempts` written on failure for audit.

---

## 11. Input validation

Central `Validator` helper: types, max lengths (translate input e.g. 500–2000 chars), UTF-8, locale enum, enum statuses.

Reject unexpected `Content-Type` on APIs.

---

## 12. File uploads (when enabled)

- Disable until needed.
- Allowlist mime + extension + magic bytes.
- Random storage name in `storage/uploads` **outside** public.
- Serve via PHP with `Content-Disposition` and MIME we set.
- No PHP/HTML execution in upload dirs (`.htaccess` deny).
- Size cap; image re-encode when possible.

---

## 13. App vs public JS

Public pages: no secrets, no AI keys, minimal JS.  
App JS: still no keys; calls `/api/v1` with cookies + CSRF.

---

## 14. Logging (security)

`security.log`: failed login (email **hash** or truncated), CSRF fail, rate limit trip, admin mutations (entity id, actor id).

Never: passwords, tokens, `Authorization`, full cookie, raw IP if policy hashes (store hash + optional short retention raw behind access control—prefer hash).

---

## 15. PHP / Hostinger hardening

- `display_errors = Off` in production
- `expose_php = Off` if allowed
- Disable unused PHP functions if Hostinger allows (`exec` not needed)
- Directory listing Off
- Deny web access to `/app`, `/config`, `/storage`, `/database` if they ever sit under a URL
- Front controller only
- Disable XML external entity if using XML
- Keep PHP version current on hPanel

---

## 16. Redirect safety

`redirects.to_path` must be site-relative paths starting with `/`, not `//evil.com`. Open-redirect tests on `return` query after login: allowlist relative paths.

---

## 17. AI-specific

- Keys server-side
- Budgets and timeouts
- Do not send other users’ conversations
- Do not send unpublished knowledge to anonymous users
- Output sanitization
- Kids mode enforced server-side

---

## 18. Roles (v1)

| Role | Can |
|---|---|
| anonymous | public GET, limited translate teaser |
| user | /app features per plan |
| editor | draft/edit knowledge, not publish verified if policy requires reviewer |
| reviewer | verify + publish |
| admin | users, redirects, config flags, all content |

---

## 19. Security roadmap (Phase 10)

- Dependency audit (when Composer is introduced)
- Backup restore test
- Cloudflare WAF
- Optional 2FA for admin
- Legal: privacy policy, cookie notice if analytics added
- Penetration-style review of auth and admin
