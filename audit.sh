#!/bin/bash

# L2LAAF Audit Bundler v1.0
# This script finds changed files and bundles them for the Architect's review.

OUTPUT_FILE="audit_bundle.txt"
> $OUTPUT_FILE

echo "--- START OF AUDIT BUNDLE ---" >> $OUTPUT_FILE

# 1. Identify files changed in the last commit or currently staged
# We look for .ts, .dart, .yaml, and .md files
FILES=$(git diff --name-only HEAD~1 HEAD | grep -E '\.(ts|dart|yaml|md|json)$')

if [ -z "$FILES" ]; then
    echo "No recent changes detected in git. Grabbing all logic files instead..."
    FILES=$(find functions/src/logic -name "*.ts")
fi

for FILE in $FILES; do
    if [ -f "$FILE" ]; then
        TITLE=$(basename "$FILE")
        echo "Processing: $FILE"
        echo "### FILE: $FILE" >> $OUTPUT_FILE
        echo "\`\`\`typescript:$TITLE:$FILE" >> $OUTPUT_FILE
        cat "$FILE" >> $OUTPUT_FILE
        echo "" >> $OUTPUT_FILE
        echo "\`\`\`eof" >> $OUTPUT_FILE
        echo "" >> $OUTPUT_FILE
    fi
done

echo "--- END OF AUDIT BUNDLE ---" >> $OUTPUT_FILE

# 2. Copy to Clipboard (Mac only)
cat $OUTPUT_FILE | pbcopy

echo "Success! Audit bundle created and copied to your clipboard."
echo "You can now paste it directly into the chat."