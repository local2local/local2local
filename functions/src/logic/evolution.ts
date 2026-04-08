import { onDocumentWritten } from "firebase-functions/v2/firestore";
import type { FirestoreEvent, Change, QueryDocumentSnapshot } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

const db = admin.firestore();

type L2LChange = Change<QueryDocumentSnapshot>;
type L2LWrittenEvent = FirestoreEvent<L2LChange | undefined, Record<string, string>>;

export const evolutionOrchestratorV3 = onDocumentWritten({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event: L2LWrittenEvent) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "dispatched") return;

  const { appId } = event.params;
  const manifest = data.payload?.manifest;
  if (manifest?.intent === "PROPOSE_LOGIC_CHANGE") {
    const { hbrId, agentId } = manifest;

    const lockRef = db.collection(`artifacts/${appId}/public/data/logic_locks`).doc(hbrId);
    
    await db.runTransaction(async (transaction) => {
      const lockSnap = await transaction.get(lockRef);
      if (lockSnap.exists) {
        throw new Error(`COLLISION: HBR ${hbrId} is currently locked by ${lockSnap.data()?.agentId}`);
      }

      transaction.set(lockRef, {
        agentId,
        lockedAt: admin.firestore.FieldValue.serverTimestamp(),
        correlation_id: data.correlation_id
      });

      const registryRef = db.doc(`artifacts/${appId}/public/data/hbr_registry/registry/${hbrId}`);
      transaction.set(registryRef, {
        lock_status: 'LOCKED',
        locked_by: agentId,
        last_modified: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    });
  }
});