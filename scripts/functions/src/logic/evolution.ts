import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

/**

L2LAAF Phase 36: Global Memory Commit Logic

Lead: Senior Cloud Architect

ARCHITECTURAL OVERVIEW:

This logic represents the 'Commit' phase of the Guided Autonomy loop.

When an agent proposes a logic shift (Phase 35) and it is APPROVED,

this function captures the full reasoning context, archives it into

the 'lessons_learned' vault, and resets the HBR (Hardened Behavioral Registry)

lock to allow for subsequent evolutions.
*/

const appId = process.env.APP_ID || "l2laaf-default";

export const onProposalFinalized = onDocumentUpdated(
"/artifacts/{appId}/public/data/proposals/{proposalId}",
async (event) => {
const newData = event.data?.after.data();

// VALIDATION: Only act on approved proposals with a pending commit flag
if (newData?.status === "APPROVED" && newData?.commit_pending === true) {
  const db = admin.firestore();
  const proposalId = event.params.proposalId;
  const hbrTarget = newData.hbr_target;

  console.log(`[Phase 36] Initializing Global Memory Archive for: ${proposalId}`);
  const batch = db.batch();

  /**
   * STEP 1: ARCHIVE REASONING
   * We persist the reasoning_vault (Semantic Tags, Context, Simulation Results)
   * into the permanent Lessons Learned collection. This forms the 'Long-Term Memory'
   * that Phase 37 will eventually query.
   */
  const lessonRef = db.collection("artifacts")
    .doc(appId)
    .collection("public")
    .doc("data")
    .collection("lessons_learned")
    .doc();

  batch.set(lessonRef, {
    ...newData.reasoning_vault,
    applied_logic: newData.proposal_logic,
    hbr_target: hbrTarget,
    agent_id: newData.agentId,
    finalized_at: admin.FieldValue.serverTimestamp(),
    tags: newData.reasoning_vault?.semantic_tags || [],
    source_proposal: proposalId
  });

  /**
   * STEP 2: RELEASE HBR LOCK
   * The HBR is locked during the proposal phase to prevent race conditions.
   * We now set it back to IDLE and update the version pointer.
   */
  const hbrRef = db.collection("artifacts")
    .doc(appId)
    .collection("public")
    .doc("data")
    .collection("hbr_registry")
    .doc(hbrTarget);

  batch.update(hbrRef, {
    lock_status: "IDLE",
    last_modified: admin.FieldValue.serverTimestamp(),
    current_version: proposalId
  });

  /**
   * STEP 3: CLEANUP
   * Remove the ephemeral proposal document to keep the working set clean.
   */
  const proposalRef = event.data?.after.ref;
  if (proposalRef) {
      batch.delete(proposalRef);
  }

  await batch.commit();
  console.log(`[Phase 36] Global Memory stabilized. HBR ${hbrTarget} released.`);
}


}
);