import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

// Initialize Admin SDK
const app = initializeApp();
export const db = getFirestore(app);

// Context Helper: Resolves the active App ID from environment or global
export const getAppId = () => {
  return process.env.APP_ID || "local2local-kaskflow";
};

// Project Context (dev, staging, prod)
export const getProjectId = () => {
  return process.env.GCP_PROJECT || "local2local-dev";
};