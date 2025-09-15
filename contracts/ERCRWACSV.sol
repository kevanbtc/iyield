// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title ERCRWACSV
 * @dev ERC-RWA:CSV implementation for tokenized life insurance assets
 * @notice This contract implements the iYield Protocol standard for insurance-backed RWAs
 */
contract ERCRWACSV is ERC721, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    struct PolicyData {
        uint256 csvValue;          // Current Cash Surrender Value
        uint256 lastValuation;     // Timestamp of last valuation
        uint256 maxLTV;           // Maximum Loan-to-Value ratio
        bool isCompliant;         // Compliance status
        string ipfsHash;          // IPFS hash for policy documents
    }

    mapping(uint256 => PolicyData) public policies;
    mapping(address => bool) public compliantAddresses;
    
    uint256 private _tokenCounter;
    uint256 public globalMaxLTV = 8000; // 80% in basis points

    event CSVUpdated(uint256 indexed tokenId, uint256 newValue, uint256 timestamp);
    event ComplianceUpdated(address indexed account, bool status);
    event LTVRatchetTriggered(uint256 indexed tokenId, uint256 newMaxLTV);

    constructor() ERC721("iYield Insurance Token", "iYLD") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(ORACLE_ROLE, msg.sender);
        _grantRole(COMPLIANCE_ROLE, msg.sender);
    }

    /**
     * @dev Check if transfer is allowed based on compliance rules
     */
    function isTransferAllowed(address from, address to, uint256 tokenId) 
        public view returns (bool) {
        return compliantAddresses[from] && compliantAddresses[to] && 
               policies[tokenId].isCompliant;
    }

    /**
     * @dev Update CSV valuation with oracle data
     */
    function updateCSVValuation(uint256 tokenId, uint256 csvValue, string memory merkleProof)
        external onlyRole(ORACLE_ROLE) {
        require(_exists(tokenId), "Token does not exist");
        
        policies[tokenId].csvValue = csvValue;
        policies[tokenId].lastValuation = block.timestamp;
        
        emit CSVUpdated(tokenId, csvValue, block.timestamp);
    }

    /**
     * @dev Get current CSV value for a token
     */
    function getCurrentCSV(uint256 tokenId) external view returns (uint256) {
        require(_exists(tokenId), "Token does not exist");
        return policies[tokenId].csvValue;
    }

    /**
     * @dev Override transfer to enforce compliance
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal override whenNotPaused {
        if (from != address(0) && to != address(0)) {
            require(isTransferAllowed(from, to, tokenId), "Transfer not compliant");
        }
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    /**
     * @dev Mint new insurance token
     */
    function mintInsuranceToken(
        address to,
        uint256 csvValue,
        string memory ipfsHash
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 tokenId = _tokenCounter++;
        
        policies[tokenId] = PolicyData({
            csvValue: csvValue,
            lastValuation: block.timestamp,
            maxLTV: globalMaxLTV,
            isCompliant: true,
            ipfsHash: ipfsHash
        });

        _safeMint(to, tokenId);
        return tokenId;
    }

    /**
     * @dev Set compliance status for an address
     */
    function setCompliance(address account, bool status) 
        external onlyRole(COMPLIANCE_ROLE) {
        compliantAddresses[account] = status;
        emit ComplianceUpdated(account, status);
    }

    /**
     * @dev Emergency pause function
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause function
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}