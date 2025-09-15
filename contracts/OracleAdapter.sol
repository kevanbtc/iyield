// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title OracleAdapter
 * @dev Mock oracle for CSV (Cash Surrender Value) data feeds
 * In production, this would integrate with Chainlink or other oracle services
 */
contract OracleAdapter is Ownable {
    uint256 public csvValue;
    uint256 public lastUpdated;
    uint256 public constant STALENESS_THRESHOLD = 1 hours;
    
    mapping(address => bool) public oracles;
    
    event CsvUpdated(uint256 newValue, uint256 timestamp);
    event OracleAdded(address indexed oracle);
    event OracleRemoved(address indexed oracle);
    
    modifier onlyOracle() {
        require(oracles[msg.sender] || msg.sender == owner(), "Not authorized oracle");
        _;
    }
    
    modifier notStale() {
        require(block.timestamp - lastUpdated <= STALENESS_THRESHOLD, "Data too stale");
        _;
    }
    
    constructor() Ownable(msg.sender) {
        csvValue = 1000000; // Default mock value: $1,000,000
        lastUpdated = block.timestamp;
    }
    
    /**
     * @dev Add oracle address
     * @param oracle Address to add as oracle
     */
    function addOracle(address oracle) external onlyOwner {
        oracles[oracle] = true;
        emit OracleAdded(oracle);
    }
    
    /**
     * @dev Remove oracle address
     * @param oracle Address to remove as oracle
     */
    function removeOracle(address oracle) external onlyOwner {
        oracles[oracle] = false;
        emit OracleRemoved(oracle);
    }
    
    /**
     * @dev Update CSV value
     * @param newValue New CSV value in wei
     */
    function updateCSV(uint256 newValue) external onlyOracle {
        csvValue = newValue;
        lastUpdated = block.timestamp;
        emit CsvUpdated(newValue, block.timestamp);
    }
    
    /**
     * @dev Get current CSV value
     * @return uint256 Current CSV value
     */
    function getCSV() external view notStale returns (uint256) {
        return csvValue;
    }
    
    /**
     * @dev Get CSV value without staleness check (for testing)
     * @return uint256 Current CSV value
     * @return uint256 Last updated timestamp
     */
    function getCsvWithTimestamp() external view returns (uint256, uint256) {
        return (csvValue, lastUpdated);
    }
    
    /**
     * @dev Check if data is stale
     * @return bool True if data is stale
     */
    function isStale() external view returns (bool) {
        return block.timestamp - lastUpdated > STALENESS_THRESHOLD;
    }
}