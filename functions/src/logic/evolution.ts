import { onDocumentCreated, onDocumentUpdated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { db } from "../config";
import { AgentBusClient } from "../agentBusClient";

/**
 * HELPER: Simple order-insensitive object comparison for SMV
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
 * Handlers for Registry Management, Shadow Initiation, and Concurrency Locking.
 */
export const evolutionOrchestratorV2 = onDocumentWritten({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const data = event.data?.after.data();
    const prev = event.data?.before.data();
    
    // GUARD: Only process when transitioning TO dispatched
    if (!data || data.status !== "dispatched" || prev?.status === "dispatched") return;
    if (data.provenance?.receiver_id !== "EVOLUTION_WORKER") return;

    const { appId } = event.params;
    const client = new AgentBusClient({ 
        agentId: "EVOLUTION_WORKER", 
        capabilities: ["logic_optimization", "concurrency_control", "shadow_mode_management"], 
        jurisdictions: ["AB"], substances: ["DATA"], role: "ORCHESTRATOR", domain: "SECURITY"
    }, appId);
    
    await client.register();

    try {
        // --- HANDLE HUMAN RESOLUTIONS ---
        if (data.control?.type === "RESPONSE" && data.payload?.result?.action === "HUMAN_COMMIT") {
            const { intervention_id, macro_applied } = data.payload.result;
            await db.collection(`artifacts/${appId}/public/data/evolution_timeline`).add({
                type: "HUMAN_OVERRIDE_COMMITTED",
                details: `Super Admin manually resolved intervention ${intervention_id} using macro: ${macro_applied}.`,
                agentId: "EVOLUTION_WORKER",
                isAutonomous: false,
                timestamp: new Date().toISOString()
            });
            return;
        }

        const manifest = data.payload?.manifest;
        if (!manifest) return;

        const { intent } = manifest;

        // --- PHASE 34: CONCURRENCY LOCKING (Firestore Mutex) ---
        if (intent === "ACQUIRE_LOGIC_LOCK") {
            const { hbrId, agentId } = manifest;
            const lockRef = db.doc(`artifacts/${appId}/public/data/logic_locks/${hbrId}`);
            
            return await db.runTransaction(async (transaction) => {
                const lockSnap = await transaction.get(lockRef);
                const now = new Date();

                if (lockSnap.exists) {
                    const lockData = lockSnap.data();
                    const expiry = new Date(lockData?.expiresAt || 0);
                    
                    if (now < expiry && lockData?.ownerId !== agentId) {
                        throw new Error("LOCK_HELD_BY_ANOTHER_AGENT");
                    }
                }

                const expiryTime = new Date(now.getTime() + 10 * 60000); // 10 minute TTL
                transaction.set(lockRef, {
                    ownerId: agentId,
                    acquiredAt: now.toISOString(),
                    expiresAt: expiryTime.toISOString(),
                    status: "locked"
                });

                return client.sendResponse(data.correlation_id, data.provenance.sender_id, { 
                    status: "lock_acquired", 
                    hbrId, 
                    expiresAt: expiryTime.toISOString() 
                });
            });
        }

        if (intent === "RELEASE_LOGIC_LOCK") {
            const { hbrId, agentId } = manifest;
            const lockRef = db.doc(`artifacts/${appId}/public/data/logic_locks/${hbrId}`);
            const lockSnap = await lockRef.get();

            if (lockSnap.exists && lockSnap.data()?.ownerId === agentId) {
                await lockRef.delete();
            }

            return client.sendResponse(data.correlation_id, data.provenance.sender_id, { 
                status: "lock_released", 
                hbrId 
            });
        }

        // --- STANDARD INTENTS ---
        if (intent === "REGISTER_DEPENDENCY") {
            const { hbrId, primaryAgentId, dependsOn = [] } = manifest;
            if (dependsOn.includes(hbrId)) throw new Error("SELF_REFERENCE_PROHIBITED");
            await db.doc(`artifacts/${appId}/public/data/logic_dependencies/${hbrId}`).set({
                hbrId, primary_agent: primaryAgentId, dependencies: dependsOn,
                updatedAt: new Date().toISOString(), status: "active"
            }, { merge: true });
            return client.sendResponse(data.correlation_id, data.provenance.sender_id, { status: "dependency_mapped", hbrId });
        }

        if (intent === "INITIATE_SHADOW_TEST") {
            const { targetAgentId } = manifest;
            await db.doc(`artifacts/${appId}/public/data/agent_registry/${targetAgentId}`).update({
                "status.mode": "shadow",
                "status.shadow_started_at": new Date().toISOString(),
                "status.shadow_success_count": 0
            });
            return client.sendResponse(data.correlation_id, data.provenance.sender_id, { status: "shadow_mode_active", agentId: targetAgentId });
        }

    } catch (error: any) {
        return client.sendResponse(data.correlation_id, data.provenance.sender_id, null, {
            code: "EVOLUTION_ERROR", message: error.message
        });
    }
});

/**
 * 2. SHADOW COMPARATOR WORKER
 */
export const shadowComparatorWorkerV2 = onDocumentWritten({
  document: "artifacts/{appId}/public/data/agent_bus/{messageId}",
  memory: "512MiB"
}, async (event) => {
    const prodMsg = event.data?.after.data();
    const prev = event.data?.before.data();
    
    if (!prodMsg || prodMsg.status !== "dispatched" || prev?.status === "dispatched") return;
    if (prodMsg.control?.type !== "RESPONSE") return;

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
        } else {
            await registryRef.update({ "status.shadow_success_count": currentCount });
        }
    } catch (error) {
        console.error("SMV Gate Error:", error);
    }
});

/**
 * 3. LOGIC COLLISION WORKER
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
        const hasCycle = async (currentId: string): Promise<boolean> => {
            if (stack.has(currentId)) return true;
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

        if (await hasCycle(hbrId)) {
            await db.doc(`artifacts/${appId}/public/data/logic_dependencies/${hbrId}`).update({ status: "blocked", collision_detected: true });
            await db.collection(`artifacts/${appId}/public/data/interventions`).add({
                type: "LOGIC_COLLISION", severity: "high", status: "active",
                details: `CIRCULAR LOGIC: ${hbrId} creates an infinite loop.`,
                createdAt: new Date().toISOString()
            });
        }
    } catch (error: any) { console.error("[LCD_ERROR]", error.message); }
});