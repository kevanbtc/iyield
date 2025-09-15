// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ERCRWACSV.sol";

/**
 * @title CSVVault
 * @dev Collateralized vault for CSV token issuance with burn-on-redeem mechanism
 * @notice Manages CSV-backed token collateralization and redemption
 */
contract CSVVault is ReentrancyGuard, AccessControl, Pausable {
    using SafeERC20 for IERC20;
    
    // Role definitions
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    
    // Vault position structure
    struct VaultPosition {
        uint256 tokenId;
        uint256 collateralValue; // Current CSV value
        uint256 debtAmount; // Amount of tokens minted
        uint256 liquidationThreshold; // LTV at which liquidation occurs
        uint256 lastUpdateTimestamp;
        address owner;
        bool isActive;
    }
    
    // Vault configuration
    struct VaultConfig {
        uint256 maxLTV; // Maximum loan-to-value ratio (basis points)
        uint256 liquidationPenalty; // Liquidation penalty (basis points)
        uint256 minCollateralValue; // Minimum CSV value required
        uint256 stabilityFee; // Annual stability fee (basis points)
        bool isEnabled;
    }
    
    // Storage
    mapping(uint256 => VaultPosition) public vaultPositions;
    mapping(address => uint256[]) public userVaults;
    
    ERCRWACSV public immutable csvToken;
    VaultConfig public vaultConfig;
    
    uint256 public totalCollateralValue;
    uint256 public totalDebt;
    uint256 public liquidationReserve;
    uint256 private _nextVaultId = 1;
    
    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    
    // Events
    event VaultOpened(uint256 indexed vaultId, address indexed owner, uint256 collateralValue);
    event VaultClosed(uint256 indexed vaultId, address indexed owner);
    event CollateralDeposited(uint256 indexed vaultId, uint256 amount);
    event CollateralWithdrawn(uint256 indexed vaultId, uint256 amount);
    event TokensMinted(uint256 indexed vaultId, uint256 amount);
    event TokensBurned(uint256 indexed vaultId, uint256 amount);
    event VaultLiquidated(uint256 indexed vaultId, address indexed liquidator, uint256 penalty);
    event CollateralValuationUpdated(uint256 indexed vaultId, uint256 oldValue, uint256 newValue);
    event StabilityFeeAccrued(uint256 indexed vaultId, uint256 feeAmount);
    
    // Modifiers
    modifier vaultExists(uint256 vaultId) {
        require(vaultPositions[vaultId].isActive, "CSVVault: Vault does not exist");
        _;
    }
    
    modifier onlyVaultOwner(uint256 vaultId) {
        require(vaultPositions[vaultId].owner == msg.sender, "CSVVault: Not vault owner");
        _;
    }
    
    constructor(
        address _csvToken,
        VaultConfig memory _config
    ) {
        require(_csvToken != address(0), "CSVVault: Invalid token address");
        
        csvToken = ERCRWACSV(_csvToken);
        vaultConfig = _config;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VAULT_MANAGER_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        _grantRole(LIQUIDATOR_ROLE, msg.sender);
    }
    
    /**
     * @dev Open a new vault position
     */
    function openVault(
        uint256 tokenId,
        uint256 collateralValue
    ) external nonReentrant whenNotPaused returns (uint256 vaultId) {
        require(vaultConfig.isEnabled, "CSVVault: Vault creation disabled");
        require(collateralValue >= vaultConfig.minCollateralValue, "CSVVault: Insufficient collateral");
        
        // Verify token ownership and metadata
        ERCRWACSV.CSVMetadata memory metadata = csvToken.getCSVMetadata(tokenId);
        require(metadata.isActive, "CSVVault: CSV token not active");
        require(metadata.cashValue == collateralValue, "CSVVault: Collateral mismatch");
        
        vaultId = _nextVaultId++;
        
        VaultPosition storage position = vaultPositions[vaultId];
        position.tokenId = tokenId;
        position.collateralValue = collateralValue;
        position.debtAmount = 0;
        position.liquidationThreshold = (collateralValue * vaultConfig.maxLTV) / BASIS_POINTS;
        position.lastUpdateTimestamp = block.timestamp;
        position.owner = msg.sender;
        position.isActive = true;
        
        userVaults[msg.sender].push(vaultId);
        totalCollateralValue += collateralValue;
        
        emit VaultOpened(vaultId, msg.sender, collateralValue);
        
        return vaultId;
    }
    
    /**
     * @dev Mint tokens against vault collateral
     */
    function mintTokens(
        uint256 vaultId,
        uint256 amount
    ) external vaultExists(vaultId) onlyVaultOwner(vaultId) nonReentrant {
        VaultPosition storage position = vaultPositions[vaultId];
        _accrueStabilityFee(vaultId);
        
        uint256 newDebt = position.debtAmount + amount;
        uint256 currentLTV = (newDebt * BASIS_POINTS) / position.collateralValue;
        
        require(currentLTV <= vaultConfig.maxLTV, "CSVVault: Exceeds maximum LTV");
        
        position.debtAmount = newDebt;
        totalDebt += amount;
        
        // Mint tokens to user
        csvToken.mintCSVToken(
            msg.sender,
            amount,
            csvToken.getCSVMetadata(position.tokenId)
        );
        
        emit TokensMinted(vaultId, amount);
    }
    
    /**
     * @dev Burn tokens to reduce vault debt
     */
    function burnTokens(
        uint256 vaultId,
        uint256 amount
    ) external vaultExists(vaultId) onlyVaultOwner(vaultId) nonReentrant {
        VaultPosition storage position = vaultPositions[vaultId];
        require(amount <= position.debtAmount, "CSVVault: Exceeds debt amount");
        
        _accrueStabilityFee(vaultId);
        
        position.debtAmount -= amount;
        totalDebt -= amount;
        
        // Burn tokens from user
        csvToken.burnCSVToken(msg.sender, amount, position.tokenId);
        
        emit TokensBurned(vaultId, amount);
    }
    
    /**
     * @dev Close vault and withdraw collateral
     */
    function closeVault(uint256 vaultId) external vaultExists(vaultId) onlyVaultOwner(vaultId) nonReentrant {
        VaultPosition storage position = vaultPositions[vaultId];
        require(position.debtAmount == 0, "CSVVault: Outstanding debt exists");
        
        uint256 collateralValue = position.collateralValue;
        position.isActive = false;
        totalCollateralValue -= collateralValue;
        
        // Remove from user vaults
        _removeUserVault(msg.sender, vaultId);
        
        emit VaultClosed(vaultId, msg.sender);
    }
    
    /**
     * @dev Update collateral valuation via oracle
     */
    function updateCollateralValuation(
        uint256 vaultId,
        uint256 newValue
    ) external vaultExists(vaultId) onlyRole(ORACLE_ROLE) {
        VaultPosition storage position = vaultPositions[vaultId];
        uint256 oldValue = position.collateralValue;
        
        position.collateralValue = newValue;
        position.liquidationThreshold = (newValue * vaultConfig.maxLTV) / BASIS_POINTS;
        totalCollateralValue = totalCollateralValue - oldValue + newValue;
        
        emit CollateralValuationUpdated(vaultId, oldValue, newValue);
    }
    
    /**
     * @dev Liquidate undercollateralized vault
     */
    function liquidateVault(uint256 vaultId) external vaultExists(vaultId) onlyRole(LIQUIDATOR_ROLE) nonReentrant {
        VaultPosition storage position = vaultPositions[vaultId];
        _accrueStabilityFee(vaultId);
        
        uint256 currentLTV = (position.debtAmount * BASIS_POINTS) / position.collateralValue;
        require(currentLTV > vaultConfig.maxLTV, "CSVVault: Vault not liquidatable");
        
        uint256 liquidationPenalty = (position.collateralValue * vaultConfig.liquidationPenalty) / BASIS_POINTS;
        uint256 liquidatorReward = liquidationPenalty / 2;
        uint256 protocolFee = liquidationPenalty - liquidatorReward;
        
        // Update state
        totalDebt -= position.debtAmount;
        totalCollateralValue -= position.collateralValue;
        liquidationReserve += protocolFee;
        
        position.isActive = false;
        
        // Remove from user vaults
        _removeUserVault(position.owner, vaultId);
        
        // Distribute rewards
        if (liquidatorReward > 0) {
            // Transfer liquidator reward (implementation would depend on reward token)
        }
        
        emit VaultLiquidated(vaultId, msg.sender, liquidationPenalty);
    }
    
    /**
     * @dev Accrue stability fee for vault
     */
    function _accrueStabilityFee(uint256 vaultId) internal {
        VaultPosition storage position = vaultPositions[vaultId];
        
        if (position.debtAmount == 0 || vaultConfig.stabilityFee == 0) {
            return;
        }
        
        uint256 timeElapsed = block.timestamp - position.lastUpdateTimestamp;
        if (timeElapsed == 0) {
            return;
        }
        
        uint256 feeRate = (vaultConfig.stabilityFee * timeElapsed) / SECONDS_PER_YEAR;
        uint256 feeAmount = (position.debtAmount * feeRate) / BASIS_POINTS;
        
        if (feeAmount > 0) {
            position.debtAmount += feeAmount;
            totalDebt += feeAmount;
            position.lastUpdateTimestamp = block.timestamp;
            
            emit StabilityFeeAccrued(vaultId, feeAmount);
        }
    }
    
    /**
     * @dev Remove vault from user's vault list
     */
    function _removeUserVault(address user, uint256 vaultId) internal {
        uint256[] storage userVaultList = userVaults[user];
        for (uint256 i = 0; i < userVaultList.length; i++) {
            if (userVaultList[i] == vaultId) {
                userVaultList[i] = userVaultList[userVaultList.length - 1];
                userVaultList.pop();
                break;
            }
        }
    }
    
    // View functions
    function getVaultPosition(uint256 vaultId) external view returns (VaultPosition memory) {
        return vaultPositions[vaultId];
    }
    
    function getUserVaults(address user) external view returns (uint256[] memory) {
        return userVaults[user];
    }
    
    function getVaultLTV(uint256 vaultId) external view returns (uint256) {
        VaultPosition storage position = vaultPositions[vaultId];
        if (position.collateralValue == 0) return 0;
        return (position.debtAmount * BASIS_POINTS) / position.collateralValue;
    }
    
    function isLiquidatable(uint256 vaultId) external view returns (bool) {
        VaultPosition storage position = vaultPositions[vaultId];
        if (!position.isActive || position.collateralValue == 0) return false;
        
        uint256 currentLTV = (position.debtAmount * BASIS_POINTS) / position.collateralValue;
        return currentLTV > vaultConfig.maxLTV;
    }
    
    // Admin functions
    function updateVaultConfig(VaultConfig memory newConfig) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newConfig.maxLTV <= BASIS_POINTS, "CSVVault: Invalid max LTV");
        require(newConfig.liquidationPenalty <= BASIS_POINTS, "CSVVault: Invalid liquidation penalty");
        
        vaultConfig = newConfig;
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    function withdrawLiquidationReserve(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(amount <= liquidationReserve, "CSVVault: Insufficient reserves");
        liquidationReserve -= amount;
        // Implementation would transfer reserve funds
    }
}