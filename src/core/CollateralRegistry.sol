// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ICollateralRegistry} from "../interfaces/ICollateralRegistry.sol";

/**
 * @title CollateralRegistry
 * @dev Registry for managing supported collateral types and their parameters
 * @notice This contract manages the configuration for different collateral types in the CDP system
 */
contract CollateralRegistry is AccessControl, ICollateralRegistry {
    /// @notice Role that can manage collateral configurations
    bytes32 public constant COLLATERAL_MANAGER_ROLE = keccak256("COLLATERAL_MANAGER_ROLE");

    /// @notice Mapping from collateral address to collateral info
    mapping(address => CollateralInfo) public collaterals;

    /// @notice Array of all supported collateral addresses
    address[] public collateralList;

    /// @notice Mapping to check if collateral is already registered
    mapping(address => bool) public isCollateralRegistered;


    /// @notice Emitted when collateral is removed
    event CollateralRemoved(address indexed collateral);


    /// @notice Error thrown when collateral is already registered
    error CollateralAlreadyRegistered(address collateral);

    /// @notice Error thrown when collateral is not registered
    error CollateralNotRegistered(address collateral);

    /**
     * @dev Constructor that sets up the registry
     */
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COLLATERAL_MANAGER_ROLE, msg.sender);
    }

    /**
     * @notice Add a new collateral type to the registry
     * @dev Only addresses with COLLATERAL_MANAGER_ROLE can call this function
     * @param collateral Address of the collateral token
     * @param liquidationRatio Liquidation ratio in basis points (e.g., 150% = 15000)
     * @param stabilityFee Stability fee rate in basis points (e.g., 2% = 200)
     * @param liquidationPenalty Liquidation penalty in basis points (e.g., 13% = 1300)
     * @param debtCeiling Maximum debt allowed for this collateral type
     */
    function addCollateral(
        address collateral,
        uint256 liquidationRatio,
        uint256 stabilityFee,
        uint256 liquidationPenalty,
        uint256 debtCeiling
    ) external onlyRole(COLLATERAL_MANAGER_ROLE) {
        if (collateral == address(0)) revert InvalidCollateral(collateral);
        if (isCollateralRegistered[collateral]) revert CollateralAlreadyRegistered(collateral);
        if (liquidationRatio == 0 || liquidationRatio < 10000) revert InvalidParameters(); // Min 100%
        if (stabilityFee > 10000) revert InvalidParameters(); // Max 100%
        if (liquidationPenalty > 5000) revert InvalidParameters(); // Max 50%

        CollateralInfo memory info = CollateralInfo({
            isActive: true,
            liquidationRatio: liquidationRatio,
            stabilityFeeRate: stabilityFee,
            debtCeiling: debtCeiling,
            liquidationPenalty: liquidationPenalty,
            totalDebt: 0
        });

        collaterals[collateral] = info;
        collateralList.push(collateral);
        isCollateralRegistered[collateral] = true;

        emit CollateralAdded(collateral, liquidationRatio, stabilityFee);
    }

    /**
     * @notice Update collateral parameters
     * @dev Only addresses with COLLATERAL_MANAGER_ROLE can call this function
     * @param collateral Address of the collateral token
     * @param liquidationRatio New liquidation ratio in basis points
     * @param stabilityFee New stability fee rate in basis points
     * @param liquidationPenalty New liquidation penalty in basis points
     */
    function updateCollateralParams(
        address collateral,
        uint256 liquidationRatio,
        uint256 stabilityFee,
        uint256 liquidationPenalty
    ) external onlyRole(COLLATERAL_MANAGER_ROLE) {
        if (!isCollateralRegistered[collateral]) revert CollateralNotRegistered(collateral);
        if (liquidationRatio == 0 || liquidationRatio < 10000) revert InvalidParameters();
        if (stabilityFee > 10000) revert InvalidParameters();
        if (liquidationPenalty > 5000) revert InvalidParameters();

        CollateralInfo storage info = collaterals[collateral];
        info.liquidationRatio = liquidationRatio;
        info.stabilityFeeRate = stabilityFee;
        info.liquidationPenalty = liquidationPenalty;

        emit ParametersUpdated(collateral, liquidationRatio, stabilityFee);
    }

    /**
     * @notice Remove a collateral type from the registry
     * @dev Only addresses with COLLATERAL_MANAGER_ROLE can call this function
     * @param collateral Address of the collateral token to remove
     */
    function removeCollateral(address collateral) external onlyRole(COLLATERAL_MANAGER_ROLE) {
        if (!isCollateralRegistered[collateral]) revert CollateralNotRegistered(collateral);
        if (collaterals[collateral].totalDebt > 0) revert InvalidParameters(); // Can't remove if there's debt

        collaterals[collateral].isActive = false;
        isCollateralRegistered[collateral] = false;

        emit CollateralRemoved(collateral);
    }

    /**
     * @notice Update total debt for a collateral type
     * @dev Only addresses with COLLATERAL_MANAGER_ROLE can call this function
     * @param collateral Address of the collateral token
     * @param newTotalDebt New total debt amount
     */
    function updateTotalDebt(address collateral, uint256 newTotalDebt) external onlyRole(COLLATERAL_MANAGER_ROLE) {
        if (!isCollateralRegistered[collateral]) revert CollateralNotRegistered(collateral);
        
        collaterals[collateral].totalDebt = newTotalDebt;
    }

    /**
     * @notice Get collateral information
     * @param collateral Address of the collateral token
     * @return CollateralInfo struct containing all collateral parameters
     */
    function getCollateralInfo(address collateral) external view returns (CollateralInfo memory) {
        if (!isCollateralRegistered[collateral]) revert CollateralNotRegistered(collateral);
        return collaterals[collateral];
    }

    /**
     * @notice Check if a collateral is active
     * @param collateral Address of the collateral token
     * @return True if collateral is active and registered
     */
    function isCollateralActive(address collateral) external view returns (bool) {
        return isCollateralRegistered[collateral] && collaterals[collateral].isActive;
    }

    /**
     * @notice Get liquidation ratio for a collateral
     * @param collateral Address of the collateral token
     * @return Liquidation ratio in basis points
     */
    function getLiquidationRatio(address collateral) external view returns (uint256) {
        if (!isCollateralRegistered[collateral]) revert CollateralNotRegistered(collateral);
        return collaterals[collateral].liquidationRatio;
    }

    /**
     * @notice Get stability fee for a collateral
     * @param collateral Address of the collateral token
     * @return Stability fee rate in basis points
     */
    function getStabilityFee(address collateral) external view returns (uint256) {
        if (!isCollateralRegistered[collateral]) revert CollateralNotRegistered(collateral);
        return collaterals[collateral].stabilityFeeRate;
    }

    /**
     * @notice Get debt ceiling for a collateral
     * @param collateral Address of the collateral token
     * @return Debt ceiling amount
     */
    function getDebtCeiling(address collateral) external view returns (uint256) {
        if (!isCollateralRegistered[collateral]) revert CollateralNotRegistered(collateral);
        return collaterals[collateral].debtCeiling;
    }

    /**
     * @notice Get liquidation penalty for a collateral type
     * @param collateral Address of the collateral token
     * @return Liquidation penalty in basis points
     */
    function getLiquidationPenalty(address collateral) external view returns (uint256) {
        if (!isCollateralRegistered[collateral]) revert CollateralNotRegistered(collateral);
        return collaterals[collateral].liquidationPenalty;
    }

    /**
     * @notice Get total debt for a collateral
     * @param collateral Address of the collateral token
     * @return Total debt amount
     */
    function getTotalDebt(address collateral) external view returns (uint256) {
        if (!isCollateralRegistered[collateral]) revert CollateralNotRegistered(collateral);
        return collaterals[collateral].totalDebt;
    }

    /**
     * @notice Get all registered collateral addresses
     * @return Array of all collateral addresses
     */
    function getAllCollaterals() external view returns (address[] memory) {
        return collateralList;
    }

    /**
     * @notice Get count of registered collaterals
     * @return Number of registered collaterals
     */
    function getCollateralCount() external view returns (uint256) {
        return collateralList.length;
    }
}
