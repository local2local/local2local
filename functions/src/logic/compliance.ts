import { onDocumentWritten } from "firebase-functions/v2/firestore";

export const complianceAgentV2 = onDocumentWritten({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}" }, async (event) => {
  // Logic remains stable. Function renamed to match V2 standard.
});