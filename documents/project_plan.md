# L2LAAF Project Plan

**Current version:** 45.1.3
**System status:** 🟢 OPERATIONAL
**Tech stack:** Flutter 3.38.5 + Node.js 24 (2nd Gen Firebase Functions) + TypeScript

---

## How this plan works

This document is the single shared roadmap for all development work on L2LAAF. It is read by Claude AI, Google Gemini, and the developer at the start of every session. Changes to the plan are committed before the implementation commits that follow them — this creates a clear audit trail of why the codebase evolved the way it did.

**Three planning horizons:**
- **Horizon 1 — Active phase:** fully specified, being built now
- **Horizon 2 — Next 2-3 phases:** planned with enough detail to make architectural decisions today that won't need to be undone later
- **Horizon 3 — Future phases:** directional intent and sequence only — no implementation detail until a phase moves to Horizon 2

Mid-course corrections are committed as `[MANUAL] CHORE(docs): Update project plan — [reason]` before any implementation changes.

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
Full automated deploy-to-dev, human-approve, promote-to-prod system. See `documents/cicd_pipeline_reference.md` and `documents/cicd_master_checklist.md`.

Key outcomes: automatic version bumping from `pubspec.yaml`, four development methods (MANUAL/ASSISTED/AUTO/DREAM), HITL gate via Google Chat, relay.sh v6.4 with targeted n8n workflow cleanup, Upstream Relay mechanism.

### Phase Group 5: SuperAdmin Dashboard (Phase 44) — COMPLETED
**Final version:** 44.4.4

Two-page dashboard (Phases page + Data page) with:
- Telemetry banner (GREEN/YELLOW/RED)
- Promoted and abandoned phase history with ID-based streaming counter
- Multi-tenant agent bus viewer (SYSTEM / KASKFLOW / MOONLITELY) with AGENT BUS / SHADOW BUS toggle
- Generic data browser across 18 known Firestore collections
- Agent bus injection UI with Raw JSON editor, Structured form, and Template library
- DEV/PROD environment switcher wired to live providers

---

## Active and upcoming phases

---

### Phase 45: Advanced Intelligence — IN PROGRESS
**Current sub-phase:** 45.1 complete (45.1.3)

---

#### 45.1 — Multi-Agent Consensus ✅ COMPLETE
Impact Classifier and Validator Agent nodes inserted into the HITL path of both DEV and PROD orchestrators. Every deployment is classified as HIGH_IMPACT or ROUTINE by Gemini 2.5 Flash. HIGH_IMPACT changes receive a Gemini risk assessment in the Google Chat HITL card under "Impact Assessment".

New orchestrator nodes (between Throttle Switch and Google Chat Card):
- `Impact Classifier` — classifies change as HIGH_IMPACT or ROUTINE
- `Extract Impact` — parses response, defaults to ROUTINE on failure
- `Impact Switch` — If node routing HIGH_IMPACT vs ROUTINE
- `Prepare Validator Prompt` — Code node building Gemini request body via `JSON.stringify`
- `Validator Agent` — produces 1-2 sentence risk assessment
- `Extract Critique` — parses response, merges into card data

---

#### 45.2 — Semantic Retrieval (PENDING)
Agents query the `lessons_learned` collection in `local2local-internal` via vector search before proposing changes. When an agent encounters a new HBR decision point, it retrieves semantically similar past decisions to inform its reasoning.

Requires:
- Vertex AI text-embedding-004 pipeline writing embeddings to `local2local-internal`
- Similarity search Cloud Function (`semanticRetrievalV1`)
- n8n orchestrator node inserted before Gemini Code Fixer to enrich context with retrieved lessons

---

#### 45.3 — Regulatory Drift Automation (PENDING)
Compliance monitoring agent tracks AGLC and CRA regulatory source documents. When regulatory content changes, the agent detects drift from current system HBRs and proposes corrective updates through the standard Evolution Engine pipeline.

---

#### 45.4 — Design Intent Infrastructure (PENDING) — HORIZON 2

Establishes the structured input format that allows the human operator to incrementally feed design specifications into the autonomous coding pipeline one unit of work at a time.

**Firestore schema — `design_intents/{intentId}`:**
```json
{
  "intent_id": "INT-046-001",
  "phase": "46.1",
  "title": "Stripe webhook handler Cloud Function",
  "method": "ASSISTED",
  "target_files": ["functions/src/stripe/webhookHandler.ts"],
  "description": "Natural language description of what to build",
  "acceptance_criteria": [
    "Verifies Stripe webhook signature before processing",
    "Handles payment_intent.succeeded and payment_intent.payment_failed",
    "Writes to orders/{orderId} on success"
  ],
  "context_files": [
    "functions/src/logic/treasury.ts",
    "documents/firestore_schema.md"
  ],
  "firestore_collections_affected": ["orders", "payment_intents"],
  "bump_type": "MINOR",
  "status": "PENDING",
  "created_at": "...",
  "satisfied_at": null,
  "result_phase": null
}
```

Status lifecycle: `PENDING` → `IN_PROGRESS` → `SATISFIED` | `ABANDONED`

**SuperAdmin dashboard panel (Dreamflow):**
- Intent queue view: list of PENDING intents with phase, title, method, acceptance criteria
- Create intent form: fields matching schema above with validation
- Intent detail: full spec, status, result phase link, lessons learned reference
- Select button: marks intent `IN_PROGRESS` and triggers the Intent Dispatcher (45.6)

The human operator writes intent documents and selects which one to process next. This is the primary mechanism for directing autonomous development work.

---

#### 45.5 — Claude QA Integration (PENDING) — HORIZON 2

Integrates Claude API as an automated QA review step in the n8n orchestrator, between code generation and the HITL gate. Claude reviews every autonomously generated bundle against known failure modes before the human sees it.

**New orchestrator nodes (inserted after Gemini Code Fixer, before Google Chat Card):**

1. `Prepare QA Prompt` (Code node) — builds the Claude API request body:
```javascript
const bundle = $json.generatedBundle;
const intent = $json.intent;
const body = JSON.stringify({
  model: "claude-opus-4-5",
  max_tokens: 2000,
  messages: [{
    role: "user",
    content: `Audit this logic_payload bundle...`
  }]
});
return { json: { ...$json, qaBody: body } };
```

2. `Claude QA Agent` (HTTP Request node, Raw body) — calls `https://api.anthropic.com/v1/messages`
   - Header: `x-api-key: {{ $json.claudeApiKey }}`
   - Header: `anthropic-version: 2023-06-01`
   - Body: `{{ $json.qaBody }}`

3. `Extract QA Result` (Code node) — parses Claude response, extracts CLEARED/BLOCKED verdict and issue list

4. `QA Gate` (If node) — routes CLEARED to HITL card, BLOCKED to Gemini correction pass

5. `Prepare Correction Prompt` (Code node, BLOCKED path) — builds a new Gemini prompt combining the original intent + Claude's specific issues

6. `Retry Counter` (Code node) — tracks correction attempts, escalates to human after 3 failed passes

**QA checklist Claude evaluates against:**
- No abbreviated code (`// ... rest of code` or equivalent)
- No orchestrator replacement if bundle contains `n8n_workflows/`
- Valid commit message format: `[SOURCE] TYPE(scope): Description`
- No version prefix in commit message
- No references to `local2local-staging`
- No hardcoded hex colours in Flutter (must use AdminColors or L2LColors)
- n8n HTTP Request nodes calling external APIs use Raw body + Code node pattern
- Webhook nodes in n8n JSON have `webhookId` fields
- All acceptance criteria from the design intent addressed

**The HITL card** gains a new field: `QA Status` showing CLEARED (with Claude's notes if any) or the correction pass count if issues were found and auto-corrected.

---

#### 45.6 — Intent Dispatcher (PENDING) — HORIZON 2

A new n8n workflow (separate from the main orchestrator) that activates when the human selects an intent in the SuperAdmin dashboard. It fetches context, calls Gemini to generate the code bundle, and feeds the result into the existing orchestrator pipeline.

**Workflow: `L2LAAF: Intent Dispatcher`**

```
Intent Selected (Firestore trigger or webhook)
    → Fetch Intent Document (Firestore read)
    → Fetch Context Files (GitHub Contents API — one call per context_file)
    → Prepare Gemini Coding Prompt (Code node)
        Combines: intent spec + acceptance criteria + current file content
    → Gemini Bundle Generator (HTTP Request → Gemini API)
        Instructs Gemini to produce a complete logic_payload.txt bundle
        with L2LAAF_BLOCK sections, COMMIT_MSG, and full file content
    → Extract Bundle (Code node — parse Gemini response)
    → Write to Agent Bus (Firestore write)
        event: CODING_PROPOSAL
        payload.manifest.generatedBundle: <bundle content>
        payload.manifest.intentId: <intent_id>
    → Existing MCP Code Payload webhook fires
    → Main orchestrator handles: State Manager → Throttling → Consensus → Claude QA → HITL
```

**Multi-file handling:** The Intent Dispatcher generates a single bundle with multiple `L2LAAF_BLOCK` sections. `patcher.js` already supports this. The pipeline commits and deploys all files in one operation. For intents with more than 3 files, the dispatcher breaks the intent into sequential sub-intents automatically, each going through its own HITL gate.

---

#### 45.7 — Autonomous Coding Loop Completion (PENDING) — HORIZON 2

Closes the feedback loop after a successful HITL promotion.

**On PROMOTE TO PROD, the orchestrator additionally:**
1. Marks the source design intent `SATISFIED` in Firestore, records `result_phase` and `satisfied_at`
2. Writes a `lessons_learned` entry to `local2local-internal` combining the intent, the generated solution, and the Claude QA clearance notes — this feeds Phase 45.2 semantic retrieval
3. Posts a summary to the SuperAdmin dashboard intent queue showing the satisfied intent and the resulting phase number
4. Surfaces the next `PENDING` intent (ordered by phase) as a suggestion in the Google Chat Final Alert card: `"Next suggested intent: INT-046-002 — Vendor Stripe onboarding function"`

**On KEEP IN DEV:**
1. Marks the intent `ABANDONED` with the correction pass count and Claude QA issues
2. Human can re-open the intent, revise the acceptance criteria, and resubmit

**Human's role in the completed loop:**
1. Write design intent documents (or review AI-proposed intents in Phase 55+)
2. Select next intent in SuperAdmin dashboard
3. Watch pipeline — Gemini codes → Claude reviews → HITL card arrives
4. Read HITL card: what was built, QA status, impact level, validator critique
5. PROMOTE or KEEP IN DEV
6. Repeat from step 2

---

#### 45.8 — Semantic Retrieval for Intent Generation (PENDING) — HORIZON 3

Once 45.2 (Semantic Retrieval) and 45.7 (feedback loop) are complete, the system can propose its own design intents based on patterns in `lessons_learned`, telemetry anomalies, and HBR drift signals. The human reviews proposed intents and approves/rejects them before they enter the queue. This is the first step toward the system directing its own evolution within human-set boundaries.

---

### Phase 46: Payments Infrastructure (Stripe Connect) — HORIZON 2

Backend-first. No marketplace UI until the payment layer is solid. All work uses ASSISTED or MANUAL methods. Each sub-phase maps to one or more design intent documents (Phase 45.4 format) that feed the autonomous coding loop.

**46.1 — Platform account setup**
Stripe Connect platform account wired to `local2local-prod`. `stripeWebhookHandler` Cloud Function with signature verification. Firestore schema: `stripe_accounts/{sellerId}`, `payment_intents/{orderId}`, `payouts/{payoutId}`.

**46.2 — Vendor onboarding**
`connectStripeAccount` callable Cloud Function. Stripe Connect Express onboarding URL generation. Webhook handler for `account.updated`. Agent bus event `STRIPE_ACCOUNT_CREATED`.

**46.3 — Payment intents**
`createPaymentIntent` callable Cloud Function with platform application fee (configurable per tenant via HBR). Webhook handler for `payment_intent.succeeded` and `payment_intent.payment_failed`. Order status updates.

**46.4 — Payouts and reconciliation**
`payoutReconciliationAgent` Cloud Function. Nightly reconciliation of Stripe payout records against Firestore orders. Dispute and refund handling.

---

### Phase 47: Adding Marketplace Tenant — HORIZON 2

Framework phase — runs once per marketplace, produces reusable infrastructure. Kaskflow, Moonlitely, and PROOF each go through this process.

**47.1 — Tenant configuration schema**
`artifacts/{tenantId}/config/tenant_config` Firestore document. HBR files for tax rules (GST/PST/HST), platform fee percentage, and category-specific regulatory rules.

**47.2 — Claim-your-listing framework**
`unclaimed_listings/{listingId}` Firestore collection. `claimListing` callable Cloud Function transferring ownership. Email notification on listing creation. Ownership verification step. Agent bus event `LISTING_CLAIMED`.

**47.3 — Scraping infrastructure**
`marketplaceScraperV2` Cloud Function with Cloud Scheduler. Per-tenant scraper configuration in Firestore. Conflict detection for claimed listings where scraped data diverges from owner data.

**47.4 — Tax and regulatory HBR setup**
Per-tenant HBR files in `functions/src/logic/taxes/{tenantId}/`. GST (5%) universal. Province-specific PST/HST by geography. Category-specific rules (AGLC markup schedule, age gate).

---

### Phase 48: Kaskflow Listing Population — HORIZON 2

Scrape liquor, non-liquor, and services data for the Kaskflow marketplace.

**Data sources:** AGLC liquor store registry, Alberta business registry, Google Places API, Yellow Pages / Canada411.

**Categories:** Liquor retail (AGLC-licensed), specialty food, local services, artisan goods, farm-direct produce.

**48.1** Liquor store scraping — AGLC public registry. Licence number stored as verified field.
**48.2** Non-liquor and services scraping — Google Places + Alberta business registry. Deduplication on name + postal code.
**48.3** Refresh and maintenance — monthly Cloud Scheduler job. Diff against existing records. Claimed listing divergence flagging.

---

### Phase 49: Kaskflow Marketplace UI/UX — HORIZON 3

Dreamflow-heavy. All UI uses `[DREAM]` method.

**49.1** Discovery and browsing — product/service grid, category filters, distance sorting, map view, search.
**49.2** Product detail and seller contact — image gallery, availability, chat with seller.
**49.3** Cart and checkout — session-scoped Riverpod cart, Stripe payment sheet, age verification gate for liquor.
**49.4** Order management (buyer) — status timeline, dispute initiation, reorder.
**49.5** Seller dashboard — order management, revenue summary, listing management, claim flow.

---

### Phase 50: Moonlitely Listing Population — HORIZON 3

Scrape local entertainment data for the Moonlitely marketplace.

**Data sources:** Eventbrite API, Ticketmaster Discovery API, Google Places, Facebook Events, municipal event calendars (Edmonton, Calgary).

**50.1** Venue scraping — Google Places + Eventbrite venue data.
**50.2** Event scraping — Eventbrite and Ticketmaster API. Events linked to venue records.
**50.3** Performer scraping — extracted from event listings. Genre classification.

---

### Phase 51: Moonlitely Marketplace UI/UX — HORIZON 3

**51.1** Event discovery — grid and map view, date/category/genre filters, featured events.
**51.2** Event detail and ticketing — ticket tier selection, Stripe payment, QR code delivery.
**51.3** Attendee experience — My Tickets, QR display for venue scan, post-event review.
**51.4** Organiser dashboard — event creation, attendee management, revenue summary, discount codes.

---

### Phase 52: PROOF Marketplace Listing Population — HORIZON 3

PROOF is a dedicated liquor store marketplace with deeper AGLC integration at the SKU level.

**Data sources:** AGLC product catalogue (full SKU database, weekly refresh), AGLC licensee registry, distillery/winery/brewery public data.

**52.1** AGLC product catalogue scraping — SKU-level data, weekly refresh.
**52.2** Store inventory mapping — SKU availability per store. `store_inventory/{storeId}/{sku}` Firestore subcollection.
**52.3** Producer profiles — distillery, winery, brewery profiles from AGLC registry.

---

### Phase 53: PROOF Marketplace UI/UX — HORIZON 3

**53.1** Product discovery — browse by category, producer, region, price, ABV. "In stock near me" filter. Age gate on entry.
**53.2** Product detail — full AGLC data, producer profile, store availability map.
**53.3** Store locator — map view of licensed stores with in-stock product list.
**53.4** Order and delivery — click-and-collect and delivery (AGLC delivery regulations enforced via HBR). Age verification at delivery.

---

### Phase 54: Mobile — HORIZON 3

**54.1** Platform build pipeline — GitHub Actions matrix for web + iOS + Android. Bundle IDs per marketplace.
**54.2** Mobile UX — bottom navigation, FCM push notifications, camera for photos and QR scanning, GPS, Apple Pay / Google Pay.
**54.3** HITL mobile buttons — HTTP endpoint at `https://local2local.ca/chat-bot-hook` replacing current `openLink` pattern.

---

### Phase 55+: Advanced Autonomy — HORIZON 3

Directional only — specifics emerge from learnings across Phases 45-54.

- System proposes its own design intents based on telemetry, usage patterns, and HBR drift
- Autonomous pricing recommendations from Evolution Engine sales pattern learning
- Demand forecasting for inventory management
- Fraud detection agent on agent bus
- Cross-tenant unified seller profile (Kaskflow vendor also runs Moonlitely events)
- Full regulatory automation (AGLC/CRA filings from transaction data)
- Autonomous listing quality agent (detects and corrects stale scraped data)
- Market expansion agent (proposes new geographies from demand signals)

---

## Tenant reference

| Tenant ID | Marketplace | Focus | Status |
|---|---|---|---|
| `local2local-kaskflow` | Kaskflow | Local goods, liquor, and services | Infrastructure only |
| `local2local-moonlitely` | Moonlitely | Local entertainment and events | Infrastructure only |
| `local2local-proof` | PROOF | Liquor specialist (SKU-level AGLC) | Not started |

---

## Autonomous coding loop (Phase 45.4-45.7)

When complete, the human operator's role in each development cycle is:

1. Write design intent document in SuperAdmin dashboard (or review system-proposed intent)
2. Select next intent to process
3. Watch pipeline — Gemini codes → Claude QA reviews → HITL card arrives
4. Read card: what was built, QA status (CLEARED/BLOCKED+corrected), impact level, validator critique
5. PROMOTE TO PROD or KEEP IN DEV
6. System marks intent SATISFIED and suggests next intent

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

---

## Development method reference

| Method | Source tag | Best for |
|---|---|---|
| Manual | `[MANUAL]` | Pipeline changes, infrastructure, bug fixes, doc updates |
| Assisted | `[ASSISTED]` | Multi-file backend changes, Cloud Functions, n8n workflows |
| Autonomous | `[AUTO]` | Agent-generated HBR refinements, intent-driven coding loop |
| Dreamflow | `[DREAM]` | Flutter UI/UX — screens, widgets, navigation, theme |
