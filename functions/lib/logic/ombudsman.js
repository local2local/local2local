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
Object.defineProperty(exports, "__esModule", { value: true });
exports.ombudsWorkerV2 = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const admin = __importStar(require("firebase-admin"));
const config_1 = require("../config");
const agentBusClient_1 = require("../agentBusClient");
exports.ombudsWorkerV2 = (0, firestore_1.onDocumentUpdated)({
    document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
    memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "OMBUDS_WORKER")
        return;
    const client = new agentBusClient_1.AgentBusClient({
        agentId: "OMBUDS_WORKER", capabilities: ["sentiment_analysis", "dispute_triage"],
        jurisdictions: ["AB"], substances: ["DATA"], role: "WORKER", domain: "SECURITY"
    });
    await client.register();
    try {
        const { intent, userId, category, feedbackText } = data.payload.manifest;
        const { appId } = event.params;
        if (intent === "PROCESS_FEEDBACK") {
            const angerKeywords = ["stole", "scam", "wrong", "broken", "angry", "never", "payout", "money"];
            const lowerText = (feedbackText || "").toLowerCase();
            const isUrgent = angerKeywords.some(keyword => lowerText.includes(keyword)) || category === "financial";
            if (isUrgent) {
                const now = admin.firestore.FieldValue.serverTimestamp();
                const busRef = config_1.db.collection(`artifacts/${appId}/public/data/agent_bus`);
                await busRef.add({
                    correlation_id: data.correlation_id,
                    status: "pending",
                    control: { type: "REQUEST", priority: "urgent" },
                    provenance: { sender_id: "OMBUDS_WORKER", receiver_id: "SAFETY_WORKER" },
                    payload: {
                        manifest: {
                            intent: "LOG_SAFETY_VIOLATION",
                            severity: "critical",
                            details: `URGENT FEEDBACK from ${userId}: ${feedbackText}`
                        }
                    },
                    created_at: now,
                    last_updated: now,
                    telemetry: { processed_at: now },
                });
                return client.sendResponse(data.correlation_id, data.provenance.sender_id, {
                    status: "escalated",
                    message: "High urgency detected. Human intervention requested."
                });
            }
            await config_1.db.collection(`artifacts/${appId}/public/data/platform_feedback`).add({
                userId,
                category,
                text: feedbackText,
                sentiment: "neutral",
                createdAt: new Date().toISOString()
            });
            return client.sendResponse(data.correlation_id, data.provenance.sender_id, {
                status: "logged",
                message: "Feedback archived for review."
            });
        }
        throw new Error(`UNSUPPORTED_INTENT: ${intent}`);
    }
    catch (error) {
        return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, {
            code: "OMBUDS_ERROR", message: error.message
        });
    }
});
//# sourceMappingURL=ombudsman.js.map