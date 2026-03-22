/**
 * L2LAAF MAIN ENTRY POINT
 * This file serves as the export hub for all modular domain logic.
 * It consolidates Orchestrators, Workers, and System Utilities.
 */

// 1. Core Infrastructure & Governance
export * from "./logic/infrastructure";

// 2. Compliance & Legal Gates
export * from "./logic/compliance";

// 3. Financial Operations (Tax, Stripe, Xero)
export * from "./logic/finance";

// 4. Marketplace Orchestration (Orders & Bookings)
export * from "./logic/orchestration";

// 5. Fulfillment & Logistics (GPS, Delivery, Escrow)
export * from "./logic/fulfillment";

// 6. Fleet Dispatch & Monitoring
export * from "./logic/dispatch";

// 7. Ombudsman & User Feedback
export * from "./logic/ombudsman";

// 8. Analytics & Performance Auditing
export * from "./logic/analytics";

// 9. Treasury & Tiered Authority
export * from "./logic/treasury";

// 10. Evolution Engine (Shadow Mode & Promotion)
export * from "./logic/evolution";

// 11. Maintenance & Developer Utilities
export * from "./utilities/listSubcollections";
export * from "./utilities/deleteSubcollection";