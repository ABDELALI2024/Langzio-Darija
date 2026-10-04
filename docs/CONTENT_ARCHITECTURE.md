# Langzio Content Architecture

Quality > volume. The public knowledge base **is** the SEO engine and the RAG corpus. It must be original, situational, and honest about verification.

---

## 1. Positioning in content

Every public template should reinforce:

> Darija with context, not just translation.

That means pages explain **tone, when, where, with whom**, not only English glosses.

---

## 2. Content types

| Type | URL | Purpose | Verification |
|---|---|---|---|
| Dictionary term | `/dictionary/{slug}` | Headword intelligence | Required for public v1 |
| Phrase | `/phrases/{slug}` | Situational utterance | Required |
| Guide | `/guides/{slug}` | Structured teaching | Required |
| Culture | `/culture/{slug}` | Cultural intelligence | Required |
| Travel | `/travel/{slug}` | Tourist situations | Required |
| Learn | `/learn/{slug}` | Learning paths | Required |
| Article (blog) | `/blog/{slug}` | Editorial, not spam | Editor review |
| FAQ | attached or `/faq` | Real questions | Required if factual Darija |
| Marketing | `/`, `/about`, `/pricing` | Entity + product | Legal/brand review |

Do not create a new URL type for every tag.

---

## 3. Verified Darija (core object)

A **Verified Darija** entry (term or phrase) **must be capable of** storing:

| Field | Term | Phrase |
|---|---|---|
| Darija Arabic | yes | yes |
| Darija Latin | yes | yes |
| Pronunciation | yes | yes |
| English meaning | yes | yes |
| French meaning | yes | yes |
| Arabic (MSA) explanation | yes | yes |
| Literal meaning | yes | yes |
| Natural meaning | yes | yes |
| Tone | yes | yes |
| Formality | yes | yes |
| Context / usage contexts | yes | yes |
| When to use | optional | **required** |
| When not to use | optional | **required** |
| Example sentences | yes | yes |
| Regional variation | yes | yes |
| Related phrases/terms | yes | yes |
| Cultural notes | yes | yes |
| Verification status | yes | yes |
| Provenance (source_type, source_reference, source_language, reviewer, reviewed_at, confidence, regional_scope, method, notes) | yes | yes |
| Author / editor | yes | yes |
| Revisions | yes | yes |

Public template **shows** empty sections only if they exist. Do not render “Regional variation: N/A” thousands of times. Prefer omitting unused blocks.

---

## 4. Lifecycle vs claim vs AI

**Lifecycle** (`content_status`): `draft | review | verified | published | deprecated | archived`

**Claim badge** (presentation / RAG): `verified | common_usage | regional | uncertain | ai_suggestion`

AI-generated text may be stored as `draft` + `claim_level = ai_suggestion`. It **never** automatically becomes lifecycle `verified` or `published`.

**Product rule:** The model/UI copy must never say “verified” unless retrieved/editorial claim level is `verified`.

App translator/chat badges (no raw DB ids for normal users):

| Badge | Meaning |
|---|---|
| Verified | Retrieved from knowledge whose claim/lifecycle supports verified |
| Common usage | Widely heard; not treated as fully standardized |
| Regional | Explicit regional_scope / region row |
| Uncertain | RAG miss, conflict, or low confidence |
| AI suggestion | Model-produced or unverified generation |

Badges appear in the authenticated app and, if a public teaser uses AI, on that teaser too.

**AI output is not auto-inserted into `darija_terms` as published.** Import is a human action.

---

## 5. Dictionary page contract (`/dictionary/safi`)

Visible structure (semantic HTML):

1. Breadcrumb: Home › Dictionary › Safi
2. `h1` with Latin + Arabic
3. Natural meaning
4. Pronunciation
5. Tone / formality
6. Literal vs natural meaning
7. Usage / when (not) to use if present
8. Examples
9. Regional notes
10. Cultural explanation
11. Related terms
12. Related phrases
13. Related guides
14. FAQ (only real Qs)
15. Last reviewed + provenance (source as appropriate; not internal notes)

This content is **useful**. If we cannot write a real page, we do not publish the slug.

---

## 6. Phrase page contract

Intent-first titles (`Thank you in Darija`) with the Darija forms in the lead.

Must include at least one example and a when-not-to-use note for informal/rude-adjacent phrases.

---

## 7. Guides

Guides are **sectioned** (`guide_sections` with anchors). Good v1 topics:

- Darija pronunciation
- Moroccan etiquette and address forms
- Taxi / café / family visit situations
- Slang vs polite speech
- Latin chat script (3, 7, 9) explained carefully

Each guide links out to real term/phrase pages rather than duplicating full entries (snippet + link).

---

## 8. Culture, travel, learn

- **Culture:** not tourism brochure filler; explain language-relevant social meaning (hospitality, bargaining tone, gender/age address—handled with care and humility).
- **Travel:** situation packs that deep-link phrases.
- **Learn:** ordered paths (greetings → survival → nuance). Diaspora: “what your parents say vs MSA.”

Avoid stereotyping. Prefer “often / in many cities / some speakers” over absolutes.

---

## 9. Blog

Blog is optional in Phase 3. If used: original reporting, interviews, methodology (“how we verify”), not 200 “Top 50 Darija words” spun lists.

`noindex` experimental posts if thin.

---

## 10. Internal linking engine

Every **published knowledge page** must have:

1. **Parent hub** (e.g. `/dictionary` for a term)
2. **Related content** (graph: `entity_links`, `phrase_terms`, `term_relations`)
3. **Contextual internal links** in copy only when semantically relevant
4. **Breadcrumbs** (visible)

`LinkingService` builds related modules from:

1. Explicit `entity_links` (editor) — preferred
2. `phrase_terms` (phrase contains term)
3. `term_relations`
4. Shared `usage_contexts` or categories (capped, relevance-ranked)

**Do not** auto-link every occurrence of a word on the page. Suggested links can appear in admin; the public HTML stays sparse enough to remain useful (caps in SEO doc).

**Anti-orphan:** SeoAuditService ERROR or WARNING if a knowledge URL has no hub inbound. Publish checklist: hub, related, breadcrumbs, unique title, provenance for Darija entities.

---

## 11. Multilingual content

Explanatory copy is translated; Darija strings are **shared** via the same term/phrase ids.

`translation_group_id` on guides/articles/pages. Dictionary: one term row; `seo_metadata` and cultural_notes per `locale`.

Do not duplicate term rows per language.

---

## 12. Voice and editorial standard

- Prefer native examples over textbook MSA calques.
- Show Latin **and** Arabic when possible (diaspora + learners).
- Mark Casablanca vs northern vs eastern when we actually know.
- Do not mock speakers or reduce Darija to “broken Arabic.”
- French/English loanwords in Darija are valid content, explained as such.

---

## 13. Provenance and sources

Public and RAG knowledge must retain:

`source_type`, `source_reference`, `source_language`, `reviewer_id`, `reviewed_at`, `confidence_level`, `regional_scope`, `verification_method`, `verification_notes`.

`source_type` examples: editorial_review, native_speaker, cited_work, fieldwork, user_submission. User submissions never publish automatically.

Public pages may show a short “Reviewed” date and a human-readable source; internal notes stay in admin.

---

## 14. Content versioning and revert

Append-only `content_revisions` for:

`darija_terms`, `darija_phrases`, `cultural_notes`, `guides`, `articles`, `pages`, `seo_metadata`.

Each save by an editor inserts a revision: who, when, snapshot, short what/why. **Revert** copies an old snapshot into the live row and appends a new revision (`change_reason = revert to revision N`). No in-place mutation of old revision rows. Not a branched CMS.

---

## 15. Kids content (`/app/kids`)

Not a public SEO mill. Authenticated, age-appropriate subset, no slang/rude tones. Filter `usage_contexts` exclude adult/rude. Public site may later have `/learn/kids` with a **small** verified set—only if quality is real.

---

## 16. Anti-spam rules

Forbidden:

- Mass LLM page generation for ranking
- Doorway pages per misspelling (use 301 aliases instead)
- Keyword-only pages without examples/context
- Duplicate gloss lists across 50 URLs

Allowed:

- High-quality cluster: one term, a few phrases, one guide that binds them

---

## 17. IA diagram

```text
Home
 ├─ /darija ──────────────────────────────┐
 ├─ /dictionary ── term ── related phrases─┤
 ├─ /phrases ──── phrase ─ related terms ──┤── /guides
 ├─ /culture                               │
 ├─ /travel ──── situation ── phrases      │
 ├─ /learn ──── path ── terms + phrases    │
 ├─ /blog (optional)                       │
 ├─ /darija-translator (teaser) → /app
 └─ /about  /pricing
```
