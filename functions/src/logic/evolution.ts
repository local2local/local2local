import { onDocumentWritten } from "firebase-functions/v2/firestore";
import type { FirestoreEvent, Change, DocumentSnapshot } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import axios from "axios";
const db = admin.firestore();
type L2LWrittenEvent = FirestoreEvent<Change<DocumentSnapshot> | undefined, { appId: string; [key: string]: string }>;
async function signalOrchestrator(payload: any, eventType: string = "DEPLOYMENT_COMPLETE") {
  const N8N_WEBHOOK_URL = "https://local2local.app.n8n.cloud/webhook/l2laaf-payload-trigger";
  try {
    await axios.post(N8N_WEBHOOK_URL, { incoming_phase: "39.1.2", build_id: payload.correlation_id || `EVO-${Date.now()}`, summary: payload.manifest?.reason || payload.summary || "Autonomous logic update.", event: eventType, filePath: payload.manifest?.targetPath || "functions/src/logic/evolution.ts", fileContent: payload.manifest?.proposedLogic || null, branch: "develop" });
  } catch (error) { console.error(`❌ ORCHESTRATOR: Failed to signal [${eventType}]`); }
}
export const evolutionOrchestratorV3 = onDocumentWritten({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}", memory: "512MiB" }, async (event: L2LWrittenEvent) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "dispatched" || data.payload?.manifest?.intent !== "PROPOSE_LOGIC_CHANGE") return;
  const { appId } = event.params;
  const manifest = data.payload.manifest;
  const correlationId = data.correlation_id || event.params.messageId;
  const lockRef = db.collection(`artifacts/${appId}/public/data/logic_locks`).doc(manifest.hbrId);
  try {
    await db.runTransaction(async (transaction) => {
      const lockSnap = await transaction.get(lockRef);
      if (lockSnap.exists) throw new Error(`COLLISION: HBR ${manifest.hbrId} locked.`);
      transaction.set(lockRef, { agentId: manifest.agentId, lockedAt: admin.firestore.FieldValue.serverTimestamp(), correlation_id: correlationId });
    });
    const shadowRef = db.collection(`artifacts/${appId}/public/data/shadow_runs`).doc(correlationId);
    await shadowRef.set({ status: "INITIALIZING", proposal_id: manifest.hbrId, agent_id: manifest.agentId, started_at: admin.firestore.FieldValue.serverTimestamp() });
    await signalOrchestrator(data, "PROPOSAL_SUBMITTED");
  } catch (e) { throw e; }
});
export const ombudsmanValidatorV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/shadow_runs/{runId}" }, async (event: L2LWrittenEvent) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "VALIDATED") return;
  await signalOrchestrator({ correlation_id: event.params.runId, summary: `⚖️ Ombudsman validated shadow run: ${event.params.runId}. Safe for promotion.` }, "SHADOW_VALIDATED");
});
export const autonomousFixerV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/system_state/state" }, async (event) => {
  const state = event.data?.after.data();
  if (!state || state.approval_gate?.status !== "FAILED_AUDIT") return;
  const fixerLogRef = db.collection(`artifacts/${event.params.appId}/public/data/fixer_logs`).doc();
  await fixerLogRef.set({ detected_at: admin.firestore.FieldValue.serverTimestamp(), status: "ANALYZING", target_phase: state.current_phase });
});
export const evolutionProposalFinalizerV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/logic_proposals/{proposalId}" }, async (event) => {});