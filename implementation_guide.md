# Phase 45.6 HITL Acknowledgment Cards & Dev-Stack Bump Type Derivation

## Pre-Test Setup
No Firestore seeding required. Ensure the DEV n8n orchestrator has been updated
to Phase 45.6 (confirmed by the Sticky Note version in the n8n workflow editor).

## Test Step 1: Bump type derivation — MINOR overrides PATCH trigger
- **Action**: Push a MINOR-tagged commit followed by a PATCH-tagged (or untagged) trigger commit. Verify the HITL card uses MINOR, not PATCH.
- **Method**:
  ```
  git commit --allow-empty -m "[MANUAL] FEAT(test): Minor feature test [BUMP: MINOR]"
  git push origin develop
  # Wait for HITL card, then push a bare trigger:
  git commit --allow-empty -m "[MANUAL] CHORE(pipeline): Trigger re-deploy"
  git push origin develop
  ```
- **Expected Result**:
  1. HITL card header shows `Release Candidate: X.X.X → MINOR bump` (not PATCH).
  2. The PROMOTE TO PROD button URL contains `bump_type=MINOR`.
  3. On promotion, pubspec.yaml bumps the MINOR segment (e.g. 45.4.4 → 45.5.0).

## Test Step 2: PROMOTE TO PROD acknowledgment card
- **Action**: On any HITL card, click PROMOTE TO PROD.
- **Method**: Click the green PROMOTE TO PROD button in Google Chat.
- **Expected Result**:
  1. Within ~5 seconds, a `⏳ L2LAAF Deployment: Phase X acknowledged` card appears in Google Chat confirming the promotion was queued.
  2. 4–6 minutes later (after GH Actions completes), the `🚀 Promoted to PROD` Final Alert card appears.
  3. If GH Actions fails, the `❌ PROD Deploy Failed` error card appears instead of the Final Alert.

## Test Step 3: ARCHIVE CHANGES cherry-pick reference
- **Action**: On a HITL card, click ARCHIVE CHANGES.
- **Method**: Click the red ARCHIVE CHANGES button in Google Chat.
- **Expected Result**:
  1. Archive Confirmation card appears with the commit SHA and the cherry-pick command:
     `git cherry-pick <build_id>`
  2. The archive branch reference `archive/<phase>` is shown.
  3. The revert commit on develop contains `[skip ci]` — no new pipeline run triggers.

## Rollback Steps
If any test step fails before the HITL gate fires:
1. Restore the Phase 45.5 orchestrator by re-running relay.sh with the previous logic_payload.txt.

If the HITL gate fires but behaves incorrectly, click ARCHIVE CHANGES to revert on develop, then restore Phase 45.5 via relay.sh.