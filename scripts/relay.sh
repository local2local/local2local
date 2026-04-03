#!/bin/bash

# L2LAAF Relay v2.0 (Path Resolution & Context Fix)
# Orchestrates local sync and GitHub push.
# Usage: ./scripts/relay.sh <payload_file.md>

# Determine the absolute path to the project root
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$ROOT_DIR/scripts"

# Default to logic_payload.md in scripts folder if no argument provided
PAYLOAD_ARG=${1:-"scripts/logic_payload.md"}

# Resolve absolute path for the payload
if [[ "$PAYLOAD_ARG" = /* ]]; then
    PAYLOAD_PATH="$PAYLOAD_ARG"
else
    # Try relative to current dir, then relative to root
    if [ -f "$PAYLOAD_ARG" ]; then
        PAYLOAD_PATH="$(pwd)/$PAYLOAD_ARG"
    elif [ -f "$ROOT_DIR/$PAYLOAD_ARG" ]; then
        PAYLOAD_PATH="$ROOT_DIR/$PAYLOAD_ARG"
    else
        echo "❌ Error: Payload file '$PAYLOAD_ARG' not found."
        exit 1
    fi
fi

echo "--- L2LAAF RELAY v2.0 ---"
echo "📂 Project Root: $ROOT_DIR"
echo "📄 Payload: $PAYLOAD_PATH"

# 1. Run Patcher to update local files
echo "📡 Synchronizing local repository..."
cd "$ROOT_DIR"
cat "$PAYLOAD_PATH" | node "$SCRIPT_DIR/patcher.js"
if [ $? -ne 0 ]; then
    echo "❌ Local sync failed."
    exit 1
fi

# 2. Extract Commit Message
COMMIT_MSG="evolution: baseline phase 36 stabilization"
if [ -f ".commit_msg.tmp" ]; then
    COMMIT_MSG=$(cat .commit_msg.tmp)
    rm .commit_msg.tmp
fi

# 3. Push to GitHub
echo "🚀 Pushing to GitHub: $COMMIT_MSG"
git add .
git commit -m "$COMMIT_MSG"
git push

echo "🏁 Local Relay complete. Check GitHub Actions for deployment status."