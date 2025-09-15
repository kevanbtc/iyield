# Compliance Matrix - iYield Protocol

## Overview
This document maps the iYield Protocol smart contracts and functionality to applicable regulatory requirements, ensuring comprehensive compliance coverage for insurance cash surrender value (CSV) backed tokens.

## Regulatory Framework Summary

### Primary Applicable Regulations
- **Securities Act of 1933** (Federal securities registration and disclosure)
- **Securities Exchange Act of 1934** (Trading and ongoing reporting)
- **Investment Company Act of 1940** (Investment company registration exemptions)
- **Investment Advisers Act of 1940** (If applicable to token management)
- **Regulation D** (Private placement exemptions)
- **Regulation S** (Offshore offerings and resales)
- **Rule 144** (Resale of restricted securities)
- **Anti-Money Laundering (AML)** regulations
- **Know Your Customer (KYC)** requirements
- **State Insurance Laws** (For underlying CSV assets)

---

## Smart Contract Compliance Mapping

### 1. ERCRWACSV.sol - Main Token Contract

#### Compliance Features Implemented

| Regulatory Requirement | Contract Implementation | Code Reference |
|------------------------|------------------------|----------------|
| **Securities Transfer Restrictions** | `onlyCompliantTransfer` modifier | Lines 44-47 |
| **Rule 144 Holding Period** | `rule144Lockup` mapping and checks | Lines 23, 94, 232-238 |
| **Accredited Investor Verification** | Integration with ComplianceRegistry | Lines 97, 199 |
| **KYC/AML Compliance** | KYC verification before transfers | Lines 91, 198 |
| **Geographic Restrictions (Reg S)** | Jurisdiction-based transfer controls | Lines 99-106 |
| **Transfer Blocking** | Comprehensive compliance checks | Lines 85-109 |
| **Audit Trail** | Event emissions for all compliance actions | Lines 222-266 |

#### Enhanced Compliance Features (To Be Added)

| Regulatory Requirement | Planned Implementation | Priority |
|------------------------|----------------------|----------|
| **Explicit Transfer Blocking Events** | `TransferBlocked` event with reason | High |
| **Reg S Offshore Controls** | Enhanced geographic restrictions | High |
| **Real-time Compliance Views** | Public compliance status functions | Medium |
| **Regulatory Reporting** | Automated compliance reporting | Medium |

### 2. CSVOracle.sol - Oracle System

#### Compliance Features Implemented

| Regulatory Requirement | Contract Implementation | Code Reference |
|------------------------|------------------------|----------------|
| **Data Integrity** | Multi-attestor consensus system | Lines 98-134 |
| **Audit Trail** | Comprehensive event logging | Lines 47-52 |
| **Access Controls** | Role-based permissions | Lines 18-21 |
| **Rate Limiting** | Submission frequency controls | Lines 103-107 |
| **Signature Verification** | Cryptographic proof of data | Lines 109-113 |

#### Enhanced Oracle Features (To Be Added)

| Regulatory Requirement | Planned Implementation | Priority |
|------------------------|----------------------|----------|
| **2-of-N Signature Threshold** | Configurable multi-sig requirements | High |
| **Attestor Slashing** | Penalty mechanism for bad actors | High |
| **Stale Data Protection** | Monotonicity and freshness checks | High |
| **Oracle Update Events** | Enhanced event emission with context | Medium |

### 3. ComplianceRegistry.sol - Compliance Management

#### Compliance Features Implemented

| Regulatory Requirement | Contract Implementation | Code Reference |
|------------------------|------------------------|----------------|
| **KYC Management** | KYC status tracking and verification | Lines 66-78 |
| **Accredited Investor Tracking** | Accreditation status management | Lines 82-95 |
| **Jurisdiction Management** | Geographic compliance tracking | Lines 99-113 |
| **Rule 144 Lockup Management** | Holding period enforcement | Lines 117-129 |
| **Batch Processing** | Efficient bulk compliance updates | Lines 196-225 |
| **Emergency Controls** | Compliance revocation capabilities | Lines 254-266 |

#### Additional Registry Features (Working Well)

| Feature | Implementation Status | Notes |
|---------|----------------------|-------|
| **Role-based Access** | ✅ Implemented | COMPLIANCE_OFFICER_ROLE, KYC_PROVIDER_ROLE |
| **Audit Logging** | ✅ Implemented | All compliance changes logged |
| **Jurisdiction Support** | ✅ Implemented | Configurable supported jurisdictions |
| **Provider Management** | ✅ Implemented | Trusted KYC provider system |

### 4. CSVVault.sol - Vault Contract (To Be Created)

#### Required Compliance Features

| Regulatory Requirement | Planned Implementation | Priority |
|------------------------|----------------------|----------|
| **Carrier Concentration Limits** | 30% maximum exposure per carrier | High |
| **Policy Vintage Requirements** | Minimum policy age enforcement | High |
| **Pre-mint Risk Checks** | Concentration/vintage validation | High |
| **CSV Value Tracking** | Real-time collateral monitoring | High |
| **Liquidation Controls** | Automatic risk management | Medium |

---

## Regulatory Mapping by Requirement Type

### Securities Law Compliance

#### Securities Act of 1933
- **Section 5 Registration Requirements**
  - *Compliance*: Private placement under Regulation D exemption
  - *Implementation*: Accredited investor verification in ComplianceRegistry
  - *Code*: `isAccreditedInvestor()` checks

- **Rule 506 Safe Harbor**
  - *Compliance*: Maximum investor count and accreditation
  - *Implementation*: ComplianceRegistry tracking and limits
  - *Code*: Batch compliance management

#### Rule 144 - Resale Restrictions
- **Holding Period Requirements**
  - *Compliance*: Minimum holding periods for restricted securities
  - *Implementation*: `rule144Lockup` mapping in ERCRWACSV
  - *Code*: Lines 23, 94 in ERCRWACSV.sol

- **Public Information Requirement**
  - *Compliance*: Adequate current information available
  - *Implementation*: IPFS disclosure system (to be added)
  - *Code*: Pin-disclosure script (to be created)

#### Regulation S - Offshore Offerings
- **Geographic Restrictions**
  - *Compliance*: No sales to US persons in offshore transactions
  - *Implementation*: Jurisdiction-based transfer controls
  - *Code*: Geographic validation in `isCompliantTransfer()`

### Investment Company Act Compliance

#### Section 3(c)(1) Exemption
- **100 Investor Limit**
  - *Compliance*: Maximum 100 beneficial owners
  - *Implementation*: Token holder count tracking (to be enhanced)
  - *Code*: Counter in ERCRWACSV (to be added)

- **No Public Offering**
  - *Compliance*: Private placement only
  - *Implementation*: Accredited investor restriction
  - *Code*: ComplianceRegistry verification

### AML/KYC Compliance

#### Bank Secrecy Act
- **Customer Identification Program**
  - *Compliance*: Identity verification for all customers
  - *Implementation*: KYC verification in ComplianceRegistry
  - *Code*: `setKYCStatus()` and verification checks

- **Suspicious Activity Reporting**
  - *Compliance*: Monitor and report suspicious transactions
  - *Implementation*: Event logging and monitoring (to be enhanced)
  - *Code*: Comprehensive event emissions

#### OFAC Compliance
- **Sanctions Screening**
  - *Compliance*: Screen against prohibited persons
  - *Implementation*: Integration with sanctions lists (to be added)
  - *Code*: Enhanced compliance checking

---

## Risk Management Mapping

### Operational Risk Controls

| Risk Category | Contract Implementation | Monitoring |
|---------------|------------------------|------------|
| **Concentration Risk** | CSVVault carrier limits (to be added) | Real-time monitoring |
| **Credit Risk** | Carrier rating requirements | Oracle-based updates |
| **Liquidity Risk** | LTV ratio management | Automatic ratchets |
| **Technology Risk** | Multi-sig controls and audits | Continuous monitoring |

### Compliance Risk Controls

| Risk Category | Implementation | Validation |
|---------------|----------------|------------|
| **Transfer Violations** | Pre-transfer compliance checks | Real-time validation |
| **Regulatory Changes** | Upgradeable compliance logic | Administrative controls |
| **Data Integrity** | Multi-attestor oracle system | Cryptographic verification |
| **Unauthorized Access** | Role-based access control | Permission auditing |

---

## Audit and Reporting Framework

### On-chain Audit Trail

All compliance-related actions generate events for regulatory audit:

```solidity
// Example compliance events
event ComplianceStatusChanged(address indexed account, bool compliant);
event TransferBlocked(address indexed from, address indexed to, string reason);
event Rule144LockupSet(address indexed account, uint256 unlockTimestamp);
event KYCStatusUpdated(address indexed account, bool status, address indexed verifier);
```

### Regulatory Reporting Capabilities

1. **Real-time Compliance Status**: Query any address for compliance status
2. **Historical Transaction Logs**: Full audit trail via blockchain events
3. **Concentration Monitoring**: Real-time carrier and geographic exposure
4. **Valuation History**: Complete CSV valuation audit trail

### External Reporting Integration

- **SEC Reporting**: Quarterly and annual filings (manual process)
- **State Regulators**: Insurance-related reporting (manual process)
- **Audit Firms**: Smart contract state and event exports
- **Compliance Officers**: Real-time monitoring dashboards

---

## Implementation Status

### Current Implementation ✅
- [x] Basic KYC/AML framework
- [x] Rule 144 holding period enforcement
- [x] Accredited investor verification
- [x] Geographic jurisdiction tracking
- [x] Multi-attestor oracle system
- [x] Role-based access controls
- [x] Comprehensive event logging

### Planned Enhancements 🔄
- [ ] Enhanced Rule 144 and Reg S controls (ERCRWACSV)
- [ ] 2-of-N oracle threshold and slashing (CSVOracle)
- [ ] Carrier concentration and vintage controls (CSVVault)
- [ ] IPFS disclosure pinning system
- [ ] Explicit transfer blocking events
- [ ] Real-time compliance reporting views

### Future Considerations 🔮
- [ ] Integration with external sanctions lists
- [ ] Automated regulatory filing systems
- [ ] Cross-border compliance frameworks
- [ ] Enhanced privacy-preserving compliance
- [ ] Decentralized compliance governance

---

*This compliance matrix is maintained as a living document and updated with each protocol upgrade. Last updated: [Date]*

**Document Version**: 1.0
**Last Review**: [Date]
**Next Review**: [Date + 6 months]