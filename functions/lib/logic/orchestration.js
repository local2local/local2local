"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.unifiedActivityWorkerV2 = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const agentBusClient_1 = require("../agentBusClient");
exports.unifiedActivityWorkerV2 = (0, firestore_1.onDocumentUpdated)("artifacts/{appId}/public/data/activity/{actId}", async (event) => {
    const appId = event.params.appId;
    const client = new agentBusClient_1.AgentBusClient({ agentId: "ORCHESTRATION_WORKER", capabilities: ["sync"], jurisdictions: ["AB"], substances: ["DATA"], role: "WORKER", domain: "OPS" }, appId);
    await client.register();
});
//# sourceMappingURL=orchestration.js.map