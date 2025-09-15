// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IERC_RWA_CSV.sol";

/**
 * @title ComplianceRegistry
 * @dev Registry for KYC, AML, and jurisdiction compliance tracking
 * @notice This contract manages compliance statuses for the iYield protocol
 */
contract ComplianceRegistry is AccessControl, IComplianceRegistry {
    // Role definitions
    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");
    bytes32 public constant KYC_PROVIDER_ROLE = keccak256("KYC_PROVIDER_ROLE");
    
    // Compliance data structures
    struct ComplianceData {
        bool kycVerified;
        bool accreditedInvestor;
        string jurisdiction;
        uint256 rule144Lockup;
        uint256 lastUpdated;
        address verifier;
    }
    
    // Storage
    mapping(address => ComplianceData) public complianceData;
    mapping(string => bool) public supportedJurisdictions;
    mapping(address => bool) public trustedKYCProviders;
    
    // Events
    event KYCStatusUpdated(address indexed account, bool status, address indexed verifier);
    event AccreditationStatusUpdated(address indexed account, bool status, address indexed verifier);
    event JurisdictionUpdated(address indexed account, string jurisdiction, address indexed verifier);
    event Rule144LockupSet(address indexed account, uint256 unlockTimestamp);
    event JurisdictionSupported(string jurisdiction, bool supported);
    event KYCProviderStatusChanged(address indexed provider, bool trusted);
    
    modifier onlyTrustedKYCProvider() {
        require(trustedKYCProviders[msg.sender] || hasRole(KYC_PROVIDER_ROLE, msg.sender), 
                "Not authorized KYC provider");
        _;
    }
    
    constructor(address _admin) {
        require(_admin != address(0), "Invalid admin address");
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(COMPLIANCE_OFFICER_ROLE, _admin);
        _grantRole(KYC_PROVIDER_ROLE, _admin);
        
        // Initialize supported jurisdictions
        supportedJurisdictions["US"] = true;
        supportedJurisdictions["UK"] = true;
        supportedJurisdictions["EU"] = true;
        supportedJurisdictions["CA"] = true;
        supportedJurisdictions["AU"] = true;
        supportedJurisdictions["SG"] = true;
        supportedJurisdictions["CH"] = true;
    }
    
    /**
     * @dev Set KYC verification status for an account
     */
    function setKYCStatus(address account, bool status) 
        external 
        override 
        onlyTrustedKYCProvider 
    {
        require(account != address(0), "Invalid account");
        
        complianceData[account].kycVerified = status;
        complianceData[account].lastUpdated = block.timestamp;
        complianceData[account].verifier = msg.sender;
        
        emit KYCStatusUpdated(account, status, msg.sender);
    }
    
    /**
     * @dev Set accredited investor status for an account
     */
    function setAccreditedStatus(address account, bool status) 
        external 
        override 
        onlyRole(COMPLIANCE_OFFICER_ROLE) 
    {
        require(account != address(0), "Invalid account");
        
        complianceData[account].accreditedInvestor = status;
        complianceData[account].lastUpdated = block.timestamp;
        complianceData[account].verifier = msg.sender;
        
        emit AccreditationStatusUpdated(account, status, msg.sender);
    }
    
    /**
     * @dev Set jurisdiction for an account
     */
    function setJurisdiction(address account, string memory jurisdiction) 
        external 
        override 
        onlyTrustedKYCProvider 
    {
        require(account != address(0), "Invalid account");
        require(supportedJurisdictions[jurisdiction], "Jurisdiction not supported");
        
        complianceData[account].jurisdiction = jurisdiction;
        complianceData[account].lastUpdated = block.timestamp;
        complianceData[account].verifier = msg.sender;
        
        emit JurisdictionUpdated(account, jurisdiction, msg.sender);
    }
    
    /**
     * @dev Set Rule 144 lockup period for an account
     */
    function setRule144Lockup(address account, uint256 unlockTimestamp) 
        external 
        onlyRole(COMPLIANCE_OFFICER_ROLE) 
    {
        require(account != address(0), "Invalid account");
        require(unlockTimestamp > block.timestamp, "Unlock time must be in future");
        
        complianceData[account].rule144Lockup = unlockTimestamp;
        complianceData[account].lastUpdated = block.timestamp;
        
        emit Rule144LockupSet(account, unlockTimestamp);
    }
    
    // View functions implementing IComplianceRegistry
    
    function isKYCVerified(address account) 
        external 
        view 
        override 
        returns (bool) 
    {
        return complianceData[account].kycVerified;
    }
    
    function isAccreditedInvestor(address account) 
        external 
        view 
        override 
        returns (bool) 
    {
        return complianceData[account].accreditedInvestor;
    }
    
    function getJurisdiction(address account) 
        external 
        view 
        override 
        returns (string memory) 
    {
        return complianceData[account].jurisdiction;
    }
    
    function getRule144Lockup(address account) 
        external 
        view 
        override 
        returns (uint256) 
    {
        return complianceData[account].rule144Lockup;
    }
    
    /**
     * @dev Get complete compliance data for an account
     */
    function getComplianceData(address account) 
        external 
        view 
        returns (ComplianceData memory) 
    {
        return complianceData[account];
    }
    
    /**
     * @dev Check if account meets all compliance requirements
     */
    function isFullyCompliant(address account) 
        external 
        view 
        returns (bool) 
    {
        ComplianceData memory data = complianceData[account];
        return data.kycVerified && 
               data.accreditedInvestor && 
               bytes(data.jurisdiction).length > 0 &&
               supportedJurisdictions[data.jurisdiction];
    }
    
    /**
     * @dev Batch set compliance data (for efficiency)
     */
    function batchSetCompliance(
        address[] memory accounts,
        bool[] memory kycStatuses,
        bool[] memory accreditedStatuses,
        string[] memory jurisdictions
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        require(accounts.length == kycStatuses.length, "Array length mismatch");
        require(accounts.length == accreditedStatuses.length, "Array length mismatch");
        require(accounts.length == jurisdictions.length, "Array length mismatch");
        
        for (uint256 i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0), "Invalid account");
            require(supportedJurisdictions[jurisdictions[i]], "Jurisdiction not supported");
            
            complianceData[accounts[i]] = ComplianceData({
                kycVerified: kycStatuses[i],
                accreditedInvestor: accreditedStatuses[i],
                jurisdiction: jurisdictions[i],
                rule144Lockup: 0,
                lastUpdated: block.timestamp,
                verifier: msg.sender
            });
            
            emit KYCStatusUpdated(accounts[i], kycStatuses[i], msg.sender);
            emit AccreditationStatusUpdated(accounts[i], accreditedStatuses[i], msg.sender);
            emit JurisdictionUpdated(accounts[i], jurisdictions[i], msg.sender);
        }
    }
    
    // Administrative functions
    
    /**
     * @dev Add or remove supported jurisdiction
     */
    function setSupportedJurisdiction(string memory jurisdiction, bool supported) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        supportedJurisdictions[jurisdiction] = supported;
        emit JurisdictionSupported(jurisdiction, supported);
    }
    
    /**
     * @dev Set trusted KYC provider status
     */
    function setTrustedKYCProvider(address provider, bool trusted) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(provider != address(0), "Invalid provider");
        trustedKYCProviders[provider] = trusted;
        emit KYCProviderStatusChanged(provider, trusted);
    }
    
    /**
     * @dev Emergency function to revoke compliance for an account
     */
    function emergencyRevokeCompliance(address account, string memory reason) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(account != address(0), "Invalid account");
        
        delete complianceData[account];
        
        emit KYCStatusUpdated(account, false, msg.sender);
        emit AccreditationStatusUpdated(account, false, msg.sender);
        emit JurisdictionUpdated(account, "", msg.sender);
    }
    
    /**
     * @dev Get list of supported jurisdictions (for UI)
     */
    function getSupportedJurisdictions() 
        external 
        view 
        returns (string[] memory) 
    {
        // This is a simplified version - in practice you'd maintain an array
        string[] memory jurisdictions = new string[](7);
        jurisdictions[0] = "US";
        jurisdictions[1] = "UK"; 
        jurisdictions[2] = "EU";
        jurisdictions[3] = "CA";
        jurisdictions[4] = "AU";
        jurisdictions[5] = "SG";
        jurisdictions[6] = "CH";
        return jurisdictions;
    }
}