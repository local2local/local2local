import * as admin from "firebase-admin";
if (admin.apps.length === 0) admin.initializeApp();

export { evolutionOrchestratorV2, ombudsmanValidatorV2, autonomousFixerV2, evolutionProposalFinalizerV2 } from "./logic/evolution";
export { complianceAgentV2 } from "./logic/compliance";
export { financeAgentV2, taxWorkerV2, stripeOnboardingWorker } from "./logic/finance";
export { gpsTelemetryWorkerV2, carrierBoardWorkerV2 } from "./logic/fulfillment";
export { facilityMatchingWorkerV2 } from "./logic/infrastructure";
export { unifiedActivityWorkerV2 } from "./logic/orchestration";
export { ingestWebError } from "./logic/telemetry";
export { deleteSubcollectionV2 } from "./utilities/deleteSubcollection";
export { listSubcollectionsV2 } from "./utilities/listSubcollections";