import { onRequest } from "firebase-functions/v2/https";
import { onMessagePublished } from "firebase-functions/v2/pubsub";
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

const db = admin.firestore();

export const ingestWebError = onRequest({ cors: true }, async (req, res): Promise<void> => {
  if (req.method !== "POST") {
    res.status(405).send({ error: "Method Not Allowed" });
    return;
  }

  try {
    const errorData = req.body;
    const now = admin.firestore.FieldValue.serverTimestamp();

    const payload = {
      correlation_id: `ERR-WEB-${Date.now()}`,
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
      },
      created_at: now,
      last_updated: now,
      telemetry: { processed_at: now },
    };

    const appId = errorData.appId || "local2local-kaskflow";
    await db.collection(`artifacts/${appId}/public/data/agent_bus`).add(payload);

    res.status(200).send({ success: true, message: "Telemetry ingested to Agent Bus." });
  } catch (err: any) {
    console.error("Failed to ingest web error:", err);
    res.status(500).send({ error: "Internal Server Error" });
  }
});

export const ingestGCPErrors = onMessagePublished({
  topic: "l2laaf-gcp-errors",
  memory: "256MiB"
}, async (event) => {
  try {
    const pubSubPayload = event.data.message.json;
    const details = pubSubPayload.textPayload || pubSubPayload.jsonPayload?.message || "Unknown GCP Error";
    const severity = pubSubPayload.severity || "ERROR";
    const now = admin.firestore.FieldValue.serverTimestamp();

    const payload = {
      correlation_id: `ERR-GCP-${Date.now()}`,
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
      },
      created_at: now,
      last_updated: now,
      telemetry: { processed_at: now },
    };

    const appId = "local2local-kaskflow";
    await db.collection(`artifacts/${appId}/public/data/agent_bus`).add(payload);

    console.log("Successfully ingested GCP error to Agent Bus.");
  } catch (err: any) {
    console.error("Failed to ingest GCP error:", err);
  }
});

export const telemetryAggregatorV2 = onSchedule({
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
        } else {
          warningCount++;
        }
      });
    });

    let status = "GREEN";
    if (fatalCount > 0) {
      status = "RED";
    } else if (warningCount > 5) {
      status = "YELLOW";
    }

    // FIX: Write to last_heartbeat (was incorrectly writing to /current).
    // The SuperAdmin dashboard repository watches last_heartbeat.
    await db.doc(`artifacts/system_status/public/data/telemetry/last_heartbeat`).set({
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
      is_overridden: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    console.log(`[SLS UPDATED] System Status is now ${status}.`);
  } catch (error) {
    console.error("Failed to aggregate telemetry:", error);
  }
});