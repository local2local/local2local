import { onDocumentWritten } from "firebase-functions/v2/firestore";
import type { FirestoreEvent, Change, QueryDocumentSnapshot } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

const db = admin.firestore();

type L2LChange = Change<QueryDocumentSnapshot>;
type L2LWrittenEvent = FirestoreEvent<L2LChange | undefined, Record<string, string>>;

async function updateTelemetry(buildId: string, task: string, progress: number, status: 'PENDING' | 'SUCCESS' | 'FAILED' = 'PENDING') {
  if (buildId === 'unknown') return;
  // ENSURING THE PATH MATCHES THE MONITOR'S EXPECTATION
  const telRef = db.doc(`artifacts/local2local-dev/public/data/deployment_telemetry/${buildId}`);
  await telRef.set({
    current_task: task,
    progress: progress,
    status: status,
    updated_at: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });
}

export const evolutionOrchestratorV3 = onDocumentWritten({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event: L2LWrittenEvent) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "dispatched") return;

  const { appId } = event.params;
  const manifest = data.payload?.manifest;
  const buildId = data.correlation_id || "unknown";

  if (manifest?.intent === "PROPOSE_LOGIC_CHANGE") {
    const { hbrId, agentId } = manifest;
    await updateTelemetry(buildId, "Acquiring Mutex Lock...", 30);
    const lockRef = db.collection(`artifacts/${appId}/public/data/logic_locks`).doc(hbrId);
    try {
      await db.runTransaction(async (transaction) => {
        const lockSnap = await transaction.get(lockRef);
        if (lockSnap.exists) throw new Error(`COLLISION: HBR ${hbrId} locked by ${lockSnap.data()?.agentId}`);
        transaction.set(lockRef, { agentId, lockedAt: admin.firestore.FieldValue.serverTimestamp(), correlation_id: buildId });
        const registryRef = db.doc(`artifacts/${appId}/public/data/hbr_registry/registry/${hbrId}`);
        transaction.set(registryRef, { lock_status: 'LOCKED', locked_by: agentId, last_modified: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      });
      await updateTelemetry(buildId, "Mutex Acquired. Shadow Run Initiated.", 100, 'SUCCESS');
    } catch (e) {
      await updateTelemetry(buildId, (e as Error).message, 100, 'FAILED');
      throw e;
    }
  }
});

export const autonomousFixerV1 = onDocumentWritten({
  document: "artifacts/{appId}/public/data/system_state/state",
  memory: "512MiB"
}, async (event) => {
  const state = event.data?.after.data();
  if (!state || state.approval_gate?.status !== "FAILED_AUDIT") return;
  const fixerLogRef = db.collection(`artifacts/${event.params.appId}/public/data/fixer_logs`).doc();
  await fixerLogRef.set({ detected_at: admin.firestore.FieldValue.serverTimestamp(), status: "ANALYZING", target_phase: state.current_phase });
});

export const ombudsmanValidatorV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/shadow_runs/{runId}" }, async (event) => {});
export const evolutionProposalFinalizerV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/logic_proposals/{proposalId}" }, async (event) => {});