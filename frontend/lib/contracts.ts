// Contract addresses (will be populated after deployment)
export const CONTRACT_ADDRESSES = {
  CSV_ORACLE: process.env.NEXT_PUBLIC_CSV_ORACLE_ADDRESS || '',
  COMPLIANCE_ENGINE: process.env.NEXT_PUBLIC_COMPLIANCE_ENGINE_ADDRESS || '',
  IYIELD_TOKEN: process.env.NEXT_PUBLIC_IYIELD_TOKEN_ADDRESS || '',
};

// ABI definitions for frontend integration
export const IYIELD_TOKEN_ABI = [
  "function totalSupply() view returns (uint256)",
  "function navPerToken() view returns (uint256)",
  "function totalCsvValue() view returns (uint256)",
  "function getSystemStatus() view returns (uint256, uint256, uint256, uint256, uint256)",
  "function getPolicyLTV(bytes32 policyId) view returns (uint256)",
  "function disclosureHashes(uint256 epoch) view returns (string)",
  "function currentEpoch() view returns (uint256)",
  "event NAVUpdated(uint256 newNav, uint256 totalCsv, uint256 totalSupply)",
  "event PolicyAdded(bytes32 indexed policyId, uint256 csvValue, uint256 tokensIssued)",
  "event PolicyUpdated(bytes32 indexed policyId, uint256 newCsvValue, uint256 oldCsvValue)",
  "event DisclosurePublished(uint256 indexed epoch, string ipfsHash, bytes32 stateHash)"
];

export const CSV_ORACLE_ABI = [
  "function getAttestation(bytes32 policyId) view returns (tuple(bytes32 policyId, uint256 csvValue, uint256 timestamp, string ipfsHash, bytes32 merkleRoot, address attester, bytes signature))",
  "function isStale(bytes32 policyId, uint256 maxAge) view returns (bool)",
  "function getMultipleAttestations(bytes32[] policyIds) view returns (tuple(bytes32 policyId, uint256 csvValue, uint256 timestamp, string ipfsHash, bytes32 merkleRoot, address attester, bytes signature)[])",
  "event AttestationUpdated(bytes32 indexed policyId, uint256 csvValue, string ipfsHash, bytes32 merkleRoot)"
];

export const COMPLIANCE_ENGINE_ABI = [
  "function getCompliance(address investor) view returns (tuple(uint8 investorType, uint256 kycTimestamp, uint256 accreditationExpiry, bool isWhitelisted, uint8 restriction, uint256 restrictionParam))",
  "function canTransfer(address from, address to, uint256 amount) view returns (bool, string)",
  "function isAccredited(address investor) view returns (bool)",
  "function getComplianceStatus(address investor) view returns (bool, bool, bool, bool, uint256, uint256, string)",
  "event ComplianceUpdated(address indexed investor, uint8 investorType)",
  "event WhitelistUpdated(address indexed investor, bool status)"
];

// Network configuration
export const SUPPORTED_NETWORKS = {
  1: 'Ethereum Mainnet',
  5: 'Goerli Testnet',
  11155111: 'Sepolia Testnet',
  31337: 'Hardhat Local'
};

export const RPC_URLS = {
  1: 'https://mainnet.infura.io/v3/YOUR_INFURA_KEY',
  5: 'https://goerli.infura.io/v3/YOUR_INFURA_KEY', 
  11155111: 'https://sepolia.infura.io/v3/YOUR_INFURA_KEY',
  31337: 'http://localhost:8545'
};