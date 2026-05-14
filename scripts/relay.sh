#!/bin/bash
# --- L2LAAF RELAY v6.7 (Connection Graph Validation + Probe Telemetry) ---
# Target: logic_payload.txt
# Deployment: Automated validation (TS + Flutter + n8n) -> Git Commit -> Auto-Rebase -> Push.

PAYLOAD_FILE="./scripts/logic_payload.txt"
PROBLEMS_FILE="🔴_flutter_problems_list.txt"
PATCHER_LOG="patcher_output.log"

function fatal_error {
    echo "❌ FATAL: $1"
    exit 1
}

# Ensure we are in the project root
if [ ! -f "pubspec.yaml" ]; then
    fatal_error "Must run relay from project root containing pubspec.yaml"
fi

test -f "$PAYLOAD_FILE" || fatal_error "Payload file not found at $PAYLOAD_FILE"

echo "--- L2LAAF RELAY v6.7 ---"
echo "Timestamp: $(date)"
echo "Using Payload: $PAYLOAD_FILE"
echo

# 0. SMART CLEANUP OLD ARTIFACTS
grep -q "n8n_workflows/" "$PAYLOAD_FILE"
GREP_RES=$?
if [ $GREP_RES -eq 0 ]; then
    echo "⚠️  New n8n workflow detected. Purging legacy workflows..."
    rm -f n8n_workflows/*.json
fi

# 1. RUN PATCHER
echo "🚀 Running Patcher..."
node ./scripts/patcher.js < "$PAYLOAD_FILE" > "$PATCHER_LOG" 2>&1 || fatal_error "Patcher failed. See $PATCHER_LOG"

# 1a. VALIDATE COMMIT_MSG FORMAT
test -f "COMMIT_MSG" || fatal_error "No COMMIT_MSG found. Did patcher run correctly?"
MSG=$(cat COMMIT_MSG)
if echo "$MSG" | grep -qE '^[0-9]+\.'; then
    fatal_error "COMMIT_MSG starts with a version number. Remove the prefix."
fi
if ! echo "$MSG" | grep -qE '^\[(MANUAL|ASSISTED|AUTO|DREAM)\]'; then
    fatal_error "COMMIT_MSG missing valid source tag."
fi

echo "✅ COMMIT_MSG format valid."

echo "============= PRE-FLIGHT CHECKS ============"

HAS_FUNCTIONS=$(grep -l "functions/" "$PAYLOAD_FILE" | wc -l | tr -d ' ')
HAS_DART=$(grep -qE '\.dart' "$PAYLOAD_FILE" && echo "1" || echo "0")
HAS_N8N=$(grep -q "n8n_workflows/" "$PAYLOAD_FILE" && echo "1" || echo "0")

# 2. RUN TSC VALIDATION
if [ "$HAS_FUNCTIONS" -gt 0 ] && grep -qE 'functions/src/.*\.ts' "$PAYLOAD_FILE"; then
    echo "①  Pre-flight check [1/3]: Validating Cloud Functions..."
    cd functions && npm run build > /dev/null 2>&1 || fatal_error "TypeScript validation failed."
    cd ..
    echo "🟢 SUCCESS: Cloud Functions Validated."
fi

# 3. RUN FLUTTER ANALYZE
if [ "$HAS_DART" = "1" ]; then
    echo "②  Pre-flight check [2/3]: Analyzing Flutter Code..."
    flutter analyze > "$PROBLEMS_FILE" 2>&1
    if [ $? -ne 0 ]; then
        fatal_error "Flutter validation failed. See $PROBLEMS_FILE"
    else
        rm -f "$PROBLEMS_FILE"
        echo "🟢 SUCCESS: Flutter Analysis Passed."
    fi
fi

# 4. N8N JSON VALIDATION
if [ "$HAS_N8N" = "1" ] && [ -d "n8n_workflows" ]; then
    echo "③  Pre-flight check [3/3]: Validating N8N Workflow Graph..."
    echo 'const fs = require("fs"); const path = require("path"); let err = false; fs.readdirSync("n8n_workflows").filter(f => f.endsWith(".json")).forEach(f => { try { const data = JSON.parse(fs.readFileSync(path.join("n8n_workflows",f),"utf8")); if(!data.nodes) throw Error("Missing nodes array"); const nodeNames = data.nodes.map(n => n.name); Object.keys(data.connections).forEach(src => { data.connections[src].main.forEach(outputs => { outputs.forEach(target => { if(!nodeNames.includes(target.node)) throw Error(`Connection broken: Destination node "${target.node}" not found in nodes list.`); }); }); }); } catch(e) { console.error("❌ " + f + ": " + e.message); err = true; } }); if(err) process.exit(1);' > .tmp_check.js
    node .tmp_check.js || fatal_error "n8n Workflow graph is invalid. Connections must use Name, not ID."
    rm -f .tmp_check.js

    # Webhook ID check
    MISSING=$(jq -s 'map(.nodes[]) | select(.type == "n8n-nodes-base.webhook") | select(.webhookId == null) | .name' n8n_workflows/*.json 2>/dev/null)
    if [ -n "$MISSING" ] && [ "$MISSING" != "null" ]; then
        fatal_error "Webhook nodes missing webhookId: $MISSING"
    fi
    echo "🟢 SUCCESS: n8n Workflow graph validated."
fi

# 5. GITHUB DEPLOYMENT SEQUENCE
echo "🚀 Deploying to GitHub..."
git add .
git commit -m "$MSG"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if ! git push origin "$CURRENT_BRANCH"; then
    git pull --rebase origin "$CURRENT_BRANCH" && git push origin "$CURRENT_BRANCH" || fatal_error "Push failed."
fi

rm -f "$PATCHER_LOG" COMMIT_MSG
echo "🎉 DEPLOYMENT COMPLETE."