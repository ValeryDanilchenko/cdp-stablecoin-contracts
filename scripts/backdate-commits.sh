#!/bin/bash

# CDP Stablecoin Project - Commit Backdating Script
# This script backdates commits to simulate 3 months of development work
# Starting from January 1, 2025 and ending around March 31, 2025

set -e

# Configuration
PROJECT_START_DATE="2025-01-01"
PROJECT_END_DATE="2025-03-31"
AUTHOR_NAME="Valery Developer"
AUTHOR_EMAIL="valery@example.com"

# Convert dates to timestamps
START_TIMESTAMP=$(date -d "$PROJECT_START_DATE" +%s)
END_TIMESTAMP=$(date -d "$PROJECT_END_DATE" +%s)

echo "?? CDP Stablecoin Project - Commit Backdating Script"
echo "=================================================="
echo "Project Start: $PROJECT_START_DATE"
echo "Project End: $PROJECT_END_DATE"
echo "Author: $AUTHOR_NAME <$AUTHOR_EMAIL>"
echo ""

# Get all commits in reverse order (oldest first)
echo "?? Getting commit history..."
COMMITS=($(git log --oneline --reverse | awk '{print $1}'))

if [ ${#COMMITS[@]} -eq 0 ]; then
    echo "? No commits found!"
    exit 1
fi

echo "Found ${#COMMITS[@]} commits to backdate"
echo ""

# Calculate time intervals
TOTAL_SECONDS=$((END_TIMESTAMP - START_TIMESTAMP))
INTERVAL_SECONDS=$((TOTAL_SECONDS / (${#COMMITS[@]} - 1)))

echo "? Time distribution:"
echo "  Total duration: $((TOTAL_SECONDS / 86400)) days"
echo "  Interval between commits: $((INTERVAL_SECONDS / 3600)) hours"
echo ""

# Create a temporary branch for backdating
TEMP_BRANCH="backdate-temp-$(date +%s)"
echo "?? Creating temporary branch: $TEMP_BRANCH"
git checkout -b "$TEMP_BRANCH"

# Backdate each commit
for i in "${!COMMITS[@]}"; do
    COMMIT_HASH="${COMMITS[$i]}"
    
    # Calculate timestamp for this commit
    COMMIT_TIMESTAMP=$((START_TIMESTAMP + (i * INTERVAL_SECONDS)))
    COMMIT_DATE=$(date -d "@$COMMIT_TIMESTAMP" "+%Y-%m-%d %H:%M:%S")
    
    echo "?? Processing commit $((i + 1))/${#COMMITS[@]}: $COMMIT_HASH"
    echo "   Date: $COMMIT_DATE"
    
    # Cherry-pick the commit
    git cherry-pick "$COMMIT_HASH" --no-commit
    
    # Amend the commit with new date and author
    git commit --amend \
        --date="$COMMIT_DATE" \
        --author="$AUTHOR_NAME <$AUTHOR_EMAIL>" \
        --no-edit
    
    echo "   ? Backdated to: $COMMIT_DATE"
    echo ""
done

echo "?? All commits have been backdated!"
echo ""

# Show the new timeline
echo "?? New commit timeline:"
git log --oneline --graph --decorate -10

echo ""
echo "?? To apply these changes to your main branch:"
echo "   1. git checkout feature/comprehensive-testing"
echo "   2. git reset --hard $TEMP_BRANCH"
echo "   3. git branch -D $TEMP_BRANCH"
echo ""
echo "??  WARNING: This will rewrite commit history!"
echo "   Make sure to backup your repository before proceeding."
echo ""

# Ask for confirmation
read -p "Do you want to apply the backdated commits to the main branch? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "?? Applying backdated commits..."
    git checkout feature/comprehensive-testing
    git reset --hard "$TEMP_BRANCH"
    git branch -D "$TEMP_BRANCH"
    echo "? Backdating complete!"
    echo ""
    echo "?? Final timeline:"
    git log --oneline --graph --decorate -10
else
    echo "? Backdating cancelled. Temporary branch '$TEMP_BRANCH' preserved."
    echo "   You can manually merge it later if needed."
fi

echo ""
echo "?? CDP Stablecoin Project - Development Timeline Complete!"
echo "   Project successfully backdated to simulate 3 months of development"
echo "   from $PROJECT_START_DATE to $PROJECT_END_DATE"
