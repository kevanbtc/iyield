// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "../interfaces/IERC_RWA_CSV.sol";

/**
 * @title CSVVault
 * @dev Vault contract with carrier concentration caps and policy vintage gating
 * @notice This contract manages CSV deposits with enhanced risk controls
 */
contract CSVVault is AccessControl, ReentrancyGuard, Pausable, ICSVVault {
    
    // Role definitions
    bytes32 public constant VAULT_MANAGER_ROLE = keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant RISK_MANAGER_ROLE = keccak256("RISK_MANAGER_ROLE");
    
    // Vault configuration
    VaultConfiguration public config;
    
    // Concentration tracking
    mapping(bytes32 => uint256) public carrierExposure; // carrierId => CSV amount
    mapping(string => uint256) public jurisdictionExposure; // jurisdiction => CSV amount
    mapping(address => uint256) public accountTokens; // account => token balance
    mapping(address => uint256) public accountCSVValue; // account => CSV value
    
    uint256 public totalExposure;
    uint256 public totalTokensIssued;
    uint256 public lastConcentrationUpdate;
    
    // Policy tracking
    mapping(bytes32 => PolicyPosition) public policyPositions;
    mapping(address => bytes32[]) public accountPolicies;
    
    struct PolicyPosition {
        bytes32 policyId;
        address owner;
        uint256 csvValue;
        uint256 vintage; // Policy inception timestamp
        bytes32 carrierId;
        string jurisdiction;
        bool isActive;
        uint256 depositTimestamp;
    }
    
    // Integration contracts
    ICSVOracle public immutable oracle;
    IERC_RWA_CSV public immutable token;
    
    // Events
    event Deposit(
        address indexed account, 
        bytes32[] policyIds,
        uint256 totalCSVAmount, 
        uint256 tokensIssued,
        uint256 timestamp
    );
    event Withdrawal(
        address indexed account, 
        uint256 tokenAmount, 
        uint256 csvReturned,
        bytes32[] policyIds
    );
    event Liquidation(
        address indexed account, 
        uint256 tokenAmount, 
        uint256 csvLiquidated,
        string reason
    );
    event ConcentrationLimitUpdated(
        uint256 oldLimit, 
        uint256 newLimit,
        uint256 timestamp
    );
    event VintageRequirementUpdated(
        uint256 oldVintage, 
        uint256 newVintage,
        uint256 timestamp
    );
    event EmergencyPause(bool paused, string reason);
    event PolicyAdded(
        bytes32 indexed policyId,
        address indexed owner,
        uint256 csvValue,
        bytes32 carrierId
    );
    event PolicyRemoved(
        bytes32 indexed policyId,
        address indexed owner,
        string reason
    );
    event ConcentrationViolation(
        bytes32 carrierId,
        uint256 currentExposure,
        uint256 limit,
        uint256 timestamp
    );
    event VintageViolation(
        bytes32 policyId,
        uint256 policyVintage,
        uint256 minRequired,
        uint256 timestamp
    );
    
    modifier onlyValidPolicy(bytes32 policyId) {
        require(policyPositions[policyId].isActive, "Policy not active");
        _;
    }
    
    modifier onlyPolicyOwner(bytes32 policyId) {
        require(policyPositions[policyId].owner == msg.sender, "Not policy owner");
        _;
    }
    
    modifier concentrationCheck(bytes32 carrierId, uint256 additionalAmount) {
        require(
            checkConcentrationLimits(carrierId, additionalAmount),
            "Would exceed carrier concentration limit"
        );
        _;
    }
    
    modifier vintageCheck(bytes32[] memory policyIds) {
        require(
            checkVintageRequirements(policyIds),
            "Policy vintage requirements not met"
        );
        _;
    }

    constructor(
        address _oracle,
        address _token,
        address _admin,
        uint256 _maxCarrierConcentration, // e.g., 3000 for 30%
        uint256 _minPolicyVintage // minimum age in seconds
    ) {
        require(_oracle != address(0), "Invalid oracle address");
        require(_token != address(0), "Invalid token address");
        require(_admin != address(0), "Invalid admin address");
        require(_maxCarrierConcentration <= 10000, "Concentration too high");
        require(_maxCarrierConcentration > 0, "Concentration too low");
        
        oracle = ICSVOracle(_oracle);
        token = IERC_RWA_CSV(_token);
        
        // Initialize configuration
        config = VaultConfiguration({
            maxCarrierConcentration: _maxCarrierConcentration,
            minPolicyVintage: _minPolicyVintage,
            maxLTV: 8000, // 80%
            liquidationThreshold: 8500, // 85%
            emergencyPaused: false
        });
        
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(VAULT_MANAGER_ROLE, _admin);
        _grantRole(LIQUIDATOR_ROLE, _admin);
        _grantRole(RISK_MANAGER_ROLE, _admin);
        
        lastConcentrationUpdate = block.timestamp;
    }
    
    /**
     * @dev Deposit CSV policies and receive tokens with pre-mint checks
     */
    function deposit(
        bytes32[] calldata policyIds, 
        uint256[] calldata csvValues
    ) external override nonReentrant whenNotPaused vintageCheck(policyIds) returns (uint256 tokensIssued) {
        require(policyIds.length == csvValues.length, "Array length mismatch");
        require(policyIds.length > 0, "No policies provided");
        
        uint256 totalCSV = 0;
        
        // Pre-mint checks for each policy
        for (uint256 i = 0; i < policyIds.length; i++) {
            require(csvValues[i] > 0, "Invalid CSV value");
            require(!policyPositions[policyIds[i]].isActive, "Policy already deposited");
            
            // Get policy data from oracle
            ICSVOracle.PolicyData memory policyData = oracle.getPolicy(policyIds[i]);
            require(policyData.isActive, "Policy not active in oracle");
            require(policyData.csvValue >= csvValues[i], "CSV value too high");
            
            // Check carrier concentration limits
            require(
                checkConcentrationLimits(
                    keccak256(abi.encodePacked(policyData.carrierName)), 
                    csvValues[i]
                ),
                string(abi.encodePacked("Concentration limit exceeded for carrier: ", policyData.carrierName))
            );
            
            totalCSV += csvValues[i];
        }
        
        // Calculate tokens to issue based on current valuation
        tokensIssued = _calculateTokensToIssue(totalCSV);
        
        // Check that issuance doesn't violate LTV limits
        uint256 newLTV = _calculateNewLTV(tokensIssued);
        require(newLTV <= config.maxLTV, "Would exceed maximum LTV ratio");
        
        // Store policy positions
        for (uint256 i = 0; i < policyIds.length; i++) {
            ICSVOracle.PolicyData memory policyData = oracle.getPolicy(policyIds[i]);
            
            policyPositions[policyIds[i]] = PolicyPosition({
                policyId: policyIds[i],
                owner: msg.sender,
                csvValue: csvValues[i],
                vintage: policyData.vintage,
                carrierId: keccak256(abi.encodePacked(policyData.carrierName)),
                jurisdiction: "US", // Simplified - should come from policy data
                isActive: true,
                depositTimestamp: block.timestamp
            });
            
            accountPolicies[msg.sender].push(policyIds[i]);
            
            // Update concentration tracking
            bytes32 carrierId = keccak256(abi.encodePacked(policyData.carrierName));
            carrierExposure[carrierId] += csvValues[i];
            
            emit PolicyAdded(policyIds[i], msg.sender, csvValues[i], carrierId);
        }
        
        // Update account balances
        accountTokens[msg.sender] += tokensIssued;
        accountCSVValue[msg.sender] += totalCSV;
        totalExposure += totalCSV;
        totalTokensIssued += tokensIssued;
        lastConcentrationUpdate = block.timestamp;
        
        // Mint tokens to user
        // Note: This would require the vault to have minting permissions on the token contract
        // token.mint(msg.sender, tokensIssued);
        
        emit Deposit(msg.sender, policyIds, totalCSV, tokensIssued, block.timestamp);
        
        return tokensIssued;
    }
    
    /**
     * @dev Withdraw tokens and return CSV
     */
    function withdraw(uint256 tokenAmount) 
        external 
        override 
        nonReentrant 
        whenNotPaused 
        returns (uint256 csvReturned) 
    {
        require(tokenAmount > 0, "Invalid token amount");
        require(accountTokens[msg.sender] >= tokenAmount, "Insufficient tokens");
        
        // Calculate proportional CSV value
        uint256 totalAccountCSV = accountCSVValue[msg.sender];
        csvReturned = (totalAccountCSV * tokenAmount) / accountTokens[msg.sender];
        
        // Select policies to withdraw (FIFO)
        bytes32[] memory policiesToWithdraw = _selectPoliciesForWithdrawal(msg.sender, csvReturned);
        
        // Update account balances
        accountTokens[msg.sender] -= tokenAmount;
        accountCSVValue[msg.sender] -= csvReturned;
        totalExposure -= csvReturned;
        totalTokensIssued -= tokenAmount;
        
        // Remove policies and update concentration tracking
        for (uint256 i = 0; i < policiesToWithdraw.length; i++) {
            PolicyPosition storage position = policyPositions[policiesToWithdraw[i]];
            carrierExposure[position.carrierId] -= position.csvValue;
            position.isActive = false;
            
            emit PolicyRemoved(policiesToWithdraw[i], msg.sender, "Withdrawal");
        }
        
        // Burn tokens from user
        // token.burnFrom(msg.sender, tokenAmount);
        
        emit Withdrawal(msg.sender, tokenAmount, csvReturned, policiesToWithdraw);
        
        return csvReturned;
    }
    
    /**
     * @dev Liquidate position if LTV exceeds threshold
     */
    function liquidate(address account, uint256 amount) 
        external 
        override 
        onlyRole(LIQUIDATOR_ROLE) 
        nonReentrant 
    {
        require(isLiquidationRequired(account), "Liquidation not required");
        require(accountTokens[account] >= amount, "Insufficient tokens");
        
        uint256 csvLiquidated = (accountCSVValue[account] * amount) / accountTokens[account];
        
        // Update account balances
        accountTokens[account] -= amount;
        accountCSVValue[account] -= csvLiquidated;
        totalExposure -= csvLiquidated;
        totalTokensIssued -= amount;
        
        emit Liquidation(account, amount, csvLiquidated, "LTV threshold exceeded");
    }
    
    /**
     * @dev Check if carrier concentration limits would be violated
     */
    function checkConcentrationLimits(bytes32 carrierId, uint256 additionalAmount) 
        external 
        view 
        override 
        returns (bool allowed) 
    {
        uint256 currentExposure = carrierExposure[carrierId];
        uint256 newExposure = currentExposure + additionalAmount;
        uint256 newTotalExposure = totalExposure + additionalAmount;
        
        if (newTotalExposure == 0) return true;
        
        uint256 concentrationBps = (newExposure * 10000) / newTotalExposure;
        return concentrationBps <= config.maxCarrierConcentration;
    }
    
    /**
     * @dev Check if policy vintage requirements are met
     */
    function checkVintageRequirements(bytes32[] calldata policyIds) 
        external 
        view 
        override 
        returns (bool compliant) 
    {
        for (uint256 i = 0; i < policyIds.length; i++) {
            ICSVOracle.PolicyData memory policyData = oracle.getPolicy(policyIds[i]);
            uint256 policyAge = block.timestamp - policyData.vintage;
            
            if (policyAge < config.minPolicyVintage) {
                emit VintageViolation(
                    policyIds[i], 
                    policyData.vintage, 
                    config.minPolicyVintage,
                    block.timestamp
                );
                return false;
            }
        }
        return true;
    }
    
    /**
     * @dev Calculate current LTV ratio
     */
    function calculateLTV() external view override returns (uint256 currentLTV) {
        if (totalExposure == 0) return 0;
        
        // Get latest CSV valuation from oracle
        ICSVOracle.ValuationData memory valuation = oracle.getLatestValuation();
        
        if (valuation.totalCSV == 0) return 0;
        
        // LTV = (total tokens issued * token value) / total CSV value
        // Simplified: assuming 1:1 token to CSV ratio for now
        return (totalTokensIssued * 10000) / valuation.totalCSV;
    }
    
    /**
     * @dev Check if liquidation is required for an account
     */
    function isLiquidationRequired(address account) 
        external 
        view 
        override 
        returns (bool) 
    {
        if (accountTokens[account] == 0 || accountCSVValue[account] == 0) {
            return false;
        }
        
        uint256 accountLTV = (accountTokens[account] * 10000) / accountCSVValue[account];
        return accountLTV > config.liquidationThreshold;
    }
    
    /**
     * @dev Update concentration limit
     */
    function updateConcentrationLimit(uint256 newLimit) 
        external 
        override 
        onlyRole(RISK_MANAGER_ROLE) 
    {
        require(newLimit <= 10000, "Limit too high");
        require(newLimit > 0, "Limit too low");
        
        uint256 oldLimit = config.maxCarrierConcentration;
        config.maxCarrierConcentration = newLimit;
        
        emit ConcentrationLimitUpdated(oldLimit, newLimit, block.timestamp);
    }
    
    /**
     * @dev Update vintage requirement
     */
    function updateVintageRequirement(uint256 newMinVintage) 
        external 
        override 
        onlyRole(RISK_MANAGER_ROLE) 
    {
        uint256 oldVintage = config.minPolicyVintage;
        config.minPolicyVintage = newMinVintage;
        
        emit VintageRequirementUpdated(oldVintage, newMinVintage, block.timestamp);
    }
    
    /**
     * @dev Update LTV limits
     */
    function updateLTVLimits(uint256 newMaxLTV, uint256 newLiquidationThreshold) 
        external 
        override 
        onlyRole(RISK_MANAGER_ROLE) 
    {
        require(newMaxLTV <= 10000, "Max LTV too high");
        require(newLiquidationThreshold <= 10000, "Liquidation threshold too high");
        require(newLiquidationThreshold > newMaxLTV, "Liquidation threshold must exceed max LTV");
        
        config.maxLTV = newMaxLTV;
        config.liquidationThreshold = newLiquidationThreshold;
    }
    
    /**
     * @dev Emergency pause function
     */
    function emergencyPause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        config.emergencyPaused = true;
        _pause();
        emit EmergencyPause(true, "Emergency pause activated");
    }
    
    /**
     * @dev Emergency unpause function
     */
    function emergencyUnpause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        config.emergencyPaused = false;
        _unpause();
        emit EmergencyPause(false, "Emergency pause deactivated");
    }
    
    // View functions
    
    function getVaultConfiguration() external view override returns (VaultConfiguration memory) {
        return config;
    }
    
    function getCurrentConcentrations() 
        external 
        view 
        override 
        returns (bytes32[] memory carrierIds, uint256[] memory concentrations) 
    {
        // This is simplified - in practice, maintain an array of active carriers
        // For now, return empty arrays
        carrierIds = new bytes32[](0);
        concentrations = new uint256[](0);
    }
    
    function getAccountPosition(address account) 
        external 
        view 
        override 
        returns (uint256 tokens, uint256 csvValue, uint256 ltv) 
    {
        tokens = accountTokens[account];
        csvValue = accountCSVValue[account];
        
        if (csvValue > 0) {
            ltv = (tokens * 10000) / csvValue;
        } else {
            ltv = 0;
        }
    }
    
    /**
     * @dev Get account's policy list
     */
    function getAccountPolicies(address account) external view returns (bytes32[] memory) {
        return accountPolicies[account];
    }
    
    /**
     * @dev Get policy position details
     */
    function getPolicyPosition(bytes32 policyId) external view returns (PolicyPosition memory) {
        return policyPositions[policyId];
    }
    
    // Internal functions
    
    /**
     * @dev Calculate tokens to issue based on CSV value
     */
    function _calculateTokensToIssue(uint256 csvValue) internal view returns (uint256) {
        // Simplified 1:1 ratio for now
        // In practice, this would use the oracle valuation and current exchange rate
        return csvValue;
    }
    
    /**
     * @dev Calculate new LTV after token issuance
     */
    function _calculateNewLTV(uint256 additionalTokens) internal view returns (uint256) {
        ICSVOracle.ValuationData memory valuation = oracle.getLatestValuation();
        
        if (valuation.totalCSV == 0) return 0;
        
        uint256 newTokenTotal = totalTokensIssued + additionalTokens;
        return (newTokenTotal * 10000) / valuation.totalCSV;
    }
    
    /**
     * @dev Select policies for withdrawal (FIFO)
     */
    function _selectPoliciesForWithdrawal(address account, uint256 targetCSV) 
        internal 
        view 
        returns (bytes32[] memory) 
    {
        bytes32[] memory userPolicies = accountPolicies[account];
        bytes32[] memory selected = new bytes32[](userPolicies.length);
        uint256 selectedCount = 0;
        uint256 accumulatedCSV = 0;
        
        for (uint256 i = 0; i < userPolicies.length && accumulatedCSV < targetCSV; i++) {
            if (policyPositions[userPolicies[i]].isActive) {
                selected[selectedCount] = userPolicies[i];
                accumulatedCSV += policyPositions[userPolicies[i]].csvValue;
                selectedCount++;
            }
        }
        
        // Resize array
        bytes32[] memory result = new bytes32[](selectedCount);
        for (uint256 i = 0; i < selectedCount; i++) {
            result[i] = selected[i];
        }
        
        return result;
    }
}