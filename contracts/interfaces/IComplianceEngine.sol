// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IComplianceEngine
 * @dev Interface for on-chain compliance checks (Reg D/S, transfer restrictions)
 * Trademark: "Compliance-by-Design™" in RWA insurance space
 */
interface IComplianceEngine {
    enum InvestorType { NONE, ACCREDITED, QUALIFIED_INSTITUTIONAL, FOREIGN }
    enum TransferRestrictionType { NONE, TIME_LOCK, VOLUME_LIMIT, WHITELIST_ONLY }
    
    struct ComplianceProfile {
        InvestorType investorType;
        uint256 kycTimestamp;
        uint256 accreditationExpiry;
        bool isWhitelisted;
        TransferRestrictionType restriction;
        uint256 restrictionParam; // timestamp for time lock, amount for volume limit
    }
    
    event ComplianceUpdated(address indexed investor, InvestorType investorType);
    event TransferRestricted(address indexed from, address indexed to, uint256 amount, string reason);
    event WhitelistUpdated(address indexed investor, bool status);
    
    function updateCompliance(address investor, ComplianceProfile calldata profile) external;
    function getCompliance(address investor) external view returns (ComplianceProfile memory);
    function canTransfer(address from, address to, uint256 amount) external view returns (bool, string memory);
    function addToWhitelist(address investor) external;
    function removeFromWhitelist(address investor) external;
    function isAccredited(address investor) external view returns (bool);
}