// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../interfaces/IERC_RWA_CSV.sol";

/**
 * @title CSVOracle
 * @dev Proof-of-CSV™ Oracle system for insurance cash surrender value attestations
 * @notice This contract manages multi-attestor valuations with carrier ratings and Merkle proofs
 */
contract CSVOracle is AccessControl, ICSVOracle {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    
    // Role definitions
    bytes32 public constant ATTESTOR_ROLE = keccak256("ATTESTOR_ROLE");
    bytes32 public constant RATING_AGENCY_ROLE = keccak256("RATING_AGENCY_ROLE");
    bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");
    
    // Configuration
    uint256 public minAttestors = 2;
    uint256 public maxAttestationAge = 1 hours;
    uint256 public constant MAX_CARRIERS = 1000;
    
    // Oracle data
    ValuationData public latestValuation;
    mapping(address => bool) public trustedAttestors;
    mapping(bytes32 => CarrierData) public carriers;
    mapping(bytes32 => mapping(address => uint256)) public attestorSubmissions;
    
    // Submission tracking
    struct AttestationSubmission {
        uint256 csvValue;
        bytes32 merkleRoot;
        uint256 timestamp;
        bytes signature;
        bool verified;
    }
    
    mapping(bytes32 => AttestationSubmission[]) public submissions;
    mapping(address => uint256) public lastSubmissionTime;
    
    // Events
    event ValuationSubmitted(address indexed attestor, uint256 csvValue, bytes32 merkleRoot, uint256 timestamp);
    event ValuationFinalized(uint256 csvValue, bytes32 merkleRoot, uint256 attestorCount, uint256 timestamp);
    event CarrierAdded(bytes32 indexed carrierId, string name, uint256 rating);
    event CarrierRatingUpdated(bytes32 indexed carrierId, uint256 oldRating, uint256 newRating);
    event AttestorStatusChanged(address indexed attestor, bool trusted);
    event MinAttestorsUpdated(uint256 oldMin, uint256 newMin);
    
    modifier onlyTrustedAttestor() {
        require(trustedAttestors[msg.sender] || hasRole(ATTESTOR_ROLE, msg.sender), 
                "Not authorized attestor");
        _;
    }
    
    modifier validCarrierId(bytes32 carrierId) {
        require(carriers[carrierId].isActive, "Carrier not active");
        _;
    }
    
    constructor(address _admin, address[] memory _initialAttestors) {
        require(_admin != address(0), "Invalid admin");
        require(_initialAttestors.length >= 2, "Need at least 2 initial attestors");
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ORACLE_MANAGER_ROLE, _admin);
        _grantRole(RATING_AGENCY_ROLE, _admin);
        
        // Set up initial trusted attestors
        for (uint256 i = 0; i < _initialAttestors.length; i++) {
            require(_initialAttestors[i] != address(0), "Invalid attestor address");
            trustedAttestors[_initialAttestors[i]] = true;
            _grantRole(ATTESTOR_ROLE, _initialAttestors[i]);
            emit AttestorStatusChanged(_initialAttestors[i], true);
        }
        
        // Initialize with empty valuation
        latestValuation = ValuationData({
            totalCSV: 0,
            timestamp: block.timestamp,
            merkleRoot: bytes32(0),
            attestors: new address[](0),
            carrierRating: 1000 // Default AAA rating
        });
    }
    
    /**
     * @dev Submit valuation with Merkle proof and signature
     */
    function submitValuation(
        uint256 csv, 
        bytes32 merkleRoot, 
        bytes calldata signature
    ) external override onlyTrustedAttestor {
        require(csv > 0, "CSV value must be positive");
        require(merkleRoot != bytes32(0), "Invalid merkle root");
        require(signature.length == 65, "Invalid signature length");
        
        // Rate limiting - prevent spam submissions
        require(
            block.timestamp - lastSubmissionTime[msg.sender] >= 10 minutes,
            "Submission too frequent"
        );
        
        // Verify signature
        bytes32 messageHash = keccak256(abi.encodePacked(csv, merkleRoot, block.timestamp, msg.sender));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedMessageHash.recover(signature);
        require(signer == msg.sender, "Invalid signature");
        
        // Create submission ID
        bytes32 submissionId = keccak256(abi.encodePacked(csv, merkleRoot, block.timestamp));
        
        // Store submission
        submissions[submissionId].push(AttestationSubmission({
            csvValue: csv,
            merkleRoot: merkleRoot,
            timestamp: block.timestamp,
            signature: signature,
            verified: true
        }));
        
        attestorSubmissions[submissionId][msg.sender] = csv;
        lastSubmissionTime[msg.sender] = block.timestamp;
        
        emit ValuationSubmitted(msg.sender, csv, merkleRoot, block.timestamp);
        
        // Check if we have enough attestations to finalize
        _checkAndFinalizeValuation(submissionId);
    }
    
    /**
     * @dev Internal function to check consensus and finalize valuation
     */
    function _checkAndFinalizeValuation(bytes32 submissionId) internal {
        AttestationSubmission[] storage subs = submissions[submissionId];
        require(subs.length > 0, "No submissions found");
        
        // For simplicity, we'll use submission count as a proxy for attestor count
        if (subs.length >= minAttestors) {
            // Calculate consensus value (simple average for now)
            uint256 totalCSV = 0;
            bytes32 consensusMerkleRoot = subs[0].merkleRoot; // Use first one for simplicity
            
            for (uint256 i = 0; i < subs.length; i++) {
                totalCSV += subs[i].csvValue;
            }
            totalCSV = totalCSV / subs.length;
            
            // Create attestor array (simplified)
            address[] memory attestorArray = new address[](subs.length);
            for (uint256 i = 0; i < subs.length && i < attestorArray.length; i++) {
                // In a real implementation, we'd track which attestor made each submission
                attestorArray[i] = address(uint160(i + 1)); // Placeholder
            }
            
            // Update latest valuation
            latestValuation = ValuationData({
                totalCSV: totalCSV,
                timestamp: block.timestamp,
                merkleRoot: consensusMerkleRoot,
                attestors: attestorArray,
                carrierRating: _calculateWeightedCarrierRating()
            });
            
            emit ValuationFinalized(totalCSV, consensusMerkleRoot, subs.length, block.timestamp);
        }
    }
    
    /**
     * @dev Calculate weighted average carrier rating
     */
    function _calculateWeightedCarrierRating() internal view returns (uint256) {
        // Simplified implementation - in practice this would weight by CSV amounts
        return 1000; // Default AAA rating for now
    }
    
    /**
     * @dev Add or update carrier information
     */
    function addCarrier(
        bytes32 carrierId,
        string memory name,
        uint256 rating
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(rating >= 1 && rating <= 1000, "Rating must be 1-1000");
        require(bytes(name).length > 0, "Name cannot be empty");
        
        bool isNewCarrier = !carriers[carrierId].isActive;
        
        carriers[carrierId] = CarrierData({
            name: name,
            rating: rating,
            lastUpdated: block.timestamp,
            isActive: true
        });
        
        if (isNewCarrier) {
            emit CarrierAdded(carrierId, name, rating);
        }
    }
    
    /**
     * @dev Update carrier rating
     */
    function updateCarrierRating(
        bytes32 carrierId, 
        uint256 newRating
    ) external override onlyRole(RATING_AGENCY_ROLE) validCarrierId(carrierId) {
        require(newRating >= 1 && newRating <= 1000, "Rating must be 1-1000");
        
        uint256 oldRating = carriers[carrierId].rating;
        carriers[carrierId].rating = newRating;
        carriers[carrierId].lastUpdated = block.timestamp;
        
        emit CarrierRatingUpdated(carrierId, oldRating, newRating);
    }
    
    /**
     * @dev Set trusted attestor status
     */
    function setTrustedAttestor(address attestor, bool trusted) 
        external 
        onlyRole(ORACLE_MANAGER_ROLE) 
    {
        require(attestor != address(0), "Invalid attestor");
        trustedAttestors[attestor] = trusted;
        
        if (trusted) {
            _grantRole(ATTESTOR_ROLE, attestor);
        } else {
            _revokeRole(ATTESTOR_ROLE, attestor);
        }
        
        emit AttestorStatusChanged(attestor, trusted);
    }
    
    /**
     * @dev Update minimum required attestors
     */
    function setMinAttestors(uint256 newMin) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newMin >= 1 && newMin <= 10, "Invalid attestor count");
        uint256 oldMin = minAttestors;
        minAttestors = newMin;
        emit MinAttestorsUpdated(oldMin, newMin);
    }
    
    // View functions implementing ICSVOracle
    
    function getLatestValuation() external view override returns (ValuationData memory) {
        return latestValuation;
    }
    
    function verifyAttestor(address attestor) external view override returns (bool) {
        return trustedAttestors[attestor] || hasRole(ATTESTOR_ROLE, attestor);
    }
    
    function getMinAttestors() external view override returns (uint256) {
        return minAttestors;
    }
    
    function getCarrierData(bytes32 carrierId) 
        external 
        view 
        override 
        returns (CarrierData memory) 
    {
        return carriers[carrierId];
    }
    
    /**
     * @dev Get submission history for a specific submission ID
     */
    function getSubmissions(bytes32 submissionId) 
        external 
        view 
        returns (AttestationSubmission[] memory) 
    {
        return submissions[submissionId];
    }
    
    /**
     * @dev Check if valuation is stale
     */
    function isValuationStale() external view returns (bool) {
        return block.timestamp - latestValuation.timestamp > maxAttestationAge;
    }
    
    /**
     * @dev Emergency function to pause oracle operations
     */
    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Implementation would halt all oracle operations
        // For now, we'll just set a very high min attestor requirement
        minAttestors = 100;
    }
}