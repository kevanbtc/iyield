# iYield Protocol Smart Contracts

This directory contains the core smart contracts for the iYield Protocol - the first comprehensive platform for tokenizing insurance cash surrender values (CSV) with built-in regulatory compliance.

## 🏗️ Architecture

### Core Contracts

- **`core/ERCRWACSV.sol`** - ERC-20 token representing tokenized insurance cash surrender values with built-in compliance features
- **`core/CSVVault.sol`** - Handles collateralized issuance and burn-on-redeem functionality
- **`core/CSVLiquidityPool.sol`** - Senior/junior tranche yield distribution system

### Compliance System

- **`compliance/ComplianceRegistry.sol`** - KYC/AML and jurisdiction management with automated verification

### Oracle System

- **`oracles/CSVOracle.sol`** - Proof-of-CSV™ multi-attestor system for insurance valuation with cryptographic verification

## 🚀 Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn

### Installation

```bash
# Install dependencies
npm install

# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test

# Deploy to local network
npx hardhat run scripts/deploy.js

# Deploy to testnet
npx hardhat run scripts/deploy.js --network sepolia
```

### Testing

```bash
# Run all tests
npm run test

# Run with gas reporting
npm run gas-report

# Generate coverage report
npm run coverage
```

## 🔧 Development

### Compiling Contracts

```bash
npm run compile
```

### Running Tests

```bash
npm run test
```

### Local Development

1. Start a local Hardhat network:
```bash
npx hardhat node
```

2. Deploy contracts to local network:
```bash
npm run deploy:local
```

3. The deployment addresses will be saved to `deployments/localhost-deployment.json`

## 🛡️ Security Features

- **Multi-signature controls** for critical functions
- **Time locks** for parameter changes
- **Emergency pauses** with circuit breakers
- **Reentrancy protection** on all state-changing functions
- **Access control** with role-based permissions

## 📊 Contract Features

### ERC-RWA:CSV Token
- Compliance-integrated transfers
- Automated KYC/AML verification
- Rule 144 lockup enforcement
- Geographic access controls

### CSV Vault System
- Collateralized token issuance
- Burn-on-redeem functionality
- Automated liquidation protection

### Liquidity Pool
- Senior/junior tranching
- Waterfall yield distribution
- Risk-adjusted returns

### Oracle System
- Multi-party attestation (2-of-3 consensus)
- Cryptographic verification via Merkle proofs
- Real-time carrier credit rating
- IPFS transparency and audit trails

## 🌐 Deployment Networks

### Mainnet
- Ethereum Mainnet (Primary)
- Polygon (Layer 2 scaling)
- Arbitrum (Optimistic rollup)

### Testnet
- Sepolia (Ethereum testnet)
- Mumbai (Polygon testnet)
- Arbitrum Goerli (Arbitrum testnet)

## 📚 Documentation

- [Technical Whitepaper](../docs/Whitepaper.md)
- [API Reference](../docs/API.md)
- [Security Audit Reports](../audits/)

## 🤝 Contributing

Please read the main [Contributing Guidelines](../CONTRIBUTING.md) before submitting pull requests.

## 📄 License

MIT License - see [LICENSE](../LICENSE) file for details.