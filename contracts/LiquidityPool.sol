// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Vault.sol";

/**
 * @title LiquidityPool
 * @dev Liquidity pool for the iYield protocol
 * Manages liquidity provision and yield distribution
 */
contract LiquidityPool is ReentrancyGuard, Ownable {
    IERC20 public stablecoin;
    Vault public vault;
    
    uint256 public totalLiquidity;
    uint256 public yieldRate = 500; // 5% annual yield rate in basis points
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    
    mapping(address => uint256) public liquidityBalance;
    mapping(address => uint256) public lastDepositTime;
    mapping(address => uint256) public accumulatedYield;
    
    event LiquidityDeposited(address indexed provider, uint256 amount);
    event LiquidityWithdrawn(address indexed provider, uint256 amount);
    event YieldClaimed(address indexed provider, uint256 amount);
    event YieldRateUpdated(uint256 newRate);
    
    modifier validAmount(uint256 amount) {
        require(amount > 0, "Amount must be greater than 0");
        _;
    }
    
    constructor(address _stablecoin, address _vault) Ownable(msg.sender) {
        stablecoin = IERC20(_stablecoin);
        vault = Vault(_vault);
    }
    
    /**
     * @dev Deposit stablecoins to provide liquidity
     * @param amount Amount of stablecoins to deposit
     */
    function depositLiquidity(uint256 amount) external validAmount(amount) nonReentrant {
        require(stablecoin.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        // Update accumulated yield before changing balance
        _updateAccumulatedYield(msg.sender);
        
        liquidityBalance[msg.sender] += amount;
        totalLiquidity += amount;
        lastDepositTime[msg.sender] = block.timestamp;
        
        emit LiquidityDeposited(msg.sender, amount);
    }
    
    /**
     * @dev Withdraw liquidity
     * @param amount Amount of liquidity to withdraw
     */
    function withdrawLiquidity(uint256 amount) external validAmount(amount) nonReentrant {
        require(liquidityBalance[msg.sender] >= amount, "Insufficient liquidity balance");
        
        // Update accumulated yield before changing balance
        _updateAccumulatedYield(msg.sender);
        
        liquidityBalance[msg.sender] -= amount;
        totalLiquidity -= amount;
        
        require(stablecoin.transfer(msg.sender, amount), "Transfer failed");
        
        emit LiquidityWithdrawn(msg.sender, amount);
    }
    
    /**
     * @dev Claim accumulated yield
     */
    function claimYield() external nonReentrant {
        _updateAccumulatedYield(msg.sender);
        
        uint256 yieldAmount = accumulatedYield[msg.sender];
        require(yieldAmount > 0, "No yield to claim");
        
        accumulatedYield[msg.sender] = 0;
        
        require(stablecoin.transfer(msg.sender, yieldAmount), "Transfer failed");
        
        emit YieldClaimed(msg.sender, yieldAmount);
    }
    
    /**
     * @dev Update accumulated yield for a user
     * @param user User address
     */
    function _updateAccumulatedYield(address user) internal {
        if (liquidityBalance[user] > 0 && lastDepositTime[user] > 0) {
            uint256 timeElapsed = block.timestamp - lastDepositTime[user];
            uint256 yieldAmount = (liquidityBalance[user] * yieldRate * timeElapsed) / 
                                 (BASIS_POINTS * SECONDS_PER_YEAR);
            accumulatedYield[user] += yieldAmount;
        }
        lastDepositTime[user] = block.timestamp;
    }
    
    /**
     * @dev Get user's liquidity information
     * @param user User address
     * @return balance Liquidity balance
     * @return pendingYield Pending yield amount
     */
    function getUserLiquidityInfo(address user) external view returns (uint256 balance, uint256 pendingYield) {
        balance = liquidityBalance[user];
        
        if (balance > 0 && lastDepositTime[user] > 0) {
            uint256 timeElapsed = block.timestamp - lastDepositTime[user];
            uint256 newYield = (balance * yieldRate * timeElapsed) / 
                              (BASIS_POINTS * SECONDS_PER_YEAR);
            pendingYield = accumulatedYield[user] + newYield;
        } else {
            pendingYield = accumulatedYield[user];
        }
    }
    
    /**
     * @dev Update yield rate (only owner)
     * @param newRate New yield rate in basis points
     */
    function updateYieldRate(uint256 newRate) external onlyOwner {
        require(newRate <= 2000, "Yield rate too high"); // Max 20%
        yieldRate = newRate;
        emit YieldRateUpdated(newRate);
    }
    
    /**
     * @dev Add yield to the pool (called by vault or owner)
     * @param amount Amount of yield to add
     */
    function addYield(uint256 amount) external {
        require(msg.sender == address(vault) || msg.sender == owner(), "Not authorized");
        require(stablecoin.transferFrom(msg.sender, address(this), amount), "Transfer failed");
    }
    
    /**
     * @dev Emergency withdrawal by owner
     * @param token Token to withdraw
     */
    function emergencyWithdraw(address token) external onlyOwner {
        IERC20(token).transfer(owner(), IERC20(token).balanceOf(address(this)));
    }
}