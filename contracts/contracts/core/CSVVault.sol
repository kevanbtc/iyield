// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ERCRWACSV.sol";

/**
 * @title CSVVault
 * @dev Handles collateralized issuance and burn-on-redeem functionality
 */
contract CSVVault is ReentrancyGuard, AccessControl {
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    
    ERCRWACSV public immutable csvToken;
    
    struct Vault {
        uint256 collateralAmount;
        uint256 tokenAmount;
        bool active;
    }
    
    mapping(bytes32 => Vault) public vaults;
    
    event VaultCreated(bytes32 indexed vaultId, uint256 collateralAmount, uint256 tokenAmount);
    event VaultRedeemed(bytes32 indexed vaultId, uint256 collateralAmount, uint256 tokenAmount);
    
    constructor(address _csvToken, address defaultAdmin) {
        csvToken = ERCRWACSV(_csvToken);
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(VAULT_MANAGER_ROLE, defaultAdmin);
    }
    
    function createVault(bytes32 vaultId, uint256 tokenAmount) 
        external 
        payable 
        onlyRole(VAULT_MANAGER_ROLE) 
        nonReentrant 
    {
        require(msg.value > 0, "Collateral required");
        require(!vaults[vaultId].active, "Vault already exists");
        
        vaults[vaultId] = Vault({
            collateralAmount: msg.value,
            tokenAmount: tokenAmount,
            active: true
        });
        
        csvToken.mint(msg.sender, tokenAmount);
        
        emit VaultCreated(vaultId, msg.value, tokenAmount);
    }
    
    function redeemVault(bytes32 vaultId) 
        external 
        onlyRole(VAULT_MANAGER_ROLE) 
        nonReentrant 
    {
        Vault storage vault = vaults[vaultId];
        require(vault.active, "Vault not active");
        
        uint256 collateralAmount = vault.collateralAmount;
        uint256 tokenAmount = vault.tokenAmount;
        
        vault.active = false;
        vault.collateralAmount = 0;
        vault.tokenAmount = 0;
        
        csvToken.burn(msg.sender, tokenAmount);
        
        payable(msg.sender).transfer(collateralAmount);
        
        emit VaultRedeemed(vaultId, collateralAmount, tokenAmount);
    }
}