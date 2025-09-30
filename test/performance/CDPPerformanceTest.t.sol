// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CDPManager} from "../../src/core/CDPManager.sol";
import {Stablecoin} from "../../src/core/Stablecoin.sol";
import {CollateralRegistry} from "../../src/core/CollateralRegistry.sol";
import {LiquidationEngine} from "../../src/core/LiquidationEngine.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

/**
 * @title CDPPerformanceTest
 * @dev Performance benchmarking tests for CDP system
 * @notice Tests gas efficiency, throughput, and scalability
 */
contract CDPPerformanceTest is Test {
    CDPManager public cdpManager;
    Stablecoin public stablecoin;
    CollateralRegistry public collateralRegistry;
    LiquidationEngine public liquidationEngine;
    MockERC20 public collateralToken;
    
    address public admin = makeAddr("admin");
    address public user = makeAddr("user");
    address public liquidator = makeAddr("liquidator");
    
    uint256 public constant INITIAL_SUPPLY = 10000000 * 10**18;
    uint256 public constant LIQUIDATION_RATIO = 150;
    uint256 public constant LIQUIDATION_PENALTY = 10;
    uint256 public constant MAX_LIQUIDATION_RATIO = 200;
    
    function setUp() public {
        // Deploy contracts
        stablecoin = new Stablecoin("TestStablecoin", "TST", 1000000000 * 10**18);
        collateralRegistry = new CollateralRegistry();
        cdpManager = new CDPManager(
            address(stablecoin),
            address(collateralRegistry)
        );
        liquidationEngine = new LiquidationEngine(
            address(cdpManager),
            address(collateralRegistry)
        );
        collateralToken = new MockERC20("TestCollateral", "TCOL");
        
        // Setup roles
        vm.startPrank(admin);
        stablecoin.grantRole(stablecoin.MINTER_ROLE(), address(cdpManager));
        stablecoin.grantRole(stablecoin.BURNER_ROLE(), address(cdpManager));
        collateralRegistry.grantRole(collateralRegistry.COLLATERAL_MANAGER_ROLE(), address(cdpManager));
        cdpManager.grantRole(cdpManager.DEFAULT_ADMIN_ROLE(), admin);
        liquidationEngine.grantRole(liquidationEngine.LIQUIDATOR_ROLE(), liquidator);
        liquidationEngine.grantRole(liquidationEngine.ADMIN_ROLE(), admin);
        vm.stopPrank();
        
        // Register collateral
        vm.startPrank(admin);
        collateralRegistry.registerCollateral(
            address(collateralToken),
            LIQUIDATION_RATIO,
            LIQUIDATION_PENALTY,
            MAX_LIQUIDATION_RATIO
        );
        vm.stopPrank();
        
        // Setup user
        collateralToken.mint(user, INITIAL_SUPPLY);
        vm.startPrank(user);
        collateralToken.approve(address(cdpManager), type(uint256).max);
        vm.stopPrank();
    }
    
    /**
     * @dev Benchmark gas usage for CDP operations
     */
    function test_GasUsage_CDPOperations() public {
        uint256 gasStart;
        uint256 gasUsed;
        
        // Benchmark CDP opening
        gasStart = gasleft();
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 1000 * 10**18);
        vm.stopPrank();
        gasUsed = gasStart - gasleft();
        console.log("CDP Opening Gas Used:", gasUsed);
        assertLt(gasUsed, 300000); // Should be less than 300k gas
        
        // Benchmark stablecoin minting
        gasStart = gasleft();
        vm.startPrank(user);
        cdpManager.mintStablecoin(cdpId, 500 * 10**18);
        vm.stopPrank();
        gasUsed = gasStart - gasleft();
        console.log("Stablecoin Minting Gas Used:", gasUsed);
        assertLt(gasUsed, 200000); // Should be less than 200k gas
        
        // Benchmark debt repayment
        gasStart = gasleft();
        vm.startPrank(user);
        cdpManager.repayDebt(cdpId, 100 * 10**18);
        vm.stopPrank();
        gasUsed = gasStart - gasleft();
        console.log("Debt Repayment Gas Used:", gasUsed);
        assertLt(gasUsed, 150000); // Should be less than 150k gas
        
        // Benchmark collateral withdrawal
        gasStart = gasleft();
        vm.startPrank(user);
        cdpManager.withdrawCollateral(cdpId, 100 * 10**18);
        vm.stopPrank();
        gasUsed = gasStart - gasleft();
        console.log("Collateral Withdrawal Gas Used:", gasUsed);
        assertLt(gasUsed, 150000); // Should be less than 150k gas
    }
    
    /**
     * @dev Benchmark gas usage for liquidation operations
     */
    function test_GasUsage_LiquidationOperations() public {
        // Setup CDP for liquidation
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 1000 * 10**18);
        cdpManager.mintStablecoin(cdpId, 800 * 10**18); // High debt ratio
        vm.stopPrank();
        
        // Setup liquidator
        stablecoin.mint(liquidator, 800 * 10**18);
        vm.startPrank(liquidator);
        stablecoin.approve(address(liquidationEngine), 800 * 10**18);
        vm.stopPrank();
        
        // Benchmark liquidation check
        uint256 gasStart = gasleft();
        bool isLiquidatable = liquidationEngine.isLiquidatable(cdpId);
        uint256 gasUsed = gasStart - gasleft();
        console.log("Liquidation Check Gas Used:", gasUsed);
        assertLt(gasUsed, 50000); // Should be less than 50k gas
        assertTrue(isLiquidatable);
        
        // Benchmark liquidation execution
        gasStart = gasleft();
        vm.startPrank(liquidator);
        liquidationEngine.liquidateCDP(cdpId);
        vm.stopPrank();
        gasUsed = gasStart - gasleft();
        console.log("Liquidation Execution Gas Used:", gasUsed);
        assertLt(gasUsed, 400000); // Should be less than 400k gas
    }
    
    /**
     * @dev Benchmark throughput for multiple CDP operations
     */
    function test_Throughput_MultipleCDPOperations() public {
        uint256 numCDPs = 10;
        uint256[] memory cdpIds = new uint256[](numCDPs);
        
        // Create multiple CDPs
        uint256 gasStart = gasleft();
        for (uint256 i = 0; i < numCDPs; i++) {
            vm.startPrank(user);
            cdpIds[i] = cdpManager.openCDP(address(collateralToken), 1000 * 10**18);
            cdpManager.mintStablecoin(cdpIds[i], 500 * 10**18);
            vm.stopPrank();
        }
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas Used for", numCDPs, "CDPs:", gasUsed);
        assertLt(gasUsed, 5000000); // Should be less than 5M gas
        
        // Perform operations on all CDPs
        gasStart = gasleft();
        for (uint256 i = 0; i < numCDPs; i++) {
            vm.startPrank(user);
            cdpManager.depositCollateral(cdpIds[i], 100 * 10**18);
            cdpManager.repayDebt(cdpIds[i], 50 * 10**18);
            cdpManager.withdrawCollateral(cdpIds[i], 25 * 10**18);
            vm.stopPrank();
        }
        gasUsed = gasStart - gasleft();
        console.log("Gas Used for", numCDPs, "CDP operations:", gasUsed);
        assertLt(gasUsed, 3000000); // Should be less than 3M gas
    }
    
    /**
     * @dev Benchmark scalability with large numbers
     */
    function test_Scalability_LargeNumbers() public {
        uint256 largeAmount = 1000000 * 10**18;
        
        // Test with large amounts
        uint256 gasStart = gasleft();
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), largeAmount);
        uint256 maxMintable = (largeAmount * 100) / LIQUIDATION_RATIO;
        cdpManager.mintStablecoin(cdpId, maxMintable);
        vm.stopPrank();
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas Used for large amounts:", gasUsed);
        assertLt(gasUsed, 1000000); // Should be less than 1M gas
    }
    
    /**
     * @dev Benchmark memory usage for complex operations
     */
    function test_MemoryUsage_ComplexOperations() public {
        uint256 numOperations = 100;
        
        // Perform many operations to test memory usage
        uint256 gasStart = gasleft();
        for (uint256 i = 0; i < numOperations; i++) {
            vm.startPrank(user);
            uint256 cdpId = cdpManager.openCDP(address(collateralToken), 1000 * 10**18);
            cdpManager.mintStablecoin(cdpId, 500 * 10**18);
            cdpManager.depositCollateral(cdpId, 100 * 10**18);
            cdpManager.repayDebt(cdpId, 50 * 10**18);
            cdpManager.withdrawCollateral(cdpId, 25 * 10**18);
            vm.stopPrank();
        }
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas Used for", numOperations, "complex operations:", gasUsed);
        assertLt(gasUsed, 10000000); // Should be less than 10M gas
    }
    
    /**
     * @dev Benchmark gas efficiency for different collateral amounts
     */
    function test_GasEfficiency_DifferentCollateralAmounts() public {
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = 100 * 10**18;   // Small
        amounts[1] = 1000 * 10**18;  // Medium
        amounts[2] = 10000 * 10**18; // Large
        amounts[3] = 100000 * 10**18; // Very large
        amounts[4] = 1000000 * 10**18; // Huge
        
        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 gasStart = gasleft();
            vm.startPrank(user);
            uint256 cdpId = cdpManager.openCDP(address(collateralToken), amounts[i]);
            uint256 maxMintable = (amounts[i] * 100) / LIQUIDATION_RATIO;
            if (maxMintable > 0) {
                cdpManager.mintStablecoin(cdpId, maxMintable);
            }
            vm.stopPrank();
            uint256 gasUsed = gasStart - gasleft();
            console.log("Gas Used for amount", amounts[i], ":", gasUsed);
            assertLt(gasUsed, 500000); // Should be less than 500k gas
        }
    }
    
    /**
     * @dev Benchmark gas usage for collateral registry operations
     */
    function test_GasUsage_CollateralRegistryOperations() public {
        MockERC20 newToken = new MockERC20("NewToken", "NEW");
        
        // Benchmark collateral registration
        uint256 gasStart = gasleft();
        vm.startPrank(admin);
        collateralRegistry.registerCollateral(
            address(newToken),
            LIQUIDATION_RATIO,
            LIQUIDATION_PENALTY,
            MAX_LIQUIDATION_RATIO
        );
        vm.stopPrank();
        uint256 gasUsed = gasStart - gasleft();
        console.log("Collateral Registration Gas Used:", gasUsed);
        assertLt(gasUsed, 200000); // Should be less than 200k gas
        
        // Benchmark parameter update
        gasStart = gasleft();
        vm.startPrank(admin);
        collateralRegistry.updateCollateralParameters(
            address(newToken),
            LIQUIDATION_RATIO + 50,
            LIQUIDATION_PENALTY + 5,
            MAX_LIQUIDATION_RATIO + 50
        );
        vm.stopPrank();
        gasUsed = gasStart - gasleft();
        console.log("Parameter Update Gas Used:", gasUsed);
        assertLt(gasUsed, 150000); // Should be less than 150k gas
        
        // Benchmark collateral unregistration
        gasStart = gasleft();
        vm.startPrank(admin);
        collateralRegistry.unregisterCollateral(address(newToken));
        vm.stopPrank();
        gasUsed = gasStart - gasleft();
        console.log("Collateral Unregistration Gas Used:", gasUsed);
        assertLt(gasUsed, 100000); // Should be less than 100k gas
    }
    
    /**
     * @dev Benchmark gas usage for stablecoin operations
     */
    function test_GasUsage_StablecoinOperations() public {
        // Benchmark minting
        uint256 gasStart = gasleft();
        vm.startPrank(admin);
        stablecoin.mint(user, 1000 * 10**18);
        vm.stopPrank();
        uint256 gasUsed = gasStart - gasleft();
        console.log("Stablecoin Minting Gas Used:", gasUsed);
        assertLt(gasUsed, 100000); // Should be less than 100k gas
        
        // Benchmark burning
        gasStart = gasleft();
        vm.startPrank(admin);
        stablecoin.burn(user, 500 * 10**18);
        vm.stopPrank();
        gasUsed = gasStart - gasleft();
        console.log("Stablecoin Burning Gas Used:", gasUsed);
        assertLt(gasUsed, 100000); // Should be less than 100k gas
        
        // Benchmark transfer
        gasStart = gasleft();
        vm.startPrank(user);
        stablecoin.transfer(admin, 100 * 10**18);
        vm.stopPrank();
        gasUsed = gasStart - gasleft();
        console.log("Stablecoin Transfer Gas Used:", gasUsed);
        assertLt(gasUsed, 100000); // Should be less than 100k gas
    }
    
    /**
     * @dev Benchmark gas usage for role management
     */
    function test_GasUsage_RoleManagement() public {
        address newAdmin = makeAddr("newAdmin");
        
        // Benchmark role granting
        uint256 gasStart = gasleft();
        vm.startPrank(admin);
        cdpManager.grantRole(cdpManager.ADMIN_ROLE(), newAdmin);
        vm.stopPrank();
        uint256 gasUsed = gasStart - gasleft();
        console.log("Role Granting Gas Used:", gasUsed);
        assertLt(gasUsed, 100000); // Should be less than 100k gas
        
        // Benchmark role revoking
        gasStart = gasleft();
        vm.startPrank(admin);
        cdpManager.revokeRole(cdpManager.ADMIN_ROLE(), newAdmin);
        vm.stopPrank();
        gasUsed = gasStart - gasleft();
        console.log("Role Revoking Gas Used:", gasUsed);
        assertLt(gasUsed, 100000); // Should be less than 100k gas
    }
    
    /**
     * @dev Benchmark gas usage for complex workflows
     */
    function test_GasUsage_ComplexWorkflows() public {
        // Complete user workflow
        uint256 gasStart = gasleft();
        
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 1000 * 10**18);
        cdpManager.mintStablecoin(cdpId, 500 * 10**18);
        cdpManager.depositCollateral(cdpId, 200 * 10**18);
        cdpManager.repayDebt(cdpId, 100 * 10**18);
        cdpManager.withdrawCollateral(cdpId, 50 * 10**18);
        cdpManager.repayDebt(cdpId, cdpManager.getCDPDebt(cdpId));
        cdpManager.withdrawCollateral(cdpId, cdpManager.getCDPCollateralAmount(cdpId));
        vm.stopPrank();
        
        uint256 gasUsed = gasStart - gasleft();
        console.log("Complete Workflow Gas Used:", gasUsed);
        assertLt(gasUsed, 2000000); // Should be less than 2M gas
    }
    
    /**
     * @dev Benchmark gas usage for edge cases
     */
    function test_GasUsage_EdgeCases() public {
        // Test with maximum values
        uint256 maxAmount = type(uint256).max;
        
        uint256 gasStart = gasleft();
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), maxAmount);
        uint256 maxMintable = (maxAmount * 100) / LIQUIDATION_RATIO;
        if (maxMintable > 0 && maxMintable <= maxAmount) {
            cdpManager.mintStablecoin(cdpId, maxMintable);
        }
        vm.stopPrank();
        uint256 gasUsed = gasStart - gasleft();
        console.log("Edge Case Gas Used:", gasUsed);
        assertLt(gasUsed, 1000000); // Should be less than 1M gas
    }
}
