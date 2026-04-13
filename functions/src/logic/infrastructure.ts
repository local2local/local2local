import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { AgentBusClient } from "../agentBusClient";
export const facilityMatchingWorkerV2 = onDocumentUpdated("artifacts/{appId}/public/data/facilities/{facId}", async (event) => {
  const appId = event.params.appId;
  const client = new AgentBusClient({ agentId: "FACILITY_WORKER", capabilities: ["matching"], jurisdictions: ["AB"], substances: ["DATA"], role: "WORKER", domain: "OPS" }, appId);
  await client.register();
});