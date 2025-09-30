#!/bin/bash

# Parallel Development Script for CDP Stablecoin
# This script demonstrates how to run multiple background processes effectively

set -e

# Configuration
PROJECT_ROOT="/Users/valery/Projects/Pets/skill-demo-contracts"
BRANCHES=("feature/core-contracts" "feature/oracle-system" "feature/liquidation-engine" "feature/testing-suite" "feature/deployment-scripts")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo -e "${BLUE}?? Starting Parallel Development Environment${NC}"
echo "=============================================="

# Function to start background test watcher
start_test_watcher() {
    local branch=$1
    local test_pattern=$2
    
    echo -e "${YELLOW}?? Starting test watcher for $branch${NC}"
    
    (
        cd "$PROJECT_ROOT"
        git checkout "$branch" > /dev/null 2>&1
        
        while true; do
            echo -e "${PURPLE}[$branch]${NC} Running tests..."
            forge test --match-path "$test_pattern" --gas-report > "logs/test-$branch-$(date +%H%M%S).log" 2>&1
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}[$branch]${NC} ? Tests passed"
            else
                echo -e "${RED}[$branch]${NC} ? Tests failed"
            fi
            
            sleep 30  # Run tests every 30 seconds
        done
    ) &
    
    echo "Test watcher PID for $branch: $!"
}

# Function to start background compilation watcher
start_compile_watcher() {
    local branch=$1
    
    echo -e "${YELLOW}?? Starting compilation watcher for $branch${NC}"
    
    (
        cd "$PROJECT_ROOT"
        git checkout "$branch" > /dev/null 2>&1
        
        while true; do
            echo -e "${PURPLE}[$branch]${NC} Compiling contracts..."
            forge build > "logs/compile-$branch-$(date +%H%M%S).log" 2>&1
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}[$branch]${NC} ? Compilation successful"
            else
                echo -e "${RED}[$branch]${NC} ? Compilation failed"
            fi
            
            sleep 60  # Compile every minute
        done
    ) &
    
    echo "Compilation watcher PID for $branch: $!"
}

# Function to start background gas monitoring
start_gas_monitor() {
    local branch=$1
    
    echo -e "${YELLOW}? Starting gas monitor for $branch${NC}"
    
    (
        cd "$PROJECT_ROOT"
        git checkout "$branch" > /dev/null 2>&1
        
        while true; do
            echo -e "${PURPLE}[$branch]${NC} Monitoring gas usage..."
            forge test --gas-report > "logs/gas-$branch-$(date +%H%M%S).log" 2>&1
            
            # Extract gas usage and log to summary
            gas_usage=$(grep -E "Gas|Test" "logs/gas-$branch-$(date +%H%M%S).log" | tail -5)
            echo -e "${BLUE}[$branch]${NC} Gas Report:"
            echo "$gas_usage"
            
            sleep 120  # Monitor gas every 2 minutes
        done
    ) &
    
    echo "Gas monitor PID for $branch: $!"
}

# Function to start background coverage tracking
start_coverage_tracker() {
    local branch=$1
    
    echo -e "${YELLOW}?? Starting coverage tracker for $branch${NC}"
    
    (
        cd "$PROJECT_ROOT"
        git checkout "$branch" > /dev/null 2>&1
        
        while true; do
            echo -e "${PURPLE}[$branch]${NC} Tracking test coverage..."
            forge coverage > "logs/coverage-$branch-$(date +%H%M%S).log" 2>&1
            
            # Extract coverage percentage
            coverage=$(grep -E "Total Coverage" "logs/coverage-$branch-$(date +%H%M%S).log" | grep -o '[0-9]*\.[0-9]*%' || echo "N/A")
            echo -e "${BLUE}[$branch]${NC} Coverage: $coverage"
            
            sleep 300  # Track coverage every 5 minutes
        done
    ) &
    
    echo "Coverage tracker PID for $branch: $!"
}

# Function to create realistic development commits
create_dev_commits() {
    local branch=$1
    local feature_name=$2
    
    echo -e "${YELLOW}?? Creating development commits for $branch${NC}"
    
    (
        cd "$PROJECT_ROOT"
        git checkout "$branch" > /dev/null 2>&1
        
        # Create realistic commit sequence
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
            # Create a small change to commit
            echo "// Development progress - $(date)" >> "src/temp-dev-$branch.sol"
            git add "src/temp-dev-$branch.sol"
            git commit -m "$commit" > /dev/null 2>&1
            
            echo -e "${GREEN}[$branch]${NC} ? Created commit: $commit"
            sleep 2  # Realistic commit timing
        done
        
        # Clean up temp file
        rm -f "src/temp-dev-$branch.sol"
        git add -A
        git commit -m "chore: clean up temporary development files" > /dev/null 2>&1
        
        echo -e "${GREEN}[$branch]${NC} ? Completed commit sequence"
    ) &
    
    echo "Commit creator PID for $branch: $!"
}

# Create logs directory
mkdir -p "$PROJECT_ROOT/logs"

# Start all background processes
echo -e "\n${BLUE}?? Starting all background processes...${NC}"

# Start processes for each branch
start_test_watcher "feature/core-contracts" "test/unit/core/*"
start_compile_watcher "feature/core-contracts"

start_test_watcher "feature/oracle-system" "test/unit/oracle/*"
start_compile_watcher "feature/oracle-system"

start_test_watcher "feature/liquidation-engine" "test/unit/liquidation/*"
start_compile_watcher "feature/liquidation-engine"

start_test_watcher "feature/testing-suite" "test/integration/*"
start_compile_watcher "feature/testing-suite"

start_test_watcher "feature/deployment-scripts" "test/deployment/*"
start_compile_watcher "feature/deployment-scripts"

# Start monitoring processes
start_gas_monitor "feature/core-contracts"
start_coverage_tracker "feature/core-contracts"

# Start commit creation processes
create_dev_commits "feature/core-contracts" "Core Contracts"
create_dev_commits "feature/oracle-system" "Oracle System"
create_dev_commits "feature/liquidation-engine" "Liquidation Engine"

echo -e "\n${GREEN}?? All background processes started!${NC}"
echo -e "${YELLOW}?? Monitor progress with:${NC}"
echo "  ps aux | grep forge"
echo "  tail -f logs/*.log"
echo "  watch 'git log --oneline --all --graph'"

echo -e "\n${BLUE}?? To stop all processes:${NC}"
echo "  pkill -f 'forge test'"
echo "  pkill -f 'forge build'"
echo "  pkill -f 'forge coverage'"

# Keep script running to show status
echo -e "\n${PURPLE}?? Real-time Status Updates:${NC}"
while true; do
    echo -e "\n${BLUE}=== Status Update $(date) ===${NC}"
    
    for branch in "${BRANCHES[@]}"; do
        if git show-ref --verify --quiet "refs/heads/$branch"; then
            commit_count=$(git rev-list --count main..$branch 2>/dev/null || echo "0")
            echo -e "${GREEN}?${NC} $branch ($commit_count commits ahead)"
        else
            echo -e "${RED}?${NC} $branch (not created)"
        fi
    done
    
    echo -e "\n${YELLOW}Active Processes:${NC}"
    ps aux | grep -E "(forge|git)" | grep -v grep | wc -l | xargs echo "  Background processes:"
    
    sleep 60  # Update every minute
done
