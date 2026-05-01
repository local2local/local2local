# AI CONTEXT RULES

This document contains hard-won rules that AI assistants must follow when working on the L2LAAF codebase. Always provide this document at the start of any AI session.

---

## CI/CD: Commit message format

**Context:** Any commit pushed through the CI/CD pipeline

**Rule:** Use this exact format:
```
[SOURCE] TYPE(scope): Description [BUMP: MAJOR|MINOR|PATCH]
```

- `[SOURCE]` — one of `MANUAL`, `ASSISTED`, `AUTO`, `DREAM` (uppercase, in brackets)
- `TYPE` — uppercase: `FIX`, `FEAT`, `CHORE`, `REFACTOR`, etc.
- `scope` — single lowercase word
- `Description` — title case
- `[BUMP: TYPE]` — optional, defaults to PATCH if omitted, case insensitive
- **Never prefix a version number** — the pipeline adds it automatically
- The entire message must be a single line (required for Dreamflow compatibility)

**Examples:**
```
[MANUAL] FIX(pipeline): Skip deployments triggered by merge commits
[ASSISTED] FEAT(marketplace): Add seller onboarding flow BUMP: MINOR
[AUTO] CHORE(orchestration): Promote phase 43.1.54 to prod
[DREAM] FEAT(triage): Add abandoned phases list to SuperAdmin dashboard
```

---

## CI/CD: Version source of truth

**Rule:** `pubspec.yaml` is the **only** source of truth for the version number. `state.json` does not hold a version. Never read or write `current_phase` to `state.json`.

---

## CI/CD: Git pull discipline

**Rule:** Always use `git pull --rebase origin develop`, never `git pull origin develop`. A plain `git pull` creates a merge commit that triggers a spurious pipeline run with `UNKNOWN` as the originator.

---

## CI/CD: Pipeline loop prevention

The pipeline skips runs when:
- Commit message contains `[skip ci]` — used by auto-version bump commits
- Commit message starts with `Merge branch` — merge commits are never deployed
- Actor is `github-actions[bot]`

Never remove these filters from `deploy.yml`.

---

## n8n: HTTP Request URL fields — no string concatenation

**Context:** n8n HTTP Request node (any typeVersion)

**Rule:** The `url` parameter must always be a complete, literal URL string. Never split `https://` from the rest of the URL using string concatenation.

**Why:** n8n validates the `url` field statically before evaluating expressions. A concatenated string is not a valid URL at parse time and will throw a `NodeOperationError` at runtime.

```json
// Allowed — static URL:
"url": "https://chat.googleapis.com/v1/spaces/SPACE_ID/messages?key=KEY&token=TOKEN"

// Allowed — fully dynamic URL:
"url": "={{ \"https://firestore.googleapis.com/v1/projects/\" + $json.projectId + \"/databases/...\" }}"

// Never allowed:
"url": "=\"https://\" + \"chat.googleapis.com/v1/spaces/...\""
```

Only use the `=` expression prefix when at least one segment is genuinely dynamic. If the entire URL is static, use a plain string with no `=` prefix.

---

## n8n: GitHub node branch targeting

**Rule:** For n8n GitHub node typeVersion 1:
- The `get` operation uses the `reference` parameter to specify branch
- The `edit` operation uses `options.branch` to specify branch
- Never leave either field unset when the target branch is not the repo default

A missing branch is a silent bug — n8n will not warn you; it will just default to `main` and 404 on any file that only exists on `develop`.

---

## n8n: No Node.js globals in expression fields

**Rule:** Never use `Buffer`, `require()`, `process`, or any other Node.js globals inside n8n expression fields (`={{ }}`). These are only valid inside Code nodes.

If base64 encoding, JSON stringification, or any Node.js operation is needed to prepare an HTTP request body, do it in a preceding Code node first, store the result as a plain field in `$json`, then reference it in the HTTP node.

---

## n8n: If node vs Switch node

**Rule:**
1. Never use Switch nodes for binary (two-output) routing decisions. Always use an If node. Switch nodes are for 3+ output routing only.
2. Never reference `$json.execution.error.node.name` in Error Alert expressions. Code node errors do not populate a node sub-object. Always use `$json.execution.lastNodeExecuted` for the failing node name.

---

## n8n: If node typeVersion 2 conditions

**Rule:** n8n If node typeVersion 2 conditions always require:
- `"combinator": "and"` at the conditions root level
- A unique `"id"` string on every condition object
- A `"name"` field on every operator object
- `"typeValidation": "loose"` when comparing expression values to string literals

Guard clauses in Code nodes must use `return []` not `throw` when the intent is to silently stop a leaked item. Only use `throw` when you genuinely want the Error Trigger to fire.

---

## TypeScript: Cloud Functions

- Every `Change` must use `<QueryDocumentSnapshot>`
- Every `params` argument must be `Record<string, string>`
- Target Node.js 24 (2nd Gen Functions) strictly
- Local imports use `package:local2local/...` (not `local2local_app`)

---

## Firestore: Field naming

- All Firestore field names use `snake_case`
- Dart model fields use `camelCase` and map to `snake_case` in `toFirestore`

---

## Code delivery: Full file content only

**Rule:** Every code block must contain the full, entire file content. Never use `// ... rest of code` or any other abbreviation. This applies to all methods — Manual, Assisted, Autonomous, and Dreamflow.

---

## Firestore: Test data format

Provide test data as a full path with no spaces and a JSON object:

```
PATH: artifacts/local2local-kaskflow/public/data/agent_bus/test_msg_001
JSON: { "status": "dispatched", "provenance": { "receiver_id": "EVOLUTION_WORKER" } }
```
