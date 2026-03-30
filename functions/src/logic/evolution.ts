import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../config";
import { AgentBusClient } from "../agentBusClient";

/**
 * HELPER: Simple order-insensitive object comparison
 */
function areResultsIdentical(a: any, b: any): boolean {
    try {
        return JSON.stringify(a, Object.keys(a).sort()) === JSON.stringify(b, Object.keys(b).sort());
    } catch (e) {
        return false;
    }
}

/**
 * 1. EVOLUTION ORCHESTRATOR
 * Handlers for Registry Management, Shadow Initiation, and Dependency Registration.
 */
export const evolutionOrchestratorV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    if (!data || data.status !== "dispatched" || data.provenance.receiver_id !== "EVOLUTION_WORKER") return;

    const { appId } = event.params;
    const client = new AgentBusClient({ 
        agentId: "EVOLUTION_WORKER", capabilities: ["logic_optimization", "dependency_mapping", "shadow_mode_management"], 
        jurisdictions: ["AB"], substances: ["DATA"], role: "ORCHESTRATOR", domain: "SECURITY"
    }, appId);
    
    await client.register();

    try {
        const { intent } = data.payload.manifest;

        // --- PHASE 28: DEPENDENCY REGISTRATION ---
        if (intent === "REGISTER_DEPENDENCY") {
            const { hbrId, primaryAgentId, dependsOn = [] } = data.payload.manifest;
            
            // Logic: Prevent an HBR from depending on itself
            if (dependsOn.includes(hbrId)) {
                throw new Error("SELF_REFERENCE_PROHIBITED");
            }

            const dependencyRef = db.doc(`artifacts/${appId}/public/data/logic_dependencies/${hbrId}`);
            
            await dependencyRef.set({
                hbrId,
                primary_agent: primaryAgentId,
                dependencies: dependsOn, // Array of other HBR IDs
                updatedAt: new Date().toISOString(),
                status: "active"
            }, { merge: true });

            return client.sendResponse(data.correlation_id, data.provenance.sender_id, { 
                status: "dependency_mapped", 
                hbrId, 
                dependencyCount: dependsOn.length 
            });
        }

        if (intent === "INITIATE_SHADOW_TEST") {
            const { targetAgentId } = data.payload.manifest;
            await db.doc(`artifacts/${appId}/public/data/agent_registry/${targetAgentId}`).update({
                "status.mode": "shadow",
                "status.shadow_started_at": new Date().toISOString(),
                "status.shadow_success_count": 0
            });

            return client.sendResponse(data.correlation_id, data.provenance.sender_id, {
                status: "shadow_mode_active",
                agentId: targetAgentId,
                message: `Shadow fork enabled for ${targetAgentId}. Resetting success counter.`
            });
        }

        throw new Error(`UNSUPPORTED_INTENT: ${intent}`);
    } catch (error: any) {
        return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, {
            code: "EVOLUTION_ERROR", message: error.message
        });
    }
});

/**
 * 2. SHADOW COMPARATOR WORKER
 * Hardened comparison and autonomous promotion to live status.
 */
export const shadowComparatorWorkerV2 = onDocumentUpdated({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const prodMsg = event.data?.after.data();
    if (!prodMsg || prodMsg.control?.type !== "RESPONSE") return;

    const { appId } = event.params;
    const { correlation_id } = prodMsg;
    const agentId = prodMsg.provenance.sender_id;

    try {
        const shadowSnap = await db.collection(`artifacts/${appId}/public/data/shadow_bus`)
            .where("correlation_id", "==", correlation_id)
            .where("control.type", "==", "RESPONSE")
            .get();

        if (shadowSnap.empty) return; 

        const shadowMsg = shadowSnap.docs[0].data();
        const isMatch = areResultsIdentical(prodMsg.payload?.result || {}, shadowMsg.payload?.result || {});
        
        await db.collection(`artifacts/${appId}/public/data/shadow_runs`).doc(correlation_id).set({
            correlation_id, agentId, status: isMatch ? "validated" : "failed",
            timestamp: new Date().toISOString(),
            metrics: { logic_integrity: isMatch ? 1.0 : 0.0 }
        });

        if (!isMatch) {
            await db.doc(`artifacts/${appId}/public/data/agent_registry/${agentId}`).update({ "status.shadow_success_count": 0 });
            await db.collection(`artifacts/${appId}/public/data/agent_bus`).add({
                correlation_id: `smv-fail-${correlation_id}`, status: "pending", control: { type: "REQUEST", priority: "high" },
                provenance: { sender_id: "EVOLUTION_WORKER", receiver_id: "SAFETY_WORKER" },
                payload: { manifest: { intent: "LOG_SAFETY_VIOLATION", severity: "high", details: `SMV Mismatch detected for ${agentId}.` } }
            });
            return;
        }

        const SUCCESS_THRESHOLD = 3; 
        const registryRef = db.doc(`artifacts/${appId}/public/data/agent_registry/${agentId}`);
        const registrySnap = await registryRef.get();
        const currentCount = (registrySnap.data()?.status?.shadow_success_count || 0) + 1;

        if (currentCount >= SUCCESS_THRESHOLD && registrySnap.data()?.status?.mode === "shadow") {
            await registryRef.update({
                "status.mode": "live",
                "status.shadow_success_count": currentCount,
                "status.last_promotion_at": new Date().toISOString()
            });

            await db.collection(`artifacts/${appId}/public/data/agent_bus`).add({
                correlation_id: `promotion-${correlation_id}`, status: "pending", control: { type: "REQUEST" },
                provenance: { sender_id: "EVOLUTION_WORKER", receiver_id: "OMBUDS_WORKER" },
                payload: { manifest: { intent: "PROCESS_FEEDBACK", category: "policy", feedbackText: `Agent ${agentId} autonomously promoted to LIVE.` } }
            });
        } else {
            await registryRef.update({ "status.shadow_success_count": currentCount });
        }
    } catch (error) {
        console.error("SMV Gate Error:", error);
    }
});

/**
 * 3. LOGIC COLLISION WORKER (Phase 28: LCD Protocol)
 * Traverses the dependency graph to prevent circular logic (A -> B -> A).
 */
export const logicCollisionWorkerV2 = onDocumentCreated({
  document: "artifacts/{appId}/public/data/logic_dependencies/{hbrId}",
  memory: "512MiB"
}, async (event) => {
    const newDep = event.data?.data();
    if (!newDep) return;

    const { appId, hbrId } = event.params;

    try {
        const visited = new Set<string>();
        const stack = new Set<string>();

        /**
         * Recursive Depth-First Search to detect cycles in the HBR graph.
         */
        const hasCycle = async (currentId: string): Promise<boolean> => {
            if (stack.has(currentId)) return true; // Cycle detected
            if (visited.has(currentId)) return false;

            visited.add(currentId);
            stack.add(currentId);

            const doc = await db.doc(`artifacts/${appId}/public/data/logic_dependencies/${currentId}`).get();
            const deps = doc.data()?.dependencies || [];

            for (const depId of deps) {
                if (await hasCycle(depId)) return true;
            }

            stack.delete(currentId);
            return false;
        };

        const cycleFound = await hasCycle(hbrId);

        if (cycleFound) {
            console.warn(`[LCD_FAILURE] Circular dependency detected for ${hbrId}. Raising Intervention.`);
            
            // 1. Mark dependency as invalid/blocked
            await db.doc(`artifacts/${appId}/public/data/logic_dependencies/${hbrId}`).update({
                status: "blocked",
                collision_detected: true,
                error_message: "CIRCULAR_LOGIC_LOOP"
            });

            // 2. Create Red Status Intervention for Human
            await db.collection(`artifacts/${appId}/public/data/interventions`).add({
                type: "LOGIC_COLLISION",
                severity: "high",
                status: "active",
                details: `CIRCULAR LOGIC: ${hbrId} creates an infinite loop in the business rule graph. Registration blocked.`,
                createdAt: new Date().toISOString()
            });
        }
    } catch (error: any) {
        console.error("[LCD_ERROR]", error.message);
    }
});