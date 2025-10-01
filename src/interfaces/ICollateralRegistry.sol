// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICollateralRegistry {
    // Events
    event CollateralAdded(address indexed collateral, uint256 liquidationRatio, uint256 stabilityFee);
    event ParametersUpdated(address indexed collateral, uint256 liquidationRatio, uint256 stabilityFee);

    // Errors
    error InvalidCollateral(address collateral);
    error InvalidParameters();

    // Structs
    struct CollateralInfo {
        bool isActive;
        uint256 liquidationRatio;    // e.g., 150% = 15000 (basis points)
        uint256 stabilityFeeRate;    // e.g., 2% = 200 (basis points)
        uint256 debtCeiling;         // Maximum debt for this collateral
        uint256 liquidationPenalty;  // e.g., 13% = 1300 (basis points)
        uint256 totalDebt;
    }

    // Core Functions
    function addCollateral(
        address collateral,
        uint256 liquidationRatio,
        uint256 stabilityFee,
        uint256 liquidationPenalty,
        uint256 debtCeiling
    ) external;
    
    function updateCollateralParams(
        address collateral,
        uint256 liquidationRatio,
        uint256 stabilityFee,
        uint256 liquidationPenalty
    ) external;
    
    function removeCollateral(address collateral) external;

    // View Functions
    function getCollateralInfo(address collateral) external view returns (CollateralInfo memory);
    function isCollateralActive(address collateral) external view returns (bool);
    function getLiquidationRatio(address collateral) external view returns (uint256);
    function getStabilityFee(address collateral) external view returns (uint256);
    function getDebtCeiling(address collateral) external view returns (uint256);
    function getLiquidationPenalty(address collateral) external view returns (uint256);
    function getTotalDebt(address collateral) external view returns (uint256);
}
