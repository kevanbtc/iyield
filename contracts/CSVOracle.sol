// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./interfaces/ICSVOracle.sol";

/**
 * @title CSVOracle
 * @dev Oracle system for Cash Surrender Value attestations with IPFS proofs
 * 
 * PATENT CLAIMS:
 * - System and method for on-chain enforceable insurance-backed securities using decentralized attestation proofs
 * - Combining off-chain policy oracle attestations with on-chain compliance verification
 * - IPFS-based provenance trail for regulatory transparency
 * 
 * Trademark: "Proof-of-CSV™" for oracle attestation framework
 */
contract CSVOracle is ICSVOracle, AccessControl {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    
    bytes32 public constant ATTESTER_ROLE = keccak256("ATTESTER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    mapping(bytes32 => PolicyAttestation) private attestations;
    mapping(string => CarrierRating) private carrierRatings;
    mapping(address => bool) public authorizedAttesters;
    
    uint256 public constant MAX_DATA_AGE = 24 hours;
    
    event AttesterAuthorized(address indexed attester, bool status);
    
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
    }
    
    /**
     * @dev Update policy attestation with signature verification (Proof-of-CSV™)
     */
    function updateAttestation(PolicyAttestation calldata attestation) external override {
        require(hasRole(ATTESTER_ROLE, msg.sender) || authorizedAttesters[msg.sender], "Unauthorized attester");
        require(attestation.csvValue > 0, "CSV value must be positive");
        require(bytes(attestation.ipfsHash).length > 0, "IPFS hash required");
        
        // Verify signature for attestation integrity
        bytes32 messageHash = keccak256(abi.encodePacked(
            attestation.policyId,
            attestation.csvValue,
            attestation.timestamp,
            attestation.ipfsHash,
            attestation.merkleRoot
        )).toEthSignedMessageHash();
        
        address signer = messageHash.recover(attestation.signature);
        require(signer == attestation.attester, "Invalid signature");
        require(hasRole(ATTESTER_ROLE, signer) || authorizedAttesters[signer], "Signer not authorized");
        
        // Store attestation with IPFS provenance
        attestations[attestation.policyId] = attestation;
        
        emit AttestationUpdated(
            attestation.policyId,
            attestation.csvValue,
            attestation.ipfsHash,
            attestation.merkleRoot
        );
    }
    
    /**
     * @dev Get policy attestation data
     */
    function getAttestation(bytes32 policyId) external view override returns (PolicyAttestation memory) {
        return attestations[policyId];
    }
    
    /**
     * @dev Check if attestation data is stale (critical for LTV calculations)
     */
    function isStale(bytes32 policyId, uint256 maxAge) external view override returns (bool) {
        PolicyAttestation memory attestation = attestations[policyId];
        if (attestation.timestamp == 0) return true; // No attestation exists
        return block.timestamp - attestation.timestamp > maxAge;
    }
    
    /**
     * @dev Verify Merkle proof for attestation data integrity
     */
    function verifyMerkleProof(
        bytes32 policyId,
        bytes32[] calldata proof,
        bytes32 leaf
    ) external view override returns (bool) {
        PolicyAttestation memory attestation = attestations[policyId];
        require(attestation.merkleRoot != bytes32(0), "No merkle root for policy");
        
        return _verifyMerkleProof(proof, attestation.merkleRoot, leaf);
    }
    
    /**
     * @dev Update insurance carrier rating
     */
    function updateCarrierRating(CarrierRating calldata rating) external override onlyRole(ATTESTER_ROLE) {
        require(bytes(rating.carrierName).length > 0, "Carrier name required");
        require(rating.rating > 0 && rating.rating <= 15, "Invalid rating range");
        require(bytes(rating.ipfsProof).length > 0, "IPFS proof required");
        
        carrierRatings[rating.carrierName] = rating;
        
        emit CarrierRatingUpdated(rating.carrierName, rating.rating, rating.ipfsProof);
    }
    
    /**
     * @dev Get carrier rating information
     */
    function getCarrierRating(string calldata carrierName) external view override returns (CarrierRating memory) {
        return carrierRatings[carrierName];
    }
    
    /**
     * @dev Authorize/deauthorize attester
     */
    function setAttesterStatus(address attester, bool status) external onlyRole(ADMIN_ROLE) {
        authorizedAttesters[attester] = status;
        emit AttesterAuthorized(attester, status);
    }
    
    /**
     * @dev Internal Merkle proof verification (patent-pending cryptographic verification)
     */
    function _verifyMerkleProof(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        bytes32 computedHash = leaf;
        
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
            } else {
                computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
            }
        }
        
        return computedHash == root;
    }
    
    /**
     * @dev Get multiple attestations (batch query for efficiency)
     */
    function getMultipleAttestations(bytes32[] calldata policyIds) 
        external view returns (PolicyAttestation[] memory) {
        PolicyAttestation[] memory results = new PolicyAttestation[](policyIds.length);
        
        for (uint256 i = 0; i < policyIds.length; i++) {
            results[i] = attestations[policyIds[i]];
        }
        
        return results;
    }
    
    /**
     * @dev Check if multiple attestations are fresh
     */
    function areAttestationsFresh(bytes32[] calldata policyIds, uint256 maxAge) 
        external view returns (bool[] memory) {
        bool[] memory results = new bool[](policyIds.length);
        
        for (uint256 i = 0; i < policyIds.length; i++) {
            PolicyAttestation memory attestation = attestations[policyIds[i]];
            results[i] = attestation.timestamp != 0 && 
                        (block.timestamp - attestation.timestamp <= maxAge);
        }
        
        return results;
    }
}