import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export const db = admin.firestore();
export const auth = admin.auth();
export const getProjectId = () => process.env.GCLOUD_PROJECT || "local2local-dev";
export const getAppId = () => getProjectId();