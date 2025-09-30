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
    
    address public admin = makeAddr("admin");
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
        collateralRegistry = new CollateralRegistry(admin);
        
        // Setup roles
        vm.startPrank(admin);
        collateralRegistry.grantRole(collateralRegistry.REGISTRAR_ROLE(), registrar);
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
        vm.assume(liquidationRatio >= 100 && liquidationRatio <= 1000); // 100% to 1000%
        vm.assume(liquidationPenalty >= 0 && liquidationPenalty <= 50); // 0% to 50%
        vm.assume(maxLiquidationRatio >= liquidationRatio && maxLiquidationRatio <= 2000); // Max 2000%
        
        vm.startPrank(registrar);
        collateralRegistry.registerCollateral(
            collateral,
            liquidationRatio,
            liquidationPenalty,
            maxLiquidationRatio
        );
        vm.stopPrank();
        
        assertTrue(collateralRegistry.isCollateralRegistered(collateral));
        assertEq(collateralRegistry.getLiquidationRatio(collateral), liquidationRatio);
        assertEq(collateralRegistry.getLiquidationPenalty(collateral), liquidationPenalty);
        assertEq(collateralRegistry.getMaxLiquidationRatio(collateral), maxLiquidationRatio);
    }
    
    /**
     * @dev Fuzz test for unregistering collaterals
     */
    function testFuzz_UnregisterCollateral_VariousCollaterals(address collateral) public {
        vm.assume(collateral != address(0));
        
        // First register the collateral
        vm.startPrank(registrar);
        collateralRegistry.registerCollateral(collateral, 150, 10, 200);
        assertTrue(collateralRegistry.isCollateralRegistered(collateral));
        
        // Then unregister it
        collateralRegistry.unregisterCollateral(collateral);
        assertFalse(collateralRegistry.isCollateralRegistered(collateral));
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
        vm.assume(newLiquidationRatio >= 100 && newLiquidationRatio <= 1000);
        vm.assume(newLiquidationPenalty >= 0 && newLiquidationPenalty <= 50);
        vm.assume(newMaxLiquidationRatio >= newLiquidationRatio && newMaxLiquidationRatio <= 2000);
        
        // First register the collateral
        vm.startPrank(registrar);
        collateralRegistry.registerCollateral(collateral, 150, 10, 200);
        
        // Update parameters
        collateralRegistry.updateCollateralParameters(
            collateral,
            newLiquidationRatio,
            newLiquidationPenalty,
            newMaxLiquidationRatio
        );
        vm.stopPrank();
        
        assertEq(collateralRegistry.getLiquidationRatio(collateral), newLiquidationRatio);
        assertEq(collateralRegistry.getLiquidationPenalty(collateral), newLiquidationPenalty);
        assertEq(collateralRegistry.getMaxLiquidationRatio(collateral), newMaxLiquidationRatio);
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
            
            collateralRegistry.registerCollateral(
                collateral,
                liquidationRatio,
                liquidationPenalty,
                maxLiquidationRatio
            );
            
            assertTrue(collateralRegistry.isCollateralRegistered(collateral));
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
        vm.assume(liquidationRatio == 100); // Minimum 100%
        vm.assume(liquidationPenalty == 0); // Minimum 0%
        vm.assume(maxLiquidationRatio == liquidationRatio); // Minimum max ratio
        
        vm.startPrank(registrar);
        collateralRegistry.registerCollateral(
            collateral,
            liquidationRatio,
            liquidationPenalty,
            maxLiquidationRatio
        );
        vm.stopPrank();
        
        assertTrue(collateralRegistry.isCollateralRegistered(collateral));
    }
    
    /**
     * @dev Fuzz test for role management
     */
    function testFuzz_RoleManagement(address account) public {
        vm.assume(account != address(0) && account != admin);
        
        // Grant registrar role
        vm.startPrank(admin);
        collateralRegistry.grantRole(collateralRegistry.REGISTRAR_ROLE(), account);
        assertTrue(collateralRegistry.hasRole(collateralRegistry.REGISTRAR_ROLE(), account));
        
        // Revoke registrar role
        collateralRegistry.revokeRole(collateralRegistry.REGISTRAR_ROLE(), account);
        assertFalse(collateralRegistry.hasRole(collateralRegistry.REGISTRAR_ROLE(), account));
        vm.stopPrank();
    }
    
    /**
     * @dev Fuzz test for gas optimization
     */
    function testFuzz_GasOptimization(address collateral) public {
        vm.assume(collateral != address(0));
        
        uint256 gasStart = gasleft();
        
        vm.startPrank(registrar);
        collateralRegistry.registerCollateral(collateral, 150, 10, 200);
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
            vm.assume(liquidationRatios[i] >= 100 && liquidationRatios[i] <= 1000);
            vm.assume(liquidationPenalties[i] >= 0 && liquidationPenalties[i] <= 50);
            vm.assume(maxLiquidationRatios[i] >= liquidationRatios[i] && maxLiquidationRatios[i] <= 2000);
            
            collateralRegistry.registerCollateral(
                collaterals[i],
                liquidationRatios[i],
                liquidationPenalties[i],
                maxLiquidationRatios[i]
            );
        }
        
        // Update parameters for first collateral
        collateralRegistry.updateCollateralParameters(
            collaterals[0],
            liquidationRatios[0] + 50,
            liquidationPenalties[0] + 5,
            maxLiquidationRatios[0] + 100
        );
        
        // Unregister second collateral
        collateralRegistry.unregisterCollateral(collaterals[1]);
        
        vm.stopPrank();
        
        // Verify final state
        assertTrue(collateralRegistry.isCollateralRegistered(collaterals[0]));
        assertFalse(collateralRegistry.isCollateralRegistered(collaterals[1]));
        assertTrue(collateralRegistry.isCollateralRegistered(collaterals[2]));
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
            
            collateralRegistry.registerCollateral(
                collateral,
                liquidationRatio,
                liquidationPenalty,
                maxLiquidationRatio
            );
            
            // Every 5th operation, update parameters
            if (i % 5 == 0 && i > 0) {
                collateralRegistry.updateCollateralParameters(
                    collateral,
                    liquidationRatio + 25,
                    liquidationPenalty + 2,
                    maxLiquidationRatio + 50
                );
            }
        }
        
        vm.stopPrank();
        
        // Verify all collaterals are registered
        for (uint256 i = 0; i < operations; i++) {
            address collateral = address(uint160(i + 1));
            assertTrue(collateralRegistry.isCollateralRegistered(collateral));
        }
    }
}
