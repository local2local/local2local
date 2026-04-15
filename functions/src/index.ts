import * as admin from "firebase-admin";
if (admin.apps.length === 0) admin.initializeApp();

export { evolutionOrchestratorV3, ombudsmanValidatorV2, autonomousFixerV2, evolutionProposalFinalizerV2 } from "./logic/evolution";
export { complianceAgent } from "./logic/compliance";
export { financeAgent, taxWorker, stripeOnboardingWorker } from "./logic/finance";
export { gpsTelemetryWorkerV2, carrierBoardWorkerV2 } from "./logic/fulfillment";
export { facilityMatchingWorkerV2 } from "./logic/infrastructure";
export { unifiedActivityWorkerV2 } from "./logic/orchestration";
export { deleteSubcollectionV3 } from "./utilities/deleteSubcollection";
export { listSubcollectionsV2 } from "./utilities/listSubcollections";