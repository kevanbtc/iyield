// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IComplianceRegistry.sol";

/**
 * @title CSVLiquidityPool
 * @dev Liquidity pool with senior/junior waterfall distribution
 * Features:
 * - Senior tranche (70%) with priority yield
 * - Junior tranche (30%) with higher risk/reward
 * - Automated waterfall distribution
 * - Compliance-gated participation
 * - Emergency pause functionality
 */
contract CSVLiquidityPool is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    bytes32 public constant POOL_MANAGER_ROLE = keccak256("POOL_MANAGER_ROLE");
    bytes32 public constant YIELD_DISTRIBUTOR_ROLE = keccak256("YIELD_DISTRIBUTOR_ROLE");
    
    // Pool configuration
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SENIOR_ALLOCATION = 7000; // 70%
    uint256 public constant JUNIOR_ALLOCATION = 3000; // 30%
    
    enum TrancheType { Senior, Junior }
    
    // Tranche data
    struct TrancheData {
        uint256 totalDeposits;
        uint256 totalShares;
        uint256 accumulatedYield;
        uint256 yieldPerShare;
        uint256 lastUpdateTime;
    }
    
    struct UserPosition {
        uint256 shares;
        uint256 yieldDebt;
        uint256 depositTime;
        uint256 lastClaimTime;
    }
    
    // Pool state
    mapping(TrancheType => TrancheData) public tranches;
    mapping(TrancheType => mapping(address => UserPosition)) public positions;
    mapping(address => bool) public authorizedAssets;
    
    IComplianceRegistry public complianceRegistry;
    IERC20 public poolAsset; // Main pool asset (e.g., USDC)
    
    // Yield distribution
    uint256 public totalPoolAssets;
    uint256 public pendingYield;
    uint256 public lastYieldDistribution;
    
    // Pool parameters
    uint256 public seniorYieldRate = 400; // 4% APY
    uint256 public juniorYieldBonus = 200; // +2% bonus for junior
    uint256 public withdrawalFee = 50; // 0.5%
    uint256 public performanceFee = 1000; // 10%
    
    // Events
    event Deposit(
        address indexed user,
        TrancheType indexed tranche,
        uint256 amount,
        uint256 shares
    );
    
    event Withdrawal(
        address indexed user,
        TrancheType indexed tranche,
        uint256 shares,
        uint256 amount
    );
    
    event YieldDistributed(
        uint256 totalYield,
        uint256 seniorYield,
        uint256 juniorYield
    );
    
    event YieldClaimed(
        address indexed user,
        TrancheType indexed tranche,
        uint256 amount
    );
    
    constructor(
        address _poolAsset,
        address _complianceRegistry
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(POOL_MANAGER_ROLE, msg.sender);
        _grantRole(YIELD_DISTRIBUTOR_ROLE, msg.sender);
        
        poolAsset = IERC20(_poolAsset);
        complianceRegistry = IComplianceRegistry(_complianceRegistry);
        
        authorizedAssets[_poolAsset] = true;
        
        // Initialize tranches
        tranches[TrancheType.Senior].lastUpdateTime = block.timestamp;
        tranches[TrancheType.Junior].lastUpdateTime = block.timestamp;
    }
    
    /**
     * @dev Deposit into specified tranche
     */
    function deposit(
        TrancheType tranche,
        uint256 amount
    ) external nonReentrant whenNotPaused {
        require(complianceRegistry.isCompliant(msg.sender), "Address not compliant");
        require(amount > 0, "Invalid amount");
        
        // Update yield before deposit
        _updateYield();
        
        TrancheData storage trancheData = tranches[tranche];
        
        // Calculate shares to mint
        uint256 shares;
        if (trancheData.totalShares == 0) {
            shares = amount;
        } else {
            shares = (amount * trancheData.totalShares) / trancheData.totalDeposits;
        }
        
        // Update tranche data
        trancheData.totalDeposits += amount;
        trancheData.totalShares += shares;
        
        // Update user position
        UserPosition storage position = positions[tranche][msg.sender];
        position.shares += shares;
        position.yieldDebt += (shares * trancheData.yieldPerShare) / 1e18;
        position.depositTime = block.timestamp;
        
        totalPoolAssets += amount;
        
        // Transfer assets
        poolAsset.safeTransferFrom(msg.sender, address(this), amount);
        
        emit Deposit(msg.sender, tranche, amount, shares);
    }
    
    /**
     * @dev Withdraw from specified tranche
     */
    function withdraw(
        TrancheType tranche,
        uint256 shares
    ) external nonReentrant whenNotPaused {
        UserPosition storage position = positions[tranche][msg.sender];
        require(position.shares >= shares, "Insufficient shares");
        
        // Update yield before withdrawal
        _updateYield();
        
        TrancheData storage trancheData = tranches[tranche];
        
        // Calculate withdrawal amount
        uint256 amount = (shares * trancheData.totalDeposits) / trancheData.totalShares;
        
        // Apply withdrawal fee if early withdrawal
        if (block.timestamp - position.depositTime < 30 days) {
            uint256 fee = (amount * withdrawalFee) / BASIS_POINTS;
            amount -= fee;
            // Fee goes to remaining pool participants
        }
        
        // Update tranche data
        trancheData.totalDeposits -= amount;
        trancheData.totalShares -= shares;
        
        // Update user position
        position.shares -= shares;
        position.yieldDebt -= (shares * trancheData.yieldPerShare) / 1e18;
        
        totalPoolAssets -= amount;
        
        // Transfer assets
        poolAsset.safeTransfer(msg.sender, amount);
        
        emit Withdrawal(msg.sender, tranche, shares, amount);
    }
    
    /**
     * @dev Claim accumulated yield
     */
    function claimYield(TrancheType tranche) external nonReentrant whenNotPaused {
        _updateYield();
        
        UserPosition storage position = positions[tranche][msg.sender];
        TrancheData storage trancheData = tranches[tranche];
        
        // Calculate pending yield
        uint256 pendingUserYield = ((position.shares * trancheData.yieldPerShare) / 1e18) - position.yieldDebt;
        
        if (pendingUserYield > 0) {
            position.yieldDebt = (position.shares * trancheData.yieldPerShare) / 1e18;
            position.lastClaimTime = block.timestamp;
            
            // Transfer yield
            poolAsset.safeTransfer(msg.sender, pendingUserYield);
            
            emit YieldClaimed(msg.sender, tranche, pendingUserYield);
        }
    }
    
    /**
     * @dev Distribute yield using waterfall mechanism
     */
    function distributeYield(uint256 yieldAmount) external onlyRole(YIELD_DISTRIBUTOR_ROLE) {
        require(yieldAmount > 0, "Invalid yield amount");
        
        // Take performance fee
        uint256 performanceFeeAmount = (yieldAmount * performanceFee) / BASIS_POINTS;
        uint256 netYield = yieldAmount - performanceFeeAmount;
        
        // Calculate allocation based on waterfall
        (uint256 seniorYield, uint256 juniorYield) = _calculateWaterfallDistribution(netYield);
        
        // Update tranche yields
        _updateTrancheYield(TrancheType.Senior, seniorYield);
        _updateTrancheYield(TrancheType.Junior, juniorYield);
        
        pendingYield += netYield;
        lastYieldDistribution = block.timestamp;
        
        // Transfer yield to pool
        poolAsset.safeTransferFrom(msg.sender, address(this), yieldAmount);
        
        // Transfer performance fee to admin
        if (performanceFeeAmount > 0) {
            poolAsset.safeTransfer(msg.sender, performanceFeeAmount);
        }
        
        emit YieldDistributed(netYield, seniorYield, juniorYield);
    }
    
    /**
     * @dev Calculate waterfall distribution
     */
    function _calculateWaterfallDistribution(uint256 totalYield) internal view returns (uint256 seniorYield, uint256 juniorYield) {
        TrancheData memory seniorTranche = tranches[TrancheType.Senior];
        TrancheData memory juniorTranche = tranches[TrancheType.Junior];
        
        // Calculate required senior yield (guaranteed rate)
        uint256 seniorRequired = (seniorTranche.totalDeposits * seniorYieldRate) / BASIS_POINTS / 365 days;
        uint256 timeElapsed = block.timestamp - lastYieldDistribution;
        seniorRequired = (seniorRequired * timeElapsed) / 1 days;
        
        if (totalYield <= seniorRequired) {
            // All yield goes to senior tranche
            seniorYield = totalYield;
            juniorYield = 0;
        } else {
            // Senior gets required amount, junior gets remainder + bonus
            seniorYield = seniorRequired;
            juniorYield = totalYield - seniorRequired;
            
            // Apply junior bonus if available
            uint256 juniorBonus = (juniorTranche.totalDeposits * juniorYieldBonus) / BASIS_POINTS / 365 days;
            juniorBonus = (juniorBonus * timeElapsed) / 1 days;
            
            if (juniorYield > juniorBonus) {
                // Excess goes to senior tranche
                uint256 excess = juniorYield - juniorBonus;
                seniorYield += excess / 2; // 50% of excess to senior
                juniorYield = juniorBonus + (excess / 2); // 50% remains with junior
            }
        }
    }
    
    /**
     * @dev Update tranche yield
     */
    function _updateTrancheYield(TrancheType tranche, uint256 yieldAmount) internal {
        TrancheData storage trancheData = tranches[tranche];
        
        if (trancheData.totalShares > 0 && yieldAmount > 0) {
            trancheData.yieldPerShare += (yieldAmount * 1e18) / trancheData.totalShares;
            trancheData.accumulatedYield += yieldAmount;
        }
        
        trancheData.lastUpdateTime = block.timestamp;
    }
    
    /**
     * @dev Update yield for all tranches
     */
    function _updateYield() internal {
        // This can be called to update any automatic yield accrual
        // For now, yields are distributed manually via distributeYield()
    }
    
    /**
     * @dev Get user position information
     */
    function getUserPosition(TrancheType tranche, address user) external view returns (
        uint256 shares,
        uint256 depositValue,
        uint256 pendingYield
    ) {
        UserPosition memory position = positions[tranche][user];
        TrancheData memory trancheData = tranches[tranche];
        
        shares = position.shares;
        
        if (trancheData.totalShares > 0) {
            depositValue = (position.shares * trancheData.totalDeposits) / trancheData.totalShares;
        }
        
        pendingYield = ((position.shares * trancheData.yieldPerShare) / 1e18) - position.yieldDebt;
    }
    
    /**
     * @dev Get tranche information
     */
    function getTrancheInfo(TrancheType tranche) external view returns (
        uint256 totalDeposits,
        uint256 totalShares,
        uint256 accumulatedYield,
        uint256 currentAPY
    ) {
        TrancheData memory trancheData = tranches[tranche];
        
        totalDeposits = trancheData.totalDeposits;
        totalShares = trancheData.totalShares;
        accumulatedYield = trancheData.accumulatedYield;
        
        // Calculate current APY based on recent yields
        if (tranche == TrancheType.Senior) {
            currentAPY = seniorYieldRate;
        } else {
            currentAPY = seniorYieldRate + juniorYieldBonus;
        }
    }
    
    /**
     * @dev Admin functions
     */
    function setYieldRates(uint256 _seniorRate, uint256 _juniorBonus) external onlyRole(POOL_MANAGER_ROLE) {
        seniorYieldRate = _seniorRate;
        juniorYieldBonus = _juniorBonus;
    }
    
    function setFees(uint256 _withdrawalFee, uint256 _performanceFee) external onlyRole(POOL_MANAGER_ROLE) {
        require(_withdrawalFee <= 500, "Withdrawal fee too high"); // Max 5%
        require(_performanceFee <= 2000, "Performance fee too high"); // Max 20%
        
        withdrawalFee = _withdrawalFee;
        performanceFee = _performanceFee;
    }
    
    function setComplianceRegistry(address _registry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        complianceRegistry = IComplianceRegistry(_registry);
    }
    
    function addAuthorizedAsset(address asset) external onlyRole(POOL_MANAGER_ROLE) {
        authorizedAssets[asset] = true;
    }
    
    function removeAuthorizedAsset(address asset) external onlyRole(POOL_MANAGER_ROLE) {
        authorizedAssets[asset] = false;
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Emergency withdrawal (admin only)
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).safeTransfer(msg.sender, amount);
    }
}