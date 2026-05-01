# CI/CD Pipeline Reference

**Version:** 43.1.x  
**Last updated:** 2026-05-01  
**Source of truth:** `.github/workflows/deploy.yml`, `n8n_workflows/`

---

## Overview

The L2LAAF CI/CD pipeline is a fully automated deploy-to-dev, human-approve, promote-to-prod system. Every change to the `develop` branch is automatically built, versioned, and deployed to the dev environment. A Human-in-the-Loop (HITL) gate in Google Chat then gives the operator the option to promote the change to production or keep it in dev.

```
Developer pushes to develop
    → GitHub Actions: Bump Version → Build → Deploy to dev → Notify n8n
    → n8n: Evaluate system status → Post HITL card to Google Chat
    → Operator: PROMOTE TO PROD or KEEP IN DEV
        → PROMOTE: Force-update main → Promotion commit → Deploy to prod → Record in Firestore
        → KEEP IN DEV: Record abandoned phase in Firestore
```

---

## Versioning

The version number follows semantic versioning: `MAJOR.MINOR.PATCH`.

| Segment | Meaning | Controlled by |
|---|---|---|
| `MAJOR` | Development phase (currently 43) | Developer — append `BUMP: MAJOR` to commit |
| `MINOR` | Feature group within the phase | Developer — append `BUMP: MINOR` to commit |
| `PATCH` | Individual change | Pipeline — default, no tag needed |

**pubspec.yaml is the single source of truth for the version.** `state.json` does not hold a version number.

The full version string in `pubspec.yaml` looks like:
```yaml
version: 43.1.54+557
```
Where `43.1.54` is the semantic version and `557` is the GitHub Actions run number (build number).

### How the pipeline bumps versions

On every push to `develop` or `main`, the `Bump Version` step in `deploy.yml`:

1. Reads the current version from `pubspec.yaml`
2. Parses the `BUMP:` tag from the commit message (case insensitive)
3. Calculates the new version — incrementing right-hand segments to 0 on MAJOR or MINOR bumps
4. Updates `pubspec.yaml` with `NEW_VERSION+RUN_NUMBER`
5. Commits back to the branch as `[AUTO] CHORE(version): Bump X to Y (PATCH) [skip ci]`

The `[skip ci]` tag on the auto-version commit prevents a pipeline loop.

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
| `scope` | Single lowercase word — e.g. `pipeline`, `orchestrator` | Developer or system |
| `Description` | Title case free text | Developer or system |
| `[BUMP: TYPE]` | Optional. Omit for PATCH (default) | Developer only |

**Examples:**
```
[MANUAL] FIX(pipeline): Skip deployments triggered by merge commits
[MANUAL] FEAT(orchestrator): Add decision card BUMP: MINOR
[ASSISTED] FIX(functions): Resolve deleteSubcollectionV2 trigger conflict
[AUTO] CHORE(orchestration): Promote phase 43.1.54 to prod
```

The version prefix (`43.1.54 - `) is added automatically by the pipeline — **never prefix versions manually**.

The `BUMP:` tag is stripped from the commit message before the final versioned message is built.

---

## Pipeline Skip Rules

The deploy job is skipped when:

- The commit message contains `[skip ci]` — used by the auto-version bump commit
- The commit message starts with `Merge branch` — merge commits are never deployed
- The actor is `github-actions[bot]`

---

## Environments

| Branch | Environment | GCP Project | Firebase Project |
|---|---|---|---|
| `develop` | Development | `local2local-dev` | local2local-dev |
| `main` | Production | `local2local-prod` | local2local-prod |

---

## Pipeline Steps (develop branch)

### 1. Bump Version
Reads `pubspec.yaml`, parses the `BUMP:` tag, calculates the new version, updates `pubspec.yaml`, and pushes an `[AUTO] CHORE(version)` commit with `[skip ci]`.

### 2. Install Firebase CLI & Dependencies
Installs Firebase CLI, Cloud Functions npm dependencies, and Flutter packages.

### 3. Build Flutter Web
Runs `flutter build web --release`.

### 4. Authenticate to Google Cloud
Uses the `GCP_SA_KEY` GitHub secret to authenticate via service account.

### 5. Deploy Stack
Runs `firebase deploy --only hosting,functions` to `local2local-dev`.

### 6. Deploy n8n Workflow
Uploads `n8n_workflows/l2laaf_autonomous_orchestrator.develop.json` to the DEV n8n workflow via the n8n API. Deactivates and reactivates the workflow to force webhook re-registration on Cloudflare's edge network.

### 7. Notify Orchestrator
Probes the DEV webhook until it responds (up to 60s), then fires the deployment payload:
```json
{
  "incoming_phase": "43.1.54",
  "build_id": "<commit SHA>",
  "summary": "43.1.54 - [MANUAL] FIX(pipeline): Description",
  "event": "DEPLOYMENT_COMPLETE",
  "env": "dev",
  "method": "MANUAL"
}
```
This step is skipped on `main` — the PROD orchestrator is triggered by the promotion commit instead.

---

## The HITL Gate

After a successful `develop` deployment, the DEV n8n orchestrator (`L2LAAF: Autonomous Orchestrator - DEV`, workflow ID `ThWtTTPTR4ymYD6a`) posts a deployment card to the `L2LAAF-Orchestrator` Google Chat space.

### Deployment Card Fields

| Field | Source |
|---|---|
| Phase | `incoming_phase` from webhook payload |
| Originator | `method` from webhook payload |
| Status | Firestore `artifacts/system_status/public/data/telemetry` (GREEN/YELLOW/RED) |
| Intent | Derived from `TYPE` in commit message |
| Build Details | Full versioned commit message |
| Throttle Evaluation | Output of Throttling Evaluator node |

### PROMOTE TO PROD

1. n8n gets the current `develop` HEAD SHA via GitHub API
2. Force-updates `main` ref to point to that SHA
3. Creates a promotion commit on `main` via GitHub Contents API — this triggers GitHub Actions on `main`
4. GitHub Actions on `main`: Bump Version → Build → Deploy to `local2local-prod` → Deploy PROD n8n workflow
5. n8n writes a `promoted_phases` record to Firestore
6. Final Alert card posted to Google Chat

### KEEP IN DEV

1. n8n writes an `abandoned_phases` record to Firestore
2. Decision card posted immediately to Google Chat showing all abandoned phase fields
3. Final Alert plain text message posted to Google Chat

---

## Firestore Tracking

All tracking records are written to `local2local-dev`.

### Promoted Phases
```
artifacts/system_status/public/data/promoted_phases/{auto-id}
```
```json
{
  "phase": "43.1.54",
  "commit_sha": "d235957...",
  "summary": "43.1.54 - [MANUAL] FIX(orchestrator): Description",
  "originator": "MANUAL",
  "promoted_at": "2026-05-01T09:41:00Z",
  "promoted_by": "todd.herron@local2local.ca",
  "status": "ACTIVE"
}
```

### Abandoned Phases
```
artifacts/system_status/public/data/abandoned_phases/{auto-id}
```
```json
{
  "phase": "43.1.44",
  "commit_sha": "d235957...",
  "summary": "43.1.44 - [MANUAL] FIX(orchestrator): Description",
  "originator": "MANUAL",
  "abandoned_at": "2026-05-01T09:41:00Z",
  "reason": "KEEP_IN_DEV",
  "status": "ABANDONED"
}
```

### Version
```
artifacts/system_status/public/data/version
```
```json
{
  "current": "43.1.54",
  "updated_at": "2026-05-01T09:41:00Z",
  "environment": "prod"
}
```

---

## GitHub Secrets and Variables

| Name | Type | Purpose |
|---|---|---|
| `GCP_SA_KEY` | Secret (env-scoped) | Google Cloud service account key for Firebase deploy |
| `N8N_API_KEY` | Secret | n8n Cloud API key for workflow deployment |
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
| `n8n_workflows/l2laaf_autonomous_orchestrator.develop.json` | DEV orchestrator workflow |
| `n8n_workflows/l2laaf_autonomous_orchestrator.main.json` | PROD orchestrator workflow |

---

## Preventing Pipeline Loops

Three layers of loop prevention are in place:

1. **`[skip ci]` tag** — appended to all `[AUTO] CHORE(version)` commits. GitHub natively skips the pipeline for these commits.
2. **`Merge branch` filter** — merge commits are filtered out by the job `if` condition.
3. **`github-actions[bot]` filter** — commits from the GitHub Actions bot actor are skipped.

---

## Throttling

The DEV orchestrator checks the system telemetry document before posting a HITL card:

| Status | Behaviour |
|---|---|
| `GREEN` | Proceed with deployment — card posted normally |
| `YELLOW` | Informational warning added to card — card still posted |
| `RED` | Deployment blocked — `Blocked Chat Card` posted instead |

Telemetry is written by the `telemetryAggregator` Cloud Function based on live error rates in `local2local-prod`.
