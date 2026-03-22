import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../config";
import { AgentBusClient } from "../agentBusClient";

/**
 * 1. FLEET STATUS WORKER (Step 8.2: Live Dispatch Data Provider)
 * Aggregates active logistics jobs for the Command Center UI.
 * This worker acts as the "Data Streamer" for the Fleet Map.
 */
export const fleetStatusWorkerV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "DISPATCH_WORKER") return;

    const client = new AgentBusClient({ 
        agentId: "DISPATCH_WORKER", capabilities: ["fleet_monitoring", "dispatch_analytics"], 
        jurisdictions: ["AB"], substances: ["DATA"], role: "WORKER", domain: "OPS"
    });
    await client.register();

    try {
        const { intent, filterJurisdiction = "AB" } = data.payload.manifest;
        const { appId } = event.params;

        if (intent === "GET_FLEET_STATE") {
            // Query all jobs that are not yet finalized
            const activeJobsSnap = await db.collection(`artifacts/${appId}/public/data/logistics_jobs`)
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
    } catch (error: any) {
        return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, {
            code: "DISPATCH_ERROR", message: error.message
        });
    }
});