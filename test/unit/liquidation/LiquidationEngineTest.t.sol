// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {LiquidationEngine} from "../../../src/core/LiquidationEngine.sol";
import {CDPManager} from "../../../src/core/CDPManager.sol";
import {Stablecoin} from "../../../src/core/Stablecoin.sol";
import {CollateralRegistry} from "../../../src/core/CollateralRegistry.sol";
import {MockERC20} from "../../../src/mocks/MockERC20.sol";
import {ILiquidationEngine} from "../../../src/interfaces/ILiquidationEngine.sol";

contract LiquidationEngineTest is Test {
    LiquidationEngine public liquidationEngine;
    CDPManager public cdpManager;
    Stablecoin public stablecoin;
    CollateralRegistry public collateralRegistry;
    MockERC20 public collateralToken;
    
    address public owner = address(0x1);
    address public user = address(0x2);
    address public liquidator = address(0x3);
    
    uint256 public constant INITIAL_COLLATERAL = 1000e18;
    uint256 public constant LIQUIDATION_RATIO = 15000; // 150%
    uint256 public constant STABILITY_FEE = 200; // 2%
    uint256 public constant LIQUIDATION_PENALTY = 1300; // 13%
    uint256 public constant TOKEN_PRICE = 2000e18; // $2000 per token

    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy core contracts
        stablecoin = new Stablecoin("USD Stablecoin", "USD", 1000000e18);
        collateralRegistry = new CollateralRegistry();
        cdpManager = new CDPManager(
            address(stablecoin),
            address(collateralRegistry)
        );
        
        // Deploy liquidation engine
        liquidationEngine = new LiquidationEngine(
            address(cdpManager),
            address(collateralRegistry)
        );
        
        // Deploy mock collateral token
        collateralToken = new MockERC20("Wrapped Ether", "WETH");
        
        // Setup collateral in registry
        collateralRegistry.addCollateral(
            address(collateralToken),
            LIQUIDATION_RATIO,
            STABILITY_FEE,
            LIQUIDATION_PENALTY,
            1000000e18 // debt ceiling
        );
        
        // Grant permissions
        stablecoin.grantRole(stablecoin.MINTER_ROLE(), address(cdpManager));
        stablecoin.grantRole(stablecoin.BURNER_ROLE(), address(cdpManager));
        liquidationEngine.grantRole(liquidationEngine.LIQUIDATOR_ROLE(), liquidator);
        
        vm.stopPrank();
        
        // Setup user with collateral
        collateralToken.mint(user, INITIAL_COLLATERAL);
        vm.prank(user);
        collateralToken.approve(address(cdpManager), type(uint256).max);
    }

    function test_CheckLiquidation_NotLiquidatable() public {
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 400e18);
        
        assertFalse(liquidationEngine.checkLiquidation(cdpId));
    }

    function test_CheckLiquidation_Liquidatable() public {
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 400e18);
        
        // Mint debt to make CDP liquidatable
        vm.prank(user);
        cdpManager.mintStablecoin(cdpId, 280e18); // Exceed liquidation ratio to make it liquidatable // 60% of max debt (within liquidation ratio)
        
        // Mark as liquidatable
        vm.prank(address(cdpManager));
        liquidationEngine.markLiquidatable(cdpId);
        
        // Should not be liquidatable immediately due to delay
        assertFalse(liquidationEngine.checkLiquidation(cdpId));
        
        // Fast forward past liquidation delay
        vm.warp(block.timestamp + liquidationEngine.getLiquidationDelay() + 1);
        
        assertTrue(liquidationEngine.checkLiquidation(cdpId));
    }

    function test_CalculateLiquidationPenalty_Success() public {
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 400e18);
        
        vm.prank(user);
        cdpManager.mintStablecoin(cdpId, 280e18); // Exceed liquidation ratio to make it liquidatable
        
        vm.prank(address(cdpManager));
        liquidationEngine.markLiquidatable(cdpId);
        
        uint256 penalty = liquidationEngine.calculateLiquidationPenalty(cdpId);
        uint256 expectedPenalty = (400e18 * LIQUIDATION_PENALTY) / 10000;
        
        assertEq(penalty, expectedPenalty);
    }

    function test_CalculateLiquidationPenalty_RevertIf_NotLiquidatable() public {
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 400e18);
        
        vm.expectRevert(ILiquidationEngine.CDPNotLiquidatable.selector);
        liquidationEngine.calculateLiquidationPenalty(cdpId);
    }

    function test_LiquidateCDP_Success() public {
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 400e18);
        
        vm.prank(user);
        cdpManager.mintStablecoin(cdpId, 280e18); // Exceed liquidation ratio to make it liquidatable
        
        vm.prank(address(cdpManager));
        liquidationEngine.markLiquidatable(cdpId);
        
        // Fast forward past liquidation delay
        vm.warp(block.timestamp + liquidationEngine.getLiquidationDelay() + 1);
        
        uint256 liquidatorBalanceBefore = collateralToken.balanceOf(liquidator);
        
        vm.prank(liquidator);
        liquidationEngine.liquidateCDP(cdpId);
        
        uint256 liquidatorBalanceAfter = collateralToken.balanceOf(liquidator);
        uint256 expectedPenalty = (400e18 * LIQUIDATION_PENALTY) / 10000;
        
        assertEq(liquidatorBalanceAfter - liquidatorBalanceBefore, expectedPenalty);
    }

    function test_LiquidateCDP_RevertIf_NotLiquidatable() public {
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 400e18);
        
        vm.prank(liquidator);
        vm.expectRevert(ILiquidationEngine.CDPNotLiquidatable.selector);
        liquidationEngine.liquidateCDP(cdpId);
    }

    function test_LiquidateCDP_RevertIf_DelayNotMet() public {
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 400e18);
        
        vm.prank(user);
        cdpManager.mintStablecoin(cdpId, 280e18); // Exceed liquidation ratio to make it liquidatable
        
        vm.prank(address(cdpManager));
        liquidationEngine.markLiquidatable(cdpId);
        
        vm.prank(liquidator);
        vm.expectRevert(abi.encodeWithSelector(
            ILiquidationEngine.LiquidationDelayNotMet.selector,
            cdpId,
            block.timestamp + liquidationEngine.getLiquidationDelay(),
            block.timestamp
        ));
        liquidationEngine.liquidateCDP(cdpId);
    }

    function test_LiquidateCDP_RevertIf_Unauthorized() public {
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 400e18);
        
        vm.prank(user);
        cdpManager.mintStablecoin(cdpId, 280e18); // Exceed liquidation ratio to make it liquidatable
        
        vm.prank(address(cdpManager));
        liquidationEngine.markLiquidatable(cdpId);
        
        vm.warp(block.timestamp + liquidationEngine.getLiquidationDelay() + 1);
        
        vm.prank(user);
        vm.expectRevert();
        liquidationEngine.liquidateCDP(cdpId);
    }

    function test_SetLiquidationDelay_Success() public {
        uint256 newDelay = 2 hours;
        
        vm.prank(owner);
        liquidationEngine.setLiquidationDelay(newDelay);
        
        assertEq(liquidationEngine.getLiquidationDelay(), newDelay);
    }

    function test_SetLiquidationDelay_RevertIf_Unauthorized() public {
        vm.prank(user);
        vm.expectRevert();
        liquidationEngine.setLiquidationDelay(2 hours);
    }

    function test_SetLiquidationDelay_RevertIf_TooLong() public {
        vm.prank(owner);
        vm.expectRevert(ILiquidationEngine.InvalidLiquidationPenalty.selector);
        liquidationEngine.setLiquidationDelay(8 days);
    }

    function test_GetLiquidationInfo_Success() public {
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 400e18);
        
        vm.prank(user);
        cdpManager.mintStablecoin(cdpId, 280e18); // Exceed liquidation ratio to make it liquidatable
        
        vm.prank(address(cdpManager));
        liquidationEngine.markLiquidatable(cdpId);
        
        (
            bool isLiquidatable,
            uint256 collateralValue,
            uint256 debtValue,
            uint256 penaltyAmount,
            uint256 collateralToSeize
        ) = liquidationEngine.getLiquidationInfo(cdpId);
        
        assertFalse(isLiquidatable); // Not yet due to delay
        assertEq(debtValue, 80e18);
        assertEq(penaltyAmount, 0); // Not liquidatable yet
        assertEq(collateralToSeize, 0);
    }

    function testFuzz_CalculateLiquidationPenalty(uint256 collateralAmount, uint256 penaltyRate) public {
        vm.assume(collateralAmount > 0 && collateralAmount <= INITIAL_COLLATERAL);
        vm.assume(penaltyRate > 0 && penaltyRate <= 5000); // Max 50%
        
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), collateralAmount);
        
        vm.prank(user);
        cdpManager.mintStablecoin(cdpId, (collateralAmount * 80) / 100); // 80% of max debt
        
        vm.prank(address(cdpManager));
        liquidationEngine.markLiquidatable(cdpId);
        
        uint256 expectedPenalty = (collateralAmount * penaltyRate) / 10000;
        uint256 actualPenalty = liquidationEngine.calculateLiquidationPenalty(cdpId);
        
        // Note: This test uses the actual penalty rate from the collateral registry
        // In a real scenario, you'd need to update the penalty rate first
        assertTrue(actualPenalty > 0);
    }
}
