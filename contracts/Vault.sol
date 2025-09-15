// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./iYieldToken.sol";
import "./OracleAdapter.sol";

/**
 * @title Vault
 * @dev Core vault contract for the iYield protocol
 * Handles deposits, withdrawals, and token minting based on CSV values
 */
contract Vault is ReentrancyGuard, Ownable {
    iYieldToken public yieldToken;
    OracleAdapter public oracle;
    
    uint256 public totalDeposits;
    uint256 public collateralRatio = 150; // 150% collateralization
    uint256 public constant BASIS_POINTS = 10000;
    
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public mintedTokens;
    
    event Deposit(address indexed user, uint256 amount, uint256 tokensIssued);
    event Withdrawal(address indexed user, uint256 amount, uint256 tokensBurned);
    event CollateralRatioUpdated(uint256 newRatio);
    
    modifier validAmount(uint256 amount) {
        require(amount > 0, "Amount must be greater than 0");
        _;
    }
    
    constructor(address _yieldToken, address _oracle) Ownable(msg.sender) {
        yieldToken = iYieldToken(_yieldToken);
        oracle = OracleAdapter(_oracle);
    }
    
    /**
     * @dev Deposit ETH and mint iYield tokens
     */
    function deposit(uint256 amount) external payable validAmount(msg.value) nonReentrant {
        require(msg.value == amount, "Value mismatch");
        
        uint256 csvValue = oracle.getCSV();
        uint256 tokensToMint = calculateTokensToMint(amount, csvValue);
        
        deposits[msg.sender] += amount;
        mintedTokens[msg.sender] += tokensToMint;
        totalDeposits += amount;
        
        yieldToken.mint(msg.sender, tokensToMint);
        
        emit Deposit(msg.sender, amount, tokensToMint);
    }
    
    /**
     * @dev Withdraw ETH by burning iYield tokens
     * @param tokenAmount Amount of tokens to burn
     */
    function withdraw(uint256 tokenAmount) external validAmount(tokenAmount) nonReentrant {
        require(mintedTokens[msg.sender] >= tokenAmount, "Insufficient minted tokens");
        
        uint256 csvValue = oracle.getCSV();
        uint256 ethToReturn = calculateEthToReturn(tokenAmount, csvValue);
        
        require(address(this).balance >= ethToReturn, "Insufficient vault balance");
        require(deposits[msg.sender] >= ethToReturn, "Withdrawal exceeds deposits");
        
        deposits[msg.sender] -= ethToReturn;
        mintedTokens[msg.sender] -= tokenAmount;
        totalDeposits -= ethToReturn;
        
        yieldToken.burnFrom(msg.sender, tokenAmount);
        
        payable(msg.sender).transfer(ethToReturn);
        
        emit Withdrawal(msg.sender, ethToReturn, tokenAmount);
    }
    
    /**
     * @dev Calculate tokens to mint based on deposit and CSV
     * @param depositAmount Amount of ETH deposited
     * @param csvValue Current CSV value
     * @return uint256 Tokens to mint
     */
    function calculateTokensToMint(uint256 depositAmount, uint256 csvValue) public view returns (uint256) {
        // Simplified calculation: tokens = (deposit * collateralRatio) / (csvValue * 100)
        // This ensures over-collateralization
        return (depositAmount * collateralRatio * 1e18) / (csvValue * BASIS_POINTS);
    }
    
    /**
     * @dev Calculate ETH to return based on tokens and CSV
     * @param tokenAmount Amount of tokens being burned
     * @param csvValue Current CSV value
     * @return uint256 ETH to return
     */
    function calculateEthToReturn(uint256 tokenAmount, uint256 csvValue) public view returns (uint256) {
        // Reverse calculation: eth = (tokens * csvValue * 100) / collateralRatio
        return (tokenAmount * csvValue * BASIS_POINTS) / (collateralRatio * 1e18);
    }
    
    /**
     * @dev Update collateral ratio (only owner)
     * @param newRatio New collateral ratio in basis points
     */
    function updateCollateralRatio(uint256 newRatio) external onlyOwner {
        require(newRatio >= 100, "Ratio must be at least 100%");
        collateralRatio = newRatio;
        emit CollateralRatioUpdated(newRatio);
    }
    
    /**
     * @dev Get user's deposit information
     * @param user User address
     * @return depositAmount User's total deposits
     * @return tokensMinted User's minted tokens
     */
    function getUserInfo(address user) external view returns (uint256 depositAmount, uint256 tokensMinted) {
        return (deposits[user], mintedTokens[user]);
    }
    
    /**
     * @dev Emergency withdrawal by owner
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}