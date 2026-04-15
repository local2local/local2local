import { onDocumentWritten } from "firebase-functions/v2/firestore";
import type { FirestoreEvent, Change, DocumentSnapshot } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import axios from "axios";
import { v4 as uuidv4 } from "uuid";

const db = admin.firestore();
type L2LWrittenEvent = FirestoreEvent<Change<DocumentSnapshot> | undefined, { appId: string; [key: string]: string }>;

async function signalOrchestrator(payload: any, eventType: string, meta: { hbrId?: string, buildId?: string }) {
  const N8N_WEBHOOK_URL = "https://local2local.app.n8n.cloud/webhook/l2laaf-payload-trigger";
  try {
    await axios.post(N8N_WEBHOOK_URL, {
      incoming_phase: "40.4.2",
      build_id: meta.buildId || payload.correlation_id || `EVO-${Date.now()}`,
      summary: payload.manifest?.reason || payload.summary || "Autonomous logic update.",
      event: eventType,
      hbrId: meta.hbrId || null,
      filePath: payload.manifest?.targetPath || "functions/src/logic/evolution.ts",
      fileContent: payload.manifest?.proposedLogic || null,
      branch: "develop"
    });
  } catch (error) { console.error(`❌ ORCHESTRATOR: Failed to signal [${eventType}]`); }
}

export const evolutionOrchestratorV3 = onDocumentWritten({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}", memory: "512MiB" }, async (event: L2LWrittenEvent) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "dispatched" || data.payload?.manifest?.intent !== "PROPOSE_LOGIC_CHANGE") return;
  const { appId } = event.params;
  const manifest = data.payload.manifest;
  const correlationId = data.correlation_id || event.params.messageId;
  const lockRef = db.collection(`artifacts/${appId}/public/data/logic_locks`).doc(manifest.hbrId);
  try {
    await db.runTransaction(async (transaction) => {
      const lockSnap = await transaction.get(lockRef);
      if (lockSnap.exists) throw new Error(`COLLISION: HBR ${manifest.hbrId} locked.`);
      transaction.set(lockRef, { agentId: manifest.agentId, lockedAt: admin.firestore.FieldValue.serverTimestamp(), correlation_id: correlationId });
      const registryRef = db.doc(`artifacts/${appId}/public/data/hbr_registry/${manifest.hbrId}`);
      transaction.set(registryRef, { lock_status: "LOCKED", locked_by: manifest.agentId, last_modified: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    });
    const shadowRef = db.collection(`artifacts/${appId}/public/data/shadow_runs`).doc(correlationId);
    await shadowRef.set({ status: "INITIALIZING", proposal_id: manifest.hbrId, agent_id: manifest.agentId, started_at: admin.firestore.FieldValue.serverTimestamp() });
    await signalOrchestrator(data, "PROPOSAL_SUBMITTED", { hbrId: manifest.hbrId, buildId: correlationId });
  } catch (e) { throw e; }
});

export const ombudsmanValidatorV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/shadow_runs/{runId}" }, async (event: L2LWrittenEvent) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "VALIDATED") return;
  const hbrId = data.proposal_id || null;
  await signalOrchestrator({ summary: `⚖️ Ombudsman validated shadow run: ${event.params.runId}.` }, "SHADOW_VALIDATED", { buildId: event.params.runId, hbrId });
});

export const autonomousFixerV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/system_state/state" }, async (event) => {
  const state = event.data?.after.data();
  if (!state || state.approval_gate?.status !== "FAILED_AUDIT") return;
  const { appId } = event.params;
  await db.collection(`artifacts/${appId}/public/data/agent_bus`).doc(uuidv4()).set({
    status: "dispatched",
    correlation_id: `FIX-${Date.now()}`,
    provenance: { sender_id: "AUTONOMOUS_FIXER", receiver_id: "EVOLUTION_ENGINE" },
    payload: { intent: "REQUEST_REASONING", context: "AUDIT_FAILURE", details: "Self-healing protocol initiated." }
  });
});

// ── evolutionProposalFinalizerV2 v40.4.2 ──────────────────────────────────────
// FIX: Hard-abort on null/empty/sentinel hbrId BEFORE any Firestore write.
// This is Layer 3 defense-in-depth — the primary gates are in n8n (Layers 1+2),
// but this function must never trust upstream data without its own validation.
export const evolutionProposalFinalizerV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/logic_proposals/{proposalId}" }, async (event: L2LWrittenEvent) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "PROMOTED") return;

  const { appId } = event.params;
  const hbrId: string | null = data.hbrId ?? null;
  const buildId: string | null = data.buildId ?? null;

  // ── HARD GATE: reject sentinel values that bypassed n8n gates ──────────────
  const INVALID_HBRID_SENTINELS = ["", "undefined", "null"];
  if (!hbrId || INVALID_HBRID_SENTINELS.includes(hbrId)) {
    console.error(
      `[evolutionProposalFinalizer] ABORT: Invalid hbrId "${hbrId}" on proposal ` +
      `${event.params.proposalId}. Firestore write suppressed. ` +
      `This indicates a logic-bleed from a non-proposal deployment path.`
    );
    // Write a diagnostic doc to a quarantine collection for post-mortem analysis.
    await db.collection(`artifacts/${appId}/public/data/finalizer_quarantine`).add({
      reason: "INVALID_HBRID",
      hbrId_received: hbrId,
      proposalId: event.params.proposalId,
      payload_keys: Object.keys(data),
      quarantined_at: admin.firestore.FieldValue.serverTimestamp(),
      diagnostic_dump: { trace_id: "v40.4.2", buildId }
    });
    return; // terminate — no lock delete, no registry update, no lessons_learned write
  }

  // ── Proceed only with a validated hbrId ────────────────────────────────────
  await db.doc(`artifacts/${appId}/public/data/logic_locks/${hbrId}`).delete();
  await db.doc(`artifacts/${appId}/public/data/hbr_registry/${hbrId}`).set(
    { lock_status: "UNLOCKED", last_modified: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );

  if (buildId) {
    await db.doc(`artifacts/${appId}/public/data/shadow_runs/${buildId}`).delete();
  }

  await db.collection(`artifacts/${appId}/public/data/lessons_learned`).add({
    ...data,
    archived_at: admin.firestore.FieldValue.serverTimestamp(),
    diagnostic_dump: {
      trace_id: "v40.4.2",
      ts: new Date().toISOString(),
      hbr_found: true, // guaranteed by hard gate above
      payload_keys: Object.keys(data)
    }
  });
});