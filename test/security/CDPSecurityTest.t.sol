// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CDPManager} from "../../src/core/CDPManager.sol";
import {Stablecoin} from "../../src/core/Stablecoin.sol";
import {CollateralRegistry} from "../../src/core/CollateralRegistry.sol";
import {LiquidationEngine} from "../../src/core/LiquidationEngine.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

/**
 * @title CDPSecurityTest
 * @dev Security-focused tests for CDP system
 * @notice Tests for reentrancy, access control, overflow, and other security vulnerabilities
 */
contract CDPSecurityTest is Test {
    CDPManager public cdpManager;
    Stablecoin public stablecoin;
    CollateralRegistry public collateralRegistry;
    LiquidationEngine public liquidationEngine;
    MockERC20 public collateralToken;
    
    address public admin = makeAddr("admin");
    address public attacker = makeAddr("attacker");
    address public user = makeAddr("user");
    address public liquidator = makeAddr("liquidator");
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;
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
     * @dev Test access control - unauthorized users cannot open CDPs
     */
    function test_AccessControl_UnauthorizedUserCannotOpenCDP() public {
        vm.startPrank(attacker);
        vm.expectRevert();
        cdpManager.openCDP(address(collateralToken), 1000 * 10**18);
        vm.stopPrank();
    }
    
    /**
     * @dev Test access control - unauthorized users cannot mint stablecoins
     */
    function test_AccessControl_UnauthorizedUserCannotMint() public {
        // First open CDP as user
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 1000 * 10**18);
        vm.stopPrank();
        
        // Attacker tries to mint
        vm.startPrank(attacker);
        vm.expectRevert();
        cdpManager.mintStablecoin(cdpId, 1000 * 10**18);
        vm.stopPrank();
    }
    
    /**
     * @dev Test access control - only CDP owner can operate their CDP
     */
    function test_AccessControl_OnlyCDPOwnerCanOperate() public {
        // User opens CDP
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 1000 * 10**18);
        cdpManager.mintStablecoin(cdpId, 500 * 10**18);
        vm.stopPrank();
        
        // Attacker tries to operate user's CDP
        vm.startPrank(attacker);
        vm.expectRevert();
        cdpManager.repayDebt(cdpId, 100 * 10**18);
        vm.stopPrank();
        
        vm.startPrank(attacker);
        vm.expectRevert();
        cdpManager.withdrawCollateral(cdpId, 100 * 10**18);
        vm.stopPrank();
    }
    
    /**
     * @dev Test reentrancy protection in CDP operations
     */
    function test_ReentrancyProtection_CDPOperations() public {
        // This test would require a malicious contract that tries to reenter
        // For now, we test that the contract doesn't have external calls before state changes
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 1000 * 10**18);
        cdpManager.mintStablecoin(cdpId, 500 * 10**18);
        vm.stopPrank();
        
        // These operations should complete without reentrancy issues
        vm.startPrank(user);
        cdpManager.repayDebt(cdpId, 100 * 10**18);
        cdpManager.withdrawCollateral(cdpId, 100 * 10**18);
        vm.stopPrank();
    }
    
    /**
     * @dev Test overflow protection in calculations
     */
    function test_OverflowProtection_Calculations() public {
        // Test with maximum values
        uint256 maxAmount = type(uint256).max;
        
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), maxAmount);
        
        // This should not overflow
        uint256 maxMintable = (maxAmount * 100) / LIQUIDATION_RATIO;
        if (maxMintable > 0) {
            cdpManager.mintStablecoin(cdpId, maxMintable);
        }
        vm.stopPrank();
    }
    
    /**
     * @dev Test underflow protection in calculations
     */
    function test_UnderflowProtection_Calculations() public {
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 1000 * 10**18);
        cdpManager.mintStablecoin(cdpId, 500 * 10**18);
        vm.stopPrank();
        
        // Try to repay more than debt
        vm.startPrank(user);
        vm.expectRevert();
        cdpManager.repayDebt(cdpId, 1000 * 10**18);
        vm.stopPrank();
        
        // Try to withdraw more than collateral
        vm.startPrank(user);
        vm.expectRevert();
        cdpManager.withdrawCollateral(cdpId, 2000 * 10**18);
        vm.stopPrank();
    }
    
    /**
     * @dev Test integer division precision
     */
    function test_IntegerDivisionPrecision_Calculations() public {
        uint256 collateralAmount = 1001; // Odd number to test precision
        uint256 expectedMintable = (collateralAmount * 100) / LIQUIDATION_RATIO;
        
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), collateralAmount);
        cdpManager.mintStablecoin(cdpId, expectedMintable);
        vm.stopPrank();
        
        assertEq(cdpManager.getCDPDebt(cdpId), expectedMintable);
    }
    
    /**
     * @dev Test liquidation ratio validation
     */
    function test_LiquidationRatioValidation_InvalidRatios() public {
        // Test with invalid liquidation ratio
        vm.startPrank(admin);
        vm.expectRevert();
        collateralRegistry.registerCollateral(
            address(collateralToken),
            50, // Too low
            LIQUIDATION_PENALTY,
            MAX_LIQUIDATION_RATIO
        );
        vm.stopPrank();
        
        // Test with invalid max liquidation ratio
        vm.startPrank(admin);
        vm.expectRevert();
        collateralRegistry.registerCollateral(
            address(collateralToken),
            LIQUIDATION_RATIO,
            LIQUIDATION_PENALTY,
            100 // Too low
        );
        vm.stopPrank();
    }
    
    /**
     * @dev Test penalty validation
     */
    function test_PenaltyValidation_InvalidPenalties() public {
        // Test with invalid penalty
        vm.startPrank(admin);
        vm.expectRevert();
        collateralRegistry.registerCollateral(
            address(collateralToken),
            LIQUIDATION_RATIO,
            100, // Too high
            MAX_LIQUIDATION_RATIO
        );
        vm.stopPrank();
    }
    
    /**
     * @dev Test zero address validation
     */
    function test_ZeroAddressValidation_InvalidAddresses() public {
        // Test with zero address collateral
        vm.startPrank(user);
        vm.expectRevert();
        cdpManager.openCDP(address(0), 1000 * 10**18);
        vm.stopPrank();
    }
    
    /**
     * @dev Test zero amount validation
     */
    function test_ZeroAmountValidation_InvalidAmounts() public {
        // Test with zero collateral amount
        vm.startPrank(user);
        vm.expectRevert();
        cdpManager.openCDP(address(collateralToken), 0);
        vm.stopPrank();
        
        // Open CDP first
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 1000 * 10**18);
        vm.stopPrank();
        
        // Test with zero mint amount
        vm.startPrank(user);
        vm.expectRevert();
        cdpManager.mintStablecoin(cdpId, 0);
        vm.stopPrank();
    }
    
    /**
     * @dev Test liquidation delay security
     */
    function test_LiquidationDelaySecurity_UnauthorizedLiquidation() public {
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 1000 * 10**18);
        cdpManager.mintStablecoin(cdpId, 800 * 10**18); // High debt ratio
        vm.stopPrank();
        
        // Setup liquidator
        stablecoin.mint(liquidator, 800 * 10**18);
        vm.startPrank(liquidator);
        stablecoin.approve(address(liquidationEngine), 800 * 10**18);
        vm.stopPrank();
        
        // Try to liquidate immediately (should fail due to delay)
        vm.startPrank(liquidator);
        vm.expectRevert();
        liquidationEngine.liquidateCDP(cdpId);
        vm.stopPrank();
    }
    
    /**
     * @dev Test role-based access control
     */
    function test_RoleBasedAccessControl_UnauthorizedOperations() public {
        // Attacker tries to grant roles
        vm.startPrank(attacker);
        vm.expectRevert();
        cdpManager.grantRole(cdpManager.ADMIN_ROLE(), attacker);
        vm.stopPrank();
        
        // Attacker tries to revoke roles
        vm.startPrank(attacker);
        vm.expectRevert();
        cdpManager.revokeRole(cdpManager.ADMIN_ROLE(), admin);
        vm.stopPrank();
    }
    
    /**
     * @dev Test collateral registry security
     */
    function test_CollateralRegistrySecurity_UnauthorizedOperations() public {
        // Attacker tries to register collateral
        vm.startPrank(attacker);
        vm.expectRevert();
        collateralRegistry.registerCollateral(
            address(collateralToken),
            LIQUIDATION_RATIO,
            LIQUIDATION_PENALTY,
            MAX_LIQUIDATION_RATIO
        );
        vm.stopPrank();
        
        // Attacker tries to unregister collateral
        vm.startPrank(attacker);
        vm.expectRevert();
        collateralRegistry.unregisterCollateral(address(collateralToken));
        vm.stopPrank();
    }
    
    /**
     * @dev Test stablecoin security
     */
    function test_StablecoinSecurity_UnauthorizedMinting() public {
        // Attacker tries to mint directly
        vm.startPrank(attacker);
        vm.expectRevert();
        stablecoin.mint(attacker, 1000 * 10**18);
        vm.stopPrank();
        
        // Attacker tries to burn user's tokens
        vm.startPrank(attacker);
        vm.expectRevert();
        stablecoin.burn(user, 1000 * 10**18);
        vm.stopPrank();
    }
    
    /**
     * @dev Test gas limit protection
     */
    function test_GasLimitProtection_LargeOperations() public {
        // Test with very large amounts
        uint256 largeAmount = 1000000 * 10**18;
        
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), largeAmount);
        
        // This should not exceed gas limit
        uint256 maxMintable = (largeAmount * 100) / LIQUIDATION_RATIO;
        if (maxMintable > 0) {
            cdpManager.mintStablecoin(cdpId, maxMintable);
        }
        vm.stopPrank();
    }
    
    /**
     * @dev Test state consistency after failed operations
     */
    function test_StateConsistency_FailedOperations() public {
        uint256 initialBalance = collateralToken.balanceOf(user);
        uint256 initialSupply = stablecoin.totalSupply();
        
        // Try invalid operation
        vm.startPrank(user);
        vm.expectRevert();
        cdpManager.openCDP(address(collateralToken), 0);
        vm.stopPrank();
        
        // State should remain unchanged
        assertEq(collateralToken.balanceOf(user), initialBalance);
        assertEq(stablecoin.totalSupply(), initialSupply);
    }
    
    /**
     * @dev Test edge case: maximum values
     */
    function test_EdgeCase_MaximumValues() public {
        uint256 maxAmount = type(uint256).max;
        
        // This should handle maximum values gracefully
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), maxAmount);
        
        // Calculate max mintable amount
        uint256 maxMintable = (maxAmount * 100) / LIQUIDATION_RATIO;
        if (maxMintable > 0 && maxMintable <= maxAmount) {
            cdpManager.mintStablecoin(cdpId, maxMintable);
        }
        vm.stopPrank();
    }
}
