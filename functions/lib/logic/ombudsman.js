"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ombudsWorkerV2 = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
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
                    }
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