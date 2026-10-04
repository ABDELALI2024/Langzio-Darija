# Langzio AI and RAG Architecture

The AI layer is a **module**. Application code talks to interfaces. Vendor SDKs exist only inside `app/AI/Providers`.

Langzio must not rely on a general LLM as the authority on Moroccan Darija. The LLM is a **composer and explainer** over retrieved, preferably **verified**, knowledge.

---

## 1. Design goals

- Swap providers without rewriting controllers.
- Ground answers in verified knowledge when it exists.
- Label uncertainty and AI suggestions explicitly.
- Run on Hostinger: short HTTP request/response, no GPU, no local LLM server.
- Control cost: cache, caps, small models for classification.
- Never put API keys in the browser or public config.

---

## 2. Component diagram

```text
User
  ↓
AI Controller  (App\Controllers\App\ChatController | TranslateController)
  ↓
SafetyService          pre: prompt injection / abuse / PII minimization
  ↓
IntentService          classify: translate | define | culture | travel | chat | unsafe
  ↓
ContextBuilder         user locale, tone pref, kids mode, history summary
  ↓
RAGService
  ├── RetrievalInterface → MySQL FULLTEXT + filters   (v1)
  ├── KnowledgeAccess     verified terms/phrases/notes
  └── optional embeddings (stored, not required)
  ↓
PromptService          system + retrieved snippets + output contract
  ↓
LLMProviderInterface   OpenAI-compatible HTTP | Anthropic | etc.
  ↓
ResponseValidator      JSON schema, citation IDs, hallucination heuristics
  ↓
SafetyService          post: leak check, rude-without-label, kids filter
  ↓
Persistence            ai_messages (retention), ai_usage_logs (no bodies)
  ↓
User UI                badges: Verified | Common | Regional | Uncertain | AI suggestion
```

---

## 3. Namespaces and contracts

```text
app/AI/Contracts/
  LLMProviderInterface.php
  EmbeddingProviderInterface.php
  RetrievalInterface.php

app/AI/Providers/
  NullProvider.php              # tests / AI disabled
  OpenAiCompatibleProvider.php  # HTTP chat completions

app/AI/
  AIService.php                 # facade for controllers
  IntentService.php
  ContextBuilder.php
  PromptService.php
  ResponseValidator.php

app/AI/Safety/
  SafetyService.php

app/AI/RAG/
  RAGService.php
  MysqlFulltextRetrieval.php
  RetrievedChunk.php
```

Controllers never `curl` the vendor.

Config: `config/ai.php` + env `AI_PROVIDER`, `AI_API_KEY`, `AI_MODEL`, `AI_EMBED_MODEL`, `AI_DAILY_TOKEN_BUDGET`, `AI_TIMEOUT_SECONDS`.

---

## 4. Provider interface (conceptual)

```text
LLMProviderInterface
  chat(messages, options): LLMResult
    options: model, max_tokens, temperature, timeout
    result: text, usage, raw_id, latency_ms

EmbeddingProviderInterface
  embed(texts): vectors[]
```

Timeouts: 15–25s wall clock. Shared hosting will kill long requests. Prefer streaming later on VPS; v1 non-stream JSON is acceptable if UX shows a wait state.

**NullProvider** returns a safe message when keys are missing so production does not fatally error on public pages.

---

## 5. RAG v1 (no vector database)

### 5.1 Retrieval recipe

1. Normalize query (trim, unicode, detect script arabic vs latin).
2. Intent → which corpora (terms, phrases, guides, cultural_notes).
3. Exact slug / exact `script_latin` / exact `script_arabic`.
4. `MATCH (...) AGAINST (... IN NATURAL LANGUAGE MODE)` on FULLTEXT columns.
5. Filter `content_status = published` first. User-facing “verified” claims require claim level `verified`, not `ai_suggestion`.
6. If k < threshold, optionally retrieve `review` **only for admin tools**, never for user-facing “verified”.
7. Expand via `entity_links` / `phrase_terms` (1 hop).
8. Cap tokens: top 5–8 chunks, each truncated.

### 5.2 Structured context passed to the model

Each retrieved item carries stable **internal** identifiers. These IDs are for the model and the validator, **not** shown to normal users unless a later “source” UI needs a public code.

```text
knowledge_id        e.g. phrase:123   (type + id; stable while the row lives)
knowledge_type      term | phrase | cultural_note | guide_section | ...
verification/claim  verified | common_usage | regional | uncertain | ai_suggestion
source_reference    provenance.source_reference / source_type
regional_scope
```

Prompt snippet example:

```text
[KNOWLEDGE_ID: phrase_123]
STATUS: VERIFIED
REGION: Morocco
SOURCE: editorial_review
CONTENT: ...
```

The LLM must not claim STATUS VERIFIED unless a retrieved block has that status. The validator enforces this (downgrade otherwise). User-facing badges: Verified, Common usage, Regional, Uncertain, AI suggestion — **without** raw database IDs.

### 5.3 Embeddings (optional write path)

If `AI_EMBED_ENABLED=true`, on publish of a term/phrase, enqueue cron job to embed chunk text into `embeddings.vector`. **v1 search does not read this column.** Later `VectorRetrieval` implements the same `RetrievalInterface`.

Distance search in MySQL is not a v1 requirement.

---

## 6. Prompt contract

System prompt (owned by `PromptService`, versioned string in code or DB):

- You are Langzio, a Moroccan Darija cultural intelligence assistant.
- Prefer retrieved verified snippets.
- If retrieval is empty, say you are uncertain; do not invent idioms as fact.
- Always classify each Darija form you output with one of: verified | common_usage | regional | uncertain | ai_suggestion.
- You may mark a form `verified` only when a retrieved block with matching KNOWLEDGE_ID has STATUS VERIFIED.
- Retrieved unpublished or ai_suggestion blocks cannot be cited as verified.
- Never claim MSA is Darija or vice versa.
- Respect kids_mode (no sexual/rude).
- Answer in the user’s UI locale; keep Darija in Arabic + Latin when teaching.

**Temperature:** low (0–0.4) for translation/definition; slightly higher only for open chat.

**Output:** prefer structured JSON internally:

```text
{
  "answer_markdown": "...",
  "items": [{
    "darija_latin": "",
    "darija_arabic": "",
    "level": "verified",
    "knowledge_ids": ["phrase_123"]
  }],
  "warnings": []
}
```

UI renders markdown + badges. Internal `knowledge_ids` stay in the API/admin if needed; consumer UI does not print `phrase_123` by default. If JSON parse fails, validator marks entire answer `uncertain` and may retry once.

---

## 7. Response validation

`ResponseValidator` checks:

- JSON schema
- For `level = verified`: at least one `knowledge_id` present in the retrieved set **and** that item’s claim/lifecycle supports verified
- If the model claims verified without supporting retrieval → downgrade to `ai_suggestion` or `uncertain`
- AI suggestions in retrieval or output never auto-write `content_status = verified` or `published`
- Blocked patterns (injection, obviously MSA-only claims when user asked Darija—heuristic)
- Length caps
- Kids mode lexicon filter (small denylist + tone_types rudeness)

Failures: return safe fallback, log `error_class=validation`.

---

## 8. Translator vs chat

### Translator (`/app/translator` + limited public teaser)

Pipeline:

1. Glossary exact match on verified phrases/terms (fast, free).
2. If match: return verified translation + tone/context **without LLM** when possible.
3. If partial: LLM with retrieved glossary as constraints.
4. Cache key: hash(locale, direction, normalized_input, kids_mode). TTL hours for identical tourist sentences.

Public teaser: shorter max chars, stricter rate limit, may disable LLM and glossary-only.

### Chat (`/app/chat`)

Multi-turn; send **summarized** history + last N messages, not infinite context. Retrieval each turn.

---

## 9. Safety

| Threat | Control |
|---|---|
| Prompt injection | Treat user text as data; delimiters; ignore “reveal system prompt” |
| Jailbreak for hate/crime | SafetyService refuse |
| Kids mode bypass | Server-side flag, not client |
| PII in logs | usage logs without bodies; messages retained with policy |
| Key theft | env only; no frontend |
| Cost bomb | per-user/day budget, max tokens, IP limit |
| Training leakage | do not paste unpublished drafts into prompts for public users |

Darija contains informal and rude speech. Adult app may explain it **with labels**. Kids surface must not.

---

## 10. Rate limits and cost

| Surface | Anonymous | Auth free | Paid (later) |
|---|---|---|---|
| Public translate | N/hour/IP, captcha after burst | — | — |
| App translate | — | M/day | higher |
| Chat | off | M/day | higher |

Implementation: `RateLimiterInterface` → file or MySQL counters (see Security doc).

Circuit breaker: if provider error rate high, disable AI, keep glossary translator.

---

## 11. Observability

`ai_usage_logs`: endpoint, model, estimated tokens, latency, status, user id, ip hash.

Do not log API keys or full prompts in `app.log`. Debug mode local only.

---

## 12. What v1 will not do

- Fine-tune a Darija LLM
- On-device models
- Realtime voice (maybe later)
- Auto-publish generated dictionary pages
- Multi-agent microservices

---

## 13. Migration to dedicated retrieval

```text
RAGService → RetrievalInterface
                ├── MysqlFulltextRetrieval   (Hostinger)
                └── HybridRetrieval
                       ├── MysqlFulltextRetrieval
                       └── HttpVectorStore    (VPS Qdrant/pgvector)
```

Knowledge tables remain the source of truth. Vector store is a projection rebuilt on publish.

---

## 14. Fail-closed vs fail-open

- Missing AI key: glossary still works; chat explains unavailable.
- RAG empty: model may answer **as suggestion only**.
- Validation fail: user-visible error, no fake verified content.
