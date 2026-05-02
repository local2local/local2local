# L2LAAF Full Technical Specification

## 1. Architectural Overview

The **Local2Local AI Agent Framework (L2LAAF)** is a multi-tenant, hierarchical AI operating system built on top of the local2local marketplace app. It uses a "Management by Exception" philosophy — autonomous agents handle the vast majority of operations and escalate to a human operator only when logic boundaries are exceeded.

---

## 2. Infrastructure Architecture

Deployment is distributed across four active Google Cloud Projects:

| Project | Role |
|---|---|
| `local2local-dev` | Development sandbox + CI/CD source of truth |
| `local2local-prod` | Live production |
| `local2local-internal` | Governance hub (Registry, Policy, Vector DB) |
| `n8n-bot-prod` | n8n chat handler service account host |

Note: The `local2local-staging` project referenced in earlier documentation has been removed from the architecture. The HITL gate in Google Chat replaces shadow mode staging as the validation layer between dev and prod.

---

## 3. The Tri-Reference Governance Model

Every agent decision is grounded in three reference layers:

1. **Hard Business Rules (HBR):** Explicit JSON/Markdown logic files (e.g. "GST = 5%", "minimum vendor rating = 4.2"). The authoritative source for agent behaviour.
2. **Lessons Learned (LL):** Vectorised experience from previous human interventions at the HITL gate. Agents query this database to inform new proposals.
3. **Policy Registry (PR):** High-level strategic intent (e.g. "Prioritise hyper-local vendors within 50km"). Sets the direction that HBRs and LL must align with.

---

## 4. Core Logic Components

### 4.1 Inter-Agent Messaging Bus
- **Path:** `artifacts/{appId}/public/data/agent_bus`
- **Pattern:** Request-Response envelope with `correlation_id` and provenance tracking
- **Security:** Zero-Trust Information Barrier scrubs PII using Regex/NER before dispatching to workers

### 4.2 Human-in-the-Loop (HITL) Gate
All agent-proposed code changes pass through a mandatory human approval step before reaching production. The HITL gate is implemented in n8n and surfaces as a Google Chat card with `PROMOTE TO PROD` and `KEEP IN DEV` buttons. See `documents/cicd_pipeline_reference.md` for the full gate flow.

### 4.3 Logic Collision Detection (LCD)
Graph-based dependency mapping prevents Agent A's changes from breaking Agent B's calculations or creating circular instructional loops.

### 4.4 Evolution Engine
- **Mutex Locks:** `logic_locks/{hbrId}` prevents race conditions during logic refinement
- **Global Memory:** `lessons_learned` collection archives the semantic reasoning of every committed HBR change to maintain system context across sessions

### 4.5 Shadow Mode Validation (SMV)
Production traffic is forked to the `shadow_bus` for validation before new logic goes live.
- **Pass Gate:** >95% Semantic Parity and 100% Logic Integrity over 100 tasks
- **Promotion:** Requires HITL approval even after passing shadow validation

---

## 5. Tech Stack

| Layer | Technology |
|---|---|
| Backend | Node.js 24 (2nd Gen Firebase Functions), TypeScript |
| Frontend | Flutter 3.38.5 (web-first) |
| State | Firestore (real-time reactive streams) |
| Auth | Firebase Auth with Custom Claims (`admin: true`, `superadmin: true`) |
| Orchestration | n8n Cloud (`local2local.app.n8n.cloud`) |
| CI/CD | GitHub Actions (`.github/workflows/deploy.yml`) |

---

## 6. Development Methods

Four methods exist for delivering changes through the pipeline. All four converge on the same HITL gate:

| Method | Source tag | Description |
|---|---|---|
| Manual | `[MANUAL]` | Developer writes code in Cursor IDE and pushes directly |
| Assisted | `[ASSISTED]` | AI generates a logic_payload bundle; developer runs `relay.sh` |
| Autonomous | `[AUTO]` | Agent writes to the agent bus; n8n orchestrates the pipeline |
| Dreamflow | `[DREAM]` | Dreamflow AI generates Flutter/Dart UI code |

See the individual method documents in `documents/` for full step-by-step instructions.

---

## 7. Guided Autonomy Tooling

| Tool | Path | Purpose |
|---|---|---|
| `patcher.js` | `scripts/patcher.js` | Extracts `L2LAAF_BLOCK` sections from a logic_payload bundle and writes files to disk |
| `relay.sh` | `scripts/relay.sh` | Validates TypeScript, Flutter, and n8n JSON, then commits and pushes the payload |
| `audit.sh` | `scripts/audit.sh` | Bundles recently changed files into a context payload for AI sessions |
| `deploy.sh` | `scripts/deploy.sh` | Convenience wrapper for the Manual method — runs analysis and commits |
