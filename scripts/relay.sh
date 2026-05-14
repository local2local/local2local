#!/bin/bash
# --- L2LAAF RELAY v6.2 (Conditional Preflight + Format Validation) ---
# Target: logic_payload.txt
# Deployment: Automated validation (TS + Flutter + n8n) -> Git Commit -> Auto-Rebase -> Push.

PAYLOAD_FILE="./scripts/logic_payload.txt"
PROBLEMS_FILE="flutter_problems_list.txt"

function fatal_error {
    echo "❌ FATAL: $1"
    exit 1
}

test -f "$PAYLOAD_FILE" || fatal_error "Payload file not found at $PAYLOAD_FILE"

echo "--- L2LAAF RELAY v6.2 ---"
echo
echo "Project Root: $(pwd)"
echo "Using Payload: $PAYLOAD_FILE"
echo

# 0. SMART CLEANUP OLD ARTIFACTS
grep -q "n8n_workflows/" "$PAYLOAD_FILE"
GREP_RES=$?
test $GREP_RES -eq 0 && echo "⚠️  New n8n workflow detected in payload. Purging legacy workflows..."
test $GREP_RES -eq 0 && rm -f n8n_workflows/*.json
test $GREP_RES -ne 0 && echo "⚠️  No n8n workflow update in payload. Preserving current workflow JSON."

# 1. RUN PATCHER
node ./scripts/patcher.js < "$PAYLOAD_FILE" || fatal_error "Patcher failed."

# 1a. VALIDATE COMMIT_MSG FORMAT
test -f "COMMIT_MSG" || fatal_error "No COMMIT_MSG found. Did patcher run correctly?"
MSG=$(cat COMMIT_MSG)

# Reject if message starts with a digit (manually prefixed version number)
if echo "$MSG" | grep -qE '^[0-9]+\.'; then
    fatal_error "COMMIT_MSG starts with a version number ('$MSG'). Remove the version prefix — the pipeline adds it automatically."
fi

# Reject if message does not start with a valid source tag
if ! echo "$MSG" | grep -qE '^\[(MANUAL|ASSISTED|AUTO|DREAM)\]'; then
    fatal_error "COMMIT_MSG missing valid source tag. Must start with [MANUAL], [ASSISTED], [AUTO], or [DREAM]. Got: '$MSG'"
fi

echo "✅ COMMIT_MSG format valid: $MSG"
echo

echo "============= PRE-FLIGHT CHECKS ============"

# Detect what's in the payload
HAS_FUNCTIONS=$(grep -l "functions/" "$PAYLOAD_FILE" | wc -l | tr -d ' ')
HAS_DART=$(grep -qE '\.dart' "$PAYLOAD_FILE" && echo "1" || echo "0")
HAS_N8N=$(grep -q "n8n_workflows/" "$PAYLOAD_FILE" && echo "1" || echo "0")

# 2. RUN TSC VALIDATION (Cloud Functions) — only if payload contains functions/
echo "①  Pre-flight check [1/3]: Validating Cloud Functions..."
if [ "$HAS_FUNCTIONS" -gt 0 ] && grep -qE 'functions/src/.*\.ts' "$PAYLOAD_FILE"; then
    cd functions || fatal_error "Could not enter functions directory."
    npm run build || fatal_error "TypeScript validation failed. Bad code will not be pushed."
    cd ..
    echo "🟢 SUCCESS: Cloud Functions Validated."
else
    echo "⏭️  No Cloud Functions found in payload. Pre-flight check skipped."
fi

echo

# 3. RUN FLUTTER ANALYZE — only if payload contains .dart files
echo "②  Pre-flight check [2/3]: Analyzing Flutter Code..."
if [ "$HAS_DART" = "1" ]; then
    flutter analyze 2>/dev/null > "$PROBLEMS_FILE"
    if [ $? -ne 0 ]; then
        fatal_error "Flutter validation failed. Fix outstanding problems before deploying. See $PROBLEMS_FILE for details."
    else
        rm -f "$PROBLEMS_FILE"
        echo "🟢 SUCCESS: Flutter Analysis Passed."
    fi
else
    echo "⏭️  No Flutter (.dart) files found in payload. Pre-flight check skipped."
fi

echo

# 4. N8N JSON VALIDATION — only if payload contains n8n_workflows/
echo "③  Pre-flight check [3/3]: Validating N8N Workflow JSON..."
if [ "$HAS_N8N" = "1" ] && [ -d "n8n_workflows" ]; then
    echo 'const fs = require("fs"); const path = require("path"); let err = false; fs.readdirSync("n8n_workflows").filter(f => f.endsWith(".json")).forEach(f => { try { if(!JSON.parse(fs.readFileSync(path.join("n8n_workflows",f),"utf8")).nodes) throw Error("Missing nodes array"); } catch(e) { console.error("❌ " + f + ": " + e.message); err = true; } }); if(err) process.exit(1);' > .tmp_check.js
    node .tmp_check.js || fatal_error "n8n Workflow JSON validation failed. Fix syntax before deploying."
    rm -f .tmp_check.js

    MISSING=$(jq '[.nodes[] | select(.type == "n8n-nodes-base.webhook") | select(.webhookId == null) | .name]' n8n_workflows/*.json 2>/dev/null)
    test "$MISSING" != "[]" && test -n "$MISSING" && fatal_error "Webhook nodes missing webhookId: $MISSING"

    echo "🟢 SUCCESS: n8n Workflows Validated (Syntax & Webhook IDs)."
else
    echo "⏭️  No n8n workflow files found in payload. Pre-flight check skipped."
fi

# 5. GITHUB DEPLOYMENT SEQUENCE
echo
echo "🚀 Initializing Deployment to GitHub..."

# Only force-track n8n_workflows if payload contains them
if [ "$HAS_N8N" = "1" ]; then
    echo "Force-tracking n8n_workflows..."
    git add -f n8n_workflows/
fi

git add .
git commit -m "$MSG"

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "📡 Pushing to origin/$CURRENT_BRANCH..."

# Auto-rebase logic
if ! git push origin "$CURRENT_BRANCH"; then
    echo "⚠️  Remote is ahead (likely due to an autonomous AI commit). Attempting to rebase..."

    if git pull --rebase origin "$CURRENT_BRANCH"; then
        echo "✅ Synchronized with remote AI commits. Retrying push..."
        git push origin "$CURRENT_BRANCH" || fatal_error "Push failed after rebase."
    else
        fatal_error "Merge conflict during rebase. The AI modified the same lines you did! Please resolve manually, run 'git rebase --continue', and push."
    fi
fi

echo "🎉 DEPLOYMENT COMPLETE: Stack stabilized and pushed."
rm -f COMMIT_MSG
