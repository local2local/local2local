import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../config";
import { AgentBusClient } from "../agentBusClient";
import { getDistanceMeters } from "../shared";
const Stripe = require("stripe");

/**
 * 1. CUSTOMS INVOICE WORKER (Step 16.2: Automated Documentation)
 * Generates the data structure for commercial invoices for cross-border equipment.
 * Triggered when a logistics job is flagged as requiresCustomsDocs.
 */
export const customsInvoiceWorkerV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/logistics_jobs/{jobId}",
  memory: "512MiB"
}, async (event) => {
    const jobData = event.data?.after.data();
    if (!jobData || !jobData.requiresCustomsDocs || jobData.customsStatus === "ready") return;

    const { appId, jobId } = event.params;
    const client = new AgentBusClient({ 
        agentId: "CUSTOMS_WORKER", capabilities: ["customs_documentation", "logistics_compliance"], 
        jurisdictions: ["AB", "BC", "US"], substances: ["DATA"], role: "WORKER", domain: "OPS" 
    }, appId);
    await client.register();

    try {
        const orderSnap = await db.doc(`artifacts/${appId}/public/data/orders/${jobData.orderId}`).get();
        const orderData = orderSnap.data();

        const commercialInvoice = {
            invoiceNumber: `CI-${jobData.orderId}`,
            date: new Date().toISOString(),
            exporter: jobData.route.origin,
            importer: jobData.route.destination,
            items: (orderData?.lineItems || []).map((item: any) => ({
                description: item.name,
                quantity: item.quantity,
                unitValue: (item.priceCents / 100).toFixed(2),
                currency: orderData?.targetCurrency || "CAD",
                hsCode: item.hsCode || "8543.70",
                countryOfOrigin: "CA"
            })),
            totalValue: (orderData?.totalCents / 100).toFixed(2)
        };

        await db.doc(`artifacts/${appId}/public/data/logistics_jobs/${jobId}`).update({
            customsInvoice: commercialInvoice,
            customsStatus: "ready",
            "telemetry.customs_verified_at": new Date().toISOString()
        });

        return client.sendResponse(`customs-${jobId}`, "LOGISTICS_ORCHESTRATOR", { 
            status: "documents_prepared",
            invoiceId: commercialInvoice.invoiceNumber
        });
    } catch (e: any) { 
        return client.sendResponse(`customs-error-${jobId}`, "LOGISTICS_ORCHESTRATOR", null, { code: "CUSTOMS_ERROR", message: e.message }); 
    }
});

/**
 * 2. LOGISTICS ORCHESTRATOR
 * Detects cross-border routes and enforces the regulatory block on international alcohol.
 */
export const logisticsOrchestratorV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "LOGISTICS_ORCHESTRATOR") return;

    const { appId } = event.params;
    const client = new AgentBusClient({ 
        agentId: "LOGISTICS_ORCHESTRATOR", capabilities: ["logistics_management"], 
        jurisdictions: ["AB", "BC", "US"], substances: ["DATA"], role: "WORKER", domain: "OPS" 
    }, appId);
    await client.register();

    try {
        const { orderId, buyerId, sellerId, isAlcohol = false } = data.payload.manifest;
        const buyerDoc = await db.doc(`artifacts/${appId}/users/${buyerId}`).get();
        const sellerDoc = await db.doc(`artifacts/${appId}/users/${sellerId}`).get();
        const buyerCountry = buyerDoc.data()?.address?.country || "CA";
        const sellerCountry = sellerDoc.data()?.address?.country || "CA";
        const isCrossBorder = buyerCountry !== sellerCountry;

        if (isCrossBorder && isAlcohol) {
            await db.collection(`artifacts/${appId}/public/data/agent_bus`).add({
                correlation_id: data.correlation_id, status: "pending", control: { type: "REQUEST", priority: "urgent" },
                provenance: { sender_id: "LOGISTICS_ORCHESTRATOR", receiver_id: "SAFETY_WORKER" },
                payload: { manifest: { intent: "LOG_SAFETY_VIOLATION", severity: "critical", details: `ILLEGAL SHIPMENT: International liquor for Order ${orderId}.` } }
            });
            throw new Error("REGULATORY_HALT: International liquor transport is prohibited.");
        }

        const jobRef = db.collection(`artifacts/${appId}/public/data/logistics_jobs`).doc();
        await jobRef.set({
            orderId, status: "open_for_bidding", createdAt: new Date().toISOString(),
            isCrossBorder, requiresCustomsDocs: isCrossBorder,
            route: { origin: sellerId, destination: buyerId, crossBorder: isCrossBorder },
            meta: { buyerCountry, sellerCountry }
        });

        return client.sendResponse(data.correlation_id, data.provenance.sender_id, { 
            jobId: jobRef.id, isCrossBorder, requiresCustomsDocs: isCrossBorder,
            message: isCrossBorder ? "International logistics job initialized. Customs required." : "Domestic logistics initialized."
        });
    } catch (e: any) { return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, { code: "LOGISTICS_ERROR", message: e.message }); }
});

/**
 * 3. GPS TELEMETRY WORKER
 */
export const gpsTelemetryWorkerV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "TELEMETRY_WORKER") return;
    const { appId } = event.params;
    const client = new AgentBusClient({ agentId: "TELEMETRY_WORKER", capabilities: ["gps_tracking"], jurisdictions: ["AB", "BC", "US"], substances: ["DATA"], role: "WORKER", domain: "OPS" }, appId);
    await client.register();
    try {
        const { intent, jobId, lat, lng } = data.payload.manifest;
        if (intent === "UPDATE_LOCATION") {
            const jobRef = db.doc(`artifacts/${appId}/public/data/logistics_jobs/${jobId}`);
            const jobSnap = await jobRef.get();
            const jobData = jobSnap.data();
            if (!jobData || jobData.status === "completed") return client.sendResponse(data.correlation_id, data.provenance.sender_id, { status: "ignored" });
            const destUserDoc = await db.doc(`artifacts/${appId}/users/${jobData.route.destination}`).get();
            const destPoint = destUserDoc.data()?.locality?.basePoint;
            if (destPoint) {
                const distance = getDistanceMeters(lat, lng, destPoint.latitude, destPoint.longitude);
                await jobRef.update({ currentLocation: { lat, lng, updatedAt: new Date().toISOString(), distanceToDestinationMeters: Math.round(distance) } });
                if (distance < 200 && jobData.status !== "arrived") {
                    await jobRef.update({ status: "arrived", arrivedAt: new Date().toISOString() });
                    return client.sendResponse(data.correlation_id, data.provenance.sender_id, { status: "arrived" });
                }
            }
            return client.sendResponse(data.correlation_id, data.provenance.sender_id, { status: jobData.status });
        }
        throw new Error("UNSUPPORTED_INTENT");
    } catch (e: any) { return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, { code: "TELEMETRY_ERROR", message: e.message }); }
});

/**
 * 4. CARRIER BOARD WORKER
 */
export const carrierBoardWorkerV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "CARRIER_BOARD_WORKER") return;
    const { appId } = event.params;
    const client = new AgentBusClient({ agentId: "CARRIER_BOARD_WORKER", capabilities: ["carrier_bidding"], jurisdictions: ["AB", "BC", "US"], substances: ["DATA"], role: "WORKER", domain: "OPS" }, appId);
    await client.register();
    try {
        const { intent, carrierId, jobId } = data.payload.manifest;
        if (intent === "AWARD_BID") {
            await db.doc(`artifacts/${appId}/public/data/logistics_jobs/${jobId}`).update({ status: "awarded", awardedCarrierId: carrierId, awardedAt: new Date().toISOString() });
            return client.sendResponse(data.correlation_id, data.provenance.sender_id, { status: "awarded" });
        }
        return client.sendResponse(data.correlation_id, data.provenance.sender_id, { status: "ok" });
    } catch (e: any) { return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, { code: "CARRIER_ERROR", message: e.message }); }
});

/**
 * 5. FULFILLMENT COMPLETION WORKER
 */
export const fulfillmentCompletionWorkerV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB",
  secrets: ["STRIPE_SECRET_KEY"]
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "FULFILLMENT_WORKER") return;
    const { appId } = event.params;
    const client = new AgentBusClient({ agentId: "FULFILLMENT_WORKER", capabilities: ["payment_capture"], jurisdictions: ["AB", "BC", "US"], substances: ["DATA"], role: "WORKER", domain: "OPS" }, appId);
    await client.register();
    try {
        const { orderId, jobId } = data.payload.manifest;
        const orderRef = db.doc(`artifacts/${appId}/public/data/orders/${orderId}`);
        const orderSnap = await orderRef.get();
        const orderData = orderSnap.data();
        if (orderData?.paymentIntentId && !orderData.paymentIntentId.includes("mock")) {
            const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
            await stripe.paymentIntents.capture(orderData.paymentIntentId);
        }
        await orderRef.update({ status: "completed", fulfillmentStatus: "delivered" });
        if (jobId) await db.doc(`artifacts/${appId}/public/data/logistics_jobs/${jobId}`).update({ status: "completed", completedAt: new Date().toISOString() });
        await db.collection(`artifacts/${appId}/public/data/agent_bus`).add({ correlation_id: data.correlation_id, status: "pending", control: { type: "REQUEST" }, provenance: { sender_id: "FULFILLMENT_WORKER", receiver_id: "XERO_SYNC_WORKER" }, payload: { manifest: { intent: "AUTHORIZE_INVOICE", orderId } } });
        return client.sendResponse(data.correlation_id, data.provenance.sender_id, { status: "delivered", orderId });
    } catch (e: any) { return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, { code: "FULFILLMENT_ERROR", message: e.message }); }
});