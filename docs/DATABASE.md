# Langzio Database Architecture

**Engine:** MySQL 8.x, InnoDB, `utf8mb4`, collation `utf8mb4_0900_ai_ci` (or `utf8mb4_unicode_ci` if 0900 is unavailable on the host).  
**Access:** PDO, prepared statements only.  
**Principle:** Normalized system of record. Embeddings are optional indexes, not the source of truth.

---

## 1. Design rules

1. No giant “content” table for all types. Shared patterns via consistent columns, not one polymorphic dumping ground for core knowledge.
2. Every public knowledge entity has: `slug`, `status`, `locale` (for explanatory content), verification fields, SEO fields (or a dedicated `seo_metadata` row).
3. Soft deletes only where audit matters (`deleted_at`). Published URLs that are removed become 301 or 410 via `redirects`.
4. Do not store API keys, raw passwords, or session secrets in knowledge tables.
5. IDs: `BIGINT UNSIGNED` auto-increment internally. Public URLs use slugs, never ids.
6. Money later: integer cents, not FLOAT.
7. Timestamps: `created_at`, `updated_at` DATETIME(3) or DATETIME; store UTC.

---

## 2. ERD (logical)

```text
users 1──* user_sessions
users 1──1 user_preferences
users 1──* subscriptions
users 1──* ai_conversations
users 1──* auth_attempts

roles *──* users          (user_roles)

tone_types
regions
knowledge_categories      (tree via parent_id)
tags
content_tags              (content_type, content_id, tag_id)

darija_terms 1──* term_senses
darija_terms 1──* pronunciations
darija_terms *──* darija_terms          (term_relations)
darija_terms *──* darija_phrases        (phrase_terms)
darija_terms 1──* cultural_notes
darija_terms *──* usage_contexts

darija_phrases 1──* phrase_examples
darija_phrases 1──* phrase_variants
darija_phrases 1──* pronunciations
darija_phrases 1──* cultural_notes
darija_phrases *──* usage_contexts
darija_phrases *──* regions             (phrase_regions)

guides 1──* guide_sections
articles
faqs  (may attach to any entity via faq_targets)

seo_metadata            (polymorphic: entity_type + entity_id + locale)
redirects               (central 301/302/410; active; no chains)
content_revisions       (append-only snapshots; revert)
seo_audit_results       (optional persist of last publish audit)

internal_links / entity_links

knowledge_documents 1──* knowledge_chunks
knowledge_chunks 1──0..1 embeddings     (optional)

ai_conversations 1──* ai_messages
ai_usage_logs
```

---

## 3. Lifecycle, claim level, and provenance

Two axes. Do not collapse them into one enum.

### 3.1 Content lifecycle (`content_status`)

Used on knowledge and public SEO entities:

```text
draft | review | verified | published | deprecated | archived
```

| State | Public URL | Notes |
|---|---|---|
| draft | 404 | work in progress |
| review | 404 | editorial queue |
| verified | 404 until published | accuracy signed off; not yet a ranking URL |
| published | 200 indexable (if robots allow) | live |
| deprecated | 301 or 410 via redirects | superseded or withdrawn; not a new ranking URL |
| archived | 404/410 | retained for history, not served |

**Publication rule (v1):** dictionary/phrase public pages require `content_status = published` **and** a claim/provenance profile that is not `ai_suggestion` pretending to be verified.

AI-generated suggestions **never** automatically become `verified` or `published`. A human must change lifecycle and provenance.

### 3.2 Claim level (UI / RAG badges)

How a fact is **presented** (may vary by region or example):

```text
verified | common_usage | regional | uncertain | ai_suggestion
```

This is **not** the same as `content_status`. A published phrase can still mark a variant as `regional`. Chat output can mix badges in one answer.

### 3.3 Provenance (required on verified Darija knowledge)

Every `darija_terms` / `darija_phrases` row (and cultural notes that make factual claims) supports:

| Field | Role |
|---|---|
| source_type | editorial_review, native_speaker, cited_work, fieldwork, user_submission, other |
| source_reference | citation, URL, internal note — not a secret |
| source_language | language of the source (en/fr/ar/darija/mixed) |
| reviewer_id | FK users, NULL until reviewed |
| reviewed_at | when last verified |
| confidence_level | low / medium / high (editorial, not a fake score in public schema) |
| regional_scope | general Morocco, named region code, diaspora, unknown |
| verification_method | native_review, dual_review, desk_research, corpus, other |
| verification_notes | internal; not required on the public page |

`author_id` remains the editor who wrote the current snapshot.

AI must never display `ai_suggestion` as `verified`. Validator uses provenance + claim level + retrieved IDs.

---

## 4. Table specifications

Column lists are architectural. Exact migration SQL is Phase 2.

### 4.1 Identity and access

#### users

| Column | Type | Notes |
|---|---|---|
| id | BIGINT PK | |
| uuid | CHAR(36) UNIQUE | public/external id |
| email | VARCHAR(191) UNIQUE | normalized lowercase |
| email_verified_at | DATETIME NULL | |
| password_hash | VARCHAR(255) | |
| display_name | VARCHAR(100) | |
| locale | CHAR(5) | preferred UI |
| role_primary | VARCHAR(32) | denorm for speed: user/editor/admin |
| is_active | TINYINT(1) | |
| last_login_at | DATETIME NULL | |
| created_at, updated_at | DATETIME | |

#### user_roles

`user_id`, `role` (`user`, `editor`, `admin`, `reviewer`)

#### user_sessions

| Column | Notes |
|---|---|
| id | PK |
| user_id | FK |
| session_token_hash | CHAR(64) | remember-me / server session id hash |
| ip_hash | CHAR(64) | do not store raw IP long-term if avoidable |
| user_agent_hash | CHAR(64) | |
| expires_at | |
| revoked_at | NULL |
| created_at | |

#### user_preferences

`user_id` PK/FK, `ui_locale`, `darija_script_pref` (arabic/latin/both), `kids_mode`, JSON `settings` (validated schema, size-capped).

#### subscriptions

| Column | Notes |
|---|---|
| id | |
| user_id | |
| plan | free / plus / later |
| status | trialing / active / past_due / canceled |
| provider | none / stripe / paddle |
| provider_customer_id | |
| current_period_end | |
| created_at, updated_at | |

#### auth_attempts

Rate-limit source of truth if file store is insufficient: `id`, `email_hash`, `ip_hash`, `action` (login/reset/register), `success`, `created_at`. Indexed `(ip_hash, created_at)`, `(email_hash, created_at)`. Purge via cron (>30 days).

#### csrf_tokens (optional)

Prefer session-stored CSRF. Table only if token must survive session store limits.

---

### 4.2 Taxonomy

#### tone_types

`id`, `code` (formal, casual, playful, blunt, affectionate, joking, rude, respectful), `label_en/fr/ar`, `description`, `sort_order`, `is_active`

#### regions

`id`, `code` (ma-north, ma-south, ma-east, ma-casa, ma-rabat, ma-marrakech, ma-fes, diaspora, general), `name_*`, `parent_id` NULL

#### knowledge_categories

`id`, `parent_id`, `type` (dictionary, phrase, guide, culture, travel, learn), `slug`, `name_*`, `description_*`, `sort_order`, `status`

Unique `(type, slug)`.

#### tags

`id`, `slug` UNIQUE, `name_*`

#### content_tags

`tag_id`, `content_type`, `content_id` — unique triple.

---

### 4.3 Darija knowledge

#### darija_terms

The dictionary entity (headword).

| Column | Notes |
|---|---|
| id | |
| slug | latin URL slug, unique per default; see locale notes |
| script_arabic | NVARCHAR / utf8mb4 text |
| script_latin | e.g. safi, 3afak |
| literal_meaning_en | |
| natural_meaning_en | |
| meaning_fr | |
| meaning_ar_msa | explanation in MSA, not “translation only” |
| part_of_speech | optional |
| formality | 1–5 or FK to tone |
| default_tone_id | FK tone_types NULL |
| content_status | lifecycle: draft…archived |
| claim_level | default badge: verified / common_usage / regional / uncertain / ai_suggestion |
| source_type | provenance |
| source_reference | |
| source_language | |
| confidence_level | low / medium / high |
| regional_scope | VARCHAR or FK regions / `general` |
| verification_method | |
| verification_notes | internal TEXT |
| author_id | FK users NULL |
| reviewer_id | FK users NULL |
| reviewed_at | |
| published_at | |
| current_revision_id | FK content_revisions NULL |
| created_at, updated_at | |

FULLTEXT index on `(script_latin, script_arabic, natural_meaning_en, meaning_fr)`.

Unique: `slug`.

#### term_senses

Multiple meanings: `term_id`, `sense_order`, glosses EN/FR/AR, `notes`, `status`.

#### pronunciations

Polymorphic-ish but typed:

`id`, `entity_type` (`term`|`phrase`|`variant`), `entity_id`, `ipa` NULL, `respelling_en`, `audio_asset_id` NULL, `region_id` NULL, `is_primary`

v1 may skip audio files; column exists.

#### phrase_variants

`phrase_id`, `script_arabic`, `script_latin`, `region_id` NULL, `notes`, `status`

#### darija_phrases

| Column | Notes |
|---|---|
| id | |
| slug | thank-you-in-darija |
| title_en/fr/ar | |
| script_arabic | |
| script_latin | |
| english_meaning | |
| french_meaning | |
| arabic_explanation | |
| literal_meaning | |
| natural_meaning | |
| when_to_use | TEXT |
| when_not_to_use | TEXT |
| formality | |
| default_tone_id | |
| category_id | |
| content_status | |
| claim_level | |
| source_type, source_reference, source_language | |
| confidence_level, regional_scope | |
| verification_method, verification_notes | |
| author_id, reviewer_id | |
| reviewed_at, published_at | |
| current_revision_id | |
| created_at, updated_at | |

#### phrase_examples

`phrase_id`, `darija_arabic`, `darija_latin`, `en`, `fr`, `ar`, `situation`, `sort_order`, `status`

#### phrase_terms

`phrase_id`, `term_id`, `weight` (related vs contains)

#### term_relations

`term_id`, `related_term_id`, `relation` (synonym, antonym, see_also, spelling_variant), unique pair + type

#### cultural_notes

`id`, `entity_type`, `entity_id`, `locale`, `title`, `body`, `content_status`, `claim_level`, provenance fields (same as terms), `author_id`, `reviewer_id`, `reviewed_at`, `current_revision_id`, `updated_at`

#### usage_contexts

`id`, `code` (taxi, souk, family, work, mosque_adjacent_politeness, online, kids, tourist), `label_*`

#### entity_usage_contexts

`entity_type`, `entity_id`, `usage_context_id`

#### phrase_regions / term_regions

`entity_id`, `region_id`, `prevalence` (common | heard | rare)

---

### 4.4 Editorial content

#### guides

`id`, `slug`, `locale` (en/fr/ar — **one row per locale version**, linked via `translation_group_id`), `title`, `excerpt`, `hero_alt`, `category_id`, `content_status`, `claim_level` (guides that teach Darija facts), `published_at`, `author_id`, `current_revision_id`, `updated_at`

#### guide_sections

`guide_id`, `sort_order`, `heading`, `body_html` (sanitized), `anchor_slug`

#### articles

Blog/longform: same locale pattern as guides. `type` = blog | culture | travel | learn if we want one table — **prefer separate tables** for culture_pages, travel_pages, learn_pages if query patterns differ; they can share a `pages` table with `type` if we keep columns identical.

**v1 recommendation:** `pages` table with `type ENUM('culture','travel','learn','marketing')` plus `articles` for blog, `guides` for structured guides. Marketing pages (about, pricing) can be templates + optional `pages` rows for CMS.

#### faqs

`id`, `question`, `answer`, `locale`, `status`

#### faq_targets

`faq_id`, `target_type`, `target_id`, `sort_order`  
Enables dictionary-page FAQs without duplicating FAQ text blindly (same FAQ can attach to related pages **only if the question is still accurate**).

---

### 4.5 SEO

#### seo_metadata

| Column | Notes |
|---|---|
| id | |
| entity_type | term, phrase, guide, article, page, category |
| entity_id | |
| locale | en, fr, ar |
| meta_title | |
| meta_description | |
| canonical_path | stored relative `/dictionary/safi` |
| robots | index,follow / noindex,… |
| og_title, og_description, og_image | |
| twitter_title, twitter_description | |
| schema_type | DefinedTerm, Article, … |
| unique | (entity_type, entity_id, locale) |

If empty, SEO service generates from entity fields (still unique). Rows are versioned via `content_revisions`.

#### redirects

Central application redirect table. Unique active `source_path`.

| Column | Notes |
|---|---|
| id | PK |
| source_path | normalized unique when `active=1` |
| destination_path | NULL if 410 |
| status_code | 301, 302, or 410 |
| reason | required for 302; recommended always |
| active | TINYINT(1) |
| created_at, updated_at | |

Admin validation: no chains, no cycles, site-relative paths only, 410 has no destination. Request path: **one hop**.

#### content_revisions

Simple **append-only** snapshot store. Not a full CMS. Revert = insert a new revision copied from an old snapshot and apply it to the live row.

| Column | Notes |
|---|---|
| id | PK |
| entity_type | darija_term, darija_phrase, cultural_note, guide, article, page, seo_metadata |
| entity_id | |
| revision_no | integer per entity, sequential |
| snapshot_json | full editorially meaningful fields at that time |
| changed_by | user_id |
| change_summary | what changed (short; optional diff_json later) |
| change_reason | why |
| created_at | |

Index `(entity_type, entity_id, revision_no UNIQUE)`. Do not update or delete revision rows in v1 (except legal erasure).

Versioned entities at minimum: `darija_terms`, `darija_phrases`, `cultural_notes`, `guides`, `articles`, `pages`, `seo_metadata`. Child rows (examples, sections) are included **inside** the parent snapshot JSON so revert is one operation.

#### seo_audit_results (optional)

Last audit for an entity+locale: `result` PASS/WARNING/ERROR, `findings_json`, `audited_at`. Not required to serve pages; used by admin publish gate.

#### sitemap_urls (optional materialized)

Generated on publish; can also be query-built. Materialize if sitemap generation is slow on shared CPU.

---

### 4.6 Internal linking

#### entity_links

`from_type`, `from_id`, `to_type`, `to_id`, `rel` (related_term, related_phrase, related_guide, related_culture, related_travel), `weight`, `is_manual`

Unique from/to/rel. Auto-job + editor override.

---

### 4.7 AI / RAG

#### knowledge_documents

Uploaded or editorial RAG sources (style guides, research notes). `id`, `title`, `source_uri`, `content_status`, `claim_level`, `locale`, `license`, `created_at`

**Public SEO must not publish these unless explicitly converted to a content type.**

#### knowledge_chunks

`id`, `document_id`, `chunk_index`, `text`, `token_estimate`, `metadata_json` (term ids, etc.)

#### embeddings

| Column | Notes |
|---|---|
| id | |
| chunk_id | UNIQUE |
| provider | |
| model | |
| dim | INT |
| vector | BLOB or JSON | **not queried in v1 SQL** |
| created_at | |

v1: write embeddings optionally; retrieval does not require them.

#### ai_conversations

`id`, `user_id`, `uuid`, `title` NULL, `created_at`

#### ai_messages

`id`, `conversation_id`, `role` (user/assistant/system), `content`, `verification_summary_json` (levels used), `retrieved_ids_json`, `model`, `created_at`

Do not keep messages forever without a retention policy (e.g. 90 days for free).

#### ai_usage_logs

`id`, `user_id` NULL, `ip_hash`, `endpoint`, `provider`, `model`, `input_chars`, `estimated_tokens`, `latency_ms`, `status`, `error_class`, `created_at`  
**No prompt/response bodies** in this table (those stay in messages with retention).

---

### 4.8 Media (minimal)

#### assets

`id`, `disk` (local), `path`, `mime`, `width`, `height`, `alt_default`, `created_at`  
Files in `storage/uploads` served via authenticated or hashed public route, not raw listing.

---

### 4.9 Rate limiting / jobs

#### rate_limit_counters

If file locking is painful: `id`, `bucket`, `window_start`, `count`. Unique `(bucket, window_start)`.

#### jobs (cron queue)

`id`, `type`, `payload_json`, `run_at`, `attempts`, `status`, `last_error`  
Worker: `php cron/run.php` every minute. No daemon required.

---

## 5. Index plan (v1)

| Table | Index |
|---|---|
| darija_terms | UNIQUE slug; KEY content_status; FULLTEXT |
| darija_phrases | UNIQUE slug; KEY content_status; FULLTEXT (latin, arabic, title_en, english_meaning) |
| guides | UNIQUE (locale, slug); KEY (content_status, published_at) |
| articles | UNIQUE (locale, slug) |
| seo_metadata | UNIQUE (entity_type, entity_id, locale) |
| redirects | UNIQUE (source_path) WHERE active (or unique source_path + active in app) |
| content_revisions | UNIQUE (entity_type, entity_id, revision_no) |
| entity_links | KEY from (type,id); KEY to |
| users | UNIQUE email, uuid |
| auth_attempts | KEY (ip_hash, created_at) |
| ai_usage_logs | KEY (created_at); KEY (user_id, created_at) |

---

## 6. Character set and Darija

- Store Arabic (Maghrebi), Latin transliteration, and IPA (optional) as separate fields.
- Do not force a single transliteration standard in the schema; `script_latin` is the **canonical Latin form for that entry**; variants go in `phrase_variants` / `term_relations` (`spelling_variant`).
- URL slugs: ASCII `[a-z0-9-]` plus digits used in chat latin (`3afak`). No Arabic in v1 slugs (encoding and duplicate-risk). Arabic UI still displays `script_arabic`.

---

## 7. Scaling notes

- Knowledge tables: thousands to low hundreds of thousands is fine on Business hosting if indexed.
- `ai_usage_logs` and `auth_attempts`: grow fast → monthly purge cron.
- Avoid SELECT * on list pages; list DTOs.
- Public pages: read replicas later; v1 single primary.
- Never run unbuffered huge exports on HTTP request; sitemap via cron file write to `public/` or `storage` then copy.

---

## 8. Abstraction for vectors

```text
RetrievalInterface
  search(Query $q): RetrievedSet

MysqlFulltextRetrieval implements RetrievalInterface   ← v1
VectorRetrieval implements RetrievalInterface          ← later
HybridRetrieval                                        ← later
```

Repositories return domain entities. Controllers never read `embeddings.vector` directly.

---

## 9. Versioning and revert flow

```text
Editor saves entity
  → validate
  → INSERT content_revisions (snapshot_json, changed_by, change_summary, change_reason)
  → UPDATE live row + current_revision_id

Editor reverts to revision N
  → load snapshot N
  → apply to live row
  → INSERT new revision (reason: revert to N)
```

No Git-style branches. Child examples/sections travel inside the parent snapshot.

---

## 10. Seed philosophy

Seed **small, excellent** sets:

- 20–50 verified terms
- 15–30 situational phrases
- 3–5 guides
- Organization/about copy

Do not seed thousands of scraped rows.

---

## 11. Backup

Daily Hostinger MySQL backup + weekly logical dump to off-host if possible. `storage/uploads` included. Test restore once per phase after Phase 2.
