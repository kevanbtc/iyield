---
erip: TBD
title: ERC-RWA:CSV - Real World Asset Token Standard for Insurance-Backed Securities
description: A token standard for insurance cash surrender value backed real world assets with on-chain compliance and proof-of-attestation
author: iYield Protocol
discussions-to: TBD
status: Draft
type: Standards Track
category: ERC
created: 2024-12-19
requires: 20, 165
---

# ERC-RWA:CSV - Real World Asset Token Standard for Insurance-Backed Securities

## Simple Summary

A token standard for tokenizing insurance cash surrender values (CSV) as real world assets with built-in compliance, transfer restrictions, and attestation proofs.

## Abstract

This proposal defines a token standard that extends ERC-20 to support insurance cash surrender value backed securities with:
- Regulatory compliance enforcement (Reg D/S, Rule 144)
- Oracle-based valuation with Merkle proof attestations (Proof-of-CSV™)
- Automatic loan-to-value (LTV) ratio management
- IPFS-based provenance tracking for regulatory transparency
- Waterfall tranche distribution mechanisms

## Motivation

Traditional insurance cash surrender values represent illiquid assets that could provide significant capital efficiency if properly tokenized. However, existing token standards lack:

1. **Regulatory Compliance**: No built-in transfer restrictions for securities regulations
2. **Attestation Framework**: No standardized way to prove underlying asset valuations
3. **Risk Management**: No automatic collateral ratio management
4. **Transparency**: No immutable audit trail for regulatory oversight

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
    event DisclosurePublished(uint256 indexed epoch, string ipfsHash, bytes32 stateHash);
    
    // Compliance Functions
    function isCompliantTransfer(address from, address to, uint256 amount) external view returns (bool);
    function setComplianceStatus(address account, bool status) external;
    
    // Attestation Functions  
    function updateValuation(bytes32 merkleRoot, uint256 newValuation, bytes calldata proof) external;
    function verifyCSVProof(bytes32[] calldata merkleProof, bytes32 leaf) external view returns (bool);
    function getLastAttestationTimestamp() external view returns (uint256);
    function getMaxOracleStale() external view returns (uint256);
    
    // Risk Management
    function getCurrentLTV() external view returns (uint256);
    function getMaxLTV() external view returns (uint256);
    function updateLTVRatio(uint256 newMaxLTV) external;
    function getTotalCSVValue() external view returns (uint256);
    
    // Transfer Functions (override ERC20)
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
```

### Compliance Registry Integration

```solidity
interface IComplianceRegistry {
    function isKYCVerified(address account) external view returns (bool);
    function isAccreditedInvestor(address account) external view returns (bool);
    function canTransfer(address from, address to, uint256 amount) external view returns (bool, string memory);
}
```

### Proof-of-CSV Oracle Interface

```solidity
interface ICSVOracle {
    struct PolicyAttestation {
        bytes32 policyId;
        uint256 csvValue;
        uint256 timestamp;
        string ipfsHash;
        bytes32 merkleRoot;
        address attester;
        bytes signature;
    }
    
    function getAttestation(bytes32 policyId) external view returns (PolicyAttestation memory);
    function isStale(bytes32 policyId, uint256 maxAge) external view returns (bool);
    function verifyMerkleProof(bytes32 policyId, bytes32[] calldata proof, bytes32 leaf) external view returns (bool);
}
```

## Implementation

### Key Features

1. **Compliance-First Approach**: All transfers are checked against compliance rules before execution
2. **Merkle Proof Attestations**: Provides cryptographic proof of underlying CSV valuations
3. **Automatic Risk Management**: LTV ratios are monitored and enforced automatically
4. **IPFS Provenance**: Transparent, immutable record-keeping for regulatory compliance

### Security Considerations

1. **Oracle Manipulation**: Multiple attestors and time-based freshness checks prevent single-point manipulation
2. **Compliance Bypass**: All transfer functions enforce compliance checks that cannot be bypassed
3. **Stale Data**: Oracle freshness guards prevent operations with outdated valuations
4. **Role Management**: Critical functions are protected by role-based access controls

## Backwards Compatibility

This standard extends ERC-20 and maintains full backwards compatibility with existing ERC-20 implementations. Additional compliance and attestation functions are additive and do not modify core ERC-20 behavior.

## Reference Implementation

A complete reference implementation is available at: [iYield Protocol Repository](https://github.com/kevanbtc/iyield)

The implementation demonstrates:
- ERC-3643 style compliance token with transfer restrictions
- CSV oracle with Merkle tree attestations and IPFS integration
- Comprehensive compliance engine with automated verification
- Waterfall tranche distribution mechanisms
- Real-time NAV calculations with automated LTV enforcement

## Security Considerations

- Oracle centralization risks are mitigated through multi-attestor requirements
- Compliance bypass attempts are prevented through modifier-based enforcement
- Stale data risks are managed through timestamp-based freshness checks
- Role-based access controls protect critical administrative functions

## Copyright

Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).