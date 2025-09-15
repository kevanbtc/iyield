// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IERC_RWA_CSV Interface
 * @dev Interface for ERC-RWA:CSV - Real World Asset Token Standard for Insurance-Backed Securities
 */
interface IERC_RWA_CSV {
    // Enhanced Events
    event ValuationUpdated(bytes32 indexed merkleRoot, uint256 newValuation, uint256 timestamp);
    event ComplianceStatusChanged(address indexed account, bool compliant);
    event TransferRestricted(address indexed from, address indexed to, string reason);
    event TransferBlocked(address indexed from, address indexed to, uint256 amount, string reason);
    event LTVRatioUpdated(uint256 newRatio, uint256 maxRatio);
    event Rule144LockupSet(address indexed account, uint256 unlockTimestamp);
    event RegSTransferAttempted(address indexed from, address indexed to, string jurisdiction);
    event Rule144StatusChanged(address indexed account, uint256 oldLockup, uint256 newLockup);
    event ComplianceOverride(address indexed account, string reason, address indexed admin);
    
    // Compliance Functions
    function isCompliantTransfer(address from, address to, uint256 amount) external view returns (bool);
    function setComplianceStatus(address account, bool status) external;
    function getJurisdictionRestrictions(address account) external view returns (string[] memory);
    function setRule144Lockup(address account, uint256 unlockTimestamp) external;
    
    // Enhanced Rule 144 Functions
    function getRule144Status(address account) external view returns (uint256 unlockTime, bool isRestricted);
    function checkRule144Compliance(address from, uint256 amount) external view returns (bool allowed, string memory reason);
    
    // Regulation S Functions  
    function checkRegSCompliance(address from, address to) external view returns (bool allowed, string memory reason);
    function setRegSRestriction(address account, bool restricted) external;
    function isRegSRestricted(address account) external view returns (bool);
    
    // Enhanced Compliance Views
    function getComplianceDetails(address account) external view returns (
        bool isKYCVerified,
        bool isAccredited,
        string memory jurisdiction,
        uint256 rule144Lockup,
        bool regSRestricted,
        uint256 complianceScore
    );
    function canTransfer(address from, address to, uint256 amount) external view returns (
        bool allowed, 
        string memory reason,
        uint256 complianceFlags
    );
    
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

/**
 * @title IComplianceRegistry Interface
 * @dev Interface for compliance and KYC verification registry
 */
interface IComplianceRegistry {
    function isKYCVerified(address account) external view returns (bool);
    function getJurisdiction(address account) external view returns (string memory);
    function isAccreditedInvestor(address account) external view returns (bool);
    function getRule144Lockup(address account) external view returns (uint256);
    function setKYCStatus(address account, bool status) external;
    function setJurisdiction(address account, string memory jurisdiction) external;
    function setAccreditedStatus(address account, bool status) external;
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
    }
    
    struct CarrierData {
        string name;
        uint256 rating; // 1-1000 (AAA=1000, D=1)
        uint256 lastUpdated;
        bool isActive;
    }
    
    struct PolicyData {
        bytes32 policyId;
        uint256 csvValue;
        uint256 vintage; // Policy inception timestamp
        string carrierName;
        uint256 lastValuation;
        bool isActive;
    }
    
    function getLatestValuation() external view returns (ValuationData memory);
    function submitValuation(uint256 csv, bytes32 merkleRoot, bytes calldata signature) external;
    function verifyAttestor(address attestor) external view returns (bool);
    function getMinAttestors() external view returns (uint256);
    function getCarrierData(bytes32 carrierId) external view returns (CarrierData memory);
    function updateCarrierRating(bytes32 carrierId, uint256 newRating) external;
    function getPolicy(bytes32 policyId) external view returns (PolicyData memory);
    function getAttestorThreshold() external view returns (uint256 required, uint256 total);
    function isValuationStale() external view returns (bool);
    
    // Enhanced events
    event AttestorStatusChanged(address indexed attestor, bool trusted);
}