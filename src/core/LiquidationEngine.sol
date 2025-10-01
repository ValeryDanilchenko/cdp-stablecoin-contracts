// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ILiquidationEngine} from "../interfaces/ILiquidationEngine.sol";
import {ICDPManager} from "../interfaces/ICDPManager.sol";
import {ICollateralRegistry} from "../interfaces/ICollateralRegistry.sol";

/**
 * @title LiquidationEngine
 * @dev Handles liquidation logic and auctions for undercollateralized CDPs
 * @notice This contract manages the liquidation process for CDPs that fall below the liquidation ratio
 */
contract LiquidationEngine is AccessControl, ReentrancyGuard, Pausable, ILiquidationEngine {
    /// @notice Role that can liquidate CDPs
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");

    /// @notice CDP Manager contract
    ICDPManager public immutable cdpManager;

    /// @notice Collateral Registry contract
    ICollateralRegistry public immutable collateralRegistry;


    /// @notice Liquidation delay (time before liquidation can be executed)
    uint256 public liquidationDelay = 1 hours;

    /// @notice Mapping to track when CDPs became liquidatable
    mapping(uint256 => uint256) public liquidationTimestamp;


    /**
     * @dev Constructor that sets up the liquidation engine
     * @param _cdpManager Address of the CDP manager contract
     * @param _collateralRegistry Address of the collateral registry contract
     */
    constructor(
        address _cdpManager,
        address _collateralRegistry
    ) {
        if (_cdpManager == address(0) || _collateralRegistry == address(0)) {
            revert InvalidLiquidationPenalty(0);
        }

        cdpManager = ICDPManager(_cdpManager);
        collateralRegistry = ICollateralRegistry(_collateralRegistry);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LIQUIDATOR_ROLE, msg.sender);
    }

    /**
     * @notice Execute liquidation of an undercollateralized CDP
     * @dev Only addresses with LIQUIDATOR_ROLE can call this function
     * @param cdpId ID of the CDP to liquidate
     */
    function liquidateCDP(uint256 cdpId) external onlyRole(LIQUIDATOR_ROLE) whenNotPaused nonReentrant {
        if (!isCDPLiquidatable(cdpId)) revert CDPNotLiquidatable(cdpId);

        // Check liquidation delay
        uint256 requiredTime = liquidationTimestamp[cdpId] + liquidationDelay;
        if (block.timestamp < requiredTime) {
            revert LiquidationDelayNotMet(cdpId, requiredTime, block.timestamp);
        }

        // Get CDP information
        address collateral = cdpManager.getCDPCollateral(cdpId);
        uint256 collateralAmount = cdpManager.getCDPCollateralAmount(cdpId);
        uint256 debtAmount = cdpManager.getCDPDebt(cdpId);

        // Calculate liquidation penalty
        uint256 penaltyRate = collateralRegistry.getLiquidationPenalty(collateral);
        uint256 penaltyAmount = (collateralAmount * penaltyRate) / 10000;

        // Ensure we don't seize more collateral than available
        if (penaltyAmount > collateralAmount) {
            penaltyAmount = collateralAmount;
        }

        // Execute liquidation through CDP manager
        cdpManager.liquidateCDP(cdpId);

        // Transfer seized collateral to liquidator
        IERC20(collateral).transfer(msg.sender, penaltyAmount);

        // Clear liquidation timestamp
        delete liquidationTimestamp[cdpId];

        emit LiquidationExecuted(cdpId, msg.sender, penaltyAmount, debtAmount);
    }

    /**
     * @notice Check if a CDP is liquidatable
     * @param cdpId ID of the CDP to check
     * @return True if CDP can be liquidated
     */
    function checkLiquidation(uint256 cdpId) external view returns (bool) {
        return isCDPLiquidatable(cdpId);
    }

    /**
     * @notice Calculate liquidation penalty for a CDP
     * @param cdpId ID of the CDP
     * @return Penalty amount in collateral tokens
     */
    function calculateLiquidationPenalty(uint256 cdpId) external view returns (uint256) {
        if (!cdpManager.isCDPLiquidatable(cdpId)) revert CDPNotLiquidatable(cdpId);

        address collateral = cdpManager.getCDPCollateral(cdpId);
        uint256 collateralAmount = cdpManager.getCDPCollateralAmount(cdpId);
        uint256 penaltyRate = collateralRegistry.getLiquidationPenalty(collateral);

        return (collateralAmount * penaltyRate) / 10000;
    }

    /**
     * @notice Get liquidation delay
     * @return Current liquidation delay in seconds
     */
    function getLiquidationDelay() external view returns (uint256) {
        return liquidationDelay;
    }

    /**
     * @notice Set liquidation delay
     * @dev Only admin can call this function
     * @param newDelay New liquidation delay in seconds
     */
    function setLiquidationDelay(uint256 newDelay) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newDelay > 7 days) revert InvalidLiquidationPenalty(newDelay);

        uint256 oldDelay = liquidationDelay;
        liquidationDelay = newDelay;

        emit LiquidationDelayUpdated(oldDelay, newDelay);
    }

    /**
     * @notice Check if a CDP is liquidatable (internal)
     * @param cdpId ID of the CDP to check
     * @return True if CDP can be liquidated
     */
    function isCDPLiquidatable(uint256 cdpId) public view returns (bool) {
        if (!cdpManager.isCDPLiquidatable(cdpId)) return false;

        // Check if liquidation delay has been met
        uint256 requiredTime = liquidationTimestamp[cdpId] + liquidationDelay;
        return block.timestamp >= requiredTime;
    }

    /**
     * @notice Get comprehensive liquidation information for a CDP
     * @param cdpId ID of the CDP
     * @return isLiquidatable Whether the CDP can be liquidated
     * @return collateralValue Value of collateral in USD
     * @return debtValue Value of debt in USD
     * @return penaltyAmount Amount of collateral to be seized as penalty
     * @return collateralToSeize Total collateral to be seized
     */
    function getLiquidationInfo(uint256 cdpId) external view returns (
        bool isLiquidatable,
        uint256 collateralValue,
        uint256 debtValue,
        uint256 penaltyAmount,
        uint256 collateralToSeize
    ) {
        isLiquidatable = this.isCDPLiquidatable(cdpId);

        if (cdpManager.getCDPDebt(cdpId) == 0) {
            return (false, 0, 0, 0, 0);
        }

        address collateral = cdpManager.getCDPCollateral(cdpId);
        uint256 collateralAmount = cdpManager.getCDPCollateralAmount(cdpId);
        uint256 debtAmount = cdpManager.getCDPDebt(cdpId);

        // For now, assume 1:1 price ratio (will be updated when oracle is integrated)
        collateralValue = collateralAmount;

        debtValue = debtAmount; // Assuming 1:1 USD peg for stablecoin

        if (isLiquidatable) {
            uint256 penaltyRate = collateralRegistry.getLiquidationPenalty(collateral);
            penaltyAmount = (collateralAmount * penaltyRate) / 10000;
            collateralToSeize = penaltyAmount;
        }
    }

    /**
     * @notice Mark a CDP as liquidatable (called by CDP manager)
     * @dev Only CDP manager can call this function
     * @param cdpId ID of the CDP
     */
    function markLiquidatable(uint256 cdpId) external {
        if (msg.sender != address(cdpManager)) revert LiquidationNotAllowed(cdpId);
        
        if (liquidationTimestamp[cdpId] == 0) {
            liquidationTimestamp[cdpId] = block.timestamp;
        }
    }

    /**
     * @notice Pause the liquidation engine
     * @dev Only admin can call this function
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the liquidation engine
     * @dev Only admin can call this function
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
