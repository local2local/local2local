/**
 * L2LAAF State Manager & Timeout Logic (Node.js 24)
 * This logic handles the 4-hour timeout and state transitions.
 */

const TIMEOUT_HOURS = 4;
const MS_PER_HOUR = 3600000;

export default async function (items) {
  const now = new Date();
  const state = items[0].json;

  // 1. Check for Timeout
  if (state.approval_gate.pending && state.approval_gate.timeout_at) {
    const timeoutDate = new Date(state.approval_gate.timeout_at);
    
    if (now > timeoutDate) {
      return [{
        json: {
          ...state,
          system_status: "STALLED",
          approval_gate: {
            ...state.approval_gate,
            pending: false,
            status: "EXPIRED"
          },
          alert: "ACTION_REQUIRED: HITL Timeout exceeded. Manual reset necessary."
        }
      }];
    }
  }

  // 2. Handle State Reconciliation (Develop vs Main)
  if (state.reconciliation.incoming_phase) {
    const current = parseFloat(state.current_phase);
    const incoming = parseFloat(state.reconciliation.incoming_phase);

    if (incoming < current) {
      state.reconciliation.conflict_detected = true;
      state.reconciliation.notes = `Blocked rollback from Phase ${current} to ${incoming}`;
    } else {
      state.current_phase = incoming.toString();
    }
  }

  return [{ json: state }];
}