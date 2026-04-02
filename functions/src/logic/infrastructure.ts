import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { db, getProjectId } from "../config";
import { AgentBusClient } from "../agentBusClient";
import { getDistanceMeters } from "../shared";

/**
 * UTILITY: CENTRALIZED PII SCRUBBER
 */
const scrubPII = (text: string): string => {
    const emailPattern = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
    const phonePattern = /(\+?\d{1,2}\s?)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}/g;
    
    return text
        .replace(emailPattern, "[MASKED_EMAIL]")
        .replace(phonePattern, "[MASKED_PHONE]");
};

// ... [Existing identityAnomalyWorkerV2, identityBridgeWorkerV2, safetyAlertWorkerV2, residencyAuditWorkerV2 remain unchanged] ...

/**
 * 5. ZERO-TRUST BARRIER & SHADOW FORK
 */
export const onMessageWrittenV2 = onDocumentCreated("artifacts/{appId}/public/data/agent_bus/{messageId}", async (event) => {
    const data = event.data?.data();
    if (!data || (data.status !== "pending" && data.status !== "intercepted")) return;
    
    const { appId } = event.params;
    const receiverId = data.provenance.receiver_id;
    
    const payloadString = JSON.stringify(data.payload || {});
    const scrubbedPayload = JSON.parse(scrubPII(payloadString));
    
    const agentSnap = await db.doc(`artifacts/${appId}/public/data/agent_registry/${receiverId}`).get();
    const agentMode = agentSnap.data()?.status?.mode;
    
    if (agentMode === "shadow" || agentMode === "shadow_testing") {
        await db.collection(`artifacts/${appId}/public/data/shadow_bus`).doc(event.params.messageId).set({
            ...data, payload: scrubbedPayload, status: "dispatched", is_shadow_clone: true, forked_at: new Date().toISOString()
        });
    }

    return event.data?.ref.update({ 
        status: "dispatched", payload: scrubbedPayload, "telemetry.processed_at": new Date().toISOString() 
    });
});

// ... [Existing facilityMatchingWorkerV2, onUserCreatedV2, agentHeartbeatMonitorV2 remain unchanged] ...

/**
 * 9. CONTEXT FOLDING WORKER
 */
export const contextFoldingWorkerV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "INFRASTRUCTURE_WORKER") return;

    const { appId } = event.params;
    const client = new AgentBusClient({ agentId: "INFRASTRUCTURE_WORKER", capabilities: ["context_management"], jurisdictions: ["AB"], substances: ["DATA"], role: "WORKER", domain: "SECURITY" }, appId);
    await client.register();

    try {
        const { intent, correlationId, targetAgentId } = data.payload.manifest;
        if (intent === "FOLD_CONTEXT") {
            const traceSnap = await db.collection(`artifacts/${appId}/public/data/agent_bus`).where("correlation_id", "==", correlationId).get();
            if (traceSnap.empty) throw new Error("TRACE_NOT_FOUND");

            const historyText = traceSnap.docs.map(d => JSON.stringify(d.data().payload)).join(" ");
            const summary = `Thread compressed. Mission: ${correlationId}. Key milestones: ${historyText.substring(0, 200)}...`;
            const scrubbedSummary = scrubPII(summary);

            await db.doc(`artifacts/${appId}/public/data/agent_registry/${targetAgentId}`).update({
                "status.context_folded_at": new Date().toISOString(),
                "status.last_fold_anchor": scrubbedSummary
            });

            return client.sendResponse(data.correlation_id, data.provenance.sender_id, { status: "folded", originalTurns: traceSnap.docs.length, summary: scrubbedSummary });
        }
    } catch (e: any) { return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, { code: "FOLD_ERROR", message: e.message }); }
});

/**
 * 10. CROSS-TENANT SOVEREIGNTY AUDIT (Phase 32)
 * Ensures Kaskflow data never bleeds into Moonlitely buses or logic traces.
 */
export const sovereigntyAuditWorkerV2 = onDocumentCreated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { appId } = event.params;
    const payloadStr = JSON.stringify(data).toLowerCase();
    
    // 1. Identify "The Enemy" namespace
    const siblingAppId = appId.includes("kaskflow") 
        ? "moonlitely" 
        : "kaskflow";

    // 2. Scan for cross-tenant keywords in identifiers or payload
    const hasLeak = payloadStr.includes(siblingAppId);

    if (hasLeak) {
        console.warn(`[SOVEREIGNTY_BREACH] Data leak detected in ${appId}. Found reference to ${siblingAppId}.`);
        
        // 3. Immediately halt the message
        await event.data?.ref.update({
            "status": "blocked",
            "control.security_tier": 3,
            "error": {
                "code": "SOVEREIGNTY_VIOLATION",
                "message": "Cross-tenant data contamination detected. Message quarantined."
            }
        });

        // 4. Trigger Emergency Red Intervention
        await db.collection(`artifacts/${appId}/public/data/interventions`).add({
            type: "DATA_SOVEREIGNTY_VIOLATION",
            severity: "critical",
            status: "active",
            details: `PIPA COMPLIANCE RISK: Agent bus message in ${appId} contains data from ${siblingAppId} namespace. Transaction halted.`,
            createdAt: new Date().toISOString(),
            correlation_id: data.correlation_id
        });
    }
});