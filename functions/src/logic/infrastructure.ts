import { onDocumentCreated, onDocumentUpdated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { db, getProjectId } from "../config";
import { AgentBusClient } from "../agentBusClient";
import { getDistanceMeters } from "../shared";

/**
 * UTILITY: CENTRALIZED PII SCRUBBER
 * Detects Emails and NA Phone Numbers to enforce Zero-Trust silos.
 */
const scrubPII = (text: string): string => {
    const emailPattern = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g;
    const phonePattern = /(\+?\d{1,2}\s?)?\(?\d{3}\)?[\s.-]?\d{3}[\s.-]?\d{4}/g;
    
    return text
        .replace(emailPattern, "[MASKED_EMAIL]")
        .replace(phonePattern, "[MASKED_PHONE]");
};

/**
 * 1. IDENTITY ANOMALY WORKER
 * Detects 'Geography Pivots' where a user claims disparate locations.
 */
export const identityAnomalyWorkerV2 = onDocumentUpdated({
    document: "artifacts/{appId}/users/{userId}"
}, async (event) => {
    const newData = event.data?.after.data();
    const oldData = event.data?.before.data();
    if (!newData || !oldData) return;

    const newLoc = newData.locality?.basePoint;
    const oldLoc = oldData.locality?.basePoint;

    if (newLoc && oldLoc && (newLoc.latitude !== oldLoc.latitude || newLoc.longitude !== oldLoc.longitude)) {
        const distance = getDistanceMeters(newLoc.latitude, newLoc.longitude, oldLoc.latitude, oldLoc.longitude);
        
        if (distance > 50000) {
            const { appId, userId } = event.params;
            await db.collection(`artifacts/${appId}/public/data/agent_bus`).add({
                correlation_id: `fraud-${userId}-${Date.now()}`,
                status: "pending",
                control: { type: "REQUEST", priority: "high" },
                provenance: { sender_id: "IDENTITY_WORKER", receiver_id: "SAFETY_WORKER" },
                payload: {
                    manifest: {
                        intent: "LOG_SAFETY_VIOLATION",
                        severity: "critical",
                        details: `IDENTITY_SPOOFING: User ${userId} geographic pivot detected (${(distance / 1000).toFixed(1)}km discrepancy).`
                    }
                }
            });
        }
    }
});

/**
 * 2. IDENTITY BRIDGE WORKER
 */
export const identityBridgeWorkerV2 = onDocumentCreated("artifacts/{appId}/users/{userId}", async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const { appId, userId } = event.params;
    const siblingAppId = appId.includes("kaskflow") ? appId.replace("kaskflow", "moonlitely") : appId.replace("moonlitely", "kaskflow");
    const siblingDoc = await db.doc(`artifacts/${siblingAppId}/users/${userId}`).get();
    if (siblingDoc.exists) {
        const siblingData = siblingDoc.data();
        await event.data?.ref.update({ 
            "meta.isCrossTenant": true, 
            "meta.siblingStatus": siblingData?.aglcStatus?.status || "pending",
            "telemetry.last_bridge_sync": new Date().toISOString()
        });
    }
});

/**
 * 3. SAFETY ALERT WORKER
 */
export const safetyAlertWorkerV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "SAFETY_WORKER") return;
    const { appId } = event.params;
    const client = new AgentBusClient({ agentId: "SAFETY_WORKER", capabilities: ["threat_detection"], jurisdictions: ["AB"], substances: ["DATA"], role: "WORKER", domain: "SECURITY" }, appId);
    await client.register();
    try {
        const manifest = data.payload?.manifest;
        if (!manifest) return;
        const { intent, severity, details } = manifest;
        if (intent === "LOG_SAFETY_VIOLATION") {
            await db.collection(`artifacts/${appId}/public/data/interventions`).add({
                type: "SAFETY_VIOLATION", severity: severity || "high", status: "active",
                details: details || "Unknown safety exception", createdAt: new Date().toISOString(),
                correlation_id: data.correlation_id
            });
            return client.sendResponse(data.correlation_id, data.provenance.sender_id, { status: "escalated" });
        }
    } catch (e: any) { return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, { code: "SAFETY_ERROR", message: e.message }); }
});

/**
 * 4. RESIDENCY AUDIT WORKER
 */
export const residencyAuditWorkerV2 = onSchedule("every 24 hours", async () => {
    const projectId = getProjectId();
    const isCanadian = projectId.includes("northamerica-northeast");
    await db.collection("artifacts/global/public/data/compliance_logs").add({
        type: "RESIDENCY_AUDIT",
        status: isCanadian ? "PASS" : "FAIL",
        region: projectId,
        timestamp: new Date().toISOString(),
        details: isCanadian ? "Data residency confirmed in Canadian regions." : "CRITICAL: Data residency outside Canadian boundaries."
    });
});

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

/**
 * 6. FACILITY MATCHING WORKER
 */
export const facilityMatchingWorkerV2 = onDocumentUpdated({
    document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
    memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "FACILITY_MATCHING_WORKER") return;
    const { appId } = event.params;
    const client = new AgentBusClient({ agentId: "FACILITY_MATCHING_WORKER", capabilities: ["technical_alignment"], jurisdictions: ["AB"], substances: ["DATA"], role: "WORKER", domain: "OPS" }, appId);
    await client.register();
    try {
        const manifest = data.payload?.manifest;
        if (!manifest) return;
        const { venueId, requirements = [] } = manifest;
        const venueDoc = await db.doc(`artifacts/${appId}/users/${venueId}`).get();
        const facilities = venueDoc.data()?.facilityProfile?.onSiteFacilities || [];
        const missing = requirements.filter((req: string) => !facilities.includes(req));
        return client.sendResponse(data.correlation_id, data.provenance.sender_id, { isMatch: missing.length === 0, missingRequirements: missing });
    } catch (e: any) { return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, { code: "MATCHING_ERROR", message: e.message }); }
});

/**
 * 7. USER INITIALIZATION WORKER
 */
export const onUserCreatedV2 = onDocumentCreated("artifacts/{appId}/users/{userId}", async (event) => {
    const data = event.data?.data();
    if (!data) return;
    return event.data?.ref.update({ 
        trustScore: 50, 
        "meta.initializedAt": new Date().toISOString(),
        "status.mode": "active"
    });
});

/**
 * 8. AGENT HEARTBEAT MONITOR
 */
export const agentHeartbeatMonitorV2 = onSchedule("every 5 minutes", async () => {
    const appIds = ["local2local-kaskflow", "local2local-moonlitely"];
    const now = new Date();
    for (const appId of appIds) {
        const agentsSnap = await db.collection(`artifacts/${appId}/public/data/agent_registry`).get();
        for (const doc of agentsSnap.docs) {
            const lastHeartbeat = new Date(doc.data().status?.last_heartbeat || 0);
            if (now.getTime() - lastHeartbeat.getTime() > 600000) {
                await doc.ref.update({ "status.health": "red" });
            }
        }
    }
});

/**
 * 9. CONTEXT FOLDING WORKER
 * Hardened: Uses onDocumentWritten with transition guard for loop-proofing.
 */
export const contextFoldingWorkerV2 = onDocumentWritten({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    const prev = event.data?.before.data();
    
    // Transition Guard: Only process when transitioning TO dispatched
    if (!data || data.status !== "dispatched" || prev?.status === "dispatched") return;
    
    // Ensure this is a REQUEST for this worker
    if (data.control?.type !== "REQUEST" || data.provenance?.receiver_id !== "INFRASTRUCTURE_WORKER") return;

    const { appId } = event.params;
    const client = new AgentBusClient({ 
        agentId: "INFRASTRUCTURE_WORKER", capabilities: ["context_management"], 
        jurisdictions: ["AB"], substances: ["DATA"], role: "WORKER", domain: "SECURITY"
    }, appId);
    
    await client.register();

    try {
        const manifest = data.payload?.manifest;
        if (!manifest) throw new Error("MISSING_MANIFEST");

        const { intent, correlationId, targetAgentId } = manifest;

        if (intent === "FOLD_CONTEXT") {
            const traceSnap = await db.collection(`artifacts/${appId}/public/data/agent_bus`)
                .where("correlation_id", "==", correlationId)
                .get();

            if (traceSnap.empty) throw new Error("TRACE_NOT_FOUND");

            const historyText = traceSnap.docs
                .map(d => JSON.stringify(d.data().payload))
                .join(" ");

            const summary = `Thread compressed. Mission: ${correlationId}. Key milestones: ${historyText.substring(0, 200)}...`;
            const scrubbedSummary = scrubPII(summary);

            await db.doc(`artifacts/${appId}/public/data/agent_registry/${targetAgentId}`).update({
                "status.context_folded_at": new Date().toISOString(),
                "status.last_fold_anchor": scrubbedSummary
            });

            return client.sendResponse(data.correlation_id, data.provenance.sender_id, {
                status: "folded",
                originalTurns: traceSnap.docs.length,
                summary: scrubbedSummary
            });
        }
    } catch (e: any) {
        return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, { 
            code: "FOLD_ERROR", 
            message: e.message 
        });
    }
});

/**
 * 10. CROSS-TENANT SOVEREIGNTY AUDIT
 * Blocks cross-app data leaks to ensure PIPA compliance.
 */
export const sovereigntyAuditWorkerV2 = onDocumentCreated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { appId } = event.params;
    const payloadStr = JSON.stringify(data).toLowerCase();
    
    const siblingAppId = appId.includes("kaskflow") ? "moonlitely" : "kaskflow";
    const hasLeak = payloadStr.includes(siblingAppId);

    if (hasLeak) {
        console.warn(`[SOVEREIGNTY_BREACH] Blocked reference to ${siblingAppId} in ${appId}.`);
        
        await event.data?.ref.update({
            "status": "blocked",
            "control.security_tier": 3,
            "error": {
                "code": "SOVEREIGNTY_VIOLATION",
                "message": "Cross-tenant data contamination detected. Message quarantined."
            }
        });

        await db.collection(`artifacts/${appId}/public/data/interventions`).add({
            type: "DATA_SOVEREIGNTY_VIOLATION",
            severity: "critical",
            status: "active",
            details: `PIPA COMPLIANCE RISK: Agent bus message in ${appId} contains data from ${siblingAppId}. Transaction halted.`,
            createdAt: new Date().toISOString(),
            correlation_id: data.correlation_id
        });
    }
});