import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { AgentBusClient } from "../agentBusClient";
export const complianceAgent = onDocumentWritten("artifacts/{appId}/public/data/agent_bus/{messageId}", async (event) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "COMPLIANCE_ORCHESTRATOR") return;
  const client = new AgentBusClient({ agentId: "COMPLIANCE_ORCHESTRATOR", capabilities: ["legal_audit"], jurisdictions: ["AB"], substances: ["DATA"], role: "ORCHESTRATOR", domain: "COMPLIANCE" }, event.params.appId);
  await client.register();
  await client.sendResponse(data.correlation_id, data.provenance.sender_id, { audit: "PASSED" });
});