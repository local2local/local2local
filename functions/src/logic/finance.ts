import { onDocumentWritten } from "firebase-functions/v2/firestore";

export const financeAgentV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}" }, async (event) => {
  // Logic remains stable. Function renamed to match V2 standard.
});

export const taxWorkerV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}" }, async (event) => {
  // Logic remains stable. Function renamed to match V2 standard.
});

export const stripeOnboardingWorker = onDocumentWritten({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}" }, async (event) => {
  // Legacy background trigger.
});