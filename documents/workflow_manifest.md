# L2LAAF Workflow Manifest (NASA Standard v6.3)

## 1. Code Delivery Protocol (Cursor IDE-Ready)
- **Zero Abbreviation Policy:** Every code block MUST contain the **full, entire file content**. Never use "// ... rest of code".
- **L2LAAF Blocks:** Wrap everything in:
  L2LAAF_BLOCK_START(type:label:filepath)
  [FULL_FILE_CONTENT]
  L2LAAF_BLOCK_END
- **Token Handling:** Replace all backticks (`) with `[BACKTICK]` within code blocks.
- **Files in this chat:** In the AI "Files in this chat" always use file names as they would appear in a folder
- **Example:**
  `evolution.ts` is correct
  `Evolution Engine` is incorrect

## 2. Strict Engineering Rules (Backend)
- **TypeScript:** Every `Change` MUST use `<QueryDocumentSnapshot>`. Every `params` argument MUST be `Record<string, string>`.
- **YAML (deploy.yml):** Header keys (name, on, env) must be on separate lines with strict indentation.
- **Node.js:** Strictly target Node.js 24 (2nd Gen Functions).
- **Local Imports:** Use the format `package:local2local/...` (not local2local_app).

## 3. Firestore Test Data Protocol
- **Format:** Provide the full path with NO spaces and the document body as a JSON object.
- **Example:**
  **PATH:** artifacts/local2local-kaskflow/public/data/agent_bus/test_msg_001
  **JSON:** { "status": "dispatched", "provenance": { "receiver_id": "EVOLUTION_WORKER" } }

## 3. Frontend-Backend Sync (Dreamflow Bridge)
- **Namespace Alignment:** Use snake_case for all Firestore keys to match Flutter models.
- **Loop:** If a backend change affects the UI, must provide a specific prompt to give back to the Dreamflow AI Agent.

## 4. Frontend-Backend Sync (Dreamflow Bridge)
- **Namespace Alignment:** Use snake_case for all Firestore keys to match Flutter models.
- **UI Impact:** If a backend change affects the UI, provide a specific prompt to give back to G1/Dreamflow.

## 5. Automation & Validation
- **Mental TSC:** G3 must simulate `tsc --noEmit` on all Node.js 24 code.
- **Check-In:** Every 5 turns, provide a "Status & Technical Debt" report.




