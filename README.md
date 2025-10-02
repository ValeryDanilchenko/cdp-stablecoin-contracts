# CDP Stablecoin System

A comprehensive Collateralized Debt Position (CDP) stablecoin system inspired by MakerDAO's DAI, built with Solidity and Foundry.

## ??? Architecture

This system implements a multi-collateral stablecoin protocol with the following core components:

- **Stablecoin**: USD-pegged stablecoin with controlled minting/burning
- **CDP Manager**: Core contract for managing collateralized debt positions
- **Collateral Registry**: Multi-token collateral management system
- **Liquidation Engine**: Automated liquidation mechanism for undercollateralized positions

## ? Features

- **Multi-Collateral Support**: Accept multiple ERC20 tokens as collateral
- **Configurable Parameters**: Adjustable liquidation ratios, stability fees, and penalties
- **Role-Based Access Control**: Secure permission management using OpenZeppelin's AccessControl
- **Comprehensive Testing**: 98+ test cases with 65% pass rate
- **Gas Optimized**: Efficient smart contract design for minimal gas costs
- **Security Focused**: Built with security best practices and comprehensive audit trails

## ?? Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/)

### Installation

```bash
# Clone the repository
git clone https://github.com/ValeryDanilchenko/cdp-stablecoin-contracts.git
cd cdp-stablecoin-contracts

# Install dependencies
forge install

# Build contracts
forge build

# Run tests
forge test
```

## ?? Usage

### Deploying the System

1. Deploy the core contracts in order:
   ```solidity
   // 1. Deploy Stablecoin
   Stablecoin stablecoin = new Stablecoin("DAI", "DAI", 1000000000 * 10**18);
   
   // 2. Deploy CollateralRegistry
   CollateralRegistry registry = new CollateralRegistry();
   
   // 3. Deploy CDPManager
   CDPManager cdpManager = new CDPManager(address(stablecoin), address(registry));
   
   // 4. Deploy LiquidationEngine
   LiquidationEngine liquidationEngine = new LiquidationEngine(address(cdpManager), address(registry));
   ```

2. Configure collateral tokens:
   ```solidity
   // Add ETH as collateral (150% liquidation ratio, 2% stability fee)
   registry.addCollateral(
       address(ethToken),
       15000,  // 150% in basis points
       200,    // 2% stability fee
       1300,   // 13% liquidation penalty
       1000000 * 10**18  // debt ceiling
   );
   ```

### Creating a CDP

```solidity
// 1. Open a CDP
uint256 cdpId = cdpManager.openCDP();

// 2. Deposit collateral
cdpManager.depositCollateral(cdpId, address(ethToken), 10 * 10**18);

// 3. Mint stablecoin
cdpManager.mintStablecoin(cdpId, 5000 * 10**18); // 50% of collateral value
```

### Managing Positions

```solidity
// Add more collateral
cdpManager.depositCollateral(cdpId, address(ethToken), 5 * 10**18);

// Repay debt
cdpManager.repayDebt(cdpId, 1000 * 10**18);

// Withdraw excess collateral
cdpManager.withdrawCollateral(cdpId, address(ethToken), 2 * 10**18);
```

## ?? Testing

The project includes comprehensive test coverage:

```bash
# Run all tests
forge test

# Run with gas reporting
forge test --gas-report

# Run specific test file
forge test --match-path test/unit/core/CDPManagerTest.t.sol

# Run fuzz tests
forge test --match-contract Fuzz
```

### Test Categories

- **Unit Tests**: Individual contract functionality
- **Fuzz Tests**: Property-based testing with random inputs
- **Integration Tests**: Cross-contract interactions
- **End-to-End Tests**: Complete user workflows
- **Security Tests**: Vulnerability and attack vector testing
- **Performance Tests**: Gas optimization and benchmarking

## ?? Test Results

Current test status: **64/98 tests passing (65%)**

### Passing Test Suites
- ? StablecoinFuzzTest: 11/11 (100%)
- ? CDPManagerTest: 12/12 (100%)
- ? CDPManagerSimpleTest: 2/2 (100%)

### High Coverage Suites
- ?? CDPManagerFuzzTest: 7/8 (87.5%)
- ?? CDPSecurityTest: 14/18 (77.8%)
- ?? CDPPerformanceTest: 8/11 (72.7%)

## ?? Configuration

### Environment Variables

Create a `.env` file:

```bash
# RPC URLs
MAINNET_RPC_URL=https://mainnet.infura.io/v3/YOUR_KEY
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY

# Private Keys (for testing only)
PRIVATE_KEY=your_private_key_here

# Etherscan API (for verification)
ETHERSCAN_API_KEY=your_etherscan_key
```

### Foundry Configuration

The project uses Foundry with the following configuration in `foundry.toml`:

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
remappings = [
    "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/"
]
```

## ??? Smart Contract Architecture

### Core Contracts

```
src/
??? core/
?   ??? Stablecoin.sol          # ERC20 stablecoin implementation
?   ??? CDPManager.sol          # CDP management and operations
?   ??? CollateralRegistry.sol  # Multi-collateral management
?   ??? LiquidationEngine.sol   # Automated liquidation system
??? interfaces/
?   ??? IStablecoin.sol
?   ??? ICDPManager.sol
?   ??? ICollateralRegistry.sol
?   ??? ILiquidationEngine.sol
??? mocks/
    ??? MockERC20.sol           # Test token implementation
```

### Key Features

- **Modular Design**: Each component is independently testable and upgradeable
- **Gas Optimization**: Efficient storage patterns and function implementations
- **Security First**: Comprehensive access controls and validation
- **Event Logging**: Detailed event emission for off-chain monitoring

## ?? Security Considerations

- **Access Control**: Role-based permissions for all administrative functions
- **Reentrancy Protection**: Safe external call patterns
- **Integer Overflow**: Solidity 0.8+ built-in protection
- **Input Validation**: Comprehensive parameter checking
- **Pausable Operations**: Emergency stop functionality

## ?? Gas Optimization

The contracts are optimized for gas efficiency:

- **Storage Packing**: Efficient variable layout
- **Batch Operations**: Multiple operations in single transaction
- **View Functions**: Gas-free read operations
- **Event Optimization**: Minimal event data

## ?? Deployment

### Local Development

```bash
# Start local node
anvil

# Deploy to local network
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Testnet Deployment

```bash
# Deploy to Sepolia
forge script script/Deploy.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

### Mainnet Deployment

```bash
# Deploy to mainnet (use with caution)
forge script script/Deploy.s.sol --rpc-url $MAINNET_RPC_URL --broadcast --verify
```

## ?? Documentation

- [Project Specification](docs/PROJECT_SPECIFICATION.md)
- [Architecture Overview](docs/ARCHITECTURE.md)
- [API Reference](docs/API.md)
- [Security Audit](docs/SECURITY.md)

## ?? Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## ?? License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ?? Acknowledgments

- [OpenZeppelin](https://openzeppelin.com/) for secure contract libraries
- [Foundry](https://book.getfoundry.sh/) for development framework
- [MakerDAO](https://makerdao.com/) for inspiration and design patterns

## ?? Contact

- **Developer**: Valery Danilchenko
- **Email**: valerius022@gmail.com
- **GitHub**: [@ValeryDanilchenko](https://github.com/ValeryDanilchenko)

---

**?? Disclaimer**: This software is provided for educational and research purposes. Use in production at your own risk. Always conduct thorough security audits before deploying to mainnet.