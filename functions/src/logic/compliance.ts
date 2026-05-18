import { onDocumentWritten, QueryDocumentSnapshot } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getFirestore } from "firebase-admin/firestore";
import { HBRVersion } from "./hbr/types";

export const complianceAgentV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}" }, async (event) => {
  // Logic visibility maintained. Renamed to match V2 export.
  const snapshot = event.data?.after as QueryDocumentSnapshot | undefined;
  if (!snapshot || !snapshot.exists) return;
});

/**
 * Handles the archive-before-update requirement for HBR drift automation.
 * Called by the pipeline or n8n to safely apply a new version while superseding the old.
 */
export const archiveAndCreateHBRVersion = onCall(async (request) => {
  if (!request.auth?.token.admin && !request.auth?.token.superadmin) {
    throw new HttpsError("permission-denied", "Must be an admin to update HBR versions.");
  }

  const data = request.data as Record<string, any>;
  const newVersion = data.newVersion as HBRVersion;
  const currentActiveId = data.currentActiveId as string | undefined;

  const db = getFirestore();
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

/**
 * Daily cron target for n8n HBR Version Activator.
 * Promotes SCHEDULED rules to ACTIVE when valid_from is reached.
 */
export const activateScheduledHBRs = onCall(async (request) => {
  const db = getFirestore();
  const now = new Date();

  const scheduledSnap = await db.collection("artifacts/system_status/public/data/hbr_versions")
    .where("status", "==", "SCHEDULED")
    .get();

  const batch = db.batch();
  let activatedCount = 0;
  const activatedIds: string[] = [];

  for (const doc of scheduledSnap.docs) {
    const data = doc.data() as HBRVersion;
    if (new Date(data.valid_from) <= now) {
      // Find current active for this rule_maker + region_scope
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