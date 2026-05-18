# CI/CD Pipeline Reference

**Version:** 45.1.x
**Last updated:** 2026-05-14
**Source of truth:** `.github/workflows/deploy.yml`, `n8n_workflows/`

---

## Overview

The L2LAAF CI/CD pipeline is a fully automated deploy-to-dev, human-approve, promote-to-prod system. Every change to the `develop` branch is automatically built, versioned, and deployed to the dev environment. A Human-in-the-Loop (HITL) gate in Google Chat then gives the operator the option to promote the change to production or keep it in dev.

```
Developer pushes to develop
    → GitHub Actions: Build → Deploy to dev → Notify n8n
    → n8n: Evaluate system status → Classify impact → Post HITL card to Google Chat
    → Operator: PROMOTE TO PROD or KEEP IN DEV
        → PROMOTE: Force-update main → Promotion commit → Deploy to prod → Record in Firestore
        → KEEP IN DEV: Record abandoned phase in Firestore
```

---

## Versioning

The version number follows semantic versioning: `MAJOR.MINOR.PATCH`.

| Segment | Meaning | Controlled by |
|---|---|---|
| `MAJOR` | Development phase (currently 45) | Developer — append `BUMP: MAJOR` to commit |
| `MINOR` | Feature group within the phase | Developer — append `BUMP: MINOR` to commit |
| `PATCH` | Individual change | Pipeline — default, no tag needed |

**`pubspec.yaml` is the single source of truth for the version.** `state.json` does not hold a version number. Version bumps only happen on `PROMOTE TO PROD` — pushing to `develop` does not bump the version.

---

## Commit Message Format

All commits follow this format:

```
[SOURCE] TYPE(scope): Description [BUMP: MAJOR|MINOR|PATCH]
```

| Token | Values | Who provides it |
|---|---|---|
| `[SOURCE]` | `MANUAL`, `ASSISTED`, `AUTO`, `DREAM` | Developer or system |
| `TYPE` | `FIX`, `FEAT`, `CHORE`, etc. — uppercase | Developer or system |
| `scope` | Single lowercase word | Developer or system |
| `Description` | Title case free text | Developer or system |
| `[BUMP: TYPE]` | Optional. Omit for PATCH (default) | Developer only |

**Never prefix a version number** — the pipeline adds it automatically. The `BUMP:` tag is stripped from the commit message before the final versioned message is built.

---

## Pipeline Skip Rules

The deploy job is skipped when:

- The commit message contains `[skip ci]` — used by auto-version bump commits and archive revert commits
- The commit message starts with `Merge branch` — merge commits are never deployed
- The actor is `github-actions[bot]`

Never remove these filters from `deploy.yml`.

---

## Environments

| Branch | Environment | GCP Project | Firebase Project |
|---|---|---|---|
| `develop` | Development | `local2local-dev` | local2local-dev |
| `main` | Production | `local2local-prod` | local2local-prod |

There is no staging environment. The HITL gate serves as the validation layer.

---

## Pipeline Steps (develop branch)

### 1. Install Firebase CLI & Dependencies
Installs Firebase CLI, Cloud Functions npm dependencies, and Flutter packages.

### 2. Build Flutter Web
Runs `flutter build web --release`.

### 3. Authenticate to Google Cloud
Uses the `GCP_SA_KEY` GitHub secret.

### 4. Deploy Stack
Runs `firebase deploy --only hosting,functions` to `local2local-dev`.

### 5. Deploy n8n Workflow
Uploads `n8n_workflows/l2laaf_autonomous_orchestrator.develop.json` to the DEV n8n workflow via the n8n API. Deactivates and reactivates the workflow to force webhook re-registration on Cloudflare's edge network.

### 6. Notify Orchestrator
Probes the DEV webhook until it responds (up to 60s), then fires the deployment payload:
```json
{
  "incoming_phase": "45.1.3",
  "build_id": "<commit SHA>",
  "summary": "45.1.3 - [MANUAL] FIX(orchestrator): Description",
  "event": "DEPLOYMENT_COMPLETE",
  "env": "dev",
  "method": "MANUAL",
  "bump_type": "PATCH"
}
```
This step is skipped on `main`.

---

## The HITL Gate

After a successful `develop` deployment, the DEV n8n orchestrator (`L2LAAF: Autonomous Orchestrator - DEV`, workflow ID `ThWtTTPTR4ymYD6a`) posts a deployment card to the `L2LAAF-Orchestrator` Google Chat space.

### Phase 45 orchestrator flow (current)

```
MCP Code Payload → Fetch Main State → State Manager → Fetch System Status
    → Throttling Evaluator → Throttle Switch
        PROCEED → Impact Classifier → Extract Impact → Impact Switch
        DELAYED → Throttle Wait → Impact Classifier (same path)
        BLOCKED → Blocked Chat Card

Impact Switch
    HIGH_IMPACT → Prepare Validator Prompt → Validator Agent → Extract Critique → Google Chat Card
    ROUTINE → Google Chat Card
```

### Deployment Card Fields

| Field | Source |
|---|---|
| Phase | `incoming_phase` from webhook payload |
| Originator | `method` from webhook payload |
| Status | Firestore telemetry (GREEN/YELLOW/RED) |
| Intent | Derived from `TYPE` in commit message |
| Build Details | Full versioned commit message |
| Throttle Evaluation | Output of Throttling Evaluator node |
| Impact Assessment | `impact_level` + optional `validator_critique` from Phase 45 consensus nodes |
| Dev Stack | List of commits on `develop` since the last promotion (commit SHA, message, originator) — shown only when stack depth > 1 |

### Three-Option HITL Decision

The deployment card presents three buttons. Each captures explicit operator intent.

#### PROMOTE TO PROD

Promotes the **entire dev stack** (all commits on `develop` since the last promotion) to production. The card lists all stacked commits so the operator sees everything that will ship — not just the latest commit.

1. n8n queries `develop` commit history since the last `promoted_phases` timestamp to build the stack list
2. n8n gets the current `develop` HEAD SHA via GitHub API
3. Force-updates `main` ref to point to that SHA
4. Creates a promotion commit on `main` — triggers GitHub Actions on `main`
5. GitHub Actions on `main`: Build → Deploy to `local2local-prod` → Deploy PROD n8n workflow
6. n8n writes a `promoted_phases` record to Firestore (includes the full list of commit SHAs promoted)
7. Any `deferred_phases` records for commits in this stack are updated with `promoted_in: {phase_version}`
8. Version is bumped in `pubspec.yaml` on `develop` via GitHub Contents API
9. Final Alert card posted to Google Chat — lists all commits promoted

#### SAVE IN DEV STACK

Acknowledges the deployment and keeps it on `develop` for inclusion in a future promotion. The change remains on the `develop` branch and will be included the next time PROMOTE TO PROD is selected.

1. n8n writes a `deferred_phases` record to Firestore with `status: STACKED`
2. Decision card posted to Google Chat confirming the change is stacked
3. The dev stack counter increments — the next deployment card will show the updated stack depth

#### ARCHIVE CHANGES

Removes the change from `develop` but preserves it in a named archive branch for potential cherry-picking later. Use this when a change is not ready for prod and should not be carried forward in the dev stack.

1. n8n creates a branch `archive/{phase_version}` from the commit SHA being archived via GitHub API
2. n8n reverts the commit on `develop` via GitHub Contents API with message: `[AUTO] CHORE(archive): Revert {phase_version} — archived [skip ci]`
3. The `[skip ci]` tag prevents the revert from triggering another pipeline run
4. n8n writes an `archived_phases` record to Firestore with the archive branch name, original commit SHA, original commit message, and timestamp
5. Decision card posted to Google Chat confirming the archive branch name and revert
6. To recover an archived change later: `git cherry-pick <SHA>` from the archive branch onto `develop` — the cherry-pick enters the pipeline as a fresh commit with a fresh HITL review

---

## Firestore Tracking

All tracking records are written to `local2local-dev`.

### Promoted Phases
`artifacts/system_status/public/data/promoted_phases/{auto-id}`

Records which commits were promoted and when. Includes the full list of commit SHAs in the dev stack at promotion time, so it's clear exactly what shipped to prod in each promotion.

### Deferred Phases
`artifacts/system_status/public/data/deferred_phases/{auto-id}`

Records commits where the operator chose SAVE IN DEV STACK. Each record carries `status: STACKED` initially. When the commit is eventually included in a PROMOTE, the record is updated with `promoted_in: {phase_version}` and `status: PROMOTED`. This creates an audit trail showing that a deferred commit was explicitly reviewed at deferral time and again at promotion time.

### Archived Phases
`artifacts/system_status/public/data/archived_phases/{auto-id}`

Records commits where the operator chose ARCHIVE CHANGES. Includes the archive branch name (`archive/{phase_version}`), the original commit SHA, and the original commit message. If the archive is later cherry-picked back onto `develop`, a new commit enters the pipeline with its own HITL review — the archived record is not modified.

### Version
`artifacts/system_status/public/data/version`

---

## GitHub Secrets and Variables

| Name | Type | Purpose |
|---|---|---|
| `GCP_SA_KEY` | Secret (env-scoped) | Google Cloud service account key |
| `N8N_API_KEY` | Secret | n8n Cloud API key |
| `N8N_WEBHOOK_URL_DEV` | Secret | DEV orchestrator trigger webhook URL |
| `N8N_WEBHOOK_URL_PROD` | Secret | PROD orchestrator trigger webhook URL |
| `N8N_WORKFLOW_ID_DEV` | Variable | `ThWtTTPTR4ymYD6a` |
| `N8N_WORKFLOW_ID_PROD` | Variable | `NQ1mzljLu78Tzx7q` |

---

## n8n Workflows

| Workflow | ID | Trigger webhook | Approval webhook |
|---|---|---|---|
| DEV | `ThWtTTPTR4ymYD6a` | `b8f49bcc-cb60-4c00-9f8c-ae008be7b5b3` | `ea64f359-a428-46e4-9dc1-d5c643f385eb` |
| PROD | `NQ1mzljLu78Tzx7q` | `b8f49bcc-cb60-4c00-9f8c-ae008be7b5b3-prod` | `ea64f359-a428-46e4-9dc1-d5c643f385eb-prod` |

Workflow JSON files are stored in `n8n_workflows/` and deployed automatically on every pipeline run.

---

## Key Files

| File | Purpose |
|---|---|
| `.github/workflows/deploy.yml` | The CI/CD pipeline |
| `pubspec.yaml` | Single source of truth for version |
| `.l2laaf/state.json` | Operational state (no version) |
| `scripts/relay.sh` | Entry point for Assisted method (v6.4) |
| `scripts/patcher.js` | Extracts L2LAAF_BLOCK sections from payload |
| `n8n_workflows/l2laaf_autonomous_orchestrator.develop.json` | DEV orchestrator (45 base nodes + 6 Phase 45 nodes) |
| `n8n_workflows/l2laaf_autonomous_orchestrator.main.json` | PROD orchestrator (same structure) |

---

## relay.sh

Current version: **v6.4** (`scripts/relay.sh`)

| Version | Key change |
|---|---|
| v6.2 | Conditional preflight checks, COMMIT_MSG format validation |
| v6.3 | Flutter analyze captures stderr (`2>&1`) |
| v6.4 | Targeted n8n cleanup — only deletes workflow files explicitly listed in payload |

The v6.4 targeted cleanup means a payload containing only `develop.json` will not delete `main.json`. Both files must be explicitly listed in the payload if both are being replaced.

---

## Throttling

| Status | Behaviour |
|---|---|
| `GREEN` | Proceed — card posted normally |
| `YELLOW` | Card posted with warning |
| `RED` | Deployment blocked — Blocked Chat Card posted |
