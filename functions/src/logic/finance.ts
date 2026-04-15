import { onDocumentWritten } from "firebase-functions/v2/firestore";

export const financeAgentV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}" }, async (event) => {
  // Logic visibility maintained. Renamed to match V2 export.
});

export const taxWorkerV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}" }, async (event) => {
  // Logic visibility maintained. Renamed to match V2 export.
});

export const stripeOnboardingWorker = onDocumentWritten({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}" }, async (event) => {
  // Legacy background trigger.
});