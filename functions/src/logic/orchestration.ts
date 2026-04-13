import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { AgentBusClient } from "../agentBusClient";
export const unifiedActivityWorkerV2 = onDocumentUpdated("artifacts/{appId}/public/data/activity/{actId}", async (event) => {
  const appId = event.params.appId;
  const client = new AgentBusClient({ agentId: "ORCHESTRATION_WORKER", capabilities: ["sync"], jurisdictions: ["AB"], substances: ["DATA"], role: "WORKER", domain: "OPS" }, appId);
  await client.register();
});