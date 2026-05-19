# Phase 45.5 Three-Option HITL Gate Implementation Guide

## Pre-Test Setup
Seed the `deferred_phases` collection in Firestore (`local2local-dev`) with a mock document to simulate a stacked proposal waiting for promotion.
- **Path**: `artifacts/system_status/public/data/deferred_phases/mock_deferred`
- **JSON Payload**:
  ```json
  {
    "commit_sha": "mock_sha_123",
    "phase": "0.0.0",
    "status": "STACKED"
  }
  ```

## Test Step 1: PROMOTE TO PROD
- **Action**: Execute the promote path.
- **Method**: In Google Chat, click the "PROMOTE TO PROD" button on the HITL card, or trigger the Approval Listener test webhook manually via shell:
  ```
  curl -X GET "https://local2local.app.n8n.cloud/webhook-test/ea64f359-a428-46e4-9dc1-d5c643f385eb?action=approve&env=dev&build_id=mock_sha_123&phase=45.4.2&method=manual&summary=Test%20promote&bump_type=MINOR&hbrId="
  ```
- **Expected Result**:
  1. `Calculate New Version` outputs the bumped version (e.g. 45.5.0).
  2. `promoted_phases` record written to Firestore with `dev_stack` array populated.
  3. CI/CD polling loop (`Wait 10s` → `Poll Main GH Actions` → `Is Run Complete`) loops until the GitHub Action completes.
  4. `Final Alert` posts the "🚀 Promoted to PROD" confirmation card in Google Chat only after the GH Actions run concludes.

## Test Step 2: SAVE IN DEV STACK
- **Action**: Execute the save/defer path.
- **Method**: In Google Chat, click the "SAVE IN DEV STACK" button, or trigger via shell:
  ```
  curl -X GET "https://local2local.app.n8n.cloud/webhook-test/ea64f359-a428-46e4-9dc1-d5c643f385eb?action=save&env=dev&build_id=mock_sha_123&phase=45.4.2&method=manual&summary=Test%20save&bump_type=MINOR&hbrId="
  ```
- **Expected Result**:
  1. Execution routes down the `SAVE` branch of `HITL Decision Switch`.
  2. New record created in `deferred_phases` at `artifacts/system_status/public/data/deferred_phases/{auto-id}` with `status: "STACKED"`.
  3. Save Confirmation card posts to Google Chat with phase and commit SHA.

## Test Step 3: ARCHIVE CHANGES
- **Action**: Execute the archive/revert path.
- **Method**: In Google Chat, click the "ARCHIVE CHANGES" button, or trigger via shell:
  ```
  curl -X GET "https://local2local.app.n8n.cloud/webhook-test/ea64f359-a428-46e4-9dc1-d5c643f385eb?action=archive&env=dev&build_id=mock_sha_123&phase=45.4.2&method=manual&summary=Test%20archive&bump_type=MINOR&hbrId="
  ```
- **Expected Result**:
  1. Branch `archive/45.4.2` created on GitHub at the commit SHA.
  2. Revert commit pushed to `develop` with message containing `[skip ci]` — confirm no new pipeline run triggers.
  3. New record created in `archived_phases` with `archive_branch: "archive/45.4.2"` and `status: "ARCHIVED"`.
  4. Archive Confirmation card posts to Google Chat.

## Test Step 4: PROMOTE with Stacked Commits
- **Action**: Promote after multiple commits exist on `develop` ahead of `main`.
- **Method**:
  1. Ensure at least two commits exist on `develop` ahead of `main` (push a trivial change if needed).
  2. Trigger approval via shell using the SHA of the latest commit:
     ```
     curl -X GET "https://local2local.app.n8n.cloud/webhook-test/ea64f359-a428-46e4-9dc1-d5c643f385eb?action=approve&env=dev&build_id=<latest_sha>&phase=45.4.2&method=manual&summary=Test%20stacked&bump_type=MINOR&hbrId="
     ```
- **Expected Result**:
  1. Deployment card in Google Chat lists the Dev Stack Commits section (only visible when stack depth > 1).
  2. The pre-seeded `mock_deferred` document in `deferred_phases` (from Pre-Test Setup) is patched to `status: "PROMOTED"` with `promoted_in` set to the new version.

## Rollback Steps
If any test case fails, perform the following before retrying:
1. Delete any created Firestore test documents in `deferred_phases`, `archived_phases`, and `promoted_phases` via the Firestore console.
2. Delete any `archive/*` branches created on GitHub during testing.
3. If `main` was force-updated during a PROMOTE test, reset it to the prior SHA via:
   ```
   git push origin <prior_sha>:refs/heads/main --force
   ```
4. Revert `pubspec.yaml` on `develop` to version `45.4.2` if the version bump was written.