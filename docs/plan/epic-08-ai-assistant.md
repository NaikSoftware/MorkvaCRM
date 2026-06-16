# Epic 8 — Global AI Assistant ("Ask Morkva")

> **Status: planned, not yet scheduled.** This is a design/scope document only — no
> implementation. It depends on the data + repository layer (Epic 2) and is richer once views
> (Epic 4) and calculated/aggregation fields (Epic 6) exist.

## Goal
A global AI chat, reachable from anywhere in the app, where the user asks anything about their
workspace in plain language and the assistant **answers**, **analyzes**, and — with explicit
confirmation — **does work** on their collections and cards.

## Why
MorkvaCRM's data is deliberately generic (collections of typed cards). That power is also a
barrier: a small-business owner has to know how to model and query it. A natural-language
assistant collapses that barrier — "how many orders are unpaid?", "revenue by month",
"create a Suppliers collection", "mark these three as shipped" — and turns the engine into
something a non-technical owner can drive by talking. It is the clearest differentiator over the
Trello setup the product replaces.

## The three things the user asked for
1. **Ask** — answer questions grounded in the user's own collections/cards (no hallucinated data).
2. **Analyze** — compute and present read-only insight (counts, aggregations, trends, simple
   tables/charts).
3. **Act** — perform changes (create/update/delete collections, fields, cards; bulk edits;
   create views) **through a preview + confirm gate**, never silently.

## In scope (for the eventual epic)
- **Chat UI**: a global entry point (a "Ask Morkva" command/FAB) opening a conversation panel —
  side sheet on web/wide, full screen on mobile. Streamed responses. (`/design`.)
- **Claude integration via a backend proxy.** The Anthropic API key is **never** in the client.
  Calls route through a Firebase callable/Cloud Function that holds the key and proxies
  streaming. (Provider/model details: consult the `/claude-api` skill at implementation time;
  current candidates — Sonnet 4.6 as the default for speed/cost + tool use, Opus 4.8 for hard
  analysis, Haiku 4.5 for cheap routing/classification.)
- **Tool-use bound to the repository interface.** The assistant is given a tool schema that maps
  onto the **same repository the app uses** (Epic 2): read tools (`listCollections`,
  `queryObjects(filter/sort/group)`, `aggregate`) and write tools (`createCollection`,
  `createObject`, `updateObject`, `deleteObject`, `createView`). All mutations flow through the
  repository, so Epic 1 validation and Epic 2 sync/conflict handling apply and the model can
  never bypass rules or touch raw storage.
- **Grounding.** Provide the model a compact **schema digest** (collections + field definitions
  + row counts) as cached context; fetch specific data via the query tool rather than dumping
  the whole workspace. Start **without embeddings/vector DB** — the workspace JSON is small;
  add retrieval only if real workspaces outgrow direct querying.
- **Action safety gate.** For any write, the model proposes a plan/diff; the UI renders a preview
  ("I'll create collection *Suppliers* with fields …, and add 3 cards"); the user confirms before
  any tool executes. Destructive operations always require confirm; read/analyze tools run freely.
- **Analysis rendering**: summaries, simple tables, and basic charts embedded in the chat
  (reuse Epic 4 view rendering / Epic 6 aggregation where possible).
- **Conversation state**: per-workspace history, persisted and clearable; a `ChatBloc`/cubit owns
  streaming, the tool-call lifecycle, and the confirmation state.
- **Guardrails**: per-user token/usage budgets, model tiering, rate limiting, and a feature flag
  (ties into the Firebase admin/feature-flags future epic).

## Out of scope
- Autonomous/unattended agents that act without confirmation; long-running background jobs.
- Fine-tuning, custom models, or a vector database (revisit only if direct querying proves
  insufficient).
- Voice input/output.
- JS-module-marketplace integration (separate future epic).

## Key concepts
- **The assistant acts through repository tools, never raw storage** — the same boundary
  principle as Epic 2's data layer. This is what makes AI actions safe and testable.
- **Read tools are free; write tools are gated** behind an explicit user confirmation with a
  visible preview/diff.
- **Key-bearing calls live server-side** (Firebase function), never in the Flutter client.

## Deliverables (when built)
- A `ChatBloc` + chat UI (global entry, streamed conversation, tool-step + analysis rendering).
- A Firebase callable/function proxying Claude with the server-held key (streaming).
- A repository-bound tool schema (read + write tools) with a confirm-before-write executor.
- A schema-digest grounding layer with prompt caching.
- Conversation persistence per workspace + usage guardrails + feature flag.
- Tests: tool executor against a faked repository (incl. the confirm gate blocking unconfirmed
  writes), bloc tests for the streaming/tool/confirm lifecycle, and grounding-digest tests.

## Acceptance criteria
- The user can open the assistant from anywhere, ask a question, and get an answer grounded in
  their real data (verifiable against the workspace).
- The assistant can run an analysis (e.g. "unpaid orders this month") and present the result.
- A requested change shows a preview and only writes after the user confirms; declining writes
  nothing; confirmed writes go through the repository (validated, synced).
- The Anthropic key is never present in client code or network traffic from the client.
- The feature can be disabled per user via a flag.

## Dependencies & design notes
- **Hard:** Epic 2 (repository interface + auth + a backend/Cloud Function surface).
- **Soft (makes it much better):** Epic 4 (view rendering for analysis output) and Epic 6
  (calculated/aggregation fields for richer analysis).
- **Use `/design`** for the chat surface — it is a flagship, trust-sensitive interface.
- **Use `/claude-api`** at implementation time for current model IDs, tool-use schema, streaming,
  and prompt-caching specifics — do not hardcode from memory.

## Open decisions (resolve at scheduling time)
- Confirm provider/model tiering (recommended: Claude — Sonnet 4.6 default, Opus 4.8 for heavy
  analysis, Haiku 4.5 for routing).
- Backend host for the proxy (recommended: Firebase Cloud Functions, same project as Auth/Storage).
- How much data to include in context vs. fetch via tools (privacy + cost trade-off).
- Whether to add embeddings/retrieval (default: no, until workspace size demands it).
