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
exports.telemetryAggregatorV2 = exports.ingestGCPErrors = exports.ingestWebError = void 0;
const https_1 = require("firebase-functions/v2/https");
const pubsub_1 = require("firebase-functions/v2/pubsub");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const admin = __importStar(require("firebase-admin"));
const db = admin.firestore();
exports.ingestWebError = (0, https_1.onRequest)({ cors: true }, async (req, res) => {
    if (req.method !== "POST") {
        res.status(405).send({ error: "Method Not Allowed" });
        return;
    }
    try {
        const errorData = req.body;
        const payload = {
            correlation_id: `ERR-WEB-${Date.now()}`,
            telemetry: {
                processed_at: new Date().toISOString()
            },
            status: "dispatched",
            provenance: {
                sender_id: "FLUTTER_CLIENT",
                receiver_id: "AUTONOMOUS_FIXER"
            },
            control: {
                priority: errorData.isFatal ? "critical" : "high",
                type: "REQUEST"
            },
            payload: {
                manifest: {
                    intent: "LOG_RUNTIME_ERROR",
                    context: "RUNTIME_CRASH",
                    severity: errorData.isFatal ? "critical" : "high",
                    details: errorData.error || "Unknown Error",
                    stackTrace: errorData.stackTrace || "No stack trace provided",
                    platform: errorData.platform || "web",
                    client_timestamp: errorData.timestamp || new Date().toISOString()
                }
            }
        };
        const appId = errorData.appId || "local2local-kaskflow";
        await db.collection(`artifacts/${appId}/public/data/agent_bus`).add(payload);
        res.status(200).send({ success: true, message: "Telemetry ingested to Agent Bus." });
    }
    catch (err) {
        console.error("Failed to ingest web error:", err);
        res.status(500).send({ error: "Internal Server Error" });
    }
});
exports.ingestGCPErrors = (0, pubsub_1.onMessagePublished)({
    topic: "l2laaf-gcp-errors",
    memory: "256MiB"
}, async (event) => {
    try {
        const pubSubPayload = event.data.message.json;
        const details = pubSubPayload.textPayload || pubSubPayload.jsonPayload?.message || "Unknown GCP Error";
        const severity = pubSubPayload.severity || "ERROR";
        const payload = {
            correlation_id: `ERR-GCP-${Date.now()}`,
            telemetry: {
                processed_at: new Date().toISOString()
            },
            status: "dispatched",
            provenance: {
                sender_id: "GCP_LOG_ROUTER",
                receiver_id: "AUTONOMOUS_FIXER"
            },
            control: {
                priority: (severity === "CRITICAL" || severity === "EMERGENCY") ? "critical" : "high",
                type: "REQUEST"
            },
            payload: {
                manifest: {
                    intent: "LOG_RUNTIME_ERROR",
                    context: "BACKEND_CRASH",
                    severity: (severity === "CRITICAL" || severity === "EMERGENCY") ? "critical" : "high",
                    details: details,
                    stackTrace: pubSubPayload.textPayload ? pubSubPayload.textPayload : JSON.stringify(pubSubPayload.jsonPayload),
                    platform: "gcp_backend",
                    client_timestamp: pubSubPayload.timestamp || new Date().toISOString(),
                    resource: pubSubPayload.resource?.type || "unknown_resource"
                }
            }
        };
        const appId = "local2local-kaskflow";
        await db.collection(`artifacts/${appId}/public/data/agent_bus`).add(payload);
        console.log("Successfully ingested GCP error to Agent Bus.");
    }
    catch (err) {
        console.error("Failed to ingest GCP error:", err);
    }
});
exports.telemetryAggregatorV2 = (0, scheduler_1.onSchedule)({
    schedule: "every 1 minutes",
    memory: "256MiB"
}, async (event) => {
    const now = new Date();
    const fiveMinutesAgo = new Date(now.getTime() - 5 * 60000).toISOString();
    try {
        const kaskflowErrors = await db.collection(`artifacts/local2local-kaskflow/public/data/agent_bus`)
            .where("payload.manifest.intent", "==", "LOG_RUNTIME_ERROR")
            .where("telemetry.processed_at", ">=", fiveMinutesAgo)
            .get();
        const moonlitelyErrors = await db.collection(`artifacts/local2local-moonlitely/public/data/agent_bus`)
            .where("payload.manifest.intent", "==", "LOG_RUNTIME_ERROR")
            .where("telemetry.processed_at", ">=", fiveMinutesAgo)
            .get();
        let fatalCount = 0;
        let warningCount = 0;
        [kaskflowErrors, moonlitelyErrors].forEach(snap => {
            snap.forEach(doc => {
                const data = doc.data();
                if (data.payload?.manifest?.severity === "critical") {
                    fatalCount++;
                }
                else {
                    warningCount++;
                }
            });
        });
        let status = "GREEN";
        if (fatalCount > 0) {
            status = "RED";
        }
        else if (warningCount > 5) {
            status = "YELLOW";
        }
        await db.doc(`artifacts/system_status/public/data/telemetry/current`).set({
            status: status,
            metrics: {
                critical_errors_5m: fatalCount,
                warnings_5m: warningCount,
                last_evaluated_at: now.toISOString()
            },
            thresholds: {
                red: "fatal > 0",
                yellow: "warnings > 5"
            },
            is_overridden: false
        }, { merge: true });
        console.log(`[SLS UPDATED] System Status is now ${status}.`);
    }
    catch (error) {
        console.error("Failed to aggregate telemetry:", error);
    }
});
//# sourceMappingURL=telemetry.js.map