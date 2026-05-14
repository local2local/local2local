# L2LAAF Project Plan

**Current version:** 45.1.3
**System status:** 🟢 OPERATIONAL
**Tech stack:** Flutter 3.38.5 + Node.js 24 (2nd Gen Firebase Functions) + TypeScript

---

## Phase groups completed

### Phase Group 1: Infrastructure & Nervous System
Phases 1–10: Multi-project GCP setup, Firestore hierarchical schema, Inter-Agent Messaging Bus.
Phases 11–16: Tiered authority (Treasury Gate), PII masking (Zero-Trust Barrier), cross-tenant data sovereignty.

### Phase Group 2: Interface & Visualization
Phase 17: Flutter Triage Hub master shell with multi-tenant toggles.
Phases 18–20: Health Grid, Fleet Map (GPS telemetry), Intervention Queue.
Phases 21–25: Identity/Security hardening and custom claim-based auth guards.

### Phase Group 3: The Evolution Engine
Phase 33: Agent Registry hardening.
Phase 34: Concurrency Locking (Mutex logic for HBR paths).
Phase 35: Autonomous Logic Refinement.
Phase 36: Global Memory (Lessons Learned Vault).

### Phase Group 4: CI/CD Pipeline (Phases 41–43) — COMPLETED & STABLE
The full CI/CD pipeline was designed and implemented. See `documents/cicd_master_checklist.md` for the complete implementation record and `documents/cicd_pipeline_reference.md` for operational reference.

Key outcomes:
- Automatic version bumping from `pubspec.yaml` on every push
- Four development methods: Manual, Assisted, Autonomous, Dreamflow
- Human-in-the-Loop (HITL) gate via Google Chat for production promotion
- `[skip ci]` logic implemented to prevent pipeline loops
- Multi-developer safety with `relay.sh` auto-rebase logic
- **Upstream Relay mechanism** — production-identified fixes are funnelled back through `develop` and the HITL gate before re-entering `main`

### Phase Group 5: SuperAdmin Dashboard (Phase 44) — COMPLETED
**Final version:** 44.4.4

Full CI/CD visibility and cross-tenant control dashboard built across two pages:

**Page 1 — Phases**
- Promoted and abandoned phase history with SHA display, originator badges, and timestamps
- Search/filter by summary text
- Per-tab streaming/static mode with live document counter (ID-based, works beyond 50-doc stream limit)
- Timestamp range filtering with quick presets (Last 15 min, Last hour, Last 24h, Custom)

**Page 2 — Data**
- Colour-coded telemetry banner (GREEN/YELLOW/RED) with status-aware icons and messages
- Multi-tenant agent bus viewer (SYSTEM / KASKFLOW / MOONLITELY)
- Agent bus / Shadow bus segmented toggle per tab
- Full-featured bus cards: correlation highlighting, sort, filter, expand, full JSON modal, copy SHA, delete by correlation ID
- Per-tab streaming/static mode with pagination (page size 50) and timestamp range filter
- Generic data browser: collection selector with autocomplete (18 known collections), document viewer, field filters, search with match highlighting, and delete
- Agent bus injection UI: Raw JSON editor (default), Structured form, Template library

**Infrastructure work completed in Phase 44:**
- GoRouter properly mounted in `app.dart`
- `adminDarkTheme` applied throughout
- Firestore paths corrected in `SuperadminRepository`
- `.gitignore` restored and expanded
- Staging environment removed from `environment_provider.dart`
- Dev project ID corrected (`local2local-dev`)
- DEV/PROD switcher wired to live environment and version providers
- `created_at`, `last_updated`, `telemetry.processed_at` added to all agent bus writes
- `telemetryAggregatorV2` fixed to write to correct Firestore document (`last_heartbeat`)
- `development_method_dreamflow.md` updated with Dreamflow AI agent workflow, minification bug rule, Firebase session conventions

---

## Branch strategy

| Branch | Environment | GCP Project | Deployment |
|---|---|---|---|
| `develop` | Development | `local2local-dev` | Automatic on push |
| `main` | Production | `local2local-prod` | Triggered by HITL approval |

---

## GCP projects

| Project | Purpose | Status |
|---|---|---|
| `local2local-dev` | Development environment, CI/CD source of truth | Active |
| `local2local-prod` | Production environment | Active |
| `local2local-internal` | Governance hub (Registry, Policy, Vector DB) | Active |
| `n8n-bot-prod` | n8n chat handler service account host | Active |

Note: `local2local-staging` was removed from the architecture in Phase 44.

---

## Upcoming work

### Phase 45: Advanced Intelligence — IN PROGRESS

**45.1 — Multi-Agent Consensus** ✅ COMPLETE (45.1.3)
Impact Classifier and Validator Agent nodes inserted into the HITL path. Every deployment is classified as HIGH_IMPACT or ROUTINE by Gemini. HIGH_IMPACT changes receive a Gemini risk assessment in the Google Chat HITL card.

New orchestrator nodes (between Throttle Switch and Google Chat Card):
- `Impact Classifier` — Gemini 2.5 Flash, classifies change
- `Extract Impact` — parses response, defaults to ROUTINE on failure
- `Impact Switch` — If node routing HIGH_IMPACT vs ROUTINE
- `Prepare Validator Prompt` — Code node building request body via `JSON.stringify`
- `Validator Agent` — Gemini 2.5 Flash, produces 1-2 sentence risk assessment
- `Extract Critique` — parses validator response, merges into card data

**45.2 — Semantic Retrieval** (PENDING)
Agents query `lessons_learned` in `local2local-internal` via vector search before proposing changes.

**45.3 — Regulatory Drift Automation** (PENDING)
Compliance monitoring agent tracks AGLC/CRA regulatory source documents and proposes corrective HBR updates when drift is detected.

---

## Development method reference

| Method | Source tag | Document |
|---|---|---|
| Manual | `[MANUAL]` | `documents/development_method_manual.md` |
| Assisted | `[ASSISTED]` | `documents/development_method_assisted.md` |
| Autonomous | `[AUTO]` | `documents/development_method_autonomous.md` |
| Dreamflow | `[DREAM]` | `documents/development_method_dreamflow.md` |
