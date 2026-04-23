"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.carrierBoardWorkerV2 = exports.gpsTelemetryWorkerV2 = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
const agentBusClient_1 = require("../agentBusClient");
exports.gpsTelemetryWorkerV2 = (0, firestore_1.onDocumentUpdated)("artifacts/{appId}/public/data/jobs/{jobId}", async (event) => {
    const appId = event.params.appId;
    const client = new agentBusClient_1.AgentBusClient({ agentId: "TELEMETRY_WORKER", capabilities: ["gps"], jurisdictions: ["AB"], substances: ["DATA"], role: "WORKER", domain: "OPS" }, appId);
    await client.register();
});
exports.carrierBoardWorkerV2 = (0, firestore_1.onDocumentUpdated)("artifacts/{appId}/public/data/carriers/{carrierId}", async (event) => {
    const appId = event.params.appId;
    const client = new agentBusClient_1.AgentBusClient({ agentId: "CARRIER_WORKER", capabilities: ["dispatch"], jurisdictions: ["AB"], substances: ["DATA"], role: "WORKER", domain: "OPS" }, appId);
    await client.register();
});
//# sourceMappingURL=fulfillment.js.map