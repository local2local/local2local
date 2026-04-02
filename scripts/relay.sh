#!/bin/bash

# L2LAAF Relay v1.9 (GitHub Actions Integration)
# Orchestrates local sync and GitHub push to trigger deployment.
# Usage: ./scripts/relay.sh <payload_file.md>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD=${1:-"logic_payload.md"}

if [ ! -f "$PAYLOAD" ]; then
    echo "❌ Error: Payload file '$PAYLOAD' not found."
    exit 1
fi

echo "--- L2LAAF RELAY v1.9 (CI/CD MODE) ---"

# 1. Run Patcher to update local files
echo "📡 Synchronizing local repository..."
cat "$PAYLOAD" | node "$SCRIPT_DIR/patcher.js"
if [ $? -ne 0 ]; then
    echo "❌ Local sync failed."
    exit 1
fi

# 2. Extract Commit Message
COMMIT_MSG="evolution: update guided autonomy logic"
if [ -f ".commit_msg.tmp" ]; then
    COMMIT_MSG=$(cat .commit_msg.tmp)
    rm .commit_msg.tmp
fi

# 3. Push to GitHub to trigger deploy.yml
echo "🚀 Pushing to GitHub: $COMMIT_MSG"
git add .
git commit -m "$COMMIT_MSG"
git push

echo "🏁 Local Relay complete. Check GitHub Actions for deployment status."