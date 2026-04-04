# L2LAAF Full Technical Specification

## 1. Architectural Overview
The **Local2Local AI Agent Framework (L2LAAF)** is a multi-tenant, hierarchical AI operating system. It leverages a "Management by Exception" philosophy, where autonomous agents manage thousands of users and transactions, escalating to a human operator only when logic boundaries are exceeded.

## 2. Infrastructure Architecture
Deployment is distributed across five isolated Google Cloud Projects:
- `local2local-internal`: Governance Hub (Registry, Policy, Vector DB).
- `local2local-dev:` Sandbox prototyping.
- `local2local-staging`: Shadow Mode testing (SMV).
- `local2local-prod`: Live Production.n8n-bot-prod: High-throughput external workers (Scrapers/API Syncs).

## 3. The Tri-Reference Governance Model
1. **Hard Business Rules (HBR)**: Explicit JSON/Markdown logic (e.g., "GST = 5%").
2. **Lessons Learned (LL)**: Vectorized experience from previous human interventions.
3. **Policy Registry (PR)**: High-level strategic intent (e.g., "Prioritize hyper-local vendors").

## 4. Core Logic Components

### 4.1 Inter-Agent Messaging Bus
- **Path**: `artifacts/{appId}/public/data/agent_bus`
- **Pattern**: Request-Response envelope with correlation_id and provenance tracking.
- **Security**: Zero-Trust Information Barrier scrubs PII using Regex/NER before dispatching to workers.

### 4.2 Shadow Mode Validation (SMV)
Production traffic is forked to the `shadow_bus`.
- **Pass Gate**: >95% Semantic Parity and 100% Logic Integrity over 100 tasks.
- **Promotion**: Autonomous promotion to "Live" status once threshold is met.

4.3 Logic Collision Detection (LCD)
Graph-based dependency mapping preventing Agent A's changes from breaking Agent B's calculations or creating circular instructional loops.

4.4 Evolution Engine (Phase 36 State)
- **Mutex Locks**: `logic_locks/{hbrId}` prevents race conditions during logic refinement.
- **Global Memory**: `lessons_learned` collection archives the semantic reasoning of every committed HBR change to maintain system context.

## 5. Tech Stack
- **Backend**: Node.js 24 (2nd Gen Firebase Functions), TypeScript.
- **Frontend**: Flutter 3.38.5 (Web-first Admin Hub).
- **State**: Firestore (Real-time reactive streams).
- **Auth**: Firebase Auth with Custom Claims (`admin: true`).

## 6. Guided Autonomy Protocol
The framework is managed via two core utilities on the developer workstation:
1. `patcher.js`: A literal-free logic extractor that parses `scripts/logic_payload.md`.
2. `relay.sh`: A shell orchestrator that handles `npm run build`, `npm run lint`, `git commit`, and `firebase deploy` with autonomous telemetry logging to the Evolution Timeline.