// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ComplianceRegistry
 * @dev Manages compliance and KYC/AML verification for the iYield protocol
 */
contract ComplianceRegistry is Ownable, ReentrancyGuard {
    
    // Compliance status enum
    enum ComplianceStatus {
        NOT_VERIFIED,
        PENDING,
        VERIFIED,
        REJECTED,
        SUSPENDED
    }
    
    // Compliance level enum
    enum ComplianceLevel {
        BASIC,
        INTERMEDIATE, 
        ADVANCED,
        INSTITUTIONAL
    }
    
    // User compliance data structure
    struct ComplianceData {
        ComplianceStatus status;
        ComplianceLevel level;
        uint256 verifiedAt;
        uint256 expiresAt;
        string jurisdiction;
        uint256 riskScore; // 0-100, lower is better
    }
    
    // Events
    event ComplianceUpdated(
        address indexed user,
        ComplianceStatus status,
        ComplianceLevel level,
        uint256 timestamp
    );
    
    event JurisdictionUpdated(address indexed user, string jurisdiction);
    event RiskScoreUpdated(address indexed user, uint256 riskScore);
    event ComplianceOfficerUpdated(address indexed officer, bool authorized);
    
    // State variables
    mapping(address => ComplianceData) public complianceData;
    mapping(address => bool) public complianceOfficers;
    mapping(string => bool) public allowedJurisdictions;
    
    uint256 public constant MAX_RISK_SCORE = 100;
    uint256 public constant VERIFICATION_VALIDITY_PERIOD = 365 days;
    uint256 public maxAllowedRiskScore = 80;
    
    modifier onlyComplianceOfficer() {
        require(complianceOfficers[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }
    
    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }
    
    constructor() Ownable(msg.sender) {
        // Initialize compliance officer
        complianceOfficers[msg.sender] = true;
        
        // Initialize allowed jurisdictions
        allowedJurisdictions["US"] = true;
        allowedJurisdictions["EU"] = true;
        allowedJurisdictions["UK"] = true;
        allowedJurisdictions["CA"] = true;
        allowedJurisdictions["AU"] = true;
    }
    
    /**
     * @dev Set compliance status for a user
     */
    function setComplianceStatus(
        address user,
        ComplianceStatus status,
        ComplianceLevel level,
        string calldata jurisdiction,
        uint256 riskScore
    ) external onlyComplianceOfficer validAddress(user) nonReentrant {
        require(riskScore <= MAX_RISK_SCORE, "Risk score too high");
        require(allowedJurisdictions[jurisdiction], "Jurisdiction not allowed");
        
        ComplianceData storage userData = complianceData[user];
        userData.status = status;
        userData.level = level;
        userData.jurisdiction = jurisdiction;
        userData.riskScore = riskScore;
        
        if (status == ComplianceStatus.VERIFIED) {
            userData.verifiedAt = block.timestamp;
            userData.expiresAt = block.timestamp + VERIFICATION_VALIDITY_PERIOD;
        }
        
        emit ComplianceUpdated(user, status, level, block.timestamp);
    }
    
    /**
     * @dev Check if user is compliant
     */
    function isCompliant(address user) external view returns (bool) {
        ComplianceData storage userData = complianceData[user];
        
        return userData.status == ComplianceStatus.VERIFIED &&
               userData.expiresAt > block.timestamp &&
               userData.riskScore <= maxAllowedRiskScore;
    }
    
    /**
     * @dev Get compliance data for a user
     */
    function getComplianceData(address user) external view returns (ComplianceData memory) {
        return complianceData[user];
    }
    
    /**
     * @dev Add or remove compliance officer
     */
    function setComplianceOfficer(address officer, bool authorized) 
        external 
        onlyOwner 
        validAddress(officer) 
    {
        complianceOfficers[officer] = authorized;
        emit ComplianceOfficerUpdated(officer, authorized);
    }
    
    /**
     * @dev Add or remove allowed jurisdiction
     */
    function setAllowedJurisdiction(string calldata jurisdiction, bool allowed) 
        external 
        onlyOwner 
    {
        allowedJurisdictions[jurisdiction] = allowed;
    }
    
    /**
     * @dev Update maximum allowed risk score
     */
    function setMaxAllowedRiskScore(uint256 newMaxRiskScore) external onlyOwner {
        require(newMaxRiskScore <= MAX_RISK_SCORE, "Risk score too high");
        maxAllowedRiskScore = newMaxRiskScore;
    }
    
    /**
     * @dev Batch update compliance for multiple users
     */
    function batchUpdateCompliance(
        address[] calldata users,
        ComplianceStatus[] calldata statuses,
        ComplianceLevel[] calldata levels,
        string[] calldata jurisdictions,
        uint256[] calldata riskScores
    ) external onlyComplianceOfficer nonReentrant {
        require(
            users.length == statuses.length &&
            users.length == levels.length &&
            users.length == jurisdictions.length &&
            users.length == riskScores.length,
            "Array length mismatch"
        );
        
        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "Invalid address");
            require(riskScores[i] <= MAX_RISK_SCORE, "Risk score too high");
            require(allowedJurisdictions[jurisdictions[i]], "Jurisdiction not allowed");
            
            ComplianceData storage userData = complianceData[users[i]];
            userData.status = statuses[i];
            userData.level = levels[i];
            userData.jurisdiction = jurisdictions[i];
            userData.riskScore = riskScores[i];
            
            if (statuses[i] == ComplianceStatus.VERIFIED) {
                userData.verifiedAt = block.timestamp;
                userData.expiresAt = block.timestamp + VERIFICATION_VALIDITY_PERIOD;
            }
            
            emit ComplianceUpdated(users[i], statuses[i], levels[i], block.timestamp);
        }
    }
}