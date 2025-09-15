// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./ComplianceRegistry.sol";
import "./OracleAdapter.sol";

/**
 * @title LiquidityPool
 * @dev Automated Market Maker (AMM) liquidity pool for token swaps and liquidity provision
 */
contract LiquidityPool is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    // Pool configuration
    struct PoolConfig {
        address tokenA;           // First token in the pair
        address tokenB;           // Second token in the pair
        uint256 feeRate;          // Trading fee rate (basis points)
        uint256 totalLiquidity;   // Total liquidity tokens
        uint256 reserveA;         // Reserve of token A
        uint256 reserveB;         // Reserve of token B
        uint256 lastUpdate;       // Last update timestamp
        bool isActive;            // Pool active status
    }
    
    // Liquidity provider info
    struct LiquidityProvider {
        uint256 liquidityTokens;  // LP tokens owned
        uint256 lastAddTime;      // Last liquidity addition timestamp
        uint256 totalProvided;    // Total liquidity provided (USD value)
        uint256 rewardsAccrued;   // Accrued rewards
        uint256 feesEarned;       // Fees earned from trading
    }
    
    // Swap transaction info
    struct SwapInfo {
        address tokenIn;          // Input token
        address tokenOut;         // Output token
        uint256 amountIn;         // Input amount
        uint256 amountOut;        // Output amount
        uint256 fee;              // Fee paid
        uint256 priceImpact;      // Price impact (basis points)
        uint256 timestamp;        // Transaction timestamp
    }
    
    // Events
    event PoolCreated(address indexed tokenA, address indexed tokenB, uint256 feeRate);
    event LiquidityAdded(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidityTokens
    );
    event LiquidityRemoved(
        address indexed provider,
        uint256 amountA,
        uint256 amountB,
        uint256 liquidityTokens
    );
    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );
    event RewardsDistributed(uint256 totalRewards, uint256 timestamp);
    event FeesCollected(address indexed collector, uint256 amount);
    
    // State variables
    ComplianceRegistry public immutable complianceRegistry;
    OracleAdapter public immutable oracleAdapter;
    
    PoolConfig public poolConfig;
    mapping(address => LiquidityProvider) public liquidityProviders;
    mapping(bytes32 => SwapInfo) public swapHistory;
    
    address[] public allProviders;
    bytes32[] public swapIds;
    
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MIN_LIQUIDITY = 1000;
    uint256 public constant MAX_PRICE_IMPACT = 1000; // 10%
    uint256 public constant MINIMUM_K = 1e18; // Minimum constant product
    
    uint256 public totalFeesCollected;
    uint256 public totalVolumeTraded;
    uint256 public rewardRate = 100; // Reward rate in basis points
    
    modifier onlyCompliant() {
        require(complianceRegistry.isCompliant(msg.sender), "User not compliant");
        _;
    }
    
    modifier poolExists() {
        require(poolConfig.isActive, "Pool not active");
        _;
    }
    
    constructor(
        address _complianceRegistry,
        address _oracleAdapter,
        address _tokenA,
        address _tokenB,
        uint256 _feeRate
    ) Ownable(msg.sender) {
        require(_complianceRegistry != address(0), "Invalid compliance registry");
        require(_oracleAdapter != address(0), "Invalid oracle adapter");
        require(_tokenA != address(0) && _tokenB != address(0), "Invalid token addresses");
        require(_tokenA != _tokenB, "Tokens must be different");
        require(_feeRate <= 1000, "Fee rate too high"); // Max 10%
        
        complianceRegistry = ComplianceRegistry(_complianceRegistry);
        oracleAdapter = OracleAdapter(_oracleAdapter);
        
        poolConfig = PoolConfig({
            tokenA: _tokenA,
            tokenB: _tokenB,
            feeRate: _feeRate,
            totalLiquidity: 0,
            reserveA: 0,
            reserveB: 0,
            lastUpdate: block.timestamp,
            isActive: true
        });
        
        emit PoolCreated(_tokenA, _tokenB, _feeRate);
    }
    
    /**
     * @dev Add liquidity to the pool
     */
    function addLiquidity(
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external onlyCompliant poolExists nonReentrant whenNotPaused returns (uint256 liquidity) {
        require(amountADesired > 0 && amountBDesired > 0, "Invalid amounts");
        
        uint256 amountA;
        uint256 amountB;
        
        if (poolConfig.totalLiquidity == 0) {
            // Initial liquidity provision
            amountA = amountADesired;
            amountB = amountBDesired;
            liquidity = _sqrt(amountA * amountB) - MIN_LIQUIDITY;
            require(liquidity > 0, "Insufficient liquidity");
        } else {
            // Calculate optimal amounts based on current reserves
            uint256 amountBOptimal = (amountADesired * poolConfig.reserveB) / poolConfig.reserveA;
            
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Insufficient B amount");
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint256 amountAOptimal = (amountBDesired * poolConfig.reserveA) / poolConfig.reserveB;
                require(amountAOptimal <= amountADesired && amountAOptimal >= amountAMin, "Insufficient A amount");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
            
            liquidity = _min(
                (amountA * poolConfig.totalLiquidity) / poolConfig.reserveA,
                (amountB * poolConfig.totalLiquidity) / poolConfig.reserveB
            );
        }
        
        require(liquidity > 0, "Insufficient liquidity minted");
        
        // Update pool state
        poolConfig.reserveA += amountA;
        poolConfig.reserveB += amountB;
        poolConfig.totalLiquidity += liquidity;
        poolConfig.lastUpdate = block.timestamp;
        
        // Update user state
        LiquidityProvider storage provider = liquidityProviders[msg.sender];
        if (provider.liquidityTokens == 0) {
            allProviders.push(msg.sender);
        }
        
        provider.liquidityTokens += liquidity;
        provider.lastAddTime = block.timestamp;
        provider.totalProvided += _getUSDValue(poolConfig.tokenA, amountA) + _getUSDValue(poolConfig.tokenB, amountB);
        
        // Transfer tokens
        IERC20(poolConfig.tokenA).safeTransferFrom(msg.sender, address(this), amountA);
        IERC20(poolConfig.tokenB).safeTransferFrom(msg.sender, address(this), amountB);
        
        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }
    
    /**
     * @dev Remove liquidity from the pool
     */
    function removeLiquidity(
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) external onlyCompliant poolExists nonReentrant returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0, "Invalid liquidity amount");
        
        LiquidityProvider storage provider = liquidityProviders[msg.sender];
        require(provider.liquidityTokens >= liquidity, "Insufficient liquidity tokens");
        
        // Calculate withdrawal amounts
        amountA = (liquidity * poolConfig.reserveA) / poolConfig.totalLiquidity;
        amountB = (liquidity * poolConfig.reserveB) / poolConfig.totalLiquidity;
        
        require(amountA >= amountAMin && amountB >= amountBMin, "Insufficient output amounts");
        
        // Update pool state
        poolConfig.reserveA -= amountA;
        poolConfig.reserveB -= amountB;
        poolConfig.totalLiquidity -= liquidity;
        poolConfig.lastUpdate = block.timestamp;
        
        // Update user state
        provider.liquidityTokens -= liquidity;
        
        // Transfer tokens
        IERC20(poolConfig.tokenA).safeTransfer(msg.sender, amountA);
        IERC20(poolConfig.tokenB).safeTransfer(msg.sender, amountB);
        
        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }
    
    /**
     * @dev Swap tokens
     */
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external onlyCompliant poolExists nonReentrant whenNotPaused returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid input amount");
        require(
            (tokenIn == poolConfig.tokenA && tokenOut == poolConfig.tokenB) ||
            (tokenIn == poolConfig.tokenB && tokenOut == poolConfig.tokenA),
            "Invalid token pair"
        );
        
        // Calculate output amount with fee
        uint256 amountInWithFee = amountIn * (BASIS_POINTS - poolConfig.feeRate) / BASIS_POINTS;
        
        if (tokenIn == poolConfig.tokenA) {
            amountOut = _getAmountOut(amountInWithFee, poolConfig.reserveA, poolConfig.reserveB);
            
            // Check slippage
            require(amountOut >= amountOutMin, "Excessive slippage");
            
            // Check price impact
            uint256 priceImpact = _calculatePriceImpact(amountIn, poolConfig.reserveA);
            require(priceImpact <= MAX_PRICE_IMPACT, "Price impact too high");
            
            // Update reserves
            poolConfig.reserveA += amountIn;
            poolConfig.reserveB -= amountOut;
        } else {
            amountOut = _getAmountOut(amountInWithFee, poolConfig.reserveB, poolConfig.reserveA);
            
            // Check slippage
            require(amountOut >= amountOutMin, "Excessive slippage");
            
            // Check price impact
            uint256 priceImpact = _calculatePriceImpact(amountIn, poolConfig.reserveB);
            require(priceImpact <= MAX_PRICE_IMPACT, "Price impact too high");
            
            // Update reserves
            poolConfig.reserveB += amountIn;
            poolConfig.reserveA -= amountOut;
        }
        
        // Ensure k invariant
        require(
            poolConfig.reserveA * poolConfig.reserveB >= MINIMUM_K,
            "K invariant violation"
        );
        
        uint256 fee = amountIn * poolConfig.feeRate / BASIS_POINTS;
        totalFeesCollected += fee;
        totalVolumeTraded += amountIn;
        poolConfig.lastUpdate = block.timestamp;
        
        // Record swap
        bytes32 swapId = keccak256(abi.encodePacked(msg.sender, block.timestamp, amountIn));
        swapHistory[swapId] = SwapInfo({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOut: amountOut,
            fee: fee,
            priceImpact: _calculatePriceImpact(amountIn, tokenIn == poolConfig.tokenA ? poolConfig.reserveA : poolConfig.reserveB),
            timestamp: block.timestamp
        });
        swapIds.push(swapId);
        
        // Transfer tokens
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);
        
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut, fee);
    }
    
    /**
     * @dev Distribute rewards to liquidity providers
     */
    function distributeRewards() external onlyOwner nonReentrant {
        require(totalFeesCollected > 0, "No fees to distribute");
        
        uint256 totalRewards = (totalFeesCollected * rewardRate) / BASIS_POINTS;
        
        for (uint256 i = 0; i < allProviders.length; i++) {
            address provider = allProviders[i];
            LiquidityProvider storage providerInfo = liquidityProviders[provider];
            
            if (providerInfo.liquidityTokens > 0) {
                uint256 providerShare = (providerInfo.liquidityTokens * BASIS_POINTS) / poolConfig.totalLiquidity;
                uint256 providerReward = (totalRewards * providerShare) / BASIS_POINTS;
                
                providerInfo.rewardsAccrued += providerReward;
                providerInfo.feesEarned += providerReward;
            }
        }
        
        totalFeesCollected -= totalRewards;
        
        emit RewardsDistributed(totalRewards, block.timestamp);
    }
    
    /**
     * @dev Claim rewards
     */
    function claimRewards() external onlyCompliant nonReentrant {
        LiquidityProvider storage provider = liquidityProviders[msg.sender];
        require(provider.rewardsAccrued > 0, "No rewards to claim");
        
        uint256 rewards = provider.rewardsAccrued;
        provider.rewardsAccrued = 0;
        
        // For simplicity, transfer rewards in tokenA
        IERC20(poolConfig.tokenA).safeTransfer(msg.sender, rewards);
    }
    
    /**
     * @dev Get amount out for a given input
     */
    function getAmountOut(uint256 amountIn, address tokenIn) 
        external 
        view 
        poolExists 
        returns (uint256 amountOut) 
    {
        require(amountIn > 0, "Invalid input amount");
        require(
            tokenIn == poolConfig.tokenA || tokenIn == poolConfig.tokenB,
            "Invalid token"
        );
        
        uint256 amountInWithFee = amountIn * (BASIS_POINTS - poolConfig.feeRate) / BASIS_POINTS;
        
        if (tokenIn == poolConfig.tokenA) {
            amountOut = _getAmountOut(amountInWithFee, poolConfig.reserveA, poolConfig.reserveB);
        } else {
            amountOut = _getAmountOut(amountInWithFee, poolConfig.reserveB, poolConfig.reserveA);
        }
    }
    
    /**
     * @dev Get current price ratio
     */
    function getPriceRatio() external view poolExists returns (uint256) {
        require(poolConfig.reserveA > 0 && poolConfig.reserveB > 0, "No liquidity");
        return (poolConfig.reserveB * 1e18) / poolConfig.reserveA;
    }
    
    /**
     * @dev Set pool fee rate
     */
    function setFeeRate(uint256 newFeeRate) external onlyOwner poolExists {
        require(newFeeRate <= 1000, "Fee rate too high"); // Max 10%
        poolConfig.feeRate = newFeeRate;
    }
    
    /**
     * @dev Set reward rate
     */
    function setRewardRate(uint256 newRewardRate) external onlyOwner {
        require(newRewardRate <= BASIS_POINTS, "Reward rate too high");
        rewardRate = newRewardRate;
    }
    
    /**
     * @dev Pause the pool
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause the pool
     */
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev Emergency withdraw (only when paused)
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        require(paused(), "Pool must be paused");
        IERC20(token).safeTransfer(owner(), amount);
    }
    
    /**
     * @dev Calculate amount out using constant product formula
     */
    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        
        uint256 numerator = amountIn * reserveOut;
        uint256 denominator = reserveIn + amountIn;
        amountOut = numerator / denominator;
    }
    
    /**
     * @dev Calculate price impact
     */
    function _calculatePriceImpact(uint256 amountIn, uint256 reserveIn) 
        internal 
        pure 
        returns (uint256) 
    {
        if (reserveIn == 0) return 0;
        return (amountIn * BASIS_POINTS) / (reserveIn + amountIn);
    }
    
    /**
     * @dev Get USD value of token amount (placeholder)
     */
    function _getUSDValue(address token, uint256 amount) internal pure returns (uint256) {
        // Placeholder - in real implementation, this would use the oracle adapter
        return amount; // Assuming 1:1 USD conversion for simplicity
    }
    
    /**
     * @dev Square root function
     */
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
    
    /**
     * @dev Get minimum of two numbers
     */
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
    
    /**
     * @dev Get pool statistics
     */
    function getPoolStats() external view returns (
        uint256 reserveA,
        uint256 reserveB,
        uint256 totalLiquidity,
        uint256 feesCollected,
        uint256 volumeTraded,
        uint256 totalProviders
    ) {
        return (
            poolConfig.reserveA,
            poolConfig.reserveB,
            poolConfig.totalLiquidity,
            totalFeesCollected,
            totalVolumeTraded,
            allProviders.length
        );
    }
    
    /**
     * @dev Get liquidity provider info
     */
    function getLiquidityProviderInfo(address provider) 
        external 
        view 
        returns (LiquidityProvider memory) 
    {
        return liquidityProviders[provider];
    }
    
    /**
     * @dev Get all providers
     */
    function getAllProviders() external view returns (address[] memory) {
        return allProviders;
    }
    
    /**
     * @dev Get swap history
     */
    function getSwapHistory(uint256 offset, uint256 limit) 
        external 
        view 
        returns (SwapInfo[] memory swaps) 
    {
        uint256 start = offset;
        uint256 end = offset + limit;
        if (end > swapIds.length) {
            end = swapIds.length;
        }
        
        swaps = new SwapInfo[](end - start);
        for (uint256 i = start; i < end; i++) {
            swaps[i - start] = swapHistory[swapIds[i]];
        }
    }
}