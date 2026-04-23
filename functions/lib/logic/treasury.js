"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.treasuryWorkerV2 = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const config_1 = require("../config");
const agentBusClient_1 = require("../agentBusClient");
exports.treasuryWorkerV2 = (0, firestore_1.onDocumentUpdated)({
    document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
    memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "TREASURY_WORKER")
        return;
    const client = new agentBusClient_1.AgentBusClient({
        agentId: "TREASURY_WORKER", capabilities: ["treasury_management", "payout_authorization", "reconciliation"],
        jurisdictions: ["AB"], substances: ["FINANCE"], role: "WORKER", domain: "FINANCE"
    });
    await client.register();
    try {
        const { intent, orderId, amountCents, stripeTransferId } = data.payload.manifest;
        const { appId } = event.params;
        if (intent === "INITIATE_PAYOUT") {
            const PAYOUT_THRESHOLD_CENTS = 100000;
            if (amountCents >= PAYOUT_THRESHOLD_CENTS) {
                const interventionRef = config_1.db.collection(`artifacts/${appId}/public/data/interventions`).doc();
                await interventionRef.set({
                    type: "PAYOUT_APPROVAL_REQUIRED",
                    severity: "high",
                    orderId,
                    amountCents,
                    status: "active",
                    details: `High-value payout ($${(amountCents / 100).toFixed(2)}) requires human sign-off.`,
                    createdAt: new Date().toISOString()
                });
                return client.sendResponse(data.correlation_id, data.provenance.sender_id, {
                    status: "intervention_triggered",
                    message: "Payout exceeds autonomous limit. Escalating to Triage Hub for human approval."
                });
            }
            const busRef = config_1.db.collection(`artifacts/${appId}/public/data/agent_bus`);
            await busRef.add({
                correlation_id: data.correlation_id,
                status: "pending",
                control: { type: "REQUEST", priority: "normal" },
                provenance: { sender_id: "TREASURY_WORKER", receiver_id: "STRIPE_PROVISIONER_WORKER" },
                payload: {
                    manifest: {
                        intent: "CAPTURE_FUNDS",
                        orderId
                    }
                }
            });
            return client.sendResponse(data.correlation_id, data.provenance.sender_id, {
                status: "payout_initiated",
                message: "Autonomous payout threshold met. Processing capture."
            });
        }
        if (intent === "RECONCILE_LEDGER") {
            const orderRef = config_1.db.doc(`artifacts/${appId}/public/data/orders/${orderId}`);
            const orderSnap = await orderRef.get();
            if (!orderSnap.exists)
                throw new Error("ORDER_NOT_FOUND");
            await orderRef.update({
                reconciliationStatus: "pending_ledger_sync",
                "telemetry.stripe_transfer_id": stripeTransferId
            });
            const busRef = config_1.db.collection(`artifacts/${appId}/public/data/agent_bus`);
            await busRef.add({
                correlation_id: `reconcile-${data.correlation_id}`,
                status: "pending",
                control: { type: "REQUEST", priority: "normal" },
                provenance: { sender_id: "TREASURY_WORKER", receiver_id: "XERO_SYNC_WORKER" },
                payload: {
                    manifest: {
                        intent: "AUTHORIZE_INVOICE",
                        orderId,
                        paymentReference: stripeTransferId
                    }
                }
            });
            return client.sendResponse(data.correlation_id, data.provenance.sender_id, {
                status: "reconciliation_dispatched",
                message: "Stripe transfer reference linked. Xero ledger sync initiated."
            });
        }
        throw new Error(`UNSUPPORTED_INTENT: ${intent}`);
    }
    catch (error) {
        return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, {
            code: "TREASURY_ERROR", message: error.message
        });
    }
});
//# sourceMappingURL=treasury.js.map