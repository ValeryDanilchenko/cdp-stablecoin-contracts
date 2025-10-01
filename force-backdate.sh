#!/bin/bash

# Force commit backdating script
# Run from project root: ./force-backdate.sh

echo "?? Force Commit Backdating Script"
echo "================================="

# Get user input
read -p "Start date (YYYY-MM-DD): " START_DATE
read -p "End date (YYYY-MM-DD): " END_DATE
read -p "Author name: " AUTHOR_NAME
read -p "Author email: " AUTHOR_EMAIL

echo ""
echo "Configuration:"
echo "  Start: $START_DATE"
echo "  End: $END_DATE"
echo "  Author: $AUTHOR_NAME <$AUTHOR_EMAIL>"
echo ""

# Convert dates to timestamps (macOS)
START_TIMESTAMP=$(date -j -f "%Y-%m-%d" "$START_DATE" +%s)
END_TIMESTAMP=$(date -j -f "%Y-%m-%d" "$END_DATE" +%s)

# Get all commits
COMMITS=($(git log --oneline --all --reverse | awk '{print $1}'))
TOTAL_SECONDS=$((END_TIMESTAMP - START_TIMESTAMP))
INTERVAL_SECONDS=$((TOTAL_SECONDS / (${#COMMITS[@]} - 1)))

echo "Found ${#COMMITS[@]} commits"
echo "Interval: $((INTERVAL_SECONDS / 3600)) hours between commits"
echo ""

# Create backup
BACKUP_BRANCH="backup-$(date +%Y%m%d-%H%M%S)"
echo "?? Creating backup: $BACKUP_BRANCH"
git branch "$BACKUP_BRANCH"

# Create filter script that ALWAYS changes dates
FILTER_SCRIPT="force_filter.sh"
cat > "$FILTER_SCRIPT" << EOF
#!/bin/bash
# Force change all commits

EOF

# Add logic for each commit
for i in "${!COMMITS[@]}"; do
    COMMIT_HASH="${COMMITS[$i]}"
    COMMIT_TIMESTAMP=$((START_TIMESTAMP + (i * INTERVAL_SECONDS)))
    COMMIT_DATE=$(date -r "$COMMIT_TIMESTAMP" "+%Y-%m-%d %H:%M:%S")
    
    echo "Commit $((i + 1))/${#COMMITS[@]}: $COMMIT_HASH -> $COMMIT_DATE"
    
    cat >> "$FILTER_SCRIPT" << EOF
if [ "\$GIT_COMMIT" = "$COMMIT_HASH" ]; then
    export GIT_AUTHOR_DATE="$COMMIT_DATE"
    export GIT_COMMITTER_DATE="$COMMIT_DATE"
    export GIT_AUTHOR_NAME="$AUTHOR_NAME"
    export GIT_AUTHOR_EMAIL="$AUTHOR_EMAIL"
    export GIT_COMMITTER_NAME="$AUTHOR_NAME"
    export GIT_COMMITTER_EMAIL="$AUTHOR_EMAIL"
    echo "Changed commit \$GIT_COMMIT to $COMMIT_DATE"
fi
EOF
done

chmod +x "$FILTER_SCRIPT"

echo ""
echo "?? Force applying changes..."
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --env-filter "source $(pwd)/$FILTER_SCRIPT" -- --all

# Cleanup
rm "$FILTER_SCRIPT"

echo ""
echo "? Done!"
echo "?? New timeline:"
git log --oneline --graph --decorate -10

echo ""
echo "?? Backup: $BACKUP_BRANCH"
echo "   To restore: git reset --hard $BACKUP_BRANCH"
