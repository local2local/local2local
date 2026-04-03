L2LAAF Phase 36 Stabilization PayloadDELIMITER_PROTOCOL: V2.6_SAFE_FLATL2LAAF_BLOCK_START(text:COMMIT_MSG:COMMIT_MSG)feat(evolution): baseline phase 36 with corrected deploy.yml and diagnostic workersL2LAAF_BLOCK_ENDL2LAAF_BLOCK_START(yaml:GitHub Deploy Action:deploy.yml)name: L2LAAF Multi-Project Deploymenton:push:branches: [ main, staging, develop ]env:FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: truejobs:deploy:runs-on: ubuntu-latestenvironment:name: ${{ (github.ref_name == 'main' && 'Production') || (github.ref_name == 'staging' && 'Staging') || 'Development' }}steps:
  - name: Checkout Repository
    uses: actions/checkout@v4

  - name: Setup Node.js
    uses: actions/setup-node@v4
    with:
      node-version: '24'
      cache: 'npm'
      cache-dependency-path: functions/package-lock.json

  - name: Setup Flutter
    uses: subosito/flutter-action@v2
    with:
      channel: 'stable'
      flutter-version: '3.38.5'

  - name: Install Dependencies
    run: |
      cd functions && npm install
      cd ..
      flutter pub get

  - name: Build Flutter Web
    run: flutter build web --release

  - name: Authenticate to Google Cloud
    id: auth
    uses: google-github-actions/auth@v2
    with:
      credentials_json: ${{ secrets.GCP_SA_KEY }}

  - name: Install Firebase CLI
    run: npm install -g firebase-tools

  - name: Deploy to Target Project
    env:
      GOOGLE_APPLICATION_CREDENTIALS: ${{ steps.auth.outputs.credentials_file_path }}
    run: |
      if [[ "${{ github.ref_name }}" == "main" ]]; then
        PROJECT_ID="local2local-prod"
      elif [[ "${{ github.ref_name }}" == "staging" ]]; then
        PROJECT_ID="local2local-staging"
      else
        PROJECT_ID="local2local-dev"
      fi
      # Targeted deployment of all functions to ensure V2 diagnostic workers are live
      firebase deploy --only functions --project $PROJECT_ID --non-interactive --force
L2LAAF_BLOCK_ENDL2LAAF_BLOCK_START(typescript:Index:functions/src/index.ts)export * from "./logic/infrastructure";export * from "./logic/compliance";export * from "./logic/finance";export * from "./logic/orchestration";export * from "./logic/fulfillment";export * from "./logic/dispatch";export * from "./logic/ombudsman";export * from "./logic/analytics";export * from "./logic/treasury";export * from "./logic/evolution";export * from "./utilities/listSubcollections";export * from "./utilities/deleteSubcollection";L2LAAF_BLOCK_ENDL2LAAF_BLOCK_START(typescript:Evolution:functions/src/logic/evolution.ts)import { onDocumentUpdated } from "firebase-functions/v2/firestore";import { onRequest } from "firebase-functions/v2/https";import * as admin from "firebase-admin";const appIdStatic = "local2local-kaskflow";export const evolutionOnProposalV2 = onDocumentUpdated("artifacts/local2local-kaskflow/public/data/logic_proposals/{proposalId}",async (event) => {console.log("[EVOLUTION-V2] Wakeup: " + event.params.proposalId);const newData = event.data?.after.data();if (!newData) return;const status = (newData.status || "").toUpperCase();
if (status === "APPROVED" && newData.commit_pending === true) {
  const db = admin.firestore();
  const hbr = newData.hbrId || "UNKNOWN";
  try {
    const batch = db.batch();
    const lessonRef = db.collection("artifacts").doc(appIdStatic).collection("public").doc("data").collection("lessons_learned").doc();
    batch.set(lessonRef, {
      reasoning_vault: newData.reasoning_vault || {},
      applied_logic: newData.proposedLogic || "N/A",
      hbr_target: hbr,
      agent_id: newData.proposingAgentId || "SYSTEM",
      finalized_at: admin.FieldValue.serverTimestamp(),
      source_proposal: event.params.proposalId
    });
    const hbrRef = db.collection("artifacts").doc(appIdStatic).collection("public").doc("data").doc("hbr_registry").collection("registry").doc(hbr);
    batch.update(hbrRef, { lock_status: "IDLE", last_modified: admin.FieldValue.serverTimestamp() });
    batch.delete(event.data!.after.ref);
    await batch.commit();
    console.log("[EVOLUTION-V2] Success");
  } catch (e) { console.error("[EVOLUTION-V2] Error", e); }
}
});export const evolutionForceBaselineV2 = onRequest(async (req, res) => {const db = admin.firestore();try {await db.collection("artifacts").doc(appIdStatic).collection("public").doc("data").collection("lessons_learned").doc("baseline_ping").set({message: "Verified",timestamp: admin.FieldValue.serverTimestamp()});res.status(200).send("✅ Success");} catch (e: any) { res.status(500).send("❌ Fail: " + e.message); }});L2LAAF_BLOCK_END