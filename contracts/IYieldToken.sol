// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ICSVOracle.sol";
import "./interfaces/IComplianceEngine.sol";

/**
 * @title iYieldToken
 * @dev ERC-3643 style compliant token for tokenized insurance-backed yield notes
 * 
 * CORE PATENT CLAIMS:
 * 1. Using life insurance CSV as collateral in tokenized securities with automated LTV enforcement
 * 2. Combining on-chain compliance checks with off-chain policy oracle attestations  
 * 3. Waterfall tranche logic (senior/junior) applied to pooled CSV assets
 * 4. IPFS-based provenance trail for regulatory transparency
 * 5. Automated liquidation triggers based on real-time CSV valuations
 * 
 * TRADEMARKS:
 * - iYield™ for tokenized insurance-backed yield notes
 * - Proof-of-CSV™ for oracle attestation framework  
 * - Compliance-by-Design™ for regulatory compliance system
 */
contract IYieldToken is ERC20, ERC20Pausable, AccessControl, ReentrancyGuard {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    // Core protocol parameters (patent-pending configuration)
    uint256 public constant MAX_ORACLE_STALE = 24 hours; // Staleness check as mentioned in problem
    uint256 public constant SENIOR_TRANCHE_RATIO = 7000; // 70% senior, 30% junior (basis points)
    uint256 public constant TARGET_LTV = 8000; // 80% LTV target (basis points)
    uint256 public constant MAX_LTV = 9000; // 90% max LTV before liquidation
    
    struct PolicyBacking {
        bytes32 policyId;
        uint256 csvValue;
        uint256 allocatedAmount; // Amount of tokens backed by this policy
        uint256 lastUpdate;
        bool isActive;
    }
    
    struct TrancheInfo {
        uint256 seniorBalance;
        uint256 juniorBalance;
        uint256 seniorYield;
        uint256 juniorYield;
        uint256 lastDistribution;
    }
    
    // State variables
    ICSVOracle public csvOracle;
    IComplianceEngine public complianceEngine;
    
    mapping(bytes32 => PolicyBacking) public policyBackings;
    mapping(address => bool) public isWhitelisted;
    mapping(address => uint256) public lockupExpiry;
    
    bytes32[] public activePolicies;
    TrancheInfo public trancheInfo;
    
    uint256 public totalCsvValue;
    uint256 public navPerToken; // Net Asset Value per token (scaled by 1e18)
    uint256 public lastNavUpdate;
    
    // IPFS provenance tracking (patent-pending transparency system)
    mapping(uint256 => string) public disclosureHashes; // epoch => IPFS hash
    uint256 public currentEpoch;
    
    // Events for transparency and compliance
    event PolicyAdded(bytes32 indexed policyId, uint256 csvValue, uint256 tokensIssued);
    event PolicyUpdated(bytes32 indexed policyId, uint256 newCsvValue, uint256 oldCsvValue);
    event NAVUpdated(uint256 newNav, uint256 totalCsv, uint256 totalSupply);
    event DisclosurePublished(uint256 indexed epoch, string ipfsHash, bytes32 stateHash);
    event LTVBreach(bytes32 indexed policyId, uint256 currentLTV, uint256 maxLTV);
    event TrancheDistribution(uint256 seniorAmount, uint256 juniorAmount);
    
    // Compliance events
    event TransferRestricted(address indexed from, address indexed to, uint256 amount, string reason);
    event ComplianceCheckPassed(address indexed from, address indexed to, uint256 amount);
    
    constructor(
        string memory name,
        string memory symbol,
        address _csvOracle,
        address _complianceEngine,
        address _admin
    ) ERC20(name, symbol) {
        csvOracle = ICSVOracle(_csvOracle);
        complianceEngine = IComplianceEngine(_complianceEngine);
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(ORACLE_ROLE, _csvOracle);
        _grantRole(COMPLIANCE_ROLE, _complianceEngine);
        
        navPerToken = 1e18; // Initialize at 1:1 ratio
        currentEpoch = 1;
        lastNavUpdate = block.timestamp;
    }
    
    /**
     * @dev Add a new insurance policy as backing collateral
     * Core patent claim: Using life insurance CSV as collateral with automated LTV enforcement
     */
    function addPolicyBacking(
        bytes32 policyId,
        uint256 initialCsvValue,
        uint256 tokensToIssue,
        address recipient
    ) external onlyRole(ADMIN_ROLE) nonReentrant {
        require(initialCsvValue > 0, "CSV value must be positive");
        require(tokensToIssue > 0, "Tokens to issue must be positive");
        require(!policyBackings[policyId].isActive, "Policy already active");
        
        // Verify oracle attestation is fresh (Proof-of-CSV™)
        ICSVOracle.PolicyAttestation memory attestation = csvOracle.getAttestation(policyId);
        require(!csvOracle.isStale(policyId, MAX_ORACLE_STALE), "Oracle data is stale");
        require(attestation.csvValue >= initialCsvValue, "Oracle value insufficient");
        
        // Check LTV compliance (patent-pending automated enforcement)
        uint256 newLTV = (tokensToIssue * navPerToken) * 10000 / initialCsvValue;
        require(newLTV <= MAX_LTV, "LTV exceeds maximum allowed");
        
        // Create policy backing
        policyBackings[policyId] = PolicyBacking({
            policyId: policyId,
            csvValue: initialCsvValue,
            allocatedAmount: tokensToIssue,
            lastUpdate: block.timestamp,
            isActive: true
        });
        
        activePolicies.push(policyId);
        totalCsvValue += initialCsvValue;
        
        // Issue tokens (compliance check in _beforeTokenTransfer)
        _mint(recipient, tokensToIssue);
        
        emit PolicyAdded(policyId, initialCsvValue, tokensToIssue);
        _updateNAV();
    }
    
    /**
     * @dev Update CSV value from oracle with freshness verification
     */
    function updatePolicyValue(bytes32 policyId) external nonReentrant {
        require(policyBackings[policyId].isActive, "Policy not active");
        
        ICSVOracle.PolicyAttestation memory attestation = csvOracle.getAttestation(policyId);
        require(!csvOracle.isStale(policyId, MAX_ORACLE_STALE), "Oracle data is stale");
        
        uint256 oldValue = policyBackings[policyId].csvValue;
        uint256 newValue = attestation.csvValue;
        
        // Update backing
        policyBackings[policyId].csvValue = newValue;
        policyBackings[policyId].lastUpdate = block.timestamp;
        
        // Update total
        totalCsvValue = totalCsvValue - oldValue + newValue;
        
        // Check LTV compliance (automated breach detection)
        uint256 currentLTV = (policyBackings[policyId].allocatedAmount * navPerToken) * 10000 / newValue;
        if (currentLTV > MAX_LTV) {
            emit LTVBreach(policyId, currentLTV, MAX_LTV);
            // Could trigger automated liquidation logic here
        }
        
        emit PolicyUpdated(policyId, newValue, oldValue);
        _updateNAV();
    }
    
    /**
     * @dev Calculate and update Net Asset Value (patent-pending real-time calculation)
     */
    function _updateNAV() internal {
        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ > 0) {
            navPerToken = (totalCsvValue * 1e18) / totalSupply_;
        }
        lastNavUpdate = block.timestamp;
        emit NAVUpdated(navPerToken, totalCsvValue, totalSupply_);
    }
    
    /**
     * @dev Waterfall distribution to tranches (senior gets priority)
     * Patent claim: Waterfall tranche logic applied to pooled CSV assets
     */
    function distributeTranches(uint256 totalYield) external onlyRole(ADMIN_ROLE) {
        uint256 seniorAmount = (totalYield * SENIOR_TRANCHE_RATIO) / 10000;
        uint256 juniorAmount = totalYield - seniorAmount;
        
        trancheInfo.seniorYield += seniorAmount;
        trancheInfo.juniorYield += juniorAmount;
        trancheInfo.lastDistribution = block.timestamp;
        
        emit TrancheDistribution(seniorAmount, juniorAmount);
    }
    
    /**
     * @dev Publish universal disclosure hash to IPFS
     * Creates transparency layer that becomes minimum bar for regulators
     */
    function publishDisclosure(string calldata ipfsHash) external onlyRole(ADMIN_ROLE) {
        // Create state hash for epoch
        bytes32 stateHash = keccak256(abi.encodePacked(
            totalCsvValue,
            totalSupply(),
            navPerToken,
            block.timestamp,
            currentEpoch
        ));
        
        disclosureHashes[currentEpoch] = ipfsHash;
        
        emit DisclosurePublished(currentEpoch, ipfsHash, stateHash);
        currentEpoch++;
    }
    
    /**
     * @dev Override transfer with compliance checks
     * Patent claim: Combining on-chain compliance checks with off-chain attestations
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Pausable) {
        super._beforeTokenTransfer(from, to, amount);
        
        // Skip compliance for minting
        if (from == address(0)) {
            require(complianceEngine.isAccredited(to), "Recipient not accredited");
            return;
        }
        
        // Skip compliance for burning
        if (to == address(0)) {
            return;
        }
        
        // Full compliance check for transfers (Compliance-by-Design™)
        (bool canTransfer, string memory reason) = complianceEngine.canTransfer(from, to, amount);
        if (!canTransfer) {
            emit TransferRestricted(from, to, amount, reason);
            revert(string(abi.encodePacked("Transfer restricted: ", reason)));
        }
        
        // Check lockup periods
        require(block.timestamp >= lockupExpiry[from], "Tokens are locked");
        
        emit ComplianceCheckPassed(from, to, amount);
    }
    
    /**
     * @dev Set lockup period for address (Reg D compliance)
     */
    function setLockup(address holder, uint256 lockupPeriod) external onlyRole(COMPLIANCE_ROLE) {
        lockupExpiry[holder] = block.timestamp + lockupPeriod;
    }
    
    /**
     * @dev Emergency pause functionality
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Get current LTV ratio for a policy
     */
    function getPolicyLTV(bytes32 policyId) external view returns (uint256) {
        PolicyBacking memory backing = policyBackings[policyId];
        require(backing.isActive, "Policy not active");
        
        if (backing.csvValue == 0) return 0;
        return (backing.allocatedAmount * navPerToken) * 10000 / backing.csvValue;
    }
    
    /**
     * @dev Get comprehensive system status for dashboard
     */
    function getSystemStatus() external view returns (
        uint256 totalCsv,
        uint256 currentNav,
        uint256 totalTokens,
        uint256 lastUpdate,
        uint256 activePolicyCount
    ) {
        return (
            totalCsvValue,
            navPerToken,
            totalSupply(),
            lastNavUpdate,
            activePolicies.length
        );
    }
    
    /**
     * @dev Mint new tokens (restricted to authorized roles)
     */
    function mint(address to, uint256 amount) external onlyRole(ADMIN_ROLE) {
        require(complianceEngine.isAccredited(to), "Recipient not accredited");
        _mint(to, amount);
        _updateNAV();
    }
    
    /**
     * @dev Burn tokens (for redemption)
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        _updateNAV();
    }
    
    /**
     * @dev Get active policy count
     */
    function getActivePolicyCount() external view returns (uint256) {
        return activePolicies.length;
    }
    
    /**
     * @dev Get policy backing details
     */
    function getPolicyBacking(bytes32 policyId) external view returns (PolicyBacking memory) {
        return policyBackings[policyId];
    }
}