// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./interfaces/ICSVOracle.sol";

/**
 * @title CSVOracle
 * @dev Proof-of-CSV™ oracle system for insurance cash surrender values
 * Features:
 * - Multi-attestor consensus mechanism
 * - Merkle proof verification for IPFS data
 * - Stale data protection
 * - Cryptographic signature validation
 * - Emergency override capabilities
 */
contract CSVOracle is ICSVOracle, AccessControl, Pausable {
    using ECDSA for bytes32;
    
    bytes32 public constant ORACLE_UPDATER_ROLE = keccak256("ORACLE_UPDATER_ROLE");
    bytes32 public constant ATTESTOR_MANAGER_ROLE = keccak256("ATTESTOR_MANAGER_ROLE");
    
    // CSV data storage
    mapping(string => CSVData) private _csvData;
    mapping(string => mapping(address => Attestation)) private _attestations;
    mapping(address => bool) private _attestors;
    
    // Oracle configuration
    uint256 public maxStaleness = 24 hours;
    uint256 public minAttestations = 2;
    string public currentIPFSHash;
    bytes32 public currentMerkleRoot;
    
    // Attestor tracking
    address[] public attestorList;
    uint256 public attestorCount;
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_UPDATER_ROLE, msg.sender);
        _grantRole(ATTESTOR_MANAGER_ROLE, msg.sender);
    }
    
    /**
     * @dev Get CSV value and timestamp for a policy
     */
    function getCSVValue(string memory policyId) external view override returns (uint256 value, uint256 timestamp) {
        CSVData memory data = _csvData[policyId];
        require(data.isActive, "Policy data not available");
        
        return (data.value, data.timestamp);
    }
    
    /**
     * @dev Get complete CSV data for a policy
     */
    function getCSVData(string memory policyId) external view override returns (CSVData memory) {
        return _csvData[policyId];
    }
    
    /**
     * @dev Check if data is fresh within specified age
     */
    function isDataFresh(string memory policyId, uint256 maxAge) external view override returns (bool) {
        CSVData memory data = _csvData[policyId];
        return data.isActive && (block.timestamp - data.timestamp <= maxAge);
    }
    
    /**
     * @dev Add attestation for CSV data
     */
    function addAttestation(
        string memory policyId,
        uint256 value,
        bytes32 merkleRoot,
        string memory ipfsHash,
        bytes memory signature
    ) external override onlyRole(ORACLE_UPDATER_ROLE) whenNotPaused {
        require(_attestors[msg.sender], "Not authorized attestor");
        require(value > 0, "Invalid CSV value");
        require(merkleRoot != bytes32(0), "Invalid merkle root");
        require(bytes(ipfsHash).length > 0, "Invalid IPFS hash");
        
        // Verify signature
        bytes32 dataHash = keccak256(abi.encodePacked(policyId, value, merkleRoot, ipfsHash));
        require(verifyAttestation(policyId, msg.sender, signature), "Invalid signature");
        
        // Store attestation
        _attestations[policyId][msg.sender] = Attestation({
            attestor: msg.sender,
            signature: signature,
            timestamp: block.timestamp,
            dataHash: dataHash
        });
        
        // Count valid attestations
        uint256 validAttestations = _countValidAttestations(policyId, value, merkleRoot, ipfsHash);
        
        // Update CSV data if consensus reached
        if (validAttestations >= minAttestations) {
            _csvData[policyId] = CSVData({
                value: value,
                timestamp: block.timestamp,
                merkleRoot: merkleRoot,
                ipfsHash: ipfsHash,
                isActive: true
            });
            
            // Update global IPFS hash and merkle root if needed
            if (keccak256(bytes(currentIPFSHash)) != keccak256(bytes(ipfsHash))) {
                string memory oldHash = currentIPFSHash;
                currentIPFSHash = ipfsHash;
                emit IPFSHashUpdated(oldHash, ipfsHash);
            }
            
            if (currentMerkleRoot != merkleRoot) {
                bytes32 oldRoot = currentMerkleRoot;
                currentMerkleRoot = merkleRoot;
                emit MerkleRootUpdated(oldRoot, merkleRoot);
            }
            
            emit CSVValueUpdated(policyId, value, block.timestamp);
        }
        
        emit AttestationAdded(policyId, msg.sender, dataHash);
    }
    
    /**
     * @dev Verify attestation signature
     */
    function verifyAttestation(
        string memory policyId,
        address attestor,
        bytes memory signature
    ) public view override returns (bool) {
        if (!_attestors[attestor]) return false;
        
        Attestation memory attestation = _attestations[policyId][attestor];
        if (attestation.attestor == address(0)) return false;
        
        bytes32 messageHash = keccak256(abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            attestation.dataHash
        ));
        
        return messageHash.recover(signature) == attestor;
    }
    
    /**
     * @dev Verify Merkle proof for IPFS data
     */
    function verifyMerkleProof(
        bytes32[] memory proof,
        bytes32 leaf,
        bytes32 root
    ) public pure override returns (bool) {
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
     * @dev Add new attestor
     */
    function addAttestor(address attestor) external override onlyRole(ATTESTOR_MANAGER_ROLE) {
        require(attestor != address(0), "Invalid attestor address");
        require(!_attestors[attestor], "Attestor already exists");
        
        _attestors[attestor] = true;
        attestorList.push(attestor);
        attestorCount++;
        
        emit AttestorAdded(attestor);
    }
    
    /**
     * @dev Remove attestor
     */
    function removeAttestor(address attestor) external override onlyRole(ATTESTOR_MANAGER_ROLE) {
        require(_attestors[attestor], "Attestor does not exist");
        
        _attestors[attestor] = false;
        
        // Remove from list
        for (uint256 i = 0; i < attestorList.length; i++) {
            if (attestorList[i] == attestor) {
                attestorList[i] = attestorList[attestorList.length - 1];
                attestorList.pop();
                break;
            }
        }
        
        attestorCount--;
        
        emit AttestorRemoved(attestor);
    }
    
    /**
     * @dev Check if address is authorized attestor
     */
    function isAttestor(address attestor) external view override returns (bool) {
        return _attestors[attestor];
    }
    
    /**
     * @dev Update IPFS hash (admin only)
     */
    function updateIPFSHash(string memory newHash) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        string memory oldHash = currentIPFSHash;
        currentIPFSHash = newHash;
        
        emit IPFSHashUpdated(oldHash, newHash);
    }
    
    /**
     * @dev Get current IPFS hash
     */
    function getCurrentIPFSHash() external view override returns (string memory) {
        return currentIPFSHash;
    }
    
    /**
     * @dev Set maximum staleness period
     */
    function setMaxStaleness(uint256 maxAge) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        maxStaleness = maxAge;
    }
    
    /**
     * @dev Get maximum staleness period
     */
    function getMaxStaleness() external view override returns (uint256) {
        return maxStaleness;
    }
    
    /**
     * @dev Set minimum required attestations
     */
    function setMinAttestations(uint256 minCount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(minCount > 0 && minCount <= attestorCount, "Invalid minimum attestations");
        minAttestations = minCount;
    }
    
    /**
     * @dev Emergency override for CSV value (admin only)
     */
    function emergencySetValue(
        string memory policyId,
        uint256 value,
        string memory reason
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _csvData[policyId] = CSVData({
            value: value,
            timestamp: block.timestamp,
            merkleRoot: bytes32(0), // No merkle root for emergency override
            ipfsHash: string(abi.encodePacked("EMERGENCY_", reason)),
            isActive: true
        });
        
        emit CSVValueUpdated(policyId, value, block.timestamp);
    }
    
    /**
     * @dev Internal function to count valid attestations
     */
    function _countValidAttestations(
        string memory policyId,
        uint256 value,
        bytes32 merkleRoot,
        string memory ipfsHash
    ) internal view returns (uint256) {
        uint256 count = 0;
        bytes32 expectedDataHash = keccak256(abi.encodePacked(policyId, value, merkleRoot, ipfsHash));
        
        for (uint256 i = 0; i < attestorList.length; i++) {
            address attestor = attestorList[i];
            if (_attestors[attestor]) {
                Attestation memory attestation = _attestations[policyId][attestor];
                if (attestation.dataHash == expectedDataHash && 
                    block.timestamp - attestation.timestamp <= maxStaleness) {
                    count++;
                }
            }
        }
        
        return count;
    }
    
    /**
     * @dev Get attestation count for policy
     */
    function getAttestationCount(string memory policyId) external view returns (uint256) {
        uint256 count = 0;
        
        for (uint256 i = 0; i < attestorList.length; i++) {
            address attestor = attestorList[i];
            if (_attestors[attestor] && _attestations[policyId][attestor].attestor != address(0)) {
                count++;
            }
        }
        
        return count;
    }
    
    /**
     * @dev Get all attestors
     */
    function getAllAttestors() external view returns (address[] memory) {
        return attestorList;
    }
    
    /**
     * @dev Pause/unpause functions
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
}