L2LAAF Phase 36 Stabilization PayloadDELIMITER_PROTOCOL: V2.6_SAFE_FLATL2LAAF_BLOCK_START(text:COMMIT_MSG:COMMIT_MSG)feat(evolution): baseline phase 36 with path-hardened trigger and verbose diagnosticsL2LAAF_BLOCK_ENDL2LAAF_BLOCK_START(typescript:Evolution:functions/src/logic/evolution.ts)import { onDocumentUpdated } from "firebase-functions/v2/firestore";import { onRequest } from "firebase-functions/v2/https";import * as admin from "firebase-admin";/**L2LAAF Phase 36: Global Memory Commit LogicOptimized for local2local-kaskflow.Lead: Senior Cloud Architect*/const appIdStatic = "local2local-kaskflow";/**TRIGGER: onProposalFinalizedHARDENED PATH: Removed leading slash and added broad wildcard matching.Target: artifacts/local2local-kaskflow/public/data/logic_proposals/{proposalId}*/export const onProposalFinalized = onDocumentUpdated("artifacts/{appId}/public/data/logic_proposals/{proposalId}",async (event) => {// Immediate log to verify trigger hitconsole.log([EVOLUTION-DIAGNOSTIC] !!! TRIGGER WAKEUP !!!);const newData = event.data?.after.data();const proposalId = event.params.proposalId;const matchedAppId = event.params.appId;console.log([EVOLUTION-DIAGNOSTIC] Processing ID: ${proposalId} | App: ${matchedAppId});if (!newData) {console.log("[EVOLUTION-DIAGNOSTIC] No data found in payload.");return;}const currentStatus = (newData.status || "").toUpperCase();const isCommitPending = newData.commit_pending === true;console.log([EVOLUTION-DIAGNOSTIC] Status: ${currentStatus} | Commit: ${isCommitPending});if (currentStatus === "APPROVED" && isCommitPending) {const db = admin.firestore();const hbrTarget = newData.hbrId || newData.hbr_target || "UNKNOWN_HBR";try {const batch = db.batch();   // 1. Move to permanent vault
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
   console.log(`[EVOLUTION-DIAGNOSTIC] SUCCESS: Commit finalized for ${hbrTarget}.`);
} catch (error) {console.error([EVOLUTION-DIAGNOSTIC] BATCH FAIL:, error);}} else {console.log([EVOLUTION-DIAGNOSTIC] Filtered: Conditions not met.);}});/**DIAGNOSTIC: forceBaselineHTTP Ping to verify collection permissions independently of triggers.*/export const forceBaseline = onRequest(async (req, res) => {const db = admin.firestore();try {const docRef = db.collection("artifacts").doc(appIdStatic).collection("public").doc("data").collection("lessons_learned").doc("baseline_ping"); await docRef.set({
     message: "System baseline verified via HTTP",
     timestamp: admin.FieldValue.serverTimestamp()
 });

 res.status(200).send("✅ Baseline document created successfully.");
} catch (e: any) {res.status(500).send(❌ Baseline failure: ${e.message});}});L2LAAF_BLOCK_END