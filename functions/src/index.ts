import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

/** * EVOLUTION & ORCHESTRATION 
 * V2 suffix indicates Cloud Functions v2 SDK usage.
 */
export { 
  evolutionOrchestratorV2, 
  autonomousFixerV2, 
  ombudsmanValidatorV2, 
  evolutionProposalFinalizerV2 
} from "./logic/evolution";

/** * UTILITIES
 * Restored for external application compatibility.
 */
export { deleteSubcollectionV2 } from "./utilities/deleteSubcollection";
export { listSubcollectionsV2 } from "./utilities/listSubcollections";