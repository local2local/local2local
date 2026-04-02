#!/bin/bash

# L2LAAF Autonomous Relay v1.7
# Fully Automated: Extracts commit messages from AI payload.

APP_ID="local2local-kaskflow"
PROJECT_ID="local2local-dev"

# Setup relative paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 INITIALIZING GUIDED AUTONOMY (FULLY AUTOMATED)"
echo "--------------------------------------------"

cd "$ROOT_DIR"

# 1. Apply Logic & Metadata
echo "Step 1: Synchronizing logic and commit metadata..."
pbpaste | node scripts/patcher.js
if [ $? -ne 0 ]; then
    echo "❌ Error: Logic synchronization failed."
    exit 1
fi

# 2. Read Extracted Commit Message
if [ -f ".commit_msg.tmp" ]; then
    COMMIT_MESSAGE=$(cat .commit_msg.tmp)
    rm .commit_msg.tmp
    echo "📝 AUTO-COMMIT: $COMMIT_MESSAGE"
else
    echo "⚠️ Warning: No embedded commit message found. Falling back to prompt."
    echo "Enter commit message:"
    read -r COMMIT_MESSAGE
fi

# 3. Build Check
if [ -d "functions" ]; then
    echo "Step 3: Validating build..."
    cd functions
    npm run lint && npm run build
    if [ $? -ne 0 ]; then
        echo "❌ Error: Build/Lint failed."
        exit 1
    fi
    cd ..
fi

# 4. Git Synchronization
echo "Step 4: Pushing to GitHub (develop)..."
git add .
git commit -m "$COMMIT_MESSAGE"
git push origin develop

# 5. Cloud Deployment
echo "Step 5: Deploying to Cloud..."
firebase deploy --only functions --project $PROJECT_ID

# 6. Telemetry Extraction
PHASE=$(echo "$COMMIT_MESSAGE" | sed -n 's/Phase \([0-9]*\):.*/\1/p')
TITLE=$(echo "$COMMIT_MESSAGE" | sed -n 's/Phase [0-9]*: \(.*\)/\1/p')

if [ -z "$PHASE" ] || [ -z "$TITLE" ]; then
    PHASE="?"
    TITLE="$COMMIT_MESSAGE"
fi

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