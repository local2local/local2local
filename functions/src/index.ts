import * as admin from "firebase-admin";

/** * SYSTEM INITIALIZATION
 * Guarded initialization at the primary entry point.
 */
if (admin.apps.length === 0) {
  admin.initializeApp();
}

/** * GLOBAL LOGIC EXPORTS
 * Restoring visibility to all business pillars.
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