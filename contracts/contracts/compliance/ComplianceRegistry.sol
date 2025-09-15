// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ComplianceRegistry
 * @dev KYC/AML and jurisdiction management for regulatory compliance
 * @notice Manages accredited investor verification and compliance status
 */
contract ComplianceRegistry is AccessControl, Pausable, ReentrancyGuard {
    
    // Role definitions
    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");
    bytes32 public constant KYC_PROVIDER_ROLE = keccak256("KYC_PROVIDER_ROLE");
    bytes32 public constant JURISDICTION_MANAGER_ROLE = keccak256("JURISDICTION_MANAGER_ROLE");
    
    // Compliance status structure
    struct ComplianceStatus {
        bool isKYCVerified;
        bool isAccredited;
        uint256 accreditationExpiry;
        uint256 kycExpiry;
        uint256 jurisdictionCode;
        bool isRestricted;
        uint256 lockupExpiry;
        address kycProvider;
        string kycHash; // IPFS hash of KYC documentation
        uint256 lastUpdateTimestamp;
    }
    
    // Jurisdiction information
    struct JurisdictionInfo {
        string countryCode;
        string jurisdictionName;
        bool isAllowed;
        bool requiresAdditionalKYC;
        uint256 additionalLockupPeriod;
        uint256[] restrictedSecurityTypes;
    }
    
    // KYC Provider information
    struct KYCProvider {
        string name;
        string endpoint;
        bool isActive;
        uint256 verificationFee;
        uint256[] supportedJurisdictions;
    }
    
    // Storage
    mapping(address => ComplianceStatus) private _complianceStatus;
    mapping(uint256 => JurisdictionInfo) private _jurisdictions;
    mapping(address => KYCProvider) private _kycProviders;
    mapping(bytes32 => bool) private _usedNonces;
    
    // Global settings
    uint256 public defaultLockupPeriod = 365 days; // Rule 144 lockup
    uint256 public kycValidityPeriod = 365 days;
    uint256 public accreditationValidityPeriod = 365 days;
    bool public autoRenewalEnabled = true;
    
    // Statistics
    uint256 public totalVerifiedUsers;
    uint256 public totalAccreditedInvestors;
    uint256 public totalRestrictedUsers;
    
    // Events
    event UserKYCUpdated(address indexed user, bool verified, uint256 expiry, address provider);
    event UserAccreditationUpdated(address indexed user, bool accredited, uint256 expiry);
    event UserRestricted(address indexed user, string reason);
    event UserUnrestricted(address indexed user);
    event JurisdictionUpdated(uint256 indexed code, string countryCode, bool allowed);
    event KYCProviderRegistered(address indexed provider, string name);
    event KYCProviderUpdated(address indexed provider, bool active);
    event LockupPeriodUpdated(address indexed user, uint256 expiry);
    event ComplianceParametersUpdated(uint256 lockupPeriod, uint256 kycValidity, uint256 accreditationValidity);
    
    // Modifiers
    modifier validAddress(address account) {
        require(account != address(0), "ComplianceRegistry: Invalid address");
        _;
    }
    
    modifier nonceNotUsed(bytes32 nonce) {
        require(!_usedNonces[nonce], "ComplianceRegistry: Nonce already used");
        _usedNonces[nonce] = true;
        _;
    }
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(COMPLIANCE_OFFICER_ROLE, msg.sender);
        _grantRole(KYC_PROVIDER_ROLE, msg.sender);
        _grantRole(JURISDICTION_MANAGER_ROLE, msg.sender);
        
        // Initialize common jurisdictions
        _initializeDefaultJurisdictions();
    }
    
    /**
     * @dev Update KYC status for a user
     */
    function updateKYCStatus(
        address user,
        bool isVerified,
        string memory kycHash,
        uint256 jurisdictionCode,
        bytes32 nonce
    ) external validAddress(user) onlyRole(KYC_PROVIDER_ROLE) nonceNotUsed(nonce) {
        require(_jurisdictions[jurisdictionCode].isAllowed, "ComplianceRegistry: Jurisdiction not allowed");
        
        ComplianceStatus storage status = _complianceStatus[user];
        
        bool wasVerified = status.isKYCVerified;
        
        status.isKYCVerified = isVerified;
        status.kycProvider = msg.sender;
        status.kycHash = kycHash;
        status.jurisdictionCode = jurisdictionCode;
        status.lastUpdateTimestamp = block.timestamp;
        
        if (isVerified) {
            status.kycExpiry = block.timestamp + kycValidityPeriod;
            
            // Apply jurisdiction-specific requirements
            JurisdictionInfo storage jurisdiction = _jurisdictions[jurisdictionCode];
            if (jurisdiction.additionalLockupPeriod > 0) {
                status.lockupExpiry = block.timestamp + jurisdiction.additionalLockupPeriod;
            } else {
                status.lockupExpiry = block.timestamp + defaultLockupPeriod;
            }
            
            if (!wasVerified) {
                totalVerifiedUsers++;
            }
        } else {
            status.kycExpiry = 0;
            status.lockupExpiry = 0;
            
            if (wasVerified) {
                totalVerifiedUsers--;
            }
        }
        
        emit UserKYCUpdated(user, isVerified, status.kycExpiry, msg.sender);
        emit LockupPeriodUpdated(user, status.lockupExpiry);
    }
    
    /**
     * @dev Update accredited investor status
     */
    function updateAccreditationStatus(
        address user,
        bool isAccredited,
        uint256 customExpiry
    ) external validAddress(user) onlyRole(COMPLIANCE_OFFICER_ROLE) {
        ComplianceStatus storage status = _complianceStatus[user];
        
        bool wasAccredited = status.isAccredited;
        
        status.isAccredited = isAccredited;
        status.lastUpdateTimestamp = block.timestamp;
        
        if (isAccredited) {
            status.accreditationExpiry = customExpiry > 0 ? 
                customExpiry : 
                block.timestamp + accreditationValidityPeriod;
                
            if (!wasAccredited) {
                totalAccreditedInvestors++;
            }
        } else {
            status.accreditationExpiry = 0;
            
            if (wasAccredited) {
                totalAccreditedInvestors--;
            }
        }
        
        emit UserAccreditationUpdated(user, isAccredited, status.accreditationExpiry);
    }
    
    /**
     * @dev Restrict user access
     */
    function restrictUser(
        address user,
        string memory reason
    ) external validAddress(user) onlyRole(COMPLIANCE_OFFICER_ROLE) {
        ComplianceStatus storage status = _complianceStatus[user];
        
        if (!status.isRestricted) {
            status.isRestricted = true;
            status.lastUpdateTimestamp = block.timestamp;
            totalRestrictedUsers++;
            
            emit UserRestricted(user, reason);
        }
    }
    
    /**
     * @dev Remove user restriction
     */
    function unrestrictUser(
        address user
    ) external validAddress(user) onlyRole(COMPLIANCE_OFFICER_ROLE) {
        ComplianceStatus storage status = _complianceStatus[user];
        
        if (status.isRestricted) {
            status.isRestricted = false;
            status.lastUpdateTimestamp = block.timestamp;
            totalRestrictedUsers--;
            
            emit UserUnrestricted(user);
        }
    }
    
    /**
     * @dev Register jurisdiction
     */
    function registerJurisdiction(
        uint256 code,
        string memory countryCode,
        string memory jurisdictionName,
        bool isAllowed,
        bool requiresAdditionalKYC,
        uint256 additionalLockupPeriod
    ) external onlyRole(JURISDICTION_MANAGER_ROLE) {
        JurisdictionInfo storage jurisdiction = _jurisdictions[code];
        
        jurisdiction.countryCode = countryCode;
        jurisdiction.jurisdictionName = jurisdictionName;
        jurisdiction.isAllowed = isAllowed;
        jurisdiction.requiresAdditionalKYC = requiresAdditionalKYC;
        jurisdiction.additionalLockupPeriod = additionalLockupPeriod;
        
        emit JurisdictionUpdated(code, countryCode, isAllowed);
    }
    
    /**
     * @dev Register KYC provider
     */
    function registerKYCProvider(
        address provider,
        string memory name,
        string memory endpoint,
        uint256 verificationFee,
        uint256[] memory supportedJurisdictions
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(provider != address(0), "ComplianceRegistry: Invalid provider address");
        
        _kycProviders[provider] = KYCProvider({
            name: name,
            endpoint: endpoint,
            isActive: true,
            verificationFee: verificationFee,
            supportedJurisdictions: supportedJurisdictions
        });
        
        _grantRole(KYC_PROVIDER_ROLE, provider);
        
        emit KYCProviderRegistered(provider, name);
    }
    
    /**
     * @dev Update KYC provider status
     */
    function updateKYCProviderStatus(
        address provider,
        bool isActive
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _kycProviders[provider].isActive = isActive;
        
        if (isActive) {
            _grantRole(KYC_PROVIDER_ROLE, provider);
        } else {
            _revokeRole(KYC_PROVIDER_ROLE, provider);
        }
        
        emit KYCProviderUpdated(provider, isActive);
    }
    
    /**
     * @dev Batch update multiple users (for migration)
     */
    function batchUpdateCompliance(
        address[] memory users,
        ComplianceStatus[] memory statuses
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        require(users.length == statuses.length, "ComplianceRegistry: Array length mismatch");
        
        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "ComplianceRegistry: Invalid address");
            _complianceStatus[users[i]] = statuses[i];
        }
    }
    
    /**
     * @dev Auto-renew expired statuses
     */
    function autoRenewStatus(address user) external {
        require(autoRenewalEnabled, "ComplianceRegistry: Auto-renewal disabled");
        
        ComplianceStatus storage status = _complianceStatus[user];
        
        // Auto-renew KYC if provider is still active
        if (status.kycExpiry <= block.timestamp && status.kycExpiry > 0) {
            KYCProvider storage provider = _kycProviders[status.kycProvider];
            if (provider.isActive) {
                status.kycExpiry = block.timestamp + kycValidityPeriod;
                emit UserKYCUpdated(user, true, status.kycExpiry, status.kycProvider);
            }
        }
        
        // Auto-renew accreditation if not explicitly expired
        if (status.accreditationExpiry <= block.timestamp && status.accreditationExpiry > 0) {
            status.accreditationExpiry = block.timestamp + accreditationValidityPeriod;
            emit UserAccreditationUpdated(user, true, status.accreditationExpiry);
        }
    }
    
    // View functions
    function getComplianceStatus(address user) external view returns (ComplianceStatus memory) {
        return _complianceStatus[user];
    }
    
    function isCompliant(address user) external view returns (bool) {
        ComplianceStatus storage status = _complianceStatus[user];
        
        return (
            status.isKYCVerified && 
            status.kycExpiry > block.timestamp &&
            status.isAccredited && 
            status.accreditationExpiry > block.timestamp &&
            !status.isRestricted
        );
    }
    
    function isTransferAllowed(address from, address to) external view returns (bool, string memory) {
        ComplianceStatus storage fromStatus = _complianceStatus[from];
        ComplianceStatus storage toStatus = _complianceStatus[to];
        
        // Check sender compliance
        if (!fromStatus.isKYCVerified || fromStatus.kycExpiry <= block.timestamp) {
            return (false, "Sender KYC verification required or expired");
        }
        if (!fromStatus.isAccredited || fromStatus.accreditationExpiry <= block.timestamp) {
            return (false, "Sender accreditation required or expired");
        }
        if (fromStatus.isRestricted) {
            return (false, "Sender account restricted");
        }
        if (fromStatus.lockupExpiry > block.timestamp) {
            return (false, "Sender under lockup period");
        }
        
        // Check receiver compliance
        if (!toStatus.isKYCVerified || toStatus.kycExpiry <= block.timestamp) {
            return (false, "Receiver KYC verification required or expired");
        }
        if (!toStatus.isAccredited || toStatus.accreditationExpiry <= block.timestamp) {
            return (false, "Receiver accreditation required or expired");
        }
        if (toStatus.isRestricted) {
            return (false, "Receiver account restricted");
        }
        
        // Check jurisdiction compatibility
        if (!_jurisdictions[fromStatus.jurisdictionCode].isAllowed || 
            !_jurisdictions[toStatus.jurisdictionCode].isAllowed) {
            return (false, "Jurisdiction not allowed");
        }
        
        return (true, "Transfer allowed");
    }
    
    function getJurisdictionInfo(uint256 code) external view returns (JurisdictionInfo memory) {
        return _jurisdictions[code];
    }
    
    function getKYCProvider(address provider) external view returns (KYCProvider memory) {
        return _kycProviders[provider];
    }
    
    function getUsersByJurisdiction(uint256 jurisdictionCode) external view returns (uint256 count) {
        // Note: This would require an enumerable mapping in production
        // For now, returning 0 as placeholder
        return 0;
    }
    
    // Admin functions
    function updateComplianceParameters(
        uint256 _defaultLockupPeriod,
        uint256 _kycValidityPeriod,
        uint256 _accreditationValidityPeriod,
        bool _autoRenewalEnabled
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        defaultLockupPeriod = _defaultLockupPeriod;
        kycValidityPeriod = _kycValidityPeriod;
        accreditationValidityPeriod = _accreditationValidityPeriod;
        autoRenewalEnabled = _autoRenewalEnabled;
        
        emit ComplianceParametersUpdated(
            _defaultLockupPeriod,
            _kycValidityPeriod,
            _accreditationValidityPeriod
        );
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Initialize default jurisdictions
     */
    function _initializeDefaultJurisdictions() internal {
        // United States - allowed with standard lockup
        _jurisdictions[1] = JurisdictionInfo({
            countryCode: "US",
            jurisdictionName: "United States",
            isAllowed: true,
            requiresAdditionalKYC: false,
            additionalLockupPeriod: 0,
            restrictedSecurityTypes: new uint256[](0)
        });
        
        // Canada - allowed with additional requirements
        _jurisdictions[2] = JurisdictionInfo({
            countryCode: "CA",
            jurisdictionName: "Canada",
            isAllowed: true,
            requiresAdditionalKYC: true,
            additionalLockupPeriod: 30 days,
            restrictedSecurityTypes: new uint256[](0)
        });
        
        // European Union - allowed with GDPR compliance
        _jurisdictions[3] = JurisdictionInfo({
            countryCode: "EU",
            jurisdictionName: "European Union",
            isAllowed: true,
            requiresAdditionalKYC: true,
            additionalLockupPeriod: 0,
            restrictedSecurityTypes: new uint256[](0)
        });
        
        // Restricted jurisdictions example
        uint256[] memory restrictedTypes = new uint256[](1);
        restrictedTypes[0] = 1; // Restricted security type 1
        
        _jurisdictions[999] = JurisdictionInfo({
            countryCode: "XX",
            jurisdictionName: "Restricted Territory",
            isAllowed: false,
            requiresAdditionalKYC: true,
            additionalLockupPeriod: 0,
            restrictedSecurityTypes: restrictedTypes
        });
    }
}