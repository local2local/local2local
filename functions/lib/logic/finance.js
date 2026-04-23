"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.stripeOnboardingWorker = exports.taxWorkerV2 = exports.financeAgentV2 = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
exports.financeAgentV2 = (0, firestore_1.onDocumentWritten)({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}" }, async (event) => {
});
exports.taxWorkerV2 = (0, firestore_1.onDocumentWritten)({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}" }, async (event) => {
});
exports.stripeOnboardingWorker = (0, firestore_1.onDocumentWritten)({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}" }, async (event) => {
});
//# sourceMappingURL=finance.js.map