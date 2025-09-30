// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";

/**
 * @title PriceOracle
 * @dev Central price oracle for managing token prices
 * @notice This contract manages price feeds for various tokens used as collateral
 */
contract PriceOracle is AccessControl, IPriceOracle {
    /// @notice Role that can manage oracles
    bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");

    /// @notice Maximum age for price data (24 hours)
    uint256 public constant MAX_PRICE_AGE = 24 hours;

    /// @notice Price data structure
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        bool isValid;
    }

    /// @notice Mapping from token to oracle address
    mapping(address => address) public oracles;

    /// @notice Mapping from token to price data
    mapping(address => PriceData) public prices;

    /// @notice Array of all supported tokens
    address[] public supportedTokens;

    /// @notice Mapping to check if token is supported
    mapping(address => bool) public isTokenSupported;



    /**
     * @dev Constructor that sets up the oracle
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_MANAGER_ROLE, msg.sender);
    }

    /**
     * @notice Set oracle for a token
     * @dev Only addresses with ORACLE_MANAGER_ROLE can call this function
     * @param token Address of the token
     * @param oracle Address of the oracle contract
     */
    function setOracle(address token, address oracle) external onlyRole(ORACLE_MANAGER_ROLE) {
        if (token == address(0) || oracle == address(0)) revert InvalidOracle(oracle);

        oracles[token] = oracle;
        
        if (!isTokenSupported[token]) {
            supportedTokens.push(token);
            isTokenSupported[token] = true;
        }

        emit OracleAdded(token, oracle);
    }

    /**
     * @notice Remove oracle for a token
     * @dev Only addresses with ORACLE_MANAGER_ROLE can call this function
     * @param token Address of the token
     */
    function removeOracle(address token) external onlyRole(ORACLE_MANAGER_ROLE) {
        if (oracles[token] == address(0)) revert OracleNotSet(token);

        delete oracles[token];
        delete prices[token];

        emit OracleRemoved(token);
    }

    /**
     * @notice Update price for a token
     * @dev Only the oracle for that token can call this function
     * @param token Address of the token
     * @param price New price (in USD with 18 decimals)
     */
    function updatePrice(address token, uint256 price) external {
        if (oracles[token] != msg.sender) revert InvalidOracle(msg.sender);
        if (price == 0) revert InvalidPrice(price);

        uint256 oldPrice = prices[token].price;
        prices[token] = PriceData({
            price: price,
            timestamp: block.timestamp,
            isValid: true
        });

        emit PriceUpdated(token, oldPrice, price);
    }

    /**
     * @notice Get current price for a token
     * @param token Address of the token
     * @return Current price in USD (18 decimals)
     */
    function getPrice(address token) external view returns (uint256) {
        if (!isTokenSupported[token]) revert OracleNotSet(token);
        
        PriceData memory priceData = prices[token];
        if (!priceData.isValid) revert OracleNotSet(token);
        
        if (block.timestamp - priceData.timestamp > MAX_PRICE_AGE) {
            revert PriceStale(token, priceData.timestamp, MAX_PRICE_AGE);
        }

        return priceData.price;
    }

    /**
     * @notice Get price with timestamp for a token
     * @param token Address of the token
     * @return price Current price in USD (18 decimals)
     * @return timestamp Timestamp of the last price update
     */
    function getPriceWithTimestamp(address token) external view returns (uint256 price, uint256 timestamp) {
        if (!isTokenSupported[token]) revert OracleNotSet(token);
        
        PriceData memory priceData = prices[token];
        if (!priceData.isValid) revert OracleNotSet(token);

        return (priceData.price, priceData.timestamp);
    }

    /**
     * @notice Check if oracle is set for a token
     * @param token Address of the token
     * @return True if oracle is set
     */
    function isOracleSet(address token) external view returns (bool) {
        return oracles[token] != address(0);
    }

    /**
     * @notice Get oracle address for a token
     * @param token Address of the token
     * @return Oracle address
     */
    function getOracle(address token) external view returns (address) {
        return oracles[token];
    }

    /**
     * @notice Get all supported tokens
     * @return Array of supported token addresses
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    /**
     * @notice Get count of supported tokens
     * @return Number of supported tokens
     */
    function getSupportedTokenCount() external view returns (uint256) {
        return supportedTokens.length;
    }

    /**
     * @notice Check if price is stale
     * @param token Address of the token
     * @return True if price is stale
     */
    function isPriceStale(address token) external view returns (bool) {
        if (!isTokenSupported[token]) return true;
        
        PriceData memory priceData = prices[token];
        if (!priceData.isValid) return true;
        
        return block.timestamp - priceData.timestamp > MAX_PRICE_AGE;
    }
}
