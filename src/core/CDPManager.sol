// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICDPManager} from "../interfaces/ICDPManager.sol";
import {IStablecoin} from "../interfaces/IStablecoin.sol";
import {ICollateralRegistry} from "../interfaces/ICollateralRegistry.sol";

/**
 * @title CDPManager
 * @dev Central contract managing all CDP positions
 * @notice This contract handles the creation, management, and liquidation of CDP positions
 */
contract CDPManager is AccessControl, ReentrancyGuard, Pausable, ICDPManager {
    /// @notice Role that can liquidate CDPs
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");

    /// @notice Stablecoin contract
    IStablecoin public immutable stablecoin;

    /// @notice Collateral registry contract
    ICollateralRegistry public immutable collateralRegistry;

    /// @notice CDP counter for unique IDs
    uint256 public cdpCounter;

    /// @notice Mapping from CDP ID to CDP data
    mapping(uint256 => CDP) public cdps;

    /// @notice Mapping from user to their CDP IDs
    mapping(address => uint256[]) public userCDPs;

    /// @notice Mapping from CDP ID to index in user's CDP array
    mapping(uint256 => uint256) public cdpIndex;

    /// @notice CDP data structure
    struct CDP {
        address owner;
        address collateral;
        uint256 collateralAmount;
        uint256 debtAmount;
        uint256 stabilityFeeAccumulated;
        uint256 lastFeeUpdate;
        bool isLiquidated;
        uint256 createdAt;
    }



    /**
     * @dev Constructor that sets up the CDP manager
     * @param _stablecoin Address of the stablecoin contract
     * @param _collateralRegistry Address of the collateral registry contract
     */
    constructor(address _stablecoin, address _collateralRegistry) {
        if (_stablecoin == address(0) || _collateralRegistry == address(0)) revert InvalidAmount();
        
        stablecoin = IStablecoin(_stablecoin);
        collateralRegistry = ICollateralRegistry(_collateralRegistry);
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(LIQUIDATOR_ROLE, msg.sender);
    }

    /**
     * @notice Open a new CDP position
     * @dev Creates a new CDP with initial collateral deposit
     * @param collateral Address of the collateral token
     * @param amount Amount of collateral to deposit
     * @return cdpId The ID of the newly created CDP
     */
    function openCDP(address collateral, uint256 amount) external whenNotPaused nonReentrant returns (uint256 cdpId) {
        if (amount == 0) revert InvalidAmount();
        if (!collateralRegistry.isCollateralActive(collateral)) revert InvalidCollateral(collateral);

        // Transfer collateral from user
        IERC20(collateral).transferFrom(msg.sender, address(this), amount);

        // Create new CDP
        cdpId = ++cdpCounter;
        cdps[cdpId] = CDP({
            owner: msg.sender,
            collateral: collateral,
            collateralAmount: amount,
            debtAmount: 0,
            stabilityFeeAccumulated: 0,
            lastFeeUpdate: block.timestamp,
            isLiquidated: false,
            createdAt: block.timestamp
        });

        // Add to user's CDP list
        userCDPs[msg.sender].push(cdpId);
        cdpIndex[cdpId] = userCDPs[msg.sender].length - 1;

        emit CDPOpened(cdpId, msg.sender, collateral);
    }

    /**
     * @notice Deposit additional collateral to an existing CDP
     * @dev Only the CDP owner can call this function
     * @param cdpId ID of the CDP
     * @param amount Amount of collateral to deposit
     */
    function depositCollateral(uint256 cdpId, uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert InvalidAmount();
        CDP storage cdp = cdps[cdpId];
        if (cdp.owner != msg.sender) revert Unauthorized();
        if (cdp.isLiquidated) revert InvalidAmount();

        // Transfer collateral from user
        IERC20(cdp.collateral).transferFrom(msg.sender, address(this), amount);

        // Update CDP
        cdp.collateralAmount += amount;

        emit CollateralDeposited(cdpId, amount);
    }

    /**
     * @notice Withdraw collateral from a CDP
     * @dev Only the CDP owner can call this function
     * @param cdpId ID of the CDP
     * @param amount Amount of collateral to withdraw
     */
    function withdrawCollateral(uint256 cdpId, uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert InvalidAmount();
        CDP storage cdp = cdps[cdpId];
        if (cdp.owner != msg.sender) revert Unauthorized();
        if (cdp.isLiquidated) revert InvalidAmount();

        // Check if withdrawal would violate liquidation ratio
        uint256 newCollateralAmount = cdp.collateralAmount - amount;
        if (cdp.debtAmount > 0) {
            uint256 liquidationRatio = collateralRegistry.getLiquidationRatio(cdp.collateral);
            uint256 requiredCollateral = (cdp.debtAmount * liquidationRatio) / 10000;
            if (newCollateralAmount < requiredCollateral) {
                revert InsufficientCollateral(cdpId, requiredCollateral, newCollateralAmount);
            }
        }

        // Update CDP
        cdp.collateralAmount = newCollateralAmount;

        // Transfer collateral to user
        IERC20(cdp.collateral).transfer(msg.sender, amount);

        emit CollateralWithdrawn(cdpId, amount);
    }

    /**
     * @notice Mint stablecoins against CDP collateral
     * @dev Only the CDP owner can call this function
     * @param cdpId ID of the CDP
     * @param amount Amount of stablecoins to mint
     */
    function mintStablecoin(uint256 cdpId, uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert InvalidAmount();
        CDP storage cdp = cdps[cdpId];
        if (cdp.owner != msg.sender) revert Unauthorized();
        if (cdp.isLiquidated) revert InvalidAmount();

        // Check debt ceiling
        uint256 newDebtAmount = cdp.debtAmount + amount;
        uint256 debtCeiling = collateralRegistry.getDebtCeiling(cdp.collateral);
        if (newDebtAmount > debtCeiling) revert InvalidAmount();

        // Check liquidation ratio
        uint256 liquidationRatio = collateralRegistry.getLiquidationRatio(cdp.collateral);
        uint256 requiredCollateral = (newDebtAmount * liquidationRatio) / 10000;
        if (cdp.collateralAmount < requiredCollateral) {
            revert InsufficientCollateral(cdpId, requiredCollateral, cdp.collateralAmount);
        }

        // Update CDP
        cdp.debtAmount = newDebtAmount;

        // Mint stablecoins to user
        stablecoin.mint(msg.sender, amount);

        emit StablecoinMinted(cdpId, amount);
    }

    /**
     * @notice Repay debt and burn stablecoins
     * @dev Only the CDP owner can call this function
     * @param cdpId ID of the CDP
     * @param amount Amount of debt to repay
     */
    function repayDebt(uint256 cdpId, uint256 amount) external whenNotPaused nonReentrant {
        if (amount == 0) revert InvalidAmount();
        CDP storage cdp = cdps[cdpId];
        if (cdp.owner != msg.sender) revert Unauthorized();
        if (cdp.isLiquidated) revert InvalidAmount();
        if (amount > cdp.debtAmount) revert InvalidAmount();

        // Burn stablecoins from user
        stablecoin.burn(msg.sender, amount);

        // Update CDP
        cdp.debtAmount -= amount;

        emit DebtRepaid(cdpId, amount);
    }

    /**
     * @notice Liquidate an undercollateralized CDP
     * @dev Only addresses with LIQUIDATOR_ROLE can call this function
     * @param cdpId ID of the CDP to liquidate
     */
    function liquidateCDP(uint256 cdpId) external onlyRole(LIQUIDATOR_ROLE) whenNotPaused nonReentrant {
        CDP storage cdp = cdps[cdpId];
        if (cdp.isLiquidated) revert InvalidAmount();
        if (!isCDPLiquidatable(cdpId)) revert CDPNotLiquidatable(cdpId);

        // Mark as liquidated
        cdp.isLiquidated = true;

        // Calculate liquidation penalty
        uint256 liquidationPenalty = collateralRegistry.getLiquidationRatio(cdp.collateral);
        uint256 penaltyAmount = (cdp.collateralAmount * liquidationPenalty) / 10000;

        // Transfer collateral to liquidator (with penalty)
        IERC20(cdp.collateral).transfer(msg.sender, penaltyAmount);

        // Transfer remaining collateral to CDP owner
        uint256 remainingCollateral = cdp.collateralAmount - penaltyAmount;
        if (remainingCollateral > 0) {
            IERC20(cdp.collateral).transfer(cdp.owner, remainingCollateral);
        }

        emit CDPLiquidated(cdpId, msg.sender, penaltyAmount);
    }

    /**
     * @notice Get CDP owner
     * @param cdpId ID of the CDP
     * @return Owner address
     */
    function getCDPOwner(uint256 cdpId) external view returns (address) {
        return cdps[cdpId].owner;
    }

    /**
     * @notice Get CDP collateral address
     * @param cdpId ID of the CDP
     * @return Collateral token address
     */
    function getCDPCollateral(uint256 cdpId) external view returns (address) {
        return cdps[cdpId].collateral;
    }

    /**
     * @notice Get CDP collateral amount
     * @param cdpId ID of the CDP
     * @return Collateral amount
     */
    function getCDPCollateralAmount(uint256 cdpId) external view returns (uint256) {
        return cdps[cdpId].collateralAmount;
    }

    /**
     * @notice Get CDP debt amount
     * @param cdpId ID of the CDP
     * @return Debt amount
     */
    function getCDPDebt(uint256 cdpId) external view returns (uint256) {
        return cdps[cdpId].debtAmount;
    }

    /**
     * @notice Get total number of CDPs
     * @return Total CDP count
     */
    function getCDPCount() external view returns (uint256) {
        return cdpCounter;
    }

    /**
     * @notice Check if a CDP is liquidatable
     * @param cdpId ID of the CDP
     * @return True if CDP can be liquidated
     */
    function isCDPLiquidatable(uint256 cdpId) public view returns (bool) {
        CDP memory cdp = cdps[cdpId];
        if (cdp.isLiquidated || cdp.debtAmount == 0) return false;

        uint256 liquidationRatio = collateralRegistry.getLiquidationRatio(cdp.collateral);
        uint256 requiredCollateral = (cdp.debtAmount * liquidationRatio) / 10000;
        
        return cdp.collateralAmount < requiredCollateral;
    }

    /**
     * @notice Get user's CDP IDs
     * @param user User address
     * @return Array of CDP IDs
     */
    function getUserCDPs(address user) external view returns (uint256[] memory) {
        return userCDPs[user];
    }

    /**
     * @notice Pause the system
     * @dev Only admin can call this function
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause the system
     * @dev Only admin can call this function
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}
