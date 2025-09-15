// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IComplianceEngine.sol";

/**
 * @title ComplianceEngine
 * @dev On-chain compliance system for Reg D/S and transfer restrictions
 * 
 * PATENT CLAIMS:
 * - Automated compliance verification with expiry tracking
 * - On-chain enforcement of securities regulations
 * - Integration with KYC/AML verification systems
 * 
 * Trademark: "Compliance-by-Design™" in RWA insurance space
 */
contract ComplianceEngine is IComplianceEngine, AccessControl {
    bytes32 public constant COMPLIANCE_OFFICER_ROLE = keccak256("COMPLIANCE_OFFICER_ROLE");
    bytes32 public constant KYC_PROVIDER_ROLE = keccak256("KYC_PROVIDER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    mapping(address => ComplianceProfile) private complianceProfiles;
    mapping(address => uint256) public dailyTransferVolume;
    mapping(address => uint256) public lastTransferDay;
    
    uint256 public constant REG_D_LOCKUP = 365 days; // 1 year lockup for Reg D
    uint256 public constant MAX_DAILY_VOLUME = 10000 * 1e18; // Max daily transfer volume
    uint256 public constant KYC_VALIDITY_PERIOD = 365 days; // KYC valid for 1 year
    uint256 public constant ACCREDITATION_VALIDITY = 365 days; // Accreditation valid for 1 year
    
    event KYCUpdated(address indexed investor, uint256 timestamp, address provider);
    event AccreditationUpdated(address indexed investor, uint256 expiry);
    event VolumeLimit(address indexed investor, uint256 dailyLimit, uint256 used);
    
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }
    
    /**
     * @dev Update investor compliance profile (Compliance-by-Design™)
     */
    function updateCompliance(
        address investor, 
        ComplianceProfile calldata profile
    ) external override onlyRole(COMPLIANCE_OFFICER_ROLE) {
        require(investor != address(0), "Invalid investor address");
        require(profile.kycTimestamp <= block.timestamp, "Future KYC timestamp");
        
        complianceProfiles[investor] = profile;
        
        emit ComplianceUpdated(investor, profile.investorType);
        emit KYCUpdated(investor, profile.kycTimestamp, msg.sender);
        
        if (profile.accreditationExpiry > block.timestamp) {
            emit AccreditationUpdated(investor, profile.accreditationExpiry);
        }
    }
    
    /**
     * @dev Get investor compliance profile
     */
    function getCompliance(address investor) external view override returns (ComplianceProfile memory) {
        return complianceProfiles[investor];
    }
    
    /**
     * @dev Check if transfer is allowed with detailed reasoning (patent-pending logic)
     */
    function canTransfer(
        address from, 
        address to, 
        uint256 amount
    ) external view override returns (bool, string memory) {
        // Basic checks
        if (from == address(0) || to == address(0)) {
            return (false, "Invalid addresses");
        }
        
        ComplianceProfile memory fromProfile = complianceProfiles[from];
        ComplianceProfile memory toProfile = complianceProfiles[to];
        
        // Check sender compliance
        if (!_isValidKYC(fromProfile.kycTimestamp)) {
            return (false, "Sender KYC expired");
        }
        
        if (!fromProfile.isWhitelisted) {
            return (false, "Sender not whitelisted");
        }
        
        // Check recipient compliance
        if (!_isValidKYC(toProfile.kycTimestamp)) {
            return (false, "Recipient KYC expired");
        }
        
        if (!toProfile.isWhitelisted) {
            return (false, "Recipient not whitelisted");
        }
        
        // Check accreditation requirements
        if (!_isAccredited(toProfile)) {
            return (false, "Recipient not accredited");
        }
        
        // Check transfer restrictions
        if (fromProfile.restriction == TransferRestrictionType.TIME_LOCK) {
            if (block.timestamp < fromProfile.restrictionParam) {
                return (false, "Tokens time-locked");
            }
        }
        
        if (fromProfile.restriction == TransferRestrictionType.VOLUME_LIMIT) {
            uint256 currentDay = block.timestamp / 1 days;
            uint256 dailyVolume = lastTransferDay[from] == currentDay ? 
                                 dailyTransferVolume[from] : 0;
            
            if (dailyVolume + amount > fromProfile.restrictionParam) {
                return (false, "Daily volume limit exceeded");
            }
        }
        
        // Reg D holding period check (critical patent claim)
        if (fromProfile.investorType == InvestorType.ACCREDITED && 
            block.timestamp < fromProfile.kycTimestamp + REG_D_LOCKUP) {
            return (false, "Reg D holding period not met");
        }
        
        return (true, "Transfer allowed");
    }
    
    /**
     * @dev Add investor to whitelist
     */
    function addToWhitelist(address investor) external override onlyRole(COMPLIANCE_OFFICER_ROLE) {
        complianceProfiles[investor].isWhitelisted = true;
        emit WhitelistUpdated(investor, true);
    }
    
    /**
     * @dev Remove investor from whitelist
     */
    function removeFromWhitelist(address investor) external override onlyRole(COMPLIANCE_OFFICER_ROLE) {
        complianceProfiles[investor].isWhitelisted = false;
        emit WhitelistUpdated(investor, false);
    }
    
    /**
     * @dev Check if investor is currently accredited
     */
    function isAccredited(address investor) external view override returns (bool) {
        return _isAccredited(complianceProfiles[investor]);
    }
    
    /**
     * @dev Update daily transfer volume (called by token contract)
     */
    function updateTransferVolume(address investor, uint256 amount) external {
        uint256 currentDay = block.timestamp / 1 days;
        
        if (lastTransferDay[investor] != currentDay) {
            dailyTransferVolume[investor] = amount;
            lastTransferDay[investor] = currentDay;
        } else {
            dailyTransferVolume[investor] += amount;
        }
        
        ComplianceProfile memory profile = complianceProfiles[investor];
        if (profile.restriction == TransferRestrictionType.VOLUME_LIMIT) {
            emit VolumeLimit(investor, profile.restrictionParam, dailyTransferVolume[investor]);
        }
    }
    
    /**
     * @dev Batch update compliance for multiple investors
     */
    function batchUpdateCompliance(
        address[] calldata investors,
        ComplianceProfile[] calldata profiles
    ) external onlyRole(COMPLIANCE_OFFICER_ROLE) {
        require(investors.length == profiles.length, "Array length mismatch");
        
        for (uint256 i = 0; i < investors.length; i++) {
            require(investors[i] != address(0), "Invalid investor address");
            complianceProfiles[investors[i]] = profiles[i];
            emit ComplianceUpdated(investors[i], profiles[i].investorType);
        }
    }
    
    /**
     * @dev Set KYC provider authorization
     */
    function setKYCProvider(address provider, bool authorized) external onlyRole(ADMIN_ROLE) {
        if (authorized) {
            _grantRole(KYC_PROVIDER_ROLE, provider);
        } else {
            _revokeRole(KYC_PROVIDER_ROLE, provider);
        }
    }
    
    /**
     * @dev Internal function to check KYC validity
     */
    function _isValidKYC(uint256 kycTimestamp) internal view returns (bool) {
        if (kycTimestamp == 0) return false;
        return block.timestamp <= kycTimestamp + KYC_VALIDITY_PERIOD;
    }
    
    /**
     * @dev Internal function to check accreditation status
     */
    function _isAccredited(ComplianceProfile memory profile) internal view returns (bool) {
        if (profile.investorType == InvestorType.NONE) return false;
        if (profile.investorType == InvestorType.QUALIFIED_INSTITUTIONAL) return true;
        
        if (profile.investorType == InvestorType.ACCREDITED) {
            return block.timestamp <= profile.accreditationExpiry;
        }
        
        return false; // FOREIGN type needs special handling
    }
    
    /**
     * @dev Get comprehensive compliance status for dashboard
     */
    function getComplianceStatus(address investor) external view returns (
        bool isCompliant,
        bool kycValid,
        bool accredited,
        bool whitelisted,
        uint256 dailyVolumeUsed,
        uint256 dailyVolumeLimit,
        string memory restrictionType
    ) {
        ComplianceProfile memory profile = complianceProfiles[investor];
        
        kycValid = _isValidKYC(profile.kycTimestamp);
        accredited = _isAccredited(profile);
        whitelisted = profile.isWhitelisted;
        
        isCompliant = kycValid && accredited && whitelisted;
        
        uint256 currentDay = block.timestamp / 1 days;
        dailyVolumeUsed = lastTransferDay[investor] == currentDay ? dailyTransferVolume[investor] : 0;
        
        if (profile.restriction == TransferRestrictionType.VOLUME_LIMIT) {
            dailyVolumeLimit = profile.restrictionParam;
            restrictionType = "Volume Limit";
        } else if (profile.restriction == TransferRestrictionType.TIME_LOCK) {
            restrictionType = "Time Lock";
        } else if (profile.restriction == TransferRestrictionType.WHITELIST_ONLY) {
            restrictionType = "Whitelist Only";
        } else {
            restrictionType = "None";
        }
    }
}