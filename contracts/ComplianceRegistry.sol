// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ComplianceRegistry
 * @dev On-chain registry for KYC/AML and jurisdictional compliance
 * @notice Manages whitelist and compliance rules for iYield Protocol
 */
contract ComplianceRegistry is AccessControl {
    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");
    
    struct ComplianceData {
        bool isKYCVerified;
        bool isAMLCleared;
        uint256 jurisdictionCode;
        uint256 accreditationLevel;
        uint256 expiryTimestamp;
    }
    
    mapping(address => ComplianceData) public compliance;
    mapping(uint256 => bool) public approvedJurisdictions;
    
    event ComplianceUpdated(address indexed account, bool kyc, bool aml, uint256 jurisdiction);
    event JurisdictionApproved(uint256 indexed jurisdictionCode, bool approved);
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COMPLIANCE_OFFICER_ROLE, msg.sender);
        
        // Pre-approve major jurisdictions
        approvedJurisdictions[1] = true; // USA
        approvedJurisdictions[44] = true; // UK
        approvedJurisdictions[49] = true; // Germany
    }
    
    /**
     * @dev Update compliance status for an address
     */
    function updateCompliance(
        address account,
        bool kycVerified,
        bool amlCleared,
        uint256 jurisdictionCode,
        uint256 accreditationLevel,
        uint256 expiryTimestamp
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        compliance[account] = ComplianceData({
            isKYCVerified: kycVerified,
            isAMLCleared: amlCleared,
            jurisdictionCode: jurisdictionCode,
            accreditationLevel: accreditationLevel,
            expiryTimestamp: expiryTimestamp
        });
        
        emit ComplianceUpdated(account, kycVerified, amlCleared, jurisdictionCode);
    }
    
    /**
     * @dev Check if an address is fully compliant
     */
    function isCompliant(address account) external view returns (bool) {
        ComplianceData memory data = compliance[account];
        return data.isKYCVerified && 
               data.isAMLCleared && 
               approvedJurisdictions[data.jurisdictionCode] &&
               block.timestamp < data.expiryTimestamp;
    }
    
    /**
     * @dev Approve or revoke jurisdiction
     */
    function setJurisdictionApproval(uint256 jurisdictionCode, bool approved) 
        external onlyRole(DEFAULT_ADMIN_ROLE) {
        approvedJurisdictions[jurisdictionCode] = approved;
        emit JurisdictionApproved(jurisdictionCode, approved);
    }
}