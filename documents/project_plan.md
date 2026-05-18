# L2LAAF Project Plan

**Current version:** 45.4.2
**System status:** 🟢 OPERATIONAL
**Tech stack:** Flutter 3.38.5 + Node.js 24 (2nd Gen Firebase Functions) + TypeScript

---

## How this plan works

This document is the single shared roadmap for all development work on L2LAAF. It is read by Claude AI, Google Gemini, and the developer at the start of every session. Changes to the plan are committed before the implementation commits that follow them.

**Three planning horizons:**
- **Horizon 1 — Active phase:** fully specified, being built now
- **Horizon 2 — Next 2-3 phases:** planned with enough detail to make architectural decisions today that won't need to be undone later
- **Horizon 3 — Future phases:** directional intent and sequence only

Mid-course corrections are committed as `[MANUAL] CHORE(docs): Update project plan — [reason]` before any implementation changes.

**Judge Layer reference:** All agent actions in this system are governed by the judge layer architecture defined in `documents/judge_layer_architecture.md`. Read that document before designing any feature that involves an agent taking an action against an external system.

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
Full automated deploy-to-dev, human-approve, promote-to-prod system. See `documents/cicd_pipeline_reference.md`.

### Phase Group 5: SuperAdmin Dashboard (Phase 44) — COMPLETED
**Final version:** 44.4.4. Two-page dashboard with telemetry, phase history, agent bus viewer, data browser, and injection UI.

---

## Active and upcoming phases

---

### Phase 45: Advanced Intelligence — IN PROGRESS
**Current sub-phase:** 45.4 complete (45.4.2)

---

#### 45.1 — Multi-Agent Consensus ✅ COMPLETE
Impact Classifier and Validator Agent inserted into HITL path. All deployments classified HIGH_IMPACT or ROUTINE. HIGH_IMPACT changes receive a Gemini risk assessment in the Google Chat card under "Impact Assessment".

**Known limitation:** Both Impact Classifier and Validator Agent use Gemini — same model family as the actor. This is the correlated judgment failure mode identified in the judge layer reference paper. Mitigated by Claude QA (Phase 45.8) which uses a different model family. The current Gemini-only validation catches surface errors; Claude catches the category errors Gemini shares with the actor.

---

#### 45.2 — Bitemporal HBR Versioning & Regulatory Data ✅ COMPLETE

Established the bitemporal HBR versioning architecture and populated all regulatory HBR files with real data:

- Bitemporal versioning model (valid time + decision time) for regulatory HBR files
- HBR version lifecycle: SCHEDULED → ACTIVE → SUPERSEDED, plus REVOKED and AMENDED paths
- Firestore `hbr_versions` collection schema at `artifacts/system_status/public/data/hbr_versions/`
- Populated AGLC rules (v1.2, 120 rules from December 2025 Liquor Agency Handbook), CRA GST rules (v1.0, 15 rules), IILA interprovincial transport rules (v1.0, 10 rules)
- `policy.md` + `rules.json` pair pattern for all three HBR directories
- HBR versioning rules added to `ai_context_rules.md`
- HBR directory structure documented in `l2laaf_full_specification.md` §8

---

#### 45.3 — Three-Option HITL Gate Architecture ✅ COMPLETE

Replaced the binary HITL gate (PROMOTE TO PROD / KEEP IN DEV) with a three-option model:

- **PROMOTE TO PROD** — ships entire dev stack, card lists all stacked commits
- **SAVE IN DEV STACK** — keeps on develop, recorded in `deferred_phases` (not `abandoned_phases`)
- **ARCHIVE CHANGES** — reverts on develop, preserves in `archive/{phase_version}` branch for cherry-picking

Architecture documents updated: `cicd_pipeline_reference.md`, `ai_context_rules.md`, `l2laaf_full_specification.md`, `judge_layer_architecture.md`. Firestore tracking collections: `promoted_phases`, `deferred_phases`, `archived_phases`.

**Implementation status:** Architecture documents complete. n8n orchestrator implementation in Phase 45.5.

---

#### 45.4 — Regulatory Drift Automation & CI/CD Hardening ✅ COMPLETE

Compliance monitoring agent tracks AGLC, CRA, and IILA regulatory source documents. Detects drift from current HBRs. Proposes corrective updates through the Evolution Engine pipeline. HBR changes produced by this agent are tagged `provenance: GENERATED` in lessons_learned and require human confirmation before becoming instruction-grade. Also added patcher v8.2 block format rule and implementation guide requirement for all Assisted method deliveries.

**This phase also establishes bitemporal HBR versioning** — the infrastructure that allows the system to answer "what rules applied at time T?" and to handle future-dated regulatory changes (rules announced now with an effective date in the future).

##### Bitemporal HBR Versioning Model

Every HBR version carries two time dimensions:

- **Valid time** (`valid_from` / `valid_until`): when the rule applies in the real world. This is the regulatory effective date, not the deployment date. A markup rate with `valid_from: 2027-04-01` does not apply to a March 31 order regardless of when the system learned about it.
- **Decision time** (`decision_recorded_at`): when the system recorded the rule. This answers "what did the system know on date X?" — required for audit if CRA or AGLC questions a historical transaction.

##### HBR Version Lifecycle

Every HBR version has a `status` field that governs how the system treats it:

| Status | Meaning | Applied to transactions? |
|---|---|---|
| `SCHEDULED` | Published by regulator with future effective date. Exists in registry, not yet governing. | Only for orders with fulfillment date ≥ `valid_from` |
| `ACTIVE` | Current governing version. `valid_from` has arrived. | Yes |
| `SUPERSEDED` | A newer version has taken effect. Immutable, queryable for audit. | Only for historical lookups at timestamps within its valid range |
| `REVOKED` | Regulator withdrew the rule before it took effect. Never applied. Retained for audit trail. | No |
| `AMENDED` | Regulator changed a scheduled rule before it took effect (e.g. pushed effective date). Replaced by a corrected `SCHEDULED` version. | No |

##### Firestore Schema — HBR Version Registry

**Collection:** `artifacts/system_status/public/data/hbr_versions/{versionId}`

```json
{
  "version_id": "HBR-AGLC-001-v1.0",
  "hbr_path": "functions/src/logic/hbr/alcohol/ca_ab_aglc/rules.json",
  "rule_maker": "AGLC",
  "region_scope": "ca_ab",
  "category": "alcohol",
  "version": "1.0",
  "status": "ACTIVE",

  "valid_from": "2026-05-16T00:00:00Z",
  "valid_until": null,

  "decision_recorded_at": "2026-05-16T00:00:00Z",
  "decision_source": "AGLC Liquor Markup Rate Schedule",
  "decision_source_url": "https://aglc.ca/liquor/agencies-suppliers-manufacturers/liquor-markup-rate-schedule",

  "supersedes_version": null,
  "superseded_by_version": null,

  "rules_snapshot": { "/* full rules object at this version */" : true },

  "change_summary": "Initial population with April 2026 markup rates and delivery rules",
  "source_commit": "abc123",
  "source_phase": "45.3.1",
  "provenance": "CONFIRMED",
  "confirmed_by": "todd.herron@local2local.ca",
  "created_at": "2026-05-16T00:00:00Z",

  "amendment_history": [
    {
      "amended_at": "2026-05-16T00:00:00Z",
      "action": "CREATED",
      "note": "Initial population"
    }
  ]
}
```

##### Runtime Resolution: `resolveHBR(ruleMaker, targetDate)`

Cloud Function that resolves the correct HBR version for a given target date. Used by pricing, checkout, and order validation.

```
Query: status IN [ACTIVE, SCHEDULED] AND valid_from <= targetDate AND (valid_until > targetDate OR valid_until == null)
```

For current transactions, `targetDate` is now. For future-dated orders (scheduled deliveries, pre-orders), `targetDate` is the fulfillment date. This means a user placing an order today for delivery after a scheduled rate change sees the correct future pricing.

##### Drift Agent Monitoring Scope

The compliance monitoring agent scrapes regulatory sources on a scheduled basis and compares against active HBR versions:

| Source | URL / Method | Check frequency | Monitored rules |
|---|---|---|---|
| AGLC markup schedule | `aglc.ca/liquor/.../liquor-markup-rate-schedule` | Weekly | Markup rates by category and ABV band |
| AGLC liquor bulletins | `aglc.ca/liquor/.../liquor-bulletins` | Weekly | Delivery policy, licensing changes, operational rules |
| CRA excise duty rates | `canada.ca/.../excise-duty-rates` | Monthly | Federal excise duty rates on alcohol |
| CRA GST/HST guidance | `canada.ca/.../digital-economy` | Monthly | Platform operator obligations, rate changes |
| IILA statute text | `laws-lois.justice.gc.ca/eng/acts/i-3/` | Monthly | Interprovincial transport exceptions |
| Canada Gazette | `gazette.gc.ca` | Weekly | Proposed and enacted regulatory changes with future effective dates |

When the drift agent detects a change:

1. **Immediate change** (already in effect): proposes a new `ACTIVE` HBR version. The pipeline archives the current version as `SUPERSEDED` before writing the new one.
2. **Future-dated change** (announced but not yet effective): proposes a `SCHEDULED` HBR version with the correct `valid_from`. The current `ACTIVE` version is not modified.
3. **Amendment to a scheduled change**: proposes marking the existing `SCHEDULED` version as `AMENDED` and creating a corrected `SCHEDULED` version.
4. **Revocation of a scheduled change**: proposes marking the `SCHEDULED` version as `REVOKED`.

All proposals go through the HITL gate. The drift agent's proposals are `provenance: GENERATED` until human-confirmed.

##### Scheduled Version Activation

An n8n scheduled workflow runs daily at 00:05 UTC. It queries for `SCHEDULED` versions where `valid_from <= now`. For each match:

1. The current `ACTIVE` version for that `rule_maker` + `region_scope` is marked `SUPERSEDED` with `valid_until` set to the scheduled version's `valid_from`
2. The scheduled version's `status` is updated to `ACTIVE`
3. The on-disk `rules.json` is updated via a pipeline commit: `[AUTO] CHORE(hbr): Activate scheduled HBR version {version_id}`
4. A notification is posted to the Google Chat space

##### Transaction-Pinned HBR References

Every order document records which HBR versions were applied at transaction time. This is implemented in Phase 46.3 (payment intents) and Phase 49.3 (checkout):

```json
{
  "hbr_versions_applied": {
    "ca_ab_aglc": "HBR-AGLC-001-v1.0",
    "ca_cra": "HBR-CRA-001-v1.0",
    "ca_iila": "HBR-IILA-001-v1.0"
  }
}
```

##### User-Facing Implications

When a `SCHEDULED` version exists and a user is browsing or ordering with a fulfillment date after `valid_from`:

- Pricing reflects the future rules, not the current rules
- A notice is displayed: "Pricing reflects [rule_maker] rates effective [valid_from date]"
- For category-level changes (e.g. interprovincial beer becomes legal): listings that will become available can be shown with an "Available starting [date]" badge and pre-order capability

These UI elements are implemented in Phase 49 (Kaskflow UI) and Phase 53 (PROOF UI).

##### Deliverables for Phase 45.4

1. `resolveHBR` Cloud Function (TypeScript, 2nd Gen)
2. `hbr_versions` Firestore collection with initial documents for all 3 rule makers
3. Compliance monitoring n8n workflow with scheduled scraping nodes
4. Scheduled version activation n8n workflow (daily cron)
5. Drift detection logic: compare scraped data against active HBR `rules_snapshot`
6. HBR archive-before-update pipeline logic in `deploy.yml` or relay.sh
7. SuperAdmin dashboard panel: HBR version timeline, scheduled versions, drift alerts

##### Known Gaps (Phase 45.4)

These items were identified during pre-flight audit and must be resolved before Phase 45.4 workflows are activated in production:

1. **Prod Cloud Function URL.** The `activateScheduledHBRs` Cloud Function URL in the HBR Version Activator n8n workflow targets `local2local-dev`. Before production activation, a parameterised version (or a separate prod workflow) must target `local2local-prod`. The prod version elevates the action to `EXTERNAL_IMPACT` per the judge layer tier table.
2. **Google Chat webhook credentials.** The `SPACE_ID`, `KEY`, and `TOKEN` placeholders in the Google Chat notification URLs in both n8n workflows must be substituted with the L2LAAF-Orchestrator space credentials before activation.
3. **Judge prompt update on HBR activation.** When `activateScheduledHBRs` promotes a `SCHEDULED` version to `ACTIVE`, any judge prompts that reference the superseded HBR version must be updated to reference the new version. This is required by `judge_layer_architecture.md` §Policy Versioning §Bitemporal HBR Versioning ("SCHEDULED → ACTIVE promotion workflow also triggers judge prompt updates"). Track implementation in Phase 45.8 (Claude QA as formal judge).

---

#### 45.5 — Three-Option HITL Gate Implementation (PENDING)

Implements the three-option HITL gate architecture (designed in Phase 45.3) in the n8n orchestrator. Also fixes two known bugs in the current orchestrator.

**n8n orchestrator changes (type 2 session — requires current orchestrator JSON per Rule 2):**

1. **Three-button Google Chat card:** Replace the current two-button card (PROMOTE TO PROD / KEEP IN DEV) with three buttons: PROMOTE TO PROD, SAVE IN DEV STACK, ARCHIVE CHANGES
2. **Approval webhook routing:** Update the approval webhook handler to route three ways instead of two
3. **SAVE IN DEV STACK path:** Write to `deferred_phases` in Firestore (replaces `abandoned_phases`), post confirmation card
4. **ARCHIVE CHANGES path:** Create `archive/{phase_version}` branch via GitHub API, revert commit on develop with `[skip ci]`, write to `archived_phases` in Firestore, post confirmation card
5. **Dev stack visibility on PROMOTE:** Query develop commit history since last `promoted_phases` timestamp, list all stacked commits on the PROMOTE card so the operator sees everything shipping to prod
6. **Deferred phases update on PROMOTE:** When PROMOTE fires, update any `deferred_phases` records for commits in the stack with `promoted_in: {phase_version}`

**Bug fixes (same orchestrator session):**

7. **Duplicate promotion messages:** The orchestrator currently posts two identical "Promoted to PROD" cards. Identify and remove the duplicate Chat notification node.
8. **Premature promotion confirmation:** The "Promoted to PROD" card posts immediately when the `main` ref is force-updated, before the GitHub Actions build/deploy completes. The confirmation should post only after the prod deployment succeeds — either by polling the GitHub Actions run status or by receiving a callback from the `main` branch pipeline.

---

#### 45.6 — Semantic Retrieval (PENDING) — HORIZON 2

Agents query `lessons_learned` in `local2local-internal` via vector search before proposing changes.

**Critical constraint from judge layer architecture:** Retrieved lessons must be filtered by `use_as` field before being included in agent context. Only lessons with `use_as: INSTRUCTION` (provenance `OBSERVED` or `CONFIRMED`) can be treated as policy. Lessons with `use_as: EVIDENCE` (provenance `INFERRED` or `GENERATED`) can be referenced but not acted on directly. This filtering must be implemented before semantic retrieval goes live, not after.

Requires: Vertex AI text-embedding-004 pipeline, `semanticRetrievalV1` Cloud Function, provenance-aware query filters, n8n orchestrator context enrichment node before Gemini Code Fixer.

---

#### 45.7 — Design Intent Infrastructure (PENDING) — HORIZON 2

Establishes the structured input mechanism for feeding design specifications into the autonomous coding pipeline. Includes the `ActionProposal` schema that all judged actions must produce.

**Firestore schema — `design_intents/{intentId}`:**
```json
{
  "intent_id": "INT-046-001",
  "phase": "46.1",
  "title": "Stripe webhook handler Cloud Function",
  "method": "ASSISTED",
  "target_files": ["functions/src/stripe/webhookHandler.ts"],
  "description": "Natural language description of what to build",
  "acceptance_criteria": ["..."],
  "context_files": ["functions/src/logic/treasury.ts"],
  "firestore_collections_affected": ["orders", "payment_intents"],
  "action_class": "EXTERNAL_IMPACT",
  "bump_type": "MINOR",
  "status": "PENDING",
  "created_at": "...",
  "satisfied_at": null,
  "result_phase": null
}
```

The `action_class` field in the design intent pre-classifies the work tier so the judge knows which checks to run before evaluating the proposal.

**ActionProposal extension to agent bus payload:**
Every autonomously generated commit appends a structured `action_proposal` field to the agent bus message. This is the object the judge evaluates — not the commit message prose. See `documents/judge_layer_architecture.md` for the full schema.

**SuperAdmin dashboard panel:** Intent queue, create form, detail view, select button.

---

#### 45.8 — Claude QA Integration (PENDING) — HORIZON 2

Integrates Claude Opus as the primary QA judge for `EXTERNAL_IMPACT` and `HIGH_STAKES` actions. Claude uses a different model family than Gemini, providing structural protection against correlated judgment failure.

**Four-outcome verdict:** Claude returns `ALLOW`, `BLOCK`, `REVISE`, or `ESCALATE` — never binary. See `documents/judge_layer_architecture.md` for routing behaviour for each outcome.

**Judge criteria are explicit policy, not vibes.** The Claude prompt implements specific HBR-versioned criteria. A list of criteria is evaluated against the structured `ActionProposal`, not against the actor's prose argument.

**Criteria checked (commit boundary):**
- Commit message format: `[SOURCE] TYPE(scope): Description` (deterministic regex — not LLM)
- No abbreviated code: `// ... rest of code` or equivalent
- No orchestrator replacement: if `n8n_workflows/` in payload, node count ≥ baseline
- No staging references: `local2local-staging` not present
- No hardcoded colours in Flutter: AdminColors or L2LColors only
- n8n HTTP Request body pattern: Raw body + Code node, not inline jsonBody expression
- Webhook nodes: `webhookId` field present
- Acceptance criteria coverage: each criterion from design intent addressed

**REVISE path:** Claude returns specific revision instructions. Gemini corrects and resubmits. Maximum 3 retries before ESCALATE.

**BLOCK path:** Reserved for security violations, orchestrator replacement attempts, secrets in code. Does not retry. Human notification only.

---

#### 45.9 — Intent Dispatcher (PENDING) — HORIZON 2

New n8n workflow (`L2LAAF: Intent Dispatcher`) activated when human selects a design intent. Fetches context files from GitHub, builds Gemini coding prompt, calls Gemini to generate a `logic_payload` bundle including the structured `ActionProposal`, writes to agent bus, feeds existing orchestrator.

Multi-file handling: bundles with more than 3 files are automatically split into sequential single-file intents by the dispatcher, each going through its own judge + HITL gate.

---

#### 45.10 — Autonomous Coding Loop Completion (PENDING) — HORIZON 2

Closes the feedback loop after HITL promotion. On PROMOTE:

1. Design intent marked `SATISFIED` in Firestore
2. Judge event written to `judge_events/{eventId}` with full decision record (see `documents/judge_layer_architecture.md`)
3. Lesson written to `lessons_learned` in `local2local-internal` with provenance label:
   - If human approved without override: `provenance: CONFIRMED`, `use_as: INSTRUCTION`
   - If human overrode a BLOCK or ESCALATE: `provenance: CONFIRMED`, `use_as: INSTRUCTION`, `human_override: true`
   - System-generated pattern recognition: `provenance: GENERATED`, `use_as: EVIDENCE`
4. Next `PENDING` intent surfaced as suggestion in Final Alert card

On SAVE IN DEV STACK: intent marked `DEFERRED`, judge event recorded with `human_outcome: SAVE_IN_DEV_STACK`, lesson written as `provenance: GENERATED`, `use_as: EVIDENCE`. The deferred commit remains on `develop` and is included in the next PROMOTE.

On ARCHIVE CHANGES: intent marked `ARCHIVED`, commit preserved in `archive/{phase_version}` branch, commit reverted on `develop` with `[skip ci]`, judge event recorded with `human_outcome: ARCHIVE_CHANGES`. Cherry-picking from the archive branch later enters the pipeline as a fresh commit.

**Human's role in the completed loop:**
1. Write or review design intent documents
2. Select next intent
3. Watch pipeline — Gemini codes → Gemini validates → Claude judges → HITL card
4. Read card: what was built, QA outcome (ALLOW/REVISE count/ESCALATE), impact tier, validator critique
5. PROMOTE TO PROD, SAVE IN DEV STACK, ARCHIVE CHANGES, REQUEST REVISION, or ESCALATE
6. System records, learns, suggests next intent

---

#### 45.11 — Judge Ops Dashboard (PENDING) — HORIZON 2

SuperAdmin dashboard panel for monitoring judge performance. Tracks metrics defined in `documents/judge_layer_architecture.md`: escalation rate, human override rate, revision success rate, BLOCK rate, latency per action class.

Alerts when metrics exceed thresholds — escalation rate > 20% signals criteria are too vague, human override rate > 5% signals judge too permissive.

---

#### 45.12 — Action-Level Judge Expansion (PENDING) — HORIZON 2

Extends judge layer to the next action boundaries beyond GitHub commit:

**Stripe API boundary (Phase 46 prerequisite):**
Every Stripe API call produces an `ActionProposal` evaluated by a Payment Judge before execution. Criteria: confirmed order linkage, amount within HBR bounds, idempotency key present, customer consent documented. Action class: `HIGH_STAKES`.

**Production Firestore write boundary (Phase 46-47 prerequisite):**
Writes to `local2local-prod` collections require `ActionProposal` evaluated by a Data Judge. Criteria: schema compliance, snake_case field naming, no PII in non-PII fields, regulatory data handling. Action class: `EXTERNAL_IMPACT`.

**Scraped data ingestion boundary (Phase 48 prerequisite):**
Scraped data entering `unclaimed_listings/` evaluated by a Quality + Safety Judge. Criteria: data quality score, source reliability, adversarial content screening (scraped data can contain prompt injection). Claimed listing merge evaluated separately as `EXTERNAL_IMPACT`. Action class: `REVERSIBLE_WRITE` → `EXTERNAL_IMPACT` on merge.

---

### Phase 46: Payments Infrastructure (Stripe Connect) — HORIZON 2

Backend-first. Stripe API boundary judge (Phase 45.12) must be deployed before Stripe API calls are made in production.

**46.1** Platform account + `stripeWebhookHandler` Cloud Function + Firestore schema.
**46.2** Vendor onboarding — `connectStripeAccount` callable, Stripe Express onboarding, `STRIPE_ACCOUNT_CREATED` agent bus event.
**46.3** Payment intents — `createPaymentIntent` callable, platform fee via HBR, webhook handler for payment events.
**46.4** Payouts and reconciliation — nightly `payoutReconciliationAgent`, dispute and refund handling.

---

### Phase 47: Adding Marketplace Tenant — HORIZON 2

Framework phase producing reusable infrastructure for all three marketplaces.

**47.1** Tenant configuration schema — `artifacts/{tenantId}/config/`, HBR files for tax and regulatory rules.
**47.2** Claim-your-listing framework — `unclaimed_listings/`, `claimListing` callable, ownership verification.
**47.3** Scraping infrastructure — `marketplaceScraperV2` Cloud Function, Cloud Scheduler, per-tenant config.
**47.4** Tax and regulatory HBR setup — per-tenant HBR files, GST/PST/HST rules, category-specific regulation.

---

### Phase 48: Kaskflow Listing Population — HORIZON 2

Scraped data ingestion boundary judge (Phase 45.12) must be deployed before scraped data enters the system.

**Data sources:** AGLC liquor store registry, Alberta business registry, Google Places API, Yellow Pages.
**48.1** Liquor store scraping — AGLC registry, licence number as verified field.
**48.2** Non-liquor and services — Google Places + Alberta registry, deduplication.
**48.3** Refresh and maintenance — monthly scheduler, diff-based update, claimed listing divergence flagging.

---

### Phase 49: Kaskflow Marketplace UI/UX — HORIZON 3

Dreamflow-heavy. All UI uses `[DREAM]` method.

**49.1** Discovery and browsing — grid, filters, distance sort, map view, search.
**49.2** Product detail and seller contact — gallery, availability, chat.
**49.3** Cart and checkout — Riverpod cart, Stripe payment, age gate for liquor.
**49.4** Order management (buyer) — status timeline, dispute, reorder.
**49.5** Seller dashboard — order management, revenue, listing management, claim flow.

---

### Phase 50: Moonlitely Listing Population — HORIZON 3

**Data sources:** Eventbrite API, Ticketmaster Discovery, Google Places, Facebook Events, municipal calendars.
**50.1** Venue scraping. **50.2** Event scraping. **50.3** Performer scraping.

---

### Phase 51: Moonlitely Marketplace UI/UX — HORIZON 3

**51.1** Event discovery. **51.2** Event detail and ticketing. **51.3** Attendee experience. **51.4** Organiser dashboard.

---

### Phase 52: PROOF Marketplace Listing Population — HORIZON 3

SKU-level AGLC integration. **52.1** Product catalogue (weekly refresh). **52.2** Store inventory mapping. **52.3** Producer profiles.

---

### Phase 53: PROOF Marketplace UI/UX — HORIZON 3

**53.1** Product discovery with age gate. **53.2** Product detail with AGLC data. **53.3** Store locator. **53.4** Order and delivery with AGLC delivery regulation enforcement.

---

### Phase 54: Mobile — HORIZON 3

**54.1** iOS + Android build pipeline. **54.2** Mobile UX — FCM, camera, GPS, Apple/Google Pay. **54.3** HITL mobile buttons via `https://local2local.ca/chat-bot-hook`.

---

### Phase 55+: Advanced Autonomy — HORIZON 3

- System proposes its own design intents (Phase 45.7 provides the infrastructure)
- Autonomous pricing from Evolution Engine learning
- Fraud detection agent
- Cross-tenant unified seller profile
- Full AGLC/CRA regulatory automation
- Autonomous listing quality agent
- Market expansion agent

---

## Judge layer boundary expansion sequence

| Boundary | Action class | Phase | Judge | Status |
|---|---|---|---|---|
| GitHub commit | EXTERNAL_IMPACT | 45.1 | Gemini Validator + Claude QA | 45.1 partial, 45.8 full |
| Stripe API calls | HIGH_STAKES | 45.12 / 46 | Payment Judge | Planned |
| Production Firestore writes | EXTERNAL_IMPACT | 45.12 / 46-47 | Data Judge | Planned |
| Scraped data ingestion | REVERSIBLE_WRITE | 45.12 / 48 | Quality + Safety Judge | Planned |
| Claimed listing merge | EXTERNAL_IMPACT | 47-48 | Data Judge | Planned |
| Agent-to-agent handoffs | Varies | 55+ | Handoff Judge | Future |

---

## Tenant reference

| Tenant ID | Marketplace | Focus | Status |
|---|---|---|---|
| `local2local-kaskflow` | Kaskflow | Local goods, liquor, services | Infrastructure only |
| `local2local-moonlitely` | Moonlitely | Local entertainment and events | Infrastructure only |
| `local2local-proof` | PROOF | Liquor specialist (SKU-level AGLC) | Not started |

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
| `local2local-internal` | Governance hub (Registry, Policy, Vector DB, Lessons Learned) | Active |
| `n8n-bot-prod` | n8n chat handler service account host | Active |

---

## Development method reference

| Method | Source tag | Best for |
|---|---|---|
| Manual | `[MANUAL]` | Pipeline changes, infrastructure, bug fixes, doc updates |
| Assisted | `[ASSISTED]` | Multi-file backend changes, Cloud Functions, n8n workflows |
| Autonomous | `[AUTO]` | Agent-generated HBR refinements, intent-driven coding loop |
| Dreamflow | `[DREAM]` | Flutter UI/UX — screens, widgets, navigation, theme |
