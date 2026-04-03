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
        commit_pending : true,
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

export const shadowComparatorWorkerV2 = ondocumentWritten({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
  const prodMsg = event.data?.after.data();
  const prev = event.data?.before.data();
  if (!prodMsg || prodMsg.status !== "dispatched" || prev?.status === "dispatched") return;
  if (prodMsg.control?.type !== "RESPONSE") return;

  const { appId } = event.params;
  try {
    const shadowSnap = await db.collection(artifacts/${appId}/public/data/shadow_bus)..where("correlation_id", "==", prodMsg.correlation_id).get();
    if (shadowSnap.empty) return;

    const shadowMsg = shadowSnap.docs[0].data();
    const isMatch = areResultsIdentical(prodMsg.payload?.result || {}, shadowMsg.payload?.result || {});

    await db.collection(`artifacts/${appId}/public/data/shadow_runs`).doc(prodMsg.correlation_id).set({
      correlation_id: prodMsg.correlation_id,
      status: isMatch ? "validated" : "failed",
      timestamp: new Date().toISOString()
    });
  } catch (e) { console.error"([SHADOW] Error:", e); }
});

export const logicCollisionWorkerV2 = onDocumentCreated({
  document: "artifacts/{appId}/public/data/logic_dependencies/{hbrId}",
  memory: "512MiB"
}, async (event) => {
  console.log("[COLLISION] Processing dependency map for:", event.params.hbrId);
});

export const evolutionProposalFinalizedV2