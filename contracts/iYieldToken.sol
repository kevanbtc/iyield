// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ComplianceRegistry.sol";

/**
 * @title iYieldToken
 * @dev ERC20 token with yield generation, compliance integration, and governance features
 */
contract iYieldToken is ERC20, ERC20Burnable, ERC20Pausable, Ownable, ReentrancyGuard {
    
    // Yield configuration
    struct YieldConfig {
        uint256 baseRate;      // Base yield rate (basis points)
        uint256 bonusRate;     // Bonus rate for higher compliance levels
        uint256 lastUpdate;    // Last yield calculation timestamp
        bool enabled;          // Yield generation enabled/disabled
    }
    
    // User yield data
    struct UserYield {
        uint256 accruedYield;     // Accrued yield not yet claimed
        uint256 lastClaimTime;    // Last time yield was claimed
        uint256 totalClaimed;     // Total yield claimed
        uint256 yieldRate;        // Personal yield rate
    }
    
    // Events
    event YieldClaimed(address indexed user, uint256 amount);
    event YieldConfigUpdated(uint256 baseRate, uint256 bonusRate, bool enabled);
    event ComplianceRegistryUpdated(address indexed registry);
    event MinimumBalanceUpdated(uint256 newMinimum);
    event YieldAccrued(address indexed user, uint256 amount);
    
    // State variables
    ComplianceRegistry public complianceRegistry;
    YieldConfig public yieldConfig;
    mapping(address => UserYield) public userYield;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public minimumBalanceForYield = 100 * 10**18; // 100 tokens
    uint256 public totalYieldDistributed;
    
    // Compliance levels yield multipliers (basis points)
    mapping(ComplianceRegistry.ComplianceLevel => uint256) public levelMultipliers;
    
    modifier onlyCompliant() {
        require(
            address(complianceRegistry) == address(0) || 
            complianceRegistry.isCompliant(msg.sender), 
            "User not compliant"
        );
        _;
    }
    
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address _complianceRegistry
    ) ERC20(name, symbol) Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
        
        if (_complianceRegistry != address(0)) {
            complianceRegistry = ComplianceRegistry(_complianceRegistry);
        }
        
        // Initialize yield configuration
        yieldConfig = YieldConfig({
            baseRate: 500,      // 5% APY
            bonusRate: 200,     // 2% bonus
            lastUpdate: block.timestamp,
            enabled: true
        });
        
        // Initialize compliance level multipliers
        levelMultipliers[ComplianceRegistry.ComplianceLevel.BASIC] = 10000;        // 1x
        levelMultipliers[ComplianceRegistry.ComplianceLevel.INTERMEDIATE] = 11000;  // 1.1x
        levelMultipliers[ComplianceRegistry.ComplianceLevel.ADVANCED] = 12000;     // 1.2x
        levelMultipliers[ComplianceRegistry.ComplianceLevel.INSTITUTIONAL] = 15000; // 1.5x
    }
    
    /**
     * @dev Update accrued yield for a user
     */
    function _updateYield(address user) internal {
        if (!yieldConfig.enabled || balanceOf(user) < minimumBalanceForYield) {
            return;
        }
        
        UserYield storage userData = userYield[user];
        uint256 timeElapsed = block.timestamp - userData.lastClaimTime;
        
        if (timeElapsed == 0) return;
        
        // Calculate base yield
        uint256 userBalance = balanceOf(user);
        uint256 baseYield = (userBalance * yieldConfig.baseRate * timeElapsed) / 
                           (BASIS_POINTS * SECONDS_PER_YEAR);
        
        // Apply compliance level multiplier
        uint256 multiplier = BASIS_POINTS;
        if (address(complianceRegistry) != address(0)) {
            ComplianceRegistry.ComplianceData memory complianceData = 
                complianceRegistry.getComplianceData(user);
            multiplier = levelMultipliers[complianceData.level];
        }
        
        uint256 finalYield = (baseYield * multiplier) / BASIS_POINTS;
        userData.accruedYield += finalYield;
        userData.lastClaimTime = block.timestamp;
        
        emit YieldAccrued(user, finalYield);
    }
    
    /**
     * @dev Claim accrued yield
     */
    function claimYield() external onlyCompliant nonReentrant {
        _updateYield(msg.sender);
        
        UserYield storage userData = userYield[msg.sender];
        uint256 claimableYield = userData.accruedYield;
        
        require(claimableYield > 0, "No yield to claim");
        
        userData.accruedYield = 0;
        userData.totalClaimed += claimableYield;
        totalYieldDistributed += claimableYield;
        
        _mint(msg.sender, claimableYield);
        
        emit YieldClaimed(msg.sender, claimableYield);
    }
    
    /**
     * @dev Get claimable yield for a user
     */
    function getClaimableYield(address user) external view returns (uint256) {
        if (!yieldConfig.enabled || balanceOf(user) < minimumBalanceForYield) {
            return userYield[user].accruedYield;
        }
        
        UserYield memory userData = userYield[user];
        uint256 timeElapsed = block.timestamp - userData.lastClaimTime;
        
        if (timeElapsed == 0) return userData.accruedYield;
        
        // Calculate pending yield
        uint256 userBalance = balanceOf(user);
        uint256 baseYield = (userBalance * yieldConfig.baseRate * timeElapsed) / 
                           (BASIS_POINTS * SECONDS_PER_YEAR);
        
        // Apply compliance level multiplier
        uint256 multiplier = BASIS_POINTS;
        if (address(complianceRegistry) != address(0)) {
            ComplianceRegistry.ComplianceData memory complianceData = 
                complianceRegistry.getComplianceData(user);
            multiplier = levelMultipliers[complianceData.level];
        }
        
        uint256 pendingYield = (baseYield * multiplier) / BASIS_POINTS;
        return userData.accruedYield + pendingYield;
    }
    
    /**
     * @dev Transfer with compliance check and yield update
     */
    function transfer(address to, uint256 amount) 
        public 
        override 
        onlyCompliant 
        returns (bool) 
    {
        _updateYield(msg.sender);
        _updateYield(to);
        return super.transfer(to, amount);
    }
    
    /**
     * @dev Transfer from with compliance check and yield update
     */
    function transferFrom(address from, address to, uint256 amount) 
        public 
        override 
        onlyCompliant 
        returns (bool) 
    {
        _updateYield(from);
        _updateYield(to);
        return super.transferFrom(from, to, amount);
    }
    
    /**
     * @dev Update yield configuration
     */
    function updateYieldConfig(
        uint256 baseRate,
        uint256 bonusRate,
        bool enabled
    ) external onlyOwner {
        require(baseRate <= 2000, "Base rate too high"); // Max 20% APY
        require(bonusRate <= 1000, "Bonus rate too high"); // Max 10% bonus
        
        yieldConfig.baseRate = baseRate;
        yieldConfig.bonusRate = bonusRate;
        yieldConfig.enabled = enabled;
        yieldConfig.lastUpdate = block.timestamp;
        
        emit YieldConfigUpdated(baseRate, bonusRate, enabled);
    }
    
    /**
     * @dev Update compliance registry
     */
    function updateComplianceRegistry(address _complianceRegistry) external onlyOwner {
        complianceRegistry = ComplianceRegistry(_complianceRegistry);
        emit ComplianceRegistryUpdated(_complianceRegistry);
    }
    
    /**
     * @dev Update minimum balance for yield
     */
    function updateMinimumBalanceForYield(uint256 _minimumBalance) external onlyOwner {
        minimumBalanceForYield = _minimumBalance;
        emit MinimumBalanceUpdated(_minimumBalance);
    }
    
    /**
     * @dev Update compliance level multipliers
     */
    function updateLevelMultiplier(
        ComplianceRegistry.ComplianceLevel level,
        uint256 multiplier
    ) external onlyOwner {
        require(multiplier >= BASIS_POINTS && multiplier <= 20000, "Invalid multiplier");
        levelMultipliers[level] = multiplier;
    }
    
    /**
     * @dev Pause contract
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Hook called before token transfer
     */
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
        
        // Update yield tracking when tokens are transferred
        if (from != address(0) && userYield[from].lastClaimTime == 0) {
            userYield[from].lastClaimTime = block.timestamp;
        }
        if (to != address(0) && userYield[to].lastClaimTime == 0) {
            userYield[to].lastClaimTime = block.timestamp;
        }
    }
    
    /**
     * @dev Get user yield information
     */
    function getUserYieldInfo(address user) external view returns (UserYield memory) {
        return userYield[user];
    }
    
    /**
     * @dev Emergency withdrawal for owner (only paused state)
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(paused(), "Contract must be paused");
        require(amount <= balanceOf(address(this)), "Insufficient balance");
        _transfer(address(this), owner(), amount);
    }
}