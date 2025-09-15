// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./ComplianceRegistry.sol";
import "./OracleAdapter.sol";
import "./iYieldToken.sol";

/**
 * @title Vault
 * @dev Multi-asset vault for yield generation and asset management in the iYield protocol
 */
contract Vault is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    // Vault configuration
    struct VaultConfig {
        uint256 managementFee;      // Management fee in basis points
        uint256 performanceFee;     // Performance fee in basis points
        uint256 maxTotalAssets;     // Maximum total assets under management
        uint256 minimumDeposit;     // Minimum deposit amount
        uint256 withdrawalFee;      // Withdrawal fee in basis points
        bool depositsEnabled;       // Whether deposits are enabled
        bool withdrawalsEnabled;    // Whether withdrawals are enabled
    }
    
    // Asset configuration
    struct AssetConfig {
        bool isSupported;           // Whether the asset is supported
        uint256 maxAllocation;      // Maximum allocation percentage (basis points)
        uint256 currentAllocation;  // Current allocation percentage (basis points)
        uint256 totalDeposited;     // Total amount of this asset deposited
        address priceOracle;        // Oracle for price data
        uint8 decimals;            // Asset decimals
    }
    
    // User deposit info
    struct UserDeposit {
        uint256 shares;            // User's shares in the vault
        uint256 lastDepositTime;   // Last deposit timestamp
        uint256 totalDeposited;    // Total amount deposited by user
        uint256 totalWithdrawn;    // Total amount withdrawn by user
    }
    
    // Yield strategy info
    struct YieldStrategy {
        address strategyAddress;   // Strategy contract address
        bool isActive;            // Whether strategy is active
        uint256 allocatedAmount;  // Amount allocated to this strategy
        uint256 expectedYield;    // Expected yield rate (basis points)
        string name;              // Strategy name
    }
    
    // Events
    event Deposit(address indexed user, address indexed asset, uint256 amount, uint256 shares);
    event Withdraw(address indexed user, address indexed asset, uint256 amount, uint256 shares);
    event YieldHarvested(uint256 totalYield, uint256 timestamp);
    event StrategyAdded(address indexed strategy, string name);
    event StrategyRemoved(address indexed strategy);
    event FeesCollected(uint256 managementFee, uint256 performanceFee);
    event AssetAdded(address indexed asset, uint256 maxAllocation);
    event AssetRemoved(address indexed asset);
    
    // State variables
    ComplianceRegistry public immutable complianceRegistry;
    OracleAdapter public immutable oracleAdapter;
    iYieldToken public immutable yieldToken;
    
    VaultConfig public vaultConfig;
    mapping(address => AssetConfig) public assetConfigs;
    mapping(address => UserDeposit) public userDeposits;
    mapping(address => YieldStrategy) public yieldStrategies;
    
    address[] public supportedAssets;
    address[] public activeStrategies;
    
    uint256 public totalShares;
    uint256 public totalAssetValue;
    uint256 public lastHarvestTime;
    uint256 public accumulatedFees;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_MANAGEMENT_FEE = 500;     // 5%
    uint256 public constant MAX_PERFORMANCE_FEE = 2000;   // 20%
    uint256 public constant MAX_WITHDRAWAL_FEE = 100;     // 1%
    
    modifier onlyCompliant() {
        require(complianceRegistry.isCompliant(msg.sender), "User not compliant");
        _;
    }
    
    modifier validAsset(address asset) {
        require(assetConfigs[asset].isSupported, "Asset not supported");
        _;
    }
    
    constructor(
        address _complianceRegistry,
        address _oracleAdapter,
        address _yieldToken
    ) Ownable(msg.sender) {
        require(_complianceRegistry != address(0), "Invalid compliance registry");
        require(_oracleAdapter != address(0), "Invalid oracle adapter");
        require(_yieldToken != address(0), "Invalid yield token");
        
        complianceRegistry = ComplianceRegistry(_complianceRegistry);
        oracleAdapter = OracleAdapter(_oracleAdapter);
        yieldToken = iYieldToken(_yieldToken);
        
        // Initialize vault configuration
        vaultConfig = VaultConfig({
            managementFee: 200,        // 2%
            performanceFee: 1000,      // 10%
            maxTotalAssets: 100000000 * 10**18,  // 100M tokens
            minimumDeposit: 100 * 10**18,        // 100 tokens
            withdrawalFee: 50,         // 0.5%
            depositsEnabled: true,
            withdrawalsEnabled: true
        });
        
        lastHarvestTime = block.timestamp;
    }
    
    /**
     * @dev Deposit assets into the vault
     */
    function deposit(address asset, uint256 amount) 
        external 
        onlyCompliant 
        validAsset(asset) 
        nonReentrant 
        whenNotPaused 
    {
        require(vaultConfig.depositsEnabled, "Deposits disabled");
        require(amount >= vaultConfig.minimumDeposit, "Amount below minimum");
        
        AssetConfig storage assetConfig = assetConfigs[asset];
        uint256 assetValue = _getAssetValue(asset, amount);
        
        require(
            totalAssetValue + assetValue <= vaultConfig.maxTotalAssets,
            "Would exceed max total assets"
        );
        
        // Calculate shares to mint
        uint256 shares;
        if (totalShares == 0) {
            shares = amount; // Initial deposit
        } else {
            shares = (amount * totalShares) / _getTotalAssetValue();
        }
        
        // Update state
        UserDeposit storage userDeposit = userDeposits[msg.sender];
        userDeposit.shares += shares;
        userDeposit.lastDepositTime = block.timestamp;
        userDeposit.totalDeposited += amount;
        
        assetConfig.totalDeposited += amount;
        totalShares += shares;
        totalAssetValue += assetValue;
        
        // Transfer assets
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        
        emit Deposit(msg.sender, asset, amount, shares);
    }
    
    /**
     * @dev Withdraw assets from the vault
     */
    function withdraw(address asset, uint256 shares) 
        external 
        onlyCompliant 
        validAsset(asset) 
        nonReentrant 
        whenNotPaused 
    {
        require(vaultConfig.withdrawalsEnabled, "Withdrawals disabled");
        
        UserDeposit storage userDeposit = userDeposits[msg.sender];
        require(userDeposit.shares >= shares, "Insufficient shares");
        
        // Calculate withdrawal amount
        uint256 totalValue = _getTotalAssetValue();
        uint256 withdrawalValue = (shares * totalValue) / totalShares;
        
        AssetConfig storage assetConfig = assetConfigs[asset];
        uint256 assetPrice = _getAssetPrice(asset);
        uint256 withdrawalAmount = (withdrawalValue * 10**assetConfig.decimals) / assetPrice;
        
        // Apply withdrawal fee
        uint256 fee = (withdrawalAmount * vaultConfig.withdrawalFee) / BASIS_POINTS;
        uint256 netWithdrawal = withdrawalAmount - fee;
        
        // Update state
        userDeposit.shares -= shares;
        userDeposit.totalWithdrawn += netWithdrawal;
        
        assetConfig.totalDeposited -= withdrawalAmount;
        totalShares -= shares;
        totalAssetValue -= withdrawalValue;
        accumulatedFees += fee;
        
        // Transfer assets
        IERC20(asset).safeTransfer(msg.sender, netWithdrawal);
        
        emit Withdraw(msg.sender, asset, netWithdrawal, shares);
    }
    
    /**
     * @dev Harvest yield from strategies
     */
    function harvestYield() external onlyOwner nonReentrant {
        uint256 totalYield = 0;
        
        for (uint256 i = 0; i < activeStrategies.length; i++) {
            address strategy = activeStrategies[i];
            YieldStrategy storage strategyInfo = yieldStrategies[strategy];
            
            if (strategyInfo.isActive) {
                // Call strategy harvest function (simplified)
                // In real implementation, this would call the actual strategy contract
                uint256 strategyYield = _calculateStrategyYield(strategy);
                totalYield += strategyYield;
            }
        }
        
        // Calculate fees
        uint256 managementFee = _calculateManagementFee();
        uint256 performanceFee = (totalYield * vaultConfig.performanceFee) / BASIS_POINTS;
        
        accumulatedFees += managementFee + performanceFee;
        totalAssetValue += totalYield - performanceFee;
        lastHarvestTime = block.timestamp;
        
        emit YieldHarvested(totalYield, block.timestamp);
        emit FeesCollected(managementFee, performanceFee);
    }
    
    /**
     * @dev Add supported asset
     */
    function addAsset(
        address asset,
        uint256 maxAllocation,
        address priceOracle,
        uint8 decimals
    ) external onlyOwner {
        require(asset != address(0), "Invalid asset address");
        require(!assetConfigs[asset].isSupported, "Asset already supported");
        require(maxAllocation <= BASIS_POINTS, "Max allocation too high");
        
        assetConfigs[asset] = AssetConfig({
            isSupported: true,
            maxAllocation: maxAllocation,
            currentAllocation: 0,
            totalDeposited: 0,
            priceOracle: priceOracle,
            decimals: decimals
        });
        
        supportedAssets.push(asset);
        
        emit AssetAdded(asset, maxAllocation);
    }
    
    /**
     * @dev Remove supported asset
     */
    function removeAsset(address asset) external onlyOwner validAsset(asset) {
        require(assetConfigs[asset].totalDeposited == 0, "Asset has deposits");
        
        // Remove from array
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            if (supportedAssets[i] == asset) {
                supportedAssets[i] = supportedAssets[supportedAssets.length - 1];
                supportedAssets.pop();
                break;
            }
        }
        
        delete assetConfigs[asset];
        
        emit AssetRemoved(asset);
    }
    
    /**
     * @dev Add yield strategy
     */
    function addStrategy(
        address strategy,
        uint256 expectedYield,
        string calldata name
    ) external onlyOwner {
        require(strategy != address(0), "Invalid strategy address");
        require(!yieldStrategies[strategy].isActive, "Strategy already exists");
        
        yieldStrategies[strategy] = YieldStrategy({
            strategyAddress: strategy,
            isActive: true,
            allocatedAmount: 0,
            expectedYield: expectedYield,
            name: name
        });
        
        activeStrategies.push(strategy);
        
        emit StrategyAdded(strategy, name);
    }
    
    /**
     * @dev Remove yield strategy
     */
    function removeStrategy(address strategy) external onlyOwner {
        require(yieldStrategies[strategy].isActive, "Strategy not active");
        require(yieldStrategies[strategy].allocatedAmount == 0, "Strategy has allocations");
        
        // Remove from array
        for (uint256 i = 0; i < activeStrategies.length; i++) {
            if (activeStrategies[i] == strategy) {
                activeStrategies[i] = activeStrategies[activeStrategies.length - 1];
                activeStrategies.pop();
                break;
            }
        }
        
        delete yieldStrategies[strategy];
        
        emit StrategyRemoved(strategy);
    }
    
    /**
     * @dev Update vault configuration
     */
    function updateVaultConfig(
        uint256 managementFee,
        uint256 performanceFee,
        uint256 maxTotalAssets,
        uint256 minimumDeposit,
        uint256 withdrawalFee
    ) external onlyOwner {
        require(managementFee <= MAX_MANAGEMENT_FEE, "Management fee too high");
        require(performanceFee <= MAX_PERFORMANCE_FEE, "Performance fee too high");
        require(withdrawalFee <= MAX_WITHDRAWAL_FEE, "Withdrawal fee too high");
        
        vaultConfig.managementFee = managementFee;
        vaultConfig.performanceFee = performanceFee;
        vaultConfig.maxTotalAssets = maxTotalAssets;
        vaultConfig.minimumDeposit = minimumDeposit;
        vaultConfig.withdrawalFee = withdrawalFee;
    }
    
    /**
     * @dev Set deposits enabled/disabled
     */
    function setDepositsEnabled(bool enabled) external onlyOwner {
        vaultConfig.depositsEnabled = enabled;
    }
    
    /**
     * @dev Set withdrawals enabled/disabled
     */
    function setWithdrawalsEnabled(bool enabled) external onlyOwner {
        vaultConfig.withdrawalsEnabled = enabled;
    }
    
    /**
     * @dev Collect accumulated fees
     */
    function collectFees() external onlyOwner {
        require(accumulatedFees > 0, "No fees to collect");
        
        uint256 feesToCollect = accumulatedFees;
        accumulatedFees = 0;
        
        // Mint yield tokens as fees (simplified)
        yieldToken.transfer(owner(), feesToCollect);
    }
    
    /**
     * @dev Pause the vault
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause the vault
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Get total asset value in USD
     */
    function _getTotalAssetValue() internal view returns (uint256) {
        uint256 totalValue = 0;
        
        for (uint256 i = 0; i < supportedAssets.length; i++) {
            address asset = supportedAssets[i];
            AssetConfig storage config = assetConfigs[asset];
            
            if (config.totalDeposited > 0) {
                totalValue += _getAssetValue(asset, config.totalDeposited);
            }
        }
        
        return totalValue;
    }
    
    /**
     * @dev Get asset value in USD
     */
    function _getAssetValue(address asset, uint256 amount) internal view returns (uint256) {
        uint256 price = _getAssetPrice(asset);
        AssetConfig storage config = assetConfigs[asset];
        
        return (amount * price) / (10 ** config.decimals);
    }
    
    /**
     * @dev Get asset price from oracle
     */
    function _getAssetPrice(address asset) internal view returns (uint256) {
        AssetConfig storage config = assetConfigs[asset];
        
        // For simplicity, assuming all assets have USD price feeds
        // In real implementation, this would use the oracle adapter properly
        return 1e18; // $1 USD (placeholder)
    }
    
    /**
     * @dev Calculate management fee
     */
    function _calculateManagementFee() internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - lastHarvestTime;
        uint256 annualFee = (totalAssetValue * vaultConfig.managementFee) / BASIS_POINTS;
        
        return (annualFee * timeElapsed) / 365 days;
    }
    
    /**
     * @dev Calculate strategy yield (placeholder)
     */
    function _calculateStrategyYield(address strategy) internal view returns (uint256) {
        YieldStrategy storage strategyInfo = yieldStrategies[strategy];
        
        // Simplified calculation - in real implementation, this would
        // interact with the actual strategy contract
        uint256 timeElapsed = block.timestamp - lastHarvestTime;
        uint256 annualYield = (strategyInfo.allocatedAmount * strategyInfo.expectedYield) / BASIS_POINTS;
        
        return (annualYield * timeElapsed) / 365 days;
    }
    
    /**
     * @dev Get user share percentage
     */
    function getUserSharePercentage(address user) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (userDeposits[user].shares * BASIS_POINTS) / totalShares;
    }
    
    /**
     * @dev Get user asset value
     */
    function getUserAssetValue(address user) external view returns (uint256) {
        if (totalShares == 0) return 0;
        return (userDeposits[user].shares * _getTotalAssetValue()) / totalShares;
    }
    
    /**
     * @dev Get supported assets
     */
    function getSupportedAssets() external view returns (address[] memory) {
        return supportedAssets;
    }
    
    /**
     * @dev Get active strategies
     */
    function getActiveStrategies() external view returns (address[] memory) {
        return activeStrategies;
    }
}