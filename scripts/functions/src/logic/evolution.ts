import { onDocumentUpdated } from "firebase-functions/v2/firestore";import { onRequest } from "firebase-functions/v2/https";import * as admin from "firebase-admin";/**L2LAAF Phase 36: Global Memory Commit LogicOptimized for local2local-kaskflow schema.Lead: Senior Cloud Architect*/const appIdStatic = "local2local-kaskflow";/**TRIGGER: onProposalFinalizedThis listens for updates to documents in the logic_proposals collection.Path: artifacts/local2local-kaskflow/public/data/logic_proposals/{proposalId}*/export const onProposalFinalized = onDocumentUpdated("/artifacts/{appId}/public/data/logic_proposals/{proposalId}",async (event) => {const newData = event.data?.after.data();const proposalId = event.params.proposalId;const matchedAppId = event.params.appId;console.log([EVOLUTION-DIAGNOSTIC] Event received for ID: ${proposalId});console.log([EVOLUTION-DIAGNOSTIC] Path Matched AppID: ${matchedAppId});if (!newData) {console.log("[EVOLUTION-DIAGNOSTIC] Data payload is null or undefined.");return;}const currentStatus = (newData.status || "").toUpperCase();const isCommitPending = newData.commit_pending === true;console.log([EVOLUTION-DIAGNOSTIC] Current Status: ${currentStatus} | Commit Pending: ${isCommitPending});if (currentStatus === "APPROVED" && isCommitPending) {const db = admin.firestore();const hbrTarget = newData.hbrId || newData.hbr_target || "UNKNOWN_HBR";console.log([EVOLUTION-DIAGNOSTIC] Criteria Met. Initiating Batch for ${hbrTarget});try {const batch = db.batch();   // 1. Move to permanent vault
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
     finalized_at: admin.FieldValue.serverTimestamp(),
     tags: newData.reasoning_vault?.semantic_tags || [],
     source_proposal: proposalId,
     diagnostic_run: true
   });

   // 2. Unlock HBR
   const hbrRef = db.collection("artifacts")
     .doc(appIdStatic)
     .collection("public")
     .doc("data")
     .collection("hbr_registry")
     .doc(hbrTarget);

   batch.update(hbrRef, {
     lock_status: "IDLE",
     last_modified: admin.FieldValue.serverTimestamp(),
     current_version: proposalId
   });

   // 3. Delete Proposal
   batch.delete(event.data!.after.ref);

   await batch.commit();
   console.log(`[EVOLUTION-DIAGNOSTIC] SUCCESS: Batch Committed. Collection 'lessons_learned' should now exist.`);
} catch (error) {console.error([EVOLUTION-DIAGNOSTIC] BATCH FAIL:, error);}} else {console.log([EVOLUTION-DIAGNOSTIC] Bypass: Document updated but does not meet commit criteria.);}});/**EMERGENCY DIAGNOSTIC: forceBaselineIf the document listener fails, visit the URL for this function tomanually verify that the lessons_learned collection can be created.*/export const forceBaseline = onRequest(async (req, res) => {const db = admin.firestore();try {const docRef = db.collection("artifacts").doc(appIdStatic).collection("public").doc("data").collection("lessons_learned").doc("baseline_ping"); await docRef.set({
     message: "System baseline verified via HTTP trigger",
     timestamp: admin.FieldValue.serverTimestamp()
 });

 res.status(200).send("✅ Baseline document created in 'lessons_learned'. Permissions verified.");
} catch (e: any) {res.status(500).send(❌ Baseline failure: ${e.message});}});