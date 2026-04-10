import { onDocumentWritten } from "firebase-functions/v2/firestore";
import type { FirestoreEvent, Change, DocumentSnapshot } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import axios from "axios";

const db = admin.firestore();

// Fixed: Using DocumentSnapshot instead of QueryDocumentSnapshot to match v2 SDK DocumentOptions
type L2LChange = Change<DocumentSnapshot>;
type L2LWrittenEvent = FirestoreEvent<L2LChange | undefined, { appId: string; [key: string]: string }>;

async function signalOrchestrator(payload: any, eventType: string = "DEPLOYMENT_COMPLETE") {
  const N8N_WEBHOOK_URL = "https://local2local.app.n8n.cloud/webhook/l2laaf-payload-trigger";
  try {
    await axios.post(N8N_WEBHOOK_URL, {
      incoming_phase: "38.9.1",
      build_id: payload.correlation_id || `EVO-${Date.now()}`,
      summary: payload.manifest?.reason || payload.summary || "Autonomous logic update.",
      event: eventType,
      filePath: payload.manifest?.targetPath || "functions/src/logic/evolution.ts",
      fileContent: payload.manifest?.proposedLogic || null,
      branch: "develop"
    });
    console.log(`📡 ORCHESTRATOR: [${eventType}] Signal transmitted successfully.`);
  } catch (error) {
    console.error(`❌ ORCHESTRATOR: Failed to signal [${eventType}]:`, error);
  }
}

/**
 * [1] EVOLUTION ORCHESTRATOR V3
 */
export const evolutionOrchestratorV3 = onDocumentWritten({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event: L2LWrittenEvent) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "dispatched") return;

  const { appId } = event.params;
  const manifest = data.payload?.manifest;
  const correlationId = data.correlation_id || event.params.messageId;

  if (manifest?.intent === "PROPOSE_LOGIC_CHANGE") {
    const { hbrId, agentId } = manifest;
    const lockRef = db.collection(`artifacts/${appId}/public/data/logic_locks`).doc(hbrId);

    try {
      await db.runTransaction(async (transaction) => {
        const lockSnap = await transaction.get(lockRef);
        if (lockSnap.exists) {
          throw new Error(`COLLISION: HBR ${hbrId} locked by ${lockSnap.data()?.agentId}`);
        }
        transaction.set(lockRef, {
          agentId,
          lockedAt: admin.firestore.FieldValue.serverTimestamp(),
          correlation_id: correlationId
        });
      });

      const shadowRef = db.collection(`artifacts/${appId}/public/data/shadow_runs`).doc(correlationId);
      await shadowRef.set({
        status: "INITIALIZING",
        proposal_id: hbrId,
        agent_id: agentId,
        started_at: admin.firestore.FieldValue.serverTimestamp(),
        manifest_summary: manifest.reason || "Logic evolution validation."
      });

      await signalOrchestrator(data, "PROPOSAL_SUBMITTED");
    } catch (e) {
      console.error("Evolution Error:", e);
      throw e;
    }
  }
});

/**
 * [2] OMBUDSMAN VALIDATOR
 */
export const ombudsmanValidatorV2 = onDocumentWritten({
  document: "artifacts/{appId}/public/data/shadow_runs/{runId}"
}, async (event: L2LWrittenEvent) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "VALIDATED") return;
  const { appId, runId } = event.params;
  await signalOrchestrator({
    correlation_id: runId,
    summary: `Ombudsman validated shadow run: ${runId}. Safe for promotion.`,
  }, "SHADOW_VALIDATED");
});

/**
 * [3] AUTONOMOUS FIXER
 */
export const autonomousFixerV2 = onDocumentWritten({
  document: "artifacts/{appId}/public/data/system_state/state",
  memory: "512MiB"
}, async (event) => {
  const state = event.data?.after.data();
  if (!state || state.approval_gate?.status !== "FAILED_AUDIT") return;
  const fixerLogRef = db.collection(`artifacts/${event.params.appId}/public/data/fixer_logs`).doc();
  await fixerLogRef.set({ detected_at: admin.firestore.FieldValue.serverTimestamp(), status: "ANALYZING", target_phase: state.current_phase });
});

export const evolutionProposalFinalizerV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/logic_proposals/{proposalId}" }, async (event) => {});