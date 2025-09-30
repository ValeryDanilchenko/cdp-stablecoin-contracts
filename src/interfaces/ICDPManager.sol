// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICDPManager {
    // Events
    event CDPOpened(uint256 indexed cdpId, address indexed owner, address collateral);
    event CollateralDeposited(uint256 indexed cdpId, uint256 amount);
    event CollateralWithdrawn(uint256 indexed cdpId, uint256 amount);
    event StablecoinMinted(uint256 indexed cdpId, uint256 amount);
    event DebtRepaid(uint256 indexed cdpId, uint256 amount);
    event CDPLiquidated(uint256 indexed cdpId, address liquidator, uint256 penalty);

    // Errors
    error InvalidCollateral(address collateral);
    error InvalidAmount();
    error Unauthorized();
    error InsufficientCollateral(uint256 cdpId, uint256 required, uint256 available);
    error CDPNotLiquidatable(uint256 cdpId);
    error SystemPaused();
    error EmergencyShutdown();

    // Core Functions
    function openCDP(address collateral, uint256 amount) external returns (uint256 cdpId);
    function depositCollateral(uint256 cdpId, uint256 amount) external;
    function withdrawCollateral(uint256 cdpId, uint256 amount) external;
    function mintStablecoin(uint256 cdpId, uint256 amount) external;
    function repayDebt(uint256 cdpId, uint256 amount) external;
    function liquidateCDP(uint256 cdpId) external;

    // View Functions
    function getCDPOwner(uint256 cdpId) external view returns (address);
    function getCDPCollateral(uint256 cdpId) external view returns (address);
    function getCDPCollateralAmount(uint256 cdpId) external view returns (uint256);
    function getCDPDebt(uint256 cdpId) external view returns (uint256);
    function getCDPCount() external view returns (uint256);
    function isCDPLiquidatable(uint256 cdpId) external view returns (bool);
}
