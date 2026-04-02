import { onDocumentCreated, onDocumentUpdated, onDocumentWritten } from "firebase-functions/v2/firestore";
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
 * 3. INTERVENTION TIMELINE WORKER
 */
export const interventionTimelineWorkerV2 = onDocumentCreated({
    document: "artifacts/{appId}/public/data/interventions/{interventionId}"
}, async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { appId, interventionId } = event.params;

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

        await db.collection(`artifacts/${appId}/public/data/evolution_timeline`).add(payload);
    } catch (error: any) {
        console.error(`[TIMELINE_ERROR] Failed during intervention log:`, error.message);
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
 * 5. EFFICACY AUDIT WORKER (Phase 31: Adaptive Thresholds)
 * Implements HBR-SAF-01 Efficacy Math.
 */
export const efficacyAuditWorkerV2 = onDocumentWritten({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    
    if (!data || data.status !== "dispatched") return;
    if (data.control?.type !== "RESPONSE") return;
    if (!data.telemetry?.completed_at || !data.telemetry?.processed_at) return;
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
    const latencyMs = end - start;

    try {
        // --- HBR-SAF-01: EFFICACY CALCULATION ---
        const BASELINE_MS = 5000;
        let perfScore = 1.0;
        if (latencyMs > BASELINE_MS) {
            perfScore = Math.max(0, 1 - (latencyMs - BASELINE_MS) / 15000);
        }

        // Aggregate Score (Simplified for initial rollout)
        // Future: Add Accuracy (A) and Compliance (C) checks
        const totalEfficacy = perfScore * 100;

        await db.collection(`artifacts/${appId}/public/data/efficacy_audit`).add({
            agentId,
            timestamp: new Date().toISOString(),
            latencyMs,
            performanceScore: perfScore,
            totalEfficacy,
            correlation_id: data.correlation_id
        });

        // Update Registry with latest health
        const registryRef = db.doc(`artifacts/${appId}/public/data/agent_registry/${agentId}`);
        await registryRef.update({
            "status.latency_ms": latencyMs,
            "status.current_efficacy": Number(totalEfficacy.toFixed(1)),
            "status.last_heartbeat": new Date().toISOString()
        });

        // --- PHASE 31: ADAPTIVE HEALING TRIGGER ---
        // Instead of hard 8s, we trigger if efficacy drops below 90% (Yellow Status)
        if (totalEfficacy < 90) {
            console.log(`[SELF-HEALING] Efficacy Drop (${totalEfficacy.toFixed(1)}%) for ${agentId}.`);
            
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