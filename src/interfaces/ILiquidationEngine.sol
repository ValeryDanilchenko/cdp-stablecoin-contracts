// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ILiquidationEngine {
    // Events
    event LiquidationExecuted(uint256 indexed cdpId, address indexed liquidator, uint256 collateralSeized, uint256 debtRepaid);
    event LiquidationPenaltyUpdated(address indexed collateral, uint256 oldPenalty, uint256 newPenalty);
    event LiquidationDelayUpdated(uint256 oldDelay, uint256 newDelay);

    // Errors
    error CDPNotLiquidatable(uint256 cdpId);
    error LiquidationDelayNotMet(uint256 cdpId, uint256 requiredTime, uint256 currentTime);
    error InsufficientLiquidationAmount(uint256 cdpId, uint256 required, uint256 available);
    error InvalidLiquidationPenalty(uint256 penalty);
    error LiquidationNotAllowed(uint256 cdpId);

    // Core Functions
    function liquidateCDP(uint256 cdpId) external;
    function checkLiquidation(uint256 cdpId) external view returns (bool);
    function calculateLiquidationPenalty(uint256 cdpId) external view returns (uint256);
    function getLiquidationDelay() external view returns (uint256);
    function setLiquidationDelay(uint256 newDelay) external;

    // View Functions
    function isCDPLiquidatable(uint256 cdpId) external view returns (bool);
    function getLiquidationInfo(uint256 cdpId) external view returns (
        bool isLiquidatable,
        uint256 collateralValue,
        uint256 debtValue,
        uint256 penaltyAmount,
        uint256 collateralToSeize
    );
}
