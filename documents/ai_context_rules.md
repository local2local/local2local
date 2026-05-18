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
- Commit message contains `[skip ci]` — used by auto-version bump commits and archive revert commits
- Commit message starts with `Merge branch` — merge commits are never deployed
- Actor is `github-actions[bot]`

Never remove these filters from `deploy.yml`.

---

## CI/CD: HITL gate decisions

**Rule:** The HITL gate has three options. Each must be used for its intended purpose:

- **PROMOTE TO PROD** — ship the entire dev stack to production. All commits on `develop` since the last promotion go to `main`.
- **SAVE IN DEV STACK** — keep the change on `develop` for inclusion in a future promotion. Recorded in `deferred_phases`, not `abandoned_phases`.
- **ARCHIVE CHANGES** — remove the change from `develop` and preserve it in a branch `archive/{phase_version}`. The revert commit on `develop` must use `[skip ci]` to prevent a pipeline cascade. To recover: cherry-pick from the archive branch.

The archive revert commit format is: `[AUTO] CHORE(archive): Revert {phase_version} — archived [skip ci]`

---

## Assisted Method: Payload Generation

**Rule:** Always instruct Gemini to generate the logic payload into a
file named `logic_payload.js` (not as plain text output). Copy from
the Gemini code canvas to `scripts/logic_payload.txt` in Cursor.

**Why:** Both Gemini and Cursor canvases normalize line endings to CRLF
when handling plain text. A .js extension forces both to treat the
content as source code and preserve LF line endings, which patcher.js
requires.

---

## n8n: NEVER replace the orchestrator

**Context:** Any change to `n8n_workflows/l2laaf_autonomous_orchestrator.develop.json` or `l2laaf_autonomous_orchestrator.main.json`

**Rule:** Never replace either orchestrator with a new workflow. The DEV and PROD orchestrators are the product of 43+ phases of accumulated pipeline logic including the HITL gate, version bumping, Firestore tracking, and the promotion flow. Replacing them destroys all of this.

**Always add nodes additively.** New features are inserted at a specific point in the existing flow. Existing nodes are never removed or replaced.

**Always request the current orchestrator JSON before making changes.** Ask the developer to provide the current file. Never generate an orchestrator workflow from scratch.

The correct insertion point for Phase 45 consensus nodes is between `Throttle Switch` PROCEED/DELAYED outputs and `Google Chat Card`. The BLOCKED path goes directly to `Blocked Chat Card` and must not be touched.

---

## n8n: HTTP Request body — use Code node + Raw body

**Context:** n8n HTTP Request node where the body contains dynamic content

**Rule:** Never build a JSON body inline in the `jsonBody` expression field of an HTTP Request node. When an expression returns a JavaScript object, n8n serialises it inconsistently — it may send `[object Object]` instead of valid JSON, causing silent failures.

**Correct pattern:**
1. Add a Code node immediately before the HTTP Request node
2. In the Code node, use `JSON.stringify()` to build the request body as a string and store it in `$json`:

```javascript
return {
  json: {
    ...$json,
    requestBody: JSON.stringify({
      contents: [{ parts: [{ text: 'your prompt here' }] }]
    })
  }
};
```

3. In the HTTP Request node, set Body Content Type to `Raw`, Content Type to `application/json`, and Body to `{{ $json.requestBody }}` using expression mode (click the expression toggle — do not type `=` literally into the field)

`JSON.stringify` is standard JavaScript — not a Node.js global — and is valid inside Code nodes.

---

## n8n: Expression mode toggle vs literal `=`

**Context:** n8n Raw body field, or any field that supports Fixed/Expression toggle

**Rule:** In n8n fields that support expression mode, the `=` prefix is a UI toggle indicator — it is not part of the value. To set a field to expression mode, click the expression toggle button (the `=` or fx icon at the right edge of the input). Then type only `{{ $json.fieldName }}` inside. If you type `={{ $json.fieldName }}` with a literal `=` in the field, n8n includes the `=` in the body and the upstream service receives `={"key":"value"}` which is not valid JSON.

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

---

## n8n: GitHub node branch targeting

**Rule:** For n8n GitHub node typeVersion 1:
- The `get` operation uses the `reference` parameter to specify branch
- The `edit` operation uses `options.branch` to specify branch
- Never leave either field unset when the target branch is not the repo default

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

## n8n: Code node mode and return format

**Rule:** n8n Code nodes have two modes with different return formats:

- **Run Once for All Items:** use `$input.all()` to access items. Return an array: `return [{ json: {...} }]`
- **Run Once for Each Item:** use `$json` to access the current item. Return a plain object: `return { json: {...} }`

`$json` is only available in "Run Once for Each Item" mode. Using it in "Run Once for All Items" mode causes a lint error. Choose the mode before writing the code.

---

## relay.sh: Targeted n8n workflow cleanup (v6.4)

**Current version:** relay.sh v6.4

**Rule:** relay.sh v6.4 only deletes n8n workflow files that are explicitly listed in the payload. It no longer purges all `n8n_workflows/*.json` files. This means:

- A payload containing only `develop.json` will NOT delete `main.json`
- A payload containing both will delete and replace both
- No workaround or "remember to include main.json" rule is needed

Do not revert to v6.3 or earlier — the blunt `rm -f n8n_workflows/*.json` in earlier versions caused `main.json` to be silently deleted.

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

---

## HBR: Regulatory file versioning

**Context:** Any change to files in `functions/src/logic/hbr/`

**Rule:** Regulatory HBR files use bitemporal versioning. Every `rules.json` file carries `hbr_version`, `valid_from`, and `status` fields. When updating a regulatory HBR file:

1. **Never overwrite a `rules.json` without archiving the current version first.** The current version must be written to Firestore at `artifacts/system_status/public/data/hbr_versions/{versionId}` with `status: SUPERSEDED` and `valid_until` set before the new version is committed.
2. **Always set `valid_from` to the regulatory effective date, not the commit date.** If AGLC publishes new markup rates effective April 1, `valid_from` is `2026-04-01T00:00:00Z` regardless of when the code is deployed.
3. **Future-dated rules are `SCHEDULED`, not `ACTIVE`.** If a regulator announces a change that takes effect in the future, create the new version with `status: SCHEDULED`. Do not modify the current `ACTIVE` version. The daily activation cron promotes `SCHEDULED` → `ACTIVE` when `valid_from` arrives.
4. **Increment `hbr_version` on every change.** Use semantic versioning: PATCH for rate/value changes, MINOR for new rules added, MAJOR for structural changes or new regulatory categories.

---

## HBR: Regulatory rules.json field requirements

**Rule:** Every `rules.json` in `functions/src/logic/hbr/` must include these top-level fields:

- `rule_maker` — uppercase abbreviation of the regulatory body (e.g. `AGLC`, `CRA`, `IILA`)
- `region_scope` — geographic scope (`ca` = national, `ca_ab` = Alberta)
- `category` — rule category (e.g. `alcohol`, `tax`)
- `hbr_version` — current version string (e.g. `1.0`)
- `valid_from` — ISO 8601 datetime when this version takes regulatory effect
- `status` — one of `ACTIVE`, `SCHEDULED`, `SUPERSEDED`, `REVOKED`, `AMENDED`
- `last_verified` — date the rules were last verified against the regulatory source
- `rules` — object containing typed rule entries

Every rule entry in the `rules` object must include `description`, `value`, and `type`. Source references (`statute_ref`, `handbook_ref`, `source`, or `policy_ref`) are strongly recommended.
