# CI/CD Implementation Record

**Status:** COMPLETE & STABLE
**Implemented:** April–May 2026
**Current version:** 43.1.66

This document records what was actually built during the CI/CD implementation session (Phases 41–43) plus the Upstream Relay mechanism added in Phase 43.1.66. For operational reference, see `documents/cicd_pipeline_reference.md`.

---

## What was built

### GitHub Actions pipeline (`.github/workflows/deploy.yml`)

- Single workflow file covering both `develop` and `main` branches
- Automatic semantic version bumping from `pubspec.yaml` on every push
- `BUMP: MAJOR|MINOR|PATCH` tag support in commit messages (case insensitive, defaults to PATCH)
- `[skip ci]` on auto-version commits to prevent pipeline loops
- Merge commit and `github-actions[bot]` skip filters
- Flutter web build and deploy to environment-specific Firebase project
- n8n workflow JSON deployment with deactivate/reactivate cycle for webhook re-registration
- Webhook probe loop (up to 60s) before firing the orchestrator notification
- `Notify Orchestrator` step skipped on `main` to prevent phantom HITL cards
- `permissions: contents: write` for GITHUB_TOKEN push access

### n8n orchestration (two separate workflows)

- **DEV:** `L2LAAF: Autonomous Orchestrator - DEV` (ID: `ThWtTTPTR4ymYD6a`)
- **PROD:** `L2LAAF: Autonomous Orchestrator - PROD` (ID: `NQ1mzljLu78Tzx7q`)
- Separate webhook paths for DEV and PROD
- State Manager reads version from webhook payload (not `state.json`)
- Throttling Evaluator checks Firestore telemetry (GREEN/YELLOW/RED)
- Google Chat HITL card with `PROMOTE TO PROD` / `KEEP IN DEV` buttons
- Post Decision Card fires immediately on button click (no browser tab content)
- Action Gate routing to approve or decline paths
- `Get Develop SHA` → `Force Update Main` replacing the merge API (resolves merge conflicts)
- `Merge Error Check` with `Merge Failed Alert` for diagnostic feedback
- `Get Main State SHA` → `Create Promotion Commit` to trigger GitHub Actions on `main`
- `Proposal Closure Check` for HBR proposal resolution
- `Write Version to Firestore` after each promotion
- `Write Promoted Phase` to `promoted_phases` collection
- `Write Abandoned Phase` to `abandoned_phases` collection
- `Final Alert` — rich card on promote, plain text on decline
- Error Alert with full error message, description, and cause fields

### Upstream Relay mechanism

Allows agents running in `local2local-prod` to propose code fixes that are funnelled back through `develop` and the HITL gate before re-entering `main`. This guarantees no production-identified fix bypasses human review.

Flow:
1. A prod agent writes a `PROPOSE_LOGIC_CHANGE` payload to its local Firestore agent bus (`local2local-prod`)
2. The PROD n8n Orchestrator intercepts the write and recognises the intent as a logic mutation
3. The PROD Orchestrator commits the `proposedLogic` to the `develop` branch via the GitHub Contents API — **without** `[skip ci]` so the DEV pipeline triggers immediately
4. Commit message format: `[AUTO] FIX(relay): Prod-identified fix for {path}`
5. The `reason` field in the agent bus payload states: `"Discovered in local2local-prod"` — this flows through to the HITL card and Firestore audit records
6. The DEV pipeline builds the change, deploys to `local2local-dev`, bumps the version, and fires the DEV n8n Orchestrator
7. The operator receives a standard HITL card and decides: `PROMOTE TO PROD` or `KEEP IN DEV`

Key rules:
- The PROD Orchestrator is forbidden from committing directly to `main`
- Relay commits never use `[skip ci]` — the fix must reach the HITL gate immediately
- The relay fix receives a new version number from the DEV pipeline's `Bump Version` step
- The `[AUTO] FIX(relay)` tag in the commit message creates a clear git audit trail

### Firestore tracking (in `local2local-dev`)

- `artifacts/system_status/public/data/promoted_phases` — promotion history
- `artifacts/system_status/public/data/abandoned_phases` — abandoned change history
- `artifacts/system_status/public/data/version` — current deployed version
- `artifacts/system_status/public/data/telemetry` — system health status

### Versioning

- `pubspec.yaml` is the single source of truth for version
- `state.json` `current_phase` field removed — no longer used
- Version format: `MAJOR.MINOR.PATCH+BUILD_NUMBER`
- Build number = GitHub Actions run number

### GCP permissions

- `n8n-orchestrator@local2local-dev.iam.gserviceaccount.com` granted `Cloud Datastore User` on `local2local-prod`
- Enables `Fetch System Status` in PROD n8n workflow to read telemetry

---

## What was explicitly not built (parked)

- **Mobile-friendly HITL buttons** — requires a real HTTP endpoint at `https://local2local.ca/chat-bot-hook` for Google Chat interactive widgets. Currently uses `openLink` buttons which open a browser tab. To be addressed when building the SuperAdmin dashboard.
- **SuperAdmin dashboard** — Flutter UI for viewing `promoted_phases`, `abandoned_phases`, and `version` from Firestore. Scaffolded but not implemented.
- **Flutter dashboard version display** — reading `artifacts/system_status/public/data/version` from Firestore to display current version in the app.

---

## GitHub secrets and variables

| Name | Type | Scope |
|---|---|---|
| `GCP_SA_KEY` | Secret | Environment-scoped (Dev / Production) |
| `N8N_API_KEY` | Secret | Repository |
| `N8N_WEBHOOK_URL_DEV` | Secret | Repository |
| `N8N_WEBHOOK_URL_PROD` | Secret | Repository |
| `N8N_WORKFLOW_ID_DEV` | Variable | Repository (`ThWtTTPTR4ymYD6a`) |
| `N8N_WORKFLOW_ID_PROD` | Variable | Repository (`NQ1mzljLu78Tzx7q`) |
