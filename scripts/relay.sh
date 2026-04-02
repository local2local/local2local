#!/bin/bash

# L2LAAF Autonomous Relay v1.6
# Interactive commit prompting and linting enforcement.

APP_ID="local2local-kaskflow"
PROJECT_ID="local2local-dev"

# Get absolute path of the script's directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 INITIALIZING GUIDED AUTONOMY"
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

# 2. Linting Check
echo "Step 2: Running linting check..."
if [ -d "functions" ]; then
    cd functions
    npm run lint
    if [ $? -ne 0 ]; then
        echo "❌ Linting failed. Please fix issues before deploying."
        exit 1
    fi
    
    # 3. Local Build Validation
    echo "Step 3: Validating TypeScript build..."
    npm run build
    if [ $? -ne 0 ]; then
        echo "❌ Build failed. Aborting deployment."
        exit 1
    fi
    cd ..
else
    echo "⚠️ No 'functions' directory found. Skipping lint/build."
fi

# 4. Prompt for Commit Message
echo ""
echo "--------------------------------------------"
echo "Enter commit message (e.g., Phase 36: Global Memory):"
read -r COMMIT_MESSAGE

if [ -z "$COMMIT_MESSAGE" ]; then
    echo "❌ Error: Commit message is required to proceed."
    exit 1
fi

# Extract Phase and Title for telemetry
PHASE=$(echo "$COMMIT_MESSAGE" | sed -n 's/Phase \([0-9]*\):.*/\1/p')
TITLE=$(echo "$COMMIT_MESSAGE" | sed -n 's/Phase [0-9]*: \(.*\)/\1/p')

if [ -z "$PHASE" ] || [ -z "$TITLE" ]; then
    PHASE="?"
    TITLE="$COMMIT_MESSAGE"
fi

# 5. Git Synchronization
echo "Step 5: Pushing to GitHub (develop)..."
git add .
git commit -m "$COMMIT_MESSAGE"
git push origin develop

# 6. Cloud Deployment
echo "Step 6: Deploying to Google Cloud ($PROJECT_ID)..."
firebase deploy --only functions --project $PROJECT_ID

# 7. Evolution Telemetry
echo "Step 7: Logging milestone to Evolution Timeline..."
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