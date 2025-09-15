// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title CSVOracle
 * @dev Proof-of-CSV™ multi-attestor system for insurance valuation
 */
contract CSVOracle is AccessControl {
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    
    struct Attestation {
        uint256 value;
        bytes32 merkleRoot;
        uint256 timestamp;
        bool isValid;
    }
    
    struct PolicyValuation {
        string policyId;
        uint256 csvValue;
        uint256 confirmations;
        uint256 requiredConfirmations;
        mapping(address => Attestation) attestations;
        address[] attestors;
        bool finalized;
    }
    
    mapping(bytes32 => PolicyValuation) public valuations;
    mapping(string => bytes32) public policyToValuationId;
    
    uint256 public constant MIN_CONFIRMATIONS = 2;
    uint256 public constant MAX_ATTESTORS = 3;
    
    event AttestationSubmitted(bytes32 indexed valuationId, address indexed attestor, uint256 value);
    event ValuationFinalized(bytes32 indexed valuationId, uint256 finalValue);
    
    constructor(address defaultAdmin) {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    }
    
    function addOracle(address oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(ORACLE_ROLE, oracle);
    }
    
    function removeOracle(address oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(ORACLE_ROLE, oracle);
    }
    
    function requestValuation(string memory policyId, uint256 requiredConfirmations) 
        external 
        returns (bytes32 valuationId) 
    {
        require(requiredConfirmations >= MIN_CONFIRMATIONS, "Insufficient confirmations required");
        require(requiredConfirmations <= MAX_ATTESTORS, "Too many confirmations required");
        
        valuationId = keccak256(abi.encodePacked(policyId, block.timestamp, msg.sender));
        
        PolicyValuation storage valuation = valuations[valuationId];
        valuation.policyId = policyId;
        valuation.requiredConfirmations = requiredConfirmations;
        
        policyToValuationId[policyId] = valuationId;
        
        return valuationId;
    }
    
    function submitAttestation(
        bytes32 valuationId, 
        uint256 csvValue, 
        bytes32 merkleRoot
    ) external onlyRole(ORACLE_ROLE) {
        PolicyValuation storage valuation = valuations[valuationId];
        require(!valuation.finalized, "Valuation already finalized");
        require(valuation.attestations[msg.sender].timestamp == 0, "Already attested");
        
        valuation.attestations[msg.sender] = Attestation({
            value: csvValue,
            merkleRoot: merkleRoot,
            timestamp: block.timestamp,
            isValid: true
        });
        
        valuation.attestors.push(msg.sender);
        valuation.confirmations++;
        
        emit AttestationSubmitted(valuationId, msg.sender, csvValue);
        
        if (valuation.confirmations >= valuation.requiredConfirmations) {
            _finalizeValuation(valuationId);
        }
    }
    
    function _finalizeValuation(bytes32 valuationId) internal {
        PolicyValuation storage valuation = valuations[valuationId];
        
        uint256 totalValue = 0;
        uint256 validAttestations = 0;
        
        for (uint256 i = 0; i < valuation.attestors.length; i++) {
            address attestor = valuation.attestors[i];
            if (valuation.attestations[attestor].isValid) {
                totalValue += valuation.attestations[attestor].value;
                validAttestations++;
            }
        }
        
        valuation.csvValue = totalValue / validAttestations;
        valuation.finalized = true;
        
        emit ValuationFinalized(valuationId, valuation.csvValue);
    }
    
    function getValuation(bytes32 valuationId) 
        external 
        view 
        returns (string memory policyId, uint256 csvValue, bool finalized) 
    {
        PolicyValuation storage valuation = valuations[valuationId];
        return (valuation.policyId, valuation.csvValue, valuation.finalized);
    }
}