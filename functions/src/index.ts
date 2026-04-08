import * as admin from "firebase-admin";

/** * SYSTEM INITIALIZATION: 
 * This is the 'systems' file for the backend. 
 * We initialize once here, at the entry point of the Cloud Functions process.
 */
if (admin.apps.length === 0) {
  admin.initializeApp();
}

// Export all application-focused functions
export * from "./logic/evolution";