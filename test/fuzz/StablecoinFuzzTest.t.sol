// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Stablecoin} from "../../src/core/Stablecoin.sol";

/**
 * @title StablecoinFuzzTest
 * @dev Comprehensive fuzz testing for Stablecoin contract
 * @notice Tests edge cases, boundary conditions, and random inputs for token operations
 */
contract StablecoinFuzzTest is Test {
    Stablecoin public stablecoin;
    
    address public admin = makeAddr("admin");
    address public minter = makeAddr("minter");
    address public burner = makeAddr("burner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
    uint256 public constant INITIAL_SUPPLY = 1000000 * 10**18;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    
    function setUp() public {
        stablecoin = new Stablecoin("TestStablecoin", "TST", 1000000000 * 10**18);
        
        // Setup roles
        vm.startPrank(admin);
        stablecoin.grantRole(stablecoin.MINTER_ROLE(), minter);
        stablecoin.grantRole(stablecoin.BURNER_ROLE(), burner);
        vm.stopPrank();
    }
    
    /**
     * @dev Fuzz test for minting with various amounts
     */
    function testFuzz_Mint_VariousAmounts(uint256 amount) public {
        vm.assume(amount > 0 && amount <= type(uint128).max);
        
        uint256 initialBalance = stablecoin.balanceOf(user1);
        uint256 initialTotalSupply = stablecoin.totalSupply();
        
        vm.startPrank(minter);
        stablecoin.mint(user1, amount);
        vm.stopPrank();
        
        assertEq(stablecoin.balanceOf(user1), initialBalance + amount);
        assertEq(stablecoin.totalSupply(), initialTotalSupply + amount);
    }
    
    /**
     * @dev Fuzz test for burning with various amounts
     */
    function testFuzz_Burn_VariousAmounts(uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(mintAmount > 0 && mintAmount <= type(uint128).max);
        vm.assume(burnAmount > 0 && burnAmount <= mintAmount);
        
        // First mint some tokens
        vm.startPrank(minter);
        stablecoin.mint(user1, mintAmount);
        vm.stopPrank();
        
        uint256 initialBalance = stablecoin.balanceOf(user1);
        uint256 initialTotalSupply = stablecoin.totalSupply();
        
        // Then burn some tokens
        vm.startPrank(burner);
        stablecoin.burn(user1, burnAmount);
        vm.stopPrank();
        
        assertEq(stablecoin.balanceOf(user1), initialBalance - burnAmount);
        assertEq(stablecoin.totalSupply(), initialTotalSupply - burnAmount);
    }
    
    /**
     * @dev Fuzz test for transfers with various amounts
     */
    function testFuzz_Transfer_VariousAmounts(uint256 mintAmount, uint256 transferAmount) public {
        vm.assume(mintAmount > 0 && mintAmount <= type(uint128).max);
        vm.assume(transferAmount > 0 && transferAmount <= mintAmount);
        
        // Mint tokens to user1
        vm.startPrank(minter);
        stablecoin.mint(user1, mintAmount);
        vm.stopPrank();
        
        uint256 initialBalance1 = stablecoin.balanceOf(user1);
        uint256 initialBalance2 = stablecoin.balanceOf(user2);
        
        // Transfer tokens
        vm.startPrank(user1);
        stablecoin.transfer(user2, transferAmount);
        vm.stopPrank();
        
        assertEq(stablecoin.balanceOf(user1), initialBalance1 - transferAmount);
        assertEq(stablecoin.balanceOf(user2), initialBalance2 + transferAmount);
    }
    
    /**
     * @dev Fuzz test for approvals with various amounts
     */
    function testFuzz_Approve_VariousAmounts(uint256 mintAmount, uint256 approveAmount) public {
        vm.assume(mintAmount > 0 && mintAmount <= type(uint128).max);
        vm.assume(approveAmount <= type(uint128).max);
        
        // Mint tokens to user1
        vm.startPrank(minter);
        stablecoin.mint(user1, mintAmount);
        vm.stopPrank();
        
        // Approve tokens
        vm.startPrank(user1);
        stablecoin.approve(user2, approveAmount);
        vm.stopPrank();
        
        assertEq(stablecoin.allowance(user1, user2), approveAmount);
    }
    
    /**
     * @dev Fuzz test for transferFrom with various amounts
     */
    function testFuzz_TransferFrom_VariousAmounts(
        uint256 mintAmount, 
        uint256 approveAmount, 
        uint256 transferAmount
    ) public {
        vm.assume(mintAmount > 0 && mintAmount <= type(uint128).max);
        vm.assume(approveAmount > 0 && approveAmount <= type(uint128).max);
        vm.assume(transferAmount > 0 && transferAmount <= approveAmount);
        vm.assume(transferAmount <= mintAmount);
        
        // Mint tokens to user1
        vm.startPrank(minter);
        stablecoin.mint(user1, mintAmount);
        vm.stopPrank();
        
        // Approve tokens
        vm.startPrank(user1);
        stablecoin.approve(user2, approveAmount);
        vm.stopPrank();
        
        uint256 initialBalance1 = stablecoin.balanceOf(user1);
        uint256 initialBalance2 = stablecoin.balanceOf(user2);
        uint256 initialAllowance = stablecoin.allowance(user1, user2);
        
        // Transfer tokens using transferFrom
        vm.startPrank(user2);
        stablecoin.transferFrom(user1, user2, transferAmount);
        vm.stopPrank();
        
        assertEq(stablecoin.balanceOf(user1), initialBalance1 - transferAmount);
        assertEq(stablecoin.balanceOf(user2), initialBalance2 + transferAmount);
        assertEq(stablecoin.allowance(user1, user2), initialAllowance - transferAmount);
    }
    
    /**
     * @dev Fuzz test for complex token operations
     */
    function testFuzz_ComplexTokenOperations(
        uint256 mintAmount,
        uint256 approveAmount,
        uint256 transferAmount,
        uint256 burnAmount
    ) public {
        vm.assume(mintAmount > 0 && mintAmount <= type(uint128).max);
        vm.assume(approveAmount > 0 && approveAmount <= mintAmount);
        vm.assume(transferAmount > 0 && transferAmount <= approveAmount);
        vm.assume(burnAmount > 0 && burnAmount <= mintAmount - transferAmount);
        
        // Mint tokens
        vm.startPrank(minter);
        stablecoin.mint(user1, mintAmount);
        vm.stopPrank();
        
        // Approve tokens
        vm.startPrank(user1);
        stablecoin.approve(user2, approveAmount);
        vm.stopPrank();
        
        // Transfer tokens
        vm.startPrank(user2);
        stablecoin.transferFrom(user1, user2, transferAmount);
        vm.stopPrank();
        
        // Burn remaining tokens from user1
        vm.startPrank(burner);
        stablecoin.burn(user1, burnAmount);
        vm.stopPrank();
        
        // Verify final balances
        assertEq(stablecoin.balanceOf(user1), mintAmount - transferAmount - burnAmount);
        assertEq(stablecoin.balanceOf(user2), transferAmount);
        assertEq(stablecoin.totalSupply(), mintAmount - burnAmount);
    }
    
    /**
     * @dev Fuzz test for role management
     */
    function testFuzz_RoleManagement(address account) public {
        vm.assume(account != address(0) && account != admin);
        
        // Grant minter role
        vm.startPrank(admin);
        stablecoin.grantRole(stablecoin.MINTER_ROLE(), account);
        assertTrue(stablecoin.hasRole(stablecoin.MINTER_ROLE(), account));
        
        // Revoke minter role
        stablecoin.revokeRole(stablecoin.MINTER_ROLE(), account);
        assertFalse(stablecoin.hasRole(stablecoin.MINTER_ROLE(), account));
        vm.stopPrank();
    }
    
    /**
     * @dev Fuzz test for boundary conditions
     */
    function testFuzz_BoundaryConditions(uint256 amount) public {
        vm.assume(amount > 0 && amount <= type(uint128).max);
        
        // Test maximum mint
        vm.startPrank(minter);
        stablecoin.mint(user1, amount);
        vm.stopPrank();
        
        assertEq(stablecoin.balanceOf(user1), amount);
        assertEq(stablecoin.totalSupply(), amount);
        
        // Test maximum burn
        vm.startPrank(burner);
        stablecoin.burn(user1, amount);
        vm.stopPrank();
        
        assertEq(stablecoin.balanceOf(user1), 0);
        assertEq(stablecoin.totalSupply(), 0);
    }
    
    /**
     * @dev Fuzz test for gas optimization
     */
    function testFuzz_GasOptimization(uint256 amount) public {
        vm.assume(amount > 0 && amount <= 1000 * 10**18);
        
        // Test mint gas usage
        uint256 gasStart = gasleft();
        vm.startPrank(minter);
        stablecoin.mint(user1, amount);
        vm.stopPrank();
        uint256 gasUsed = gasStart - gasleft();
        
        // Gas usage should be reasonable (less than 100k gas)
        assertLt(gasUsed, 100000);
    }
    
    /**
     * @dev Fuzz test for multiple users
     */
    function testFuzz_MultipleUsers(uint256[5] memory amounts) public {
        address[5] memory users = [makeAddr("user1"), makeAddr("user2"), makeAddr("user3"), makeAddr("user4"), makeAddr("user5")];
        
        vm.startPrank(minter);
        
        for (uint256 i = 0; i < 5; i++) {
            vm.assume(amounts[i] > 0 && amounts[i] <= type(uint128).max / 5);
            stablecoin.mint(users[i], amounts[i]);
            assertEq(stablecoin.balanceOf(users[i]), amounts[i]);
        }
        
        vm.stopPrank();
        
        // Verify total supply
        uint256 totalSupply = 0;
        for (uint256 i = 0; i < 5; i++) {
            totalSupply += amounts[i];
        }
        assertEq(stablecoin.totalSupply(), totalSupply);
    }
    
    /**
     * @dev Fuzz test for allowance edge cases
     */
    function testFuzz_AllowanceEdgeCases(uint256 amount) public {
        vm.assume(amount > 0 && amount <= type(uint128).max);
        
        // Mint tokens
        vm.startPrank(minter);
        stablecoin.mint(user1, amount);
        vm.stopPrank();
        
        // Test maximum allowance
        vm.startPrank(user1);
        stablecoin.approve(user2, type(uint256).max);
        assertEq(stablecoin.allowance(user1, user2), type(uint256).max);
        
        // Test zero allowance
        stablecoin.approve(user2, 0);
        assertEq(stablecoin.allowance(user1, user2), 0);
        vm.stopPrank();
    }
}
