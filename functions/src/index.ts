import * as admin from "firebase-admin";
if (admin.apps.length === 0) admin.initializeApp();

/** * EVOLUTION & CORE */
export { evolutionOrchestratorV3, ombudsmanValidatorV2, autonomousFixerV2, evolutionProposalFinalizerV2 } from "./logic/evolution";

/** * LOGIC AGENTS */
export { complianceAgent } from "./logic/compliance";
export { financeAgent, taxWorker, stripeOnboardingWorker } from "./logic/finance";
export { gpsTelemetryWorkerV2, carrierBoardWorkerV2 } from "./logic/fulfillment";
export { facilityMatchingWorkerV2 } from "./logic/infrastructure";
export { unifiedActivityWorkerV2 } from "./logic/orchestration";

/** * UTILITY FUNCTIONS */
export { deleteSubcollectionV2 } from "./deleteSubcollection";
export { listSubcollectionsV2 } from "./listSubcollections";