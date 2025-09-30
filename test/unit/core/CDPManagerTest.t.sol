// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CDPManager} from "../../../src/core/CDPManager.sol";
import {Stablecoin} from "../../../src/core/Stablecoin.sol";
import {CollateralRegistry} from "../../../src/core/CollateralRegistry.sol";
import {MockERC20} from "../../../src/mocks/MockERC20.sol";
import {ICDPManager} from "../../../src/interfaces/ICDPManager.sol";

contract CDPManagerTest is Test {
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

    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy core contracts
        stablecoin = new Stablecoin("USD Stablecoin", "USD", 1000000e18);
        collateralRegistry = new CollateralRegistry();
        cdpManager = new CDPManager(
            address(stablecoin),
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
        
        vm.stopPrank();
        
        // Setup user with collateral
        collateralToken.mint(user, INITIAL_COLLATERAL);
        vm.prank(user);
        collateralToken.approve(address(cdpManager), type(uint256).max);
    }

    function test_OpenCDP_Success() public {
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 100e18);
        
        assertEq(cdpId, 1);
        assertEq(cdpManager.getCDPOwner(cdpId), user);
        assertEq(cdpManager.getCDPCollateral(cdpId), address(collateralToken));
        assertEq(cdpManager.getCDPCollateralAmount(cdpId), 100e18);
        assertEq(cdpManager.getCDPDebt(cdpId), 0);
    }

    function test_OpenCDP_RevertIf_InvalidCollateral() public {
        MockERC20 invalidToken = new MockERC20("Invalid", "INV");
        
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(
            ICDPManager.InvalidCollateral.selector,
            address(invalidToken)
        ));
        cdpManager.openCDP(address(invalidToken), 100e18);
    }

    function test_OpenCDP_RevertIf_ZeroAmount() public {
        vm.prank(user);
        vm.expectRevert(ICDPManager.InvalidAmount.selector);
        cdpManager.openCDP(address(collateralToken), 0);
    }

    function test_DepositCollateral_Success() public {
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 100e18);
        
        vm.prank(user);
        cdpManager.depositCollateral(cdpId, 50e18);
        
        assertEq(cdpManager.getCDPCollateralAmount(cdpId), 150e18);
    }

    function test_DepositCollateral_RevertIf_NotOwner() public {
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 100e18);
        
        vm.prank(liquidator);
        vm.expectRevert(abi.encodeWithSelector(
            ICDPManager.Unauthorized.selector
        ));
        cdpManager.depositCollateral(cdpId, 50e18);
    }

    function test_MintStablecoin_Success() public {
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 100e18);
        
        vm.prank(user);
        cdpManager.mintStablecoin(cdpId, 50e18);
        
        assertEq(cdpManager.getCDPDebt(cdpId), 50e18);
        assertEq(stablecoin.balanceOf(user), 50e18);
    }

    function test_MintStablecoin_RevertIf_ExceedsLiquidationRatio() public {
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 100e18);
        
        // Try to mint more than liquidation ratio allows
        // With 100e18 collateral at 150% ratio, max debt is ~66.67e18
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(
            ICDPManager.InsufficientCollateral.selector,
            cdpId,
            150e18, // required (100e18 debt * 150% ratio)
            100e18  // available
        ));
        cdpManager.mintStablecoin(cdpId, 100e18);
    }

    function test_RepayDebt_Success() public {
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 100e18);
        
        vm.prank(user);
        cdpManager.mintStablecoin(cdpId, 50e18);
        
        vm.prank(user);
        cdpManager.repayDebt(cdpId, 25e18);
        
        assertEq(cdpManager.getCDPDebt(cdpId), 25e18);
        assertEq(stablecoin.balanceOf(user), 25e18);
    }

    function test_WithdrawCollateral_Success() public {
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 100e18);
        
        vm.prank(user);
        cdpManager.withdrawCollateral(cdpId, 30e18);
        
        assertEq(cdpManager.getCDPCollateralAmount(cdpId), 70e18);
        assertEq(collateralToken.balanceOf(user), INITIAL_COLLATERAL - 70e18);
    }

    function test_WithdrawCollateral_RevertIf_ExceedsLiquidationRatio() public {
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 100e18);
        
        vm.prank(user);
        cdpManager.mintStablecoin(cdpId, 50e18);
        
        // Try to withdraw too much collateral
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(
            ICDPManager.InsufficientCollateral.selector,
            cdpId,
            75e18, // required (50e18 debt * 150% ratio)
            50e18  // available
        ));
        cdpManager.withdrawCollateral(cdpId, 50e18);
    }

    function testFuzz_OpenCDP_ValidAmounts(uint256 amount) public {
        vm.assume(amount > 0 && amount <= INITIAL_COLLATERAL);
        
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), amount);
        
        assertEq(cdpManager.getCDPCollateralAmount(cdpId), amount);
    }

    function testFuzz_MintStablecoin_WithinLiquidationRatio(uint256 collateralAmount, uint256 debtAmount) public {
        vm.assume(collateralAmount > 0 && collateralAmount <= INITIAL_COLLATERAL);
        vm.assume(debtAmount > 0);
        
        // Ensure debt amount doesn't exceed liquidation ratio
        uint256 maxDebt = (collateralAmount * 1e18) / (LIQUIDATION_RATIO * 1e14);
        vm.assume(debtAmount <= maxDebt);
        
        vm.prank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), collateralAmount);
        
        vm.prank(user);
        cdpManager.mintStablecoin(cdpId, debtAmount);
        
        assertEq(cdpManager.getCDPDebt(cdpId), debtAmount);
    }
}
