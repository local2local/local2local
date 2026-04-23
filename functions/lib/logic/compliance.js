"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.complianceAgentV2 = void 0;
const firestore_1 = require("firebase-functions/v2/firestore");
exports.complianceAgentV2 = (0, firestore_1.onDocumentWritten)({ document: "artifacts/{appId}/public/data/agent_bus/{messageId}" }, async (event) => {
});
//# sourceMappingURL=compliance.js.map