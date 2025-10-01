// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CDPManager} from "../../src/core/CDPManager.sol";
import {Stablecoin} from "../../src/core/Stablecoin.sol";
import {CollateralRegistry} from "../../src/core/CollateralRegistry.sol";
import {LiquidationEngine} from "../../src/core/LiquidationEngine.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

/**
 * @title CDPIntegrationTest
 * @dev Integration tests for CDP system components
 * @notice Tests interactions between CDPManager, Stablecoin, CollateralRegistry, and LiquidationEngine
 */
contract CDPIntegrationTest is Test {
    CDPManager public cdpManager;
    Stablecoin public stablecoin;
    CollateralRegistry public collateralRegistry;
    LiquidationEngine public liquidationEngine;
    MockERC20 public collateralToken1;
    MockERC20 public collateralToken2;
    
    address public admin = address(this);
    address public liquidator = makeAddr("liquidator");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 public constant LIQUIDATION_RATIO_1 = 150; // 150% = 1.5x
    uint256 public constant LIQUIDATION_PENALTY_1 = 10; // 10%
    uint256 public constant MAX_LIQUIDATION_RATIO_1 = 200; // 200% = 2x
    
    uint256 public constant LIQUIDATION_RATIO_2 = 200; // 200% = 2x
    uint256 public constant LIQUIDATION_PENALTY_2 = 15; // 15%
    uint256 public constant MAX_LIQUIDATION_RATIO_2 = 300; // 300% = 3x
    
    event CDPOpened(uint256 indexed cdpId, address indexed owner, address indexed collateral);
    event CollateralDeposited(uint256 indexed cdpId, uint256 amount);
    event StablecoinMinted(uint256 indexed cdpId, uint256 amount);
    event DebtRepaid(uint256 indexed cdpId, uint256 amount);
    event CollateralWithdrawn(uint256 indexed cdpId, uint256 amount);
    event CDPLiquidated(uint256 indexed cdpId, address indexed liquidator, uint256 collateralAmount, uint256 debtAmount);
    
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
        
        // Deploy mock tokens
        collateralToken1 = new MockERC20("Collateral1", "COL1");
        collateralToken2 = new MockERC20("Collateral2", "COL2");
        
        // Setup roles
        vm.startPrank(admin);
        stablecoin.grantRole(stablecoin.MINTER_ROLE(), address(cdpManager));
        stablecoin.grantRole(stablecoin.BURNER_ROLE(), address(cdpManager));
        collateralRegistry.grantRole(collateralRegistry.COLLATERAL_MANAGER_ROLE(), admin);
        cdpManager.grantRole(cdpManager.DEFAULT_ADMIN_ROLE(), admin);
        liquidationEngine.grantRole(liquidationEngine.LIQUIDATOR_ROLE(), liquidator);
        liquidationEngine.grantRole(liquidationEngine.DEFAULT_ADMIN_ROLE(), admin);
        vm.stopPrank();
        
        // Register collaterals
        vm.startPrank(admin);
        collateralRegistry.addCollateral(
            address(collateralToken1),
            LIQUIDATION_RATIO_1 * 100, // Convert to basis points
            200, // 2% stability fee
            LIQUIDATION_PENALTY_1 * 100, // Convert to basis points
            1000000 * 10**18 // 1M debt ceiling
        );
        collateralRegistry.addCollateral(
            address(collateralToken2),
            LIQUIDATION_RATIO_2 * 100, // Convert to basis points
            200, // 2% stability fee
            LIQUIDATION_PENALTY_2 * 100, // Convert to basis points
            1000000 * 10**18 // 1M debt ceiling
        );
        vm.stopPrank();
        
        // Setup users
        collateralToken1.mint(user1, INITIAL_SUPPLY);
        collateralToken1.mint(user2, INITIAL_SUPPLY);
        collateralToken2.mint(user1, INITIAL_SUPPLY);
        collateralToken2.mint(user2, INITIAL_SUPPLY);
        
        vm.startPrank(user1);
        collateralToken1.approve(address(cdpManager), type(uint256).max);
        collateralToken2.approve(address(cdpManager), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(user2);
        collateralToken1.approve(address(cdpManager), type(uint256).max);
        collateralToken2.approve(address(cdpManager), type(uint256).max);
        vm.stopPrank();
    }
    
    /**
     * @dev Test complete CDP lifecycle with multiple collaterals
     */
    function test_CompleteCDPLifecycle_MultipleCollaterals() public {
        uint256 collateralAmount1 = 1000 * 10**18;
        uint256 collateralAmount2 = 500 * 10**18;
        uint256 mintAmount = 1000 * 10**18;
        
        vm.startPrank(user1);
        
        // Open CDP with first collateral
        uint256 cdpId1 = cdpManager.openCDP(address(collateralToken1), collateralAmount1);
        assertTrue(cdpId1 > 0);
        
        // Open CDP with second collateral
        uint256 cdpId2 = cdpManager.openCDP(address(collateralToken2), collateralAmount2);
        assertTrue(cdpId2 > 0);
        
        // Mint stablecoins from both CDPs
        uint256 maxMintable1 = (collateralAmount1 * 100) / LIQUIDATION_RATIO_1;
        uint256 maxMintable2 = (collateralAmount2 * 100) / LIQUIDATION_RATIO_2;
        uint256 mintAmount1 = maxMintable1 / 2;
        uint256 mintAmount2 = maxMintable2 / 2;
        
        cdpManager.mintStablecoin(cdpId1, mintAmount1);
        cdpManager.mintStablecoin(cdpId2, mintAmount2);
        
        // Verify balances
        assertEq(stablecoin.balanceOf(user1), mintAmount1 + mintAmount2);
        assertEq(cdpManager.getCDPDebt(cdpId1), mintAmount1);
        assertEq(cdpManager.getCDPDebt(cdpId2), mintAmount2);
        
        // Repay some debt
        cdpManager.repayDebt(cdpId1, mintAmount1 / 2);
        cdpManager.repayDebt(cdpId2, mintAmount2 / 2);
        
        // Withdraw some collateral
        cdpManager.withdrawCollateral(cdpId1, collateralAmount1 / 4);
        cdpManager.withdrawCollateral(cdpId2, collateralAmount2 / 4);
        
        vm.stopPrank();
        
        // Verify final state
        assertEq(cdpManager.getCDPDebt(cdpId1), mintAmount1 / 2);
        assertEq(cdpManager.getCDPDebt(cdpId2), mintAmount2 / 2);
        assertEq(cdpManager.getCDPCollateralAmount(cdpId1), collateralAmount1 * 3 / 4);
        assertEq(cdpManager.getCDPCollateralAmount(cdpId2), collateralAmount2 * 3 / 4);
    }
    
    /**
     * @dev Test liquidation process integration
     */
    function test_LiquidationProcess_Integration() public {
        uint256 collateralAmount = 1000 * 10**18;
        uint256 mintAmount = 800 * 10**18; // High debt ratio
        
        // Setup CDP
        vm.startPrank(user1);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken1), collateralAmount);
        cdpManager.mintStablecoin(cdpId, mintAmount);
        vm.stopPrank();
        
        // Verify CDP is liquidatable
        assertTrue(liquidationEngine.isCDPLiquidatable(cdpId));
        
        // Setup liquidator
        stablecoin.mint(liquidator, mintAmount);
        vm.startPrank(liquidator);
        stablecoin.approve(address(liquidationEngine), mintAmount);
        vm.stopPrank();
        
        // Liquidate CDP
        vm.startPrank(liquidator);
        liquidationEngine.liquidateCDP(cdpId);
        vm.stopPrank();
        
        // Verify liquidation results
        assertEq(cdpManager.getCDPDebt(cdpId), 0);
        assertEq(cdpManager.getCDPCollateralAmount(cdpId), 0);
        assertTrue(cdpManager.getCDPOwner(cdpId) == address(0));
    }
    
    /**
     * @dev Test multiple users with different CDP strategies
     */
    function test_MultipleUsers_DifferentStrategies() public {
        // User1: Conservative strategy - low debt ratio
        vm.startPrank(user1);
        uint256 cdpId1 = cdpManager.openCDP(address(collateralToken1), 1000 * 10**18);
        cdpManager.mintStablecoin(cdpId1, 500 * 10**18); // 50% of max
        vm.stopPrank();
        
        // User2: Aggressive strategy - high debt ratio
        vm.startPrank(user2);
        uint256 cdpId2 = cdpManager.openCDP(address(collateralToken2), 1000 * 10**18);
        cdpManager.mintStablecoin(cdpId2, 400 * 10**18); // 80% of max
        vm.stopPrank();
        
        // Verify both CDPs are valid
        assertTrue(cdpManager.getCDPOwner(cdpId1) == user1);
        assertTrue(cdpManager.getCDPOwner(cdpId2) == user2);
        assertTrue(cdpManager.getCDPDebt(cdpId1) > 0);
        assertTrue(cdpManager.getCDPDebt(cdpId2) > 0);
        
        // User1's CDP should not be liquidatable (conservative)
        assertFalse(liquidationEngine.isCDPLiquidatable(cdpId1));
        
        // User2's CDP should be liquidatable (aggressive)
        assertTrue(liquidationEngine.isCDPLiquidatable(cdpId2));
    }
    
    /**
     * @dev Test collateral parameter updates affecting existing CDPs
     */
    function test_CollateralParameterUpdates_ExistingCDPs() public {
        uint256 collateralAmount = 1000 * 10**18;
        uint256 mintAmount = 600 * 10**18;
        
        // Setup CDP
        vm.startPrank(user1);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken1), collateralAmount);
        cdpManager.mintStablecoin(cdpId, mintAmount);
        vm.stopPrank();
        
        // Update collateral parameters (increase liquidation ratio)
        vm.startPrank(admin);
        collateralRegistry.updateCollateralParams(
            address(collateralToken1),
            LIQUIDATION_RATIO_1 + 50, // Increase to 200%
            LIQUIDATION_PENALTY_1,
            MAX_LIQUIDATION_RATIO_1 + 50
        );
        vm.stopPrank();
        
        // CDP should now be liquidatable due to parameter change
        assertTrue(liquidationEngine.isCDPLiquidatable(cdpId));
    }
    
    /**
     * @dev Test emergency scenarios and system resilience
     */
    function test_EmergencyScenarios_SystemResilience() public {
        uint256 collateralAmount = 1000 * 10**18;
        uint256 mintAmount = 700 * 10**18;
        
        // Setup CDP
        vm.startPrank(user1);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken1), collateralAmount);
        cdpManager.mintStablecoin(cdpId, mintAmount);
        vm.stopPrank();
        
        // Simulate price drop by updating liquidation ratio
        vm.startPrank(admin);
        collateralRegistry.updateCollateralParams(
            address(collateralToken1),
            LIQUIDATION_RATIO_1 + 100, // Increase to 250%
            LIQUIDATION_PENALTY_1 + 5, // Increase penalty
            MAX_LIQUIDATION_RATIO_1 + 100
        );
        vm.stopPrank();
        
        // CDP should be liquidatable
        assertTrue(liquidationEngine.isCDPLiquidatable(cdpId));
        
        // Setup liquidator
        stablecoin.mint(liquidator, mintAmount);
        vm.startPrank(liquidator);
        stablecoin.approve(address(liquidationEngine), mintAmount);
        vm.stopPrank();
        
        // Liquidate CDP
        vm.startPrank(liquidator);
        liquidationEngine.liquidateCDP(cdpId);
        vm.stopPrank();
        
        // Verify system state
        assertEq(cdpManager.getCDPDebt(cdpId), 0);
        assertEq(cdpManager.getCDPCollateralAmount(cdpId), 0);
    }
    
    /**
     * @dev Test gas optimization across multiple operations
     */
    function test_GasOptimization_MultipleOperations() public {
        uint256 gasStart = gasleft();
        
        vm.startPrank(user1);
        
        // Open multiple CDPs
        uint256 cdpId1 = cdpManager.openCDP(address(collateralToken1), 1000 * 10**18);
        uint256 cdpId2 = cdpManager.openCDP(address(collateralToken2), 1000 * 10**18);
        
        // Mint from both CDPs
        cdpManager.mintStablecoin(cdpId1, 500 * 10**18);
        cdpManager.mintStablecoin(cdpId2, 400 * 10**18);
        
        // Perform various operations
        cdpManager.depositCollateral(cdpId1, 100 * 10**18);
        cdpManager.repayDebt(cdpId1, 100 * 10**18);
        cdpManager.withdrawCollateral(cdpId1, 50 * 10**18);
        
        vm.stopPrank();
        
        uint256 gasUsed = gasStart - gasleft();
        
        // Gas usage should be reasonable for multiple operations
        assertLt(gasUsed, 2000000); // Less than 2M gas
    }
    
    /**
     * @dev Test system state consistency across operations
     */
    function test_SystemStateConsistency_AcrossOperations() public {
        uint256 collateralAmount = 1000 * 10**18;
        uint256 mintAmount = 600 * 10**18;
        
        // Track initial state
        uint256 initialTotalSupply = stablecoin.totalSupply();
        uint256 initialCollateralBalance = collateralToken1.balanceOf(user1);
        
        vm.startPrank(user1);
        
        // Open CDP
        uint256 cdpId = cdpManager.openCDP(address(collateralToken1), collateralAmount);
        
        // Mint stablecoin
        cdpManager.mintStablecoin(cdpId, mintAmount);
        
        // Verify state consistency
        assertEq(stablecoin.totalSupply(), initialTotalSupply + mintAmount);
        assertEq(stablecoin.balanceOf(user1), mintAmount);
        assertEq(collateralToken1.balanceOf(user1), initialCollateralBalance - collateralAmount);
        assertEq(cdpManager.getCDPCollateralAmount(cdpId), collateralAmount);
        assertEq(cdpManager.getCDPDebt(cdpId), mintAmount);
        
        // Repay debt
        cdpManager.repayDebt(cdpId, mintAmount / 2);
        
        // Verify state after repayment
        assertEq(stablecoin.totalSupply(), initialTotalSupply + mintAmount / 2);
        assertEq(stablecoin.balanceOf(user1), mintAmount / 2);
        assertEq(cdpManager.getCDPDebt(cdpId), mintAmount / 2);
        
        // Withdraw collateral
        cdpManager.withdrawCollateral(cdpId, collateralAmount / 2);
        
        // Verify final state
        assertEq(collateralToken1.balanceOf(user1), initialCollateralBalance - collateralAmount / 2);
        assertEq(cdpManager.getCDPCollateralAmount(cdpId), collateralAmount / 2);
        
        vm.stopPrank();
    }
}
