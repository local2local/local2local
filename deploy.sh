#!/bin/bash

# 1. Run Flutter Analyze and output to problems_list.txt
echo "Running flutter analyze..."
flutter analyze > problems_list.txt

# 2. Check if the output indicates issues
# If the file contains anything other than "No issues found!", it has problems
if ! grep -q "No issues found!" problems_list.txt; then
    echo "----------------------------------------------------"
    cat problems_list.txt
    echo "----------------------------------------------------"
    echo "Error: Fix outstanding problems before deploying."
    exit 1
fi

# 3. Prompt for commit message
echo "Analysis passed. Enter your commit message:"
read -r commit_message

# 4. Check if commit message is blank
if [ -z "$commit_message" ]; then
    echo "Error: No commit message. Deployment stopped."
    exit 1
fi

# 5. Git operations
git add .
git commit -m "$commit_message"
git push origin develop

# Clean up the temporary file on success
rm problems_list.txt

echo "Successfully pushed to develop branch."