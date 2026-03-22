import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../config";
import { AgentBusClient } from "../agentBusClient";

/**
 * 1. LEGAL GATE WORKER (Step 14.3: Major Legal Versioning)
 * Verifies if the user has accepted the latest mandatory legal documents.
 */
export const legalGateWorkerV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "LEGAL_GATE_WORKER") return;

    const { appId } = event.params;
    const client = new AgentBusClient({ 
        agentId: "LEGAL_GATE_WORKER", capabilities: ["legal_compliance", "version_audit"], 
        jurisdictions: ["AB", "BC"], substances: ["DATA"], role: "WORKER", domain: "COMPLIANCE"
    }, appId);
    await client.register();

    try {
        const { userId, documentType = "terms_of_use" } = data.payload.manifest;

        // 1. Get the latest mandatory version from central governance
        const latestDocSnap = await db.collection("legal_documents")
            .doc(documentType)
            .collection("versions")
            .orderBy("publishedAt", "desc")
            .limit(1)
            .get();

        if (latestDocSnap.empty) {
            return client.sendResponse(data.correlation_id, data.provenance.sender_id, { 
                isCompliant: true, message: "No legal documents found. Bypass active." 
            });
        }

        const latestVersion = latestDocSnap.docs[0].data();
        const latestVersionId = latestDocSnap.docs[0].id;

        // 2. Compare with user acceptance status
        const userDoc = await db.doc(`artifacts/${appId}/users/${userId}`).get();
        const userAcceptedVersion = userDoc.data()?.legal_compliance?.acceptedVersions?.[documentType];

        const isCompliant = userAcceptedVersion === latestVersionId;

        return client.sendResponse(data.correlation_id, data.provenance.sender_id, {
            isCompliant,
            latestVersion: latestVersionId,
            requiresAction: !isCompliant && latestVersion.isMajorChange,
            message: isCompliant ? "Legal gate passed." : "User must re-accept updated terms."
        });
    } catch (error: any) {
        return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, {
            code: "LEGAL_GATE_ERROR", message: error.message
        });
    }
});