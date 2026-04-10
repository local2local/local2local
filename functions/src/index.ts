import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

/** * EVOLUTION & ORCHESTRATION */
export { 
  evolutionOrchestratorV3, 
  autonomousFixerV2, 
  ombudsmanValidatorV2, 
  evolutionProposalFinalizerV2 
} from "./logic/evolution";

/** * UTILITY FUNCTIONS */
export { deleteSubcollectionV2 } from "./deleteSubcollection";
export { listSubcollectionsV2 } from "./listSubcollections";