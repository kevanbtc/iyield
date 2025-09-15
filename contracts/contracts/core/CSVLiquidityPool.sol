// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title CSVLiquidityPool
 * @dev Handles senior/junior tranche yield distribution
 */
contract CSVLiquidityPool is ReentrancyGuard, AccessControl {
    bytes32 public constant POOL_MANAGER_ROLE = keccak256("POOL_MANAGER_ROLE");
    
    struct Tranche {
        uint256 totalDeposits;
        uint256 yieldAccumulated;
        uint256 sharePrice;
    }
    
    Tranche public seniorTranche;
    Tranche public juniorTranche;
    
    mapping(address => uint256) public seniorDeposits;
    mapping(address => uint256) public juniorDeposits;
    
    uint256 public constant SENIOR_YIELD_RATE = 8; // 8% APY
    uint256 public constant BASIS_POINTS = 10000;
    
    event YieldDistributed(uint256 seniorYield, uint256 juniorYield);
    event DepositMade(address indexed user, uint256 amount, bool isSenior);
    
    constructor(address defaultAdmin) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(POOL_MANAGER_ROLE, defaultAdmin);
        
        seniorTranche.sharePrice = 1e18;
        juniorTranche.sharePrice = 1e18;
    }
    
    function depositSenior() external payable nonReentrant {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        seniorDeposits[msg.sender] += msg.value;
        seniorTranche.totalDeposits += msg.value;
        
        emit DepositMade(msg.sender, msg.value, true);
    }
    
    function depositJunior() external payable nonReentrant {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        
        juniorDeposits[msg.sender] += msg.value;
        juniorTranche.totalDeposits += msg.value;
        
        emit DepositMade(msg.sender, msg.value, false);
    }
    
    function distributeYield() external onlyRole(POOL_MANAGER_ROLE) {
        uint256 totalYield = address(this).balance - seniorTranche.totalDeposits - juniorTranche.totalDeposits;
        
        if (totalYield > 0) {
            // Senior tranche gets fixed yield first
            uint256 seniorYield = (seniorTranche.totalDeposits * SENIOR_YIELD_RATE) / BASIS_POINTS;
            uint256 juniorYield = totalYield > seniorYield ? totalYield - seniorYield : 0;
            
            seniorTranche.yieldAccumulated += seniorYield;
            juniorTranche.yieldAccumulated += juniorYield;
            
            emit YieldDistributed(seniorYield, juniorYield);
        }
    }
}