import { onDocumentCreated, onDocumentUpdated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { db } from "../config";
import { AgentBusClient } from "../agentBusClient";

// ... (Previous workers 1-4 remain unchanged) ...

/**
 * 5. EFFICACY AUDIT WORKER (Phase 27: Self-Healing Triggers)
 * Guarded: Only audits 'dispatched' messages to prevent duplicate triggers 
 * during the Interception/Dispatch lifecycle.
 */
export const efficacyAuditWorkerV2 = onDocumentWritten({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    
    // 1. Validation Logic: ONLY audit when the message is fully 'dispatched'
    // This prevents the double-trigger you saw during the Interception phase.
    if (!data || data.status !== "dispatched") return;
    if (data.control?.type !== "RESPONSE") return;
    if (!data.telemetry?.completed_at || !data.telemetry?.processed_at) return;
    
    // 2. Infinite Loop Guard
    if (data.correlation_id.startsWith("healing-")) return;

    const { appId } = event.params;
    const agentId = data.provenance.sender_id;
    
    const getTime = (val: any) => {
        if (!val) return NaN;
        if (val.toDate && typeof val.toDate === 'function') return val.toDate().getTime();
        if (typeof val === 'string') {
            const dateStr = val.endsWith('Z') ? val : val + 'Z';
            return Date.parse(dateStr);
        }
        return NaN;
    };

    const end = getTime(data.telemetry.completed_at);
    const start = getTime(data.telemetry.processed_at);

    if (isNaN(start) || isNaN(end)) return;

    const latency = end - start;

    try {
        await db.collection(`artifacts/${appId}/public/data/efficacy_audit`).add({
            agentId,
            timestamp: new Date().toISOString(),
            latencyMs: latency,
            status: "success",
            correlation_id: data.correlation_id
        });

        const THRESHOLD = 8000;
        if (latency > THRESHOLD) {
            console.log(`[SELF-HEALING_TRIGGER] Latency: ${latency}ms for ${agentId}.`);
            
            await db.collection(`artifacts/${appId}/public/data/agent_bus`).add({
                correlation_id: `healing-${data.correlation_id}`,
                status: "pending",
                control: { type: "REQUEST", priority: "normal" },
                provenance: { sender_id: "ANALYTICS_WORKER", receiver_id: "INFRASTRUCTURE_WORKER" },
                payload: {
                    manifest: {
                        intent: "FOLD_CONTEXT",
                        correlationId: data.correlation_id,
                        targetAgentId: agentId
                    }
                }
            });
        }
    } catch (error: any) {
        console.error("[AUDIT_ERROR]", error.message);
    }
});