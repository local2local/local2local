#!/bin/bash

# L2LAAF Relay v1.8
# Orchestrates local sync, build, and deployment for Node.js 24 Functions.
# Usage: ./scripts/relay.sh <payload_file.md>

PAYLOAD=$1

if [ -z "$PAYLOAD" ] || [ ! -f "$PAYLOAD" ]; then
    echo "❌ Error: Valid payload markdown file required."
    exit 1
fi

echo "--- L2LAAF RELAY v1.8 START ---"

# 1. Run Patcher via stdin pipe (The Vacuum Method)
echo "📡 Vacuuming payload into local filesystem..."
cat "$PAYLOAD" | node scripts/patcher.js
if [ $? -ne 0 ]; then
    echo "❌ Patcher failed. Aborting relay."
    exit 1
fi

# 2. Build Functions
echo "📦 Building Firebase Functions (Node.js 24)..."
cd functions
npm run build
if [ $? -ne 0 ]; then
    echo "❌ Build failed. Check compiler errors."
    exit 1
fi
cd ..

# 3. Deploy Phase 36/37 Logic
echo "☁️ Deploying Guided Autonomy Evolution Logic..."
firebase deploy --only functions:onProposalFinalized,functions:onResearchIntentCreated

if [ $? -eq 0 ]; then
    echo "🏁 RELAY SUCCESSFUL: Evolution Logic is Live."
else
    echo "❌ Deployment failed."
    exit 1
fi

echo "--- L2LAAF RELAY END ---"