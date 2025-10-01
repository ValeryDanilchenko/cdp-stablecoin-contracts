#!/bin/bash

# Final working backdating script for macOS
# This script creates a realistic development timeline

set -e

# Configuration
START_DATE="2025-01-01"
END_DATE="2025-03-31"
AUTHOR_NAME="Valery Developer"
AUTHOR_EMAIL="valery@example.com"

echo "?? CDP Stablecoin Project - Final Backdating Script"
echo "=================================================="
echo "Project Start: $START_DATE"
echo "Project End: $END_DATE"
echo "Author: $AUTHOR_NAME <$AUTHOR_EMAIL>"
echo ""

# Convert dates to timestamps (macOS compatible)
START_TIMESTAMP=$(date -j -f "%Y-%m-%d" "$START_DATE" +%s)
END_TIMESTAMP=$(date -j -f "%Y-%m-%d" "$END_DATE" +%s)

# Get all commits from all branches
echo "?? Getting commit history..."
COMMITS=($(git log --oneline --all --reverse | awk '{print $1}'))

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

# Create backup
BACKUP_BRANCH="backup-$(date +%Y%m%d-%H%M%S)"
echo "?? Creating backup branch: $BACKUP_BRANCH"
git branch "$BACKUP_BRANCH"

echo ""
echo "?? Starting backdating process..."
echo "   This will rewrite commit history with new dates"
echo ""

# Create the filter script
FILTER_SCRIPT="filter_script.sh"
cat > "$FILTER_SCRIPT" << 'EOF'
#!/bin/bash
# Auto-generated filter script for git filter-branch

EOF

# Add filter logic for each commit
for i in "${!COMMITS[@]}"; do
    COMMIT_HASH="${COMMITS[$i]}"
    COMMIT_TIMESTAMP=$((START_TIMESTAMP + (i * INTERVAL_SECONDS)))
    COMMIT_DATE=$(date -r "$COMMIT_TIMESTAMP" "+%Y-%m-%d %H:%M:%S")
    
    echo "?? Commit $((i + 1))/${#COMMITS[@]}: $COMMIT_HASH -> $COMMIT_DATE"
    
    # Add to filter script
    cat >> "$FILTER_SCRIPT" << EOF
if [ "\$GIT_COMMIT" = "$COMMIT_HASH" ]; then
    export GIT_AUTHOR_DATE="$COMMIT_DATE"
    export GIT_COMMITTER_DATE="$COMMIT_DATE"
    export GIT_AUTHOR_NAME="$AUTHOR_NAME"
    export GIT_AUTHOR_EMAIL="$AUTHOR_EMAIL"
    export GIT_COMMITTER_NAME="$AUTHOR_NAME"
    export GIT_COMMITTER_EMAIL="$AUTHOR_EMAIL"
fi
EOF
done

chmod +x "$FILTER_SCRIPT"

echo ""
echo "?? Applying date changes to all commits..."
echo "   This may take a few minutes..."

# Apply the filter to all branches
git filter-branch -f --env-filter "source $(pwd)/$FILTER_SCRIPT" -- --all

# Clean up
rm "$FILTER_SCRIPT"

echo ""
echo "?? Commit history has been successfully backdated!"
echo ""

# Show the new timeline
echo "?? New Development Timeline:"
git log --oneline --graph --decorate -15

echo ""
echo "?? Development Statistics:"
echo "   Total commits: ${#COMMITS[@]}"
echo "   Development period: $((TOTAL_SECONDS / 86400)) days"
echo "   Average commits per day: $(echo "scale=2; ${#COMMITS[@]} / $((TOTAL_SECONDS / 86400))" | bc)"
echo "   Author: $AUTHOR_NAME <$AUTHOR_EMAIL>"
echo ""

echo "? Backdating Complete!"
echo ""
echo "?? Backup branch created: $BACKUP_BRANCH"
echo "   If you need to restore: git reset --hard $BACKUP_BRANCH"
echo ""
echo "?? Your CDP stablecoin project now has a realistic 3-month development timeline!"
echo "   Perfect for showcasing your development skills and GitHub contributions!"
