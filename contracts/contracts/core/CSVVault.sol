// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IERC_RWA_CSV.sol";

/**
 * @title CSVVault
 * @dev Vault for managing CSV-backed token issuance and redemption with burn-on-redeem mechanism
 * @notice This contract manages the collateralization and redemption of insurance CSV tokens
 */
contract CSVVault is AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    
    // Role definitions
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    // Vault configuration
    struct VaultConfig {
        uint256 maxLTV;                 // Maximum loan-to-value ratio (basis points)
        uint256 liquidationThreshold;  // LTV threshold for liquidation (basis points)  
        uint256 liquidationPenalty;    // Penalty for liquidation (basis points)
        uint256 minCollateralRatio;    // Minimum collateral ratio (basis points)
        uint256 redemptionFee;         // Fee for redemption (basis points)
        bool paused;                   // Emergency pause state
    }
    
    // Position tracking
    struct Position {
        uint256 collateralAmount;      // Amount of CSV collateral
        uint256 tokensIssued;          // Amount of tokens issued against collateral
        uint256 lastUpdate;           // Last update timestamp
        bytes32 carrierId;            // Insurance carrier ID
        bool active;                  // Position status
    }
    
    // Storage
    VaultConfig public vaultConfig;
    IERC_RWA_CSV public immutable csvToken;
    ICSVOracle public immutable oracle;
    IComplianceRegistry public immutable complianceRegistry;
    
    mapping(address => Position) public positions;
    mapping(bytes32 => uint256) public carrierCollateral; // Track collateral by carrier
    
    uint256 public totalCollateral;
    uint256 public totalIssued;
    uint256 public totalRedeemed;
    
    // Redemption queue for managing liquidity
    struct RedemptionRequest {
        address user;
        uint256 amount;
        uint256 timestamp;
        bool processed;
    }
    
    RedemptionRequest[] public redemptionQueue;
    mapping(address => uint256) public pendingRedemptions;
    
    // Events
    event CollateralDeposited(address indexed user, uint256 amount, bytes32 carrierId);
    event TokensIssued(address indexed user, uint256 tokenAmount, uint256 collateralAmount);
    event RedemptionRequested(address indexed user, uint256 amount, uint256 queueIndex);
    event RedemptionProcessed(address indexed user, uint256 amount, uint256 collateralReleased);
    event PositionLiquidated(address indexed user, uint256 collateralSeized, uint256 tokensBurned);
    event VaultConfigUpdated(VaultConfig oldConfig, VaultConfig newConfig);
    event EmergencyWithdrawal(address indexed user, uint256 amount);
    
    modifier whenNotPaused() {
        require(!vaultConfig.paused, "Vault paused");
        _;
    }
    
    modifier validPosition(address user) {
        require(positions[user].active, "No active position");
        _;
    }
    
    modifier compliantUser(address user) {
        require(complianceRegistry.isKYCVerified(user), "User not KYC verified");
        require(complianceRegistry.isAccreditedInvestor(user), "User not accredited");
        _;
    }
    
    constructor(
        address _csvToken,
        address _oracle,
        address _complianceRegistry,
        address _admin
    ) {
        require(_csvToken != address(0), "Invalid CSV token");
        require(_oracle != address(0), "Invalid oracle");
        require(_complianceRegistry != address(0), "Invalid compliance registry");
        require(_admin != address(0), "Invalid admin");
        
        csvToken = IERC_RWA_CSV(_csvToken);
        oracle = ICSVOracle(_oracle);
        complianceRegistry = IComplianceRegistry(_complianceRegistry);
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(VAULT_MANAGER_ROLE, _admin);
        _grantRole(LIQUIDATOR_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        
        // Initialize vault configuration
        vaultConfig = VaultConfig({
            maxLTV: 8000,              // 80%
            liquidationThreshold: 8500, // 85%
            liquidationPenalty: 1000,   // 10%
            minCollateralRatio: 12000,  // 120%
            redemptionFee: 50,          // 0.5%
            paused: false
        });
    }
    
    /**
     * @dev Deposit CSV collateral and issue tokens
     */
    function depositAndIssue(
        uint256 collateralAmount,
        uint256 tokenAmount,
        bytes32 carrierId
    ) external nonReentrant whenNotPaused compliantUser(msg.sender) {
        require(collateralAmount > 0, "Invalid collateral amount");
        require(tokenAmount > 0, "Invalid token amount");
        
        // Verify carrier exists and is active
        ICSVOracle.CarrierData memory carrier = oracle.getCarrierData(carrierId);
        require(carrier.isActive, "Carrier not active");
        
        // Check oracle freshness
        ICSVOracle.ValuationData memory valuation = oracle.getLatestValuation();
        require(
            block.timestamp - valuation.timestamp <= csvToken.getMaxOracleStale(),
            "Oracle data stale"
        );
        
        // Calculate LTV and ensure it's within limits
        uint256 ltv = (tokenAmount * 10000) / collateralAmount;
        require(ltv <= vaultConfig.maxLTV, "LTV exceeds maximum");
        
        // Update position
        Position storage position = positions[msg.sender];
        position.collateralAmount += collateralAmount;
        position.tokensIssued += tokenAmount;
        position.lastUpdate = block.timestamp;
        position.carrierId = carrierId;
        position.active = true;
        
        // Update global tracking
        totalCollateral += collateralAmount;
        totalIssued += tokenAmount;
        carrierCollateral[carrierId] += collateralAmount;
        
        // Transfer collateral from user (this would be CSV in a real implementation)
        // For now, we'll mint tokens directly
        // csvToken.mint(msg.sender, tokenAmount); // Would need mint function
        
        emit CollateralDeposited(msg.sender, collateralAmount, carrierId);
        emit TokensIssued(msg.sender, tokenAmount, collateralAmount);
    }
    
    /**
     * @dev Request redemption of tokens for underlying CSV
     */
    function requestRedemption(uint256 tokenAmount) 
        external 
        nonReentrant 
        whenNotPaused 
        validPosition(msg.sender) 
    {
        require(tokenAmount > 0, "Invalid token amount");
        require(csvToken.balanceOf(msg.sender) >= tokenAmount, "Insufficient token balance");
        
        Position storage position = positions[msg.sender];
        require(position.tokensIssued >= tokenAmount, "Insufficient tokens issued");
        
        // Calculate collateral to release
        uint256 collateralToRelease = (tokenAmount * position.collateralAmount) / position.tokensIssued;
        
        // Apply redemption fee
        uint256 fee = (collateralToRelease * vaultConfig.redemptionFee) / 10000;
        collateralToRelease -= fee;
        
        // Add to redemption queue
        redemptionQueue.push(RedemptionRequest({
            user: msg.sender,
            amount: tokenAmount,
            timestamp: block.timestamp,
            processed: false
        }));
        
        pendingRedemptions[msg.sender] += tokenAmount;
        
        // Burn tokens immediately (burn-on-redeem mechanism)
        // csvToken.burn(tokenAmount); // Would need burn function or transfer to vault
        
        emit RedemptionRequested(msg.sender, tokenAmount, redemptionQueue.length - 1);
    }
    
    /**
     * @dev Process redemption requests in queue
     */
    function processRedemptions(uint256 count) 
        external 
        onlyRole(VAULT_MANAGER_ROLE) 
        nonReentrant 
    {
        require(count > 0, "Invalid count");
        uint256 processed = 0;
        
        for (uint256 i = 0; i < redemptionQueue.length && processed < count; i++) {
            RedemptionRequest storage request = redemptionQueue[i];
            
            if (!request.processed) {
                Position storage position = positions[request.user];
                
                // Calculate collateral to release
                uint256 collateralToRelease = (request.amount * position.collateralAmount) / position.tokensIssued;
                uint256 fee = (collateralToRelease * vaultConfig.redemptionFee) / 10000;
                collateralToRelease -= fee;
                
                // Update position
                position.collateralAmount -= (collateralToRelease + fee);
                position.tokensIssued -= request.amount;
                position.lastUpdate = block.timestamp;
                
                if (position.tokensIssued == 0) {
                    position.active = false;
                }
                
                // Update global tracking
                totalCollateral -= (collateralToRelease + fee);
                totalRedeemed += request.amount;
                carrierCollateral[position.carrierId] -= (collateralToRelease + fee);
                
                pendingRedemptions[request.user] -= request.amount;
                request.processed = true;
                
                // Transfer collateral back to user
                // In a real implementation, this would transfer actual CSV
                
                emit RedemptionProcessed(request.user, request.amount, collateralToRelease);
                processed++;
            }
        }
    }
    
    /**
     * @dev Liquidate undercollateralized positions
     */
    function liquidatePosition(address user) 
        external 
        onlyRole(LIQUIDATOR_ROLE) 
        nonReentrant 
        validPosition(user) 
    {
        Position storage position = positions[user];
        
        // Check if position is undercollateralized
        uint256 currentLTV = (position.tokensIssued * 10000) / position.collateralAmount;
        require(currentLTV > vaultConfig.liquidationThreshold, "Position not liquidatable");
        
        // Calculate liquidation amounts
        uint256 tokensToLiquidate = position.tokensIssued;
        uint256 collateralSeized = position.collateralAmount;
        uint256 penalty = (collateralSeized * vaultConfig.liquidationPenalty) / 10000;
        
        // Update global tracking
        totalCollateral -= collateralSeized;
        totalIssued -= tokensToLiquidate;
        carrierCollateral[position.carrierId] -= collateralSeized;
        
        // Clear position
        delete positions[user];
        
        emit PositionLiquidated(user, collateralSeized, tokensToLiquidate);
    }
    
    /**
     * @dev Update vault configuration
     */
    function updateVaultConfig(VaultConfig memory newConfig) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        require(newConfig.maxLTV <= 9000, "Max LTV too high");
        require(newConfig.liquidationThreshold > newConfig.maxLTV, "Invalid liquidation threshold");
        require(newConfig.liquidationPenalty <= 2000, "Penalty too high");
        require(newConfig.minCollateralRatio >= 11000, "Min collateral ratio too low");
        require(newConfig.redemptionFee <= 1000, "Redemption fee too high");
        
        VaultConfig memory oldConfig = vaultConfig;
        vaultConfig = newConfig;
        
        emit VaultConfigUpdated(oldConfig, newConfig);
    }
    
    /**
     * @dev Emergency pause/unpause
     */
    function setPause(bool _paused) external onlyRole(EMERGENCY_ROLE) {
        vaultConfig.paused = _paused;
    }
    
    /**
     * @dev Emergency withdrawal (only when paused)
     */
    function emergencyWithdraw(address user) 
        external 
        onlyRole(EMERGENCY_ROLE) 
        validPosition(user) 
    {
        require(vaultConfig.paused, "Not in emergency mode");
        
        Position storage position = positions[user];
        uint256 collateralAmount = position.collateralAmount;
        
        // Update global tracking
        totalCollateral -= collateralAmount;
        carrierCollateral[position.carrierId] -= collateralAmount;
        
        // Clear position
        delete positions[user];
        
        emit EmergencyWithdrawal(user, collateralAmount);
    }
    
    // View functions
    
    function getPosition(address user) external view returns (Position memory) {
        return positions[user];
    }
    
    function getCurrentLTV(address user) external view returns (uint256) {
        Position memory position = positions[user];
        if (position.collateralAmount == 0) return 0;
        return (position.tokensIssued * 10000) / position.collateralAmount;
    }
    
    function isLiquidatable(address user) external view returns (bool) {
        if (!positions[user].active) return false;
        uint256 ltv = (positions[user].tokensIssued * 10000) / positions[user].collateralAmount;
        return ltv > vaultConfig.liquidationThreshold;
    }
    
    function getRedemptionQueueLength() external view returns (uint256) {
        return redemptionQueue.length;
    }
    
    function getCarrierCollateral(bytes32 carrierId) external view returns (uint256) {
        return carrierCollateral[carrierId];
    }
    
    function getVaultStats() external view returns (
        uint256 _totalCollateral,
        uint256 _totalIssued,
        uint256 _totalRedeemed,
        uint256 _globalLTV
    ) {
        _totalCollateral = totalCollateral;
        _totalIssued = totalIssued;
        _totalRedeemed = totalRedeemed;
        _globalLTV = totalCollateral > 0 ? (totalIssued * 10000) / totalCollateral : 0;
    }
}