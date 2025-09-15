# EIP-XXXX: ERC-RWA-CSV - Real World Asset Token Standard for Insurance-Backed Securities

## Simple Summary

A standard interface for tokenizing insurance cash surrender value (CSV) backed securities with integrated compliance, risk management, and transparency features.

## Abstract

This EIP proposes a standard for Real World Asset (RWA) tokens specifically designed for insurance cash surrender value backed securities. The standard extends ERC-20 with compliance controls, oracle-based valuation updates, and risk management features required for regulated financial products.

The standard defines the Proof-of-CSV™ system that ensures transparency and auditability of underlying insurance assets while maintaining compliance with securities regulations.

## Motivation

Traditional insurance policies with cash surrender value represent a significant untapped asset class that could benefit from tokenization. However, existing token standards lack the necessary compliance, risk management, and transparency features required for regulated financial products.

This standard addresses:
- **Regulatory Compliance**: Built-in KYC/AML, Rule 144, and Regulation S controls
- **Risk Management**: Automated LTV monitoring and concentration limits
- **Transparency**: Oracle-based valuations with cryptographic proofs
- **Liquidity**: Programmable secondary markets with compliance enforcement

## Specification

### Interface

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IERC20.sol";

/**
 * @title IERC_RWA_CSV Interface
 * @dev Interface for ERC-RWA-CSV - Real World Asset Token Standard for Insurance-Backed Securities
 */
interface IERC_RWA_CSV is IERC20 {
    
    // Compliance Events
    event ValuationUpdated(bytes32 indexed merkleRoot, uint256 newValuation, uint256 timestamp);
    event ComplianceStatusChanged(address indexed account, bool compliant);
    event TransferBlocked(address indexed from, address indexed to, string reason);
    event LTVRatioUpdated(uint256 newRatio, uint256 maxRatio);
    event Rule144LockupSet(address indexed account, uint256 unlockTimestamp);
    event RegSTransferAttempted(address indexed from, address indexed to, string jurisdiction);
    
    // Compliance Functions
    function isCompliantTransfer(address from, address to, uint256 amount) external view returns (bool);
    function setComplianceStatus(address account, bool status) external;
    function getJurisdictionRestrictions(address account) external view returns (string[] memory);
    function setRule144Lockup(address account, uint256 unlockTimestamp) external;
    function getRule144Status(address account) external view returns (uint256 unlockTime, bool isRestricted);
    function checkRegSCompliance(address from, address to) external view returns (bool allowed, string memory reason);
    
    // Attestation Functions  
    function updateValuation(bytes32 merkleRoot, uint256 newValuation, bytes calldata proof) external;
    function verifyCSVProof(bytes32[] calldata merkleProof, bytes32 leaf) external view returns (bool);
    function getLastAttestationTimestamp() external view returns (uint256);
    function getMaxOracleStale() external view returns (uint256);
    function getCurrentMerkleRoot() external view returns (bytes32);
    
    // Risk Management
    function getCurrentLTV() external view returns (uint256);
    function getMaxLTV() external view returns (uint256);
    function updateLTVRatio(uint256 newMaxLTV) external;
    function getTotalCSVValue() external view returns (uint256);
    function getCollateralizationRatio() external view returns (uint256);
    
    // Enhanced Transfer Functions
    function compliantTransfer(address to, uint256 amount, bytes calldata complianceData) external returns (bool);
    function compliantTransferFrom(address from, address to, uint256 amount, bytes calldata complianceData) external returns (bool);
    
    // Disclosure and Transparency
    function getDisclosureHash() external view returns (string memory ipfsHash);
    function updateDisclosureHash(string calldata newIpfsHash) external;
    function getUnderlyingAssetSummary() external view returns (
        uint256 totalCSV,
        uint256 policyCount,
        string[] memory carrierNames,
        uint256[] memory carrierExposures
    );
}

/**
 * @title IComplianceProvider Interface
 * @dev Interface for external compliance verification
 */
interface IComplianceProvider {
    function verifyKYC(address account) external view returns (bool);
    function verifyAccreditation(address account) external view returns (bool);
    function getJurisdiction(address account) external view returns (string memory);
    function checkSanctions(address account) external view returns (bool isSanctioned);
    function getComplianceScore(address account) external view returns (uint256 score);
}

/**
 * @title ICSVOracle Interface  
 * @dev Interface for Proof-of-CSV oracle system
 */
interface ICSVOracle {
    struct ValuationData {
        uint256 totalCSV;
        uint256 timestamp;
        bytes32 merkleRoot;
        address[] attestors;
        uint256 carrierRating;
        uint256 concentrationRisk;
    }
    
    struct CarrierData {
        string name;
        uint256 rating; // 1-1000 (AAA=1000, D=1)
        uint256 lastUpdated;
        bool isActive;
        uint256 csvAmount;
        uint256 policyCount;
    }
    
    struct PolicyData {
        bytes32 policyId;
        uint256 csvValue;
        uint256 vintage; // Policy inception timestamp
        string carrierName;
        uint256 lastValuation;
        bool isActive;
    }
    
    // Core Oracle Functions
    function getLatestValuation() external view returns (ValuationData memory);
    function submitValuation(uint256 csv, bytes32 merkleRoot, bytes calldata signature) external;
    function verifyAttestor(address attestor) external view returns (bool);
    function getMinAttestors() external view returns (uint256);
    function getAttestorThreshold() external view returns (uint256 required, uint256 total);
    
    // Carrier and Policy Management
    function getCarrierData(bytes32 carrierId) external view returns (CarrierData memory);
    function updateCarrierRating(bytes32 carrierId, uint256 newRating) external;
    function addPolicy(PolicyData calldata policy) external;
    function removePolicy(bytes32 policyId) external;
    function getPolicy(bytes32 policyId) external view returns (PolicyData memory);
    
    // Risk Assessment
    function calculateConcentrationRisk() external view returns (uint256);
    function getCarrierConcentration(bytes32 carrierId) external view returns (uint256 percentage);
    function checkVintageCompliance(uint256 minVintage) external view returns (bool);
    
    // Oracle Events
    event ValuationSubmitted(address indexed attestor, uint256 csvValue, bytes32 merkleRoot, uint256 timestamp);
    event ValuationFinalized(uint256 csvValue, bytes32 merkleRoot, uint256 attestorCount, uint256 timestamp);
    event AttestorSlashed(address indexed attestor, uint256 slashAmount, string reason);
    event CarrierRatingUpdated(bytes32 indexed carrierId, uint256 oldRating, uint256 newRating);
    event PolicyAdded(bytes32 indexed policyId, uint256 csvValue, string carrier);
    event PolicyRemoved(bytes32 indexed policyId, string reason);
}

/**
 * @title ICSVVault Interface
 * @dev Interface for CSV vault with concentration and vintage controls
 */
interface ICSVVault {
    struct VaultConfiguration {
        uint256 maxCarrierConcentration; // Basis points (3000 = 30%)
        uint256 minPolicyVintage; // Minimum age in seconds
        uint256 maxLTV; // Maximum loan-to-value ratio
        uint256 liquidationThreshold; // LTV threshold for liquidation
        bool emergencyPaused;
    }
    
    struct ConcentrationLimits {
        mapping(bytes32 => uint256) carrierExposure;
        mapping(string => uint256) jurisdictionExposure;
        uint256 totalExposure;
        uint256 lastUpdated;
    }
    
    // Vault Management
    function deposit(bytes32[] calldata policyIds, uint256[] calldata csvValues) external returns (uint256 tokensIssued);
    function withdraw(uint256 tokenAmount) external returns (uint256 csvReturned);
    function liquidate(address account, uint256 amount) external;
    
    // Risk Controls
    function checkConcentrationLimits(bytes32 carrierId, uint256 additionalAmount) external view returns (bool allowed);
    function checkVintageRequirements(bytes32[] calldata policyIds) external view returns (bool compliant);
    function calculateLTV() external view returns (uint256 currentLTV);
    function isLiquidationRequired(address account) external view returns (bool);
    
    // Configuration
    function updateConcentrationLimit(uint256 newLimit) external;
    function updateVintageRequirement(uint256 newMinVintage) external;
    function updateLTVLimits(uint256 newMaxLTV, uint256 newLiquidationThreshold) external;
    function emergencyPause() external;
    function emergencyUnpause() external;
    
    // View Functions
    function getVaultConfiguration() external view returns (VaultConfiguration memory);
    function getCurrentConcentrations() external view returns (bytes32[] memory carrierIds, uint256[] memory concentrations);
    function getAccountPosition(address account) external view returns (uint256 tokens, uint256 csvValue, uint256 ltv);
    
    // Events
    event Deposit(address indexed account, uint256 csvAmount, uint256 tokensIssued);
    event Withdrawal(address indexed account, uint256 tokenAmount, uint256 csvReturned);
    event Liquidation(address indexed account, uint256 tokenAmount, uint256 csvLiquidated);
    event ConcentrationLimitUpdated(uint256 oldLimit, uint256 newLimit);
    event VintageRequirementUpdated(uint256 oldVintage, uint256 newVintage);
    event EmergencyPause(bool paused);
}
```

### Key Features

#### 1. Compliance Integration

The standard requires integration with a compliance provider that verifies:
- KYC/AML status
- Accredited investor status  
- Jurisdiction and geographic restrictions
- Sanctions screening
- Rule 144 holding periods
- Regulation S offshore transfer restrictions

#### 2. Oracle-Based Valuations

The Proof-of-CSV™ system provides:
- Multi-attestor consensus for valuations
- Cryptographic proof of underlying assets
- Merkle tree verification of individual policies
- Stale data protection
- Attestor slashing for incorrect data

#### 3. Risk Management

Built-in risk controls include:
- Loan-to-value (LTV) ratio monitoring
- Carrier concentration limits
- Policy vintage requirements
- Automatic liquidation triggers
- Emergency pause mechanisms

#### 4. Transparency and Disclosure

The standard supports:
- IPFS-based disclosure documents
- Real-time asset composition queries
- Historical valuation data
- Compliance audit trails
- Regulatory reporting capabilities

## Implementation

### Core Contract Structure

```solidity
contract ERCRWACSV is ERC20, AccessControl, ReentrancyGuard, IERC_RWA_CSV {
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
    
    // Integration contracts
    IComplianceProvider public immutable complianceProvider;
    ICSVOracle public immutable csvOracle;
    ICSVVault public immutable csvVault;
    
    // IPFS disclosure hash
    string public disclosureHash;
    
    modifier onlyCompliantTransfer(address from, address to, uint256 amount) {
        (bool allowed, string memory reason) = _checkCompliance(from, to, amount);
        require(allowed, reason);
        _;
    }
    
    function _checkCompliance(address from, address to, uint256 amount) 
        internal view returns (bool allowed, string memory reason) 
    {
        // KYC verification
        if (!complianceProvider.verifyKYC(to)) {
            return (false, "Recipient not KYC verified");
        }
        
        // Accredited investor requirement
        if (!complianceProvider.verifyAccreditation(to)) {
            return (false, "Recipient not accredited investor");
        }
        
        // Rule 144 lockup check
        if (rule144Lockup[from] > block.timestamp) {
            return (false, "Rule 144 holding period not met");
        }
        
        // Sanctions screening
        if (complianceProvider.checkSanctions(to)) {
            return (false, "Recipient on sanctions list");
        }
        
        // Regulation S compliance
        (bool regSAllowed, string memory regSReason) = checkRegSCompliance(from, to);
        if (!regSAllowed) {
            return (false, regSReason);
        }
        
        return (true, "");
    }
}
```

### Oracle Implementation

```solidity
contract CSVOracle is AccessControl, ICSVOracle {
    uint256 public requiredAttestors = 2;
    uint256 public totalAttestors = 5;
    
    mapping(address => uint256) public attestorStake;
    mapping(address => bool) public slashedAttestors;
    
    function submitValuation(uint256 csv, bytes32 merkleRoot, bytes calldata signature) 
        external override onlyAttestor 
    {
        require(!slashedAttestors[msg.sender], "Attestor slashed");
        require(_verifySignature(csv, merkleRoot, signature), "Invalid signature");
        
        // Store submission and check for consensus
        _processSubmission(csv, merkleRoot);
    }
    
    function slashAttestor(address attestor, string calldata reason) 
        external onlyRole(ORACLE_MANAGER_ROLE) 
    {
        require(attestorStake[attestor] > 0, "No stake to slash");
        
        uint256 slashAmount = attestorStake[attestor];
        attestorStake[attestor] = 0;
        slashedAttestors[attestor] = true;
        
        emit AttestorSlashed(attestor, slashAmount, reason);
    }
}
```

### Vault Implementation

```solidity
contract CSVVault is AccessControl, ReentrancyGuard, ICSVVault {
    VaultConfiguration public config;
    
    function deposit(bytes32[] calldata policyIds, uint256[] calldata csvValues) 
        external override nonReentrant returns (uint256 tokensIssued) 
    {
        require(checkVintageRequirements(policyIds), "Policy vintage requirement not met");
        
        uint256 totalCSV = 0;
        for (uint256 i = 0; i < policyIds.length; i++) {
            bytes32 carrierId = oracle.getPolicy(policyIds[i]).carrierId;
            require(
                checkConcentrationLimits(carrierId, csvValues[i]),
                "Would exceed carrier concentration limit"
            );
            totalCSV += csvValues[i];
        }
        
        tokensIssued = _calculateTokensToIssue(totalCSV);
        _mint(msg.sender, tokensIssued);
        
        emit Deposit(msg.sender, totalCSV, tokensIssued);
    }
    
    function checkConcentrationLimits(bytes32 carrierId, uint256 additionalAmount) 
        external view override returns (bool allowed) 
    {
        uint256 currentExposure = concentrationLimits.carrierExposure[carrierId];
        uint256 newExposure = currentExposure + additionalAmount;
        uint256 totalExposure = concentrationLimits.totalExposure + additionalAmount;
        
        uint256 concentrationBps = (newExposure * 10000) / totalExposure;
        return concentrationBps <= config.maxCarrierConcentration;
    }
}
```

## Rationale

### Design Decisions

1. **Compliance-First Approach**: All transfers require compliance verification to ensure regulatory adherence
2. **Oracle Integration**: Multi-attestor system provides transparency and prevents manipulation
3. **Risk Management**: Built-in LTV and concentration controls protect token holders
4. **Modularity**: Separate contracts for different concerns allow upgradability and flexibility
5. **Transparency**: IPFS integration and public view functions provide full disclosure

### Security Considerations

1. **Reentrancy Protection**: All state-changing functions use reentrancy guards
2. **Access Control**: Role-based permissions for administrative functions
3. **Oracle Manipulation**: Multi-attestor consensus and slashing prevents oracle attacks
4. **Compliance Bypass**: Multiple layers of compliance checking prevent circumvention
5. **Emergency Controls**: Pause mechanisms for emergency situations

## Implementation Examples

### Basic Token Creation

```solidity
// Deploy compliance provider
ComplianceProvider compliance = new ComplianceProvider();

// Deploy oracle system
CSVOracle oracle = new CSVOracle(admin, attestors);

// Deploy vault
CSVVault vault = new CSVVault(oracle, compliance);

// Deploy main token
ERCRWACSV token = new ERCRWACSV(
    "iYield CSV Token",
    "iCSV",
    address(compliance),
    address(oracle),
    address(vault),
    admin
);
```

### Compliance Integration

```solidity
// Set up compliance for user
compliance.setKYCStatus(user, true);
compliance.setAccreditedStatus(user, true);
compliance.setJurisdiction(user, "US");

// Set Rule 144 lockup
uint256 lockupEnd = block.timestamp + 365 days;
token.setRule144Lockup(user, lockupEnd);

// Transfer will check all compliance requirements
token.transfer(recipient, amount);
```

### Oracle Updates

```solidity
// Attestors submit valuations
oracle.submitValuation(1000000e18, merkleRoot, signature1);
oracle.submitValuation(1000100e18, merkleRoot, signature2);

// Once consensus reached, token contract updates
token.updateValuation(merkleRoot, consensusValue, proof);
```

## Security Considerations

### Oracle Security
- Multi-attestor consensus prevents single points of failure
- Cryptographic signatures ensure data integrity
- Slashing mechanism penalizes bad actors
- Stale data protection prevents outdated valuations

### Compliance Security
- Multiple verification layers prevent bypass attempts
- Integration with external compliance providers
- Comprehensive audit trails for regulatory review
- Emergency controls for crisis situations

### Smart Contract Security
- Comprehensive access controls
- Reentrancy protection on all critical functions
- Input validation and bounds checking
- Emergency pause mechanisms

## Copyright

Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).

---

**Authors**: iYield Protocol Team
**Discussions**: [Link to discussions]
**Status**: Draft
**Type**: Standards Track
**Category**: ERC
**Created**: [Date]
**Requires**: EIP-20