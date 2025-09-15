// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ComplianceRegistry
 * @dev Manages compliance whitelist for the iYield protocol
 */
contract ComplianceRegistry is Ownable {
    mapping(address => bool) public whitelist;
    mapping(address => uint256) public kycLevel;
    
    event AddressWhitelisted(address indexed user, bool status);
    event KycLevelUpdated(address indexed user, uint256 level);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Set whitelist status for an address
     * @param user Address to update
     * @param status Whitelist status
     */
    function setWhitelist(address user, bool status) external onlyOwner {
        whitelist[user] = status;
        emit AddressWhitelisted(user, status);
    }
    
    /**
     * @dev Set KYC level for an address
     * @param user Address to update
     * @param level KYC level (0 = none, 1 = basic, 2 = advanced)
     */
    function setKycLevel(address user, uint256 level) external onlyOwner {
        kycLevel[user] = level;
        emit KycLevelUpdated(user, level);
    }
    
    /**
     * @dev Check if address is whitelisted
     * @param user Address to check
     * @return bool Whitelist status
     */
    function isWhitelisted(address user) external view returns (bool) {
        return whitelist[user];
    }
    
    /**
     * @dev Get KYC level for address
     * @param user Address to check
     * @return uint256 KYC level
     */
    function getKycLevel(address user) external view returns (uint256) {
        return kycLevel[user];
    }
}