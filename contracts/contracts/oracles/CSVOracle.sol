// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title CSVOracle
 * @dev Proof-of-CSV™ multi-attestor system for valuation verification
 * @notice Manages CSV valuations through decentralized oracle consensus
 */
contract CSVOracle is AccessControl, Pausable, ReentrancyGuard {
    
    // Role definitions
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant ORACLE_MANAGER_ROLE = keccak256("ORACLE_MANAGER_ROLE");
    bytes32 public constant CONSUMER_ROLE = keccak256("CONSUMER_ROLE");
    
    // Oracle information
    struct OracleInfo {
        string name;
        string endpoint;
        bool isActive;
        uint256 totalSubmissions;
        uint256 totalCorrectSubmissions;
        uint256 reputationScore;
        address operatorAddress;
        uint256 stakingAmount;
        uint256 lastActiveTimestamp;
    }
    
    // Valuation request structure
    struct ValuationRequest {
        uint256 requestId;
        string policyNumber;
        address requester;
        uint256 timestamp;
        uint256 deadline;
        bool isActive;
        uint256 responseCount;
        uint256 agreedValue;
        bool isFinalized;
        string ipfsHash;
    }
    
    // Oracle response structure
    struct OracleResponse {
        address oracle;
        uint256 value;
        uint256 timestamp;
        bytes32 proofHash;
        string documentationURI;
        bool isValid;
    }
    
    // Consensus parameters
    struct ConsensusConfig {
        uint256 minOracles;
        uint256 maxOracles;
        uint256 consensusThreshold; // Percentage agreement required (basis points)
        uint256 disputePeriod;
        uint256 maxDeviationPercent; // Maximum deviation from median (basis points)
        uint256 responsePeriod;
    }
    
    // Storage
    mapping(address => OracleInfo) public oracles;
    mapping(uint256 => ValuationRequest) public valuationRequests;
    mapping(uint256 => mapping(address => OracleResponse)) public responses;
    mapping(uint256 => address[]) public requestOracles;
    mapping(string => uint256) public policyToLatestRequest;
    
    address[] public registeredOracles;
    uint256 public nextRequestId = 1;
    ConsensusConfig public consensusConfig;
    
    // Fee structure
    uint256 public requestFee = 0.01 ether;
    uint256 public oracleReward = 0.002 ether;
    uint256 public protocolFeeRate = 1000; // 10% in basis points
    
    // Constants
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_REPUTATION_SCORE = 7500; // 75% accuracy required
    uint256 public constant MAX_RESPONSE_TIME = 24 hours;
    
    // Events
    event OracleRegistered(address indexed oracle, string name, uint256 stakingAmount);
    event OracleDeregistered(address indexed oracle, string reason);
    event ValuationRequested(uint256 indexed requestId, string policyNumber, address requester);
    event ValuationSubmitted(uint256 indexed requestId, address indexed oracle, uint256 value);
    event ValuationFinalized(uint256 indexed requestId, uint256 agreedValue, uint256 responseCount);
    event ConsensusReached(uint256 indexed requestId, uint256 finalValue);
    event DisputeRaised(uint256 indexed requestId, address indexed disputer, string reason);
    event OracleSlashed(address indexed oracle, uint256 amount, string reason);
    event OracleRewarded(address indexed oracle, uint256 amount, uint256 requestId);
    
    // Modifiers
    modifier onlyRegisteredOracle() {
        require(oracles[msg.sender].isActive, "CSVOracle: Oracle not registered or inactive");
        _;
    }
    
    modifier validRequest(uint256 requestId) {
        require(requestId < nextRequestId, "CSVOracle: Invalid request ID");
        require(valuationRequests[requestId].isActive, "CSVOracle: Request not active");
        _;
    }
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ORACLE_MANAGER_ROLE, msg.sender);
        
        // Initialize consensus parameters
        consensusConfig = ConsensusConfig({
            minOracles: 3,
            maxOracles: 7,
            consensusThreshold: 6000, // 60% agreement
            disputePeriod: 24 hours,
            maxDeviationPercent: 1000, // 10% maximum deviation
            responsePeriod: 24 hours
        });
    }
    
    /**
     * @dev Register as an oracle
     */
    function registerOracle(
        string memory name,
        string memory endpoint,
        uint256 stakingAmount
    ) external payable nonReentrant {
        require(msg.value >= stakingAmount, "CSVOracle: Insufficient staking amount");
        require(!oracles[msg.sender].isActive, "CSVOracle: Oracle already registered");
        require(bytes(name).length > 0, "CSVOracle: Name required");
        
        oracles[msg.sender] = OracleInfo({
            name: name,
            endpoint: endpoint,
            isActive: true,
            totalSubmissions: 0,
            totalCorrectSubmissions: 0,
            reputationScore: 10000, // Start with perfect score
            operatorAddress: msg.sender,
            stakingAmount: stakingAmount,
            lastActiveTimestamp: block.timestamp
        });
        
        registeredOracles.push(msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        
        emit OracleRegistered(msg.sender, name, stakingAmount);
    }
    
    /**
     * @dev Request CSV valuation
     */
    function requestValuation(
        string memory policyNumber,
        uint256 deadline,
        string memory ipfsHash
    ) external payable nonReentrant whenNotPaused returns (uint256 requestId) {
        require(msg.value >= requestFee, "CSVOracle: Insufficient fee");
        require(deadline > block.timestamp, "CSVOracle: Invalid deadline");
        require(bytes(policyNumber).length > 0, "CSVOracle: Policy number required");
        
        requestId = nextRequestId++;
        
        valuationRequests[requestId] = ValuationRequest({
            requestId: requestId,
            policyNumber: policyNumber,
            requester: msg.sender,
            timestamp: block.timestamp,
            deadline: deadline,
            isActive: true,
            responseCount: 0,
            agreedValue: 0,
            isFinalized: false,
            ipfsHash: ipfsHash
        });
        
        policyToLatestRequest[policyNumber] = requestId;
        
        // Select oracles for this request
        _selectOraclesForRequest(requestId);
        
        emit ValuationRequested(requestId, policyNumber, msg.sender);
        
        return requestId;
    }
    
    /**
     * @dev Submit valuation response
     */
    function submitValuation(
        uint256 requestId,
        uint256 value,
        bytes32 proofHash,
        string memory documentationURI
    ) external validRequest(requestId) onlyRegisteredOracle nonReentrant {
        ValuationRequest storage request = valuationRequests[requestId];
        require(block.timestamp <= request.deadline, "CSVOracle: Deadline passed");
        require(responses[requestId][msg.sender].timestamp == 0, "CSVOracle: Already submitted");
        require(_isOracleAssigned(requestId, msg.sender), "CSVOracle: Oracle not assigned to request");
        require(value > 0, "CSVOracle: Value must be positive");
        
        responses[requestId][msg.sender] = OracleResponse({
            oracle: msg.sender,
            value: value,
            timestamp: block.timestamp,
            proofHash: proofHash,
            documentationURI: documentationURI,
            isValid: true
        });
        
        request.responseCount++;
        oracles[msg.sender].totalSubmissions++;
        oracles[msg.sender].lastActiveTimestamp = block.timestamp;
        
        emit ValuationSubmitted(requestId, msg.sender, value);
        
        // Check if we can finalize
        if (request.responseCount >= consensusConfig.minOracles) {
            _attemptFinalization(requestId);
        }
    }
    
    /**
     * @dev Finalize valuation request
     */
    function finalizeValuation(uint256 requestId) external validRequest(requestId) {
        ValuationRequest storage request = valuationRequests[requestId];
        require(block.timestamp > request.deadline || request.responseCount >= consensusConfig.maxOracles, 
                "CSVOracle: Cannot finalize yet");
        require(!request.isFinalized, "CSVOracle: Already finalized");
        
        _attemptFinalization(requestId);
    }
    
    /**
     * @dev Attempt to finalize valuation based on consensus
     */
    function _attemptFinalization(uint256 requestId) internal {
        ValuationRequest storage request = valuationRequests[requestId];
        
        if (request.responseCount < consensusConfig.minOracles) {
            return; // Not enough responses
        }
        
        // Collect all valid responses
        uint256[] memory values = new uint256[](request.responseCount);
        address[] memory respondingOracles = new address[](request.responseCount);
        uint256 validResponses = 0;
        
        for (uint256 i = 0; i < requestOracles[requestId].length; i++) {
            address oracleAddr = requestOracles[requestId][i];
            OracleResponse storage response = responses[requestId][oracleAddr];
            
            if (response.timestamp > 0 && response.isValid) {
                values[validResponses] = response.value;
                respondingOracles[validResponses] = oracleAddr;
                validResponses++;
            }
        }
        
        if (validResponses >= consensusConfig.minOracles) {
            uint256 consensusValue = _calculateConsensus(values, validResponses);
            
            if (consensusValue > 0) {
                request.agreedValue = consensusValue;
                request.isFinalized = true;
                request.isActive = false;
                
                _distributeRewards(requestId, values, respondingOracles, validResponses, consensusValue);
                
                emit ValuationFinalized(requestId, consensusValue, validResponses);
                emit ConsensusReached(requestId, consensusValue);
            }
        }
    }
    
    /**
     * @dev Calculate consensus value from responses
     */
    function _calculateConsensus(
        uint256[] memory values,
        uint256 count
    ) internal view returns (uint256) {
        if (count == 0) return 0;
        
        // Sort values to find median
        _quickSort(values, 0, int256(count - 1));
        
        uint256 median;
        if (count % 2 == 0) {
            median = (values[count / 2 - 1] + values[count / 2]) / 2;
        } else {
            median = values[count / 2];
        }
        
        // Check consensus threshold
        uint256 agreementCount = 0;
        uint256 maxDeviation = (median * consensusConfig.maxDeviationPercent) / BASIS_POINTS;
        
        for (uint256 i = 0; i < count; i++) {
            if (values[i] >= median - maxDeviation && values[i] <= median + maxDeviation) {
                agreementCount++;
            }
        }
        
        uint256 consensusPercent = (agreementCount * BASIS_POINTS) / count;
        
        if (consensusPercent >= consensusConfig.consensusThreshold) {
            return median;
        }
        
        return 0; // No consensus reached
    }
    
    /**
     * @dev Distribute rewards to oracles
     */
    function _distributeRewards(
        uint256 requestId,
        uint256[] memory values,
        address[] memory oracles,
        uint256 count,
        uint256 consensusValue
    ) internal {
        uint256 totalReward = oracleReward * count;
        uint256 individualReward = oracleReward;
        
        uint256 maxDeviation = (consensusValue * consensusConfig.maxDeviationPercent) / BASIS_POINTS;
        
        for (uint256 i = 0; i < count; i++) {
            address oracleAddr = oracles[i];
            bool isAccurate = values[i] >= consensusValue - maxDeviation && 
                            values[i] <= consensusValue + maxDeviation;
            
            if (isAccurate) {
                oracles[oracleAddr].totalCorrectSubmissions++;
                
                // Transfer reward
                payable(oracleAddr).transfer(individualReward);
                emit OracleRewarded(oracleAddr, individualReward, requestId);
            }
            
            // Update reputation score
            _updateReputationScore(oracleAddr);
        }
    }
    
    /**
     * @dev Update oracle reputation score
     */
    function _updateReputationScore(address oracleAddr) internal {
        OracleInfo storage oracle = oracles[oracleAddr];
        
        if (oracle.totalSubmissions > 0) {
            oracle.reputationScore = (oracle.totalCorrectSubmissions * BASIS_POINTS) / oracle.totalSubmissions;
            
            // Deactivate oracle if reputation drops too low
            if (oracle.reputationScore < MIN_REPUTATION_SCORE) {
                oracle.isActive = false;
                _revokeRole(ORACLE_ROLE, oracleAddr);
                emit OracleDeregistered(oracleAddr, "Low reputation score");
            }
        }
    }
    
    /**
     * @dev Select oracles for a request
     */
    function _selectOraclesForRequest(uint256 requestId) internal {
        uint256 availableOracles = 0;
        
        // Count available oracles
        for (uint256 i = 0; i < registeredOracles.length; i++) {
            if (oracles[registeredOracles[i]].isActive && 
                oracles[registeredOracles[i]].reputationScore >= MIN_REPUTATION_SCORE) {
                availableOracles++;
            }
        }
        
        require(availableOracles >= consensusConfig.minOracles, "CSVOracle: Insufficient active oracles");
        
        // Select oracles (simplified selection - in production, use more sophisticated method)
        uint256 selected = 0;
        uint256 maxToSelect = availableOracles > consensusConfig.maxOracles ? 
                            consensusConfig.maxOracles : availableOracles;
        
        for (uint256 i = 0; i < registeredOracles.length && selected < maxToSelect; i++) {
            address oracleAddr = registeredOracles[i];
            if (oracles[oracleAddr].isActive && 
                oracles[oracleAddr].reputationScore >= MIN_REPUTATION_SCORE) {
                requestOracles[requestId].push(oracleAddr);
                selected++;
            }
        }
    }
    
    /**
     * @dev Check if oracle is assigned to request
     */
    function _isOracleAssigned(uint256 requestId, address oracleAddr) internal view returns (bool) {
        address[] storage assignedOracles = requestOracles[requestId];
        for (uint256 i = 0; i < assignedOracles.length; i++) {
            if (assignedOracles[i] == oracleAddr) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * @dev Quick sort implementation
     */
    function _quickSort(uint256[] memory arr, int256 left, int256 right) internal pure {
        if (left < right) {
            int256 pi = _partition(arr, left, right);
            _quickSort(arr, left, pi - 1);
            _quickSort(arr, pi + 1, right);
        }
    }
    
    function _partition(uint256[] memory arr, int256 left, int256 right) internal pure returns (int256) {
        uint256 pivot = arr[uint256(right)];
        int256 i = left - 1;
        
        for (int256 j = left; j < right; j++) {
            if (arr[uint256(j)] <= pivot) {
                i++;
                (arr[uint256(i)], arr[uint256(j)]) = (arr[uint256(j)], arr[uint256(i)]);
            }
        }
        
        (arr[uint256(i + 1)], arr[uint256(right)]) = (arr[uint256(right)], arr[uint256(i + 1)]);
        return i + 1;
    }
    
    // View functions
    function getValuationRequest(uint256 requestId) external view returns (ValuationRequest memory) {
        return valuationRequests[requestId];
    }
    
    function getOracleResponse(uint256 requestId, address oracle) external view returns (OracleResponse memory) {
        return responses[requestId][oracle];
    }
    
    function getAssignedOracles(uint256 requestId) external view returns (address[] memory) {
        return requestOracles[requestId];
    }
    
    function getActiveOracleCount() external view returns (uint256 count) {
        for (uint256 i = 0; i < registeredOracles.length; i++) {
            if (oracles[registeredOracles[i]].isActive) {
                count++;
            }
        }
    }
    
    function getOracleInfo(address oracleAddr) external view returns (OracleInfo memory) {
        return oracles[oracleAddr];
    }
    
    function getLatestValuation(string memory policyNumber) external view returns (uint256, bool) {
        uint256 requestId = policyToLatestRequest[policyNumber];
        if (requestId == 0) return (0, false);
        
        ValuationRequest storage request = valuationRequests[requestId];
        return (request.agreedValue, request.isFinalized);
    }
    
    // Admin functions
    function updateConsensusConfig(ConsensusConfig memory newConfig) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(newConfig.minOracles >= 2, "CSVOracle: Minimum oracles too low");
        require(newConfig.maxOracles >= newConfig.minOracles, "CSVOracle: Invalid oracle counts");
        require(newConfig.consensusThreshold <= BASIS_POINTS, "CSVOracle: Invalid consensus threshold");
        
        consensusConfig = newConfig;
    }
    
    function updateFees(
        uint256 _requestFee,
        uint256 _oracleReward,
        uint256 _protocolFeeRate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        requestFee = _requestFee;
        oracleReward = _oracleReward;
        protocolFeeRate = _protocolFeeRate;
    }
    
    function slashOracle(
        address oracleAddr,
        uint256 amount,
        string memory reason
    ) external onlyRole(ORACLE_MANAGER_ROLE) {
        require(oracles[oracleAddr].stakingAmount >= amount, "CSVOracle: Insufficient stake");
        
        oracles[oracleAddr].stakingAmount -= amount;
        if (oracles[oracleAddr].stakingAmount == 0) {
            oracles[oracleAddr].isActive = false;
            _revokeRole(ORACLE_ROLE, oracleAddr);
        }
        
        emit OracleSlashed(oracleAddr, amount, reason);
    }
    
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }
    
    function withdrawProtocolFees() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(msg.sender).transfer(balance);
        }
    }
    
    // Allow contract to receive Ether
    receive() external payable {}
}