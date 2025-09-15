// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ComplianceRegistry.sol";

/**
 * @title iYieldToken
 * @dev ERC20 token with compliance features for the iYield protocol
 */
contract iYieldToken is ERC20, Ownable {
    ComplianceRegistry public complianceRegistry;
    
    mapping(address => bool) public minters;
    mapping(address => bool) public burners;
    
    event MinterAdded(address indexed minter);
    event MinterRemoved(address indexed minter);
    event BurnerAdded(address indexed burner);
    event BurnerRemoved(address indexed burner);
    
    modifier onlyMinter() {
        require(minters[msg.sender], "Not authorized to mint");
        _;
    }
    
    modifier onlyBurner() {
        require(burners[msg.sender], "Not authorized to burn");
        _;
    }
    
    modifier onlyWhitelisted(address user) {
        require(complianceRegistry.isWhitelisted(user), "User not whitelisted");
        _;
    }
    
    constructor(address _complianceRegistry) 
        ERC20("iYield Token", "iYLD") 
        Ownable(msg.sender) 
    {
        complianceRegistry = ComplianceRegistry(_complianceRegistry);
    }
    
    /**
     * @dev Add minter role to address
     * @param minter Address to add as minter
     */
    function addMinter(address minter) external onlyOwner {
        minters[minter] = true;
        emit MinterAdded(minter);
    }
    
    /**
     * @dev Remove minter role from address
     * @param minter Address to remove as minter
     */
    function removeMinter(address minter) external onlyOwner {
        minters[minter] = false;
        emit MinterRemoved(minter);
    }
    
    /**
     * @dev Add burner role to address
     * @param burner Address to add as burner
     */
    function addBurner(address burner) external onlyOwner {
        burners[burner] = true;
        emit BurnerAdded(burner);
    }
    
    /**
     * @dev Remove burner role from address
     * @param burner Address to remove as burner
     */
    function removeBurner(address burner) external onlyOwner {
        burners[burner] = false;
        emit BurnerRemoved(burner);
    }
    
    /**
     * @dev Mint tokens to whitelisted address
     * @param to Address to mint to
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external onlyMinter onlyWhitelisted(to) {
        _mint(to, amount);
    }
    
    /**
     * @dev Burn tokens from address
     * @param from Address to burn from
     * @param amount Amount to burn
     */
    function burnFrom(address from, uint256 amount) external onlyBurner {
        _burn(from, amount);
    }
    
    /**
     * @dev Override transfer to include compliance check
     */
    function transfer(address to, uint256 amount) public override onlyWhitelisted(to) returns (bool) {
        return super.transfer(to, amount);
    }
    
    /**
     * @dev Override transferFrom to include compliance check
     */
    function transferFrom(address from, address to, uint256 amount) public override onlyWhitelisted(to) returns (bool) {
        return super.transferFrom(from, to, amount);
    }
}