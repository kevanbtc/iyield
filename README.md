# iYield Protocol™

**The Future of Insurance-Backed Asset Tokenization**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Built with Hardhat](https://img.shields.io/badge/Built%20with-Hardhat-FFDB1C.svg)](https://hardhat.org/)
[![Next.js](https://img.shields.io/badge/Frontend-Next.js-black)](https://nextjs.org/)

## 🏛️ Overview

iYield Protocol is the **first comprehensive platform** for tokenizing insurance cash surrender values (CSV) with built-in regulatory compliance, risk management, and institutional-grade infrastructure. Our patent-pending **Proof-of-CSV™** system and **Compliance-by-Design™** architecture unlock $2.7 trillion in underutilized insurance assets.

### 🎯 Key Innovations

- **ERC-RWA:CSV Token Standard** - Industry-first standard for insurance-backed securities
- **Proof-of-CSV™ Oracle System** - Multi-attestor valuation with cryptographic verification
- **Compliance-by-Design™** - Automated Reg D/S compliance and KYC/AML integration
- **Institutional Dashboard** - Professional-grade transparency and risk monitoring
- **Patent-Defensible IP** - Comprehensive intellectual property protection strategy

## 🏗️ Technical Architecture

### Core Smart Contracts

```
contracts/
├── core/
│   ├── ERCRWACSV.sol           # Enhanced token with Rule 144/Reg S compliance
│   ├── CSVVault.sol            # Carrier concentration & vintage controls  
│   └── CSVLiquidityPool.sol    # Senior/junior tranche yield distribution
├── compliance/
│   └── ComplianceRegistry.sol  # Enhanced KYC/AML and jurisdiction management
├── oracles/
│   └── CSVOracle.sol          # Enhanced 2-of-N consensus with slashing
└── interfaces/
    └── IERC_RWA_CSV.sol       # Complete ERC-RWA:CSV interface
```

### Frontend Dashboard

```
frontend/
├── app/
│   ├── dashboard/             # Main protocol dashboard
│   ├── compliance/            # KYC/compliance interface  
│   ├── liquidity/             # Pool management interface
│   └── risk/                  # Risk monitoring dashboard
└── components/                # Reusable UI components
```

## 🚀 Quick Start

### Prerequisites

- Node.js 18+ 
- npm or yarn
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/kevanbtc/iyield.git
cd iyield

# Install all dependencies
npm run install-all

# Build contracts
npm run build-contracts

# Start the development server
npm run dev-frontend
```

### Smart Contract Deployment

```bash
cd contracts

# Deploy to local network
npx hardhat run scripts/deploy.js

# Deploy to testnet
npx hardhat run scripts/deploy.js --network sepolia

# Verify contracts
npx hardhat verify --network sepolia <contract-address>
```

## 📊 System Features

### 🔒 Enhanced Compliance-by-Design™

- **Programmatic Rule 144** - Automated holding periods, volume limits, frequency controls
- **Regulation S Framework** - Geographic restrictions with offshore transfer controls  
- **Enhanced KYC/AML** - Real-time verification with comprehensive audit trails
- **Transfer Blocking** - Explicit compliance violations with detailed reasoning
- **Accredited Investor Verification** - SEC compliance automation with scoring
- **Jurisdiction Mapping** - Fine-grained geographic access controls

### 🏦 Enhanced Proof-of-CSV™ Oracle System

- **2-of-N Signature Consensus** - Configurable threshold with attestor consensus
- **Attestor Slashing** - Stake-based penalty system for bad actors
- **Monotonicity Checks** - Prevent sudden valuation drops and stale data
- **Enhanced Events** - Complete audit trail with full context emission
- **Cryptographic Verification** - Multi-signature validation with bitmap tracking
- **IPFS Integration** - Automated disclosure pinning with on-chain CID updates

### 💰 Advanced Risk Management

- **Carrier Concentration Caps** - Hard 30% limits with real-time monitoring
- **Policy Vintage Gating** - Minimum age requirements for asset backing
- **Pre-mint Validation** - Comprehensive risk checks before token issuance
- **Dynamic LTV Controls** - Automated liquidation triggers and ratchets
- **Emergency Controls** - Circuit breakers with compliance override capabilities

## 🛡️ Security & Risk Management

### Smart Contract Security

- **Multi-Signature Controls** - 3-of-5 multisig for critical functions
- **Time Locks** - 48-hour delay for parameter changes
- **Emergency Pauses** - Circuit breakers for system protection
- **Formal Verification** - Mathematical proof of contract correctness

### Financial Risk Controls

- **Conservative LTV Limits** - Maximum 80% loan-to-value ratios
- **Diversification Rules** - Carrier concentration limits
- **Stress Testing** - Regular scenario analysis and risk assessment
- **Insurance Coverage** - Professional liability and operational risk

## 📈 Market Opportunity

### Total Addressable Market

- **$2.7 Trillion** - Total U.S. insurance CSV assets
- **$150 Billion** - Annual premium payments
- **4-8% Target Yield** - Competitive return profile
- **Institutional Focus** - Professional asset management

### Competitive Advantages

1. **Patent Protection** - Defensible IP in CSV tokenization
2. **Regulatory Compliance** - Built-in securities law automation  
3. **Standards Capture** - ERC-RWA:CSV industry adoption
4. **Technical Superiority** - Working system vs competitor whitepapers
5. **Network Effects** - Ecosystem lock-in through open standards

## 🏛️ Regulatory Compliance

### SEC Engagement

- **Regulatory Sandbox** - Active SEC Innovation Hub participation
- **No-Action Letters** - Proactive regulatory guidance
- **Industry Leadership** - Thought leadership on compliant tokenization

### Legal Framework

- **Regulation D** - 506(c) exemption with general solicitation
- **Rule 144** - Automated holding period compliance
- **Investment Company Act** - Exemption analysis and maintenance
- **State Compliance** - Blue sky law notice filings

## 🎯 Deployment Networks

### Mainnet Deployments
- **Ethereum Mainnet** - Primary deployment
- **Polygon** - Layer 2 scaling solution
- **Arbitrum** - Optimistic rollup implementation

### Testnet Development
- **Sepolia** - Ethereum testnet
- **Mumbai** - Polygon testnet  
- **Arbitrum Goerli** - Arbitrum testnet

## 🔧 Development

### Running Tests

```bash
cd contracts

# Run basic tests
npm run test

# Run enhanced compliance tests
npx hardhat test test/enhanced-compliance.test.js

# Run all tests with coverage
npm run coverage
```

### IPFS Disclosure Management

```bash
# Pin disclosure documents
npx ts-node scripts/pin-disclosure.ts <contract-address> DISCLOSURES.md --verify --save-locally

# View disclosure history
npx ts-node scripts/pin-disclosure.ts <contract-address> DISCLOSURES.md --history
```

### Code Coverage

```bash
cd contracts  
npm run coverage
```

### Gas Analysis

```bash
cd contracts
npm run gas-report
```

## 📚 Documentation

- [Technical Whitepaper](./docs/Whitepaper.md)
- [ERC-RWA:CSV Standard](./specs/erc-rwa-csv.md)
- [Compliance Matrix](./docs/compliance-matrix.md)
- [Regulatory Disclosures](./DISCLOSURES.md)
- [Smart Contract Documentation](./contracts/README.md)
- [Frontend Documentation](./frontend/README.md)
- [API Reference](./docs/API.md)
- [Security Audit Reports](./audits/)

## 🤝 Contributing

We welcome contributions from the community. Please read our [Contributing Guidelines](CONTRIBUTING.md) before submitting pull requests.

### Development Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚖️ Legal Disclaimers

- Securities laws compliance required for all token holders
- Professional legal and tax advice recommended
- Past performance does not guarantee future results
- All investments carry risk of loss

## 🌐 Community & Support

- **Website**: [iyield.protocol](https://iyield.protocol)
- **Documentation**: [docs.iyield.protocol](https://docs.iyield.protocol)
- **Discord**: [discord.gg/iyield](https://discord.gg/iyield)
- **Twitter**: [@iYieldProtocol](https://twitter.com/iYieldProtocol)
- **Telegram**: [t.me/iyieldprotocol](https://t.me/iyieldprotocol)

## 🏆 Recognition & Awards

- **SEC Innovation Hub** - Regulatory Sandbox Participant  
- **DeFi Pulse** - Featured Protocol
- **ConsenSys** - Security Audit Partner
- **Insurance Innovation** - Industry Recognition

---

**⚠️ Important Notice**: iYield tokens constitute securities under U.S. law. This offering is limited to accredited investors only. Please consult with qualified legal and financial professionals before participating.

**Patent Pending**: Core tokenization and oracle technologies are patent-pending. International trademark registration in progress for iYield™, Proof-of-CSV™, and Compliance-by-Design™.

**Built with ❤️ by the iYield Protocol Team**

*Unlocking the future of insurance asset tokenization through compliance innovation and technical excellence.*