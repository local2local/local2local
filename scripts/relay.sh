#!/bin/bash
# --- L2LAAF RELAY v6.8 (Structural Audit + Connection Integrity) ---
# Target: logic_payload.txt
# Deployment: Automated validation (TS + Flutter + n8n) -> Git Commit -> Auto-Rebase -> Push.

PAYLOAD_FILE="./scripts/logic_payload.txt"
PROBLEMS_FILE="🔴_flutter_problems_list.txt"
PATCHER_LOG="patcher_output.log"

function fatal_error {
    echo "❌ FATAL: $1"
    exit 1
}

# 0. PROJECT STRUCTURE AUDIT
echo "--- L2LAAF RELAY v6.8 ---"
echo "Timestamp: $(date)"
echo "Checking Environment..."

# Verify project root
if [ ! -f "pubspec.yaml" ]; then
    fatal_error "Must run relay from project root containing pubspec.yaml"
fi

# Verify required directories
for dir in "functions" "lib" "n8n_workflows" "scripts"; do
    if [ ! -d "$dir" ]; then
        fatal_error "Missing required directory: $dir"
    fi
done

# Check for jq
if ! command -v jq &> /dev/null; then
    fatal_error "jq is not installed. Please install it to use the relay script."
fi

test -f "$PAYLOAD_FILE" || fatal_error "Payload file not found at $PAYLOAD_FILE"
echo "🟢 Environment Verified."
echo

# 1. SMART CLEANUP OLD ARTIFACTS
grep -q "n8n_workflows/" "$PAYLOAD_FILE"
GREP_RES=$?
if [ $GREP_RES -eq 0 ]; then
    echo "⚠️  New n8n workflow detected. Purging legacy workflows..."
    rm -f n8n_workflows/*.json
fi

# 2. RUN PATCHER
echo "🚀 Running Patcher..."
node ./scripts/patcher.js < "$PAYLOAD_FILE" > "$PATCHER_LOG" 2>&1 || fatal_error "Patcher failed. See $PATCHER_LOG"

# 3. VALIDATE COMMIT_MSG FORMAT
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

# 4. RUN TSC VALIDATION
if [ "$HAS_FUNCTIONS" -gt 0 ] && grep -qE 'functions/src/.*\.ts' "$PAYLOAD_FILE"; then
    echo "①  Pre-flight check [1/3]: Validating Cloud Functions..."
    cd functions && npm run build > /dev/null 2>&1 || fatal_error "TypeScript validation failed."
    cd ..
    echo "🟢 SUCCESS: Cloud Functions Validated."
fi

# 5. RUN FLUTTER ANALYZE
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

# 6. N8N JSON VALIDATION (STRICT AUDIT)
if [ "$HAS_N8N" = "1" ] && [ -d "n8n_workflows" ]; then
    echo "③  Pre-flight check [3/3]: Validating N8N Workflow Graph..."
    
    # 6a. Schema and Node Compatibility Check
    echo 'const fs = require("fs"); const path = require("path"); let err = false; 
    fs.readdirSync("n8n_workflows").filter(f => f.endsWith(".json")).forEach(f => { 
        try { 
            const data = JSON.parse(fs.readFileSync(path.join("n8n_workflows",f),"utf8")); 
            if(!data.nodes) throw Error("Missing nodes array"); 
            if(!data.settings || typeof data.settings !== "object") throw Error("settings must be an object {}"); 
            const nodeNames = data.nodes.map(n => n.name); 
            
            // Check for deprecated nodes
            data.nodes.forEach(n => { if(n.type.includes("googleGemini")) throw Error(`Deprecated node type: "${n.type}" in node "${n.name}". Use httpRequest.`); });

            // Check connection integrity
            Object.keys(data.connections).forEach(src => { 
                if(!nodeNames.includes(src)) throw Error(`Connection source "${src}" does not exist in nodes list.`);
                data.connections[src].main.forEach(outputs => { 
                    outputs.forEach(target => { 
                        if(!nodeNames.includes(target.node)) throw Error(`Connection target "${target.node}" (linked from "${src}") not found.`); 
                    }); 
                }); 
            }); 
        } catch(e) { console.error("❌ " + f + ": " + e.message); err = true; } 
    }); if(err) process.exit(1);' > .tmp_check.js
    
    node .tmp_check.js || fatal_error "n8n Workflow graph is invalid. Fix naming/connections."
    rm -f .tmp_check.js

    # 6b. Webhook ID check
    MISSING=$(jq -s 'map(.nodes[]) | select(.type == "n8n-nodes-base.webhook") | select(.webhookId == null) | .name' n8n_workflows/*.json 2>/dev/null)
    if [ -n "$MISSING" ] && [ "$MISSING" != "null" ]; then
        fatal_error "Webhook nodes missing webhookId: $MISSING"
    fi
    echo "🟢 SUCCESS: n8n Workflow graph validated."
fi

# 7. GITHUB DEPLOYMENT SEQUENCE
echo "🚀 Deploying to GitHub..."
git add .
git commit -m "$MSG"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if ! git push origin "$CURRENT_BRANCH"; then
    echo "📡 Syncing with remote..."
    git pull --rebase origin "$CURRENT_BRANCH" && git push origin "$CURRENT_BRANCH" || fatal_error "Push failed after sync."
fi

rm -f "$PATCHER_LOG" COMMIT_MSG
echo "🎉 DEPLOYMENT COMPLETE."