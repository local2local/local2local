"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.evolutionProposalFinalizerV2 = exports.autonomousFixerV2 = exports.ombudsmanValidatorV2 = exports.evolutionOrchestratorV2 = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const admin = __importStar(require("firebase-admin"));
const axios_1 = __importDefault(require("axios"));
const uuid_1 = require("uuid");
const db = admin.firestore();
async function signalOrchestrator(payload, eventType, meta) {
    const N8N_WEBHOOK_URL = "https://local2local.app.n8n.cloud/webhook/l2laaf-payload-trigger";
    try {
        await axios_1.default.post(N8N_WEBHOOK_URL, {
            incoming_phase: "40.7.22",
            build_id: meta.buildId || payload.correlation_id || `EVO-${Date.now()}`,
            summary: payload.payload?.manifest?.reason || payload.summary || "Circuit stabilization update.",
            event: eventType,
            hbrId: meta.hbrId || null,
            filePath: payload.payload?.manifest?.targetPath || "functions/src/logic/evolution.ts",
            fileContent: payload.payload?.manifest?.proposedLogic || null,
            branch: "develop"
        });
    }
    catch (error) {
        console.error(`❌ ORCHESTRATOR: Failed to signal [${eventType}]`);
    }
}
exports.evolutionOrchestratorV2 = (0, firestore_1.onDocumentWritten)({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}", memory: "512MiB" }, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.payload?.manifest?.intent !== "PROPOSE_LOGIC_CHANGE")
        return;
    const { appId } = event.params;
    const manifest = data.payload.manifest;
    const correlationId = data.correlation_id || event.params.messageId;
    const lockRef = db.collection(`artifacts/${appId}/public/data/logic_locks`).doc(manifest.hbrId);
    try {
        await db.runTransaction(async (transaction) => {
            const lockSnap = await transaction.get(lockRef);
            if (lockSnap.exists)
                throw new Error(`COLLISION: HBR ${manifest.hbrId} locked.`);
            transaction.set(lockRef, { agentId: manifest.agentId, lockedAt: admin.firestore.FieldValue.serverTimestamp(), correlation_id: correlationId });
            const registryRef = db.doc(`artifacts/${appId}/public/data/hbr_registry/${manifest.hbrId}`);
            transaction.set(registryRef, { lock_status: "LOCKED", locked_by: manifest.agentId, last_modified: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        });
        const shadowRef = db.collection(`artifacts/${appId}/public/data/shadow_runs`).doc(correlationId);
        await shadowRef.set({ status: "INITIALIZING", proposal_id: manifest.hbrId, agent_id: manifest.agentId, started_at: admin.firestore.FieldValue.serverTimestamp() });
        await signalOrchestrator(data, "PROPOSAL_SUBMITTED", { hbrId: manifest.hbrId, buildId: correlationId });
    }
    catch (e) {
        throw e;
    }
});
exports.ombudsmanValidatorV2 = (0, firestore_1.onDocumentWritten)({ document: "artifacts/{appId}/public/data/shadow_runs/{runId}" }, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "VALIDATED")
        return;
    const hbrId = data.proposal_id || null;
    await signalOrchestrator({ summary: `⚖️ Ombudsman validated shadow run: ${event.params.runId}.` }, "SHADOW_VALIDATED", { buildId: event.params.runId, hbrId });
});
exports.autonomousFixerV2 = (0, firestore_1.onDocumentWritten)({ document: "artifacts/{appId}/public/data/system_state/state" }, async (event) => {
    const state = event.data?.after.data();
    if (!state || state.approval_gate?.status !== "FAILED_AUDIT")
        return;
    const { appId } = event.params;
    await db.collection(`artifacts/${appId}/public/data/agent_bus`).doc((0, uuid_1.v4)()).set({
        status: "dispatched",
        correlation_id: `FIX-${Date.now()}`,
        provenance: { sender_id: "AUTONOMOUS_FIXER", receiver_id: "EVOLUTION_ENGINE" },
        payload: { intent: "REQUEST_REASONING", context: "AUDIT_FAILURE", details: "Self-healing protocol initiated." }
    });
});
exports.evolutionProposalFinalizerV2 = (0, firestore_1.onDocumentWritten)({ document: "artifacts/{appId}/public/data/logic_proposals/{proposalId}" }, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "PROMOTED")
        return;
    const { appId } = event.params;
    const hbrId = data.hbrId;
    const buildId = data.buildId || null;
    if (!hbrId || ["", "undefined", "null"].includes(hbrId)) {
        console.warn(`⚠️ FINALIZER: Missing hbrId. appId: ${appId}`);
        return;
    }
    try {
        const lockPath = `artifacts/${appId}/public/data/logic_locks/${hbrId}`;
        console.log(`🧹 FINALIZER: Purging lock: ${lockPath}`);
        await db.doc(lockPath).delete();
        await db.doc(`artifacts/${appId}/public/data/hbr_registry/${hbrId}`).set({
            lock_status: "UNLOCKED",
            last_modified: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        if (buildId) {
            const shadowPath = `artifacts/${appId}/public/data/shadow_runs/${buildId}`;
            console.log(`🧹 FINALIZER: Purging shadow run: ${shadowPath}`);
            await db.doc(shadowPath).delete();
        }
        await db.collection(`artifacts/${appId}/public/data/lessons_learned`).add({
            ...data,
            archived_at: admin.firestore.FieldValue.serverTimestamp(),
            diagnostic_dump: { trace_id: "v40.7.22" }
        });
    }
    catch (err) {
        console.error(`❌ FINALIZER ERROR: ${err.message}`);
    }
});
//# sourceMappingURL=evolution.js.map