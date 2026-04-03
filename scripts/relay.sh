#!/bin/bash

# L2LAAF Relay v3.0 (NASA Standard - Pre-Flight Check)
# Orchestrates local sync, validates TypeScript, and handles GitHub push.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$ROOT_DIR/scripts"
PAYLOAD_ARG=${1:-"scripts/logic_payload.md"}

if [ ! -f "$PAYLOAD_ARG" ]; then
    echo "❌ Error: Payload file '$PAYLOAD_ARG' not found."
    exit 1
fi

echo "--- L2LAAF RELAY v3.0 ---"
echo "📂 Project Root: $ROOT_DIR"

# 1. Run Patcher
echo "📡 Synchronizing local repository..."
cd "$ROOT_DIR"
cat "$PAYLOAD_ARG" | node "$SCRIPT_DIR/patcher.js"
if [ $? -ne 0 ]; then
    echo "❌ Local sync failed."
    exit 1
fi

# 2. Pre-flight check (NASA Standard)
echo "🔍 Pre-flight check: Validating Cloud Functions..."
cd "$ROOT_DIR/functions"
# Run tsc directly to verify logic integrity
./node_modules/.bin/tsc --noEmit
if [ $? -ne 0 ]; then
    echo "❌ FATAL: TypeScript validation failed. Bad code will not be pushed."
    exit 1
fi
echo "✅ Logic integrity verified."

# 3. Git Operations
cd "$ROOT_DIR"
COMMIT_MSG="evolution: baseline phase 36 stabilization"
if [ -f ".commit_msg.tmp" ]; then
    COMMIT_MSG=$(cat .commit_msg.tmp)
    rm .commit_msg.tmp
fi

echo "🚀 Pushing to GitHub: $COMMIT_MSG"
git add .
git commit -m "$COMMIT_MSG"
git push

echo "🏁 Local Relay complete. System is stable."