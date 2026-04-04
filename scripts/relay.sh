#!/bin/bash
# --- L2LAAF RELAY v3.5 ---
# Fix: Redirects payload file into stdin to prevent hanging.
# Deployment: Automatically commits and pushes to GitHub after validation.

PAYLOAD_FILE="./scripts/logic_payload.js"

if [ ! -f "$PAYLOAD_FILE" ]; then
    # Fallback chain
    if [ -f "./scripts/logic_payload.txt" ]; then
        PAYLOAD_FILE="./scripts/logic_payload.txt"
    else
        PAYLOAD_FILE="./scripts/logic_payload.md"
    fi
fi

echo "--- L2LAAF RELAY v3.5 ---"
echo "📂 Project Root: $(pwd)"
echo "📡 Using Payload: $PAYLOAD_FILE"

# 1. RUN PATCHER
# REDIRECTION: < "$PAYLOAD_FILE" feeds content to fs.readFileSync(0)
node ./scripts/patcher.js < "$PAYLOAD_FILE"

if [ $? -eq 0 ]; then
    # 2. RUN TSC VALIDATION
    echo "🔍 Pre-flight check: Validating Cloud Functions..."
    cd functions && npm run build
    if [ $? -eq 0 ]; then
        echo "🟢 SUCCESS: TSC Validation Passed."
        cd ..
        
        # 3. GITHUB DEPLOYMENT SEQUENCE
        echo "🚀 Initializing Deployment to GitHub..."
        
        # Check if commit message file was generated
        if [ -f "COMMIT_MSG" ]; then
            MSG=$(cat COMMIT_MSG)
            git add .
            git commit -m "$MSG"
            
            # Detect current branch
            CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
            echo "📡 Pushing to origin/$CURRENT_BRANCH..."
            git push origin "$CURRENT_BRANCH"
            
            if [ $? -eq 0 ]; then
                echo "🎉 DEPLOYMENT COMPLETE: Evolution stabilized and pushed."
                # Cleanup temporary commit file
                rm COMMIT_MSG
            else
                echo "❌ FATAL: Push failed. Check your internet connection or permissions."
                exit 1
            fi
        else
            echo "⚠️  WARNING: COMMIT_MSG file not found. Skipping git push."
        fi
    else
        echo "❌ FATAL: TypeScript validation failed. Bad code will not be pushed."
        exit 1
    fi
else
    echo "❌ FATAL: Patching failed."
    exit 1
fi