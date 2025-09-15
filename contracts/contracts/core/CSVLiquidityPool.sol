// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ERCRWACSV.sol";

/**
 * @title CSVLiquidityPool
 * @dev Senior/junior tranche yield distribution for CSV-backed assets
 * @notice Manages liquidity pools with risk-adjusted returns
 */
contract CSVLiquidityPool is ReentrancyGuard, AccessControl, Pausable {
    using SafeERC20 for IERC20;
    
    // Role definitions
    bytes32 public constant POOL_MANAGER_ROLE = keccak256("POOL_MANAGER_ROLE");
    bytes32 public constant YIELD_DISTRIBUTOR_ROLE = keccak256("YIELD_DISTRIBUTOR_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    
    // Tranche types
    enum TrancheType { SENIOR, JUNIOR }
    
    // Tranche structure
    struct Tranche {
        uint256 totalDeposits;
        uint256 totalShares;
        uint256 yieldRate; // Annual yield rate in basis points
        uint256 priority; // Higher number = higher priority in waterfall
        uint256 minDeposit;
        uint256 lockupPeriod;
        bool isActive;
        mapping(address => uint256) userShares;
        mapping(address => uint256) userDeposits;
        mapping(address => uint256) depositTimestamp;
        mapping(address => uint256) lastYieldClaim;
    }
    
    // Pool configuration
    struct PoolConfig {
        uint256 seniorYieldRate; // Senior tranche yield rate (basis points)
        uint256 juniorYieldRate; // Junior tranche yield rate (basis points)
        uint256 protocolFeeRate; // Protocol fee (basis points)
        uint256 performanceFeeRate; // Performance fee (basis points)
        uint256 withdrawalFeeRate; // Early withdrawal fee (basis points)
        uint256 maxUtilization; // Maximum pool utilization (basis points)
    }
    
    // Yield distribution event
    struct YieldDistribution {
        uint256 timestamp;
        uint256 totalYield;
        uint256 seniorYield;
        uint256 juniorYield;
        uint256 protocolFee;
    }
    
    // Storage
    mapping(TrancheType => Tranche) private _tranches;
    ERCRWACSV public immutable csvToken;
    IERC20 public immutable baseToken; // USDC or similar stablecoin
    
    PoolConfig public poolConfig;
    uint256 public totalPoolValue;
    uint256 public protocolFeeReserve;
    uint256 public lastYieldDistribution;
    
    YieldDistribution[] public yieldHistory;
    
    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    
    // Events
    event TrancheDeposit(TrancheType indexed tranche, address indexed user, uint256 amount, uint256 shares);
    event TrancheWithdrawal(TrancheType indexed tranche, address indexed user, uint256 amount, uint256 shares);
    event YieldDistributed(uint256 totalYield, uint256 seniorYield, uint256 juniorYield, uint256 protocolFee);
    event YieldClaimed(TrancheType indexed tranche, address indexed user, uint256 amount);
    event TrancheConfigured(TrancheType indexed tranche, uint256 yieldRate, uint256 minDeposit, uint256 lockupPeriod);
    
    // Modifiers
    modifier validTranche(TrancheType tranche) {
        require(_tranches[tranche].isActive, "CSVLiquidityPool: Tranche not active");
        _;
    }
    
    constructor(
        address _csvToken,
        address _baseToken,
        PoolConfig memory _config
    ) {
        require(_csvToken != address(0), "CSVLiquidityPool: Invalid CSV token");
        require(_baseToken != address(0), "CSVLiquidityPool: Invalid base token");
        
        csvToken = ERCRWACSV(_csvToken);
        baseToken = IERC20(_baseToken);
        poolConfig = _config;
        
        // Initialize tranches
        _tranches[TrancheType.SENIOR].isActive = true;
        _tranches[TrancheType.SENIOR].yieldRate = _config.seniorYieldRate;
        _tranches[TrancheType.SENIOR].priority = 1;
        _tranches[TrancheType.SENIOR].minDeposit = 1000 * 10**6; // 1000 USDC
        _tranches[TrancheType.SENIOR].lockupPeriod = 90 days;
        
        _tranches[TrancheType.JUNIOR].isActive = true;
        _tranches[TrancheType.JUNIOR].yieldRate = _config.juniorYieldRate;
        _tranches[TrancheType.JUNIOR].priority = 0;
        _tranches[TrancheType.JUNIOR].minDeposit = 10000 * 10**6; // 10000 USDC
        _tranches[TrancheType.JUNIOR].lockupPeriod = 180 days;
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(POOL_MANAGER_ROLE, msg.sender);
        _grantRole(YIELD_DISTRIBUTOR_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        
        lastYieldDistribution = block.timestamp;
    }
    
    /**
     * @dev Deposit into a tranche
     */
    function deposit(
        TrancheType tranche,
        uint256 amount
    ) external validTranche(tranche) nonReentrant whenNotPaused {
        require(amount >= _tranches[tranche].minDeposit, "CSVLiquidityPool: Below minimum deposit");
        
        Tranche storage trancheData = _tranches[tranche];
        
        // Check compliance
        ERCRWACSV.ComplianceData memory compliance = csvToken.getComplianceData(msg.sender);
        require(compliance.isKYCVerified, "CSVLiquidityPool: KYC verification required");
        require(compliance.isAccredited, "CSVLiquidityPool: Accredited investor required");
        
        // Calculate shares
        uint256 shares;
        if (trancheData.totalShares == 0) {
            shares = amount;
        } else {
            shares = (amount * trancheData.totalShares) / trancheData.totalDeposits;
        }
        
        // Transfer tokens
        baseToken.safeTransferFrom(msg.sender, address(this), amount);
        
        // Update state
        trancheData.totalDeposits += amount;
        trancheData.totalShares += shares;
        trancheData.userShares[msg.sender] += shares;
        trancheData.userDeposits[msg.sender] += amount;
        trancheData.depositTimestamp[msg.sender] = block.timestamp;
        trancheData.lastYieldClaim[msg.sender] = block.timestamp;
        
        totalPoolValue += amount;
        
        emit TrancheDeposit(tranche, msg.sender, amount, shares);
    }
    
    /**
     * @dev Withdraw from a tranche
     */
    function withdraw(
        TrancheType tranche,
        uint256 shares
    ) external validTranche(tranche) nonReentrant {
        Tranche storage trancheData = _tranches[tranche];
        require(shares <= trancheData.userShares[msg.sender], "CSVLiquidityPool: Insufficient shares");
        
        // Check lockup period
        uint256 timeSinceDeposit = block.timestamp - trancheData.depositTimestamp[msg.sender];
        bool isEarlyWithdrawal = timeSinceDeposit < trancheData.lockupPeriod;
        
        // Calculate withdrawal amount
        uint256 amount = (shares * trancheData.totalDeposits) / trancheData.totalShares;
        uint256 withdrawalFee = 0;
        
        if (isEarlyWithdrawal) {
            withdrawalFee = (amount * poolConfig.withdrawalFeeRate) / BASIS_POINTS;
            amount -= withdrawalFee;
            protocolFeeReserve += withdrawalFee;
        }
        
        // Update state
        trancheData.totalDeposits -= (amount + withdrawalFee);
        trancheData.totalShares -= shares;
        trancheData.userShares[msg.sender] -= shares;
        trancheData.userDeposits[msg.sender] -= (amount + withdrawalFee);
        
        totalPoolValue -= (amount + withdrawalFee);
        
        // Transfer tokens
        baseToken.safeTransfer(msg.sender, amount);
        
        emit TrancheWithdrawal(tranche, msg.sender, amount, shares);
    }
    
    /**
     * @dev Distribute yield following waterfall structure
     */
    function distributeYield(uint256 totalYield) external onlyRole(YIELD_DISTRIBUTOR_ROLE) nonReentrant {
        require(totalYield > 0, "CSVLiquidityPool: No yield to distribute");
        
        uint256 protocolFee = (totalYield * poolConfig.protocolFeeRate) / BASIS_POINTS;
        uint256 remainingYield = totalYield - protocolFee;
        
        protocolFeeReserve += protocolFee;
        
        // Senior tranche gets priority
        Tranche storage seniorTranche = _tranches[TrancheType.SENIOR];
        Tranche storage juniorTranche = _tranches[TrancheType.JUNIOR];
        
        uint256 seniorYieldDue = (seniorTranche.totalDeposits * seniorTranche.yieldRate) / BASIS_POINTS;
        uint256 seniorYield = seniorYieldDue > remainingYield ? remainingYield : seniorYieldDue;
        uint256 juniorYield = remainingYield - seniorYield;
        
        // Update tranche values
        if (seniorYield > 0 && seniorTranche.totalShares > 0) {
            seniorTranche.totalDeposits += seniorYield;
            totalPoolValue += seniorYield;
        }
        
        if (juniorYield > 0 && juniorTranche.totalShares > 0) {
            juniorTranche.totalDeposits += juniorYield;
            totalPoolValue += juniorYield;
        }
        
        // Record distribution
        yieldHistory.push(YieldDistribution({
            timestamp: block.timestamp,
            totalYield: totalYield,
            seniorYield: seniorYield,
            juniorYield: juniorYield,
            protocolFee: protocolFee
        }));
        
        lastYieldDistribution = block.timestamp;
        
        emit YieldDistributed(totalYield, seniorYield, juniorYield, protocolFee);
    }
    
    /**
     * @dev Claim accrued yield for user
     */
    function claimYield(TrancheType tranche) external validTranche(tranche) nonReentrant {
        Tranche storage trancheData = _tranches[tranche];
        require(trancheData.userShares[msg.sender] > 0, "CSVLiquidityPool: No shares");
        
        uint256 currentValue = (trancheData.userShares[msg.sender] * trancheData.totalDeposits) / trancheData.totalShares;
        uint256 originalDeposit = trancheData.userDeposits[msg.sender];
        
        if (currentValue > originalDeposit) {
            uint256 yield = currentValue - originalDeposit;
            uint256 performanceFee = (yield * poolConfig.performanceFeeRate) / BASIS_POINTS;
            uint256 netYield = yield - performanceFee;
            
            protocolFeeReserve += performanceFee;
            trancheData.totalDeposits -= yield;
            totalPoolValue -= yield;
            
            baseToken.safeTransfer(msg.sender, netYield);
            
            emit YieldClaimed(tranche, msg.sender, netYield);
        }
        
        trancheData.lastYieldClaim[msg.sender] = block.timestamp;
    }
    
    // View functions
    function getUserPosition(TrancheType tranche, address user) external view returns (
        uint256 shares,
        uint256 deposits,
        uint256 currentValue,
        uint256 depositTimestamp,
        uint256 lockupExpiry
    ) {
        Tranche storage trancheData = _tranches[tranche];
        shares = trancheData.userShares[user];
        deposits = trancheData.userDeposits[user];
        
        if (trancheData.totalShares > 0) {
            currentValue = (shares * trancheData.totalDeposits) / trancheData.totalShares;
        }
        
        depositTimestamp = trancheData.depositTimestamp[user];
        lockupExpiry = depositTimestamp + trancheData.lockupPeriod;
    }
    
    function getTrancheInfo(TrancheType tranche) external view returns (
        uint256 totalDeposits,
        uint256 totalShares,
        uint256 yieldRate,
        uint256 priority,
        uint256 minDeposit,
        uint256 lockupPeriod,
        bool isActive
    ) {
        Tranche storage trancheData = _tranches[tranche];
        return (
            trancheData.totalDeposits,
            trancheData.totalShares,
            trancheData.yieldRate,
            trancheData.priority,
            trancheData.minDeposit,
            trancheData.lockupPeriod,
            trancheData.isActive
        );
    }
    
    function getPoolUtilization() external view returns (uint256) {
        if (totalPoolValue == 0) return 0;
        uint256 utilizedValue = csvToken.totalCSVValue();
        return (utilizedValue * BASIS_POINTS) / totalPoolValue;
    }
    
    function getYieldHistory(uint256 index) external view returns (YieldDistribution memory) {
        require(index < yieldHistory.length, "CSVLiquidityPool: Invalid index");
        return yieldHistory[index];
    }
    
    function getYieldHistoryLength() external view returns (uint256) {
        return yieldHistory.length;
    }
    
    // Admin functions
    function configureTrancheData(
        TrancheType tranche,
        uint256 yieldRate,
        uint256 minDeposit,
        uint256 lockupPeriod
    ) external onlyRole(POOL_MANAGER_ROLE) {
        Tranche storage trancheData = _tranches[tranche];
        trancheData.yieldRate = yieldRate;
        trancheData.minDeposit = minDeposit;
        trancheData.lockupPeriod = lockupPeriod;
        
        emit TrancheConfigured(tranche, yieldRate, minDeposit, lockupPeriod);
    }
    
    function updatePoolConfig(PoolConfig memory newConfig) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newConfig.maxUtilization <= BASIS_POINTS, "CSVLiquidityPool: Invalid max utilization");
        require(newConfig.protocolFeeRate <= BASIS_POINTS, "CSVLiquidityPool: Invalid protocol fee");
        require(newConfig.performanceFeeRate <= BASIS_POINTS, "CSVLiquidityPool: Invalid performance fee");
        require(newConfig.withdrawalFeeRate <= BASIS_POINTS, "CSVLiquidityPool: Invalid withdrawal fee");
        
        poolConfig = newConfig;
    }
    
    function withdrawProtocolFees(address to, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(amount <= protocolFeeReserve, "CSVLiquidityPool: Insufficient reserves");
        protocolFeeReserve -= amount;
        baseToken.safeTransfer(to, amount);
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}