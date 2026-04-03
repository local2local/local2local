import { onDocumentWritten, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import type { Request, Response } from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../config";
import { AgentBusClient } from "../agentBusClient";

const appIdStatic = "local2local-kaskflow";

export const evolutionOrchestratorV2 = onDocumentWritten({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched") return;
    if (data.provenance?.receiver_id !== "EVOLUTION_WORKER") return;

    const { appId } = event.params;
    const client = new AgentBusClient({
      agentId: "EVOLUTION_WORKER",
      capabilities: ["logic_optimization", "memory_commit"],
      jurisdictions: ["AB"],
      substances: ["DATA"],
      role: "ORCHESTRATOR",
      domain: "SECURITY"
    }, appId);
    await client.register();

    try {
        const manifest = data.payload?.manifest;
        if (!manifest) return;

        if (manifest.intent === "PROPOSE_LOGIC_CHANGE") {
            const { hbrId, agentId, proposedLogic, reason } = manifest;
            const proposalRef = db.collection(artifacts/${appId}/public/data/logic_proposals).doc();
            await proposalRef.set({ hbrId, agentId, proposedLogic, reason, status: "PENDING", commit_pending: true, createdAt: new Date().toISOString() });
            return client.sendResponse(data.correlation_id, data.provenance.sender_id, { status: "REGISTERED", proposalId: proposalRef.id });
        }
    } catch (err) { console.error("Evolution Error", err); }
});

export const onProposalFinalized = onDocumentUpdated(
  "artifacts/local2local-kaskflow/public/data/logic_proposals/{proposalId}",
  async (event) => {
    const newData = event.data?.after.data();
    if (!newData) return;

    const status = (newData.status || "").toUpperCase();
    if (status === "APPROVED" && newData.commit_pending === true) {
      const dborg = admin.firestore();
      const hbr = newData.hbrId || newData.hbr_target || "UNKNOWN";
      try {
        const batch = dborg.batch();
        const lessonRef = dborg.collection("artifacts").doc(appIdStatic).collection("public").doc("data").collection("lessons_learned").doc();
        batch.set(lessonRef, {
          reasoning_vault: newData.reasoning_vault || {},
          applied_logic: newData.proposedLogic || newData.proposed_logic || "N/A",
          hbr_target: hbr,
          agent_id: newData.proposingAgentId || newData.agent_id || "SYSTEM",
          finalized_at: FieldValue.serverTimestamp(),
          source_proposal: event.params.proposalId
        });
        const hbrRef = dborg.doc(artifacts/${appIdStatic}/public/data/hbr_registry/registry/${hbr});
        batch.update(hbrRef, { lock_status: "IDLE", last_modified: FieldValue.serverTimestamp() });
        batch.delete(event.data!.after.ref);
        await batch.commit();
        console.log(`[EVOLUTION-P36] Processed ${hbr}`);
      } catch (e) { console.error("Batch Error", e); }
    }
  }
);

export const forceBaseline = onRequest(async (req: Request, res: Response) => {
  const dbInstance = admin.firestore();
  try {
    await dbInstance.doc(artifacts/${appIdStatic}/public/data/lessons_learned/baseline_ping).set({
      message: "Verified",
      timestamp: FieldValue.serverTimestamp()
    });
    res.status(200).send("☍ Success");
  } catch (e: any) { res.status(500).send("❌ Fail: " + e.message); }
});
