#!/bin/bash
# --- L2LAAF RELAY v5.3 (Phase 42.1.1 Smart Purge Upgrade) ---
# Target: logic_payload.txt
# Deployment: Automated validation (TS + Flutter + n8n) -> Git Commit -> Push.

PAYLOAD_FILE="./scripts/logic_payload.txt"

if [ ! -f "$PAYLOAD_FILE" ]; then
    echo "❌ FATAL: Payload file not found at $PAYLOAD_FILE"
    exit 1
fi

echo "--- L2LAAF RELAY v5.3 ---"
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
    echo "🔍 Pre-flight check [1/3]: Validating Cloud Functions..."
    cd functions && npm run build
    if [ $? -ne 0 ]; then
        echo "❌ FATAL: TypeScript validation failed. Bad code will not be pushed."
        exit 1
    fi
    cd ..
    echo "🟢 SUCCESS: Cloud Functions Validated."

    # 3. RUN FLUTTER ANALYSIS (Web App)
    echo "🔍 Pre-flight check [2/3]: Analyzing Flutter Code..."
    flutter analyze > problems_list.txt 2>&1
    
    if grep -q "error •" problems_list.txt; then
        echo "❌ FATAL: Flutter Lint/Analysis found errors. See problems_list.txt."
        exit 1
    else
        echo "🟢 SUCCESS: Flutter Analysis Passed."
        [ -f problems_list.txt ] && rm problems_list.txt
    fi

    # 4. RUN N8N JSON VALIDATION
    echo "🔍 Pre-flight check [3/3]: Validating n8n Workflow JSON..."
    if [ -d "n8n_workflows" ]; then
        node -e "
        const fs = require('fs');
        const path = require('path');
        const files = fs.readdirSync('n8n_workflows').filter(f => f.endsWith('.json'));
        let hasError = false;
        for (const f of files) {
            try {
                const data = JSON.parse(fs.readFileSync(path.join('n8n_workflows', f), 'utf8'));
                if (!data.nodes) throw new Error('Missing \"nodes\" array in workflow definition.');
            } catch (e) {
                console.error('❌ Invalid n8n JSON in ' + f + ': ' + e.message);
                hasError = true;
            }
        }
        if (hasError) process.exit(1);
        "
        if [ $? -ne 0 ]; then
            echo "❌ FATAL: n8n Workflow JSON validation failed. Fix syntax before deploying."
            exit 1
        fi
        echo "🟢 SUCCESS: n8n Workflows Validated."
    else
        echo "⚠️  n8n_workflows directory not found. Skipping."
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
        echo "⚠️  WARNING: COMMIT_MSG file not found. Skipping git push."
    fi
else
    echo "❌ FATAL: Patching failed."
    exit 1
fi