#!/bin/bash

# L2LAAF Audit Bundler v1.1
# This script finds changed files or grabs the core Logic & UI structure.

OUTPUT_FILE="audit_bundle.txt"
> $OUTPUT_FILE

echo "--- START OF AUDIT BUNDLE ---" >> $OUTPUT_FILE

# 1. Identify files changed in the last commit or currently staged
FILES=$(git diff --name-only HEAD~1 HEAD | grep -E '\.(ts|dart|yaml|md|json)$')

if [ -z "$FILES" ]; then
    echo "No recent git changes. Grabbing Logic (TS) & UI (Dart) structure..."
    # Grab backend logic
    FILES_TS=$(find functions/src/logic -name "*.ts")
    # Grab frontend lib structure
    FILES_DART=$(find lib -name "*.dart" 2>/dev/null)
    # Grab core configs
    FILES_CFG=$(find . -maxdepth 1 -name "pubspec.yaml" -o -name "architecture.md")
    
    FILES="$FILES_TS $FILES_DART $FILES_CFG"
fi

for FILE in $FILES; do
    if [ -f "$FILE" ]; then
        TITLE=$(basename "$FILE")
        # Determine language for markdown block
        EXT="${FILE##*.}"
        LANG="typescript"
        case "$EXT" in
            dart) LANG="dart" ;;
            yaml) LANG="yaml" ;;
            md)   LANG="markdown" ;;
            json) LANG="json" ;;
            ts)   LANG="typescript" ;;
        esac

        echo "Processing: $FILE"
        echo "### FILE: $FILE" >> $OUTPUT_FILE
        echo "\`\`\`$LANG:$TITLE:$FILE" >> $OUTPUT_FILE
        cat "$FILE" >> $OUTPUT_FILE
        echo "" >> $OUTPUT_FILE
        echo "\`\`\`eof" >> $OUTPUT_FILE
        echo "" >> $OUTPUT_FILE
    fi
done

echo "--- END OF AUDIT BUNDLE ---" >> $OUTPUT_FILE

# 2. Copy to Clipboard (Mac only)
if command -v pbcopy > /dev/null; then
    cat $OUTPUT_FILE | pbcopy
    echo "Success! Audit bundle created and copied to your clipboard."
else
    echo "Success! Audit bundle created in $OUTPUT_FILE."
fi