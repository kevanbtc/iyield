// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title ComplianceRegistry
 * @dev Manages KYC/AML and jurisdiction controls
 */
contract ComplianceRegistry is AccessControl {
    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");
    
    enum KYCStatus { None, Pending, Verified, Rejected }
    enum Jurisdiction { None, US, EU, UK, Other }
    
    struct UserCompliance {
        KYCStatus kycStatus;
        Jurisdiction jurisdiction;
        bool accreditedInvestor;
        uint256 verificationTimestamp;
        uint256 expiryTimestamp;
    }
    
    mapping(address => UserCompliance) public userCompliance;
    mapping(Jurisdiction => bool) public jurisdictionAllowed;
    
    event KYCStatusUpdated(address indexed user, KYCStatus status);
    event JurisdictionUpdated(address indexed user, Jurisdiction jurisdiction);
    event AccreditationUpdated(address indexed user, bool accredited);
    
    constructor(address defaultAdmin) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(COMPLIANCE_OFFICER_ROLE, defaultAdmin);
        
        // Initially allow US jurisdiction
        jurisdictionAllowed[Jurisdiction.US] = true;
    }
    
    function updateKYCStatus(address user, KYCStatus status, uint256 expiryDays) 
        external 
        onlyRole(COMPLIANCE_OFFICER_ROLE) 
    {
        userCompliance[user].kycStatus = status;
        userCompliance[user].verificationTimestamp = block.timestamp;
        userCompliance[user].expiryTimestamp = block.timestamp + (expiryDays * 1 days);
        
        emit KYCStatusUpdated(user, status);
    }
    
    function updateJurisdiction(address user, Jurisdiction jurisdiction) 
        external 
        onlyRole(COMPLIANCE_OFFICER_ROLE) 
    {
        userCompliance[user].jurisdiction = jurisdiction;
        emit JurisdictionUpdated(user, jurisdiction);
    }
    
    function updateAccreditation(address user, bool accredited) 
        external 
        onlyRole(COMPLIANCE_OFFICER_ROLE) 
    {
        userCompliance[user].accreditedInvestor = accredited;
        emit AccreditationUpdated(user, accredited);
    }
    
    function setJurisdictionAllowed(Jurisdiction jurisdiction, bool allowed) 
        external 
        onlyRole(COMPLIANCE_OFFICER_ROLE) 
    {
        jurisdictionAllowed[jurisdiction] = allowed;
    }
    
    function isCompliant(address user) external view returns (bool) {
        UserCompliance memory compliance = userCompliance[user];
        
        return compliance.kycStatus == KYCStatus.Verified &&
               compliance.expiryTimestamp > block.timestamp &&
               jurisdictionAllowed[compliance.jurisdiction] &&
               compliance.accreditedInvestor;
    }
}