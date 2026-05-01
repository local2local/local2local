# L2LAAF Project Plan

**Current version:** 43.1.x  
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

### Phase Group 4: CI/CD Pipeline (Phases 41–43) — COMPLETED
The full CI/CD pipeline was designed and implemented. See `documents/cicd_master_checklist.md` for the complete implementation record and `documents/cicd_pipeline_reference.md` for operational reference.

Key outcomes:
- Automatic version bumping from `pubspec.yaml` on every push
- Four development methods: Manual, Assisted, Autonomous, Dreamflow
- Human-in-the-Loop (HITL) gate via Google Chat
- `PROMOTE TO PROD` and `KEEP IN DEV` approval flow
- Firestore tracking of all promoted and abandoned phases
- Separate DEV and PROD n8n orchestrator workflows

---

## GCP projects

| Project | Purpose | Status |
|---|---|---|
| `local2local-dev` | Development environment, CI/CD source of truth | Active |
| `local2local-prod` | Production environment | Active |
| `local2local-internal` | Governance hub (Registry, Policy, Vector DB) | Active |
| `n8n-bot-prod` | n8n chat handler service account host | Active |

Note: `local2local-staging` was removed from the architecture. The HITL gate in Google Chat serves as the validation layer between dev and prod.

---

## Upcoming work

### SuperAdmin Dashboard (Phase 44)
Flutter UI in the Triage Hub for CI/CD visibility and control:
- Current version display (reads from `artifacts/system_status/public/data/version`)
- Promoted phases history (reads from `artifacts/system_status/public/data/promoted_phases`)
- Abandoned phases history with cherry-pick reference (reads from `artifacts/system_status/public/data/abandoned_phases`)
- System telemetry status display and manual override
- Mobile-friendly HITL buttons (requires real HTTP endpoint at `https://local2local.ca/chat-bot-hook`)

### Phase 45: Advanced Intelligence
- Semantic Retrieval: agents query the `lessons_learned` database via vector search
- Multi-Agent Consensus: requiring approval from multiple orchestrators for high-impact changes
- Regulatory Drift Automation: closed-loop adaptation to AGLC/CRA legislative shifts

---

## Development method reference

| Method | Source tag | Document |
|---|---|---|
| Manual | `[MANUAL]` | `documents/development_method_manual.md` |
| Assisted | `[ASSISTED]` | `documents/development_method_assisted.md` |
| Autonomous | `[AUTO]` | `documents/development_method_autonomous.md` |
| Dreamflow | `[DREAM]` | `documents/development_method_dreamflow.md` |
