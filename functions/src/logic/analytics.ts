import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../config";
import { AgentBusClient } from "../agentBusClient";

/**
 * 1. EVOLUTION TIMELINE WORKER
 */
export const evolutionTimelineWorkerV2 = onDocumentCreated({
  document: "artifacts/{appId}/public/data/shadow_runs/{runId}",
}, async (event) => {
    const runData = event.data?.data();
    if (!runData) return;
    const { appId } = event.params;
    
    console.log(`[TIMELINE_PROBE] Shadow Run Triggered for ${appId}`);

    try {
        return db.collection(`artifacts/${appId}/public/data/evolution_timeline`).add({
            type: runData.status === "validated" ? "LOGIC_VALIDATION_SUCCESS" : "LOGIC_VALIDATION_FAILURE",
            agentId: runData.agentId,
            correlationId: runData.correlation_id,
            timestamp: runData.timestamp || new Date().toISOString(),
            details: runData.status === "validated" 
                ? `Agent ${runData.agentId} passed integrity checks.` 
                : `Critical mismatch detected in ${runData.agentId} reasoning.`,
            isAutonomous: true,
            source: "evolution_engine"
        });
    } catch (error) {
        console.error(`[TIMELINE_ERROR] Shadow write failed:`, error);
    }
});

/**
 * 2. LOGISTICS TIMELINE WORKER
 */
export const logisticsTimelineWorkerV2 = onDocumentUpdated({
    document: "artifacts/{appId}/public/data/logistics_jobs/{jobId}"
}, async (event) => {
    const newData = event.data?.after.data();
    const oldData = event.data?.before.data();
    if (!newData || !oldData) return;

    const statusChanged = newData.status !== oldData.status;
    const sobrietyTriggered = newData.requiresSobrietyCheck && !oldData.requiresSobrietyCheck;

    if (!statusChanged && !sobrietyTriggered) return;
    const { appId, jobId } = event.params;

    console.log(`[TIMELINE_PROBE] Logistics Milestone Triggered for ${appId}`);

    try {
        return db.collection(`artifacts/${appId}/public/data/evolution_timeline`).add({
            type: sobrietyTriggered ? "REGULATORY_CHECK_ENABLED" : "LOGISTICS_MILESTONE",
            jobId: jobId,
            orderId: newData.orderId,
            timestamp: new Date().toISOString(),
            details: sobrietyTriggered 
                ? `Safety Protocol: Sobriety check enabled for Order ${newData.orderId}.`
                : `Logistics Job ${jobId} transitioned to ${newData.status}.`,
            isAutonomous: false,
            source: "logistics_orchestrator"
        });
    } catch (error) {
        console.error(`[TIMELINE_ERROR] Logistics write failed:`, error);
    }
});

/**
 * 3. INTERVENTION TIMELINE WORKER (Step 16.3: Hardening)
 * Hardened: uses try/catch with explicit collection references to avoid Eventarc silent drops.
 */
export const interventionTimelineWorkerV2 = onDocumentCreated({
    document: "artifacts/{appId}/public/data/interventions/{interventionId}"
}, async (event) => {
    const data = event.data?.data();
    if (!data) {
        console.log("[TIMELINE_CRITICAL] No data in event snapshot.");
        return;
    }

    const { appId, interventionId } = event.params;
    console.log(`[TIMELINE_PROBE] Intercepted Intervention in ${appId}: ${interventionId}`);

    try {
        const payload = {
            type: "CRITICAL_INTERVENTION_REQUIRED",
            interventionId: interventionId,
            timestamp: data.createdAt || new Date().toISOString(),
            details: data.details || "No details provided.",
            severity: data.severity || "high",
            isAutonomous: false,
            source: "safety_worker",
            correlation_id: data.correlation_id || "N/A"
        };

        // Explicitly write to the timeline of the same appId
        await db.collection(`artifacts/${appId}/public/data/evolution_timeline`).add(payload);
        console.log(`[TIMELINE_SUCCESS] Written to artifacts/${appId}/public/data/evolution_timeline`);

    } catch (error: any) {
        console.error(`[TIMELINE_ERROR] Failed during intervention log in ${appId}:`, error.message);
    }
});

/**
 * 4. PROFIT ANALYSIS WORKER
 */
export const profitAnalysisWorkerV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "ANALYTICS_WORKER") return;
    const client = new AgentBusClient({ agentId: "ANALYTICS_WORKER", capabilities: ["financial_reporting"], jurisdictions: ["AB"], substances: ["DATA"], role: "WORKER", domain: "FINANCE" }, event.params.appId);
    await client.register();
    try {
        const { intent } = data.payload.manifest;
        if (intent === "GENERATE_PROFIT_REPORT") {
            const ordersSnap = await db.collection(`artifacts/${event.params.appId}/public/data/orders`).where("status", "==", "completed").get();
            let totalGMVCents = 0;
            ordersSnap.docs.forEach(doc => { totalGMVCents += (doc.data().totalCents || 0); });
            return client.sendResponse(data.correlation_id, data.provenance.sender_id, { 
                reportType: "PROFIT_SUMMARY", 
                orderCount: ordersSnap.docs.length, 
                totalGMV: (totalGMVCents / 100).toFixed(2), 
                totalPlatformRevenue: ((totalGMVCents * 0.10) / 100).toFixed(2), 
                currency: "CAD", 
                timestamp: new Date().toISOString() 
            });
        }
    } catch (error: any) { return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, { code: "ANALYTICS_ERROR", message: error.message }); }
});

/**
 * 5. EFFICACY AUDIT WORKER
 */
export const efficacyAuditWorkerV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.control?.type !== "RESPONSE") return;

    const { appId } = event.params;
    const agentId = data.provenance.sender_id;

    try {
        const auditRef = db.collection(`artifacts/${appId}/public/data/efficacy_audit`).doc();
        await auditRef.set({
            agentId,
            timestamp: new Date().toISOString(),
            latencyMs: new Date(data.telemetry.completed_at).getTime() - new Date(data.telemetry.processed_at).getTime(),
            status: "success",
            correlation_id: data.correlation_id
        });
    } catch (error) {
        console.error("Audit Logging Error:", error);
    }
});