import { getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { HBRVersion } from "./hbr/types";

/**
 * Resolves the applicable HBR version for a given rule maker and target date.
 * Enforces bitemporal precedence: SCHEDULED wins if its valid_from <= targetDate.
 */
export async function resolveHBRInternal(ruleMaker: string, targetDate: Date): Promise<HBRVersion | null> {
  const db = getFirestore();
  const snapshot = await db.collection("artifacts/system_status/public/data/hbr_versions")
    .where("rule_maker", "==", ruleMaker)
    .where("status", "in", ["ACTIVE", "SCHEDULED"])
    .get();

  let activeVersion: HBRVersion | null = null;
  let scheduledVersion: HBRVersion | null = null;

  snapshot.forEach((doc) => {
    const data = doc.data() as HBRVersion;
    const validFrom = new Date(data.valid_from);
    const validUntil = data.valid_until ? new Date(data.valid_until) : null;

    if (validFrom <= targetDate && (!validUntil || validUntil > targetDate)) {
      if (data.status === "ACTIVE") {
        activeVersion = data;
      } else if (data.status === "SCHEDULED") {
        // In the event of multiple scheduled versions (e.g. cascading future changes),
        // we take the one with the latest valid_from that is still <= targetDate.
        if (!scheduledVersion || new Date(data.valid_from) > new Date(scheduledVersion.valid_from)) {
          scheduledVersion = data;
        }
      }
    }
  });

  return scheduledVersion || activeVersion || null;
}

export const resolveHBR = onCall(async (request) => {
  const data = request.data as Record<string, string>;
  const ruleMaker = data.ruleMaker;
  const targetDateStr = data.targetDate;

  if (!ruleMaker || !targetDateStr) {
    throw new HttpsError("invalid-argument", "ruleMaker and targetDate are required.");
  }

  const targetDate = new Date(targetDateStr);
  const version = await resolveHBRInternal(ruleMaker, targetDate);

  if (!version) {
    throw new HttpsError("not-found", `No applicable HBR version found for ${ruleMaker} on ${targetDateStr}`);
  }

  return version;
});