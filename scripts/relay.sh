#!/bin/bash

# L2LAAF Autonomous Relay v1.1
# Orchestrates Code Patching, Git Synchronization, and Cloud Deployment.

PHASE=$1
APP_ID="local2local-kaskflow"
PROJECT_ID="local2local-dev"

if [ -z "$PHASE" ]; then
    echo "❌ Error: Please specify a Phase number (e.g., ./relay.sh 35)"
    exit 1
fi

echo "🚀 INITIALIZING GUIDED AUTONOMY: PHASE $PHASE"
echo "--------------------------------------------"

# 1. Apply Code Shifts
echo "Step 1: Extracting logic from clipboard..."
pbpaste | node scripts/patcher.js
if [ $? -ne 0 ]; then
    echo "❌ Patching failed. Aborting deployment."
    exit 1
fi

# 2. Local Build Validation
echo "Step 2: Validating TypeScript build..."
if [ -d "functions" ]; then
    cd functions
    npm run build
    if [ $? -ne 0 ]; then
        echo "❌ Build failed. Aborting deployment."
        exit 1
    fi
    cd ..
fi

# 3. Git Synchronization
echo "Step 3: Pushing logic to GitHub (develop)..."
git add .
git commit -m "AUTONOMOUS: Phase $PHASE Implementation & Tooling"
git push origin develop

# 4. Cloud Deployment
echo "Step 4: Deploying to Google Cloud ($PROJECT_ID)..."
firebase deploy --only functions --project $PROJECT_ID

# 5. Evolution Telemetry
echo "Step 5: Logging milestone to Evolution Timeline..."
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

firebase firestore:add "artifacts/$APP_ID/public/data/evolution_timeline" --data "{
  \"type\": \"PHASE_AUTONOMOUSLY_COMMITTED\",
  \"details\": \"Guided Autonomy successfully synchronized Phase $PHASE logic and tools to the Cloud.\",
  \"agentId\": \"RELAY_WORKER\",
  \"isAutonomous\": true,
  \"timestamp\": \"$TIMESTAMP\"
}" --project $PROJECT_ID

echo "--------------------------------------------"
echo "✅ PHASE $PHASE IS LIVE. MONITOR EVOLUTION TIMELINE IN COCKPIT."