import * as admin from "firebase-admin";

/** * SYSTEM INITIALIZATION: 
 * This is the 'systems' file for the backend. 
 * We initialize once here at the process entry point.
 */
if (admin.apps.length === 0) {
  admin.initializeApp();
}

// Export all application-focused logic modules
export * from "./logic/evolution";