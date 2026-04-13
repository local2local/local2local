#!/bin/bash
# --- L2LAAF RELAY v4.1 (Phase 37.5.3 Optimized) ---
# Target: logic_payload.txt
# Deployment: Automated validation (TS + Flutter) -> Git Commit -> Push.

# Point to the TXT payload version for Cursor compatibility
PAYLOAD_FILE="./scripts/logic_payload.txt"

if [ ! -f "$PAYLOAD_FILE" ]; then
    echo "❌ FATAL: Payload file not found at $PAYLOAD_FILE"
    exit 1
fi

echo "--- L2LAAF RELAY v4.1 ---"
echo "📂 Project Root: $(pwd)"
echo "📡 Using Payload: $PAYLOAD_FILE"

# 1. RUN PATCHER
node ./scripts/patcher.js < "$PAYLOAD_FILE"

if [ $? -eq 0 ]; then
    # 2. RUN TSC VALIDATION (Cloud Functions)
    echo "🔍 Pre-flight check [1/2]: Validating Cloud Functions..."
    cd functions && npm run build
    if [ $? -ne 0 ]; then
        echo "❌ FATAL: TypeScript validation failed. Bad code will not be pushed."
        exit 1
    fi
    cd ..
    echo "🟢 SUCCESS: Cloud Functions Validated."

    # 3. RUN FLUTTER ANALYSIS (Web App)
    echo "🔍 Pre-flight check [2/2]: Analyzing Flutter Code..."
    flutter analyze > problems_list.txt 2>&1
    
    # Check for 'error' strings in the output
    if grep -q "error •" problems_list.txt; then
        echo "❌ FATAL: Flutter Lint/Analysis found errors. See problems_list.txt."
        exit 1
    else
        echo "🟢 SUCCESS: Flutter Analysis Passed."
        [ -f problems_list.txt ] && rm problems_list.txt
    fi

    # 4. GITHUB DEPLOYMENT SEQUENCE
    echo "🚀 Initializing Deployment to GitHub..."
    if [ -f "COMMIT_MSG" ]; then
        MSG=$(cat COMMIT_MSG)
        git add .
        git commit -m "$MSG"
        
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
        echo "📡 Pushing to origin/$CURRENT_BRANCH..."
        git push origin "$CURRENT_BRANCH"
        
        if [ $? -eq 0 ]; then
            echo "🎉 DEPLOYMENT COMPLETE: Stack stabilized and pushed."
            rm COMMIT_MSG
        else
            echo "❌ FATAL: Push failed."
            exit 1
        fi
    else
        echo "⚠️  WARNING: COMMIT_MSG file not found. Skipping git push."
    fi
else
    echo "❌ FATAL: Patching failed."
    exit 1
fi