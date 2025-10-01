// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CollateralRegistry} from "../../src/core/CollateralRegistry.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";

/**
 * @title CollateralRegistryFuzzTest
 * @dev Comprehensive fuzz testing for CollateralRegistry contract
 * @notice Tests edge cases, boundary conditions, and random inputs for collateral management
 */
contract CollateralRegistryFuzzTest is Test {
    CollateralRegistry public collateralRegistry;
    
    address public admin = address(this);
    address public registrar = makeAddr("registrar");
    
    event CollateralRegistered(
        address indexed collateral,
        uint256 liquidationRatio,
        uint256 liquidationPenalty,
        uint256 maxLiquidationRatio
    );
    event CollateralUnregistered(address indexed collateral);
    event CollateralParametersUpdated(
        address indexed collateral,
        uint256 liquidationRatio,
        uint256 liquidationPenalty,
        uint256 maxLiquidationRatio
    );
    
    function setUp() public {
        collateralRegistry = new CollateralRegistry();
        
        // Setup roles
        vm.startPrank(admin);
        collateralRegistry.grantRole(collateralRegistry.COLLATERAL_MANAGER_ROLE(), registrar);
        vm.stopPrank();
    }
    
    /**
     * @dev Fuzz test for registering collaterals with various parameters
     */
    function testFuzz_RegisterCollateral_VariousParameters(
        address collateral,
        uint256 liquidationRatio,
        uint256 liquidationPenalty,
        uint256 maxLiquidationRatio
    ) public {
        vm.assume(collateral != address(0));
        vm.assume(liquidationRatio >= 10000 && liquidationRatio <= 50000); // 100% to 500% in basis points
        vm.assume(liquidationPenalty >= 0 && liquidationPenalty <= 5000); // 0% to 50% in basis points
        vm.assume(maxLiquidationRatio >= liquidationRatio && maxLiquidationRatio <= 100000); // Max 1000% in basis points
        
        vm.startPrank(registrar);
        collateralRegistry.addCollateral(
            collateral,
            liquidationRatio, // Already in basis points
            200, // 2% stability fee
            liquidationPenalty, // Already in basis points
            1000000 * 10**18 // 1M debt ceiling
        );
        vm.stopPrank();
        
        assertTrue(collateralRegistry.isCollateralActive(collateral));
        assertEq(collateralRegistry.getLiquidationRatio(collateral), liquidationRatio);
        assertEq(collateralRegistry.getStabilityFee(collateral), 200);
        assertEq(collateralRegistry.getDebtCeiling(collateral), 1000000 * 10**18);
    }
    
    /**
     * @dev Fuzz test for unregistering collaterals
     */
    function testFuzz_UnregisterCollateral_VariousCollaterals(address collateral) public {
        vm.assume(collateral != address(0));
        
        // First register the collateral
        vm.startPrank(registrar);
        collateralRegistry.addCollateral(collateral, 15000, 200, 1000, 1000000 * 10**18);
        assertTrue(collateralRegistry.isCollateralActive(collateral));
        
        // Then unregister it
        collateralRegistry.removeCollateral(collateral);
        assertFalse(collateralRegistry.isCollateralActive(collateral));
        vm.stopPrank();
    }
    
    /**
     * @dev Fuzz test for updating collateral parameters
     */
    function testFuzz_UpdateCollateralParameters_VariousValues(
        address collateral,
        uint256 newLiquidationRatio,
        uint256 newLiquidationPenalty,
        uint256 newMaxLiquidationRatio
    ) public {
        vm.assume(collateral != address(0));
        vm.assume(newLiquidationRatio >= 10000 && newLiquidationRatio <= 50000);
        vm.assume(newLiquidationPenalty >= 0 && newLiquidationPenalty <= 5000);
        vm.assume(newMaxLiquidationRatio >= newLiquidationRatio && newMaxLiquidationRatio <= 100000);
        
        // First register the collateral
        vm.startPrank(registrar);
        collateralRegistry.addCollateral(collateral, 15000, 200, 1000, 1000000 * 10**18);
        
        // Update parameters
        collateralRegistry.updateCollateralParams(
            collateral,
            newLiquidationRatio, // Already in basis points
            200, // 2% stability fee
            newLiquidationPenalty // Already in basis points
        );
        vm.stopPrank();
        
        assertEq(collateralRegistry.getLiquidationRatio(collateral), newLiquidationRatio);
        assertEq(collateralRegistry.getStabilityFee(collateral), 200);
        assertEq(collateralRegistry.getDebtCeiling(collateral), 1000000 * 10**18);
    }
    
    /**
     * @dev Fuzz test for multiple collateral registrations
     */
    function testFuzz_MultipleCollateralRegistrations(uint256 count) public {
        vm.assume(count > 0 && count <= 10); // Reasonable limit for testing
        
        vm.startPrank(registrar);
        
        for (uint256 i = 0; i < count; i++) {
            address collateral = address(uint160(i + 1)); // Generate unique addresses
            uint256 liquidationRatio = 100 + (i * 50); // Vary ratios
            uint256 liquidationPenalty = i * 5; // Vary penalties
            uint256 maxLiquidationRatio = liquidationRatio + 100;
            
            collateralRegistry.addCollateral(
                collateral,
                liquidationRatio * 100, // Convert to basis points
                200, // 2% stability fee
                liquidationPenalty * 100, // Convert to basis points
                1000000 * 10**18 // 1M debt ceiling
            );
            
            assertTrue(collateralRegistry.isCollateralActive(collateral));
        }
        
        vm.stopPrank();
    }
    
    /**
     * @dev Fuzz test for boundary conditions
     */
    function testFuzz_BoundaryConditions(
        uint256 liquidationRatio,
        uint256 liquidationPenalty,
        uint256 maxLiquidationRatio
    ) public {
        address collateral = makeAddr("collateral");
        
        // Test minimum values
        vm.assume(liquidationRatio == 10000); // Minimum 100% in basis points
        vm.assume(liquidationPenalty == 0); // Minimum 0%
        vm.assume(maxLiquidationRatio == liquidationRatio); // Minimum max ratio
        
        vm.startPrank(registrar);
        collateralRegistry.addCollateral(
            collateral,
            liquidationRatio, // Already in basis points
            200, // 2% stability fee
            liquidationPenalty, // Already in basis points
            1000000 * 10**18 // 1M debt ceiling
        );
        vm.stopPrank();
        
        assertTrue(collateralRegistry.isCollateralActive(collateral));
    }
    
    /**
     * @dev Fuzz test for role management
     */
    function testFuzz_RoleManagement(address account) public {
        vm.assume(account != address(0) && account != admin);
        
        // Grant registrar role
        vm.startPrank(admin);
        collateralRegistry.grantRole(collateralRegistry.COLLATERAL_MANAGER_ROLE(), account);
        assertTrue(collateralRegistry.hasRole(collateralRegistry.COLLATERAL_MANAGER_ROLE(), account));
        
        // Revoke registrar role
        collateralRegistry.revokeRole(collateralRegistry.COLLATERAL_MANAGER_ROLE(), account);
        assertFalse(collateralRegistry.hasRole(collateralRegistry.COLLATERAL_MANAGER_ROLE(), account));
        vm.stopPrank();
    }
    
    /**
     * @dev Fuzz test for gas optimization
     */
    function testFuzz_GasOptimization(address collateral) public {
        vm.assume(collateral != address(0));
        
        uint256 gasStart = gasleft();
        
        vm.startPrank(registrar);
        collateralRegistry.addCollateral(collateral, 15000, 200, 1000, 1000000 * 10**18);
        vm.stopPrank();
        
        uint256 gasUsed = gasStart - gasleft();
        
        // Gas usage should be reasonable (less than 200k gas)
        assertLt(gasUsed, 200000);
    }
    
    /**
     * @dev Fuzz test for complex collateral management
     */
    function testFuzz_ComplexCollateralManagement(
        address[3] memory collaterals,
        uint256[3] memory liquidationRatios,
        uint256[3] memory liquidationPenalties,
        uint256[3] memory maxLiquidationRatios
    ) public {
        vm.assume(collaterals[0] != address(0) && collaterals[1] != address(0) && collaterals[2] != address(0));
        vm.assume(collaterals[0] != collaterals[1] && collaterals[1] != collaterals[2] && collaterals[0] != collaterals[2]);
        
        vm.startPrank(registrar);
        
        // Register all collaterals
        for (uint256 i = 0; i < 3; i++) {
            vm.assume(liquidationRatios[i] >= 10000 && liquidationRatios[i] <= 50000);
            vm.assume(liquidationPenalties[i] >= 0 && liquidationPenalties[i] <= 5000);
            vm.assume(maxLiquidationRatios[i] >= liquidationRatios[i] && maxLiquidationRatios[i] <= 100000);
            
            collateralRegistry.addCollateral(
                collaterals[i],
                liquidationRatios[i], // Already in basis points
                200, // 2% stability fee
                liquidationPenalties[i], // Already in basis points
                1000000 * 10**18 // 1M debt ceiling
            );
        }
        
        // Update parameters for first collateral
            collateralRegistry.updateCollateralParams(
                collaterals[0],
                liquidationRatios[0] + 5000, // Add 50% in basis points
                200, // 2% stability fee
                liquidationPenalties[0] + 500 // Add 5% in basis points
            );
        
        // Unregister second collateral
        collateralRegistry.removeCollateral(collaterals[1]);
        
        vm.stopPrank();
        
        // Verify final state
        assertTrue(collateralRegistry.isCollateralActive(collaterals[0]));
        assertFalse(collateralRegistry.isCollateralActive(collaterals[1]));
        assertTrue(collateralRegistry.isCollateralActive(collaterals[2]));
    }
    
    /**
     * @dev Fuzz test for stress testing with many operations
     */
    function testFuzz_StressTesting(uint256 operations) public {
        vm.assume(operations > 0 && operations <= 50); // Reasonable limit
        
        vm.startPrank(registrar);
        
        for (uint256 i = 0; i < operations; i++) {
            address collateral = address(uint160(i + 1));
            uint256 liquidationRatio = 100 + (i % 900); // 100% to 1000%
            uint256 liquidationPenalty = i % 51; // 0% to 50%
            uint256 maxLiquidationRatio = liquidationRatio + 100;
            
            collateralRegistry.addCollateral(
                collateral,
                liquidationRatio * 100, // Convert to basis points
                200, // 2% stability fee
                liquidationPenalty * 100, // Convert to basis points
                1000000 * 10**18 // 1M debt ceiling
            );
            
            // Every 5th operation, update parameters
            if (i % 5 == 0 && i > 0) {
                collateralRegistry.updateCollateralParams(
                    collateral,
                    liquidationRatio + 2500, // Add 25% in basis points
                    200, // 2% stability fee
                    liquidationPenalty + 200 // Add 2% in basis points
                );
            }
        }
        
        vm.stopPrank();
        
        // Verify all collaterals are registered
        for (uint256 i = 0; i < operations; i++) {
            address collateral = address(uint160(i + 1));
            assertTrue(collateralRegistry.isCollateralActive(collateral));
        }
    }
}
