import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import type { FirestoreEvent, Change, DocumentSnapshot } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import axios from "axios";
import { v4 as uuidv4 } from "uuid";

const db = admin.firestore();
type L2LWrittenEvent = FirestoreEvent<Change<DocumentSnapshot> | undefined, { appId: string; [key: string]: string }>;

async function signalOrchestrator(payload: any, eventType: string = "DEPLOYMENT_COMPLETE") {
  const N8N_WEBHOOK_URL = "https://local2local.app.n8n.cloud/webhook/l2laaf-payload-trigger";
  try {
    await axios.post(N8N_WEBHOOK_URL, {
      build_id: payload.correlation_id || ("EVO-" + Date.now()),
      summary: payload.manifest?.reason || payload.manifest?.error || payload.summary || "Autonomous logic update.",
      event: eventType,
      filePath: payload.manifest?.targetPath || "functions/src/logic/evolution.ts",
      fileContent: payload.manifest?.proposedLogic || null,
      stackTrace: payload.manifest?.stackTrace || null,
      platform: payload.manifest?.platform || null,
      branch: "develop"
    });
  } catch (error) { console.error("❌ ORCHESTRATOR: Failed to signal [" + eventType + "]"); }
}

export const ingestWebErrorV2 = onRequest({ cors: true, memory: "256MiB" }, async (req, res) => {
    try {
        const { error, stackTrace, isFatal, appId, platform } = req.body;

        if (!error) {
            res.status(400).send({ status: "error", message: "Missing error field" });
            return;
        }

        const targetAppId = appId || "local2local-kaskflow";
        const now = admin.firestore.FieldValue.serverTimestamp();

        await db.collection("artifacts/" + targetAppId + "/public/data/agent_bus").add({
            correlation_id: "ERR-" + Date.now(),
            status: "dispatched",
            provenance: { sender_id: "TELEMETRY_CLIENT", receiver_id: "EVOLUTION_WORKER" },
            control: { type: "REQUEST", priority: isFatal ? "urgent" : "high" },
            payload: {
                manifest: {
                    intent: "AUTONOMOUS_REMEDIATION",
                    error,
                    stackTrace,
                    platform
                }
            },
            created_at: now,
            last_updated: now,
            telemetry: { processed_at: now },
        });

        res.status(200).send({ status: "ingested" });
    } catch (err: any) {
        console.error("Failed to ingest error:", err);
        res.status(500).send({ status: "error", message: err.message });
    }
});

export const evolutionOrchestratorV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}", memory: "512MiB" }, async (event: L2LWrittenEvent) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "dispatched") return;

  const intent = data.payload?.manifest?.intent;
  if (intent !== "PROPOSE_LOGIC_CHANGE" && intent !== "AUTONOMOUS_REMEDIATION") return;

  const { appId } = event.params;
  const manifest = data.payload.manifest;
  const correlationId = data.correlation_id || event.params.messageId;

  try {
    if (intent === "PROPOSE_LOGIC_CHANGE") {
        const lockRef = db.collection("artifacts/" + appId + "/public/data/logic_locks").doc(manifest.hbrId || "UNKNOWN_HBR");
        await db.runTransaction(async (transaction) => {
          const lockSnap = await transaction.get(lockRef);
          if (lockSnap.exists) throw new Error("COLLISION: HBR " + manifest.hbrId + " locked.");
          transaction.set(lockRef, { agentId: manifest.agentId, lockedAt: admin.firestore.FieldValue.serverTimestamp(), correlation_id: correlationId });
        });
        const shadowRef = db.collection("artifacts/" + appId + "/public/data/shadow_runs").doc(correlationId);
        await shadowRef.set({ status: "INITIALIZING", proposal_id: manifest.hbrId || "UNKNOWN", agent_id: manifest.agentId, started_at: admin.firestore.FieldValue.serverTimestamp() });
        await signalOrchestrator(data, "PROPOSAL_SUBMITTED");

    } else if (intent === "AUTONOMOUS_REMEDIATION") {
        await signalOrchestrator(data, "REMEDIATION_REQUESTED");
    }
  } catch (e) { throw e; }
});

export const ombudsmanValidatorV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/shadow_runs/{runId}" }, async (event: L2LWrittenEvent) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "VALIDATED") return;
  await signalOrchestrator({ correlation_id: event.params.runId, summary: "⚖️ Ombudsman validated shadow run: " + event.params.runId }, "SHADOW_VALIDATED");
});

export const autonomousFixerV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/system_state/state" }, async (event) => {
  const state = event.data?.after.data();
  if (!state || state.approval_gate?.status !== "FAILED_AUDIT") return;
  const { appId } = event.params;
  const now = admin.firestore.FieldValue.serverTimestamp();
  await db.collection("artifacts/" + appId + "/public/data/agent_bus").doc(uuidv4()).set({
    status: "dispatched",
    correlation_id: "FIX-" + Date.now(),
    provenance: { sender_id: "AUTONOMOUS_FIXER", receiver_id: "EVOLUTION_ENGINE" },
    payload: { intent: "REQUEST_REASONING", context: "AUDIT_FAILURE", details: "Self-healing protocol initiated." },
    created_at: now,
    last_updated: now,
    telemetry: { processed_at: now },
  });
});

export const evolutionProposalFinalizerV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/logic_proposals/{proposalId}" }, async (event: L2LWrittenEvent) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "PROMOTED") return;
  if (data.hbrId) {
    await db.doc("artifacts/" + event.params.appId + "/public/data/logic_locks/" + data.hbrId).delete();
  }
  await db.collection("artifacts/" + event.params.appId + "/public/data/lessons_learned").add({ ...data, archived_at: admin.firestore.FieldValue.serverTimestamp() });
});