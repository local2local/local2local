import { onRequest } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

const db = admin.firestore();

export const ingestWebError = onRequest({ cors: true }, async (req, res): Promise<void> => {
  if (req.method !== "POST") {
    res.status(405).send({ error: "Method Not Allowed" });
    return;
  }

  try {
    const errorData = req.body;
    
    // Package the error for the Agent Bus matching the strict schema
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
  } catch (err: any) {
    console.error("Failed to ingest web error:", err);
    res.status(500).send({ error: "Internal Server Error" });
  }
});