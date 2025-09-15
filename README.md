# iYield Protocol

A decentralized yield farming protocol with built-in compliance features and CSV (Cash Surrender Value) oracle integration.

## 🚀 Features

- **Compliance Registry**: KYC/AML whitelist management for regulatory compliance
- **iYield Token**: ERC20 token with compliance-gated transfers and controlled minting
- **Oracle Adapter**: CSV data feeds for real-time policy value tracking
- **Vault System**: Collateralized token minting based on CSV values
- **Liquidity Pool**: Yield distribution and liquidity management

## 📂 Project Structure

```
iYield-Protocol/
├── contracts/
│   ├── ComplianceRegistry.sol    # KYC/AML compliance management
│   ├── iYieldToken.sol          # Main protocol token with compliance
│   ├── OracleAdapter.sol        # CSV oracle data adapter
│   ├── Vault.sol                # Core vault for deposits/withdrawals
│   └── LiquidityPool.sol        # Liquidity and yield management
│
├── scripts/
│   └── deploy.js                # Deployment script
│
├── test/
│   ├── ComplianceRegistry.test.js
│   ├── iYieldToken.test.js
│   ├── Vault.test.js
│   └── LiquidityPool.test.js
│
├── hardhat.config.js
├── package.json
└── README.md
```

## 🛠️ Setup Instructions

### 1. Clone and Install

```bash
git clone https://github.com/kevanbtc/iyield.git
cd iyield
npm install
```

### 2. Compile Contracts

```bash
npm run compile
```

### 3. Run Tests

```bash
npm run test
```

### 4. Local Development

Start a local Hardhat network:

```bash
npm run node
```

Deploy to local network:

```bash
npm run deploy
```

### 5. Deploy to Sepolia

Set up environment variables:

```bash
export SEPOLIA_RPC_URL="your_sepolia_rpc_url"
export PRIVATE_KEY="your_private_key"
export ETHERSCAN_API_KEY="your_etherscan_api_key"
```

Deploy:

```bash
npm run deploy:sepolia
```

## 📋 Smart Contracts

### ComplianceRegistry
- Manages KYC/AML whitelist
- Controls user access levels
- Owner-controlled compliance updates

### iYieldToken (iYLD)
- ERC20 token with compliance features
- Minting/burning controls
- Transfer restrictions to whitelisted addresses only

### OracleAdapter
- CSV data feed management
- Mock oracle for testing (integrate with Chainlink for production)
- Staleness protection

### Vault
- Core deposit/withdrawal mechanism
- Collateralized token minting based on CSV values
- Configurable collateral ratios

### LiquidityPool
- Liquidity provision and management
- Yield distribution system
- Time-based yield calculations

## 🧪 Testing

The project includes comprehensive tests for all contracts:

- **ComplianceRegistry**: Whitelist and KYC level management
- **iYieldToken**: Token operations with compliance checks
- **Vault**: Deposit/withdrawal and collateral management
- **LiquidityPool**: Liquidity operations and yield calculations

Run all tests:

```bash
npm run test
```

## 🔧 Configuration

### Hardhat Networks

- **Hardhat**: Local development network
- **Sepolia**: Ethereum testnet deployment

### Environment Variables

```bash
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/your-project-id
PRIVATE_KEY=your-private-key-here
ETHERSCAN_API_KEY=your-etherscan-api-key
```

## 🚧 Development Roadmap

- [ ] **Chainlink Integration**: Replace mock oracle with real CSV feeds
- [ ] **DAO Governance**: Implement governance for protocol parameters
- [ ] **Yield Strategies**: Advanced yield farming mechanisms
- [ ] **Multi-asset Support**: Support for multiple collateral types
- [ ] **Insurance Module**: Protocol insurance integration
- [ ] **Cross-chain**: Multi-chain deployment support

## 📄 License

MIT License - see LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## ⚠️ Security Notice

This is experimental software. Do not use in production without proper security audits.