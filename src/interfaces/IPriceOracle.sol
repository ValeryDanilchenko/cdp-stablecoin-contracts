// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPriceOracle {
    // Events
    event PriceUpdated(address indexed token, uint256 oldPrice, uint256 newPrice);
    event OracleAdded(address indexed token, address oracle);
    event OracleRemoved(address indexed token);

    // Errors
    error InvalidOracle(address oracle);
    error InvalidPrice(uint256 price);
    error PriceStale(address token, uint256 lastUpdate, uint256 maxAge);
    error OracleNotSet(address token);

    // Core Functions
    function setOracle(address token, address oracle) external;
    function removeOracle(address token) external;
    function updatePrice(address token, uint256 price) external;

    // View Functions
    function getPrice(address token) external view returns (uint256);
    function getPriceWithTimestamp(address token) external view returns (uint256 price, uint256 timestamp);
    function isOracleSet(address token) external view returns (bool);
    function getOracle(address token) external view returns (address);
}
