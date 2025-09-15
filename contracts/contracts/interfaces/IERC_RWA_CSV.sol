// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IERC_RWA_CSV Interface
 * @dev Interface for ERC-RWA:CSV - Real World Asset Token Standard for Insurance-Backed Securities
 */
interface IERC_RWA_CSV {
    // Events
    event ValuationUpdated(bytes32 indexed merkleRoot, uint256 newValuation, uint256 timestamp);
    event ComplianceStatusChanged(address indexed account, bool compliant);
    event TransferRestricted(address indexed from, address indexed to, string reason);
    event LTVRatioUpdated(uint256 newRatio, uint256 maxRatio);
    event Rule144LockupSet(address indexed account, uint256 unlockTimestamp);
    
    // Compliance Functions
    function isCompliantTransfer(address from, address to, uint256 amount) external view returns (bool);
    function setComplianceStatus(address account, bool status) external;
    function getJurisdictionRestrictions(address account) external view returns (string[] memory);
    function setRule144Lockup(address account, uint256 unlockTimestamp) external;
    
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
    
    function getLatestValuation() external view returns (ValuationData memory);
    function submitValuation(uint256 csv, bytes32 merkleRoot, bytes calldata signature) external;
    function verifyAttestor(address attestor) external view returns (bool);
    function getMinAttestors() external view returns (uint256);
    function getCarrierData(bytes32 carrierId) external view returns (CarrierData memory);
    function updateCarrierRating(bytes32 carrierId, uint256 newRating) external;
}