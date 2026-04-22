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
    
    // Package the error for the Agent Bus
    const payload = {
      status: "dispatched",
      correlation_id: `ERR-WEB-${Date.now()}`,
      provenance: {
        sender_id: "FLUTTER_WEB_CLIENT",
        receiver_id: "AUTONOMOUS_FIXER"
      },
      payload: {
        intent: "REQUEST_REASONING",
        context: "RUNTIME_CRASH",
        details: errorData.error || "Unknown Error",
        stackTrace: errorData.stackTrace || "No stack trace provided",
        isFatal: errorData.isFatal || false,
        platform: errorData.platform || "web",
        timestamp: errorData.timestamp || new Date().toISOString()
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