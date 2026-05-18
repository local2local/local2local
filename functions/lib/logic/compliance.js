"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.activateScheduledHBRs = exports.archiveAndCreateHBRVersion = exports.complianceAgentV2 = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const firestore_2 = require("firebase-admin/firestore");
exports.complianceAgentV2 = (0, firestore_1.onDocumentWritten)({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}" }, async (event) => {
    const snapshot = event.data?.after;
    if (!snapshot || !snapshot.exists)
        return;
});
exports.archiveAndCreateHBRVersion = (0, https_1.onCall)(async (request) => {
    if (!request.auth?.token.admin && !request.auth?.token.superadmin) {
        throw new https_1.HttpsError("permission-denied", "Must be an admin to update HBR versions.");
    }
    const data = request.data;
    const newVersion = data.newVersion;
    const currentActiveId = data.currentActiveId;
    const db = (0, firestore_2.getFirestore)();
    const batch = db.batch();
    if (currentActiveId) {
        const currentRef = db.collection("artifacts/system_status/public/data/hbr_versions").doc(currentActiveId);
        batch.update(currentRef, {
            status: "SUPERSEDED",
            valid_until: newVersion.valid_from,
            superseded_by_version: newVersion.version_id
        });
        newVersion.supersedes_version = currentActiveId;
    }
    const newRef = db.collection("artifacts/system_status/public/data/hbr_versions").doc(newVersion.version_id);
    batch.set(newRef, newVersion);
    await batch.commit();
    return { success: true, version_id: newVersion.version_id };
});
exports.activateScheduledHBRs = (0, https_1.onCall)(async (request) => {
    const db = (0, firestore_2.getFirestore)();
    const now = new Date();
    const scheduledSnap = await db.collection("artifacts/system_status/public/data/hbr_versions")
        .where("status", "==", "SCHEDULED")
        .get();
    const batch = db.batch();
    let activatedCount = 0;
    const activatedIds = [];
    for (const doc of scheduledSnap.docs) {
        const data = doc.data();
        if (new Date(data.valid_from) <= now) {
            const activeSnap = await db.collection("artifacts/system_status/public/data/hbr_versions")
                .where("rule_maker", "==", data.rule_maker)
                .where("region_scope", "==", data.region_scope)
                .where("status", "==", "ACTIVE")
                .get();
            activeSnap.forEach((activeDoc) => {
                batch.update(activeDoc.ref, {
                    status: "SUPERSEDED",
                    valid_until: data.valid_from,
                    superseded_by_version: data.version_id
                });
            });
            batch.update(doc.ref, {
                status: "ACTIVE",
                supersedes_version: activeSnap.empty ? null : activeSnap.docs[0].id
            });
            activatedCount++;
            activatedIds.push(data.version_id);
        }
    }
    if (activatedCount > 0) {
        await batch.commit();
    }
    return { success: true, activatedCount, activatedIds };
});
//# sourceMappingURL=compliance.js.map