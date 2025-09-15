// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IComplianceRegistry
 * @dev Interface for compliance registry implementing Compliance-by-Design™
 */
interface IComplianceRegistry {
    
    enum ComplianceLevel {
        None,
        Basic,
        Standard,
        Premium,
        Institutional
    }
    
    struct ComplianceData {
        ComplianceLevel level;
        uint256 expiryTimestamp;
        bool isActive;
        string jurisdiction;
        uint256 riskScore; // 0-100
    }
    
    // Events
    event AddressCompliant(address indexed user, ComplianceLevel level);
    event AddressNonCompliant(address indexed user);
    event JurisdictionBlocked(string jurisdiction);
    event TransferRestricted(address indexed from, address indexed to, string reason);
    
    // Compliance checks
    function isCompliant(address user) external view returns (bool);
    function getComplianceLevel(address user) external view returns (ComplianceLevel);
    function canTransfer(address from, address to) external view returns (bool);
    
    // Compliance management
    function setCompliant(address user, ComplianceLevel level, uint256 duration) external;
    function removeCompliance(address user) external;
    function setJurisdiction(address user, string memory jurisdiction) external;
    function blockJurisdiction(string memory jurisdiction) external;
    
    // Risk management
    function setRiskScore(address user, uint256 score) external;
    function getRiskScore(address user) external view returns (uint256);
    
    // Getters
    function getComplianceData(address user) external view returns (ComplianceData memory);
}