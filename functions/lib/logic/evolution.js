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
exports.evolutionProposalFinalizerV2 = exports.autonomousFixerV2 = exports.ombudsmanValidatorV2 = exports.evolutionOrchestratorV2 = exports.ingestWebErrorV2 = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
const axios_1 = __importDefault(require("axios"));
const uuid_1 = require("uuid");
const db = admin.firestore();
async function signalOrchestrator(payload, eventType = "DEPLOYMENT_COMPLETE") {
    const N8N_WEBHOOK_URL = "https://local2local.app.n8n.cloud/webhook/l2laaf-payload-trigger";
    try {
        await axios_1.default.post(N8N_WEBHOOK_URL, {
            build_id: payload.correlation_id || ("EVO-" + Date.now()),
            summary: payload.manifest?.reason || payload.manifest?.error || payload.summary || "Autonomous logic update.",
            event: eventType,
            filePath: payload.manifest?.targetPath || "functions/src/logic/evolution.ts",
            fileContent: payload.manifest?.proposedLogic || null,
            stackTrace: payload.manifest?.stackTrace || null,
            platform: payload.manifest?.platform || null,
            branch: "develop"
        });
    }
    catch (error) {
        console.error("❌ ORCHESTRATOR: Failed to signal [" + eventType + "]");
    }
}
exports.ingestWebErrorV2 = (0, https_1.onRequest)({ cors: true, memory: "256MiB" }, async (req, res) => {
    try {
        const { error, stackTrace, isFatal, appId, platform } = req.body;
        if (!error) {
            res.status(400).send({ status: "error", message: "Missing error field" });
            return;
        }
        const targetAppId = appId || "local2local-kaskflow";
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
            }
        });
        res.status(200).send({ status: "ingested" });
    }
    catch (err) {
        console.error("Failed to ingest error:", err);
        res.status(500).send({ status: "error", message: err.message });
    }
});
exports.evolutionOrchestratorV2 = (0, firestore_1.onDocumentWritten)({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}", memory: "512MiB" }, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched")
        return;
    const intent = data.payload?.manifest?.intent;
    if (intent !== "PROPOSE_LOGIC_CHANGE" && intent !== "AUTONOMOUS_REMEDIATION")
        return;
    const { appId } = event.params;
    const manifest = data.payload.manifest;
    const correlationId = data.correlation_id || event.params.messageId;
    try {
        if (intent === "PROPOSE_LOGIC_CHANGE") {
            const lockRef = db.collection("artifacts/" + appId + "/public/data/logic_locks").doc(manifest.hbrId || "UNKNOWN_HBR");
            await db.runTransaction(async (transaction) => {
                const lockSnap = await transaction.get(lockRef);
                if (lockSnap.exists)
                    throw new Error("COLLISION: HBR " + manifest.hbrId + " locked.");
                transaction.set(lockRef, { agentId: manifest.agentId, lockedAt: admin.firestore.FieldValue.serverTimestamp(), correlation_id: correlationId });
            });
            const shadowRef = db.collection("artifacts/" + appId + "/public/data/shadow_runs").doc(correlationId);
            await shadowRef.set({ status: "INITIALIZING", proposal_id: manifest.hbrId || "UNKNOWN", agent_id: manifest.agentId, started_at: admin.firestore.FieldValue.serverTimestamp() });
            await signalOrchestrator(data, "PROPOSAL_SUBMITTED");
        }
        else if (intent === "AUTONOMOUS_REMEDIATION") {
            await signalOrchestrator(data, "REMEDIATION_REQUESTED");
        }
    }
    catch (e) {
        throw e;
    }
});
exports.ombudsmanValidatorV2 = (0, firestore_1.onDocumentWritten)({ document: "artifacts/{appId}/public/data/shadow_runs/{runId}" }, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "VALIDATED")
        return;
    await signalOrchestrator({ correlation_id: event.params.runId, summary: "⚖️ Ombudsman validated shadow run: " + event.params.runId }, "SHADOW_VALIDATED");
});
exports.autonomousFixerV2 = (0, firestore_1.onDocumentWritten)({ document: "artifacts/{appId}/public/data/system_state/state" }, async (event) => {
    const state = event.data?.after.data();
    if (!state || state.approval_gate?.status !== "FAILED_AUDIT")
        return;
    const { appId } = event.params;
    await db.collection("artifacts/" + appId + "/public/data/agent_bus").doc((0, uuid_1.v4)()).set({
        status: "dispatched",
        correlation_id: "FIX-" + Date.now(),
        provenance: { sender_id: "AUTONOMOUS_FIXER", receiver_id: "EVOLUTION_ENGINE" },
        payload: { intent: "REQUEST_REASONING", context: "AUDIT_FAILURE", details: "Self-healing protocol initiated." }
    });
});
exports.evolutionProposalFinalizerV2 = (0, firestore_1.onDocumentWritten)({ document: "artifacts/{appId}/public/data/logic_proposals/{proposalId}" }, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "PROMOTED")
        return;
    if (data.hbrId) {
        await db.doc("artifacts/" + event.params.appId + "/public/data/logic_locks/" + data.hbrId).delete();
    }
    await db.collection("artifacts/" + event.params.appId + "/public/data/lessons_learned").add({ ...data, archived_at: admin.firestore.FieldValue.serverTimestamp() });
});
//# sourceMappingURL=evolution.js.map