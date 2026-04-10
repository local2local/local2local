import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

/** * EVOLUTION & ORCHESTRATION 
 * V3 suffix indicates latest logic branch.
 */
export { 
  evolutionOrchestratorV3, 
  autonomousFixerV2, 
  ombudsmanValidatorV2, 
  evolutionProposalFinalizerV2 
} from "./logic/evolution";