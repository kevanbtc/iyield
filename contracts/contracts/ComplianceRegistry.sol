// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IComplianceRegistry.sol";

/**
 * @title ComplianceRegistry
 * @dev Compliance-by-Design™ registry for KYC/AML verification
 * Features:
 * - Multi-level compliance (Basic to Institutional)
 * - Jurisdiction-based restrictions
 * - Risk scoring and monitoring
 * - Rule 144 lockup enforcement
 * - Reg D/S compliance gates
 */
contract ComplianceRegistry is IComplianceRegistry, AccessControl, Pausable {
    
    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    
    // Compliance data storage
    mapping(address => ComplianceData) private _complianceData;
    mapping(string => bool) public blockedJurisdictions;
    mapping(address => uint256) public lastTransferTime;
    
    // Rule 144 lockup period (365 days default)
    uint256 public rule144LockupPeriod = 365 days;
    
    // Risk scoring thresholds
    uint256 public constant MAX_RISK_SCORE = 100;
    uint256 public highRiskThreshold = 70;
    
    // Transfer restrictions
    mapping(address => mapping(address => bool)) public transferRestrictions;
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COMPLIANCE_OFFICER_ROLE, msg.sender);
        _grantRole(RISK_MANAGER_ROLE, msg.sender);
        
        // Block high-risk jurisdictions by default
        blockedJurisdictions["OFAC"] = true;
        blockedJurisdictions["NORTH_KOREA"] = true;
        blockedJurisdictions["IRAN"] = true;
    }
    
    /**
     * @dev Check if address is compliant
     */
    function isCompliant(address user) external view override returns (bool) {
        ComplianceData memory data = _complianceData[user];
        
        return data.isActive && 
               data.level != ComplianceLevel.None &&
               block.timestamp <= data.expiryTimestamp &&
               !blockedJurisdictions[data.jurisdiction] &&
               data.riskScore <= highRiskThreshold;
    }
    
    /**
     * @dev Get compliance level for address
     */
    function getComplianceLevel(address user) external view override returns (ComplianceLevel) {
        return _complianceData[user].level;
    }
    
    /**
     * @dev Check if transfer is allowed between addresses
     */
    function canTransfer(address from, address to) external view override returns (bool) {
        // Check basic compliance
        if (!this.isCompliant(from) || !this.isCompliant(to)) {
            return false;
        }
        
        // Check for specific transfer restrictions
        if (transferRestrictions[from][to]) {
            return false;
        }
        
        // Check Rule 144 lockup period
        if (block.timestamp - lastTransferTime[from] < rule144LockupPeriod) {
            // Allow transfers only to institutional level addresses during lockup
            return _complianceData[to].level == ComplianceLevel.Institutional;
        }
        
        return true;
    }
    
    /**
     * @dev Set compliance status for address
     */
    function setCompliant(
        address user,
        ComplianceLevel level,
        uint256 duration
    ) external override onlyRole(COMPLIANCE_OFFICER_ROLE) whenNotPaused {
        require(user != address(0), "Invalid address");
        require(level != ComplianceLevel.None, "Invalid compliance level");
        require(duration > 0, "Invalid duration");
        
        _complianceData[user] = ComplianceData({
            level: level,
            expiryTimestamp: block.timestamp + duration,
            isActive: true,
            jurisdiction: _complianceData[user].jurisdiction, // Keep existing jurisdiction
            riskScore: _complianceData[user].riskScore // Keep existing risk score
        });
        
        emit AddressCompliant(user, level);
    }
    
    /**
     * @dev Remove compliance status
     */
    function removeCompliance(address user) external override onlyRole(COMPLIANCE_OFFICER_ROLE) {
        _complianceData[user].isActive = false;
        _complianceData[user].level = ComplianceLevel.None;
        
        emit AddressNonCompliant(user);
    }
    
    /**
     * @dev Set jurisdiction for address
     */
    function setJurisdiction(
        address user,
        string memory jurisdiction
    ) external override onlyRole(COMPLIANCE_OFFICER_ROLE) {
        require(!blockedJurisdictions[jurisdiction], "Jurisdiction is blocked");
        
        _complianceData[user].jurisdiction = jurisdiction;
    }
    
    /**
     * @dev Block a jurisdiction
     */
    function blockJurisdiction(string memory jurisdiction) external override onlyRole(COMPLIANCE_OFFICER_ROLE) {
        blockedJurisdictions[jurisdiction] = true;
        
        emit JurisdictionBlocked(jurisdiction);
    }
    
    /**
     * @dev Unblock a jurisdiction
     */
    function unblockJurisdiction(string memory jurisdiction) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        blockedJurisdictions[jurisdiction] = false;
    }
    
    /**
     * @dev Set risk score for address
     */
    function setRiskScore(address user, uint256 score) external override onlyRole(RISK_MANAGER_ROLE) {
        require(score <= MAX_RISK_SCORE, "Risk score too high");
        
        _complianceData[user].riskScore = score;
    }
    
    /**
     * @dev Get risk score for address
     */
    function getRiskScore(address user) external view override returns (uint256) {
        return _complianceData[user].riskScore;
    }
    
    /**
     * @dev Get complete compliance data
     */
    function getComplianceData(address user) external view override returns (ComplianceData memory) {
        return _complianceData[user];
    }
    
    /**
     * @dev Set transfer restriction between specific addresses
     */
    function setTransferRestriction(
        address from,
        address to,
        bool restricted
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        transferRestrictions[from][to] = restricted;
        
        if (restricted) {
            emit TransferRestricted(from, to, "Manual restriction");
        }
    }
    
    /**
     * @dev Update Rule 144 lockup period
     */
    function setRule144LockupPeriod(uint256 period) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rule144LockupPeriod = period;
    }
    
    /**
     * @dev Update high risk threshold
     */
    function setHighRiskThreshold(uint256 threshold) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(threshold <= MAX_RISK_SCORE, "Threshold too high");
        highRiskThreshold = threshold;
    }
    
    /**
     * @dev Record transfer time for Rule 144 tracking
     */
    function recordTransfer(address from) external {
        // Only callable by approved contracts
        require(hasRole(COMPLIANCE_OFFICER_ROLE, msg.sender), "Unauthorized");
        lastTransferTime[from] = block.timestamp;
    }
    
    /**
     * @dev Batch operations for efficiency
     */
    function batchSetCompliant(
        address[] memory users,
        ComplianceLevel[] memory levels,
        uint256[] memory durations
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        require(users.length == levels.length && levels.length == durations.length, "Array length mismatch");
        
        for (uint256 i = 0; i < users.length; i++) {
            this.setCompliant(users[i], levels[i], durations[i]);
        }
    }
    
    /**
     * @dev Emergency functions
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Check if jurisdiction is blocked
     */
    function isJurisdictionBlocked(string memory jurisdiction) external view returns (bool) {
        return blockedJurisdictions[jurisdiction];
    }
    
    /**
     * @dev Get time until Rule 144 lockup expires
     */
    function getRule144TimeRemaining(address user) external view returns (uint256) {
        uint256 timeSinceLastTransfer = block.timestamp - lastTransferTime[user];
        if (timeSinceLastTransfer >= rule144LockupPeriod) {
            return 0;
        }
        return rule144LockupPeriod - timeSinceLastTransfer;
    }
}