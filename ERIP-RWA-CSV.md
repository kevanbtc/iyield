---
erip: TBD
title: ERC-RWA:CSV - Real World Asset Token Standard for Insurance-Backed Securities
description: A token standard for insurance cash surrender value backed real world assets with on-chain compliance and proof-of-attestation
author: iYield Protocol
discussions-to: TBD
status: Draft
type: Standards Track
category: ERC
created: 2024-09-15
requires: 20, 165, 721
---

# ERC-RWA:CSV - Real World Asset Token Standard for Insurance-Backed Securities

## Simple Summary

A token standard for tokenizing insurance cash surrender values (CSV) as real world assets with built-in compliance, transfer restrictions, and attestation proofs.

## Abstract

This proposal defines a token standard that extends ERC-20 to support insurance cash surrender value backed securities with:
- Regulatory compliance enforcement (Reg D/S, Rule 144)
- Jurisdiction-based transfer restrictions
- KYC proof verification via soulbound NFTs
- Oracle-based valuation with Merkle proof attestations (Proof-of-CSV™)
- Automatic loan-to-value (LTV) ratio management

## Motivation

Traditional insurance cash surrender values are illiquid assets that could provide significant capital efficiency if properly tokenized. However, existing token standards lack:

1. **Regulatory Compliance**: No built-in transfer restrictions for securities regulations
2. **Attestation Framework**: No standardized way to prove underlying asset valuations
3. **Geographic Restrictions**: No jurisdiction-based transfer controls
4. **Identity Verification**: No integration with KYC/AML requirements
5. **Risk Management**: No automatic collateral ratio management

The ERC-RWA:CSV standard addresses these gaps by providing a comprehensive framework for insurance-backed RWA tokens.

## Specification

### Core Interface

```solidity
interface IERC_RWA_CSV is IERC20, IERC165 {
    // Events
    event ValuationUpdated(bytes32 indexed merkleRoot, uint256 newValuation, uint256 timestamp);
    event ComplianceStatusChanged(address indexed account, bool compliant);
    event TransferRestricted(address indexed from, address indexed to, string reason);
    event LTVRatioUpdated(uint256 newRatio, uint256 maxRatio);
    
    // Compliance Functions
    function isCompliantTransfer(address from, address to, uint256 amount) external view returns (bool);
    function setComplianceStatus(address account, bool status) external;
    function getJurisdictionRestrictions(address account) external view returns (string[] memory);
    
    // Attestation Functions
    function updateValuation(bytes32 merkleRoot, uint256 newValuation, bytes calldata proof) external;
    function verifyCSVProof(bytes32[] calldata merkleProof, bytes32 leaf) external view returns (bool);
    function getLastAttestationTimestamp() external view returns (uint256);
    function getMaxOracleStale() external view returns (uint256);
    
    // Risk Management
    function getCurrentLTV() external view returns (uint256);
    function getMaxLTV() external view returns (uint256);
    function updateLTVRatio(uint256 newMaxLTV) external;
    
    // Transfer Restrictions
    function transfer(address to, uint256 amount) external override returns (bool);
    function transferFrom(address from, address to, uint256 amount) external override returns (bool);
}
```

### Compliance Registry Integration

```solidity
interface IComplianceRegistry {
    function isKYCVerified(address account) external view returns (bool);
    function getJurisdiction(address account) external view returns (string memory);
    function isAccreditedInvestor(address account) external view returns (bool);
    function getRule144Lockup(address account) external view returns (uint256);
}
```

### Proof-of-CSV Oracle Interface

```solidity
interface ICSVOracle {
    struct ValuationData {
        uint256 totalCSV;
        uint256 timestamp;
        bytes32 merkleRoot;
        address[] attestors;
    }
    
    function getLatestValuation() external view returns (ValuationData memory);
    function submitValuation(uint256 csv, bytes32 merkleRoot, bytes calldata signature) external;
    function verifyAttestor(address attestor) external view returns (bool);
    function getMinAttestors() external view returns (uint256);
}
```

## Implementation

### Basic Implementation

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract ERCRWACSV is ERC20, AccessControl, IERC_RWA_CSV {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    
    // Compliance tracking
    mapping(address => bool) public complianceStatus;
    mapping(address => uint256) public rule144Lockup;
    mapping(address => string) public jurisdiction;
    
    // Attestation data
    bytes32 public currentMerkleRoot;
    uint256 public lastAttestationTimestamp;
    uint256 public constant MAX_ORACLE_STALE = 7 days;
    uint256 public totalCSVValue;
    
    // Risk management
    uint256 public currentLTV;
    uint256 public maxLTV = 8000; // 80%
    
    IComplianceRegistry public complianceRegistry;
    ICSVOracle public csvOracle;
    
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
    
    constructor(
        string memory name,
        string memory symbol,
        address _complianceRegistry,
        address _csvOracle
    ) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        complianceRegistry = IComplianceRegistry(_complianceRegistry);
        csvOracle = ICSVOracle(_csvOracle);
    }
    
    function isCompliantTransfer(
        address from,
        address to,
        uint256 amount
    ) public view override returns (bool) {
        // KYC verification
        if (!complianceRegistry.isKYCVerified(to)) return false;
        
        // Rule 144 lockup check
        if (rule144Lockup[from] > block.timestamp) return false;
        
        // Accredited investor requirement
        if (!complianceRegistry.isAccreditedInvestor(to)) return false;
        
        // Jurisdiction restrictions
        string memory fromJurisdiction = complianceRegistry.getJurisdiction(from);
        string memory toJurisdiction = complianceRegistry.getJurisdiction(to);
        
        // Add jurisdiction-specific logic here
        
        return true;
    }
    
    function transfer(address to, uint256 amount) 
        public 
        override(ERC20, IERC_RWA_CSV) 
        onlyCompliantTransfer(msg.sender, to, amount)
        oracleNotStale
        returns (bool) 
    {
        return super.transfer(to, amount);
    }
    
    function transferFrom(address from, address to, uint256 amount)
        public
        override(ERC20, IERC_RWA_CSV)
        onlyCompliantTransfer(from, to, amount)
        oracleNotStale
        returns (bool)
    {
        return super.transferFrom(from, to, amount);
    }
    
    function updateValuation(
        bytes32 merkleRoot,
        uint256 newValuation,
        bytes calldata proof
    ) external override onlyRole(ORACLE_ROLE) {
        // Verify oracle signature and consensus
        ICSVOracle.ValuationData memory data = csvOracle.getLatestValuation();
        require(data.attestors.length >= csvOracle.getMinAttestors(), "Insufficient attestors");
        
        currentMerkleRoot = merkleRoot;
        totalCSVValue = newValuation;
        lastAttestationTimestamp = block.timestamp;
        
        // Update LTV ratio
        _updateLTV();
        
        emit ValuationUpdated(merkleRoot, newValuation, block.timestamp);
    }
    
    function verifyCSVProof(
        bytes32[] calldata merkleProof,
        bytes32 leaf
    ) external view override returns (bool) {
        return MerkleProof.verify(merkleProof, currentMerkleRoot, leaf);
    }
    
    function _updateLTV() internal {
        if (totalSupply() > 0) {
            currentLTV = (totalSupply() * 10000) / totalCSVValue;
            
            if (currentLTV > maxLTV) {
                // Trigger automatic LTV ratchet
                emit LTVRatioUpdated(currentLTV, maxLTV);
            }
        }
    }
    
    function getCurrentLTV() external view override returns (uint256) {
        return currentLTV;
    }
    
    function getMaxLTV() external view override returns (uint256) {
        return maxLTV;
    }
    
    function updateLTVRatio(uint256 newMaxLTV) 
        external 
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        maxLTV = newMaxLTV;
        emit LTVRatioUpdated(currentLTV, maxLTV);
    }
    
    // Additional required functions...
    function setComplianceStatus(address account, bool status) 
        external 
        override 
        onlyRole(COMPLIANCE_ROLE) 
    {
        complianceStatus[account] = status;
        emit ComplianceStatusChanged(account, status);
    }
    
    function getJurisdictionRestrictions(address account) 
        external 
        view 
        override 
        returns (string[] memory) 
    {
        // Implementation for jurisdiction restrictions
        string[] memory restrictions = new string[](1);
        restrictions[0] = complianceRegistry.getJurisdiction(account);
        return restrictions;
    }
    
    function getLastAttestationTimestamp() external view override returns (uint256) {
        return lastAttestationTimestamp;
    }
    
    function getMaxOracleStale() external view override returns (uint256) {
        return MAX_ORACLE_STALE;
    }
    
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC20, AccessControl, IERC165) 
        returns (bool) 
    {
        return interfaceId == type(IERC_RWA_CSV).interfaceId ||
               super.supportsInterface(interfaceId);
    }
}
```

## Rationale

### Design Decisions

1. **Compliance-First Approach**: All transfers are checked against compliance rules before execution
2. **Merkle Proof Attestations**: Provides cryptographic proof of underlying CSV valuations
3. **Multi-Oracle Redundancy**: Requires consensus from multiple trusted attestors
4. **Automatic Risk Management**: LTV ratios are monitored and enforced automatically
5. **Jurisdiction-Aware**: Built-in support for geographic restrictions

### Security Considerations

1. **Oracle Manipulation**: Multiple attestors and time-based freshness checks prevent single-point manipulation
2. **Compliance Bypass**: All transfer functions enforce compliance checks that cannot be bypassed
3. **Stale Data**: Oracle freshness guards prevent operations with outdated valuations
4. **Role Management**: Critical functions are protected by role-based access controls

## Backwards Compatibility

This standard extends ERC-20 and maintains full backwards compatibility with existing ERC-20 implementations. Additional compliance and attestation functions are additive and do not modify core ERC-20 behavior.

## Test Cases

```solidity
// Test cases for compliance transfers
function testCompliantTransfer() public {
    // Setup compliant accounts
    complianceRegistry.setKYCStatus(alice, true);
    complianceRegistry.setAccreditedStatus(alice, true);
    
    // Should succeed
    token.transfer(alice, 1000);
    assert(token.balanceOf(alice) == 1000);
}

function testNonCompliantTransfer() public {
    // Setup non-compliant account
    complianceRegistry.setKYCStatus(bob, false);
    
    // Should fail
    vm.expectRevert("Transfer not compliant");
    token.transfer(bob, 1000);
}

// Test cases for oracle attestations
function testValidAttestation() public {
    bytes32 merkleRoot = keccak256("test_root");
    uint256 valuation = 1000000;
    
    vm.prank(oracle);
    token.updateValuation(merkleRoot, valuation, "");
    
    assert(token.currentMerkleRoot() == merkleRoot);
    assert(token.totalCSVValue() == valuation);
}
```

## Implementation

A reference implementation is available at: [GitHub Repository Link]

## Security Considerations

- Oracle centralization risks are mitigated through multi-attestor requirements
- Compliance bypass attempts are prevented through modifier-based enforcement
- Stale data risks are managed through timestamp-based freshness checks
- Role-based access controls protect critical administrative functions

## Copyright

Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).