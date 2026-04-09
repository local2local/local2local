import * as admin from "firebase-admin";

/**
 * SHARED SYSTEM CONFIG
 * This file is imported by many logic modules. We must guard initialization here.
 */
if (admin.apps.length === 0) {
  admin.initializeApp();
}

export const db = admin.firestore();
export const auth = admin.auth();

/**
 * Returns the current GCP Project ID.
 */
export const getProjectId = () => process.env.GCLOUD_PROJECT || "local2local-dev";

/**
 * Returns the App ID used in Firestore pathing.
 * In L2LAAF, the App ID typically matches the Project ID.
 */
export const getAppId = () => getProjectId();