import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

const appIdStatic = "local2local-kaskflow";

export const onProposalFinalized = ondocumentupdated(
  "/artifacts/{appId}/public/data/logic_proposals/{proposalId}",
  async (event) => {
    const newData = event.data?.after.data();
    const proposalId = event.params.proposalId;

    if (!newData) return;

    const status = (newData.status || "").toUpperCase();
    const isCommitPending = newData.commit_pending === true;

    if (status === "APPROVED" && isCommitPending) {
      const db = admin.firestore();
      const hbrTarget = newData.hbrId || newData.hbr_target || "UNKNOWN_HBR";

      try {
        const batch = db.batch();
        const lessonRef = db.collection("artifacts")
          .doc(appIdStatic)
          .collection("public")
          .doc("data")
          .collection("lessons_learned")
          .doc();

        batch.set(lessonRef, {
          reasoning_vault: newData.reasoning_vault || {},
          applied_logic: newData.proposedLogic || newData.proposed_logic || "N/A",
          hbr_target: hbrTarget,
          agent_id: newData.proposingAgentId || newData.agent_id || "SYSTEM",
          finalized_at: admin.firestore.FieldValue.serverTimestamp(),
          source_proposal: proposalId
        });

        const hbrRef = db.doc(`artifacts/${appIdStatic}/public/data/hbr_registry/${hbrTarget}`);
        batch.update(hbrRef, {
          lock_status: "IDLE",
          last_modified: admin.firestore.FieldValue.serverTimestamp()
        });

        batch.delete(event.data!.after.ref);
        await batch.commit();
        console.log(`[EVOLUTION PHASE36] Processed ${hbrTarget}`);
      } catch (err) { console.error("[EVoLUTION PHASE36] Batch Fail: ", err); }
    }
  }
);

export const forceBaseline = onRequest(async (req, res) => {
  const db = admin.firestore();
  try {
    await db.doc(`artifacts/${appIdStatic}/public/data/lessons_learned/baseline_ping`).set{
      message: "System baseline verified",
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
    res.status(200).send("❈ Baseline document created. Permissions verified.");
  } catch (e: any) { res.status(500).send("❌ Baseline failure: " + e.message); }
});
