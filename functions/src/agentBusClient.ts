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
  trace?: string;
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
    const doc = await registryRef.get();
    
    if (!doc.exists) {
      await registryRef.set({
        agent_id: this.config.agentId,
        type: this.config.role,
        domain: this.config.domain,
        capabilities: this.config.capabilities,
        jurisdictions: this.config.jurisdictions,
        substances: this.config.substances,
        status: {
          health: "green",
          mode: "live",
          current_efficacy: 100,
          last_heartbeat: new Date().toISOString()
        },
        deployment: {
          project: process.env.GCLOUD_PROJECT || "unknown",
          environment: "production",
          last_deployed: new Date().toISOString()
        }
      });
    } else {
      await registryRef.update({
        "status.last_heartbeat": new Date().toISOString(),
        capabilities: this.config.capabilities,
        jurisdictions: this.config.jurisdictions,
        substances: this.config.substances,
        "deployment.last_deployed": new Date().toISOString()
      });
    }
  }

  async sendResponse(correlationId: string, receiverId: string, payload: any, error?: AgentError) {
    const busRef = db.collection(`artifacts/${this.appId}/public/data/agent_bus`);
    const messageId = uuidv4();

    await busRef.doc(messageId).set({
      message_id: messageId,
      correlation_id: correlationId,
      provenance: {
        sender_id: this.config.agentId,
        receiver_id: receiverId,
        app_id: this.appId
      },
      control: {
        type: error ? "ERROR" : "RESPONSE",
        priority: "normal"
      },
      payload: error ? { error } : { result: payload },
      telemetry: {
        completed_at: new Date().toISOString()
      },
      status: "intercepted" 
    });
  }
}