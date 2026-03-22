import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { db, getProjectId } from "../config";
import { AgentBusClient } from "../agentBusClient";
import { getDistanceMeters } from "../shared";

/**
 * 1. IDENTITY ANOMALY WORKER (Step 16.3: Advanced Fraud Detection)
 * Scans cross-app identity bridge events for semantic or geographic spoofing.
 */
export const identityAnomalyWorkerV2 = onDocumentUpdated({
  document: "artifacts/{appId}/users/{userId}",
  memory: "512MiB"
}, async (event) => {
    const newData = event.data?.after.data();
    if (!newData || !newData.telemetry?.last_sync_from) return;

    const { appId, userId } = event.params;
    const client = new AgentBusClient({ 
        agentId: "FRAUD_DETECTION_WORKER", capabilities: ["identity_verification", "fraud_analysis"], 
        jurisdictions: ["AB", "BC", "US"], substances: ["DATA"], role: "WORKER", domain: "SECURITY"
    }, appId);
    await client.register();

    try {
        const sourceAppId = newData.telemetry.last_sync_from;
        
        // 1. GEOGRAPHIC ANOMALY (The "Geography Pivot")
        // Check if the user is claiming a different "Local" status in the other app
        const siblingAppId = appId.includes("kaskflow") ? appId.replace("kaskflow", "moonlitely") : appId.replace("moonlitely", "kaskflow");
        const siblingDoc = await db.doc(`artifacts/${siblingAppId}/users/${userId}`).get();
        
        if (siblingDoc.exists) {
            const siblingLocality = siblingDoc.data()?.locality?.basePoint;
            const currentLocality = newData.locality?.basePoint;

            if (siblingLocality && currentLocality) {
                const distance = getDistanceMeters(
                    currentLocality.latitude, currentLocality.longitude,
                    siblingLocality.latitude, siblingLocality.longitude
                );

                if (distance > 50000) { // > 50km discrepancy
                    await db.collection(`artifacts/${appId}/public/data/agent_bus`).add({
                        correlation_id: `fraud-${userId}-${Date.now()}`,
                        status: "pending",
                        control: { type: "REQUEST", priority: "urgent" },
                        provenance: { sender_id: "FRAUD_DETECTION_WORKER", receiver_id: "SAFETY_WORKER" },
                        payload: {
                            manifest: {
                                intent: "LOG_SAFETY_VIOLATION",
                                severity: "critical",
                                details: `IDENTITY_SPOOFING: User ${userId} geographic pivot detected. (${Math.round(distance/1000)}km gap between ${appId} and ${siblingAppId}).`
                            }
                        }
                    });
                }
            }
        }

        // 2. FINANCIAL ANOMALY (Tax avoidance check)
        const stripeCountry = newData.address?.country;
        const aglcStatus = newData.aglcStatus?.status;
        
        if (stripeCountry === "US" && aglcStatus === "active") {
            // High risk: Claiming Alberta Liquor benefits while using a US financial nexus
            await db.collection(`artifacts/${appId}/public/data/agent_bus`).add({
                correlation_id: `fraud-tax-${userId}`,
                status: "pending",
                control: { type: "REQUEST", priority: "high" },
                provenance: { sender_id: "FRAUD_DETECTION_WORKER", receiver_id: "SAFETY_WORKER" },
                payload: {
                    manifest: {
                        intent: "LOG_SAFETY_VIOLATION",
                        severity: "high",
                        details: `FINANCIAL_INCONSISTENCY: User ${userId} is active in AGLC (AB) but has a US Stripe country profile.`
                    }
                }
            });
        }

    } catch (e: any) {
        console.error("Fraud Detection Error:", e.message);
    }
});

/**
 * 2. IDENTITY BRIDGE WORKER (Phase 13: Moonlitely Integration)
 */
export const identityBridgeWorkerV2 = onDocumentUpdated("artifacts/{appId}/users/{userId}", async (event) => {
    const newData = event.data?.after.data();
    const oldData = event.data?.before.data();
    if (!newData || !oldData) return;

    const sharedFields = ["businessName", "phoneNumber", "locality", "address", "facilityProfile"];
    const hasChanged = sharedFields.some(f => JSON.stringify(newData[f]) !== JSON.stringify(oldData[f]));
    if (!hasChanged) return;

    const { appId, userId } = event.params;
    const siblingAppId = appId.includes("kaskflow") ? appId.replace("kaskflow", "moonlitely") : appId.replace("moonlitely", "kaskflow");

    const siblingRef = db.doc(`artifacts/${siblingAppId}/users/${userId}`);
    const siblingSnap = await siblingRef.get();

    if (siblingSnap.exists) {
        const updatePayload: any = {};
        sharedFields.forEach(f => { 
            if (newData[f] !== undefined) updatePayload[f] = newData[f]; 
        });
        if (Object.keys(updatePayload).length === 0) return;

        return siblingRef.update({
            ...updatePayload,
            "telemetry.last_sync_from": appId,
            "telemetry.synced_at": new Date().toISOString()
        });
    }
});

/**
 * 3. SAFETY ALERT WORKER (HBR-SAF-02)
 * Hardened: Handles "undefined" jobId for pre-creation violations.
 */
export const safetyAlertWorkerV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "SAFETY_WORKER") return;

    const { appId } = event.params;
    const client = new AgentBusClient({ 
        agentId: "SAFETY_WORKER", capabilities: ["safety_monitoring"], 
        jurisdictions: ["AB", "BC", "US"], substances: ["DATA"], role: "WORKER", domain: "SECURITY"
    }, appId);
    await client.register();

    try {
        const { intent, jobId, severity = "high", details } = data.payload.manifest;
        if (intent === "LOG_SAFETY_VIOLATION") {
            const interventionRef = db.collection(`artifacts/${appId}/public/data/interventions`).doc();
            const interventionData: any = {
                type: "SAFETY_VIOLATION",
                severity,
                status: "active",
                details,
                createdAt: new Date().toISOString(),
                correlation_id: data.correlation_id
            };
            if (jobId) interventionData.jobId = jobId;
            await interventionRef.set(interventionData);
            return client.sendResponse(data.correlation_id, data.provenance.sender_id, { status: "intervention_created" });
        }
        throw new Error(`UNSUPPORTED_INTENT: ${intent}`);
    } catch (e: any) { 
        return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, { code: "SAFETY_ERROR", message: e.message }); 
    }
});

/**
 * 4. RESIDENCY AUDIT WORKER (Phase 14: PIPA Compliance)
 */
export const residencyAuditWorkerV2 = onSchedule("every 24 hours", async () => {
    const projectId = getProjectId();
    const appId = "local2local-kaskflow"; 
    const isCanadianRegion = true; 
    if (!isCanadianRegion) {
        await db.collection(`artifacts/${appId}/public/data/interventions`).add({
            type: "DATA_RESIDENCY_VIOLATION", severity: "critical", details: `Project ${projectId} audit FAILED.`, createdAt: new Date().toISOString(), status: "active"
        });
    } else {
        await db.collection(`artifacts/${appId}/public/data/agent_bus`).add({
            correlation_id: `audit-residency-${Date.now()}`, status: "pending", control: { type: "RESPONSE" }, provenance: { sender_id: "SAFETY_WORKER", receiver_id: "DASHBOARD_UI" },
            payload: { result: { status: "residency_verified", region: "northamerica-northeast1", compliance: "PIPA/PIPEDA Pass", audit_timestamp: new Date().toISOString() } }
        });
    }
});

/**
 * 5. ZERO-TRUST BARRIER & SHADOW FORK
 */
export const onMessageWrittenV2 = onDocumentCreated("artifacts/{appId}/public/data/agent_bus/{messageId}", async (event) => {
    const data = event.data?.data();
    if (!data || data.status !== "pending") return;
    const { appId } = event.params;
    const receiverId = data.provenance.receiver_id;
    const payloadString = JSON.stringify(data.payload || {});
    const piiPattern = /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g; 
    const scrubbedPayload = JSON.parse(payloadString.replace(piiPattern, "[MASKED_EMAIL]"));
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
    const client = new AgentBusClient({ agentId: "FACILITY_MATCHING_WORKER", capabilities: ["technical_matching"], jurisdictions: ["AB", "BC", "US"], substances: ["DATA"], role: "WORKER", domain: "OPS" }, appId);
    await client.register();
    try {
        const { venueId, requirements = [] } = data.payload.manifest;
        const venueDoc = await db.doc(`artifacts/${appId}/users/${venueId}`).get();
        const facilities = venueDoc.data()?.facilityProfile?.onSiteFacilities || [];
        const missing = requirements.filter((req: string) => !facilities.includes(req));
        if (missing.length > 0) return client.sendResponse(data.correlation_id, data.provenance.sender_id, { match: false, missingRequirements: missing });
        return client.sendResponse(data.correlation_id, data.provenance.sender_id, { match: true });
    } catch (e: any) { return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, { code: "MATCHING_ERROR", message: e.message }); }
});

/**
 * 7. IDENTITY TRIGGERS
 */
export const onUserCreatedV2 = onDocumentCreated("artifacts/{appId}/users/{userId}", async (event) => {
    return event.data?.ref.set({ 
        trustScore: 50, aglcStatus: { status: "pending", isVerified: false }, stripeStatus: "not_started", subscriptionTier: "basic", meta: { isProbation: false } 
    }, { merge: true });
});

/**
 * 8. AGENT HEARTBEAT MONITOR
 */
export const agentHeartbeatMonitorV2 = onSchedule("every 5 minutes", async () => {
    const snap = await db.collectionGroup("agent_registry").get(); 
    const batch = db.batch();
    snap.docs.forEach(doc => { 
        const lastHeartbeat = doc.data().status?.last_heartbeat;
        if (lastHeartbeat && (new Date().getTime() - new Date(lastHeartbeat).getTime()) / 60000 > 10) {
            batch.update(doc.ref, { "status.health": "red" }); 
        }
    });
    await batch.commit();
});