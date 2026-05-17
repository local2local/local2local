# Phase 45.3: Regulatory Drift Automation — Implementation Prompt

## Documents attached to this session

Attach all of the following documents to the Gemini session before sending this prompt:

1. `ai_context_rules.md` — (amended) hard rules for all AI work on this codebase
2. `project_plan.md` — (amended) full project plan with expanded Phase 45.3 specification
3. `judge_layer_architecture.md` — (amended) judge layer with bitemporal policy versioning
4. `l2laaf_full_specification.md` — (amended) system spec with HBR directory structure and Evolution Engine updates
5. `cicd_pipeline_reference.md` — (unchanged) CI/CD pipeline reference
6. `functions/src/logic/hbr/alcohol/ca_iila/rules.json` — federal IILA rules (populated)
7. `functions/src/logic/hbr/alcohol/ca_iila/policy.md` — federal IILA policy (populated)
8. `functions/src/logic/hbr/alcohol/ca_ab_aglc/rules.json` — Alberta AGLC rules (populated)
9. `functions/src/logic/hbr/alcohol/ca_ab_aglc/policy.md` — Alberta AGLC policy (populated)
10. `functions/src/logic/hbr/taxes/ca_cra/rules.json` — federal CRA GST rules (populated)
11. `functions/src/logic/hbr/taxes/ca_cra/policy.md` — federal CRA GST policy (populated)
12. `functions/src/logic/compliance.ts` — current compliance Cloud Function (provide from repo)

---

## Prompt

You are implementing Phase 45.3 — Regulatory Drift Automation for the L2LAAF system. Read all attached documents before proceeding. Pay particular attention to:

- **`ai_context_rules.md`** sections "HBR: Regulatory file versioning" and "HBR: Regulatory rules.json field requirements" — these are mandatory rules for all HBR changes
- **`project_plan.md`** Phase 45.3 — this is the full specification for what you are building, including the bitemporal versioning model, Firestore schema, drift agent monitoring scope, scheduled version activation, and deliverables list
- **`judge_layer_architecture.md`** section "Bitemporal HBR Versioning (Phase 45.3)" — this defines how the judge layer integrates with the versioning model
- **`l2laaf_full_specification.md`** sections 4.4 (Evolution Engine) and 8 (Regulatory HBR Directory Structure) — these define the HBR file conventions

### What has already been done

The six HBR files (3 `rules.json` + 3 `policy.md`) have been populated with real regulatory data sourced from AGLC, CRA, and IILA as of May 2026. Each `rules.json` already carries the bitemporal fields (`hbr_version`, `valid_from`, `status`, `decision_recorded_at`). These files are your baseline — the drift agent monitors for deviations from these values.

### What you are building

Per the deliverables list in Phase 45.3 of the project plan:

1. **`resolveHBR` Cloud Function** (TypeScript, 2nd Gen, Node.js 24)
   - Signature: `resolveHBR(ruleMaker: string, targetDate: Date): Promise<HBRVersion>`
   - Queries `artifacts/system_status/public/data/hbr_versions/{versionId}` in Firestore
   - Returns the HBR version where `status` is `ACTIVE` or `SCHEDULED`, `valid_from <= targetDate`, and `valid_until > targetDate` or `valid_until == null`
   - For current transactions, `targetDate` is now. For future-dated orders, `targetDate` is the fulfillment date
   - Must handle the case where both an `ACTIVE` and a `SCHEDULED` version exist for the same rule maker — `SCHEDULED` wins when `targetDate >= scheduled.valid_from`
   - Firestore field names use `snake_case` per the ai_context_rules
   - Every `Change` must use `<QueryDocumentSnapshot>`, every `params` must be `Record<string, string>` per the TypeScript rules in ai_context_rules

2. **Firestore `hbr_versions` collection — initial seed documents**
   - Generate the initial `hbr_versions` documents for all 3 rule makers based on the populated `rules.json` files
   - Each document must include the full `rules_snapshot` (the complete rules object from the corresponding `rules.json`)
   - Use the version ID format: `HBR-{RULE_MAKER}-001-v{VERSION}` (e.g. `HBR-AGLC-001-v1.0`)
   - All 3 initial versions have `status: ACTIVE`
   - Provide as Firestore test data in the format specified in ai_context_rules (PATH + JSON)

3. **Compliance monitoring n8n workflow**
   - Workflow name: `L2LAAF: Regulatory Drift Monitor`
   - Scheduled trigger: runs weekly (configurable per source)
   - For each monitored source (see the drift agent monitoring scope table in Phase 45.3):
     - HTTP Request node fetches the regulatory source page
     - Code node extracts relevant values (rates, thresholds, policy changes)
     - Code node compares extracted values against the active `rules_snapshot` from `hbr_versions`
     - If drift detected: posts a drift alert to the Google Chat space with details of what changed
     - If future-dated change detected: includes the announced effective date in the alert
   - Follow all n8n rules in ai_context_rules: HTTP Request body via Code node + Raw body, no Node.js globals in expressions, If nodes for binary routing, Code node mode/return format rules
   - Never replace the existing orchestrator — this is a separate workflow

4. **Scheduled version activation n8n workflow**
   - Workflow name: `L2LAAF: HBR Version Activator`
   - Schedule trigger: daily at 00:05 UTC
   - Queries `hbr_versions` for documents where `status == SCHEDULED` and `valid_from <= now`
   - For each match:
     - Updates the current `ACTIVE` version for that `rule_maker`/`region_scope` to `SUPERSEDED` with `valid_until` set
     - Updates the `SCHEDULED` version to `ACTIVE`
     - Posts activation notification to Google Chat
   - The on-disk `rules.json` update is a separate pipeline commit triggered after activation — this workflow only manages Firestore state

5. **Drift detection logic**
   - The comparison between scraped regulatory data and the active `rules_snapshot` must be value-level, not text-level. For example, if AGLC changes the spirits markup from $20.16/L to $20.50/L, the drift detector must identify the specific rule key (`markup_spirits_gt60_abv`), the old value, and the new value
   - Output format for drift alerts must include: rule maker, rule key, current value, detected value, source URL, and whether the change appears to be already in effect or future-dated

6. **HBR archive-before-update logic**
   - When a drift alert leads to an HBR update (after HITL confirmation), the pipeline must archive the current `ACTIVE` version as `SUPERSEDED` in Firestore before writing the new version
   - This logic can be implemented as a Code node in the drift monitor workflow or as a helper Cloud Function called by the workflow

7. **SuperAdmin dashboard panel** (specification only for this phase — UI implementation in Phase 45.4)
   - Define the data queries and layout for an HBR version timeline panel
   - Shows: all HBR versions by rule maker, status badges, valid date ranges, scheduled versions highlighted, drift alerts

### Constraints

- All code blocks must contain full file content — never use `// ... rest of code` or abbreviations
- Commit message format: `[ASSISTED] FEAT(compliance): Description [BUMP: MINOR]`
- `pubspec.yaml` is the only version source of truth — never write version to `state.json`
- Target Node.js 24 (2nd Gen Functions), TypeScript strict
- Firestore field names in `snake_case`, Dart model fields in `camelCase`
- All n8n workflow changes are additive — never replace existing workflows
- The `resolveHBR` function must handle edge cases: no active version found, multiple scheduled versions for the same date, overlapping valid ranges

### Delivery method

This is an Assisted method delivery. Generate the logic payload as `logic_payload.js` per the Assisted Method rules in ai_context_rules. The payload should contain L2LAAF_BLOCK sections for:

- `functions/src/logic/compliance.ts` (updated)
- `functions/src/logic/resolveHBR.ts` (new)
- `functions/src/logic/hbr/types.ts` (new — TypeScript interfaces for HBRVersion, HBRRule, etc.)
- Any additional Cloud Function files needed

The n8n workflows should be provided as complete JSON files, not as part of the logic payload.

Per Rule 2 — request the current file contents before generating code. You already have the HBR files. You still need `functions/src/logic/compliance.ts` from the developer.
