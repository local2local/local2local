#!/bin/bash

# L2LAAF Autonomous Relay v1.4
# Updated: Custom commit naming convention [Phase X: Title]

PHASE=$1
TITLE=$2
APP_ID="local2local-kaskflow"
PROJECT_ID="local2local-dev"

# Get the absolute path of the script's directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -z "$PHASE" ] || [ -z "$TITLE" ]; then
    echo "❌ Error: Please specify Phase and Title."
    echo "Usage: ./scripts/relay.sh 36 \"Global Memory (The Lessons Learned Vault)\""
    exit 1
fi

echo "🚀 INITIALIZING GUIDED AUTONOMY: PHASE $PHASE"
echo "📝 TITLE: $TITLE"
echo "--------------------------------------------"

cd "$ROOT_DIR"

# 1. Apply Code Shifts
echo "Step 1: Extracting logic from clipboard..."
pbpaste | node scripts/patcher.js
if [ $? -ne 0 ]; then
    echo "❌ Patching failed."
    exit 1
fi

# 2. Local Build Validation
echo "Step 2: Validating TypeScript build..."
if [ -d "functions" ]; then
    cd functions
    npm run build
    if [ $? -ne 0 ]; then
        echo "❌ Build failed. Aborting."
        exit 1
    fi
    cd ..
fi

# 3. Git Synchronization
echo "Step 3: Pushing to GitHub (develop)..."
git add .
git commit -m "Phase $PHASE: $TITLE"
git push origin develop

# 4. Cloud Deployment
echo "Step 4: Deploying to Google Cloud ($PROJECT_ID)..."
firebase deploy --only functions --project $PROJECT_ID

# 5. Evolution Telemetry
echo "Step 5: Logging milestone to Evolution Timeline..."
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
firebase firestore:add "artifacts/$APP_ID/public/data/evolution_timeline" --data "{
  \"type\": \"PHASE_AUTONOMOUSLY_COMMITTED\",
  \"details\": \"$TITLE successfully synchronized.\",
  \"agentId\": \"RELAY_WORKER\",
  \"isAutonomous\": true,
  \"timestamp\": \"$TIMESTAMP\"
}" --project $PROJECT_ID

echo "--------------------------------------------"
echo "✅ PHASE $PHASE IS LIVE: $TITLE"