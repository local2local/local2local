import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../config";
import { AgentBusClient } from "../agentBusClient";

/**
 * 1. OMBUDS WORKER (Step 9.2: Dispute Triage)
 * Scans user feedback for sentiment and urgency. 
 * Escalates high-risk issues to the Intervention Queue.
 */
export const ombudsWorkerV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "OMBUDS_WORKER") return;

    const client = new AgentBusClient({ 
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
                // Autonomous Escalation to Safety Worker for Intervention creation
                const busRef = db.collection(`artifacts/${appId}/public/data/agent_bus`);
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

            // Normal Log for non-urgent feedback
            await db.collection(`artifacts/${appId}/public/data/platform_feedback`).add({
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
    } catch (error: any) {
        return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, {
            code: "OMBUDS_ERROR", message: error.message
        });
    }
});