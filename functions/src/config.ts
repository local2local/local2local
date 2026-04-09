import * as admin from "firebase-admin";

/**
 * SHARED SYSTEM CONFIG
 * Hardened with admin.apps check to prevent 'duplicate-app' errors.
 */
if (admin.apps.length === 0) {
  admin.initializeApp();
}

export const db = admin.firestore();
export const auth = admin.auth();

/**
 * Helper: Returns the current GCP Project ID.
 */
export const getProjectId = () => process.env.GCLOUD_PROJECT || "local2local-dev";

/**
 * Helper: Returns the App ID used in Firestore pathing.
 */
export const getAppId = () => getProjectId();