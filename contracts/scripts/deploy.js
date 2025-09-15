const hre = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
  console.log("🚀 Starting iYield Protocol deployment...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Deploy ComplianceRegistry first
  console.log("\n📋 Deploying ComplianceRegistry...");
  const ComplianceRegistry = await ethers.getContractFactory("ComplianceRegistry");
  const complianceRegistry = await ComplianceRegistry.deploy();
  await complianceRegistry.deployed();
  console.log("✅ ComplianceRegistry deployed to:", complianceRegistry.address);

  // Deploy CSVOracle
  console.log("\n🔮 Deploying CSVOracle...");
  const CSVOracle = await ethers.getContractFactory("CSVOracle");
  const csvOracle = await CSVOracle.deploy();
  await csvOracle.deployed();
  console.log("✅ CSVOracle deployed to:", csvOracle.address);

  // Deploy ERCRWACSV token
  console.log("\n🪙 Deploying ERCRWACSV token...");
  const ERCRWACSV = await ethers.getContractFactory("ERCRWACSV");
  const csvToken = await ERCRWACSV.deploy(
    "iYield CSV Token",
    "iYCSV",
    complianceRegistry.address,
    csvOracle.address
  );
  await csvToken.deployed();
  console.log("✅ ERCRWACSV token deployed to:", csvToken.address);

  // Deploy CSVVault
  console.log("\n🏦 Deploying CSVVault...");
  const CSVVault = await ethers.getContractFactory("CSVVault");
  const vaultConfig = {
    maxLTV: 8000, // 80% max LTV
    liquidationPenalty: 500, // 5% liquidation penalty
    minCollateralValue: ethers.utils.parseEther("1000"), // Min $1000 CSV
    stabilityFee: 300, // 3% annual stability fee
    isEnabled: true
  };
  
  const csvVault = await CSVVault.deploy(csvToken.address, vaultConfig);
  await csvVault.deployed();
  console.log("✅ CSVVault deployed to:", csvVault.address);

  // Deploy mock USDC for testing (in production, use real USDC address)
  console.log("\n💵 Deploying Mock USDC...");
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const mockUSDC = await MockERC20.deploy("USD Coin", "USDC", 6);
  await mockUSDC.deployed();
  console.log("✅ Mock USDC deployed to:", mockUSDC.address);

  // Deploy CSVLiquidityPool
  console.log("\n🌊 Deploying CSVLiquidityPool...");
  const CSVLiquidityPool = await ethers.getContractFactory("CSVLiquidityPool");
  const poolConfig = {
    seniorYieldRate: 400, // 4% senior yield
    juniorYieldRate: 800, // 8% junior yield
    protocolFeeRate: 200, // 2% protocol fee
    performanceFeeRate: 1000, // 10% performance fee
    withdrawalFeeRate: 100, // 1% early withdrawal fee
    maxUtilization: 9000 // 90% max utilization
  };
  
  const liquidityPool = await CSVLiquidityPool.deploy(
    csvToken.address,
    mockUSDC.address,
    poolConfig
  );
  await liquidityPool.deployed();
  console.log("✅ CSVLiquidityPool deployed to:", liquidityPool.address);

  // Grant necessary roles
  console.log("\n🔐 Setting up roles and permissions...");
  
  // CSV Token roles
  const MINTER_ROLE = await csvToken.MINTER_ROLE();
  const BURNER_ROLE = await csvToken.BURNER_ROLE();
  const ORACLE_ROLE = await csvToken.ORACLE_ROLE();
  
  await csvToken.grantRole(MINTER_ROLE, csvVault.address);
  await csvToken.grantRole(BURNER_ROLE, csvVault.address);
  await csvToken.grantRole(ORACLE_ROLE, csvOracle.address);
  console.log("✅ CSV Token roles configured");

  // Vault roles
  const VAULT_ORACLE_ROLE = await csvVault.ORACLE_ROLE();
  await csvVault.grantRole(VAULT_ORACLE_ROLE, csvOracle.address);
  console.log("✅ CSV Vault roles configured");

  // Oracle roles
  const ORACLE_CONSUMER_ROLE = await csvOracle.CONSUMER_ROLE();
  await csvOracle.grantRole(ORACLE_CONSUMER_ROLE, csvToken.address);
  await csvOracle.grantRole(ORACLE_CONSUMER_ROLE, csvVault.address);
  console.log("✅ CSV Oracle roles configured");

  // Mint some mock USDC for testing
  if (hre.network.name === "hardhat" || hre.network.name === "localhost") {
    console.log("\n💰 Minting test USDC tokens...");
    const testAmount = ethers.utils.parseUnits("1000000", 6); // 1M USDC
    await mockUSDC.mint(deployer.address, testAmount);
    console.log("✅ Minted 1M USDC for testing");
  }

  // Save deployment addresses
  const deploymentInfo = {
    network: hre.network.name,
    timestamp: new Date().toISOString(),
    deployer: deployer.address,
    contracts: {
      ComplianceRegistry: complianceRegistry.address,
      CSVOracle: csvOracle.address,
      ERCRWACSV: csvToken.address,
      CSVVault: csvVault.address,
      CSVLiquidityPool: liquidityPool.address,
      MockUSDC: mockUSDC.address
    },
    verification: {
      ComplianceRegistry: `npx hardhat verify --network ${hre.network.name} ${complianceRegistry.address}`,
      CSVOracle: `npx hardhat verify --network ${hre.network.name} ${csvOracle.address}`,
      ERCRWACSV: `npx hardhat verify --network ${hre.network.name} ${csvToken.address} "iYield CSV Token" "iYCSV" ${complianceRegistry.address} ${csvOracle.address}`,
      CSVVault: `npx hardhat verify --network ${hre.network.name} ${csvVault.address} ${csvToken.address} '${JSON.stringify(vaultConfig)}'`,
      CSVLiquidityPool: `npx hardhat verify --network ${hre.network.name} ${liquidityPool.address} ${csvToken.address} ${mockUSDC.address} '${JSON.stringify(poolConfig)}'`,
      MockUSDC: `npx hardhat verify --network ${hre.network.name} ${mockUSDC.address} "USD Coin" "USDC" 6`
    }
  };

  console.log("\n📄 Deployment Summary:");
  console.log("=====================");
  console.table(deploymentInfo.contracts);
  
  console.log("\n🔗 Verification Commands:");
  Object.entries(deploymentInfo.verification).forEach(([contract, command]) => {
    console.log(`${contract}: ${command}`);
  });

  // Save to file
  const fs = require('fs');
  const path = require('path');
  
  const deploymentsDir = path.join(__dirname, '../deployments');
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }
  
  const deploymentFile = path.join(deploymentsDir, `${hre.network.name}-${Date.now()}.json`);
  fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
  console.log(`\n💾 Deployment info saved to: ${deploymentFile}`);

  console.log("\n🎉 iYield Protocol deployment completed successfully!");
  console.log("🔒 Remember to:");
  console.log("   1. Verify contracts on Etherscan");
  console.log("   2. Set up oracle operators");
  console.log("   3. Configure compliance parameters");
  console.log("   4. Initialize liquidity pools");
  console.log("   5. Update frontend contract addresses");
}

// Mock ERC20 contract for testing
const MockERC20Source = `
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC20 is ERC20, Ownable {
    uint8 private _decimals;
    
    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }
    
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
`;

// Create MockERC20.sol if it doesn't exist
const fs = require('fs');
const path = require('path');
const mockContractPath = path.join(__dirname, '../contracts/MockERC20.sol');

if (!fs.existsSync(mockContractPath)) {
  fs.writeFileSync(mockContractPath, MockERC20Source);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });