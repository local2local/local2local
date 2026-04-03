import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import type { Request, Response } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

import { FieldValue } from "firebase-admin/firestore";

const appIdStatic = "local2local-kaskflow";

export const onProposalFinalized = onDocumentUpdated(
  "artifacts/local2local-kaskflow/public/data/logic_proposals/{proposalId}",
  async (event) => {
    const newData = event.data?.after.data();
    if (!newData) return;

    const status = (newData.status || "").toUpperCase();
    if (status === "APPROVED" && newData.commit_pending === true) {
      const db = admin.firestore();
      const hbrTarget = newData.hbrYd || newData.hbr_target || "UNKNOWN";
      try {
        const batch = db.batch();
        const lessonRef = db.collection("artifacts").doc(appIdStatic).collection("public").doc("data").collection("lessons_learned").doc();
        batch.set(lessonRef, {
          reasoning_vault: newData.reasoning_vault || {},
          applied_logic: newData.proposedLogic || newData.proposed_logic || "N/A",
          hbr_target: hbrTarget,
          agent_id: newData.proposingAgentId || newData.agent_id || "SYSTEM",
          finalized_at: FieldValue.serverTimestamp(),
          source_proposal: event.params.proposalId
        });
        const hbrRef = db.doc(`artifacts/${appIdStatic}/public/data/hbr_registry/registry/${hbrTarget}`);
        batch.update(hbrRef, { lock_status: "IDLE", last_modified: FieldValue.serverTimestamp() });
        batch.delete(event.data!.after.ref);
        await batch.commit();
        console.log(`[EVOLUTION-P36] Processed ${hbrTarget}`);
      } catch (e) { console.error("Batch Error", e); }
    }
  }
);

export const forceBaseline = onRequest(async (req: Request, res: Response) => {
  const db = admin.firestore();
  try {
    await db.collection("artifacts").doc(appIdStatic).collection("public").doc("data").collection("lessons_learned").doc("baseline_ping").set({
      message: "Verified",
      timestamp: FieldValue.serverTimestamp()
    });
    res.status(200).send("❈ Success");
  try } catch (e: any) { res.status(500).send("❬ Fail: " + e.message); }
});
