// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IComplianceRegistry.sol";
import "./interfaces/ICSVOracle.sol";

/**
 * @title ERCRWACSV
 * @dev ERC-RWA:CSV compliant token for tokenized insurance cash surrender values
 * Features:
 * - Compliance-by-Design™ transfer restrictions
 * - LTV enforcement with oracle integration
 * - Burn-on-redeem mechanism
 * - Role-based access control
 * - Emergency pause functionality
 */
contract ERCRWACSV is ERC721, AccessControl, Pausable, ReentrancyGuard {
    using Counters for Counters.Counter;
    
    // Roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant ORACLE_UPDATER_ROLE = keccak256("ORACLE_UPDATER_ROLE");
    
    // Token counter
    Counters.Counter private _tokenIdCounter;
    
    // Compliance and Oracle contracts
    IComplianceRegistry public complianceRegistry;
    ICSVOracle public csvOracle;
    
    // Token metadata
    struct TokenData {
        string policyId;
        uint256 csvValue;
        uint256 ltvRatio; // Basis points (e.g., 9000 = 90%)
        uint256 issuanceTimestamp;
        bool isRedeemed;
    }
    
    mapping(uint256 => TokenData) public tokenData;
    mapping(string => uint256) public policyToToken;
    
    // LTV configuration
    uint256 public constant MAX_LTV_RATIO = 9000; // 90% max LTV
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public maxOracleStale = 24 hours;
    
    // Events
    event TokenMinted(
        uint256 indexed tokenId,
        address indexed to,
        string policyId,
        uint256 csvValue,
        uint256 ltvRatio
    );
    
    event TokenRedeemed(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 redemptionValue
    );
    
    event LTVUpdated(
        uint256 indexed tokenId,
        uint256 oldLTV,
        uint256 newLTV
    );
    
    event OracleUpdated(address newOracle);
    event ComplianceRegistryUpdated(address newRegistry);
    
    constructor(
        address _complianceRegistry,
        address _csvOracle
    ) ERC721("iYield Cash Surrender Value", "iYLD-CSV") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(ORACLE_UPDATER_ROLE, msg.sender);
        
        complianceRegistry = IComplianceRegistry(_complianceRegistry);
        csvOracle = ICSVOracle(_csvOracle);
    }
    
    /**
     * @dev Mint a new token representing a CSV-backed position
     * @param to Address to mint to
     * @param policyId Unique policy identifier
     * @param csvValue Current CSV value from oracle
     * @param ltvRatio LTV ratio in basis points
     */
    function safeMint(
        address to,
        string memory policyId,
        uint256 csvValue,
        uint256 ltvRatio
    ) public onlyRole(MINTER_ROLE) nonReentrant whenNotPaused {
        require(bytes(policyId).length > 0, "Invalid policy ID");
        require(csvValue > 0, "CSV value must be positive");
        require(ltvRatio <= MAX_LTV_RATIO, "LTV ratio too high");
        require(policyToToken[policyId] == 0, "Policy already tokenized");
        require(complianceRegistry.isCompliant(to), "Address not compliant");
        
        // Verify oracle data is fresh
        (uint256 oracleValue, uint256 timestamp) = csvOracle.getCSVValue(policyId);
        require(block.timestamp - timestamp <= maxOracleStale, "Oracle data stale");
        require(oracleValue == csvValue, "CSV value mismatch");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        tokenData[tokenId] = TokenData({
            policyId: policyId,
            csvValue: csvValue,
            ltvRatio: ltvRatio,
            issuanceTimestamp: block.timestamp,
            isRedeemed: false
        });
        
        policyToToken[policyId] = tokenId;
        
        _safeMint(to, tokenId);
        
        emit TokenMinted(tokenId, to, policyId, csvValue, ltvRatio);
    }
    
    /**
     * @dev Redeem a token and burn it
     * @param tokenId Token to redeem
     */
    function redeem(uint256 tokenId) external nonReentrant whenNotPaused {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        require(!tokenData[tokenId].isRedeemed, "Token already redeemed");
        
        TokenData storage data = tokenData[tokenId];
        
        // Get current CSV value from oracle
        (uint256 currentValue, uint256 timestamp) = csvOracle.getCSVValue(data.policyId);
        require(block.timestamp - timestamp <= maxOracleStale, "Oracle data stale");
        
        data.isRedeemed = true;
        
        _burn(tokenId);
        
        emit TokenRedeemed(tokenId, msg.sender, currentValue);
    }
    
    /**
     * @dev Update LTV ratio for a token (oracle updater only)
     */
    function updateLTV(
        uint256 tokenId,
        uint256 newLtvRatio
    ) external onlyRole(ORACLE_UPDATER_ROLE) {
        require(_exists(tokenId), "Token does not exist");
        require(newLtvRatio <= MAX_LTV_RATIO, "LTV ratio too high");
        require(!tokenData[tokenId].isRedeemed, "Token already redeemed");
        
        uint256 oldLTV = tokenData[tokenId].ltvRatio;
        tokenData[tokenId].ltvRatio = newLtvRatio;
        
        emit LTVUpdated(tokenId, oldLTV, newLtvRatio);
    }
    
    /**
     * @dev Override transfer functions for compliance checks
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override whenNotPaused {
        if (from != address(0) && to != address(0)) {
            // Check compliance for transfers (not minting/burning)
            require(complianceRegistry.isCompliant(from), "From address not compliant");
            require(complianceRegistry.isCompliant(to), "To address not compliant");
            require(complianceRegistry.canTransfer(from, to), "Transfer not allowed");
        }
        
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }
    
    /**
     * @dev Check if oracle data is stale for a token
     */
    function isOracleStale(uint256 tokenId) external view returns (bool) {
        require(_exists(tokenId), "Token does not exist");
        
        (, uint256 timestamp) = csvOracle.getCSVValue(tokenData[tokenId].policyId);
        return block.timestamp - timestamp > maxOracleStale;
    }
    
    /**
     * @dev Get current LTV ratio with fresh oracle data
     */
    function getCurrentLTV(uint256 tokenId) external view returns (uint256) {
        require(_exists(tokenId), "Token does not exist");
        
        TokenData memory data = tokenData[tokenId];
        (uint256 currentValue,) = csvOracle.getCSVValue(data.policyId);
        
        if (currentValue == 0) return 0;
        
        // Calculate current LTV based on token value vs CSV value
        uint256 tokenValue = (data.csvValue * data.ltvRatio) / BASIS_POINTS;
        return (tokenValue * BASIS_POINTS) / currentValue;
    }
    
    /**
     * @dev Admin functions
     */
    function setComplianceRegistry(address _registry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        complianceRegistry = IComplianceRegistry(_registry);
        emit ComplianceRegistryUpdated(_registry);
    }
    
    function setCSVOracle(address _oracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        csvOracle = ICSVOracle(_oracle);
        emit OracleUpdated(_oracle);
    }
    
    function setMaxOracleStale(uint256 _maxStale) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxOracleStale = _maxStale;
    }
    
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }
    
    /**
     * @dev Get total number of tokens minted
     */
    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current();
    }
    
    // The following functions are overrides required by Solidity.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}