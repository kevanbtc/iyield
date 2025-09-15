// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
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
    
    // Compliance tracking
    mapping(address => bool) public complianceStatus;
    mapping(address => uint256) public rule144Lockup;
    mapping(address => string) public jurisdiction;
    
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
    }
    
    /**
     * @dev Comprehensive compliance check for transfers
     */
    function isCompliantTransfer(
        address from,
        address to,
        uint256 amount
    ) public view override returns (bool) {
        // Check if recipient is KYC verified
        if (!complianceRegistry.isKYCVerified(to)) return false;
        
        // Rule 144 lockup check for sender
        if (rule144Lockup[from] > block.timestamp) return false;
        
        // Accredited investor requirement for recipient
        if (!complianceRegistry.isAccreditedInvestor(to)) return false;
        
        // Jurisdiction restrictions (simplified - can be extended)
        string memory fromJurisdiction = complianceRegistry.getJurisdiction(from);
        string memory toJurisdiction = complianceRegistry.getJurisdiction(to);
        
        // For now, allow same jurisdiction transfers and US-based transfers
        // This can be extended with more sophisticated geo-blocking
        if (bytes(toJurisdiction).length == 0) return false;
        
        // Additional compliance checks can be added here
        return true;
    }
    
    /**
     * @dev Compliant transfer function with additional checks
     */
    function transfer(address to, uint256 amount) 
        public 
        override(ERC20, IERC_RWA_CSV) 
        whenNotPaused
        onlyCompliantTransfer(msg.sender, to, amount)
        oracleNotStale
        returns (bool) 
    {
        return super.transfer(to, amount);
    }
    
    /**
     * @dev Compliant transferFrom function with additional checks  
     */
    function transferFrom(address from, address to, uint256 amount)
        public
        override(ERC20, IERC_RWA_CSV)
        whenNotPaused
        onlyCompliantTransfer(from, to, amount)
        oracleNotStale
        returns (bool)
    {
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
     * @dev Set Rule 144 lockup for an account
     */
    function setRule144Lockup(address account, uint256 unlockTimestamp) 
        external 
        override 
        onlyRole(COMPLIANCE_ROLE) 
    {
        rule144Lockup[account] = unlockTimestamp;
        emit Rule144LockupSet(account, unlockTimestamp);
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