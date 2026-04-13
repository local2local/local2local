import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { AgentBusClient } from "../agentBusClient";
export const gpsTelemetryWorkerV2 = onDocumentUpdated("artifacts/{appId}/public/data/jobs/{jobId}", async (event) => {
  const appId = event.params.appId;
  const client = new AgentBusClient({ agentId: "TELEMETRY_WORKER", capabilities: ["gps"], jurisdictions: ["AB"], substances: ["DATA"], role: "WORKER", domain: "OPS" }, appId);
  await client.register();
});
export const carrierBoardWorkerV2 = onDocumentUpdated("artifacts/{appId}/public/data/carriers/{carrierId}", async (event) => {
  const appId = event.params.appId;
  const client = new AgentBusClient({ agentId: "CARRIER_WORKER", capabilities: ["dispatch"], jurisdictions: ["AB"], substances: ["DATA"], role: "WORKER", domain: "OPS" }, appId);
  await client.register();
});