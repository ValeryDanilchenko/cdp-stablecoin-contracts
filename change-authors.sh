#!/bin/bash

# Script to change all commit authors across all branches
# Run from project root: ./change-authors.sh

echo "?? Change All Commit Authors Script"
echo "=================================="

# Get new author details
read -p "New author name: " NEW_AUTHOR_NAME
read -p "New author email: " NEW_AUTHOR_EMAIL

echo ""
echo "Configuration:"
echo "  Author: $NEW_AUTHOR_NAME <$NEW_AUTHOR_EMAIL>"
echo ""

# Create backup
BACKUP_BRANCH="backup-authors-$(date +%Y%m%d-%H%M%S)"
echo "?? Creating backup: $BACKUP_BRANCH"
git branch "$BACKUP_BRANCH"

# Create filter script
FILTER_SCRIPT="author_filter.sh"
cat > "$FILTER_SCRIPT" << 'EOF'
#!/bin/bash
# Change all commit authors
EOF

# Add logic to change all authors
cat >> "$FILTER_SCRIPT" << EOF
export GIT_AUTHOR_NAME="$NEW_AUTHOR_NAME"
export GIT_AUTHOR_EMAIL="$NEW_AUTHOR_EMAIL"
export GIT_COMMITTER_NAME="$NEW_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$NEW_AUTHOR_EMAIL"
echo "Changed author to: $NEW_AUTHOR_NAME <$NEW_AUTHOR_EMAIL>"
EOF

chmod +x "$FILTER_SCRIPT"

echo "?? Changing all commit authors..."
echo "   This will rewrite the entire git history"
echo ""

# Apply to all branches
FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch -f --env-filter "source $(pwd)/$FILTER_SCRIPT" -- --all

# Cleanup
rm "$FILTER_SCRIPT"

echo ""
echo "? All commit authors changed!"
echo "?? New commit history:"
git log --oneline --graph --decorate -10

echo ""
echo "?? Backup: $BACKUP_BRANCH"
echo "   To restore: git reset --hard $BACKUP_BRANCH"
echo ""
echo "?? All commits now have author: $NEW_AUTHOR_NAME <$NEW_AUTHOR_EMAIL>"
