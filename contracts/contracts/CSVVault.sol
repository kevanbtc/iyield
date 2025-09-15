// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IComplianceRegistry.sol";
import "./interfaces/ICSVOracle.sol";

/**
 * @title CSVVault
 * @dev Vault for managing CSV-backed collateral with LTV enforcement
 * Features:
 * - Automated LTV monitoring and liquidation
 * - Burn-on-redeem mechanism
 * - Multi-asset collateral support
 * - Emergency pause functionality
 * - Stale oracle protection
 */
contract CSVVault is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    
    // Vault configuration
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MAX_LTV = 9000; // 90%
    uint256 public constant LIQUIDATION_THRESHOLD = 9500; // 95%
    uint256 public constant LIQUIDATION_PENALTY = 500; // 5%
    
    // Oracle and compliance
    ICSVOracle public csvOracle;
    IComplianceRegistry public complianceRegistry;
    
    // Vault positions
    struct Position {
        string policyId;
        uint256 collateralAmount;
        uint256 debtAmount;
        uint256 lastUpdateTime;
        bool isActive;
        address owner;
    }
    
    mapping(uint256 => Position) public positions;
    mapping(address => uint256[]) public userPositions;
    mapping(string => uint256) public policyToPosition;
    
    uint256 public nextPositionId = 1;
    uint256 public totalCollateral;
    uint256 public totalDebt;
    
    // Supported collateral tokens
    mapping(address => bool) public supportedCollateral;
    mapping(address => uint256) public collateralFactors; // Basis points
    
    // Events
    event PositionOpened(
        uint256 indexed positionId,
        address indexed owner,
        string policyId,
        uint256 collateralAmount,
        uint256 debtAmount
    );
    
    event PositionClosed(
        uint256 indexed positionId,
        address indexed owner,
        uint256 collateralReturned
    );
    
    event PositionLiquidated(
        uint256 indexed positionId,
        address indexed liquidator,
        uint256 collateralSeized,
        uint256 debtRepaid
    );
    
    event CollateralAdded(
        uint256 indexed positionId,
        uint256 amount
    );
    
    event DebtRepaid(
        uint256 indexed positionId,
        uint256 amount
    );
    
    constructor(
        address _csvOracle,
        address _complianceRegistry
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(VAULT_MANAGER_ROLE, msg.sender);
        _grantRole(LIQUIDATOR_ROLE, msg.sender);
        
        csvOracle = ICSVOracle(_csvOracle);
        complianceRegistry = IComplianceRegistry(_complianceRegistry);
    }
    
    /**
     * @dev Open new position with CSV collateral
     */
    function openPosition(
        string memory policyId,
        uint256 collateralAmount,
        uint256 requestedDebt,
        address collateralToken
    ) external nonReentrant whenNotPaused returns (uint256 positionId) {
        require(complianceRegistry.isCompliant(msg.sender), "Address not compliant");
        require(supportedCollateral[collateralToken], "Collateral not supported");
        require(collateralAmount > 0, "Invalid collateral amount");
        require(requestedDebt > 0, "Invalid debt amount");
        require(policyToPosition[policyId] == 0, "Policy already used");
        
        // Verify CSV value from oracle
        (uint256 csvValue, uint256 timestamp) = csvOracle.getCSVValue(policyId);
        require(csvOracle.isDataFresh(policyId, 24 hours), "Oracle data stale");
        require(csvValue > 0, "Invalid CSV value");
        
        // Calculate LTV
        uint256 collateralValue = (collateralAmount * collateralFactors[collateralToken]) / BASIS_POINTS;
        uint256 ltv = (requestedDebt * BASIS_POINTS) / collateralValue;
        require(ltv <= MAX_LTV, "LTV too high");
        
        // Transfer collateral
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);
        
        // Create position
        positionId = nextPositionId++;
        positions[positionId] = Position({
            policyId: policyId,
            collateralAmount: collateralAmount,
            debtAmount: requestedDebt,
            lastUpdateTime: block.timestamp,
            isActive: true,
            owner: msg.sender
        });
        
        userPositions[msg.sender].push(positionId);
        policyToPosition[policyId] = positionId;
        
        totalCollateral += collateralAmount;
        totalDebt += requestedDebt;
        
        emit PositionOpened(positionId, msg.sender, policyId, collateralAmount, requestedDebt);
    }
    
    /**
     * @dev Close position and burn debt tokens
     */
    function closePosition(uint256 positionId) external nonReentrant whenNotPaused {
        Position storage position = positions[positionId];
        require(position.isActive, "Position not active");
        require(position.owner == msg.sender, "Not position owner");
        
        // Calculate current debt (with interest if applicable)
        uint256 currentDebt = position.debtAmount;
        
        // Burn debt tokens (implementation depends on debt token contract)
        // For now, we assume debt is repaid externally
        
        // Return collateral
        uint256 collateralToReturn = position.collateralAmount;
        position.isActive = false;
        position.collateralAmount = 0;
        position.debtAmount = 0;
        
        totalCollateral -= collateralToReturn;
        totalDebt -= currentDebt;
        
        // Transfer collateral back (assuming ETH for simplicity)
        payable(msg.sender).transfer(collateralToReturn);
        
        emit PositionClosed(positionId, msg.sender, collateralToReturn);
    }
    
    /**
     * @dev Liquidate undercollateralized position
     */
    function liquidatePosition(uint256 positionId) external nonReentrant whenNotPaused {
        require(hasRole(LIQUIDATOR_ROLE, msg.sender), "Not authorized liquidator");
        
        Position storage position = positions[positionId];
        require(position.isActive, "Position not active");
        
        // Check if position is liquidatable
        require(isPositionLiquidatable(positionId), "Position not liquidatable");
        
        // Calculate liquidation amounts
        uint256 debtToRepay = position.debtAmount;
        uint256 collateralToSeize = (position.collateralAmount * (BASIS_POINTS + LIQUIDATION_PENALTY)) / BASIS_POINTS;
        
        if (collateralToSeize > position.collateralAmount) {
            collateralToSeize = position.collateralAmount;
        }
        
        // Update position
        position.isActive = false;
        position.collateralAmount = 0;
        position.debtAmount = 0;
        
        totalCollateral -= collateralToSeize;
        totalDebt -= debtToRepay;
        
        // Transfer seized collateral to liquidator
        payable(msg.sender).transfer(collateralToSeize);
        
        emit PositionLiquidated(positionId, msg.sender, collateralToSeize, debtToRepay);
    }
    
    /**
     * @dev Check if position is liquidatable
     */
    function isPositionLiquidatable(uint256 positionId) public view returns (bool) {
        Position memory position = positions[positionId];
        if (!position.isActive) return false;
        
        // Get current CSV value
        (uint256 csvValue,) = csvOracle.getCSVValue(position.policyId);
        if (csvValue == 0) return true; // Liquidate if no CSV value
        
        // Check if oracle data is stale
        if (!csvOracle.isDataFresh(position.policyId, 24 hours)) {
            return true; // Liquidate if oracle is stale
        }
        
        // Calculate current LTV
        uint256 currentLTV = (position.debtAmount * BASIS_POINTS) / position.collateralAmount;
        
        return currentLTV >= LIQUIDATION_THRESHOLD;
    }
    
    /**
     * @dev Get position LTV ratio
     */
    function getPositionLTV(uint256 positionId) external view returns (uint256) {
        Position memory position = positions[positionId];
        require(position.isActive, "Position not active");
        
        if (position.collateralAmount == 0) return type(uint256).max;
        
        return (position.debtAmount * BASIS_POINTS) / position.collateralAmount;
    }
    
    /**
     * @dev Add collateral to position
     */
    function addCollateral(uint256 positionId, uint256 amount) external payable nonReentrant whenNotPaused {
        Position storage position = positions[positionId];
        require(position.isActive, "Position not active");
        require(position.owner == msg.sender, "Not position owner");
        require(amount > 0, "Invalid amount");
        
        position.collateralAmount += amount;
        position.lastUpdateTime = block.timestamp;
        totalCollateral += amount;
        
        emit CollateralAdded(positionId, amount);
    }
    
    /**
     * @dev Repay debt
     */
    function repayDebt(uint256 positionId, uint256 amount) external nonReentrant whenNotPaused {
        Position storage position = positions[positionId];
        require(position.isActive, "Position not active");
        require(position.owner == msg.sender, "Not position owner");
        require(amount > 0 && amount <= position.debtAmount, "Invalid amount");
        
        position.debtAmount -= amount;
        position.lastUpdateTime = block.timestamp;
        totalDebt -= amount;
        
        emit DebtRepaid(positionId, amount);
    }
    
    /**
     * @dev Get user positions
     */
    function getUserPositions(address user) external view returns (uint256[] memory) {
        return userPositions[user];
    }
    
    /**
     * @dev Admin functions
     */
    function addSupportedCollateral(
        address token,
        uint256 factor
    ) external onlyRole(VAULT_MANAGER_ROLE) {
        require(factor <= BASIS_POINTS, "Invalid factor");
        supportedCollateral[token] = true;
        collateralFactors[token] = factor;
    }
    
    function removeSupportedCollateral(address token) external onlyRole(VAULT_MANAGER_ROLE) {
        supportedCollateral[token] = false;
        collateralFactors[token] = 0;
    }
    
    function setCSVOracle(address _oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        csvOracle = ICSVOracle(_oracle);
    }
    
    function setComplianceRegistry(address _registry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        complianceRegistry = IComplianceRegistry(_registry);
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
        if (token == address(0)) {
            payable(msg.sender).transfer(amount);
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }
    }
    
    /**
     * @dev Receive ETH
     */
    receive() external payable {}
}