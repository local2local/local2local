#!/bin/bash
# --- L2LAAF RELAY v5.4.2 (Syntax Guard Upgrade) ---
# Target: logic_payload.txt
# Deployment: Automated validation (TS + Flutter + n8n) -> Git Commit -> Push.

PAYLOAD_FILE="./scripts/logic_payload.txt"

if [ ! -f "$PAYLOAD_FILE" ]; then
    echo "❌ FATAL: Payload file not found at $PAYLOAD_FILE"
    exit 1
fi

echo "--- L2LAAF RELAY v5.4.2 ---"
echo "📂 Project Root: $(pwd)"
echo "📡 Using Payload: $PAYLOAD_FILE"

# 0. SMART CLEANUP OLD ARTIFACTS
if grep -q "n8n_workflows/" "$PAYLOAD_FILE"; then
    echo "🧹 New n8n workflow detected in payload. Purging legacy workflows..."
    rm -f n8n_workflows/*.json
else
    echo "⏭️ No n8n workflow update in payload. Preserving current workflow JSON."
fi

# 1. RUN PATCHER
node ./scripts/patcher.js < "$PAYLOAD_FILE"

if [ $? -eq 0 ]; then
    # 2. RUN TSC VALIDATION (Cloud Functions)
    echo "🔍 Pre-flight check [1/4]: Validating Cloud Functions..."
    cd functions && npm run build
    if [ $? -ne 0 ]; then
        echo "❌ FATAL: TypeScript validation failed. Bad code will not be pushed."
        exit 1
    fi
    cd ..
    echo "🟢 SUCCESS: Cloud Functions Validated."

    # 3. RUN FLUTTER ANALYZE
    echo "🔍 Pre-flight check [2/4]: Analyzing Flutter Code..."
    flutter analyze > /dev/null
    if [ $? -ne 0 ]; then
        echo "❌ FATAL: Flutter validation failed. Fix outstanding problems before deploying."
        exit 1
    fi
    echo "🟢 SUCCESS: Flutter Analysis Passed."

    # 4. N8N JSON VALIDATION
    echo "🔍 Pre-flight check [3/4]: Validating n8n Workflow JSON structure..."
    if [ -d "n8n_workflows" ]; then
        node << 'EOF'
const fs = require('fs');
const path = require('path');
let hasError = false;
for (const f of fs.readdirSync('n8n_workflows').filter(n => n.endsWith('.json'))) {
    try {
        const data = JSON.parse(fs.readFileSync(path.join('n8n_workflows', f), 'utf8'));
        if (!data.nodes) throw new Error('Missing "nodes" array in workflow definition.');
    } catch (e) {
        console.error('❌ Invalid n8n JSON in ' + f + ': ' + e.message);
        hasError = true;
    }
}
if (hasError) process.exit(1);
EOF
        if [ $? -ne 0 ]; then
            echo "❌ FATAL: n8n Workflow JSON validation failed. Fix syntax before deploying."
            exit 1
        fi
        
        # --- WEBHOOK ID PRE-FLIGHT GUARD ---
        echo "🔍 Pre-flight check [4/4]: Validating n8n Webhook IDs..."
        MISSING=$(jq '[.nodes[] | select(.type == "n8n-nodes-base.webhook") | select(.webhookId == null) | .name]' n8n_workflows/*.json 2>/dev/null)
        if [[ "$MISSING" != "[]" && -n "$MISSING" ]]; then
            echo "❌ FATAL: Webhook nodes missing webhookId: $MISSING"
            exit 1
        fi
        echo "✅ All webhook nodes have webhookId."
        
        echo "🟢 SUCCESS: n8n Workflows Validated."
    else
        echo "⚠️  n8n_workflows directory not found. Skipping validation."
    fi

    # 5. GITHUB DEPLOYMENT SEQUENCE
    echo "🚀 Initializing Deployment to GitHub..."
    if [ -f "COMMIT_MSG" ]; then
        MSG=$(cat COMMIT_MSG)
        
        # FORCE TRACK N8N FOLDER TO BYPASS .GITIGNORE
        echo "📦 Force-tracking n8n_workflows..."
        git add -f n8n_workflows/
        
        git add .
        git commit -m "$MSG"
        
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
        echo "📡 Pushing to origin/$CURRENT_BRANCH..."
        git push origin "$CURRENT_BRANCH"
        
        if [ $? -eq 0 ]; then
            echo "🎉 DEPLOYMENT COMPLETE: Stack stabilized and pushed."
            rm COMMIT_MSG
        else
            echo "❌ FATAL: Push failed."
            exit 1
        fi
    else
        echo "⚠️  No COMMIT_MSG found. Did patcher run correctly?"
        exit 1
    fi
else
    echo "❌ FATAL: Patcher failed."
    exit 1
fi