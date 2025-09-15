// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ICSVOracle
 * @dev Interface for Cash Surrender Value Oracle with attestations
 * Patent-pending: "System and method for on-chain enforceable insurance-backed securities 
 * using decentralized attestation proofs"
 */
interface ICSVOracle {
    struct PolicyAttestation {
        bytes32 policyId;
        uint256 csvValue;
        uint256 timestamp;
        string ipfsHash; // IPFS hash of full policy documentation
        bytes32 merkleRoot; // Root of attestation Merkle tree
        address attester;
        bytes signature;
    }
    
    struct CarrierRating {
        string carrierName;
        uint8 rating; // A.M. Best rating (1-15 scale)
        uint256 timestamp;
        string ipfsProof;
    }
    
    event AttestationUpdated(
        bytes32 indexed policyId,
        uint256 csvValue,
        string ipfsHash,
        bytes32 merkleRoot
    );
    
    event CarrierRatingUpdated(
        string indexed carrierName,
        uint8 rating,
        string ipfsProof
    );
    
    function updateAttestation(PolicyAttestation calldata attestation) external;
    function getAttestation(bytes32 policyId) external view returns (PolicyAttestation memory);
    function isStale(bytes32 policyId, uint256 maxAge) external view returns (bool);
    function verifyMerkleProof(bytes32 policyId, bytes32[] calldata proof, bytes32 leaf) external view returns (bool);
    function updateCarrierRating(CarrierRating calldata rating) external;
    function getCarrierRating(string calldata carrierName) external view returns (CarrierRating memory);
}