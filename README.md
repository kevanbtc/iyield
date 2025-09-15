# iYield Protocol

A comprehensive DeFi protocol that provides yield farming, liquidity provision, and asset management with built-in compliance features. The protocol enables users to earn yield on their digital assets while maintaining regulatory compliance through integrated KYC/AML verification.

## 🏗 Architecture

The iYield protocol consists of five main smart contracts:

### Core Contracts

1. **ComplianceRegistry** - Manages KYC/AML verification and compliance levels
2. **iYieldToken** - ERC20 token with yield generation and compliance integration  
3. **OracleAdapter** - Price feed management and oracle integration
4. **Vault** - Multi-asset vault for yield generation and asset management
5. **LiquidityPool** - AMM-style liquidity pool for token swaps

## 📁 Project Structure

```
iYield-Protocol/
├── contracts/
│   ├── ComplianceRegistry.sol    # KYC/AML compliance management
│   ├── iYieldToken.sol          # Yield-generating ERC20 token
│   ├── OracleAdapter.sol        # Price feed and oracle management
│   ├── Vault.sol                # Multi-asset yield vault
│   └── LiquidityPool.sol        # AMM liquidity pool
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
├── hardhat.config.js            # Hardhat configuration
├── package.json                 # Dependencies and scripts
└── README.md                    # This file
```

## 🚀 Getting Started

### Prerequisites

- Node.js (v16 or higher)
- npm or yarn
- Git

### Installation

1. Clone the repository:
```bash
git clone https://github.com/kevanbtc/iyield.git
cd iyield
```

2. Install dependencies:
```bash
npm install
```

3. Compile contracts:
```bash
npm run compile
```

### Testing

Run the comprehensive test suite:
```bash
npm test
```

For test coverage:
```bash
npm run test:coverage
```

### Deployment

Deploy to local hardhat network:
```bash
# Start local node
npm run node

# Deploy contracts (in another terminal)
npm run deploy:localhost
```

## 📖 Contract Details

### ComplianceRegistry

Manages user compliance and KYC/AML verification with the following features:

- **Multi-level compliance**: Basic, Intermediate, Advanced, Institutional
- **Jurisdiction management**: Support for multiple regulatory jurisdictions
- **Risk scoring**: 0-100 risk assessment for each user
- **Batch operations**: Efficient bulk compliance updates
- **Expiration tracking**: Time-based compliance validity

**Key Functions:**
- `setComplianceStatus()` - Update user compliance
- `isCompliant()` - Check if user meets compliance requirements
- `batchUpdateCompliance()` - Update multiple users efficiently

### iYieldToken

ERC20 token with integrated yield generation and compliance checks:

- **Automatic yield**: Configurable APY based on compliance level
- **Compliance integration**: Blocks transfers for non-compliant users
- **Yield multipliers**: Higher yields for advanced compliance levels
- **Pausable**: Emergency pause functionality
- **Burnable**: Token burning capability

**Yield Features:**
- Base yield rate (configurable APY)
- Compliance level multipliers (1x to 1.5x)
- Minimum balance requirements
- Automatic yield accrual and claiming

### OracleAdapter

Centralized price feed management with multiple oracle support:

- **Multi-feed support**: Aggregate multiple price sources
- **Staleness protection**: Automatic detection of stale prices
- **Emergency mode**: Manual price override capability
- **Deviation limits**: Prevent price manipulation
- **Feed management**: Add/remove/configure price feeds

**Price Features:**
- Real-time price updates
- Historical price tracking
- Multi-precision support (different decimal places)
- Batch price updates

### Vault

Multi-asset yield vault with strategy management:

- **Multi-asset support**: Deposit multiple token types
- **Strategy integration**: Pluggable yield strategies
- **Fee management**: Configurable management and performance fees
- **Share-based accounting**: Proportional ownership tracking
- **Withdrawal controls**: Minimum amounts and fee structures

**Vault Features:**
- Automated yield harvesting
- Risk-adjusted allocations
- Compliance-gated access
- Emergency withdrawal capabilities

### LiquidityPool

AMM-style liquidity pool for token swaps:

- **Constant product formula**: x * y = k pricing model
- **LP token rewards**: Fee sharing for liquidity providers
- **Price impact protection**: Limits on large trades
- **Slippage protection**: Minimum output guarantees
- **Fee customization**: Configurable trading fees

**Trading Features:**
- Automated market making
- Liquidity mining rewards
- Price impact calculations
- Historical trade tracking

## 🔐 Security Features

- **Reentrancy protection**: All external calls protected
- **Access control**: Role-based permissions
- **Pausable contracts**: Emergency pause functionality
- **Compliance integration**: KYC/AML requirement enforcement
- **Input validation**: Comprehensive parameter checking
- **Overflow protection**: SafeMath implementation

## 📊 Governance & Fees

### Fee Structure
- **Management Fee**: 2% annually (configurable)
- **Performance Fee**: 10% of profits (configurable)
- **Trading Fee**: 0.3% per swap (configurable)
- **Withdrawal Fee**: 0.5% (configurable)

### Yield Rates
- **Base APY**: 5% (configurable)
- **Compliance Multipliers**:
  - Basic: 1.0x
  - Intermediate: 1.1x
  - Advanced: 1.2x  
  - Institutional: 1.5x

## 🛠 Development

### Available Scripts

- `npm run compile` - Compile smart contracts
- `npm run test` - Run test suite
- `npm run test:coverage` - Generate coverage report
- `npm run deploy` - Deploy to configured network
- `npm run node` - Start local Hardhat node
- `npm run clean` - Clean artifacts and cache

### Testing

The project includes comprehensive tests covering:

- Unit tests for all contract functions
- Integration tests for cross-contract interactions
- Edge case handling
- Access control verification
- Event emission testing
- Gas optimization validation

## 🌐 Network Support

The protocol is designed to work on:

- Ethereum Mainnet
- Ethereum Testnets (Goerli, Sepolia)
- Local Hardhat Network
- Other EVM-compatible chains

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## 🔗 Links

- [Documentation](https://github.com/kevanbtc/iyield/wiki)
- [Issues](https://github.com/kevanbtc/iyield/issues)
- [Pull Requests](https://github.com/kevanbtc/iyield/pulls)

## ⚠️ Disclaimer

This software is provided "as is", without warranty of any kind. Use at your own risk. The smart contracts have not been audited and should not be used with real funds without proper security review.