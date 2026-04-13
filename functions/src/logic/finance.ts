import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { AgentBusClient } from "../agentBusClient";
export const financeAgent = onDocumentWritten("artifacts/{appId}/public/data/agent_bus/{messageId}", async (event) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "FINANCE_ORCHESTRATOR") return;
  const client = new AgentBusClient({ agentId: "FINANCE_ORCHESTRATOR", capabilities: ["ledger_sync"], jurisdictions: ["AB"], substances: ["FINANCE"], role: "ORCHESTRATOR", domain: "FINANCE" }, event.params.appId);
  await client.register();
  await client.sendResponse(data.correlation_id, data.provenance.sender_id, { status: "SYNCED" });
});
export const taxWorker = onDocumentWritten("artifacts/{appId}/public/data/agent_bus/{messageId}", async (event) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "TAX_WORKER") return;
  const client = new AgentBusClient({ agentId: "TAX_WORKER", capabilities: ["tax_calc"], jurisdictions: ["AB"], substances: ["FINANCE"], role: "WORKER", domain: "FINANCE" }, event.params.appId);
  await client.sendResponse(data.correlation_id, data.provenance.sender_id, { tax: 0.05 });
});
export const stripeOnboardingWorker = onDocumentWritten("artifacts/{appId}/public/data/agent_bus/{messageId}", async (event) => {
  const data = event.data?.after.data();
  if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "STRIPE_ONBOARDING_WORKER") return;
  const client = new AgentBusClient({ agentId: "STRIPE_ONBOARDING_WORKER", capabilities: ["onboarding"], jurisdictions: ["AB"], substances: ["FINANCE"], role: "WORKER", domain: "FINANCE" }, event.params.appId);
  await client.sendResponse(data.correlation_id, data.provenance.sender_id, { link: "https://stripe.com/onboard" });
});