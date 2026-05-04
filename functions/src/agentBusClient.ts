import * as admin from "firebase-admin";
import { v4 as uuidv4 } from "uuid";
const db = admin.firestore();

export interface AgentConfig {
  agentId: string;
  capabilities: string[];
  jurisdictions: string[];
  substances: string[];
  role: "ORCHESTRATOR" | "WORKER";
  domain: "COMPLIANCE" | "FINANCE" | "MARKET_DEV" | "OPS" | "INSIGHTS" | "SECURITY";
}

export interface AgentError {
  code: string;
  message: string;
}

export interface DispatchParams {
  correlationId: string;
  receiverId: string;
  payload: Record<string, any>;
  priority?: "normal" | "urgent" | "high" | "critical";
  status?: "pending" | "dispatched";
}

export class AgentBusClient {
  private config: AgentConfig;
  private appId: string;

  constructor(config: AgentConfig, tenantId?: string) {
    this.config = config;
    this.appId = tenantId || process.env.GCLOUD_PROJECT || "local2local-kaskflow";
  }

  async register() {
    const registryRef = db.doc(`artifacts/${this.appId}/public/data/agent_registry/${this.config.agentId}`);
    await registryRef.set({
      agent_id: this.config.agentId,
      status: { health: "green", last_heartbeat: admin.firestore.FieldValue.serverTimestamp() }
    }, { merge: true });
  }

  /// Sends a RESPONSE or ERROR message back to the originating agent.
  /// Adds created_at, last_updated, and telemetry timestamps on every write.
  async sendResponse(correlationId: string, receiverId: string, payload: any, error?: AgentError) {
    const messageId = uuidv4();
    const now = admin.firestore.FieldValue.serverTimestamp();
    await db.collection(`artifacts/${this.appId}/public/data/agent_bus`).doc(messageId).set({
      message_id: messageId,
      correlation_id: correlationId,
      provenance: { sender_id: this.config.agentId, receiver_id: receiverId, app_id: this.appId },
      control: { type: error ? "ERROR" : "RESPONSE", priority: "normal" },
      payload: error ? { error } : { result: payload },
      status: "intercepted",
      created_at: now,
      last_updated: now,
      telemetry: {
        processed_at: now,
        completed_at: now,
      },
    });
  }

  /// Dispatches a new REQUEST message to a target agent.
  /// Use this instead of direct Firestore writes for all outbound requests.
  /// Adds created_at, last_updated, and telemetry timestamps on every write.
  async dispatch(params: DispatchParams): Promise<void> {
    const messageId = uuidv4();
    const now = admin.firestore.FieldValue.serverTimestamp();
    await db.collection(`artifacts/${this.appId}/public/data/agent_bus`).doc(messageId).set({
      message_id: messageId,
      correlation_id: params.correlationId,
      provenance: {
        sender_id: this.config.agentId,
        receiver_id: params.receiverId,
        app_id: this.appId,
      },
      control: { type: "REQUEST", priority: params.priority || "normal" },
      payload: params.payload,
      status: params.status || "pending",
      created_at: now,
      last_updated: now,
      telemetry: { processed_at: now },
    });
  }
}