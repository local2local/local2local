#!/bin/bash
# --- L2LAAF RELAY v5.9 (Syntax Bulletproof Upgrade) ---
# Target: logic_payload.txt
# Deployment: Automated validation (TS + Flutter + n8n) -> Git Commit -> Push.

PAYLOAD_FILE="./scripts/logic_payload.txt"

function fatal_error {
    echo "❌ FATAL: $1"
    exit 1
}

test -f "$PAYLOAD_FILE" || fatal_error "Payload file not found at $PAYLOAD_FILE"

echo "--- L2LAAF RELAY v5.9 ---"
echo "📂 Project Root: $(pwd)"
echo "📡 Using Payload: $PAYLOAD_FILE"

# 0. SMART CLEANUP OLD ARTIFACTS
grep -q "n8n_workflows/" "$PAYLOAD_FILE"
GREP_RES=$?
test $GREP_RES -eq 0 && echo "🧹 New n8n workflow detected in payload. Purging legacy workflows..."
test $GREP_RES -eq 0 && rm -f n8n_workflows/*.json
test $GREP_RES -ne 0 && echo "⏭️ No n8n workflow update in payload. Preserving current workflow JSON."

# 1. RUN PATCHER
node ./scripts/patcher.js < "$PAYLOAD_FILE" || fatal_error "Patcher failed."

# 2. RUN TSC VALIDATION (Cloud Functions)
echo "🔍 Pre-flight check [1/3]: Validating Cloud Functions..."
cd functions || fatal_error "Could not enter functions directory."
npm run build || fatal_error "TypeScript validation failed. Bad code will not be pushed."
cd ..
echo "🟢 SUCCESS: Cloud Functions Validated."

# 3. RUN FLUTTER ANALYZE
echo "🔍 Pre-flight check [2/3]: Analyzing Flutter Code..."
flutter analyze > /dev/null || fatal_error "Flutter validation failed. Fix outstanding problems before deploying."
echo "🟢 SUCCESS: Flutter Analysis Passed."

# 4. N8N JSON VALIDATION
function validate_n8n {
    echo 'const fs = require("fs"); const path = require("path"); let err = false; fs.readdirSync("n8n_workflows").filter(f => f.endsWith(".json")).forEach(f => { try { if(!JSON.parse(fs.readFileSync(path.join("n8n_workflows",f),"utf8")).nodes) throw Error("Missing nodes array"); } catch(e) { console.error("❌ " + f + ": " + e.message); err = true; } }); if(err) process.exit(1);' > .tmp_check.js
    node .tmp_check.js || fatal_error "n8n Workflow JSON validation failed. Fix syntax before deploying."
    rm -f .tmp_check.js
    
    MISSING=$(jq '[.nodes[] | select(.type == "n8n-nodes-base.webhook") | select(.webhookId == null) | .name]' n8n_workflows/*.json 2>/dev/null)
    test "$MISSING" != "[]" && test -n "$MISSING" && fatal_error "Webhook nodes missing webhookId: $MISSING"
    
    echo "🟢 SUCCESS: n8n Workflows Validated (Syntax & Webhook IDs)."
}

echo "🔍 Pre-flight check [3/3]: Validating n8n Workflows..."
test -d "n8n_workflows" && validate_n8n
test -d "n8n_workflows" || echo "⚠️  n8n_workflows directory not found. Skipping validation."

# 5. GITHUB DEPLOYMENT SEQUENCE
echo "🚀 Initializing Deployment to GitHub..."
test -f "COMMIT_MSG" || fatal_error "No COMMIT_MSG found. Did patcher run correctly?"

MSG=$(cat COMMIT_MSG)
echo "📦 Force-tracking n8n_workflows..."
git add -f n8n_workflows/
git add .
git commit -m "$MSG"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "📡 Pushing to origin/$CURRENT_BRANCH..."
git push origin "$CURRENT_BRANCH" || fatal_error "Push failed."

echo "🎉 DEPLOYMENT COMPLETE: Stack stabilized and pushed."
rm COMMIT_MSG