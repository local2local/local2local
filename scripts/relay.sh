#!/bin/bash

# L2LAAF Autonomous Relay v1.5
# Updated: Single-string argument handling "Phase X: Title"

FULL_INPUT=$1
APP_ID="local2local-kaskflow"
PROJECT_ID="local2local-dev"

# 1. Extract Phase and Title from the single string
# Pattern expected: "Phase 36: Global Memory"
PHASE=$(echo "$FULL_INPUT" | sed -n 's/Phase \([0-9]*\):.*/\1/p')
TITLE=$(echo "$FULL_INPUT" | sed -n 's/Phase [0-9]*: \(.*\)/\1/p')

# Get absolute path of the script's directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

if [ -z "$PHASE" ] || [ -z "$TITLE" ]; then
    echo "❌ Error: Invalid format. Please use \"Phase [Number]: [Title]\""
    echo "Example: ./scripts/relay.sh \"Phase 36: Global Memory\""
    exit 1
fi

echo "🚀 INITIALIZING GUIDED AUTONOMY: PHASE $PHASE"
echo "📝 TITLE: $TITLE"
echo "--------------------------------------------"

cd "$ROOT_DIR"

# 1. Apply Code Shifts
echo "Step 1: Extracting logic from clipboard..."
# On macOS, pbpaste gets the current clipboard content
pbpaste | node scripts/patcher.js
if [ $? -ne 0 ]; then
    echo "❌ Patching failed. Ensure scripts/patcher.js exists and you copied the FULL response."
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

# Create a telemetry record in Firestore via CLI
firebase firestore:add "artifacts/$APP_ID/public/data/evolution_timeline" --data "{
  \"type\": \"PHASE_AUTONOMOUSLY_COMMITTED\",
  \"details\": \"$TITLE successfully synchronized.\",
  \"agentId\": \"RELAY_WORKER\",
  \"isAutonomous\": true,
  \"timestamp\": \"$TIMESTAMP\"
}" --project $PROJECT_ID

echo "--------------------------------------------"
echo "✅ PHASE $PHASE IS LIVE: $TITLE"