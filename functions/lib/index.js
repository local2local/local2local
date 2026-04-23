"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.listSubcollectionsV2 = exports.deleteSubcollectionV2 = exports.facilityMatchingWorkerV2 = exports.carrierBoardWorkerV2 = exports.gpsTelemetryWorkerV2 = exports.stripeOnboardingWorker = exports.taxWorkerV2 = exports.financeAgentV2 = exports.complianceAgentV2 = exports.unifiedActivityWorkerV2 = exports.telemetryAggregatorV2 = exports.ingestGCPErrors = exports.ingestWebError = exports.evolutionProposalFinalizerV2 = exports.autonomousFixerV2 = exports.ombudsmanValidatorV2 = exports.evolutionOrchestratorV2 = void 0;
const admin = __importStar(require("firebase-admin"));
if (admin.apps.length === 0)
    admin.initializeApp();
var evolution_1 = require("./logic/evolution");
Object.defineProperty(exports, "evolutionOrchestratorV2", { enumerable: true, get: function () { return evolution_1.evolutionOrchestratorV2; } });
Object.defineProperty(exports, "ombudsmanValidatorV2", { enumerable: true, get: function () { return evolution_1.ombudsmanValidatorV2; } });
Object.defineProperty(exports, "autonomousFixerV2", { enumerable: true, get: function () { return evolution_1.autonomousFixerV2; } });
Object.defineProperty(exports, "evolutionProposalFinalizerV2", { enumerable: true, get: function () { return evolution_1.evolutionProposalFinalizerV2; } });
var telemetry_1 = require("./logic/telemetry");
Object.defineProperty(exports, "ingestWebError", { enumerable: true, get: function () { return telemetry_1.ingestWebError; } });
Object.defineProperty(exports, "ingestGCPErrors", { enumerable: true, get: function () { return telemetry_1.ingestGCPErrors; } });
Object.defineProperty(exports, "telemetryAggregatorV2", { enumerable: true, get: function () { return telemetry_1.telemetryAggregatorV2; } });
var orchestration_1 = require("./logic/orchestration");
Object.defineProperty(exports, "unifiedActivityWorkerV2", { enumerable: true, get: function () { return orchestration_1.unifiedActivityWorkerV2; } });
var compliance_1 = require("./logic/compliance");
Object.defineProperty(exports, "complianceAgentV2", { enumerable: true, get: function () { return compliance_1.complianceAgentV2; } });
var finance_1 = require("./logic/finance");
Object.defineProperty(exports, "financeAgentV2", { enumerable: true, get: function () { return finance_1.financeAgentV2; } });
Object.defineProperty(exports, "taxWorkerV2", { enumerable: true, get: function () { return finance_1.taxWorkerV2; } });
Object.defineProperty(exports, "stripeOnboardingWorker", { enumerable: true, get: function () { return finance_1.stripeOnboardingWorker; } });
var fulfillment_1 = require("./logic/fulfillment");
Object.defineProperty(exports, "gpsTelemetryWorkerV2", { enumerable: true, get: function () { return fulfillment_1.gpsTelemetryWorkerV2; } });
Object.defineProperty(exports, "carrierBoardWorkerV2", { enumerable: true, get: function () { return fulfillment_1.carrierBoardWorkerV2; } });
var infrastructure_1 = require("./logic/infrastructure");
Object.defineProperty(exports, "facilityMatchingWorkerV2", { enumerable: true, get: function () { return infrastructure_1.facilityMatchingWorkerV2; } });
var deleteSubcollection_1 = require("./utilities/deleteSubcollection");
Object.defineProperty(exports, "deleteSubcollectionV2", { enumerable: true, get: function () { return deleteSubcollection_1.deleteSubcollectionV2; } });
var listSubcollections_1 = require("./utilities/listSubcollections");
Object.defineProperty(exports, "listSubcollectionsV2", { enumerable: true, get: function () { return listSubcollections_1.listSubcollectionsV2; } });
//# sourceMappingURL=index.js.map