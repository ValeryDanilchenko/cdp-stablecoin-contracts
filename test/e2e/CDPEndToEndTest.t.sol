// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CDPManager} from "../../src/core/CDPManager.sol";
import {Stablecoin} from "../../src/core/Stablecoin.sol";
import {CollateralRegistry} from "../../src/core/CollateralRegistry.sol";
import {LiquidationEngine} from "../../src/core/LiquidationEngine.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

/**
 * @title CDPEndToEndTest
 * @dev End-to-end tests for complete CDP system workflows
 * @notice Tests realistic user scenarios and complete system functionality
 */
contract CDPEndToEndTest is Test {
    CDPManager public cdpManager;
    Stablecoin public stablecoin;
    CollateralRegistry public collateralRegistry;
    LiquidationEngine public liquidationEngine;
    MockERC20 public weth;
    MockERC20 public wbtc;
    MockERC20 public usdc;
    
    address public admin = address(this);
    address public liquidator = makeAddr("liquidator");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    
    uint256 public constant INITIAL_SUPPLY = 10000000 * 10**18;
    
    // Collateral parameters
    uint256 public constant WETH_LIQUIDATION_RATIO = 150; // 150%
    uint256 public constant WETH_LIQUIDATION_PENALTY = 8; // 8%
    uint256 public constant WETH_MAX_LIQUIDATION_RATIO = 200; // 200%
    
    uint256 public constant WBTC_LIQUIDATION_RATIO = 200; // 200%
    uint256 public constant WBTC_LIQUIDATION_PENALTY = 12; // 12%
    uint256 public constant WBTC_MAX_LIQUIDATION_RATIO = 300; // 300%
    
    uint256 public constant USDC_LIQUIDATION_RATIO = 110; // 110%
    uint256 public constant USDC_LIQUIDATION_PENALTY = 5; // 5%
    uint256 public constant USDC_MAX_LIQUIDATION_RATIO = 150; // 150%
    
    event CDPOpened(uint256 indexed cdpId, address indexed owner, address indexed collateral);
    event CollateralDeposited(uint256 indexed cdpId, uint256 amount);
    event StablecoinMinted(uint256 indexed cdpId, uint256 amount);
    event DebtRepaid(uint256 indexed cdpId, uint256 amount);
    event CollateralWithdrawn(uint256 indexed cdpId, uint256 amount);
    event CDPLiquidated(uint256 indexed cdpId, address indexed liquidator, uint256 collateralAmount, uint256 debtAmount);
    
    function setUp() public {
        // Deploy contracts
        stablecoin = new Stablecoin("DAI", "DAI", 1000000000 * 10**18);
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
        weth = new MockERC20("Wrapped Ether", "WETH");
        wbtc = new MockERC20("Wrapped Bitcoin", "WBTC");
        usdc = new MockERC20("USD Coin", "USDC");
        
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
            address(weth),
            WETH_LIQUIDATION_RATIO * 100, // Convert to basis points
            200, // 2% stability fee
            WETH_LIQUIDATION_PENALTY * 100, // Convert to basis points
            1000000 * 10**18 // 1M debt ceiling
        );
        collateralRegistry.addCollateral(
            address(wbtc),
            WBTC_LIQUIDATION_RATIO * 100, // Convert to basis points
            300, // 3% stability fee
            WBTC_LIQUIDATION_PENALTY * 100, // Convert to basis points
            1000000 * 10**18 // 1M debt ceiling
        );
        collateralRegistry.addCollateral(
            address(usdc),
            USDC_LIQUIDATION_RATIO * 100, // Convert to basis points
            100, // 1% stability fee
            USDC_LIQUIDATION_PENALTY * 100, // Convert to basis points
            1000000 * 10**18 // 1M debt ceiling
        );
        vm.stopPrank();
        
        // Setup users with collateral
        weth.mint(alice, INITIAL_SUPPLY);
        wbtc.mint(bob, INITIAL_SUPPLY);
        usdc.mint(charlie, INITIAL_SUPPLY);
        
        // Approve CDP manager
        vm.startPrank(alice);
        weth.approve(address(cdpManager), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(bob);
        wbtc.approve(address(cdpManager), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(charlie);
        usdc.approve(address(cdpManager), type(uint256).max);
        vm.stopPrank();
    }
    
    /**
     * @dev Test complete user journey: Alice opens CDP, mints DAI, uses it, repays, closes CDP
     */
    function test_CompleteUserJourney_Alice() public {
        uint256 wethAmount = 10 * 10**18; // 10 WETH
        uint256 daiAmount = 6000 * 10**18; // 6000 DAI (60% of max)
        
        // Step 1: Alice opens CDP with WETH
        vm.startPrank(alice);
        uint256 cdpId = cdpManager.openCDP(address(weth), wethAmount);
        assertTrue(cdpId > 0);
        assertEq(cdpManager.getCDPOwner(cdpId), alice);
        vm.stopPrank();
        
        // Step 2: Alice mints DAI
        vm.startPrank(alice);
        cdpManager.mintStablecoin(cdpId, daiAmount);
        assertEq(stablecoin.balanceOf(alice), daiAmount);
        assertEq(cdpManager.getCDPDebt(cdpId), daiAmount);
        vm.stopPrank();
        
        // Step 3: Alice uses DAI (simulate by transferring to Bob)
        vm.startPrank(alice);
        stablecoin.transfer(bob, daiAmount / 2);
        assertEq(stablecoin.balanceOf(alice), daiAmount / 2);
        assertEq(stablecoin.balanceOf(bob), daiAmount / 2);
        vm.stopPrank();
        
        // Step 4: Alice repays some debt
        vm.startPrank(alice);
        cdpManager.repayDebt(cdpId, daiAmount / 4);
        assertEq(cdpManager.getCDPDebt(cdpId), daiAmount * 3 / 4);
        assertEq(stablecoin.balanceOf(alice), daiAmount / 4);
        vm.stopPrank();
        
        // Step 5: Alice withdraws some collateral
        vm.startPrank(alice);
        cdpManager.withdrawCollateral(cdpId, wethAmount / 4);
        assertEq(cdpManager.getCDPCollateralAmount(cdpId), wethAmount * 3 / 4);
        assertEq(weth.balanceOf(alice), wethAmount / 4);
        vm.stopPrank();
        
        // Step 6: Alice repays remaining debt and withdraws all collateral
        vm.startPrank(alice);
        cdpManager.repayDebt(cdpId, cdpManager.getCDPDebt(cdpId));
        cdpManager.withdrawCollateral(cdpId, cdpManager.getCDPCollateralAmount(cdpId));
        assertEq(cdpManager.getCDPDebt(cdpId), 0);
        assertEq(cdpManager.getCDPCollateralAmount(cdpId), 0);
        vm.stopPrank();
    }
    
    /**
     * @dev Test complex multi-user scenario with different strategies
     */
    function test_ComplexMultiUserScenario() public {
        // Alice: Conservative strategy with WETH
        vm.startPrank(alice);
        uint256 aliceCdpId = cdpManager.openCDP(address(weth), 20 * 10**18);
        cdpManager.mintStablecoin(aliceCdpId, 8000 * 10**18); // 40% of max
        vm.stopPrank();
        
        // Bob: Aggressive strategy with WBTC
        vm.startPrank(bob);
        uint256 bobCdpId = cdpManager.openCDP(address(wbtc), 1 * 10**18);
        cdpManager.mintStablecoin(bobCdpId, 4000 * 10**18); // 80% of max
        vm.stopPrank();
        
        // Charlie: Stable strategy with USDC
        vm.startPrank(charlie);
        uint256 charlieCdpId = cdpManager.openCDP(address(usdc), 10000 * 10**18);
        cdpManager.mintStablecoin(charlieCdpId, 9000 * 10**18); // 90% of max
        vm.stopPrank();
        
        // Verify all CDPs are valid
        assertTrue(cdpManager.getCDPOwner(aliceCdpId) == alice);
        assertTrue(cdpManager.getCDPOwner(bobCdpId) == bob);
        assertTrue(cdpManager.getCDPOwner(charlieCdpId) == charlie);
        
        // Alice's CDP should not be liquidatable (conservative)
        assertFalse(liquidationEngine.isCDPLiquidatable(aliceCdpId));
        
        // Bob's CDP should be liquidatable (aggressive)
        assertTrue(liquidationEngine.isCDPLiquidatable(bobCdpId));
        
        // Charlie's CDP should not be liquidatable (stable collateral)
        assertFalse(liquidationEngine.isCDPLiquidatable(charlieCdpId));
        
        // Simulate market crash by updating liquidation ratios
        vm.startPrank(admin);
        collateralRegistry.updateCollateralParams(
            address(weth),
            WETH_LIQUIDATION_RATIO + 50,
            WETH_LIQUIDATION_PENALTY + 2,
            WETH_MAX_LIQUIDATION_RATIO + 50
        );
        collateralRegistry.updateCollateralParams(
            address(wbtc),
            WBTC_LIQUIDATION_RATIO + 100,
            WBTC_LIQUIDATION_PENALTY + 5,
            WBTC_MAX_LIQUIDATION_RATIO + 100
        );
        vm.stopPrank();
        
        // Now Alice's CDP should be liquidatable too
        assertTrue(liquidationEngine.isCDPLiquidatable(aliceCdpId));
        assertTrue(liquidationEngine.isCDPLiquidatable(bobCdpId));
        assertFalse(liquidationEngine.isCDPLiquidatable(charlieCdpId));
    }
    
    /**
     * @dev Test liquidation scenario with multiple liquidators
     */
    function test_LiquidationScenario_MultipleLiquidators() public {
        uint256 wethAmount = 10 * 10**18;
        uint256 daiAmount = 8000 * 10**18; // High debt ratio
        
        // Setup CDP
        vm.startPrank(alice);
        uint256 cdpId = cdpManager.openCDP(address(weth), wethAmount);
        cdpManager.mintStablecoin(cdpId, daiAmount);
        vm.stopPrank();
        
        // Setup liquidators
        address liquidator1 = makeAddr("liquidator1");
        address liquidator2 = makeAddr("liquidator2");
        
        stablecoin.mint(liquidator1, daiAmount / 2);
        stablecoin.mint(liquidator2, daiAmount / 2);
        
        vm.startPrank(liquidator1);
        stablecoin.approve(address(liquidationEngine), daiAmount / 2);
        vm.stopPrank();
        
        vm.startPrank(liquidator2);
        stablecoin.approve(address(liquidationEngine), daiAmount / 2);
        vm.stopPrank();
        
        // First liquidator liquidates half
        vm.startPrank(liquidator1);
        liquidationEngine.liquidateCDP(cdpId);
        vm.stopPrank();
        
        // Verify partial liquidation
        assertTrue(cdpManager.getCDPDebt(cdpId) > 0);
        assertTrue(cdpManager.getCDPCollateralAmount(cdpId) > 0);
        
        // Second liquidator liquidates remaining
        vm.startPrank(liquidator2);
        liquidationEngine.liquidateCDP(cdpId);
        vm.stopPrank();
        
        // Verify complete liquidation
        assertEq(cdpManager.getCDPDebt(cdpId), 0);
        assertEq(cdpManager.getCDPCollateralAmount(cdpId), 0);
    }
    
    /**
     * @dev Test stress scenario with many CDPs and operations
     */
    function test_StressScenario_ManyCDPsAndOperations() public {
        uint256 numCDPs = 10;
        uint256[] memory cdpIds = new uint256[](numCDPs);
        
        // Create multiple CDPs
        for (uint256 i = 0; i < numCDPs; i++) {
            address user = makeAddr(string(abi.encodePacked("user", i)));
            weth.mint(user, 100 * 10**18);
            
            vm.startPrank(user);
            weth.approve(address(cdpManager), type(uint256).max);
            cdpIds[i] = cdpManager.openCDP(address(weth), 10 * 10**18);
            cdpManager.mintStablecoin(cdpIds[i], 5000 * 10**18);
            vm.stopPrank();
        }
        
        // Perform various operations on all CDPs
        for (uint256 i = 0; i < numCDPs; i++) {
            address user = makeAddr(string(abi.encodePacked("user", i)));
            
            vm.startPrank(user);
            // Deposit more collateral
            cdpManager.depositCollateral(cdpIds[i], 5 * 10**18);
            // Repay some debt
            cdpManager.repayDebt(cdpIds[i], 1000 * 10**18);
            // Withdraw some collateral
            cdpManager.withdrawCollateral(cdpIds[i], 2 * 10**18);
            vm.stopPrank();
        }
        
        // Verify all CDPs are still valid
        for (uint256 i = 0; i < numCDPs; i++) {
            assertTrue(cdpManager.getCDPOwner(cdpIds[i]) != address(0));
            assertTrue(cdpManager.getCDPDebt(cdpIds[i]) > 0);
            assertTrue(cdpManager.getCDPCollateralAmount(cdpIds[i]) > 0);
        }
    }
    
    /**
     * @dev Test emergency scenario with system parameter updates
     */
    function test_EmergencyScenario_SystemParameterUpdates() public {
        // Setup multiple CDPs
        vm.startPrank(alice);
        uint256 aliceCdpId = cdpManager.openCDP(address(weth), 20 * 10**18);
        cdpManager.mintStablecoin(aliceCdpId, 10000 * 10**18);
        vm.stopPrank();
        
        vm.startPrank(bob);
        uint256 bobCdpId = cdpManager.openCDP(address(wbtc), 2 * 10**18);
        cdpManager.mintStablecoin(bobCdpId, 8000 * 10**18);
        vm.stopPrank();
        
        // Emergency: Update liquidation ratios significantly
        vm.startPrank(admin);
        collateralRegistry.updateCollateralParams(
            address(weth),
            WETH_LIQUIDATION_RATIO + 100, // Increase to 250%
            WETH_LIQUIDATION_PENALTY + 10, // Increase penalty
            WETH_MAX_LIQUIDATION_RATIO + 100
        );
        collateralRegistry.updateCollateralParams(
            address(wbtc),
            WBTC_LIQUIDATION_RATIO + 150, // Increase to 350%
            WBTC_LIQUIDATION_PENALTY + 15, // Increase penalty
            WBTC_MAX_LIQUIDATION_RATIO + 150
        );
        vm.stopPrank();
        
        // Both CDPs should now be liquidatable
        assertTrue(liquidationEngine.isCDPLiquidatable(aliceCdpId));
        assertTrue(liquidationEngine.isCDPLiquidatable(bobCdpId));
        
        // Setup liquidators
        stablecoin.mint(liquidator, 20000 * 10**18);
        vm.startPrank(liquidator);
        stablecoin.approve(address(liquidationEngine), 20000 * 10**18);
        vm.stopPrank();
        
        // Liquidate both CDPs
        vm.startPrank(liquidator);
        liquidationEngine.liquidateCDP(aliceCdpId);
        liquidationEngine.liquidateCDP(bobCdpId);
        vm.stopPrank();
        
        // Verify both CDPs are liquidated
        assertEq(cdpManager.getCDPDebt(aliceCdpId), 0);
        assertEq(cdpManager.getCDPDebt(bobCdpId), 0);
    }
    
    /**
     * @dev Test system resilience and recovery
     */
    function test_SystemResilience_Recovery() public {
        // Setup initial state
        vm.startPrank(alice);
        uint256 cdpId = cdpManager.openCDP(address(weth), 10 * 10**18);
        cdpManager.mintStablecoin(cdpId, 6000 * 10**18);
        vm.stopPrank();
        
        // Simulate market crash
        vm.startPrank(admin);
        collateralRegistry.updateCollateralParams(
            address(weth),
            WETH_LIQUIDATION_RATIO + 200, // Increase to 350%
            WETH_LIQUIDATION_PENALTY + 20, // Increase penalty
            WETH_MAX_LIQUIDATION_RATIO + 200
        );
        vm.stopPrank();
        
        // CDP should be liquidatable
        assertTrue(liquidationEngine.isCDPLiquidatable(cdpId));
        
        // Setup liquidator
        stablecoin.mint(liquidator, 6000 * 10**18);
        vm.startPrank(liquidator);
        stablecoin.approve(address(liquidationEngine), 6000 * 10**18);
        vm.stopPrank();
        
        // Liquidate CDP
        vm.startPrank(liquidator);
        liquidationEngine.liquidateCDP(cdpId);
        vm.stopPrank();
        
        // System should recover - new CDPs should work
        vm.startPrank(alice);
        uint256 newCdpId = cdpManager.openCDP(address(weth), 5 * 10**18);
        cdpManager.mintStablecoin(newCdpId, 2000 * 10**18);
        vm.stopPrank();
        
        assertTrue(cdpManager.getCDPOwner(newCdpId) == alice);
        assertEq(cdpManager.getCDPDebt(newCdpId), 2000 * 10**18);
    }
    
    /**
     * @dev Test gas efficiency across complete workflows
     */
    function test_GasEfficiency_CompleteWorkflows() public {
        uint256 gasStart = gasleft();
        
        // Complete user journey
        vm.startPrank(alice);
        uint256 cdpId = cdpManager.openCDP(address(weth), 10 * 10**18);
        cdpManager.mintStablecoin(cdpId, 6000 * 10**18);
        cdpManager.depositCollateral(cdpId, 5 * 10**18);
        cdpManager.repayDebt(cdpId, 2000 * 10**18);
        cdpManager.withdrawCollateral(cdpId, 3 * 10**18);
        cdpManager.repayDebt(cdpId, cdpManager.getCDPDebt(cdpId));
        cdpManager.withdrawCollateral(cdpId, cdpManager.getCDPCollateralAmount(cdpId));
        vm.stopPrank();
        
        uint256 gasUsed = gasStart - gasleft();
        
        // Gas usage should be reasonable for complete workflow
        assertLt(gasUsed, 3000000); // Less than 3M gas
    }
}
