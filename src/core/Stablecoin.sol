// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IStablecoin} from "../interfaces/IStablecoin.sol";

/**
 * @title Stablecoin
 * @dev USD-pegged stablecoin with controlled minting and burning
 * @notice This contract implements a stablecoin that can only be minted/burned by authorized contracts
 */
contract Stablecoin is ERC20, AccessControl, IStablecoin {
    /// @notice Role that can mint new stablecoins
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    /// @notice Role that can burn stablecoins
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice Maximum total supply (can be updated by admin)
    uint256 public maxSupply;

    /// @notice Emitted when max supply is updated
    event MaxSupplyUpdated(uint256 oldMaxSupply, uint256 newMaxSupply);


    /// @notice Error thrown when trying to mint more than max supply
    error ExceedsMaxSupply(uint256 requested, uint256 maxSupply);


    /**
     * @dev Constructor that sets up the stablecoin
     * @param _name Name of the stablecoin
     * @param _symbol Symbol of the stablecoin
     * @param _maxSupply Maximum total supply
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply
    ) ERC20(_name, _symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        
        maxSupply = _maxSupply;
    }

    /**
     * @notice Mint new stablecoins to a specified address
     * @dev Only addresses with MINTER_ROLE can call this function
     * @param to Address to mint stablecoins to
     * @param amount Amount of stablecoins to mint
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (amount == 0) revert InvalidAmount();
        if (totalSupply() + amount > maxSupply) {
            revert ExceedsMaxSupply(amount, maxSupply);
        }

        _mint(to, amount);
        emit Mint(to, amount);
    }

    /**
     * @notice Burn stablecoins from a specified address
     * @dev Only addresses with BURNER_ROLE can call this function
     * @param from Address to burn stablecoins from
     * @param amount Amount of stablecoins to burn
     */
    function burn(address from, uint256 amount) external onlyRole(BURNER_ROLE) {
        if (amount == 0) revert InvalidAmount();
        if (balanceOf(from) < amount) revert InvalidAmount();

        _burn(from, amount);
        emit Burn(from, amount);
    }

    /**
     * @notice Update the maximum supply
     * @dev Only admin can call this function
     * @param newMaxSupply New maximum supply
     */
    function updateMaxSupply(uint256 newMaxSupply) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newMaxSupply < totalSupply()) revert InvalidAmount();
        
        uint256 oldMaxSupply = maxSupply;
        maxSupply = newMaxSupply;
        emit MaxSupplyUpdated(oldMaxSupply, newMaxSupply);
    }

    /**
     * @notice Get the current total supply
     * @return Current total supply of stablecoins
     */
    function getTotalSupply() external view returns (uint256) {
        return totalSupply();
    }

    /**
     * @notice Check if an address can mint
     * @param account Address to check
     * @return True if address has MINTER_ROLE
     */
    function canMint(address account) external view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }

    /**
     * @notice Check if an address can burn
     * @param account Address to check
     * @return True if address has BURNER_ROLE
     */
    function canBurn(address account) external view returns (bool) {
        return hasRole(BURNER_ROLE, account);
    }
}
