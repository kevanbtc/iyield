// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ICSVOracle
 * @dev Interface for Proof-of-CSV™ oracle system
 */
interface ICSVOracle {
    
    struct CSVData {
        uint256 value;
        uint256 timestamp;
        bytes32 merkleRoot;
        string ipfsHash;
        bool isActive;
    }
    
    struct Attestation {
        address attestor;
        bytes signature;
        uint256 timestamp;
        bytes32 dataHash;
    }
    
    // Events
    event CSVValueUpdated(string indexed policyId, uint256 value, uint256 timestamp);
    event AttestationAdded(string indexed policyId, address indexed attestor, bytes32 dataHash);
    event MerkleRootUpdated(bytes32 indexed oldRoot, bytes32 indexed newRoot);
    event IPFSHashUpdated(string indexed oldHash, string indexed newHash);
    event AttestorAdded(address indexed attestor);
    event AttestorRemoved(address indexed attestor);
    
    // Oracle data access
    function getCSVValue(string memory policyId) external view returns (uint256 value, uint256 timestamp);
    function getCSVData(string memory policyId) external view returns (CSVData memory);
    function isDataFresh(string memory policyId, uint256 maxAge) external view returns (bool);
    
    // Attestation management
    function addAttestation(
        string memory policyId,
        uint256 value,
        bytes32 merkleRoot,
        string memory ipfsHash,
        bytes memory signature
    ) external;
    
    function verifyAttestation(
        string memory policyId,
        address attestor,
        bytes memory signature
    ) external view returns (bool);
    
    // Merkle proof verification
    function verifyMerkleProof(
        bytes32[] memory proof,
        bytes32 leaf,
        bytes32 root
    ) external pure returns (bool);
    
    // Attestor management
    function addAttestor(address attestor) external;
    function removeAttestor(address attestor) external;
    function isAttestor(address attestor) external view returns (bool);
    
    // IPFS integration
    function updateIPFSHash(string memory newHash) external;
    function getCurrentIPFSHash() external view returns (string memory);
    
    // Data staleness
    function setMaxStaleness(uint256 maxAge) external;
    function getMaxStaleness() external view returns (uint256);
}