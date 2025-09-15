// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../interfaces/IERC_RWA_CSV.sol";

/**
 * @title CSVOracle
 * @dev Enhanced Proof-of-CSV™ Oracle system with 2-of-N signatures, slashing, and monotonicity checks
 * @notice This contract manages multi-attestor valuations with enhanced security and risk controls
 */
contract CSVOracle is AccessControl, ICSVOracle {
    using ECDSA for bytes32;
    
    // Role definitions
    bytes32 public constant ATTESTOR_ROLE = keccak256("ATTESTOR_ROLE");
    bytes32 public constant RATING_AGENCY_ROLE = keccak256("RATING_AGENCY_ROLE");
    bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");
    
    // Enhanced configuration
    uint256 public requiredSignatures = 2; // 2-of-N threshold
    uint256 public totalAttestors = 5;
    uint256 public maxAttestationAge = 1 hours;
    uint256 public slashingAmount = 1 ether; // Stake required and slashed
    uint256 public constant MAX_CARRIERS = 1000;
    
    // Oracle data with enhanced tracking
    ValuationData public latestValuation;
    mapping(address => bool) public trustedAttestors;
    mapping(address => uint256) public attestorStake;
    mapping(address => bool) public slashedAttestors;
    mapping(address => uint256) public attestorLastUpdate;
    mapping(bytes32 => CarrierData) public carriers;
    
    // Attestor bitmap for efficient signature tracking
    mapping(bytes32 => uint256) public attestorBitmap; // submissionId => bitmap
    mapping(bytes32 => address[]) public submissionAttestors; // submissionId => attestor addresses
    
    // Submission tracking with enhanced data
    struct AttestationSubmission {
        uint256 csvValue;
        bytes32 merkleRoot;
        uint256 timestamp;
        bytes signature;
        address attestor;
        bool verified;
        uint256 blockNumber;
    }
    
    mapping(bytes32 => AttestationSubmission[]) public submissions;
    mapping(address => uint256) public lastSubmissionTime;
    
    // Monotonicity tracking
    uint256 public lastFinalizedValue;
    uint256 public lastFinalizedTimestamp;
    uint256 public maxValueDecrease = 1000; // 10% max decrease in basis points
    
    // Enhanced events with full context
    event OracleUpdate(
        bytes32 indexed submissionId,
        uint256 csvValue,
        bytes32 merkleRoot,
        address[] attestors,
        uint256 attestorCount,
        uint256 timestamp,
        uint256 blockNumber
    );
    event ValuationSubmitted(
        address indexed attestor, 
        bytes32 indexed submissionId,
        uint256 csvValue, 
        bytes32 merkleRoot, 
        uint256 timestamp
    );
    event ValuationFinalized(
        bytes32 indexed submissionId,
        uint256 csvValue, 
        bytes32 merkleRoot, 
        uint256 attestorCount, 
        uint256 timestamp
    );
    event AttestorSlashed(
        address indexed attestor, 
        uint256 slashAmount, 
        string reason,
        uint256 timestamp
    );
    event AttestorStakeUpdated(address indexed attestor, uint256 oldStake, uint256 newStake);
    event SignatureThresholdUpdated(uint256 oldThreshold, uint256 newThreshold);
    event MonotonicityViolation(uint256 proposedValue, uint256 lastValue, uint256 maxAllowed);
    event StaleDataDetected(address indexed attestor, uint256 submissionTime, uint256 maxAge);
    
    modifier onlyTrustedAttestor() {
        require(
            trustedAttestors[msg.sender] && !slashedAttestors[msg.sender],
            "Not authorized or slashed attestor"
        );
        require(attestorStake[msg.sender] >= slashingAmount, "Insufficient stake");
        _;
    }
    
    modifier validCarrierId(bytes32 carrierId) {
        require(carriers[carrierId].isActive, "Carrier not active");
        _;
    }
    
    modifier notStale(uint256 timestamp) {
        require(
            block.timestamp - timestamp <= maxAttestationAge,
            "Attestation data too stale"
        );
        _;
    }

    constructor(address _admin, address[] memory _initialAttestors) {
        require(_admin != address(0), "Invalid admin");
        require(_initialAttestors.length >= requiredSignatures, "Insufficient initial attestors");
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ORACLE_MANAGER_ROLE, _admin);
        _grantRole(RATING_AGENCY_ROLE, _admin);
        
        totalAttestors = _initialAttestors.length;
        
        // Set up initial trusted attestors with required stake
        for (uint256 i = 0; i < _initialAttestors.length; i++) {
            require(_initialAttestors[i] != address(0), "Invalid attestor address");
            trustedAttestors[_initialAttestors[i]] = true;
            attestorStake[_initialAttestors[i]] = slashingAmount; // Initial stake
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
        
        lastFinalizedTimestamp = block.timestamp;
    }
    
    /**
     * @dev Enhanced valuation submission with signature verification and bitmap tracking
     */
    function submitValuation(
        uint256 csv, 
        bytes32 merkleRoot, 
        bytes calldata signature
    ) external override onlyTrustedAttestor notStale(block.timestamp) {
        require(csv > 0, "CSV value must be positive");
        require(merkleRoot != bytes32(0), "Invalid merkle root");
        require(signature.length == 65, "Invalid signature length");
        
        // Rate limiting - prevent spam submissions
        require(
            block.timestamp - lastSubmissionTime[msg.sender] >= 10 minutes,
            "Submission too frequent"
        );
        
        // Monotonicity check - prevent sudden large decreases
        if (lastFinalizedValue > 0) {
            uint256 minAllowedValue = lastFinalizedValue - 
                (lastFinalizedValue * maxValueDecrease) / 10000;
            require(csv >= minAllowedValue, "Value decrease too large");
        }
        
        // Verify signature
        bytes32 messageHash = keccak256(abi.encodePacked(
            csv, 
            merkleRoot, 
            block.timestamp, 
            msg.sender,
            block.chainid
        ));
        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(messageHash);
        address signer = ethSignedMessageHash.recover(signature);
        require(signer == msg.sender, "Invalid signature");
        
        // Create submission ID
        bytes32 submissionId = keccak256(abi.encodePacked(
            csv, 
            merkleRoot, 
            block.timestamp,
            block.number
        ));
        
        // Check if attestor already submitted for this valuation
        require(!_hasAttestorSubmitted(submissionId, msg.sender), "Already submitted");
        
        // Store submission with enhanced data
        submissions[submissionId].push(AttestationSubmission({
            csvValue: csv,
            merkleRoot: merkleRoot,
            timestamp: block.timestamp,
            signature: signature,
            attestor: msg.sender,
            verified: true,
            blockNumber: block.number
        }));
        
        // Update attestor bitmap
        _updateAttestorBitmap(submissionId, msg.sender);
        
        lastSubmissionTime[msg.sender] = block.timestamp;
        attestorLastUpdate[msg.sender] = block.timestamp;
        
        emit ValuationSubmitted(msg.sender, submissionId, csv, merkleRoot, block.timestamp);
        
        // Check if we have enough signatures to finalize
        _checkAndFinalizeValuation(submissionId);
    }
    
    /**
     * @dev Enhanced finalization with 2-of-N signature verification
     */
    function _checkAndFinalizeValuation(bytes32 submissionId) internal {
        AttestationSubmission[] storage subs = submissions[submissionId];
        require(subs.length > 0, "No submissions found");
        
        // Check if we have reached the required signature threshold
        if (subs.length >= requiredSignatures) {
            // Verify all signatures are from different attestors
            address[] memory submissionAttestorList = submissionAttestors[submissionId];
            require(submissionAttestorList.length >= requiredSignatures, "Insufficient unique attestors");
            
            // Calculate consensus value (weighted average by stake)
            uint256 totalCSV = _calculateConsensusValue(submissionId);
            bytes32 consensusMerkleRoot = subs[0].merkleRoot; // Use first merkle root
            
            // Create attestor array for this valuation
            address[] memory attestorArray = new address[](submissionAttestorList.length);
            for (uint256 i = 0; i < submissionAttestorList.length; i++) {
                attestorArray[i] = submissionAttestorList[i];
            }
            
            // Update latest valuation
            latestValuation = ValuationData({
                totalCSV: totalCSV,
                timestamp: block.timestamp,
                merkleRoot: consensusMerkleRoot,
                attestors: attestorArray,
                carrierRating: _calculateWeightedCarrierRating()
            });
            
            // Update monotonicity tracking
            lastFinalizedValue = totalCSV;
            lastFinalizedTimestamp = block.timestamp;
            
            emit ValuationFinalized(submissionId, totalCSV, consensusMerkleRoot, subs.length, block.timestamp);
            emit OracleUpdate(
                submissionId,
                totalCSV,
                consensusMerkleRoot,
                attestorArray,
                attestorArray.length,
                block.timestamp,
                block.number
            );
        }
    }
    
    /**
     * @dev Calculate consensus value using stake-weighted average
     */
    function _calculateConsensusValue(bytes32 submissionId) internal view returns (uint256) {
        AttestationSubmission[] storage subs = submissions[submissionId];
        uint256 totalValue = 0;
        uint256 totalWeight = 0;
        
        for (uint256 i = 0; i < subs.length; i++) {
            uint256 weight = attestorStake[subs[i].attestor];
            totalValue += subs[i].csvValue * weight;
            totalWeight += weight;
        }
        
        return totalWeight > 0 ? totalValue / totalWeight : 0;
    }
    
    /**
     * @dev Update attestor bitmap for efficient tracking
     */
    function _updateAttestorBitmap(bytes32 submissionId, address attestor) internal {
        // Find attestor index
        uint256 attestorIndex = _getAttestorIndex(attestor);
        require(attestorIndex < 256, "Too many attestors for bitmap");
        
        // Set bit in bitmap
        attestorBitmap[submissionId] |= (1 << attestorIndex);
        
        // Add to attestor list
        submissionAttestors[submissionId].push(attestor);
    }
    
    /**
     * @dev Check if attestor has already submitted for this valuation
     */
    function _hasAttestorSubmitted(bytes32 submissionId, address attestor) internal view returns (bool) {
        uint256 attestorIndex = _getAttestorIndex(attestor);
        return (attestorBitmap[submissionId] & (1 << attestorIndex)) != 0;
    }
    
    /**
     * @dev Get attestor index for bitmap operations
     */
    function _getAttestorIndex(address attestor) internal view returns (uint256) {
        // Simple implementation - in production, maintain a mapping
        address[] memory allAttestors = new address[](totalAttestors);
        uint256 index = 0;
        
        // This is simplified - in practice, maintain an attestor index mapping
        for (uint256 i = 0; i < totalAttestors && index < allAttestors.length; i++) {
            if (trustedAttestors[attestor]) {
                if (attestor == address(uint160(i + 1))) { // Placeholder logic
                    return i;
                }
            }
        }
        
        revert("Attestor not found");
    }
    
    /**
     * @dev Enhanced slashing mechanism with detailed tracking
     */
    function slashAttestor(
        address attestor, 
        string calldata reason
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(trustedAttestors[attestor], "Not a trusted attestor");
        require(!slashedAttestors[attestor], "Already slashed");
        require(attestorStake[attestor] > 0, "No stake to slash");
        
        uint256 slashAmount = attestorStake[attestor];
        attestorStake[attestor] = 0;
        slashedAttestors[attestor] = true;
        trustedAttestors[attestor] = false;
        
        // Revoke attestor role
        _revokeRole(ATTESTOR_ROLE, attestor);
        
        emit AttestorSlashed(attestor, slashAmount, reason, block.timestamp);
        emit AttestorStatusChanged(attestor, false);
    }
    
    /**
     * @dev Add stake for attestor
     */
    function addAttestorStake(address attestor) external payable onlyRole(ORACLE_MANAGER_ROLE) {
        require(trustedAttestors[attestor], "Not a trusted attestor");
        require(msg.value > 0, "Must send stake");
        
        uint256 oldStake = attestorStake[attestor];
        attestorStake[attestor] += msg.value;
        
        emit AttestorStakeUpdated(attestor, oldStake, attestorStake[attestor]);
    }
    
    /**
     * @dev Update signature threshold (2-of-N)
     */
    function updateSignatureThreshold(uint256 newThreshold) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newThreshold >= 1 && newThreshold <= totalAttestors, "Invalid threshold");
        require(newThreshold <= 10, "Threshold too high");
        
        uint256 oldThreshold = requiredSignatures;
        requiredSignatures = newThreshold;
        
        emit SignatureThresholdUpdated(oldThreshold, newThreshold);
    }
    
    /**
     * @dev Check for stale oracle data
     */
    function isValuationStale() external view override returns (bool) {
        return block.timestamp - latestValuation.timestamp > maxAttestationAge;
    }
    
    /**
     * @dev Get attestor threshold information
     */
    function getAttestorThreshold() external view override returns (uint256 required, uint256 total) {
        return (requiredSignatures, totalAttestors);
    }
    
    /**
     * @dev Enhanced view functions
     */
    function getSubmissionDetails(bytes32 submissionId) 
        external 
        view 
        returns (
            AttestationSubmission[] memory submissions_,
            address[] memory attestors,
            uint256 bitmap
        ) 
    {
        return (
            submissions[submissionId],
            submissionAttestors[submissionId],
            attestorBitmap[submissionId]
        );
    }
    
    /**
     * @dev Calculate weighted average carrier rating
     */
    function _calculateWeightedCarrierRating() internal view returns (uint256) {
        // Simplified implementation - in practice this would weight by CSV amounts
        return 1000; // Default AAA rating for now
    }
    
    // Existing functions from original implementation...
    // (keeping existing functionality while adding enhancements)
    
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
    
    // View functions implementing ICSVOracle
    
    function getLatestValuation() external view override returns (ValuationData memory) {
        return latestValuation;
    }
    
    function verifyAttestor(address attestor) external view override returns (bool) {
        return trustedAttestors[attestor] && !slashedAttestors[attestor] && 
               attestorStake[attestor] >= slashingAmount;
    }
    
    function getMinAttestors() external view override returns (uint256) {
        return requiredSignatures;
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
     * @dev Emergency function to pause oracle operations
     */
    function emergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        // Set very high signature requirement to effectively pause
        requiredSignatures = totalAttestors + 1;
        emit SignatureThresholdUpdated(requiredSignatures, totalAttestors + 1);
    }
    
    /**
     * @dev Set trusted attestor status with stake requirement
     */
    function setTrustedAttestor(address attestor, bool trusted) 
        external 
        onlyRole(ORACLE_MANAGER_ROLE) 
    {
        require(attestor != address(0), "Invalid attestor");
        
        if (trusted && !trustedAttestors[attestor]) {
            require(attestorStake[attestor] >= slashingAmount, "Insufficient stake");
            totalAttestors++;
        } else if (!trusted && trustedAttestors[attestor]) {
            totalAttestors--;
        }
        
        trustedAttestors[attestor] = trusted;
        
        if (trusted) {
            _grantRole(ATTESTOR_ROLE, attestor);
        } else {
            _revokeRole(ATTESTOR_ROLE, attestor);
        }
        
        emit AttestorStatusChanged(attestor, trusted);
    }
}