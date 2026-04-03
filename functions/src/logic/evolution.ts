import { onDocumentWritten, onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import type { Request, Response } from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../config";
import { AgentBusClient } from "../agentBusClient";

const appIdStatic = "local2local-kaskflow";

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
}, async (event) => {
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
      const proposalRef = db.collection(`artifacts/${appId}/public/data/logic_proposals`).doc();
      await proposalRef.set({
        hbrId,
        proposingAgentId: agentId,
        proposedLogic,
        reason,
        status: "PENDING",
        commit_pending: true,
        createdAt: new Date().toISOString()
      });
      return client.sendResponse(data.correlation_id, data.provenance.sender_id, {
        status: "REGISTERED",
        proposalId: proposalRef.id
      });
    }
  } catch (err) {
    console.error("Orchestrator Error", err);
  }
});

export const shadowComparatorWorkerV2 = onDocumentWritten({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
  const prodMsg = event.data?.after.data();
  const prev = event.data?.before.data();
  if (!prodMsg || prodMsg.status !== "dispatched" || prev?.status === "dispatched") return;
  if (prodMsg.control?.type !== "RESPONSE") return;

  const { appId } = event.params;
  try {
    const shadowSnap = await db.collection(`artifacts/${appId}/public/data/shadow_bus`).where("correlation_id", "==", prodMsg.correlation_id).get();
    if (shadowSnap.empty) return;

    const shadowMsg = shadowSnap.docs[0].data();
    const isMatch = areResultsIdentical(prodMsg.payload?.result || {}, shadowMsg.payload?.result || {});

    await db.collection(artifacts/${appId}/public/data/shadow_runs).doc(prodMsg.correlation_id).set({
      correlation_id: prodMsg.correlation_id,
      status: isMatch ? "validated" : "failed",
      timestamp: new Date().toISOString()
    });
  } catch (e) { console.error("Shadow Error", e); }
});

export const logicCollisionWorkerV2 = onDocumentCreated({
  document: "artifacts/{appId}/public/data/logic_dependencies/{hbrId}",
  memory: "512MiB"
}, async (event) => {
  console.log("[COLLISION] Processing dependency map for:", event.params.hbrIdi;
});

export const evolutionProposalFinalizedV2 = onDocumentUpdated({
  document: "artifacts/local2local-kaskflow/public/data/logic_proposals/{proposalId}",
  memory: "512MiB"
}, async (event) => {
  const newData = event.data?.after.data();
  if (!newData) return;

  const status = (newData.status || "").toUpperCase();
  if (status === "APPROVED" && newData.commit_pending === true) {
    const dbInstance = admin.firestore();
    const hbrTarget = newData.hbrId || newData.hbr_target || "UNKNOWN";
    try {
      const batch = dbInstance.batch();
      const lessonRef = dbInstance.collection("artifacts").doc(appIdStatic).collection("public").doc("data").collection("lessons_learned").doc();

      batch.set(lessonRef, {
        reasoning_vault: newData.reasoning_vault || {},
        applied_logic: newData.proposedLogic || newData.proposed_logic || "N/A",
        hbr_target: hbrUF&vWB��vV�E��C��WtFF�&��6��tvV�D�B���WtFF�vV�E��B��%5�5DT�"��f��Ɨ�VE�C�f�V�Ef�VR�6W'fW%F��W7F�����6�W&6U�&��6âWfV�B�&�2�&��6Ė@�ғ���6��7B�'%&Vb�F$��7F�6R�F�2�'F�f7G2�G��E7FF�7��V&Ɩ2�FF��'%�&Vv�7G'��&Vv�7G'��G��'%F&vWG����&F6��WFFR��'%&Vb�����6��7FGW3�$�D�R"���7E���F�f�VC�f�V�Ef�VR�6W'fW%F��W7F����ғ���&F6��FV�WFR�WfV�B�FF�gFW"�&Vb���v�B&F6��6��֗B����6��6��R���r��Ud��UD����3e�&�6W76VBG��'%Target}`);
    } catch (e) {
      console.error("Batch Error", e);
    }
  }
});

export const evolutionForceBaselineV2 = onRequest(async (req: Request, res: Response) => {
  const dbInstance = admin.firestore();
  try {
    await dbInstance.collection("artifacts").doc(appIdStatic).collection("public").doc("data").collection("lessons_learned").doc("baseline_ping").set({
      message: "Verified",
      timestamp: FieldValue.serverTimestamp()
    });
    res.status(200).send("☈ Success");
  } catch (e: any) { res.status(500).send("❬ Fail: " + e.message); }
});