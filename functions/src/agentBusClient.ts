import { db, getAppId, getProjectId } from "./config";
import { v4 as uuidv4 } from "uuid";

/**
 * Agent Configuration Interface
 */
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

  /**
   * @param config Agent metadata
   * @param tenantId Optional App ID. If provided, overrides default env config.
   */
  constructor(config: AgentConfig, tenantId?: string) {
    this.config = config;
    this.appId = tenantId || getAppId();
  }

  async register() {
    const registryRef = db.doc(`artifacts/${this.appId}/public/data/agent_registry/${this.config.agentId}`);
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
        project: getProjectId(),
        environment: "production",
        last_deployed: new Date().toISOString()
      }
    }, { merge: true });
  }

  async lookupCapability(capability: string, jurisdiction: string): Promise<string | null> {
    const registryRef = db.collection(`artifacts/${this.appId}/public/data/agent_registry`);
    const snapshot = await registryRef
      .where("capabilities", "array-contains", capability)
      .where("status.mode", "==", "live")
      .where("status.health", "==", "green")
      .get();

    if (snapshot.empty) return null;

    const matches = snapshot.docs
      .map(doc => doc.data())
      .filter(data => data.jurisdictions.includes(jurisdiction));

    if (matches.length === 0) return null;
    matches.sort((a, b) => b.status.current_efficacy - a.status.current_efficacy);
    return matches[0].agent_id;
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
        app_id: this.appId,
        project_id: getProjectId()
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