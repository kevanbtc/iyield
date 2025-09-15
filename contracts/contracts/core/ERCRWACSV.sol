// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ERCRWACSV
 * @dev ERC-RWA:CSV Token Standard for Insurance Cash Surrender Value tokenization
 * @notice This contract implements the first comprehensive token standard for insurance-backed securities
 */
contract ERCRWACSV is ERC20, ERC20Permit, AccessControl, Pausable, ReentrancyGuard {
    
    // Role definitions
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    
    // Token metadata
    struct CSVMetadata {
        string policyNumber;
        string carrierName;
        uint256 cashValue;
        uint256 deathBenefit;
        uint256 premiumAmount;
        uint256 policyAge;
        uint8 creditRating; // 1-5 scale (5 = AAA, 1 = C)
        uint256 lastValuationTimestamp;
        bool isActive;
    }
    
    // Compliance structure
    struct ComplianceData {
        bool isAccredited;
        bool isKYCVerified;
        uint256 jurisdictionCode;
        uint256 lockupExpiry;
        bool isRestricted;
    }
    
    // Storage
    mapping(uint256 => CSVMetadata) private _csvMetadata;
    mapping(address => ComplianceData) private _complianceData;
    mapping(uint256 => address) private _tokenToOwner;
    mapping(address => uint256[]) private _ownerTokens;
    
    uint256 private _nextTokenId = 1;
    uint256 public totalCSVValue;
    address public complianceRegistry;
    address public csvOracle;
    
    // Events
    event CSVTokenMinted(uint256 indexed tokenId, address indexed to, uint256 csvValue);
    event CSVTokenBurned(uint256 indexed tokenId, address indexed from, uint256 csvValue);
    event CSVValuationUpdated(uint256 indexed tokenId, uint256 oldValue, uint256 newValue);
    event ComplianceUpdated(address indexed account, bool kyc, bool accredited);
    event TransferRestricted(address indexed from, address indexed to, string reason);
    
    // Modifiers
    modifier onlyCompliant(address account) {
        require(_complianceData[account].isKYCVerified, "ERCRWACSV: Account not KYC verified");
        require(_complianceData[account].isAccredited, "ERCRWACSV: Account not accredited");
        require(!_complianceData[account].isRestricted, "ERCRWACSV: Account restricted");
        _;
    }
    
    modifier notUnderLockup(address account) {
        require(
            block.timestamp >= _complianceData[account].lockupExpiry,
            "ERCRWACSV: Account under lockup period"
        );
        _;
    }
    
    constructor(
        string memory name,
        string memory symbol,
        address _complianceRegistry,
        address _csvOracle
    ) ERC20(name, symbol) ERC20Permit(name) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(BURNER_ROLE, msg.sender);
        _grantRole(COMPLIANCE_ROLE, msg.sender);
        _grantRole(PAUSE_ROLE, msg.sender);
        
        complianceRegistry = _complianceRegistry;
        csvOracle = _csvOracle;
    }
    
    /**
     * @dev Mint CSV-backed tokens
     */
    function mintCSVToken(
        address to,
        uint256 amount,
        CSVMetadata memory metadata
    ) external onlyRole(MINTER_ROLE) onlyCompliant(to) nonReentrant {
        require(to != address(0), "ERCRWACSV: mint to zero address");
        require(amount > 0, "ERCRWACSV: amount must be positive");
        require(metadata.cashValue > 0, "ERCRWACSV: CSV value must be positive");
        
        uint256 tokenId = _nextTokenId++;
        _csvMetadata[tokenId] = metadata;
        _tokenToOwner[tokenId] = to;
        _ownerTokens[to].push(tokenId);
        
        totalCSVValue += metadata.cashValue;
        
        _mint(to, amount);
        
        emit CSVTokenMinted(tokenId, to, metadata.cashValue);
    }
    
    /**
     * @dev Burn CSV-backed tokens on policy redemption
     */
    function burnCSVToken(
        address from,
        uint256 amount,
        uint256 tokenId
    ) external onlyRole(BURNER_ROLE) nonReentrant {
        require(from != address(0), "ERCRWACSV: burn from zero address");
        require(amount > 0, "ERCRWACSV: amount must be positive");
        require(_tokenToOwner[tokenId] == from, "ERCRWACSV: not token owner");
        
        CSVMetadata storage metadata = _csvMetadata[tokenId];
        require(metadata.isActive, "ERCRWACSV: token not active");
        
        totalCSVValue -= metadata.cashValue;
        metadata.isActive = false;
        
        _burn(from, amount);
        
        emit CSVTokenBurned(tokenId, from, metadata.cashValue);
    }
    
    /**
     * @dev Update CSV valuation via oracle
     */
    function updateCSVValuation(
        uint256 tokenId,
        uint256 newValue
    ) external onlyRole(ORACLE_ROLE) {
        CSVMetadata storage metadata = _csvMetadata[tokenId];
        require(metadata.isActive, "ERCRWACSV: token not active");
        
        uint256 oldValue = metadata.cashValue;
        metadata.cashValue = newValue;
        metadata.lastValuationTimestamp = block.timestamp;
        
        totalCSVValue = totalCSVValue - oldValue + newValue;
        
        emit CSVValuationUpdated(tokenId, oldValue, newValue);
    }
    
    /**
     * @dev Update compliance status
     */
    function updateCompliance(
        address account,
        ComplianceData memory complianceData
    ) external onlyRole(COMPLIANCE_ROLE) {
        _complianceData[account] = complianceData;
        
        emit ComplianceUpdated(
            account,
            complianceData.isKYCVerified,
            complianceData.isAccredited
        );
    }
    
    /**
     * @dev Override transfer to include compliance checks
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        if (from != address(0) && to != address(0)) {
            // Check compliance for both parties
            require(
                _complianceData[from].isKYCVerified && _complianceData[to].isKYCVerified,
                "ERCRWACSV: KYC verification required"
            );
            require(
                _complianceData[from].isAccredited && _complianceData[to].isAccredited,
                "ERCRWACSV: Accredited investor status required"
            );
            require(
                block.timestamp >= _complianceData[from].lockupExpiry,
                "ERCRWACSV: Sender under lockup period"
            );
            require(
                !_complianceData[from].isRestricted && !_complianceData[to].isRestricted,
                "ERCRWACSV: Account restricted"
            );
        }
        
        super._beforeTokenTransfer(from, to, amount);
    }
    
    // View functions
    function getCSVMetadata(uint256 tokenId) external view returns (CSVMetadata memory) {
        return _csvMetadata[tokenId];
    }
    
    function getComplianceData(address account) external view returns (ComplianceData memory) {
        return _complianceData[account];
    }
    
    function getOwnerTokens(address owner) external view returns (uint256[] memory) {
        return _ownerTokens[owner];
    }
    
    function isTransferAllowed(address from, address to) external view returns (bool, string memory) {
        if (!_complianceData[from].isKYCVerified || !_complianceData[to].isKYCVerified) {
            return (false, "KYC verification required");
        }
        if (!_complianceData[from].isAccredited || !_complianceData[to].isAccredited) {
            return (false, "Accredited investor status required");
        }
        if (block.timestamp < _complianceData[from].lockupExpiry) {
            return (false, "Sender under lockup period");
        }
        if (_complianceData[from].isRestricted || _complianceData[to].isRestricted) {
            return (false, "Account restricted");
        }
        return (true, "Transfer allowed");
    }
    
    // Admin functions
    function pause() external onlyRole(PAUSE_ROLE) {
        _pause();
    }
    
    function unpause() external onlyRole(PAUSE_ROLE) {
        _unpause();
    }
    
    function setComplianceRegistry(address _complianceRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        complianceRegistry = _complianceRegistry;
    }
    
    function setCSVOracle(address _csvOracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        csvOracle = _csvOracle;
    }
    
    // Required overrides
    function supportsInterface(bytes4 interfaceId) public view virtual override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}