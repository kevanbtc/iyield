// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IERC_RWA_CSV.sol";

/**
 * @title ERCRWACSV
 * @dev Implementation of ERC-RWA:CSV - Real World Asset Token Standard for Insurance-Backed Securities
 * @notice This contract implements the Proof-of-CSV™ system for insurance cash surrender value backed tokens
 */
contract ERCRWACSV is ERC20, AccessControl, ReentrancyGuard, IERC_RWA_CSV {
    // Role definitions
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    
    // Enhanced compliance tracking
    mapping(address => bool) public complianceStatus;
    mapping(address => uint256) public rule144Lockup;
    mapping(address => string) public jurisdiction;
    mapping(address => bool) public regSRestricted; // Regulation S restrictions
    mapping(address => uint256) public lastTransferTime; // For Rule 144 tracking
    mapping(address => bool) public complianceOverride; // Emergency override
    
    // Rule 144 constants
    uint256 public constant RULE144_HOLDING_PERIOD = 365 days; // 1 year for restricted securities
    uint256 public constant RULE144_PUBLIC_INFO_PERIOD = 90 days; // Adequate current information period
    uint256 public constant RULE144_VOLUME_LIMIT = 1000; // 1% in basis points
    
    // Reg S constants  
    uint256 public constant REGS_RESTRICTION_PERIOD = 40 days; // Distribution compliance period
    mapping(string => bool) public regSAllowedJurisdictions;
    
    // Attestation data (Proof-of-CSV™)
    bytes32 public currentMerkleRoot;
    uint256 public lastAttestationTimestamp;
    uint256 public constant MAX_ORACLE_STALE = 7 days;
    uint256 public totalCSVValue;
    
    // Risk management
    uint256 public currentLTV;
    uint256 public maxLTV = 8000; // 80% (basis points)
    uint256 public constant MAX_POSSIBLE_LTV = 9500; // 95%
    
    // Oracle and compliance integration
    IComplianceRegistry public immutable complianceRegistry;
    ICSVOracle public immutable csvOracle;
    
    // Emergency controls
    bool public paused;
    
    modifier onlyCompliantTransfer(address from, address to, uint256 amount) {
        require(isCompliantTransfer(from, to, amount), "Transfer not compliant");
        _;
    }
    
    modifier oracleNotStale() {
        require(
            block.timestamp - lastAttestationTimestamp <= MAX_ORACLE_STALE,
            "Oracle data stale"
        );
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Contract paused");
        _;
    }
    
    constructor(
        string memory name,
        string memory symbol,
        address _complianceRegistry,
        address _csvOracle,
        address _admin
    ) ERC20(name, symbol) {
        require(_complianceRegistry != address(0), "Invalid compliance registry");
        require(_csvOracle != address(0), "Invalid CSV oracle");
        require(_admin != address(0), "Invalid admin");
        
        complianceRegistry = IComplianceRegistry(_complianceRegistry);
        csvOracle = ICSVOracle(_csvOracle);
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ORACLE_ROLE, _admin);
        _grantRole(COMPLIANCE_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        
        // Initialize Reg S allowed jurisdictions
        regSAllowedJurisdictions["US"] = false; // US persons not allowed in Reg S
        regSAllowedJurisdictions["UK"] = true;
        regSAllowedJurisdictions["EU"] = true;
        regSAllowedJurisdictions["CA"] = true;
        regSAllowedJurisdictions["AU"] = true;
        regSAllowedJurisdictions["SG"] = true;
        regSAllowedJurisdictions["CH"] = true;
    }
    
    /**
     * @dev Enhanced compliance check for transfers with detailed Rule 144 and Reg S controls
     */
    function isCompliantTransfer(
        address from,
        address to,
        uint256 amount
    ) public view override returns (bool) {
        // Emergency override check
        if (complianceOverride[from] || complianceOverride[to]) {
            return true;
        }
        
        // Call enhanced compliance check
        (bool allowed, , ) = canTransfer(from, to, amount);
        return allowed;
    }
    
    /**
     * @dev Comprehensive transfer compliance check with detailed reasons
     */
    function canTransfer(address from, address to, uint256 amount) 
        external 
        view 
        override 
        returns (bool allowed, string memory reason, uint256 complianceFlags) 
    {
        // Check basic compliance status
        if (!complianceRegistry.isKYCVerified(to)) {
            return (false, "Recipient not KYC verified", 1);
        }
        
        if (!complianceRegistry.isAccreditedInvestor(to)) {
            return (false, "Recipient not accredited investor", 2);
        }
        
        // Check Rule 144 compliance
        (bool rule144Allowed, string memory rule144Reason) = checkRule144Compliance(from, amount);
        if (!rule144Allowed) {
            return (false, rule144Reason, 4);
        }
        
        // Check Regulation S compliance
        (bool regSAllowed, string memory regSReason) = checkRegSCompliance(from, to);
        if (!regSAllowed) {
            return (false, regSReason, 8);
        }
        
        // Check sanctions
        // Note: This would integrate with external sanctions list in production
        string memory fromJurisdiction = complianceRegistry.getJurisdiction(from);
        string memory toJurisdiction = complianceRegistry.getJurisdiction(to);
        
        if (bytes(toJurisdiction).length == 0) {
            return (false, "Recipient jurisdiction not set", 16);
        }
        
        // Check for sanctioned jurisdictions (simplified)
        if (keccak256(abi.encodePacked(toJurisdiction)) == keccak256(abi.encodePacked("OFAC_BLOCKED"))) {
            return (false, "Recipient in sanctioned jurisdiction", 32);
        }
        
        return (true, "Transfer allowed", 0);
    }
    
    /**
     * @dev Enhanced Rule 144 compliance check
     */
    function checkRule144Compliance(address from, uint256 amount) 
        external 
        view 
        override 
        returns (bool allowed, string memory reason) 
    {
        // Check if account has Rule 144 lockup
        if (rule144Lockup[from] > block.timestamp) {
            return (false, "Rule 144 holding period not met");
        }
        
        // Check adequate current information requirement
        uint256 timeSinceLastAttestation = block.timestamp - lastAttestationTimestamp;
        if (timeSinceLastAttestation > RULE144_PUBLIC_INFO_PERIOD) {
            return (false, "Adequate current information requirement not met");
        }
        
        // Check volume limitations (simplified - 1% of outstanding)
        uint256 maxVolume = (totalSupply() * RULE144_VOLUME_LIMIT) / 10000;
        if (amount > maxVolume) {
            return (false, "Rule 144 volume limitation exceeded");
        }
        
        // Check frequency limitations (no more than one transfer per week for large amounts)
        if (amount > maxVolume / 2 && 
            lastTransferTime[from] > 0 && 
            block.timestamp - lastTransferTime[from] < 7 days) {
            return (false, "Rule 144 frequency limitation");
        }
        
        return (true, "Rule 144 compliant");
    }
    
    /**
     * @dev Regulation S compliance check
     */
    function checkRegSCompliance(address from, address to) 
        external 
        view 
        override 
        returns (bool allowed, string memory reason) 
    {
        string memory fromJurisdiction = complianceRegistry.getJurisdiction(from);
        string memory toJurisdiction = complianceRegistry.getJurisdiction(to);
        
        // If either party is US person, Reg S restrictions apply
        bool fromIsUS = keccak256(abi.encodePacked(fromJurisdiction)) == keccak256(abi.encodePacked("US"));
        bool toIsUS = keccak256(abi.encodePacked(toJurisdiction)) == keccak256(abi.encodePacked("US"));
        
        // US to US transfers - not subject to Reg S
        if (fromIsUS && toIsUS) {
            return (true, "Domestic transfer");
        }
        
        // US person selling to offshore - check restrictions
        if (fromIsUS && !toIsUS) {
            if (regSRestricted[from]) {
                return (false, "Seller subject to Reg S distribution compliance period");
            }
        }
        
        // Offshore person selling to US person - prohibited under Reg S during restriction period
        if (!fromIsUS && toIsUS) {
            if (regSRestricted[from]) {
                return (false, "Offshore to US transfer prohibited during Reg S restriction period");
            }
        }
        
        // Check if recipient jurisdiction is allowed under Reg S
        if (!regSAllowedJurisdictions[toJurisdiction] && !toIsUS) {
            return (false, "Recipient jurisdiction not allowed under Reg S");
        }
        
        return (true, "Reg S compliant");
    }
    
    /**
     * @dev Get detailed Rule 144 status
     */
    function getRule144Status(address account) 
        external 
        view 
        override 
        returns (uint256 unlockTime, bool isRestricted) 
    {
        unlockTime = rule144Lockup[account];
        isRestricted = unlockTime > block.timestamp;
    }
    
    /**
     * @dev Set Regulation S restriction
     */
    function setRegSRestriction(address account, bool restricted) 
        external 
        override 
        onlyRole(COMPLIANCE_ROLE) 
    {
        regSRestricted[account] = restricted;
        emit ComplianceStatusChanged(account, !restricted);
    }
    
    /**
     * @dev Check if account is Reg S restricted
     */
    function isRegSRestricted(address account) 
        external 
        view 
        override 
        returns (bool) 
    {
        return regSRestricted[account];
    }
    
    /**
     * @dev Get comprehensive compliance details
     */
    function getComplianceDetails(address account) 
        external 
        view 
        override 
        returns (
            bool isKYCVerified,
            bool isAccredited,
            string memory accountJurisdiction,
            uint256 rule144LockupTime,
            bool regSRestrictedStatus,
            uint256 complianceScore
        ) 
    {
        isKYCVerified = complianceRegistry.isKYCVerified(account);
        isAccredited = complianceRegistry.isAccreditedInvestor(account);
        accountJurisdiction = complianceRegistry.getJurisdiction(account);
        rule144LockupTime = rule144Lockup[account];
        regSRestrictedStatus = regSRestricted[account];
        
        // Calculate compliance score (0-100)
        complianceScore = 0;
        if (isKYCVerified) complianceScore += 30;
        if (isAccredited) complianceScore += 30;
        if (bytes(accountJurisdiction).length > 0) complianceScore += 20;
        if (rule144LockupTime <= block.timestamp) complianceScore += 10;
        if (!regSRestrictedStatus) complianceScore += 10;
    }
    
    /**
     * @dev Enhanced compliant transfer function with blocking events
     */
    function transfer(address to, uint256 amount) 
        public 
        override(ERC20, IERC_RWA_CSV) 
        whenNotPaused
        oracleNotStale
        returns (bool) 
    {
        // Check compliance with detailed reason
        (bool allowed, string memory reason, ) = this.canTransfer(msg.sender, to, amount);
        
        if (!allowed) {
            emit TransferBlocked(msg.sender, to, amount, reason);
            revert(string(abi.encodePacked("Transfer blocked: ", reason)));
        }
        
        // Update transfer tracking for Rule 144
        lastTransferTime[msg.sender] = block.timestamp;
        
        return super.transfer(to, amount);
    }
    
    /**
     * @dev Enhanced compliant transferFrom function with blocking events
     */
    function transferFrom(address from, address to, uint256 amount)
        public
        override(ERC20, IERC_RWA_CSV)
        whenNotPaused
        oracleNotStale
        returns (bool)
    {
        // Check compliance with detailed reason
        (bool allowed, string memory reason, ) = this.canTransfer(from, to, amount);
        
        if (!allowed) {
            emit TransferBlocked(from, to, amount, reason);
            revert(string(abi.encodePacked("Transfer blocked: ", reason)));
        }
        
        // Update transfer tracking for Rule 144
        lastTransferTime[from] = block.timestamp;
        
        return super.transferFrom(from, to, amount);
    }
    
    /**
     * @dev Update valuation with Proof-of-CSV™ attestation
     */
    function updateValuation(
        bytes32 merkleRoot,
        uint256 newValuation,
        bytes calldata proof
    ) external override onlyRole(ORACLE_ROLE) whenNotPaused {
        // Verify oracle consensus
        ICSVOracle.ValuationData memory data = csvOracle.getLatestValuation();
        require(data.attestors.length >= csvOracle.getMinAttestors(), "Insufficient attestors");
        require(data.timestamp > lastAttestationTimestamp, "Stale oracle data");
        
        // Update valuation data
        currentMerkleRoot = merkleRoot;
        totalCSVValue = newValuation;
        lastAttestationTimestamp = data.timestamp;
        
        // Update LTV ratio and check limits
        _updateLTV();
        
        emit ValuationUpdated(merkleRoot, newValuation, block.timestamp);
    }
    
    /**
     * @dev Verify CSV proof using Merkle tree
     */
    function verifyCSVProof(
        bytes32[] calldata merkleProof,
        bytes32 leaf
    ) external view override returns (bool) {
        return MerkleProof.verify(merkleProof, currentMerkleRoot, leaf);
    }
    
    /**
     * @dev Internal function to update LTV ratio with automatic ratchets
     */
    function _updateLTV() internal {
        if (totalSupply() > 0 && totalCSVValue > 0) {
            // Calculate LTV as (total tokens * 10000) / total CSV value
            currentLTV = (totalSupply() * 10000) / totalCSVValue;
            
            // Automatic LTV ratchet if exceeds maximum
            if (currentLTV > maxLTV) {
                // In a real implementation, this could trigger automatic liquidation
                // or halt new issuance until LTV improves
                emit LTVRatioUpdated(currentLTV, maxLTV);
            }
        }
    }
    
    /**
     * @dev Mint new tokens (restricted)
     */
    function mint(address to, uint256 amount) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
        whenNotPaused 
    {
        require(complianceRegistry.isKYCVerified(to), "Recipient not KYC verified");
        require(complianceRegistry.isAccreditedInvestor(to), "Recipient not accredited");
        
        _mint(to, amount);
        _updateLTV();
        
        // Ensure mint doesn't violate LTV limits
        require(currentLTV <= maxLTV, "Mint would exceed LTV limit");
    }
    
    /**
     * @dev Burn tokens (for redemption)
     */
    function burn(uint256 amount) external whenNotPaused {
        _burn(msg.sender, amount);
        _updateLTV();
    }
    
    /**
     * @dev Set compliance status for an account
     */
    function setComplianceStatus(address account, bool status) 
        external 
        override 
        onlyRole(COMPLIANCE_ROLE) 
    {
        complianceStatus[account] = status;
        emit ComplianceStatusChanged(account, status);
    }
    
    /**
     * @dev Enhanced Rule 144 lockup setting with status change events
     */
    function setRule144Lockup(address account, uint256 unlockTimestamp) 
        external 
        override 
        onlyRole(COMPLIANCE_ROLE) 
    {
        uint256 oldLockup = rule144Lockup[account];
        rule144Lockup[account] = unlockTimestamp;
        
        emit Rule144LockupSet(account, unlockTimestamp);
        emit Rule144StatusChanged(account, oldLockup, unlockTimestamp);
    }
    
    /**
     * @dev Set compliance override for emergency situations
     */
    function setComplianceOverride(address account, bool override_, string calldata reason) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        complianceOverride[account] = override_;
        emit ComplianceOverride(account, reason, msg.sender);
    }
    
    /**
     * @dev Update Reg S allowed jurisdictions
     */
    function updateRegSJurisdiction(string calldata jurisdiction, bool allowed) 
        external 
        onlyRole(COMPLIANCE_ROLE) 
    {
        regSAllowedJurisdictions[jurisdiction] = allowed;
    }
    
    /**
     * @dev Get jurisdiction restrictions for an account
     */
    function getJurisdictionRestrictions(address account) 
        external 
        view 
        override 
        returns (string[] memory) 
    {
        string[] memory restrictions = new string[](1);
        restrictions[0] = complianceRegistry.getJurisdiction(account);
        return restrictions;
    }
    
    /**
     * @dev Update maximum LTV ratio
     */
    function updateLTVRatio(uint256 newMaxLTV) 
        external 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newMaxLTV <= MAX_POSSIBLE_LTV, "LTV too high");
        require(newMaxLTV > 0, "LTV too low");
        
        maxLTV = newMaxLTV;
        emit LTVRatioUpdated(currentLTV, maxLTV);
    }
    
    // View functions
    function getCurrentLTV() external view override returns (uint256) {
        return currentLTV;
    }
    
    function getMaxLTV() external view override returns (uint256) {
        return maxLTV;
    }
    
    function getTotalCSVValue() external view override returns (uint256) {
        return totalCSVValue;
    }
    
    function getLastAttestationTimestamp() external view override returns (uint256) {
        return lastAttestationTimestamp;
    }
    
    function getMaxOracleStale() external view override returns (uint256) {
        return MAX_ORACLE_STALE;
    }
    
    /**
     * @dev Emergency pause function
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        paused = true;
    }
    
    /**
     * @dev Unpause function
     */  
    function unpause() external onlyRole(PAUSER_ROLE) {
        paused = false;
    }
    
    /**
     * @dev Support for ERC165 interface detection
     */
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC20, AccessControl) 
        returns (bool) 
    {
        return interfaceId == type(IERC_RWA_CSV).interfaceId ||
               super.supportsInterface(interfaceId);
    }
}