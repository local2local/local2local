#!/bin/bash

L2LAAF Relay v1.8

PAYLOAD=$1
if [ -z "$PAYLOAD" ] || [ ! -f "$PAYLOAD" ]; then echo "❌ Error: Valid payload required."; exit 1; fi
echo "--- L2LAAF RELAY v1.8 ---"
echo "📡 Ingesting payload into local filesystem..."
cat "$PAYLOAD" | node scripts/patcher.js
if [ $? -ne 0 ]; then echo "❌ Patcher failed."; exit 1; fi
if [ -f ".commit_msg.tmp" ]; then
COMMIT_MSG=$(cat .commit_msg.tmp)
rm .commit_msg.tmp
echo "📝 Context: $COMMIT_MSG"
fi
echo "📦 Building Firebase Functions (Node.js 24)..."
cd functions && npm run build && cd ..
echo "☁️ Deploying Phase 36 Logic..."
firebase deploy --only functions:onProposalFinalized
echo "--- L2LAAF RELAY END ---"