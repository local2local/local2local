# L2LAAF Judge Layer Architecture

**Status:** Active design — implemented at Phase 45.1, expanding through Phase 45.9
**Last updated:** 2026-05-14
**Reference:** Nate's Substack, "You gave your AI agent real tools. Here's the 4-part control layer it's missing" (May 2026)

---

## Overview

The Judge Layer is the control surface that decides whether an agent's proposed action should be allowed to execute. It is not the same as orchestration (which coordinates who does the work) or memory (which provides context). Its sole job is to decide whether a specific proposed action is authorized, supported, safe, and policy-compliant before it crosses a boundary into consequence.

The line between an agent demo and an agent product is not what the agent can do — it's how the surrounding system decides whether the agent should do it.

---

## The Core Principle: Proposals, Not Prose

The most important implementation detail from the reference paper: **the actor must produce a structured proposal, not a prose justification.** An actor that can win by writing a more persuasive paragraph will learn to over-justify. An actor forced to make structured claims about authorization, evidence, consequence, and rollback cannot game the system with confident language.

Every judged action boundary in L2LAAF uses a structured `ActionProposal` object. The judge evaluates the proposal's claims against explicit criteria, not the actor's overall tone or confidence.

### ActionProposal Schema

```typescript
interface ActionProposal {
  action_id: string;             // Unique ID for this proposal
  action_type: ActionClass;      // READ_ONLY | REVERSIBLE_WRITE | EXTERNAL_IMPACT | HIGH_STAKES
  intent_id?: string;            // Design intent this action satisfies (Phase 45.4)
  
  // What the actor wants to do
  description: string;           // Plain English statement of the action
  target: string;                // What is being acted on (file path, collection, endpoint)
  operation: string;             // CREATE | UPDATE | DELETE | SEND | DEPLOY | EXECUTE
  
  // Why the actor believes it is authorized
  authorization_source: string;  // Where the user authorized this (intent doc ID, HBR ID, or INFERRED)
  authorization_confidence: 'EXPLICIT' | 'INFERRED' | 'ASSUMED';
  
  // Supporting evidence
  evidence: string[];            // List of evidence items supporting the action
  hbr_references: string[];      // HBR IDs that govern this action
  hbr_versions: Record<string, string>; // HBR ID → version string
  
  // Consequence and reversibility
  expected_consequence: string;  // What will change if this executes
  reversible: boolean;           // Can this be undone?
  rollback_path?: string;        // How to undo it if reversible
  
  // Data sensitivity
  data_sensitivity: 'PUBLIC' | 'INTERNAL' | 'CONFIDENTIAL' | 'REGULATED';
  pii_involved: boolean;
  regulated_data: string[];      // e.g. ['AGLC_LICENCE_DATA', 'PAYMENT_DATA']
}
```

---

## Action Classification

All actions in L2LAAF are classified into four tiers. The tier determines which judges run and whether human review is required.

| Tier | Examples in L2LAAF | Judge requirement | Human requirement |
|---|---|---|---|
| `READ_ONLY` | Firestore reads, telemetry queries, log inspection, Git file fetch | None for standard reads; lightweight check for regulated data | None |
| `REVERSIBLE_WRITE` | Agent bus writes, state.json updates, internal Firestore writes (dev), branch changes | Lightweight validation or post-action audit | None for GREEN system |
| `EXTERNAL_IMPACT` | GitHub commits, n8n workflow deploys, external API calls, Stripe payment intents | Full judge — Authorization + Policy checks | HITL gate |
| `HIGH_STAKES` | Force update main, Stripe payouts, production Firestore deletes, AGLC-regulated data writes, permission changes | Full judge — all specialist judges | HITL gate required, cannot be bypassed |

The same action can move up a tier based on context. A Firestore write to `local2local-dev` is `REVERSIBLE_WRITE`. The same write to `local2local-prod` is `EXTERNAL_IMPACT`. A Stripe API call that creates a payment intent is `EXTERNAL_IMPACT`. One that initiates a payout is `HIGH_STAKES`.

---

## The Four-Outcome Decision

Judges never return a binary yes/no. Every judge returns one of four outcomes:

| Outcome | Meaning | Runtime behaviour |
|---|---|---|
| `ALLOW` | Proposal is authorized, evidenced, and policy-compliant | Execute the action |
| `BLOCK` | Proposal has a serious violation — security risk, policy breach, unauthorized action | Reject. Do not retry automatically. Notify human. |
| `REVISE` | Action is directionally correct but needs a specific change before execution | Return to actor with the required revision. Retry up to 3 times. |
| `ESCALATE` | Action is ambiguous, sensitive, irreversible, or high-impact beyond automated threshold | Route to human review queue. Pause pipeline. |

`REVISE` is the most important outcome for the autonomous coding loop. It allows the system to fix what it can fix automatically without requiring a human for every imperfect proposal. The revision instruction is specific and structured, not a vague "try again."

`BLOCK` is rare and reserved for clear violations: an orchestrator replacement attempt, a commit containing secrets, an action that has no authorization source other than `ASSUMED`. Block does not retry.

---

## Correlated Judgment Mitigation

The primary risk of same-model judging: actor and judge share blind spots. If Gemini codes and Gemini validates, the judge may become confidence-laundering — blessing what the actor already wanted to do, missing the same category error the actor made.

**L2LAAF mitigation strategy:**

1. **Model diversity at the highest-risk boundary.** Claude (Anthropic) serves as the QA judge for `EXTERNAL_IMPACT` and `HIGH_STAKES` actions. Gemini (Google) serves as the actor. Different model families, different training data, different architectural assumptions — correlated failure is structurally harder.

2. **Structured proposals, not prose.** The judge evaluates typed claims against explicit criteria, not the actor's overall argument. A Gemini-generated justification cannot win a Claude QA review by sounding confident.

3. **Deterministic policy checks.** Certain checks bypass LLM judgment entirely: commit message format validation (regex), node count comparison (integer comparison against baseline), webhookId presence (JSON path check). These are not gameable by either actor or judge.

4. **Specialist judges for critical domains.** The general Impact Classifier handles overall risk tier. Specialist checks (authorization, privacy, policy) handle domain-specific criteria. No single judge carries the full burden.

---

## Judge Placement in L2LAAF

Judges are placed at action boundaries — the exact points where the system crosses from language into consequence. There is one boundary active today and a defined sequence for expansion.

### Active boundary: GitHub commit (EXTERNAL_IMPACT)

```
Design Intent → Gemini Actor generates ActionProposal + code bundle
    → Impact Classifier (Gemini) — tier classification
    → Extract Impact — parse and default
    → Impact Switch — route by tier
    
    HIGH_STAKES / EXTERNAL_IMPACT:
        → Prepare Validator Prompt (Code node — structured proposal)
        → Validator Agent (Gemini) — authorization + evidence check
        → Extract Critique — parse response
        → Prepare QA Prompt (Code node — structured proposal)
        → Claude QA Agent (Claude Opus) — policy + quality + correlated-failure check
        → Extract QA Result — ALLOW / BLOCK / REVISE / ESCALATE
        → QA Gate (If node)
            ALLOW / ESCALATE → Google Chat HITL card (4 buttons)
            REVISE → Gemini Correction Pass (up to 3 retries)
            BLOCK → Block Alert → Human notification
    
    REVERSIBLE_WRITE:
        → Lightweight audit log only
        → Google Chat HITL card (standard)
```

### Planned boundary: Stripe API (HIGH_STAKES)
Phase 46. Every Stripe API call that creates or modifies a financial record requires an ActionProposal evaluated by a Payment Judge before the API call executes. Judge criteria: payment authorization (is this linked to a confirmed order?), amount bounds (within HBR-defined limits?), idempotency key presence, customer consent evidence.

### Planned boundary: Production Firestore writes (EXTERNAL_IMPACT)
Phase 46-47. Writes to `local2local-prod` collections (`orders/`, `stripe_accounts/`, `payouts/`) require an ActionProposal evaluated by a Data Judge. Criteria: schema compliance, field naming (snake_case), no PII in non-PII fields, regulatory data handling (AGLC, CRA).

### Planned boundary: Scraped data ingestion (REVERSIBLE_WRITE → EXTERNAL_IMPACT)
Phase 48. Scraped data entering `unclaimed_listings/` is a REVERSIBLE_WRITE. Scraped data being merged into a claimed listing is EXTERNAL_IMPACT (affects the owner's listing). Judge criteria: data quality score, source reliability, field conflict with owner-provided data.

---

## Memory Provenance

The paper's most critical point for L2LAAF: **agent-generated lessons must be evidence, not instruction.** Once the Lessons Learned vault is queried by semantic retrieval (Phase 45.2), retrieved lessons can silently become future instructions for agents. Without provenance, the system cannot distinguish between what was confirmed by a human and what was inferred by an agent.

### Provenance labels for `lessons_learned` entries

Every document written to `local2local-internal/lessons_learned/` carries a `provenance` field:

| Label | Meaning | Can be used as... |
|---|---|---|
| `OBSERVED` | Directly recorded from a human action (e.g. human manually approved a commit) | Instruction |
| `CONFIRMED` | Agent-generated, explicitly confirmed by human operator | Instruction |
| `INFERRED` | Agent-generated, derived from patterns, not confirmed | Evidence only |
| `GENERATED` | Agent-generated from a model call, no human review | Evidence only |
| `DISPUTED` | Human has indicated this lesson is incorrect | Do not use |
| `SUPERSEDED` | Replaced by a newer lesson | Do not use |

**Firestore schema addition for `lessons_learned`:**

```json
{
  "lesson_id": "LL-045-001",
  "content": "When the Impact Classifier receives a commit touching n8n_workflows/, it should classify as EXTERNAL_IMPACT regardless of file size.",
  "provenance": "CONFIRMED",
  "source_type": "JUDGE_DECISION",
  "source_event_id": "JE-045-112",
  "intent_id": "INT-045-003",
  "result_phase": "45.1.3",
  "human_confirmed_at": "2026-05-14T11:24:00Z",
  "confirmed_by": "todd.herron@local2local.ca",
  "created_at": "2026-05-14T11:20:00Z",
  "use_as": "INSTRUCTION",
  "tags": ["n8n", "orchestrator", "impact_classification"]
}
```

When Phase 45.2 (Semantic Retrieval) queries `lessons_learned`, it filters by `use_as: INSTRUCTION` for lessons it can act on directly, and `use_as: EVIDENCE` for lessons it can reference but must not treat as policy.

---

## Judge Events: Audit Trail

Every judgment decision is stored in `artifacts/system_status/public/data/judge_events/{eventId}`:

```json
{
  "event_id": "JE-045-112",
  "timestamp": "2026-05-14T11:20:00Z",
  "action_proposal": { ... },
  "judge": "CLAUDE_QA",
  "outcome": "ALLOW",
  "verdict": "Code structure correct. Commit message format valid. No orchestrator replacement detected. No abbreviated content.",
  "criteria_checked": ["commit_format", "no_abbreviation", "no_orchestrator_replacement", "no_staging_refs"],
  "criteria_failed": [],
  "hbr_versions_at_decision": { "HBR-N8N-001": "v2.1", "HBR-COMMIT-001": "v1.3" },
  "memory_used": ["LL-045-001", "LL-043-007"],
  "human_outcome": "PROMOTE_TO_PROD",
  "human_override": false,
  "latency_ms": 1847,
  "model": "claude-opus-4-5"
}
```

This creates the operational data needed to improve the judge over time: false allow rate, false block rate, revision rate, escalation rate, human override rate by action class and judge.

---

## Judge Performance Metrics

Track these in the SuperAdmin dashboard (Phase 45.4 dashboard panel):

| Metric | Target | Action if exceeded |
|---|---|---|
| Escalation rate | < 20% of actions | Judge criteria too vague — tighten |
| Human override rate (judge allowed, human rejected) | < 5% | Judge too permissive — review criteria |
| Human override rate (judge blocked/escalated, human approved) | < 10% | Judge too conservative — review criteria |
| Revision success rate (revision fixed the issue) | > 80% | If lower — actor not incorporating feedback |
| BLOCK rate | < 2% | If higher — actor generating bad proposals |
| Avg latency per judged action | < 5s | If higher — consider lightweight checks for lower tiers |

---

## Policy Versioning

Judge prompts encode policy at a point in time. When HBRs change, judge prompts must explicitly update. Without versioning, the system silently runs stale judgment.

Every HBR file in `functions/src/logic/` has a version field in its header comment:
```typescript
/**
 * HBR-N8N-001: n8n Orchestrator Integrity Rules
 * Version: 2.1
 * Last updated: 2026-05-14
 * Governs: All n8n workflow changes
 */
```

Every judge prompt references specific HBR versions:
```
"You are evaluating this action against HBR-N8N-001 v2.1 and HBR-COMMIT-001 v1.3.
If the action complies with both, return ALLOW..."
```

When an HBR version increments, the affected judge prompts are updated in the same commit. The `judge_events` record captures `hbr_versions_at_decision` so decisions can be audited against the policy that was in effect at the time.

### Bitemporal HBR Versioning (Phase 45.3)

Regulatory HBR files (tax, alcohol, trade policy) require a stronger versioning model than code-level HBRs because:

1. **Regulators publish future-dated changes.** A new AGLC markup rate announced in February with an April 1 effective date must coexist with the current rate until the effective date arrives.
2. **Transactions must be auditable against the rules that governed them.** CRA may ask what GST rate was applied to a specific order on a specific date.
3. **Future-dated rules can be amended or revoked before taking effect.** The system must handle a scheduled rule being pushed back, modified, or withdrawn entirely.

The bitemporal model adds two time dimensions to every regulatory HBR version:

- **Valid time** (`valid_from` / `valid_until`): when the rule governs transactions in the real world. This is the regulatory effective date, not the deployment date.
- **Decision time** (`decision_recorded_at`): when the system first recorded the rule. Required for audit to prove what the system knew at any given point.

Every regulatory HBR version carries a `status` field:

| Status | Meaning | Judge behaviour |
|---|---|---|
| `ACTIVE` | Currently governing | Judge evaluates against this version for current actions |
| `SCHEDULED` | Published with future effective date | Judge evaluates against this version only for actions with a future target date ≥ `valid_from` |
| `SUPERSEDED` | Replaced by a newer version | Judge references only for historical audit of past decisions |
| `REVOKED` | Withdrawn before taking effect | Judge ignores; retained for audit trail |
| `AMENDED` | Modified before taking effect; replaced by corrected `SCHEDULED` version | Judge ignores; retained for audit trail |

**Judge integration:** When a judge evaluates an `ActionProposal` involving a regulated domain (tax calculation, alcohol compliance, delivery eligibility), it must resolve the applicable HBR version using the transaction's target date, not the current system time. The `hbr_versions_at_decision` field in `judge_events` records the resolved version IDs, linking the judgment to the exact policy state that was in effect.

**Drift-triggered judge prompt updates:** When the Regulatory Drift Automation agent (Phase 45.3) proposes a new HBR version, the judge prompts that reference that HBR must be updated in the same commit. The `SCHEDULED` → `ACTIVE` promotion workflow (daily cron) also triggers judge prompt updates if the newly active version changes any criteria the judge evaluates.

See `project_plan.md` Phase 45.3 for the full Firestore schema, version lifecycle, and drift agent specification.

---

## What to Build First

The paper's practical guidance: one workflow, one real action boundary, one proposal format, one judge, one eval set, one write-back loop.

L2LAAF has already done this. The GitHub commit boundary has a judge (Phase 45.1), a four-outcome routing structure (planned Phase 45.5), and a write-back loop (planned Phase 45.7).

**The expansion sequence:**

1. ✅ GitHub commit boundary (Phase 45.1) — EXTERNAL_IMPACT, Gemini + Claude judges
2. 🔲 Claude QA as formal judge with four outcomes (Phase 45.5)
3. 🔲 Structured ActionProposal in agent bus payload (Phase 45.4 update)
4. 🔲 Memory provenance for lessons_learned (Phase 45.7 update)
5. 🔲 Judge events audit collection (Phase 45.9)
6. 🔲 Stripe API boundary (Phase 46) — HIGH_STAKES, payment judge
7. 🔲 Production Firestore write boundary (Phase 46-47) — EXTERNAL_IMPACT, data judge
8. 🔲 Scraped data ingestion boundary (Phase 48) — REVERSIBLE_WRITE → EXTERNAL_IMPACT, quality + safety judge

The contract established at boundary 1 (proposal format, judge criteria, eval harness, write-back pattern) travels to every subsequent boundary. Each new boundary is easier than the last because the infrastructure already exists.
