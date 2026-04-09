import * as admin from "firebase-admin";

/** * SYSTEM INITIALIZATION
 * This ensures Firebase is ready before any application logic exports.
 */
if (admin.apps.length === 0) {
  admin.initializeApp();
}

/** * GLOBAL LOGIC EXPORTS
 * These exports make the functions inside each file visible to the Firebase CLI.
 * Each module below represents a critical business pillar of L2LAAF.
 */
export * from "./logic/analytics";
export * from "./logic/compliance";
export * from "./logic/dispatch";
export * from "./logic/evolution";
export * from "./logic/finance";
export * from "./logic/fulfillment";
export * from "./logic/infrastructure";
export * from "./logic/ombudsman";
export * from "./logic/orchestration";
export * from "./logic/treasury";