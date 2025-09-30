// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {PriceOracle} from "../../../src/core/PriceOracle.sol";
import {MockPriceFeed} from "../../../src/mocks/MockPriceFeed.sol";
import {MockERC20} from "../../../src/mocks/MockERC20.sol";
import {IPriceOracle} from "../../../src/interfaces/IPriceOracle.sol";

contract PriceOracleTest is Test {
    PriceOracle public priceOracle;
    MockERC20 public token1;
    MockERC20 public token2;
    MockPriceFeed public priceFeed1;
    MockPriceFeed public priceFeed2;
    
    address public owner = address(0x1);
    address public oracleManager = address(0x2);
    address public unauthorized = address(0x3);
    
    uint256 public constant INITIAL_PRICE_1 = 2000e18; // $2000
    uint256 public constant INITIAL_PRICE_2 = 1e18;    // $1

    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy contracts
        priceOracle = new PriceOracle();
        token1 = new MockERC20("Wrapped Ether", "WETH");
        token2 = new MockERC20("USD Coin", "USDC");
        
        // Grant oracle manager role
        priceOracle.grantRole(priceOracle.ORACLE_MANAGER_ROLE(), oracleManager);
        
        vm.stopPrank();
        
        // Set up oracles first
        vm.prank(oracleManager);
        priceOracle.setOracle(address(token1), address(this)); // Use test contract as oracle
        
        vm.prank(oracleManager);
        priceOracle.setOracle(address(token2), address(this)); // Use test contract as oracle
        
        // Deploy price feeds
        vm.prank(oracleManager);
        priceFeed1 = new MockPriceFeed(address(priceOracle), address(token1), INITIAL_PRICE_1);
        
        vm.prank(oracleManager);
        priceFeed2 = new MockPriceFeed(address(priceOracle), address(token2), INITIAL_PRICE_2);
        
        // Update oracle addresses to point to price feeds
        vm.prank(oracleManager);
        priceOracle.setOracle(address(token1), address(priceFeed1));
        
        vm.prank(oracleManager);
        priceOracle.setOracle(address(token2), address(priceFeed2));
    }

    function test_SetOracle_Success() public {
        vm.prank(oracleManager);
        priceOracle.setOracle(address(token1), address(priceFeed1));
        
        assertTrue(priceOracle.isOracleSet(address(token1)));
        assertEq(priceOracle.getOracle(address(token1)), address(priceFeed1));
        assertTrue(priceOracle.isTokenSupported(address(token1)));
    }

    function test_SetOracle_RevertIf_Unauthorized() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        priceOracle.setOracle(address(token1), address(priceFeed1));
    }

    function test_SetOracle_RevertIf_InvalidAddress() public {
        vm.prank(oracleManager);
        vm.expectRevert(IPriceOracle.InvalidOracle.selector);
        priceOracle.setOracle(address(0), address(priceFeed1));
        
        vm.prank(oracleManager);
        vm.expectRevert(IPriceOracle.InvalidOracle.selector);
        priceOracle.setOracle(address(token1), address(0));
    }

    function test_UpdatePrice_Success() public {
        vm.prank(oracleManager);
        priceOracle.setOracle(address(token1), address(priceFeed1));
        
        uint256 newPrice = 2500e18;
        vm.prank(address(priceFeed1));
        priceOracle.updatePrice(address(token1), newPrice);
        
        (uint256 price, uint256 timestamp) = priceOracle.getPriceWithTimestamp(address(token1));
        assertEq(price, newPrice);
        assertEq(timestamp, block.timestamp);
    }

    function test_UpdatePrice_RevertIf_NotOracle() public {
        vm.prank(oracleManager);
        priceOracle.setOracle(address(token1), address(priceFeed1));
        
        vm.prank(unauthorized);
        vm.expectRevert(IPriceOracle.InvalidOracle.selector);
        priceOracle.updatePrice(address(token1), 2500e18);
    }

    function test_UpdatePrice_RevertIf_InvalidPrice() public {
        vm.prank(oracleManager);
        priceOracle.setOracle(address(token1), address(priceFeed1));
        
        vm.prank(address(priceFeed1));
        vm.expectRevert(IPriceOracle.InvalidPrice.selector);
        priceOracle.updatePrice(address(token1), 0);
    }

    function test_GetPrice_Success() public {
        vm.prank(oracleManager);
        priceOracle.setOracle(address(token1), address(priceFeed1));
        
        uint256 price = priceOracle.getPrice(address(token1));
        assertEq(price, INITIAL_PRICE_1);
    }

    function test_GetPrice_RevertIf_OracleNotSet() public {
        vm.expectRevert(IPriceOracle.OracleNotSet.selector);
        priceOracle.getPrice(address(token1));
    }

    function test_GetPrice_RevertIf_PriceStale() public {
        vm.prank(oracleManager);
        priceOracle.setOracle(address(token1), address(priceFeed1));
        
        // Fast forward time beyond MAX_PRICE_AGE
        vm.warp(block.timestamp + priceOracle.MAX_PRICE_AGE() + 1);
        
        vm.expectRevert(abi.encodeWithSelector(
            IPriceOracle.PriceStale.selector,
            address(token1),
            block.timestamp - priceOracle.MAX_PRICE_AGE() - 1,
            priceOracle.MAX_PRICE_AGE()
        ));
        priceOracle.getPrice(address(token1));
    }

    function test_RemoveOracle_Success() public {
        vm.prank(oracleManager);
        priceOracle.setOracle(address(token1), address(priceFeed1));
        
        vm.prank(oracleManager);
        priceOracle.removeOracle(address(token1));
        
        assertFalse(priceOracle.isOracleSet(address(token1)));
        assertEq(priceOracle.getOracle(address(token1)), address(0));
    }

    function test_RemoveOracle_RevertIf_OracleNotSet() public {
        vm.prank(oracleManager);
        vm.expectRevert(IPriceOracle.OracleNotSet.selector);
        priceOracle.removeOracle(address(token1));
    }

    function test_IsPriceStale_Success() public {
        vm.prank(oracleManager);
        priceOracle.setOracle(address(token1), address(priceFeed1));
        
        // Price should not be stale initially
        assertFalse(priceOracle.isPriceStale(address(token1)));
        
        // Fast forward time beyond MAX_PRICE_AGE
        vm.warp(block.timestamp + priceOracle.MAX_PRICE_AGE() + 1);
        
        // Price should now be stale
        assertTrue(priceOracle.isPriceStale(address(token1)));
    }

    function test_GetSupportedTokens_Success() public {
        vm.prank(oracleManager);
        priceOracle.setOracle(address(token1), address(priceFeed1));
        
        vm.prank(oracleManager);
        priceOracle.setOracle(address(token2), address(priceFeed2));
        
        address[] memory tokens = priceOracle.getSupportedTokens();
        assertEq(tokens.length, 2);
        assertEq(tokens[0], address(token1));
        assertEq(tokens[1], address(token2));
    }

    function testFuzz_UpdatePrice_ValidPrices(uint256 price) public {
        vm.assume(price > 0 && price <= type(uint128).max);
        
        vm.prank(oracleManager);
        priceOracle.setOracle(address(token1), address(priceFeed1));
        
        vm.prank(address(priceFeed1));
        priceOracle.updatePrice(address(token1), price);
        
        assertEq(priceOracle.getPrice(address(token1)), price);
    }

    function testFuzz_SimulateVolatility(uint256 volatilityFactor) public {
        vm.assume(volatilityFactor > 0 && volatilityFactor <= 20000); // 0% to 200%
        
        vm.prank(oracleManager);
        priceOracle.setOracle(address(token1), address(priceFeed1));
        
        uint256 expectedPrice = (INITIAL_PRICE_1 * volatilityFactor) / 10000;
        
        vm.prank(address(priceFeed1));
        priceFeed1.simulateVolatility(volatilityFactor);
        
        assertEq(priceOracle.getPrice(address(token1)), expectedPrice);
    }
}
