// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CDPManager} from "../../../src/core/CDPManager.sol";
import {Stablecoin} from "../../../src/core/Stablecoin.sol";
import {CollateralRegistry} from "../../../src/core/CollateralRegistry.sol";
import {MockERC20} from "../../../src/mocks/MockERC20.sol";

/**
 * @title CDPManagerSimpleTest
 * @dev Simple test to verify basic functionality
 */
contract CDPManagerSimpleTest is Test {
    CDPManager public cdpManager;
    Stablecoin public stablecoin;
    CollateralRegistry public collateralRegistry;
    MockERC20 public collateralToken;
    
    address public admin = makeAddr("admin");
    address public user = makeAddr("user");
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;
    
    function setUp() public {
        // Deploy contracts
        stablecoin = new Stablecoin("TestStablecoin", "TST", 1000000000 * 10**18);
        collateralRegistry = new CollateralRegistry();
        cdpManager = new CDPManager(
            address(stablecoin),
            address(collateralRegistry)
        );
        collateralToken = new MockERC20("TestCollateral", "TCOL");
        
        // Setup roles
        vm.startPrank(admin);
        stablecoin.grantRole(stablecoin.MINTER_ROLE(), address(cdpManager));
        stablecoin.grantRole(stablecoin.BURNER_ROLE(), address(cdpManager));
        collateralRegistry.grantRole(collateralRegistry.COLLATERAL_MANAGER_ROLE(), address(cdpManager));
        cdpManager.grantRole(cdpManager.DEFAULT_ADMIN_ROLE(), admin);
        vm.stopPrank();
        
        // Register collateral
        vm.startPrank(admin);
        collateralRegistry.addCollateral(
            address(collateralToken),
            15000, // 150% liquidation ratio in basis points
            200,   // 2% stability fee in basis points
            1000,  // 10% liquidation penalty in basis points
            1000000 * 10**18 // 1M debt ceiling
        );
        vm.stopPrank();
        
        // Setup user
        collateralToken.mint(user, INITIAL_SUPPLY);
        vm.startPrank(user);
        collateralToken.approve(address(cdpManager), type(uint256).max);
        vm.stopPrank();
    }
    
    function test_OpenCDP_Success() public {
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 1000 * 10**18);
        vm.stopPrank();
        
        assertTrue(cdpId > 0);
        assertEq(cdpManager.getCDPOwner(cdpId), user);
    }
    
    function test_MintStablecoin_Success() public {
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), 1000 * 10**18);
        cdpManager.mintStablecoin(cdpId, 500 * 10**18);
        vm.stopPrank();
        
        assertEq(cdpManager.getCDPDebt(cdpId), 500 * 10**18);
        assertEq(stablecoin.balanceOf(user), 500 * 10**18);
    }
}
