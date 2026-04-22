# Full-Stack Autonomous CI/CD Implementation Checklist

## Phase 41: The Monorepo & Telemetry Engine (COMPLETED)
**Goal:** Restructure the repository and funnel all environment errors into the `agent_bus`.

- [x] **Manual Bootstrap:** Verify repository structure (Flutter at root, `functions/` alongside it). Create `/n8n_workflows`, `/buildship`, `/.github/workflows` as needed.
- [x] **Manual Bootstrap:** Verify Cloud Functions code is correctly placed in `/functions`.
- [x] **Autonomous (Option A):** Implement native Dart error catchers (`FlutterError.onError` and `PlatformDispatcher.instance.onError`) to make an HTTP POST to the new telemetry endpoint.
- [x] **Autonomous (Option A):** Deploy the `ingestWebError` Firebase Cloud Function to receive web errors and write them directly to the `agent_bus`.
- [x] **Autonomous:** Deploy the `ingestGCPErrors` Cloud Function to sink those into the `agent_bus`.
- [x] **Manual Bootstrap:** Configure GCP Log Router to push Error Reporting events to the `l2laaf-gcp-errors` Pub/Sub topic.

## Phase 42: Service Level Throttling & Superadmin Dashboard
**Goal:** Dynamically control deployment velocity based on live production health.

- [x] **Autonomous:** Define the Firestore schema and deploy the "Telemetry Aggregator" Cloud Function to continuously evaluate SLIs and update the `system_status` document.
- [ ] **Autonomous:** Update the n8n Orchestrator workflow to check `system_status` before processing `FUNCTIONALITY` intents (rate-limiting or blocking based on status).
- [ ] **Autonomous:** Scaffold the Flutter Superadmin Dashboard UI components to read and manually override the `system_status` document.

## Phase 43: Autonomous Generation & Dev Deployment
**Goal:** Inform the team, write the code, and auto-deploy to the dev environment sandbox.

- [ ] **Autonomous:** Update the n8n workflow to emit the "YELLOW" Informational Ping to Google Chat when a fix/feature is initiated.
- [ ] **Manual Bootstrap:** Create the `.github/workflows/deploy-dev.yml` Action to detect changes in `develop` and auto-deploy to the respective `local2local-dev` environments.
- [ ] **Manual Bootstrap:** Configure necessary GitHub Secrets (Firebase tokens, Buildship API keys, n8n API keys) for the Dev Action.

## Phase 44: Shadow Testing & The HITL Gate
**Goal:** Validate the deployment automatically and queue for human approval.

- [ ] **Autonomous:** Deploy the `Ombudsman Validator` logic to pause and monitor telemetry for 5-10 minutes post-deployment.
- [ ] **Autonomous:** Build the Success/Failure fork logic (Re-trigger Phase 43 on failure, or trigger Phase 45 on success).
- [ ] **Autonomous:** Update the n8n workflow to emit the "GREEN" Actionable Ping to Google Chat upon shadow run success.

## Phase 45: Production Promotion
**Goal:** Merge the code and deploy to the live environment upon human approval.

- [ ] **Manual Bootstrap:** Create a Personal Access Token (PAT) for GitHub to allow n8n to generate and merge Pull Requests.
- [ ] **Autonomous:** Update the n8n Orchestrator to create a PR from `develop` to `main`, auto-merge it, and format the Google Chat confirmation.
- [ ] **Manual Bootstrap:** Create the `.github/workflows/deploy-prod.yml` Action to detect merges to `main` and deploy to `local2local-prod`.
- [ ] **Manual Bootstrap:** Configure necessary GitHub Secrets for the Prod Action.