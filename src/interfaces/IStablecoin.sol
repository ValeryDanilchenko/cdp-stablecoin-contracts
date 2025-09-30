// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStablecoin {
    // Events
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    // Errors
    error UnauthorizedMinter();
    error UnauthorizedBurner();
    error InvalidAmount();

    // Roles
    function MINTER_ROLE() external view returns (bytes32);
    function BURNER_ROLE() external view returns (bytes32);

    // Core Functions
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
}
