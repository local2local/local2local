"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.efficacyAuditWorkerV2 = exports.profitAnalysisWorkerV2 = exports.interventionTimelineWorkerV2 = exports.logisticsTimelineWorkerV2 = exports.evolutionTimelineWorkerV2 = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const config_1 = require("../config");
const agentBusClient_1 = require("../agentBusClient");
exports.evolutionTimelineWorkerV2 = (0, firestore_1.onDocumentCreated)({
    document: "artifacts/{appId}/public/data/shadow_runs/{runId}",
}, async (event) => {
    const runData = event.data?.data();
    if (!runData)
        return;
    const { appId } = event.params;
    try {
        return config_1.db.collection(`artifacts/${appId}/public/data/evolution_timeline`).add({
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
    }
    catch (error) {
        console.error(`[TIMELINE_ERROR] Shadow write failed:`, error);
    }
});
exports.logisticsTimelineWorkerV2 = (0, firestore_1.onDocumentUpdated)({
    document: "artifacts/{appId}/public/data/logistics_jobs/{jobId}"
}, async (event) => {
    const newData = event.data?.after.data();
    const oldData = event.data?.before.data();
    if (!newData || !oldData)
        return;
    const statusChanged = newData.status !== oldData.status;
    const sobrietyTriggered = newData.requiresSobrietyCheck && !oldData.requiresSobrietyCheck;
    if (!statusChanged && !sobrietyTriggered)
        return;
    const { appId, jobId } = event.params;
    try {
        return config_1.db.collection(`artifacts/${appId}/public/data/evolution_timeline`).add({
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
    }
    catch (error) {
        console.error(`[TIMELINE_ERROR] Logistics write failed:`, error);
    }
});
exports.interventionTimelineWorkerV2 = (0, firestore_1.onDocumentCreated)({
    document: "artifacts/{appId}/public/data/interventions/{interventionId}"
}, async (event) => {
    const data = event.data?.data();
    if (!data)
        return;
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
        await config_1.db.collection(`artifacts/${appId}/public/data/evolution_timeline`).add(payload);
    }
    catch (error) {
        console.error(`[TIMELINE_ERROR] Failed during intervention log:`, error.message);
    }
});
exports.profitAnalysisWorkerV2 = (0, firestore_1.onDocumentWritten)({
    document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
    memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    const prev = event.data?.before.data();
    if (!data || data.status !== "dispatched" || prev?.status === "dispatched")
        return;
    if (data.provenance?.receiver_id !== "ANALYTICS_WORKER" || data.control?.type !== "REQUEST")
        return;
    const client = new agentBusClient_1.AgentBusClient({
        agentId: "ANALYTICS_WORKER", capabilities: ["financial_reporting"],
        jurisdictions: ["AB"], substances: ["DATA"], role: "WORKER", domain: "FINANCE"
    }, event.params.appId);
    await client.register();
    try {
        const manifest = data.payload?.manifest;
        if (!manifest)
            throw new Error("MISSING_MANIFEST");
        const { intent } = manifest;
        if (intent === "GENERATE_PROFIT_REPORT") {
            const ordersSnap = await config_1.db.collection(`artifacts/${event.params.appId}/public/data/orders`).where("status", "==", "completed").get();
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
    }
    catch (error) {
        return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, {
            code: "ANALYTICS_ERROR",
            message: error.message
        });
    }
});
exports.efficacyAuditWorkerV2 = (0, firestore_1.onDocumentWritten)({
    document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
    memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    const prev = event.data?.before.data();
    if (!data || data.status !== "dispatched" || prev?.status === "dispatched")
        return;
    const type = data.control?.type;
    if (type !== "RESPONSE" && type !== "ERROR")
        return;
    if (!data.telemetry?.completed_at || !data.telemetry?.processed_at)
        return;
    if (data.correlation_id?.startsWith("healing-"))
        return;
    const { appId } = event.params;
    const agentId = data.provenance?.sender_id;
    if (!agentId || agentId === "ANALYTICS_WORKER")
        return;
    const getTime = (val) => {
        if (!val)
            return NaN;
        if (val.toDate && typeof val.toDate === 'function')
            return val.toDate().getTime();
        if (typeof val === 'string') {
            const dateStr = val.endsWith('Z') ? val : val + 'Z';
            return Date.parse(dateStr);
        }
        return NaN;
    };
    const end = getTime(data.telemetry?.completed_at);
    const start = getTime(data.telemetry?.processed_at);
    if (isNaN(start) || isNaN(end))
        return;
    const latencyMs = end - start;
    try {
        const BASELINE_MS = 5000;
        let perfScore = 1.0;
        if (latencyMs > BASELINE_MS)
            perfScore = Math.max(0, 1 - (latencyMs - BASELINE_MS) / 15000);
        let complianceScore = 1.0;
        const errorData = data.payload?.error;
        if (errorData) {
            const trace = (errorData.trace || "").toLowerCase();
            const msg = (errorData.message || "").toLowerCase();
            if (trace.length < 20)
                complianceScore = 0.5;
            if (msg.includes("unexpected") || msg.includes("unknown"))
                complianceScore = 0.2;
        }
        const totalEfficacy = ((complianceScore * 0.7) + (perfScore * 0.3)) * 100;
        await config_1.db.collection(`artifacts/${appId}/public/data/efficacy_audit`).add({
            agentId, timestamp: new Date().toISOString(), latencyMs, performanceScore: perfScore, complianceScore, totalEfficacy, correlation_id: data.correlation_id
        });
        const registryRef = config_1.db.doc(`artifacts/${appId}/public/data/agent_registry/${agentId}`);
        await registryRef.update({
            "status.latency_ms": latencyMs,
            "status.current_efficacy": Number(totalEfficacy.toFixed(1)),
            "status.last_heartbeat": new Date().toISOString()
        });
        if (totalEfficacy < 90) {
            console.log(`[SELF-HEALING_TRIGGER] Efficacy drop to ${totalEfficacy.toFixed(1)}% for ${agentId}.`);
            await config_1.db.collection(`artifacts/${appId}/public/data/agent_bus`).add({
                correlation_id: `healing-${data.correlation_id}`,
                status: "pending",
                control: { type: "REQUEST", priority: "normal" },
                provenance: { sender_id: "ANALYTICS_WORKER", receiver_id: "INFRASTRUCTURE_WORKER" },
                payload: { manifest: { intent: "FOLD_CONTEXT", correlationId: data.correlation_id, targetAgentId: agentId } }
            });
        }
    }
    catch (error) {
        console.error("[AUDIT_ERROR]", error.message);
    }
});
//# sourceMappingURL=analytics.js.map