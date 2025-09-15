# iYield Protocol API Reference

This document provides comprehensive API documentation for the iYield Protocol smart contracts and frontend interfaces.

## Smart Contract APIs

### ERCRWACSV Token Contract

The core ERC-RWA:CSV token contract implementing the insurance cash surrender value tokenization standard.

**Contract Address**: `0x...` (See deployment documentation)

#### Core Functions

##### `mintCSVToken(address to, uint256 amount, CSVMetadata memory metadata)`

Mints new CSV-backed tokens.

**Parameters**:
- `to`: Address to mint tokens to
- `amount`: Amount of tokens to mint
- `metadata`: CSV policy metadata

**Returns**: None

**Events**: `CSVTokenMinted(uint256 indexed tokenId, address indexed to, uint256 csvValue)`

**Access**: `MINTER_ROLE` required

**Example**:
```solidity
CSVMetadata memory metadata = CSVMetadata({
    policyNumber: "POL-123456",
    carrierName: "MetLife Inc.",
    cashValue: 50000e18,
    deathBenefit: 250000e18,
    premiumAmount: 2000e18,
    policyAge: 120,
    creditRating: 5,
    lastValuationTimestamp: block.timestamp,
    isActive: true
});

csvToken.mintCSVToken(user, 40000e18, metadata);
```

##### `burnCSVToken(address from, uint256 amount, uint256 tokenId)`

Burns CSV-backed tokens on policy redemption.

**Parameters**:
- `from`: Address to burn tokens from
- `amount`: Amount of tokens to burn
- `tokenId`: Associated token ID

**Access**: `BURNER_ROLE` required

##### `updateCSVValuation(uint256 tokenId, uint256 newValue)`

Updates CSV valuation via oracle.

**Parameters**:
- `tokenId`: Token ID to update
- `newValue`: New CSV value

**Access**: `ORACLE_ROLE` required

##### `updateCompliance(address account, ComplianceData memory complianceData)`

Updates compliance status for an account.

**Parameters**:
- `account`: Account to update
- `complianceData`: New compliance data

**Access**: `COMPLIANCE_ROLE` required

#### View Functions

##### `getCSVMetadata(uint256 tokenId) returns (CSVMetadata memory)`

Returns CSV metadata for a token.

##### `getComplianceData(address account) returns (ComplianceData memory)`

Returns compliance data for an account.

##### `isTransferAllowed(address from, address to) returns (bool, string memory)`

Checks if transfer is allowed between addresses.

### CSVVault Contract

Manages collateralized vaults for CSV token issuance.

#### Core Functions

##### `openVault(uint256 tokenId, uint256 collateralValue) returns (uint256 vaultId)`

Opens a new vault position.

**Parameters**:
- `tokenId`: CSV token ID to use as collateral
- `collateralValue`: Value of collateral

**Returns**: New vault ID

**Example**:
```solidity
uint256 vaultId = csvVault.openVault(1, 50000e18);
```

##### `mintTokens(uint256 vaultId, uint256 amount)`

Mints tokens against vault collateral.

**Parameters**:
- `vaultId`: Vault to mint against
- `amount`: Amount to mint

##### `burnTokens(uint256 vaultId, uint256 amount)`

Burns tokens to reduce vault debt.

##### `closeVault(uint256 vaultId)`

Closes vault and withdraws collateral.

#### View Functions

##### `getVaultPosition(uint256 vaultId) returns (VaultPosition memory)`

Returns vault position details.

##### `getVaultLTV(uint256 vaultId) returns (uint256)`

Returns current loan-to-value ratio.

##### `isLiquidatable(uint256 vaultId) returns (bool)`

Checks if vault can be liquidated.

### CSVLiquidityPool Contract

Manages senior/junior tranche liquidity pools.

#### Core Functions

##### `deposit(TrancheType tranche, uint256 amount)`

Deposits into a tranche.

**Parameters**:
- `tranche`: TrancheType.SENIOR or TrancheType.JUNIOR
- `amount`: Amount to deposit

##### `withdraw(TrancheType tranche, uint256 shares)`

Withdraws from a tranche.

##### `distributeYield(uint256 totalYield)`

Distributes yield following waterfall structure.

**Access**: `YIELD_DISTRIBUTOR_ROLE` required

#### View Functions

##### `getUserPosition(TrancheType tranche, address user)`

Returns user's position in a tranche.

##### `getTrancheInfo(TrancheType tranche)`

Returns tranche information.

##### `getPoolUtilization() returns (uint256)`

Returns current pool utilization percentage.

### ComplianceRegistry Contract

Manages KYC/AML and regulatory compliance.

#### Core Functions

##### `updateKYCStatus(address user, bool isVerified, string memory kycHash, uint256 jurisdictionCode, bytes32 nonce)`

Updates KYC status for a user.

**Access**: `KYC_PROVIDER_ROLE` required

##### `updateAccreditationStatus(address user, bool isAccredited, uint256 customExpiry)`

Updates accredited investor status.

**Access**: `COMPLIANCE_OFFICER_ROLE` required

##### `restrictUser(address user, string memory reason)`

Restricts user access.

##### `registerJurisdiction(uint256 code, string memory countryCode, ...)`

Registers a new jurisdiction.

#### View Functions

##### `getComplianceStatus(address user) returns (ComplianceStatus memory)`

Returns compliance status for a user.

##### `isCompliant(address user) returns (bool)`

Checks if user is compliant.

##### `isTransferAllowed(address from, address to) returns (bool, string memory)`

Checks if transfer is allowed.

### CSVOracle Contract

Manages Proof-of-CSV™ oracle system.

#### Core Functions

##### `registerOracle(string memory name, string memory endpoint, uint256 stakingAmount)`

Registers as an oracle.

**Payment**: Must send staking amount in ETH

##### `requestValuation(string memory policyNumber, uint256 deadline, string memory ipfsHash) returns (uint256 requestId)`

Requests CSV valuation.

**Payment**: Must send request fee

##### `submitValuation(uint256 requestId, uint256 value, bytes32 proofHash, string memory documentationURI)`

Submits oracle valuation.

**Access**: `ORACLE_ROLE` required

#### View Functions

##### `getValuationRequest(uint256 requestId) returns (ValuationRequest memory)`

Returns valuation request details.

##### `getLatestValuation(string memory policyNumber) returns (uint256, bool)`

Returns latest valuation for a policy.

## Frontend APIs

### React Components

#### `DashboardPage`

Main dashboard component displaying protocol statistics.

**Props**: None

**Usage**:
```tsx
import DashboardPage from './app/dashboard/page'

<DashboardPage />
```

#### `CompliancePage`

Compliance management interface.

#### `LiquidityPage`

Liquidity pool management interface.

#### `RiskPage`

Risk monitoring dashboard.

### Custom Hooks

#### `useContractRead`

Reads data from smart contracts.

```tsx
const { data, isLoading, error } = useContractRead({
  address: CONTRACT_ADDRESS,
  abi: CONTRACT_ABI,
  functionName: 'functionName',
  args: [arg1, arg2]
})
```

#### `useContractWrite`

Writes data to smart contracts.

```tsx
const { write, isLoading, isSuccess } = useContractWrite({
  address: CONTRACT_ADDRESS,
  abi: CONTRACT_ABI,
  functionName: 'functionName'
})
```

### Utility Functions

#### `formatCurrency(amount: number)`

Formats number as currency.

```tsx
formatCurrency(1234567) // "$1,234,567"
```

#### `getRiskLevel(score: number)`

Returns risk level based on score.

```tsx
getRiskLevel(75) // { level: 'high', label: 'High', color: 'text-orange-600' }
```

## WebSocket APIs

### Real-time Updates

The protocol supports real-time updates via WebSocket connections.

#### Connection

```javascript
const ws = new WebSocket('wss://api.iyield.protocol/ws')
```

#### Event Types

##### `valuation_update`

Fired when CSV valuations are updated.

```json
{
  "event": "valuation_update",
  "data": {
    "tokenId": 1,
    "oldValue": 50000,
    "newValue": 51000,
    "timestamp": 1640995200
  }
}
```

##### `vault_liquidation`

Fired when a vault is liquidated.

```json
{
  "event": "vault_liquidation",
  "data": {
    "vaultId": 123,
    "owner": "0x...",
    "liquidationValue": 45000,
    "penalty": 2250
  }
}
```

##### `compliance_update`

Fired when compliance status changes.

```json
{
  "event": "compliance_update",
  "data": {
    "user": "0x...",
    "kycStatus": true,
    "accreditationStatus": true,
    "expiryDate": 1672531200
  }
}
```

## REST APIs

### Authentication

All API requests require authentication via JWT tokens.

```bash
curl -H "Authorization: Bearer <token>" https://api.iyield.protocol/endpoint
```

### Endpoints

#### GET `/api/v1/stats`

Returns protocol statistics.

**Response**:
```json
{
  "totalValueLocked": 2750000,
  "activeVaults": 156,
  "totalUsers": 89,
  "yieldGenerated": 187500
}
```

#### GET `/api/v1/vaults/{vaultId}`

Returns vault details.

**Response**:
```json
{
  "vaultId": 123,
  "owner": "0x...",
  "collateralValue": 50000,
  "debtAmount": 40000,
  "ltv": 80.0,
  "isActive": true
}
```

#### POST `/api/v1/valuation/request`

Requests CSV valuation.

**Body**:
```json
{
  "policyNumber": "POL-123456",
  "carrierName": "MetLife Inc.",
  "ipfsHash": "QmHash..."
}
```

#### GET `/api/v1/compliance/{address}`

Returns compliance status.

**Response**:
```json
{
  "address": "0x...",
  "isKYCVerified": true,
  "isAccredited": true,
  "jurisdictionCode": 1,
  "lockupExpiry": 1672531200,
  "isRestricted": false
}
```

## Error Codes

### Smart Contract Errors

| Code | Message | Description |
|------|---------|-------------|
| `ERCRWACSV: Account not KYC verified` | User not KYC verified | |
| `ERCRWACSV: Account not accredited` | User not accredited investor | |
| `ERCRWACSV: Account under lockup period` | Transfer during lockup | |
| `CSVVault: Exceeds maximum LTV` | LTV exceeds limit | |
| `CSVOracle: Insufficient fee` | Oracle request fee too low | |
| `ComplianceRegistry: Jurisdiction not allowed` | Restricted jurisdiction | |

### HTTP Error Codes

| Code | Message | Description |
|------|---------|-------------|
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource not found |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server error |

## Rate Limits

### API Rate Limits

- **General APIs**: 1000 requests/hour
- **Oracle APIs**: 100 requests/hour
- **Compliance APIs**: 500 requests/hour

### WebSocket Limits

- **Connections**: 10 per IP
- **Messages**: 1000/hour per connection

## SDKs and Libraries

### JavaScript/TypeScript SDK

```bash
npm install @iyield/protocol-sdk
```

```typescript
import { iYieldSDK } from '@iyield/protocol-sdk'

const sdk = new iYieldSDK({
  rpcUrl: 'https://mainnet.infura.io/v3/...',
  contractAddresses: {
    csvToken: '0x...',
    csvVault: '0x...',
    liquidityPool: '0x...'
  }
})

// Get vault details
const vault = await sdk.getVault(123)

// Check compliance
const isCompliant = await sdk.checkCompliance('0x...')
```

### Python SDK

```bash
pip install iyield-protocol
```

```python
from iyield import Protocol

protocol = Protocol(rpc_url='https://mainnet.infura.io/v3/...')

# Get protocol stats
stats = protocol.get_stats()

# Request valuation
request_id = protocol.request_valuation(
    policy_number='POL-123456',
    carrier='MetLife Inc.'
)
```

## Testing

### Testnet Contracts

| Contract | Sepolia Address |
|----------|-----------------|
| ERCRWACSV | `0x...` |
| CSVVault | `0x...` |
| CSVLiquidityPool | `0x...` |
| ComplianceRegistry | `0x...` |
| CSVOracle | `0x...` |

### Test Data

Use the following test data for development:

```json
{
  "testPolicy": {
    "policyNumber": "TEST-123456",
    "carrierName": "Test Insurance Co.",
    "csvValue": 50000,
    "deathBenefit": 250000
  },
  "testUser": {
    "address": "0x742d35Cc6634C0532925a3b8D96bC18Bb68e3B69",
    "isKYCVerified": true,
    "isAccredited": true
  }
}
```

## Support

For API support and questions:

- **Documentation**: https://docs.iyield.protocol
- **Discord**: https://discord.gg/iyield
- **GitHub Issues**: https://github.com/kevanbtc/iyield/issues
- **Email**: developers@iyield.protocol