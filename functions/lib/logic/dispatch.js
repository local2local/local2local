"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.fleetStatusWorkerV2 = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const config_1 = require("../config");
const agentBusClient_1 = require("../agentBusClient");
exports.fleetStatusWorkerV2 = (0, firestore_1.onDocumentUpdated)({
    document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
    memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "DISPATCH_WORKER")
        return;
    const client = new agentBusClient_1.AgentBusClient({
        agentId: "DISPATCH_WORKER", capabilities: ["fleet_monitoring", "dispatch_analytics"],
        jurisdictions: ["AB"], substances: ["DATA"], role: "WORKER", domain: "OPS"
    });
    await client.register();
    try {
        const { intent, filterJurisdiction = "AB" } = data.payload.manifest;
        const { appId } = event.params;
        if (intent === "GET_FLEET_STATE") {
            const activeJobsSnap = await config_1.db.collection(`artifacts/${appId}/public/data/logistics_jobs`)
                .where("status", "in", ["awarded", "bidding", "in_transit", "arrived"])
                .get();
            const fleet = activeJobsSnap.docs.map(doc => {
                const job = doc.data();
                return {
                    jobId: doc.id,
                    orderId: job.orderId,
                    status: job.status,
                    currentLocation: job.currentLocation || null,
                    carrierId: job.awardedCarrierId || "unassigned",
                    lastUpdate: job.currentLocation?.updatedAt || job.createdAt
                };
            });
            return client.sendResponse(data.correlation_id, data.provenance.sender_id, {
                activeJobCount: fleet.length,
                fleet: fleet,
                timestamp: new Date().toISOString()
            });
        }
        throw new Error(`UNSUPPORTED_INTENT: ${intent}`);
    }
    catch (error) {
        return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, {
            code: "DISPATCH_ERROR", message: error.message
        });
    }
});
//# sourceMappingURL=dispatch.js.map