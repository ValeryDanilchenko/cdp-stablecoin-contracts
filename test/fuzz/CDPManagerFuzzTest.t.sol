// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CDPManager} from "../../src/core/CDPManager.sol";
import {Stablecoin} from "../../src/core/Stablecoin.sol";
import {CollateralRegistry} from "../../src/core/CollateralRegistry.sol";
import {MockERC20} from "../../src/mocks/MockERC20.sol";
import {ICDPManager} from "../../src/interfaces/ICDPManager.sol";

/**
 * @title CDPManagerFuzzTest
 * @dev Comprehensive fuzz testing for CDPManager contract
 * @notice Tests edge cases, boundary conditions, and random inputs
 */
contract CDPManagerFuzzTest is Test {
    CDPManager public cdpManager;
    Stablecoin public stablecoin;
    CollateralRegistry public collateralRegistry;
    MockERC20 public collateralToken;
    
    address public user = makeAddr("user");
    address public admin = makeAddr("admin");
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;
    uint256 public constant LIQUIDATION_RATIO = 150; // 150% = 1.5x
    uint256 public constant LIQUIDATION_PENALTY = 10; // 10%
    uint256 public constant MAX_LIQUIDATION_RATIO = 200; // 200% = 2x
    
    event CDPOpened(uint256 indexed cdpId, address indexed owner, address indexed collateral);
    event CollateralDeposited(uint256 indexed cdpId, uint256 amount);
    event StablecoinMinted(uint256 indexed cdpId, uint256 amount);
    event DebtRepaid(uint256 indexed cdpId, uint256 amount);
    event CollateralWithdrawn(uint256 indexed cdpId, uint256 amount);
    
    function setUp() public {
        // Deploy contracts
        stablecoin = new Stablecoin("TestStablecoin", "TST", admin);
        collateralRegistry = new CollateralRegistry(admin);
        cdpManager = new CDPManager(
            address(stablecoin),
            address(collateralRegistry),
            admin
        );
        collateralToken = new MockERC20("TestCollateral", "TCOL");
        
        // Setup roles
        vm.startPrank(admin);
        stablecoin.grantRole(stablecoin.MINTER_ROLE(), address(cdpManager));
        stablecoin.grantRole(stablecoin.BURNER_ROLE(), address(cdpManager));
        collateralRegistry.grantRole(collateralRegistry.REGISTRAR_ROLE(), address(cdpManager));
        cdpManager.grantRole(cdpManager.ADMIN_ROLE(), admin);
        
        // Register collateral
        collateralRegistry.addCollateral(
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
     * @dev Fuzz test for opening CDPs with various amounts
     */
    function testFuzz_OpenCDP_VariousAmounts(uint256 amount) public {
        vm.assume(amount > 0 && amount <= INITIAL_SUPPLY);
        
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), amount);
        vm.stopPrank();
        
        assertTrue(cdpId > 0);
        assertEq(cdpManager.getCDPOwner(cdpId), user);
        assertEq(cdpManager.getCDPCollateral(cdpId), address(collateralToken));
        assertEq(cdpManager.getCDPCollateralAmount(cdpId), amount);
    }
    
    /**
     * @dev Fuzz test for minting stablecoins with various ratios
     */
    function testFuzz_MintStablecoin_VariousRatios(uint256 collateralAmount, uint256 mintAmount) public {
        vm.assume(collateralAmount > 0 && collateralAmount <= INITIAL_SUPPLY);
        vm.assume(mintAmount > 0);
        
        // Open CDP
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), collateralAmount);
        
        // Calculate max mintable amount (collateral * 100 / liquidation ratio)
        uint256 maxMintable = (collateralAmount * 100) / LIQUIDATION_RATIO;
        vm.assume(mintAmount <= maxMintable);
        
        // Mint stablecoin
        cdpManager.mintStablecoin(cdpId, mintAmount);
        vm.stopPrank();
        
        assertEq(cdpManager.getCDPDebt(cdpId), mintAmount);
        assertEq(stablecoin.balanceOf(user), mintAmount);
    }
    
    /**
     * @dev Fuzz test for repaying debt with various amounts
     */
    function testFuzz_RepayDebt_VariousAmounts(uint256 collateralAmount, uint256 mintAmount, uint256 repayAmount) public {
        vm.assume(collateralAmount > 0 && collateralAmount <= INITIAL_SUPPLY);
        vm.assume(mintAmount > 0);
        
        // Open CDP and mint
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), collateralAmount);
        
        uint256 maxMintable = (collateralAmount * 100) / LIQUIDATION_RATIO;
        vm.assume(mintAmount <= maxMintable);
        
        cdpManager.mintStablecoin(cdpId, mintAmount);
        
        // Repay debt
        vm.assume(repayAmount > 0 && repayAmount <= mintAmount);
        cdpManager.repayDebt(cdpId, repayAmount);
        vm.stopPrank();
        
        assertEq(cdpManager.getCDPDebt(cdpId), mintAmount - repayAmount);
        assertEq(stablecoin.balanceOf(user), mintAmount - repayAmount);
    }
    
    /**
     * @dev Fuzz test for withdrawing collateral with various amounts
     */
    function testFuzz_WithdrawCollateral_VariousAmounts(
        uint256 collateralAmount, 
        uint256 mintAmount, 
        uint256 withdrawAmount
    ) public {
        vm.assume(collateralAmount > 0 && collateralAmount <= INITIAL_SUPPLY);
        vm.assume(mintAmount > 0);
        
        // Open CDP and mint
        vm.startPrank(user);
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), collateralAmount);
        
        uint256 maxMintable = (collateralAmount * 100) / LIQUIDATION_RATIO;
        vm.assume(mintAmount <= maxMintable);
        
        cdpManager.mintStablecoin(cdpId, mintAmount);
        
        // Calculate max withdrawable amount
        uint256 remainingCollateral = collateralAmount;
        uint256 remainingDebt = mintAmount;
        uint256 requiredCollateral = (remainingDebt * LIQUIDATION_RATIO) / 100;
        uint256 maxWithdrawable = remainingCollateral - requiredCollateral;
        
        vm.assume(withdrawAmount > 0 && withdrawAmount <= maxWithdrawable);
        
        cdpManager.withdrawCollateral(cdpId, withdrawAmount);
        vm.stopPrank();
        
        assertEq(cdpManager.getCDPCollateralAmount(cdpId), collateralAmount - withdrawAmount);
    }
    
    /**
     * @dev Fuzz test for complex CDP operations
     */
    function testFuzz_ComplexCDPOperations(
        uint256 initialCollateral,
        uint256 mintAmount,
        uint256 additionalCollateral,
        uint256 repayAmount,
        uint256 withdrawAmount
    ) public {
        vm.assume(initialCollateral > 0 && initialCollateral <= INITIAL_SUPPLY / 2);
        vm.assume(mintAmount > 0);
        vm.assume(additionalCollateral > 0 && additionalCollateral <= INITIAL_SUPPLY / 2);
        
        vm.startPrank(user);
        
        // Open CDP
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), initialCollateral);
        
        // Mint stablecoin
        uint256 maxMintable = (initialCollateral * 100) / LIQUIDATION_RATIO;
        vm.assume(mintAmount <= maxMintable);
        cdpManager.mintStablecoin(cdpId, mintAmount);
        
        // Add more collateral
        cdpManager.depositCollateral(cdpId, additionalCollateral);
        
        // Repay some debt
        vm.assume(repayAmount > 0 && repayAmount <= mintAmount);
        cdpManager.repayDebt(cdpId, repayAmount);
        
        // Withdraw some collateral
        uint256 totalCollateral = initialCollateral + additionalCollateral;
        uint256 remainingDebt = mintAmount - repayAmount;
        uint256 requiredCollateral = (remainingDebt * LIQUIDATION_RATIO) / 100;
        uint256 maxWithdrawable = totalCollateral - requiredCollateral;
        
        vm.assume(withdrawAmount > 0 && withdrawAmount <= maxWithdrawable);
        cdpManager.withdrawCollateral(cdpId, withdrawAmount);
        
        vm.stopPrank();
        
        // Verify final state
        assertEq(cdpManager.getCDPCollateralAmount(cdpId), totalCollateral - withdrawAmount);
        assertEq(cdpManager.getCDPDebt(cdpId), remainingDebt);
    }
    
    /**
     * @dev Fuzz test for boundary conditions
     */
    function testFuzz_BoundaryConditions(uint256 amount) public {
        vm.assume(amount > 0 && amount <= type(uint128).max);
        
        vm.startPrank(user);
        
        // Test maximum mintable amount
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), amount);
        uint256 maxMintable = (amount * 100) / LIQUIDATION_RATIO;
        
        if (maxMintable > 0) {
            cdpManager.mintStablecoin(cdpId, maxMintable);
            assertEq(cdpManager.getCDPDebt(cdpId), maxMintable);
        }
        
        vm.stopPrank();
    }
    
    /**
     * @dev Fuzz test for multiple CDPs per user
     */
    function testFuzz_MultipleCDPsPerUser(uint256[3] memory amounts) public {
        vm.assume(amounts[0] > 0 && amounts[0] <= INITIAL_SUPPLY / 3);
        vm.assume(amounts[1] > 0 && amounts[1] <= INITIAL_SUPPLY / 3);
        vm.assume(amounts[2] > 0 && amounts[2] <= INITIAL_SUPPLY / 3);
        
        vm.startPrank(user);
        
        uint256 cdpId1 = cdpManager.openCDP(address(collateralToken), amounts[0]);
        uint256 cdpId2 = cdpManager.openCDP(address(collateralToken), amounts[1]);
        uint256 cdpId3 = cdpManager.openCDP(address(collateralToken), amounts[2]);
        
        assertTrue(cdpId1 != cdpId2);
        assertTrue(cdpId2 != cdpId3);
        assertTrue(cdpId1 != cdpId3);
        
        assertEq(cdpManager.getCDPOwner(cdpId1), user);
        assertEq(cdpManager.getCDPOwner(cdpId2), user);
        assertEq(cdpManager.getCDPOwner(cdpId3), user);
        
        vm.stopPrank();
    }
    
    /**
     * @dev Fuzz test for gas optimization scenarios
     */
    function testFuzz_GasOptimization(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 1000 * 10**18); // Reasonable amount for gas testing
        
        vm.startPrank(user);
        
        uint256 gasStart = gasleft();
        uint256 cdpId = cdpManager.openCDP(address(collateralToken), amount);
        uint256 gasUsed = gasStart - gasleft();
        
        // Gas usage should be reasonable (less than 500k gas)
        assertLt(gasUsed, 500000);
        
        vm.stopPrank();
    }
}

