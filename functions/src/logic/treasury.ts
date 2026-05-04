import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";
import { db } from "../config";
import { AgentBusClient } from "../agentBusClient";

/**
 * 1. TREASURY WORKER (Phase 11: Financial Operations)
 * Manages the final release of funds and ledger reconciliation.
 * Implements "Management by Exception" for high-value payouts and auto-ledgering.
 */
export const treasuryWorkerV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "TREASURY_WORKER") return;

    const client = new AgentBusClient({
        agentId: "TREASURY_WORKER", capabilities: ["treasury_management", "payout_authorization", "reconciliation"],
        jurisdictions: ["AB"], substances: ["FINANCE"], role: "WORKER", domain: "FINANCE"
    });
    await client.register();

    try {
        const { intent, orderId, amountCents, stripeTransferId } = data.payload.manifest;
        const { appId } = event.params;

        // --- STEP 11.1: PAYOUT AUTHORIZATION ---
        if (intent === "INITIATE_PAYOUT") {
            const PAYOUT_THRESHOLD_CENTS = 100000; // $1,000.00 CAD

            if (amountCents >= PAYOUT_THRESHOLD_CENTS) {
                const interventionRef = db.collection(`artifacts/${appId}/public/data/interventions`).doc();
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

            const now = admin.firestore.FieldValue.serverTimestamp();
            const busRef = db.collection(`artifacts/${appId}/public/data/agent_bus`);
            await busRef.add({
                correlation_id: data.correlation_id,
                status: "pending",
                control: { type: "REQUEST", priority: "normal" },
                provenance: { sender_id: "TREASURY_WORKER", receiver_id: "STRIPE_PROVISIONER_WORKER" },
                payload: { manifest: { intent: "CAPTURE_FUNDS", orderId } },
                created_at: now,
                last_updated: now,
                telemetry: { processed_at: now },
            });

            return client.sendResponse(data.correlation_id, data.provenance.sender_id, {
                status: "payout_initiated",
                message: "Autonomous payout threshold met. Processing capture."
            });
        }

        // --- STEP 11.2: AUTONOMOUS RECONCILIATION ---
        if (intent === "RECONCILE_LEDGER") {
            const orderRef = db.doc(`artifacts/${appId}/public/data/orders/${orderId}`);
            const orderSnap = await orderRef.get();
            if (!orderSnap.exists) throw new Error("ORDER_NOT_FOUND");

            await orderRef.update({
                reconciliationStatus: "pending_ledger_sync",
                "telemetry.stripe_transfer_id": stripeTransferId
            });

            const now = admin.firestore.FieldValue.serverTimestamp();
            const busRef = db.collection(`artifacts/${appId}/public/data/agent_bus`);
            await busRef.add({
                correlation_id: `reconcile-${data.correlation_id}`,
                status: "pending",
                control: { type: "REQUEST", priority: "normal" },
                provenance: { sender_id: "TREASURY_WORKER", receiver_id: "XERO_SYNC_WORKER" },
                payload: { manifest: { intent: "AUTHORIZE_INVOICE", orderId, paymentReference: stripeTransferId } },
                created_at: now,
                last_updated: now,
                telemetry: { processed_at: now },
            });

            return client.sendResponse(data.correlation_id, data.provenance.sender_id, {
                status: "reconciliation_dispatched",
                message: "Stripe transfer reference linked. Xero ledger sync initiated."
            });
        }

        throw new Error(`UNSUPPORTED_INTENT: ${intent}`);
    } catch (error: any) {
        return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, {
            code: "TREASURY_ERROR", message: error.message
        });
    }
});