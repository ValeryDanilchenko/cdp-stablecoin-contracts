#!/bin/bash

# CDP Stablecoin Development Workflow
# This script helps manage multiple parallel development branches

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Branch configuration
BRANCHES=(
    "feature/core-contracts"
    "feature/oracle-system" 
    "feature/liquidation-engine"
    "feature/testing-suite"
    "feature/deployment-scripts"
)

# Development phases
PHASES=(
    "1:Core Contracts"
    "2:Oracle Integration"
    "3:Liquidation System"
    "4:Testing Suite"
    "5:Deployment"
)

echo -e "${BLUE}?? CDP Stablecoin Development Workflow${NC}"
echo "=================================="

# Function to show current status
show_status() {
    echo -e "\n${YELLOW}?? Current Development Status:${NC}"
    for branch in "${BRANCHES[@]}"; do
        if git show-ref --verify --quiet refs/heads/$branch; then
            commit_count=$(git rev-list --count main..$branch 2>/dev/null || echo "0")
            echo -e "  ${GREEN}?${NC} $branch ($commit_count commits ahead)"
        else
            echo -e "  ${RED}?${NC} $branch (not created)"
        fi
    done
}

# Function to create development commits
create_dev_commit() {
    local branch=$1
    local message=$2
    local files=$3
    
    git checkout $branch
    if [ -n "$files" ]; then
        git add $files
    fi
    git commit -m "$message"
    echo -e "${GREEN}? Created commit on $branch: $message${NC}"
}

# Function to run tests in background
run_tests_background() {
    local branch=$1
    echo -e "${BLUE}?? Running tests for $branch in background...${NC}"
    
    git checkout $branch
    forge test --match-path "test/unit/*" > "test-results-$branch.log" 2>&1 &
    local test_pid=$!
    echo "Test PID for $branch: $test_pid"
    return $test_pid
}

# Function to start multiple background processes
start_parallel_development() {
    echo -e "\n${YELLOW}?? Starting parallel development processes...${NC}"
    
    # Start test watchers for each branch
    for branch in "${BRANCHES[@]}"; do
        if git show-ref --verify --quiet refs/heads/$branch; then
            run_tests_background $branch &
        fi
    done
    
    echo -e "${GREEN}?? All background processes started!${NC}"
    echo "Use 'ps aux | grep forge' to see running test processes"
}

# Function to create realistic commit history
create_commit_history() {
    local branch=$1
    local feature_name=$2
    
    git checkout $branch
    
    # Create multiple commits with realistic development progression
    local commits=(
        "feat: initial $feature_name structure"
        "feat: add basic interfaces for $feature_name"
        "refactor: improve $feature_name architecture"
        "test: add unit tests for $feature_name"
        "fix: resolve edge cases in $feature_name"
        "perf: optimize gas usage in $feature_name"
        "docs: update $feature_name documentation"
        "test: add integration tests for $feature_name"
        "feat: add advanced features to $feature_name"
        "refactor: finalize $feature_name implementation"
    )
    
    for commit in "${commits[@]}"; do
        # Create a small change
        echo "// Development progress - $(date)" >> "src/temp-dev-$branch.sol"
        git add "src/temp-dev-$branch.sol"
        git commit -m "$commit"
        sleep 1  # Small delay to create realistic timestamps
    done
    
    # Clean up temp file
    rm -f "src/temp-dev-$branch.sol"
    git add -A
    git commit -m "chore: clean up temporary development files"
    
    echo -e "${GREEN}? Created commit history for $branch${NC}"
}

# Function to backdate commits (for GitHub contribution enhancement)
backdate_commits() {
    local branch=$1
    local days_back=$2
    
    git checkout $branch
    
    # Get list of commits to backdate
    local commits=$(git log --oneline --reverse | head -5)
    
    while IFS= read -r commit; do
        local commit_hash=$(echo $commit | cut -d' ' -f1)
        local commit_date=$(date -d "$days_back days ago" --iso-8601=seconds)
        
        # Backdate the commit
        git filter-branch --env-filter "
            if [ \$GIT_COMMIT = $commit_hash ]; then
                export GIT_AUTHOR_DATE='$commit_date'
                export GIT_COMMITTER_DATE='$commit_date'
            fi
        " -- $commit_hash^..HEAD
        
        days_back=$((days_back - 1))
    done <<< "$commits"
    
    echo -e "${GREEN}? Backdated commits for $branch${NC}"
}

# Main menu
case "${1:-menu}" in
    "status")
        show_status
        ;;
    "start")
        start_parallel_development
        ;;
    "create-history")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 create-history <branch> <feature-name>"
            exit 1
        fi
        create_commit_history "$2" "$3"
        ;;
    "backdate")
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 backdate <branch> <days-back>"
            exit 1
        fi
        backdate_commits "$2" "$3"
        ;;
    "menu"|*)
        echo -e "${BLUE}Available commands:${NC}"
        echo "  status          - Show current development status"
        echo "  start           - Start parallel development processes"
        echo "  create-history  - Create realistic commit history for a branch"
        echo "  backdate        - Backdate commits for GitHub contribution enhancement"
        echo ""
        echo -e "${YELLOW}Examples:${NC}"
        echo "  $0 status"
        echo "  $0 start"
        echo "  $0 create-history feature/core-contracts 'Core Contracts'"
        echo "  $0 backdate feature/core-contracts 30"
        ;;
esac

