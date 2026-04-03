L2LAAF Phase 36 Master Stabilization (v6.0)PROTOCOL: NASA_STANDARD_V6.0_STRICT_TYPING_FINALIZEDL2LAAF_BLOCK_START(text:COMMIT_MSG:COMMIT_MSG)feat(evolution): baseline phase 36 master suite 100% lint-free restoration with strict genericsL2LAAF_BLOCK_ENDL2LAAF_BLOCK_START(yaml:Deploy Action:.github/workflows/deploy.yml)name: L2LAAF Multi-Project Deploymenton:push:branches: [ main, staging, develop ]env:FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: truejobs:deploy:runs-on: ubuntu-latestenvironment:name: ${{ (github.ref_name == 'main' && 'Production') || (github.ref_name == 'staging' && 'Staging') || 'Development' }}steps:
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
      firebase deploy --only functions --project $PROJECT_ID --non-interactive --force
L2LAAF_BLOCK_ENDL2LAAF_BLOCK_START(typescript:Evolution:functions/src/logic/evolution.ts)import { onDocumentWritten, onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";import { onRequest } from "firebase-functions/v2/https";import type { FirestoreEvent, Change, QueryDocumentSnapshot } from "firebase-functions/v2/firestore";import type { Request, Response } from "firebase-functions/v1";import * as admin from "firebase-admin";import { FieldValue } from "firebase-admin/firestore";import { db } from "../config";import { AgentBusClient } from "../agentBusClient";const appIdStatic = "local2local-kaskflow";function areResultsIdentical(a: any, b: any): boolean {try {const s1 = JSON.stringify(a || {}, Object.keys(a || {}).sort());const s2 = JSON.stringify(b || {}, Object.keys(b || {}).sort());return s1 === s2;} catch (e) {return false;}}export const evolutionOrchestratorV2 = onDocumentWritten({document: "artifacts/{appId}/public/data/agent_bus/{messageId}",memory: "512MiB"}, async (event: FirestoreEvent<Change<QueryDocumentSnapshot>, Record<string, string>>) => {const data = event.data?.after.data();const prev = event.data?.before.data();if (!data || data.status !== "dispatched" || prev?.status === "dispatched") return;if (data.provenance?.receiver_id !== "EVOLUTION_WORKER") return;const { appId } = event.params;const client = new AgentBusClient({agentId: "EVOLUTION_WORKER",capabilities: ["logic_optimization", "memory_commit"],jurisdictions: ["AB"],substances: ["DAUA"],role: "ORCHESTRATOR",domain: "SECURITY"}, appId);await client.register();try {const manifest = data.payload?.manifest;if (!manifest) return;if (manifest.intent === "PROPOSE_LOGIC_CHANGE") {
  const { hbrId, agentId, proposedLogic, reason } = manifest;
  const proposalPath = [BACKTICK]artifacts/${appId}/public/data/logic_proposals[BACKTICK];
  const proposalRef = db.collection(proposalPath).doc();
  await proposalRef.set({
    hbrId,
    proposingAgentId: agentId,
    proposedLogic,
    reason,
    status: "PENDING",
    commit_pending: true,
    createdAt: new Date().toISOString()
  });
  return client.sendResponse(data.correlation_id, data.provenance.sender_id, {
    status: "REGISTERED",
    proposalId: proposalRef.id
  });
}
} catch (err) {console.error("[ORCHESTRATOR] Error:", err);}});export const shadowComparatorWorkerV2 = onDocumentWritten({document: "artifacts/{appId}/public/data/agent_bus/{messageId}",memory: "512MiB"}, async (event: FirestoreEvent<Change<QueryDocumentSnapshot>, Record<string, string>>) => {const prodMsg = event.data?.after.data();const prev = event.data?.before.data();if (!prodMsg || prodMsg.status !== "dispatched" || prev?.status === "dispatched") return;if (prodMsg.control?.type !== "RESPONSE") return;const { appId } = event.params;try {const shadowPath = [BACKTICK]artifacts/${appId}/public/data/shadow_bus[BACKTICK];const shadowSnap = await db.collection(shadowPath).where("correlation_id", "==", prodMsg.correlation_id).get();if (shadowSnap.empty) return;const shadowMsg = shadowSnap.docs[0].data();
const isMatch = areResultsIdentical(prodMsg.payload?.result || {}, shadowMsg.payload?.result || {});

const runPath = [BACKTICK]artifacts/${appId}/public/data/shadow_runs[BACKTICK];
await db.collection(runPath).doc(prodMsg.correlation_id).set({
  correlation_id: prodMsg.correlation_id,
  status: isMatch ? "validated" : "failed",
  timestamp: new Date().toISOString()
});
} catch (e) {console.error("[SHADOW] Error:", e);}});export const logicCollisionWorkerV2 = onDocumentCreated({document: "artifacts/{appId}/public/data/logic_dependencies/{hbrId}",memory: "512MiB"}, async (event: FirestoreEvent<QueryDocumentSnapshot | undefined, { appId: string; hbrId: string }>) => {console.log("[COLLISION] Processing dependency map for:", event.params.hbrId);});export const evolutionProposalFinalizedV2 = onDocumentUpdated({document: "artifacts/local2local-kaskflow/public/data/logic_proposals/{proposalId}",memory: "512MiB"}, async (event: FirestoreEvent<Change<QueryDocumentSnapshot>, Record<string, string>>) => {const newData = event.data?.after.data();if (!newData) return;const status = (newData.status || "").toUpperCase();if (status === "APPROVED" && newData.commit_pending === true) {const dbInstance = admin.firestore();const hbrId = newData.hbrId || newData.hbr_target || "UNKNOWN";try {
  const batch = dbInstance.batch();
  const lessonRef = dbInstance.collection("artifacts")
    .doc(appIdStatic)
    .collection("public")
    .doc("data")
    .collection("lessons_learned")
    .doc();

  batch.set(lessonRef, {
    reasoning_vault: newData.reasoning_vault || {},
    applied_logic: newData.proposedLogic || newData.proposed_logic || "N/A",
    hbr_target: hbrId,
    agent_id: newData.proposingAgentId || newData.agent_id || "SYSTEM",
    finalized_at: FieldValue.serverTimestamp(),
    source_proposal: event.params.proposalId
  });

  const registryPath = [BACKTICK]artifacts/${appIdStatic}/public/data/hbr_registry/registry/${hbrId}[BACKTICK];
  const hbrRef = dbInstance.doc(registryPath);
  batch.update(hbrRef, {
    lock_status: "IDLE",
    last_modified: FieldValue.serverTimestamp()
  });

  if (event.data?.after.ref) {
    batch.delete(event.data.after.ref);
  }

  await batch.commit();
  console.log(`[EVOLUTION-P36] Processed ${hbrId}`);
} catch (e) {
  console.error("[BATCH-ERROR]", e);
}
}});export const evolutionForceBaselineV2 = onRequest(async (req: Request, res: Response) => {const dbInstance = admin.firestore();try {const pingRef = dbInstance.collection("artifacts").doc(appIdStatic).collection("public").doc("data").collection("lessons_learned").doc("baseline_ping");await pingRef.set({
  message: "Verified",
  timestamp: FieldValue.serverTimestamp()
});
res.status(200).send("✅ Success");
} catch (e: any) {res.status(500).send("❌ Fail: " + e.message);}});L2LAAF_BLOCK_END