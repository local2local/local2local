import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { db } from "../config";
import { AgentBusClient } from "../agentBusClient";
const Stripe = require("stripe");

/**
 * 1. ORDER ORCHESTRATOR WORKER (Phase 13: Moonlitely Handshake)
 * Hardened: Now correctly passes tenant appId to the AgentBusClient.
 */
export const orderOrchestratorV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "ORDER_ORCHESTRATOR") return;

    const { appId } = event.params;
    const client = new AgentBusClient({ 
        agentId: "ORDER_ORCHESTRATOR", capabilities: ["order_management", "moonlitely_orchestration"], 
        jurisdictions: ["AB"], substances: ["DATA"], role: "ORCHESTRATOR", domain: "OPS"
    }, appId); // Pass appId to constructor
    
    await client.register();

    try {
        const { intent, orderId, sellerId, buyerId, paymentIntentId, requirements = [] } = data.payload.manifest;

        if (intent === "BOOK_TALENT") {
            const busRef = db.collection(`artifacts/${appId}/public/data/agent_bus`);
            await busRef.add({
                correlation_id: data.correlation_id, status: "pending", control: { type: "REQUEST" },
                provenance: { sender_id: "ORDER_ORCHESTRATOR", receiver_id: "FACILITY_MATCHING_WORKER" },
                payload: { manifest: { venueId: buyerId, talentId: sellerId, requirements } }
            });
            return client.sendResponse(data.correlation_id, data.provenance.sender_id, { status: "audit_initiated" });
        }

        if (intent === "START_PERFORMANCE") {
            const orderRef = db.doc(`artifacts/${appId}/public/data/orders/${orderId}`);
            const orderSnap = await orderRef.get();
            const orderData = orderSnap.data();

            if (orderData?.status !== "accepted" && orderData?.fulfillmentStatus !== "arrived") {
                throw new Error("CANNOT_START: Artist not yet verified as arrived via GPS.");
            }

            await orderRef.update({
                performanceStatus: "live",
                performanceStartedAt: new Date().toISOString(),
                "telemetry.start_verified": true
            });

            return client.sendResponse(data.correlation_id, data.provenance.sender_id, { 
                status: "performance_live", 
                message: "Performance clock started. Good luck!" 
            });
        }

        if (intent === "END_PERFORMANCE") {
            const orderRef = db.doc(`artifacts/${appId}/public/data/orders/${orderId}`);
            const orderSnap = await orderRef.get();
            const orderData = orderSnap.data();

            if (orderData?.performanceStatus !== "live") throw new Error("PERFORMANCE_NOT_LIVE");

            const endTime = new Date();
            const startTime = new Date(orderData.performanceStartedAt);
            const durationMinutes = Math.floor((endTime.getTime() - startTime.getTime()) / 60000);

            await orderRef.update({
                performanceStatus: "ended",
                performanceEndedAt: endTime.toISOString(),
                actualDurationMinutes: durationMinutes
            });

            // DISPATCH TO FULFILLMENT: Target the correct namespace bus
            const busRef = db.collection(`artifacts/${appId}/public/data/agent_bus`);
            await busRef.add({
                correlation_id: `payout-${data.correlation_id}`,
                status: "pending",
                control: { type: "REQUEST" },
                provenance: { sender_id: "ORDER_ORCHESTRATOR", receiver_id: "FULFILLMENT_WORKER" },
                payload: {
                    manifest: {
                        intent: "CONFIRM_DELIVERY",
                        orderId: orderId
                    }
                }
            });

            return client.sendResponse(data.correlation_id, data.provenance.sender_id, { 
                status: "verification_complete", 
                durationMinutes,
                message: "Performance verified. Payout sequence initiated." 
            });
        }

        if (intent === "ACCEPT_ORDER") {
            const orderRef = db.doc(`artifacts/${appId}/public/data/orders/${orderId}`);
            const orderData = (await orderRef.get()).data();
            await orderRef.update({ status: "accepted", "telemetry.accepted_at": new Date().toISOString(), paymentIntentId: paymentIntentId || orderData?.paymentIntentId || null });
            
            const busRef = db.collection(`artifacts/${appId}/public/data/agent_bus`);
            await busRef.add({ correlation_id: data.correlation_id, status: "pending", control: { type: "REQUEST" }, provenance: { sender_id: "ORDER_ORCHESTRATOR", receiver_id: "XERO_SYNC_WORKER" }, payload: { manifest: { orderId, buyerId, sellerId, totalCents: orderData?.totalCents, lineItems: orderData?.lineItems || [] } } });
            
            if (orderData?.type !== "moonlitely") {
                await busRef.add({ correlation_id: data.correlation_id, status: "pending", control: { type: "REQUEST" }, provenance: { sender_id: "ORDER_ORCHESTRATOR", receiver_id: "LOGISTICS_ORCHESTRATOR" }, payload: { manifest: { orderId, mode: "3PL" } } });
            }
            return client.sendResponse(data.correlation_id, data.provenance.sender_id, { status: "accepted" });
        }
        throw new Error("UNSUPPORTED_INTENT");
    } catch (e: any) { return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, { code: "ORCHESTRATION_ERROR", message: e.message }); }
});

/**
 * 2. UNIFIED ACTIVITY WORKER
 */
export const unifiedActivityWorkerV2 = onDocumentUpdated({
    document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
    memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "UNIFIED_ACTIVITY_WORKER") return;
    
    const { appId } = event.params;
    const client = new AgentBusClient({ agentId: "UNIFIED_ACTIVITY_WORKER", capabilities: ["multi_app_query"], jurisdictions: ["AB"], substances: ["DATA"], role: "WORKER", domain: "OPS" }, appId);
    
    await client.register();
    try {
        const { userId } = data.payload.manifest;
        const siblingAppId = appId.includes("kaskflow") ? appId.replace("kaskflow", "moonlitely") : appId.replace("moonlitely", "kaskflow");
        const currentOrdersSnap = await db.collection(`artifacts/${appId}/public/data/orders`).where("buyerId", "==", userId).where("status", "in", ["pending", "accepted", "in_transit"]).get();
        const siblingBookingsSnap = await db.collection(`artifacts/${siblingAppId}/public/data/orders`).where("buyerId", "==", userId).where("status", "in", ["pending", "accepted"]).get();
        const activity: any[] = [
            ...currentOrdersSnap.docs.map(doc => ({ id: doc.id, ...doc.data(), source: appId })),
            ...siblingBookingsSnap.docs.map(doc => ({ id: doc.id, ...doc.data(), source: siblingAppId }))
        ];
        activity.sort((a, b) => new Date(b.createdAt || 0).getTime() - new Date(a.createdAt || 0).getTime());
        return client.sendResponse(data.correlation_id, data.provenance.sender_id, { userId, activeItemsCount: activity.length, timeline: activity });
    } catch (error: any) { return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, { code: "AGGREGATION_ERROR", message: error.message }); }
});

/**
 * 3. EVENT ESCROW WORKER
 */
export const eventEscrowWorkerV2 = onSchedule("every 1 hours", async () => {
    const appId = "local2local-kaskflow";
    const now = new Date();
    const gracePeriodEnd = new Date(now.getTime() - (24 * 60 * 60 * 1000));
    const eventsSnap = await db.collection(`artifacts/${appId}/public/data/orders`).where("type", "==", "moonlitely").where("status", "==", "accepted").get();
    const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
    for (const doc of eventsSnap.docs) {
        const orderData = doc.data();
        if (new Date(orderData.eventTimestamp) < gracePeriodEnd && orderData.paymentIntentId) {
            try {
                if (!orderData.paymentIntentId.includes("mock")) await stripe.paymentIntents.capture(orderData.paymentIntentId);
                await doc.ref.update({ status: "completed", fulfillmentStatus: "event_finalized" });
                await db.collection(`artifacts/${appId}/public/data/agent_bus`).add({ correlation_id: `escrow-release-${doc.id}`, status: "pending", control: { type: "REQUEST" }, provenance: { sender_id: "EVENT_ESCROW_WORKER", receiver_id: "XERO_SYNC_WORKER" }, payload: { manifest: { intent: "AUTHORIZE_INVOICE", orderId: doc.id } } });
            } catch (e: any) { console.error(`Escrow Error: ${e.message}`); }
        }
    }
});