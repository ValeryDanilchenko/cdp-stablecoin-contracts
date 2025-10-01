# CDP Stablecoin Project - Commit Backdating Scripts

This directory contains scripts to backdate git commits to simulate realistic development timelines.

## Scripts Available

### 1. `backdate-commits.sh` - Simple Backdating
- **Purpose**: Basic commit backdating with even time distribution
- **Usage**: `./scripts/backdate-commits.sh`
- **Features**:
  - Evenly distributes commits between start and end dates
  - Simple configuration
  - Automatic branch management

### 2. `advanced-backdate.sh` - Realistic Development Pattern
- **Purpose**: Advanced backdating with realistic development phases
- **Usage**: `./scripts/advanced-backdate.sh`
- **Features**:
  - 3-phase development simulation (Setup ? Development ? Finalization)
  - Realistic commit timing with random variations
  - Interactive configuration
  - Color-coded output
  - Development statistics

## Quick Start

### Option 1: Simple Backdating
```bash
cd /Users/valery/Projects/Pets/skill-demo-contracts
./scripts/backdate-commits.sh
```

### Option 2: Advanced Backdating (Recommended)
```bash
cd /Users/valery/Projects/Pets/skill-demo-contracts
./scripts/advanced-backdate.sh
```

## Configuration

### Default Settings
- **Start Date**: January 1, 2025
- **End Date**: March 31, 2025
- **Author**: Valery Developer <valery@example.com>

### Custom Configuration
The advanced script allows you to customize:
- Project start and end dates
- Author name and email
- Development phases and timing

## Development Phases (Advanced Script)

1. **Phase 1 - Setup** (25% of timeline)
   - Core contracts and basic tests
   - More frequent commits (every 2 days)
   - Initial project structure

2. **Phase 2 - Development** (50% of timeline)
   - Main features and comprehensive tests
   - Regular commit intervals (daily)
   - Feature implementation

3. **Phase 3 - Finalization** (25% of timeline)
   - Bug fixes and optimization
   - More frequent commits (every 12 hours)
   - Final testing and polish

## Safety Features

- Creates temporary branches for testing
- Preserves original commit history
- Interactive confirmation before applying changes
- Automatic cleanup of temporary branches

## Example Timeline

```
2025-01-01 - Project initialization
2025-01-03 - Core contract setup
2025-01-05 - Basic testing framework
2025-01-08 - CDP Manager implementation
2025-01-12 - Collateral Registry
2025-01-15 - Liquidation Engine
2025-01-20 - Comprehensive test suite
2025-02-15 - Fuzz testing implementation
2025-03-01 - Security testing
2025-03-15 - Performance optimization
2025-03-25 - Final bug fixes
2025-03-31 - Project completion
```

## Troubleshooting

### Common Issues

1. **No commits found**
   - Make sure you're in a git repository
   - Check if there are any commits in the current branch

2. **Invalid date format**
   - Use YYYY-MM-DD format (e.g., 2025-01-01)
   - Ensure end date is after start date

3. **Permission denied**
   - Make sure scripts are executable: `chmod +x scripts/*.sh`

### Recovery

If something goes wrong:
1. The original branch is preserved
2. Temporary branches can be deleted manually
3. Use `git reflog` to recover previous states

## Notes

- Scripts preserve commit messages and content
- Only timestamps and author information are modified
- Original commit hashes will change after backdating
- Make sure to backup your repository before running

## Support

For issues or questions:
1. Check the script output for error messages
2. Verify git repository state
3. Ensure all dependencies are installed
