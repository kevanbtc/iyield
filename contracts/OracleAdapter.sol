// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title OracleAdapter
 * @dev Adapts external price feeds and provides standardized price data for the iYield protocol
 */
contract OracleAdapter is Ownable, ReentrancyGuard {
    
    // Price feed data structure
    struct PriceFeed {
        address feedAddress;    // Address of the price feed
        uint256 lastPrice;      // Last recorded price
        uint256 lastUpdate;     // Timestamp of last update
        uint8 decimals;         // Decimals of the price feed
        bool isActive;          // Whether the feed is active
        uint256 heartbeat;      // Maximum time between updates
        string description;     // Description of the price feed
    }
    
    // Price data structure for external consumption
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint8 decimals;
        bool isValid;
    }
    
    // Events
    event PriceFeedAdded(bytes32 indexed feedId, address feedAddress, string description);
    event PriceFeedUpdated(bytes32 indexed feedId, uint256 price, uint256 timestamp);
    event PriceFeedRemoved(bytes32 indexed feedId);
    event PriceFeedStatusChanged(bytes32 indexed feedId, bool isActive);
    event HeartbeatUpdated(bytes32 indexed feedId, uint256 newHeartbeat);
    event EmergencyPriceSet(bytes32 indexed feedId, uint256 price);
    
    // State variables
    mapping(bytes32 => PriceFeed) public priceFeeds;
    mapping(string => bytes32) public symbolToFeedId;
    bytes32[] public activeFeedIds;
    
    uint256 public constant MAX_HEARTBEAT = 24 hours;
    uint256 public constant PRICE_STALENESS_THRESHOLD = 1 hours;
    uint256 public constant MAX_PRICE_DEVIATION = 1000; // 10% in basis points
    
    // Emergency controls
    bool public emergencyMode;
    mapping(address => bool) public emergencyOperators;
    mapping(bytes32 => uint256) public emergencyPrices;
    
    modifier onlyEmergencyOperator() {
        require(emergencyOperators[msg.sender] || msg.sender == owner(), "Not authorized");
        _;
    }
    
    modifier validFeedId(bytes32 feedId) {
        require(priceFeeds[feedId].feedAddress != address(0), "Feed does not exist");
        _;
    }
    
    constructor() Ownable(msg.sender) {
        emergencyOperators[msg.sender] = true;
    }
    
    /**
     * @dev Add a new price feed
     */
    function addPriceFeed(
        string calldata symbol,
        address feedAddress,
        uint8 decimals,
        uint256 heartbeat,
        string calldata description
    ) external onlyOwner {
        require(feedAddress != address(0), "Invalid feed address");
        require(heartbeat <= MAX_HEARTBEAT, "Heartbeat too long");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        
        bytes32 feedId = keccak256(abi.encodePacked(symbol));
        require(priceFeeds[feedId].feedAddress == address(0), "Feed already exists");
        
        priceFeeds[feedId] = PriceFeed({
            feedAddress: feedAddress,
            lastPrice: 0,
            lastUpdate: 0,
            decimals: decimals,
            isActive: true,
            heartbeat: heartbeat,
            description: description
        });
        
        symbolToFeedId[symbol] = feedId;
        activeFeedIds.push(feedId);
        
        emit PriceFeedAdded(feedId, feedAddress, description);
    }
    
    /**
     * @dev Update price for a feed
     */
    function updatePrice(bytes32 feedId, uint256 newPrice) 
        external 
        validFeedId(feedId) 
        nonReentrant 
    {
        PriceFeed storage feed = priceFeeds[feedId];
        require(feed.isActive, "Feed is not active");
        
        // Validate price deviation if there's a previous price
        if (feed.lastPrice > 0) {
            uint256 deviation = _calculateDeviation(feed.lastPrice, newPrice);
            require(deviation <= MAX_PRICE_DEVIATION, "Price deviation too high");
        }
        
        feed.lastPrice = newPrice;
        feed.lastUpdate = block.timestamp;
        
        emit PriceFeedUpdated(feedId, newPrice, block.timestamp);
    }
    
    /**
     * @dev Get latest price for a symbol
     */
    function getPrice(string calldata symbol) external view returns (PriceData memory) {
        bytes32 feedId = symbolToFeedId[symbol];
        return getPriceByFeedId(feedId);
    }
    
    /**
     * @dev Get latest price by feed ID
     */
    function getPriceByFeedId(bytes32 feedId) public view validFeedId(feedId) returns (PriceData memory) {
        PriceFeed storage feed = priceFeeds[feedId];
        
        // Check if we're in emergency mode and have an emergency price
        if (emergencyMode && emergencyPrices[feedId] > 0) {
            return PriceData({
                price: emergencyPrices[feedId],
                timestamp: block.timestamp,
                decimals: feed.decimals,
                isValid: true
            });
        }
        
        // Check if price is stale
        bool isStale = block.timestamp - feed.lastUpdate > feed.heartbeat;
        bool isValid = feed.isActive && !isStale && feed.lastPrice > 0;
        
        return PriceData({
            price: feed.lastPrice,
            timestamp: feed.lastUpdate,
            decimals: feed.decimals,
            isValid: isValid
        });
    }
    
    /**
     * @dev Get prices for multiple symbols
     */
    function getPrices(string[] calldata symbols) external view returns (PriceData[] memory) {
        PriceData[] memory prices = new PriceData[](symbols.length);
        
        for (uint256 i = 0; i < symbols.length; i++) {
            bytes32 feedId = symbolToFeedId[symbols[i]];
            if (priceFeeds[feedId].feedAddress != address(0)) {
                prices[i] = getPriceByFeedId(feedId);
            } else {
                prices[i] = PriceData({
                    price: 0,
                    timestamp: 0,
                    decimals: 0,
                    isValid: false
                });
            }
        }
        
        return prices;
    }
    
    /**
     * @dev Convert price to different decimal precision
     */
    function convertPrecision(
        uint256 price,
        uint8 fromDecimals,
        uint8 toDecimals
    ) external pure returns (uint256) {
        if (fromDecimals == toDecimals) {
            return price;
        } else if (fromDecimals > toDecimals) {
            return price / (10 ** (fromDecimals - toDecimals));
        } else {
            return price * (10 ** (toDecimals - fromDecimals));
        }
    }
    
    /**
     * @dev Set feed active/inactive status
     */
    function setFeedStatus(bytes32 feedId, bool isActive) 
        external 
        onlyOwner 
        validFeedId(feedId) 
    {
        priceFeeds[feedId].isActive = isActive;
        emit PriceFeedStatusChanged(feedId, isActive);
    }
    
    /**
     * @dev Update feed heartbeat
     */
    function updateHeartbeat(bytes32 feedId, uint256 newHeartbeat) 
        external 
        onlyOwner 
        validFeedId(feedId) 
    {
        require(newHeartbeat <= MAX_HEARTBEAT, "Heartbeat too long");
        priceFeeds[feedId].heartbeat = newHeartbeat;
        emit HeartbeatUpdated(feedId, newHeartbeat);
    }
    
    /**
     * @dev Remove a price feed
     */
    function removePriceFeed(bytes32 feedId) external onlyOwner validFeedId(feedId) {
        PriceFeed storage feed = priceFeeds[feedId];
        
        // Remove from active feeds array
        for (uint256 i = 0; i < activeFeedIds.length; i++) {
            if (activeFeedIds[i] == feedId) {
                activeFeedIds[i] = activeFeedIds[activeFeedIds.length - 1];
                activeFeedIds.pop();
                break;
            }
        }
        
        // Clear the feed data
        delete priceFeeds[feedId];
        
        emit PriceFeedRemoved(feedId);
    }
    
    /**
     * @dev Set emergency mode
     */
    function setEmergencyMode(bool _emergencyMode) external onlyOwner {
        emergencyMode = _emergencyMode;
    }
    
    /**
     * @dev Set emergency operator
     */
    function setEmergencyOperator(address operator, bool authorized) external onlyOwner {
        require(operator != address(0), "Invalid operator address");
        emergencyOperators[operator] = authorized;
    }
    
    /**
     * @dev Set emergency price
     */
    function setEmergencyPrice(bytes32 feedId, uint256 price) 
        external 
        onlyEmergencyOperator 
        validFeedId(feedId) 
    {
        require(emergencyMode, "Not in emergency mode");
        require(price > 0, "Price must be greater than 0");
        
        emergencyPrices[feedId] = price;
        emit EmergencyPriceSet(feedId, price);
    }
    
    /**
     * @dev Get all active feed IDs
     */
    function getActiveFeedIds() external view returns (bytes32[] memory) {
        return activeFeedIds;
    }
    
    /**
     * @dev Check if price is stale
     */
    function isPriceStale(bytes32 feedId) external view validFeedId(feedId) returns (bool) {
        PriceFeed storage feed = priceFeeds[feedId];
        return block.timestamp - feed.lastUpdate > feed.heartbeat;
    }
    
    /**
     * @dev Get feed information
     */
    function getFeedInfo(bytes32 feedId) external view validFeedId(feedId) returns (PriceFeed memory) {
        return priceFeeds[feedId];
    }
    
    /**
     * @dev Calculate percentage deviation between two prices
     */
    function _calculateDeviation(uint256 oldPrice, uint256 newPrice) internal pure returns (uint256) {
        if (oldPrice == 0) return 0;
        
        uint256 diff = oldPrice > newPrice ? oldPrice - newPrice : newPrice - oldPrice;
        return (diff * 10000) / oldPrice; // Return in basis points
    }
    
    /**
     * @dev Batch update multiple prices
     */
    function batchUpdatePrices(
        bytes32[] calldata feedIds,
        uint256[] calldata prices
    ) external nonReentrant {
        require(feedIds.length == prices.length, "Array length mismatch");
        
        for (uint256 i = 0; i < feedIds.length; i++) {
            bytes32 feedId = feedIds[i];
            require(priceFeeds[feedId].feedAddress != address(0), "Feed does not exist");
            
            PriceFeed storage feed = priceFeeds[feedId];
            require(feed.isActive, "Feed is not active");
            
            // Validate price deviation if there's a previous price
            if (feed.lastPrice > 0) {
                uint256 deviation = _calculateDeviation(feed.lastPrice, prices[i]);
                require(deviation <= MAX_PRICE_DEVIATION, "Price deviation too high");
            }
            
            feed.lastPrice = prices[i];
            feed.lastUpdate = block.timestamp;
            
            emit PriceFeedUpdated(feedId, prices[i], block.timestamp);
        }
    }
}