// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IERC_RWA_CSV.sol";

/**
 * @title CSVLiquidityPool
 * @dev Liquidity pool with senior/junior waterfall distribution for CSV-backed tokens
 * @notice This contract implements a tranche system for risk/return optimization
 */
contract CSVLiquidityPool is ERC20, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Role definitions
    bytes32 public constant POOL_MANAGER_ROLE = keccak256("POOL_MANAGER_ROLE");
    bytes32 public constant YIELD_DISTRIBUTOR_ROLE = keccak256("YIELD_DISTRIBUTOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // Tranche types
    enum TrancheType { SENIOR, JUNIOR }
    
    // Tranche configuration
    struct TrancheConfig {
        uint256 maxAllocation;        // Maximum allocation percentage (basis points)
        uint256 minYield;            // Minimum guaranteed yield (basis points annually)
        uint256 maxYield;            // Maximum yield cap (basis points annually)
        uint256 riskWeight;          // Risk weighting factor
        bool active;                 // Tranche status
    }
    
    // User position in a tranche
    struct TranchePosition {
        uint256 amount;              // Amount deposited
        uint256 shares;              // Pool shares owned
        uint256 lastRewardBlock;     // Last block rewards were claimed
        uint256 accruedRewards;      // Unclaimed rewards
        uint256 depositTime;         // Time of deposit
    }
    
    // Pool state
    struct PoolState {
        uint256 totalAssets;         // Total assets under management
        uint256 seniorAssets;        // Assets in senior tranche
        uint256 juniorAssets;        // Assets in junior tranche
        uint256 totalYieldGenerated; // Cumulative yield generated
        uint256 lastYieldDistribution; // Last yield distribution timestamp
        bool paused;                 // Emergency pause state
    }
    
    // Storage
    IERC_RWA_CSV public immutable csvToken;
    IComplianceRegistry public immutable complianceRegistry;
    
    mapping(TrancheType => TrancheConfig) public trancheConfigs;
    mapping(address => mapping(TrancheType => TranchePosition)) public positions;
    mapping(TrancheType => uint256) public trancheTotalShares;
    mapping(TrancheType => uint256) public trancheRewardPerShare;
    
    PoolState public poolState;
    
    // Yield distribution tracking
    uint256 public constant REWARD_PRECISION = 1e18;
    uint256 public yieldDistributionPeriod = 1 days;
    uint256 public seniorProtectionRatio = 8000; // 80% protection for senior tranche
    
    // Events
    event TrancheDeposit(address indexed user, TrancheType tranche, uint256 amount, uint256 shares);
    event TrancheWithdrawal(address indexed user, TrancheType tranche, uint256 amount, uint256 shares);
    event YieldDistributed(uint256 totalYield, uint256 seniorYield, uint256 juniorYield);
    event RewardsClaimed(address indexed user, TrancheType tranche, uint256 amount);
    event TrancheConfigUpdated(TrancheType tranche, TrancheConfig config);
    event EmergencyWithdrawal(address indexed user, uint256 amount);
    
    modifier whenNotPaused() {
        require(!poolState.paused, "Pool paused");
        _;
    }
    
    modifier compliantUser(address user) {
        require(complianceRegistry.isKYCVerified(user), "User not KYC verified");
        require(complianceRegistry.isAccreditedInvestor(user), "User not accredited");
        _;
    }
    
    modifier validTranche(TrancheType tranche) {
        require(trancheConfigs[tranche].active, "Tranche not active");
        _;
    }
    
    constructor(
        string memory name,
        string memory symbol,
        address _csvToken,
        address _complianceRegistry,
        address _admin
    ) ERC20(name, symbol) {
        require(_csvToken != address(0), "Invalid CSV token");
        require(_complianceRegistry != address(0), "Invalid compliance registry");
        require(_admin != address(0), "Invalid admin");
        
        csvToken = IERC_RWA_CSV(_csvToken);
        complianceRegistry = IComplianceRegistry(_complianceRegistry);
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(POOL_MANAGER_ROLE, _admin);
        _grantRole(YIELD_DISTRIBUTOR_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        
        // Initialize tranche configurations
        trancheConfigs[TrancheType.SENIOR] = TrancheConfig({
            maxAllocation: 7000,    // 70%
            minYield: 300,          // 3% annually
            maxYield: 800,          // 8% annually
            riskWeight: 1000,       // Lower risk weight
            active: true
        });
        
        trancheConfigs[TrancheType.JUNIOR] = TrancheConfig({
            maxAllocation: 3000,    // 30%
            minYield: 0,            // No guaranteed yield
            maxYield: 2000,         // 20% annually
            riskWeight: 3000,       // Higher risk weight
            active: true
        });
        
        poolState.lastYieldDistribution = block.timestamp;
    }
    
    /**
     * @dev Deposit assets into a specific tranche
     */
    function depositToTranche(
        TrancheType tranche,
        uint256 amount
    ) external nonReentrant whenNotPaused compliantUser(msg.sender) validTranche(tranche) {
        require(amount > 0, "Invalid amount");
        require(csvToken.balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        // Check tranche allocation limits
        uint256 newTrancheTotal = (tranche == TrancheType.SENIOR ? poolState.seniorAssets : poolState.juniorAssets) + amount;
        uint256 newPoolTotal = poolState.totalAssets + amount;
        uint256 allocationPercentage = (newTrancheTotal * 10000) / newPoolTotal;
        
        require(allocationPercentage <= trancheConfigs[tranche].maxAllocation, "Exceeds tranche allocation limit");
        
        // Update rewards before changing position
        _updateRewards(msg.sender, tranche);
        
        // Calculate shares based on current tranche value
        uint256 shares;
        if (trancheTotalShares[tranche] == 0) {
            shares = amount; // Initial deposit gets 1:1 ratio
        } else {
            uint256 trancheAssets = (tranche == TrancheType.SENIOR) ? poolState.seniorAssets : poolState.juniorAssets;
            shares = (amount * trancheTotalShares[tranche]) / trancheAssets;
        }
        
        // Update position
        TranchePosition storage position = positions[msg.sender][tranche];
        position.amount += amount;
        position.shares += shares;
        position.depositTime = block.timestamp;
        
        // Update tranche and pool state
        trancheTotalShares[tranche] += shares;
        if (tranche == TrancheType.SENIOR) {
            poolState.seniorAssets += amount;
        } else {
            poolState.juniorAssets += amount;
        }
        poolState.totalAssets += amount;
        
        // Transfer tokens to pool
        csvToken.transferFrom(msg.sender, address(this), amount);
        
        emit TrancheDeposit(msg.sender, tranche, amount, shares);
    }
    
    /**
     * @dev Withdraw assets from a specific tranche
     */
    function withdrawFromTranche(
        TrancheType tranche,
        uint256 shares
    ) external nonReentrant whenNotPaused validTranche(tranche) {
        require(shares > 0, "Invalid shares");
        
        TranchePosition storage position = positions[msg.sender][tranche];
        require(position.shares >= shares, "Insufficient shares");
        
        // Update rewards before changing position
        _updateRewards(msg.sender, tranche);
        
        // Calculate withdrawal amount
        uint256 trancheAssets = (tranche == TrancheType.SENIOR) ? poolState.seniorAssets : poolState.juniorAssets;
        uint256 amount = (shares * trancheAssets) / trancheTotalShares[tranche];
        
        // Update position
        position.amount = (position.amount * (position.shares - shares)) / position.shares;
        position.shares -= shares;
        
        // Update tranche and pool state
        trancheTotalShares[tranche] -= shares;
        if (tranche == TrancheType.SENIOR) {
            poolState.seniorAssets -= amount;
        } else {
            poolState.juniorAssets -= amount;
        }
        poolState.totalAssets -= amount;
        
        // Transfer tokens back to user
        csvToken.transfer(msg.sender, amount);
        
        emit TrancheWithdrawal(msg.sender, tranche, amount, shares);
    }
    
    /**
     * @dev Distribute yield according to waterfall structure
     */
    function distributeYield(uint256 totalYield) 
        external 
        onlyRole(YIELD_DISTRIBUTOR_ROLE) 
        nonReentrant 
    {
        require(totalYield > 0, "No yield to distribute");
        require(
            block.timestamp >= poolState.lastYieldDistribution + yieldDistributionPeriod,
            "Distribution too frequent"
        );
        
        // Calculate yield distribution based on waterfall
        (uint256 seniorYield, uint256 juniorYield) = _calculateWaterfallDistribution(totalYield);
        
        // Update reward per share for each tranche
        if (trancheTotalShares[TrancheType.SENIOR] > 0) {
            trancheRewardPerShare[TrancheType.SENIOR] += 
                (seniorYield * REWARD_PRECISION) / trancheTotalShares[TrancheType.SENIOR];
        }
        
        if (trancheTotalShares[TrancheType.JUNIOR] > 0) {
            trancheRewardPerShare[TrancheType.JUNIOR] += 
                (juniorYield * REWARD_PRECISION) / trancheTotalShares[TrancheType.JUNIOR];
        }
        
        // Update pool state
        poolState.totalYieldGenerated += totalYield;
        poolState.lastYieldDistribution = block.timestamp;
        
        emit YieldDistributed(totalYield, seniorYield, juniorYield);
    }
    
    /**
     * @dev Calculate waterfall yield distribution
     */
    function _calculateWaterfallDistribution(uint256 totalYield) 
        internal 
        view 
        returns (uint256 seniorYield, uint256 juniorYield) 
    {
        TrancheConfig memory seniorConfig = trancheConfigs[TrancheType.SENIOR];
        
        // Calculate senior tranche minimum yield (guaranteed return)
        uint256 seniorMinYield = (poolState.seniorAssets * seniorConfig.minYield) / 10000;
        
        if (totalYield <= seniorMinYield) {
            // All yield goes to senior tranche if below minimum
            seniorYield = totalYield;
            juniorYield = 0;
        } else {
            // Senior gets minimum yield first
            seniorYield = seniorMinYield;
            uint256 remainingYield = totalYield - seniorMinYield;
            
            // Calculate senior protection amount
            uint256 seniorProtection = (remainingYield * seniorProtectionRatio) / 10000;
            
            // Distribute remaining yield
            seniorYield += seniorProtection;
            juniorYield = remainingYield - seniorProtection;
            
            // Apply senior yield cap
            uint256 seniorMaxYield = (poolState.seniorAssets * seniorConfig.maxYield) / 10000;
            if (seniorYield > seniorMaxYield) {
                juniorYield += seniorYield - seniorMaxYield;
                seniorYield = seniorMaxYield;
            }
        }
    }
    
    /**
     * @dev Update rewards for a user's position
     */
    function _updateRewards(address user, TrancheType tranche) internal {
        TranchePosition storage position = positions[user][tranche];
        
        if (position.shares > 0) {
            uint256 pendingReward = (position.shares * trancheRewardPerShare[tranche]) / REWARD_PRECISION 
                                  - position.accruedRewards;
            position.accruedRewards += pendingReward;
        }
        
        position.lastRewardBlock = block.number;
    }
    
    /**
     * @dev Claim accumulated rewards
     */
    function claimRewards(TrancheType tranche) 
        external 
        nonReentrant 
        whenNotPaused 
    {
        _updateRewards(msg.sender, tranche);
        
        TranchePosition storage position = positions[msg.sender][tranche];
        uint256 rewards = position.accruedRewards;
        
        require(rewards > 0, "No rewards to claim");
        
        position.accruedRewards = 0;
        
        // Transfer rewards (in practice, this might be a different token or mechanism)
        csvToken.transfer(msg.sender, rewards);
        
        emit RewardsClaimed(msg.sender, tranche, rewards);
    }
    
    /**
     * @dev Update tranche configuration
     */
    function updateTrancheConfig(
        TrancheType tranche,
        TrancheConfig memory config
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(config.maxAllocation <= 10000, "Invalid max allocation");
        require(config.maxYield >= config.minYield, "Invalid yield range");
        
        trancheConfigs[tranche] = config;
        
        emit TrancheConfigUpdated(tranche, config);
    }
    
    /**
     * @dev Emergency pause/unpause
     */
    function setPause(bool _paused) external onlyRole(EMERGENCY_ROLE) {
        poolState.paused = _paused;
    }
    
    /**
     * @dev Update yield distribution period
     */
    function setYieldDistributionPeriod(uint256 _period) 
        external 
        onlyRole(POOL_MANAGER_ROLE) 
    {
        require(_period >= 1 hours && _period <= 30 days, "Invalid period");
        yieldDistributionPeriod = _period;
    }
    
    // View functions
    
    function getPosition(address user, TrancheType tranche) 
        external 
        view 
        returns (TranchePosition memory) 
    {
        return positions[user][tranche];
    }
    
    function getPendingRewards(address user, TrancheType tranche) 
        external 
        view 
        returns (uint256) 
    {
        TranchePosition memory position = positions[user][tranche];
        if (position.shares == 0) return 0;
        
        return (position.shares * trancheRewardPerShare[tranche]) / REWARD_PRECISION 
               - position.accruedRewards;
    }
    
    function getTrancheUtilization(TrancheType tranche) 
        external 
        view 
        returns (uint256) 
    {
        if (poolState.totalAssets == 0) return 0;
        
        uint256 trancheAssets = (tranche == TrancheType.SENIOR) ? 
                               poolState.seniorAssets : poolState.juniorAssets;
        
        return (trancheAssets * 10000) / poolState.totalAssets;
    }
    
    function getPoolStats() 
        external 
        view 
        returns (
            uint256 totalAssets,
            uint256 seniorAssets,
            uint256 juniorAssets,
            uint256 totalYieldGenerated,
            uint256 seniorAPY,
            uint256 juniorAPY
        ) 
    {
        totalAssets = poolState.totalAssets;
        seniorAssets = poolState.seniorAssets;
        juniorAssets = poolState.juniorAssets;
        totalYieldGenerated = poolState.totalYieldGenerated;
        
        // Calculate estimated APYs based on recent yield distribution
        // This is simplified - a real implementation would track historical data
        if (poolState.totalYieldGenerated > 0 && totalAssets > 0) {
            uint256 timeElapsed = block.timestamp - poolState.lastYieldDistribution;
            if (timeElapsed > 0) {
                seniorAPY = seniorAssets > 0 ? (poolState.totalYieldGenerated * 365 days * 10000) / (seniorAssets * timeElapsed) : 0;
                juniorAPY = juniorAssets > 0 ? (poolState.totalYieldGenerated * 365 days * 10000) / (juniorAssets * timeElapsed) : 0;
            }
        }
    }
    
    function simulateYieldDistribution(uint256 totalYield) 
        external 
        view 
        returns (uint256 seniorYield, uint256 juniorYield) 
    {
        return _calculateWaterfallDistribution(totalYield);
    }
}