import { onDocumentWritten, onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import type { FirestoreEvent, Change, QueryDocumentSnapshot } from "firebase-functions/v2/firestore";
import type { Request, Response } from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../config";
import { AgentBusClient } from "../agentBusClient";

/**
 * TYPE ALIASES: Enforcing strict generic compliance.
 */
type L2LChange = Change<QueryDocumentSnapshot>;
type L2LWrittenEvent = FirestoreEvent<L2LChange | undefined, Record<string, string>>;
type L2LCreatedEvent = FirestoreEvent<QueryDocumentSnapshot | undefined, Record<string, string>>;
type L2LUpdatedEvent = FirestoreEvent<L2LChange | undefined, Record<string, string>>;

function areResultsIdentical(a: any, b: any): boolean {
  try {
    const s1 = JSON.stringify(a || {}, Object.keys(a || {}).sort());
    const s2 = JSON.stringify(b || {}, Object.keys(b || {}).sort());
    return s1 === s2;
  } catch (e) {
    return false;
  }
}

export const evolutionOrchestratorV2 = onDocumentWritten({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event: L2LWrittenEvent) => {
  const data = event.data?.after.data();
  const prev = event.data?.before.data();
  if (!data || data.status !== "dispatched" || prev?.status === "dispatched") return;
  if (data.provenance?.receiver_id !== "EVOLUTION_WORKER") return;

  const { appId } = event.params;
  const client = new AgentBusClient({
    agentId: "EVOLUTION_WORKER",
    capabilities: ["logic_optimization", "memory_commit"],
    jurisdictions: ["AB"],
    substances: ["DAUA"],
    role: "ORCHESTRATOR",
    domain: "SECURITY"
  }, appId);

  await client.register();

  try {
    const manifest = data.payload?.manifest;
    if (!manifest) return;

    if (manifest.intent === "PROPOSE_LOGIC_CHANGE") {
      const { hbrId, agentId, proposedLogic, reason } = manifest;

      const lockRef = db.collection(`artifacts/${appId}/public/data/logic_locks`).doc(hbrId);
      const lockSnap = await lockRef.get();
      if (lockSnap.exists) {
        console.warn(`[ORCHESTRATOR] Collision: HBR ${hbrId} is currently locked.`);
        return;
      }

      const proposalPath = `artifacts/${appId}/public/data/logic_proposals`;
      const proposalRef = db.collection(proposalPath).doc();
      
      await proposalRef.set({
        hbrId,
        proposingAgentId: agentId,
        proposedLogic,
        reason,
        status: "PENDING",
        correlation_id: data.correlation_id,
        commit_pending: false,
        createdAt: new Date().toISOString()
      });

      return client.sendResponse(data.correlation_id, data.provenance.sender_id, {
        status: "REGISTERED",
        proposalId: proposalRef.id
      });
    }
  } catch (err) {
    console.error("[ORCHESTRATOR] Error:", err);
  }
});

export const ombudsmanValidatorV2 = onDocumentCreated({
  document: "artifacts/{appId}/public/data/shadow_runs/{runId}",
  memory: "512MiB"
}, async (event: L2LCreatedEvent) => {
  const data = event.data?.data();
  if (!data || data.status !== "validated") return;

  const { appId } = event.params;
  const correlationId = data.correlation_id;

  try {
    const proposalsPath = `artifacts/${appId}/public/data/logic_proposals`;
    const proposalSnap = await db.collection(proposalsPath)
      .where("correlation_id", "==", correlationId)
      .get();

    if (proposalSnap.empty) return;

    const proposalRef = proposalSnap.docs[0].ref;
    await proposalRef.update({
      status: "APPROVED",
      commit_pending: true,
      validated_at: new Date().toISOString(),
      validation_source: "OMBUDSMAN_AUTO_RUN"
    });

    console.log(`[OMBUDSMAN] Auto-approved proposal for correlation: ${correlationId}`);
  } catch (err) {
    console.error("[OMBUDSMAN] Error:", err);
  }
});

export const shadowComparatorWorkerV2 = onDocumentWritten({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event: L2LWrittenEvent) => {
  const prodMsg = event.data?.after.data();
  const prev = event.data?.before.data();
  if (!prodMsg || prodMsg.status !== "dispatched" || prev?.status === "dispatched") return;
  if (prodMsg.control?.type !== "RESPONSE") return;

  const { appId } = event.params;
  try {
    const shadowPath = `artifacts/${appId}/public/data/shadow_bus`;
    const shadowSnap = await db.collection(shadowPath).where("correlation_id", "==", prodMsg.correlation_id).get();
    
    if (shadowSnap.empty) return;
    const shadowMsg = shadowSnap.docs[0].data();
    const isMatch = areResultsIdentical(prodMsg.payload?.result || {}, shadowMsg.payload?.result || {});

    const runPath = `artifacts/${appId}/public/data/shadow_runs`;
    await db.collection(runPath).doc(prodMsg.correlation_id).set({
      correlation_id: prodMsg.correlation_id,
      agentId: prodMsg.provenance.sender_id,
      status: isMatch ? "validated" : "failed",
      timestamp: new Date().toISOString()
    });
  } catch (e) {
    console.error("[SHADOW] Error:", e);
  }
});

export const evolutionProposalFinalizedV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/logic_proposals/{proposalId}",
  memory: "512MiB"
}, async (event: L2LUpdatedEvent) => {
  const newData = event.data?.after.data();
  const oldData = event.data?.before.data();
  const { appId, proposalId } = event.params;

  if (!newData || !oldData) return;

  const isApproved = newData.status === "APPROVED";
  const isCommitReady = newData.commit_pending === true;
  const wasAlreadyProcessed = oldData.status === "APPROVED" && oldData.commit_pending === true;

  if (!isApproved || !isCommitReady || wasAlreadyProcessed) return;

  const dbInstance = admin.firestore();
  const hbrId = newData.hbrId || "UNKNOWN";

  try {
    const batch = dbInstance.batch();

    // 1. ARCHIVE TO LESSONS LEARNED
    const lessonRef = dbInstance.collection("artifacts")
      .doc(appId)
      .collection("public")
      .doc("data")
      .collection("lessons_learned")
      .doc();

    batch.set(lessonRef, {
      reasoning_vault: newData.reasoning_vault || {},
      applied_logic: newData.proposedLogic || "N/A",
      hbr_target: hbrId,
      agent_id: newData.proposingAgentId || "SYSTEM",
      finalized_at: FieldValue.serverTimestamp(),
      source_proposal: proposalId
    });

    // 2. BROADCAST TO COCKPIT TIMELINE (Business Meaningful Context)
    const timelineRef = dbInstance.collection("artifacts")
      .doc(appId)
      .collection("public")
      .doc("data")
      .collection("evolution_timeline")
      .doc();

    const bizSummary = `Successfully committed optimized logic for ${hbrId}. ` +
      `Enforcement Profile: (1) Mutex collision prevention active; ` +
      `(2) Ombudsman shadow-verification protocol autonomously verified logic integrity, bypassing manual review gates. ` +
      `Atomic state transition completed.`;

    batch.set(timelineRef, {
      type: "LOGIC_COMMIT_SUCCESS",
      title: "LOGIC COMMIT SUCCESS",
      description: bizSummary,
      is_autonomous: true,
      agent_name: "EVOLUTION_WORKER",
      timestamp: new Date().toISOString(),
      hbr_id: hbrId
    });

    // 3. UPDATE REGISTRY STATUS
    const registryPath = `artifacts/${appId}/public/data/hbr_registry/${hbrId}`;
    const hbrRef = dbInstance.doc(registryPath);
    batch.set(hbrRef, {
      lock_status: "IDLE",
      last_modified: FieldValue.serverTimestamp()
    }, { merge: true });

    const lockPath = `artifacts/${appId}/public/data/logic_locks/${hbrId}`;
    const lockRef = dbInstance.doc(lockPath);
    batch.delete(lockRef);

    if (event.data?.after.ref) {
      batch.delete(event.data.after.ref);
    }

    await batch.commit();
    console.log(`[EVOLUTION-P36] [${appId}] Successfully committed logic for ${hbrId}`);
  } catch (e) {
    console.error("[EVOLUTION-P36] Finalization Error:", e);
  }
});

export const evolutionForceBaselineV2 = onRequest(async (req: Request, res: Response) => {
  const appId = (req.query.appId as string) || "local2local-kaskflow";
  const dbInstance = admin.firestore();
  try {
    const pingRef = dbInstance.collection("artifacts").doc(appId).collection("public").doc("data").collection("lessons_learned").doc("baseline_ping");
    await pingRef.set({
      message: "Verified",
      timestamp: FieldValue.serverTimestamp(),
      tenant: appId
    });
    res.status(200).send(`✅ Success for tenant: ${appId}`);
  } catch (e: any) {
    res.status(500).send("❌ Fail: " + e.message);
  }
});