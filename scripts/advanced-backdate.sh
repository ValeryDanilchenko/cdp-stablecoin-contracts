#!/bin/bash

# CDP Stablecoin Project - Advanced Commit Backdating Script
# This script provides flexible backdating with realistic development patterns

set -e

# Default configuration
DEFAULT_START_DATE="2025-01-01"
DEFAULT_END_DATE="2025-03-31"
DEFAULT_AUTHOR_NAME="Valery Developer"
DEFAULT_AUTHOR_EMAIL="valery@example.com"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${PURPLE}?? CDP Stablecoin Project - Advanced Commit Backdating Script${NC}"
echo -e "${PURPLE}============================================================${NC}"
echo ""

# Function to get user input with default
get_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    read -p "$prompt [$default]: " input
    if [ -z "$input" ]; then
        eval "$var_name='$default'"
    else
        eval "$var_name='$input'"
    fi
}

# Get configuration from user
echo -e "${CYAN}?? Configuration Setup${NC}"
echo "========================"
get_input "Project start date (YYYY-MM-DD)" "$DEFAULT_START_DATE" START_DATE
get_input "Project end date (YYYY-MM-DD)" "$DEFAULT_END_DATE" END_DATE
get_input "Author name" "$DEFAULT_AUTHOR_NAME" AUTHOR_NAME
get_input "Author email" "$DEFAULT_AUTHOR_EMAIL" AUTHOR_EMAIL

echo ""
echo -e "${GREEN}? Configuration:${NC}"
echo "  Start Date: $START_DATE"
echo "  End Date: $END_DATE"
echo "  Author: $AUTHOR_NAME <$AUTHOR_EMAIL>"
echo ""

# Validate dates
START_TIMESTAMP=$(date -d "$START_DATE" +%s 2>/dev/null || echo "")
END_TIMESTAMP=$(date -d "$END_DATE" +%s 2>/dev/null || echo "")

if [ -z "$START_TIMESTAMP" ] || [ -z "$END_TIMESTAMP" ]; then
    echo -e "${RED}? Invalid date format! Please use YYYY-MM-DD${NC}"
    exit 1
fi

if [ "$START_TIMESTAMP" -ge "$END_TIMESTAMP" ]; then
    echo -e "${RED}? End date must be after start date!${NC}"
    exit 1
fi

# Get all commits
echo -e "${CYAN}?? Getting commit history...${NC}"
COMMITS=($(git log --oneline --reverse | awk '{print $1}'))

if [ ${#COMMITS[@]} -eq 0 ]; then
    echo -e "${RED}? No commits found!${NC}"
    exit 1
fi

echo -e "${GREEN}Found ${#COMMITS[@]} commits to backdate${NC}"
echo ""

# Calculate realistic time distribution
TOTAL_SECONDS=$((END_TIMESTAMP - START_TIMESTAMP))
TOTAL_DAYS=$((TOTAL_SECONDS / 86400))

echo -e "${YELLOW}? Time Distribution Analysis${NC}"
echo "=============================="
echo "Total duration: $TOTAL_DAYS days"
echo ""

# Create development phases
PHASE1_DAYS=$((TOTAL_DAYS / 4))  # Initial setup and core contracts
PHASE2_DAYS=$((TOTAL_DAYS / 2))  # Main development and testing
PHASE3_DAYS=$((TOTAL_DAYS / 4))  # Final testing and fixes

echo "Development phases:"
echo "  Phase 1 (Setup): $PHASE1_DAYS days - Core contracts and basic tests"
echo "  Phase 2 (Development): $PHASE2_DAYS days - Main features and comprehensive tests"
echo "  Phase 3 (Finalization): $PHASE3_DAYS days - Bug fixes and optimization"
echo ""

# Calculate commit distribution
PHASE1_COMMITS=$(((${#COMMITS[@]} * PHASE1_DAYS) / TOTAL_DAYS))
PHASE2_COMMITS=$(((${#COMMITS[@]} * PHASE2_DAYS) / TOTAL_DAYS))
PHASE3_COMMITS=$((${#COMMITS[@]} - PHASE1_COMMITS - PHASE2_COMMITS))

echo "Commit distribution:"
echo "  Phase 1: $PHASE1_COMMITS commits"
echo "  Phase 2: $PHASE2_COMMITS commits"
echo "  Phase 3: $PHASE3_COMMITS commits"
echo ""

# Create temporary branch
TEMP_BRANCH="backdate-advanced-$(date +%s)"
echo -e "${CYAN}?? Creating temporary branch: $TEMP_BRANCH${NC}"
git checkout -b "$TEMP_BRANCH"

# Function to add realistic commit time variation
add_time_variation() {
    local base_timestamp=$1
    local variation_hours=$((RANDOM % 8))  # 0-8 hours variation
    local variation_minutes=$((RANDOM % 60))  # 0-60 minutes variation
    local variation_seconds=$((RANDOM % 60))  # 0-60 seconds variation
    
    echo $((base_timestamp + variation_hours * 3600 + variation_minutes * 60 + variation_seconds))
}

# Backdate commits with realistic distribution
echo -e "${CYAN}?? Backdating commits...${NC}"
echo "=========================="

# Phase 1: Initial setup (more frequent commits)
PHASE1_END_TIMESTAMP=$((START_TIMESTAMP + PHASE1_DAYS * 86400))
for i in $(seq 0 $((PHASE1_COMMITS - 1))); do
    COMMIT_HASH="${COMMITS[$i]}"
    COMMIT_TIMESTAMP=$(add_time_variation $((START_TIMESTAMP + (i * 86400 * 2))))
    COMMIT_DATE=$(date -d "@$COMMIT_TIMESTAMP" "+%Y-%m-%d %H:%M:%S")
    
    echo -e "${BLUE}Phase 1 - Commit $((i + 1))/$PHASE1_COMMITS: $COMMIT_HASH${NC}"
    echo "   Date: $COMMIT_DATE"
    
    git cherry-pick "$COMMIT_HASH" --no-commit
    git commit --amend --date="$COMMIT_DATE" --author="$AUTHOR_NAME <$AUTHOR_EMAIL>" --no-edit
done

# Phase 2: Main development (regular intervals)
PHASE2_START_TIMESTAMP=$PHASE1_END_TIMESTAMP
PHASE2_END_TIMESTAMP=$((PHASE2_START_TIMESTAMP + PHASE2_DAYS * 86400))
for i in $(seq $PHASE1_COMMITS $((PHASE1_COMMITS + PHASE2_COMMITS - 1))); do
    COMMIT_HASH="${COMMITS[$i]}"
    PHASE_INDEX=$((i - PHASE1_COMMITS))
    COMMIT_TIMESTAMP=$(add_time_variation $((PHASE2_START_TIMESTAMP + (PHASE_INDEX * 86400))))
    COMMIT_DATE=$(date -d "@$COMMIT_TIMESTAMP" "+%Y-%m-%d %H:%M:%S")
    
    echo -e "${GREEN}Phase 2 - Commit $((PHASE_INDEX + 1))/$PHASE2_COMMITS: $COMMIT_HASH${NC}"
    echo "   Date: $COMMIT_DATE"
    
    git cherry-pick "$COMMIT_HASH" --no-commit
    git commit --amend --date="$COMMIT_DATE" --author="$AUTHOR_NAME <$AUTHOR_EMAIL>" --no-edit
done

# Phase 3: Finalization (more frequent commits)
PHASE3_START_TIMESTAMP=$PHASE2_END_TIMESTAMP
for i in $(seq $((PHASE1_COMMITS + PHASE2_COMMITS)) $((${#COMMITS[@]} - 1))); do
    COMMIT_HASH="${COMMITS[$i]}"
    PHASE_INDEX=$((i - PHASE1_COMMITS - PHASE2_COMMITS))
    COMMIT_TIMESTAMP=$(add_time_variation $((PHASE3_START_TIMESTAMP + (PHASE_INDEX * 43200))))  # Every 12 hours
    COMMIT_DATE=$(date -d "@$COMMIT_TIMESTAMP" "+%Y-%m-%d %H:%M:%S")
    
    echo -e "${YELLOW}Phase 3 - Commit $((PHASE_INDEX + 1))/$PHASE3_COMMITS: $COMMIT_HASH${NC}"
    echo "   Date: $COMMIT_DATE"
    
    git cherry-pick "$COMMIT_HASH" --no-commit
    git commit --amend --date="$COMMIT_DATE" --author="$AUTHOR_NAME <$AUTHOR_EMAIL>" --no-edit
done

echo ""
echo -e "${GREEN}?? All commits have been backdated with realistic development patterns!${NC}"
echo ""

# Show timeline
echo -e "${CYAN}?? New Development Timeline:${NC}"
echo "=============================="
git log --oneline --graph --decorate -15

echo ""
echo -e "${PURPLE}?? Next Steps:${NC}"
echo "============="
echo "1. Review the timeline above"
echo "2. If satisfied, run:"
echo "   git checkout feature/comprehensive-testing"
echo "   git reset --hard $TEMP_BRANCH"
echo "   git branch -D $TEMP_BRANCH"
echo ""
echo "3. If you want to modify the timeline, edit this script and run again"
echo ""

# Ask for confirmation
read -p "Do you want to apply the backdated commits to the main branch? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}?? Applying backdated commits...${NC}"
    git checkout feature/comprehensive-testing
    git reset --hard "$TEMP_BRANCH"
    git branch -D "$TEMP_BRANCH"
    echo -e "${GREEN}? Backdating complete!${NC}"
    echo ""
    echo -e "${CYAN}?? Final Timeline:${NC}"
    git log --oneline --graph --decorate -10
else
    echo -e "${YELLOW}? Backdating cancelled. Temporary branch '$TEMP_BRANCH' preserved.${NC}"
    echo "   You can manually merge it later if needed."
fi

echo ""
echo -e "${PURPLE}?? CDP Stablecoin Project - Development Timeline Complete!${NC}"
echo "   Project successfully backdated to simulate realistic development"
echo "   from $START_DATE to $END_DATE"
echo ""
echo -e "${GREEN}?? Development Statistics:${NC}"
echo "   Total commits: ${#COMMITS[@]}"
echo "   Development period: $TOTAL_DAYS days"
echo "   Average commits per day: $(echo "scale=2; ${#COMMITS[@]} / $TOTAL_DAYS" | bc)"
echo "   Author: $AUTHOR_NAME <$AUTHOR_EMAIL>"
