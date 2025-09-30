// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IPriceOracle} from "../interfaces/IPriceOracle.sol";

/**
 * @title MockPriceFeed
 * @dev Mock price feed for testing purposes
 * @notice This contract simulates a price feed oracle for testing
 */
contract MockPriceFeed {
    IPriceOracle public priceOracle;
    address public token;
    uint256 public currentPrice;
    uint256 public lastUpdateTime;

    /// @notice Emitted when price is updated
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);

    /// @notice Error thrown when price is zero
    error InvalidPrice();

    /**
     * @dev Constructor
     * @param _priceOracle Address of the price oracle contract
     * @param _token Address of the token this feed provides prices for
     * @param _initialPrice Initial price of the token
     */
    constructor(address _priceOracle, address _token, uint256 _initialPrice) {
        if (_priceOracle == address(0) || _token == address(0)) revert InvalidPrice();
        if (_initialPrice == 0) revert InvalidPrice();

        priceOracle = IPriceOracle(_priceOracle);
        token = _token;
        currentPrice = _initialPrice;
        lastUpdateTime = block.timestamp;
    }

    /**
     * @notice Update the price of the token
     * @param newPrice New price of the token
     */
    function updatePrice(uint256 newPrice) external {
        if (newPrice == 0) revert InvalidPrice();

        uint256 oldPrice = currentPrice;
        currentPrice = newPrice;
        lastUpdateTime = block.timestamp;

        // Update the price oracle
        priceOracle.updatePrice(token, newPrice);

        emit PriceUpdated(oldPrice, newPrice);
    }

    /**
     * @notice Get the current price
     * @return Current price of the token
     */
    function getPrice() external view returns (uint256) {
        return currentPrice;
    }

    /**
     * @notice Get the last update time
     * @return Timestamp of the last price update
     */
    function getLastUpdateTime() external view returns (uint256) {
        return lastUpdateTime;
    }

    /**
     * @notice Simulate price volatility by updating price with a random factor
     * @param volatilityFactor Factor to apply to current price (in basis points, e.g., 1000 = 10%)
     */
    function simulateVolatility(uint256 volatilityFactor) external {
        uint256 newPrice = (currentPrice * volatilityFactor) / 10000;
        this.updatePrice(newPrice);
    }
}
