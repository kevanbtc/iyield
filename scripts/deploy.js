const { ethers } = require("hardhat");

async function main() {
  console.log("Starting iYield Protocol deployment...");

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

  // Deploy ComplianceRegistry
  console.log("\n1. Deploying ComplianceRegistry...");
  const ComplianceRegistry = await ethers.getContractFactory("ComplianceRegistry");
  const complianceRegistry = await ComplianceRegistry.deploy();
  await complianceRegistry.waitForDeployment();
  const complianceRegistryAddress = await complianceRegistry.getAddress();
  console.log("ComplianceRegistry deployed to:", complianceRegistryAddress);

  // Deploy OracleAdapter
  console.log("\n2. Deploying OracleAdapter...");
  const OracleAdapter = await ethers.getContractFactory("OracleAdapter");
  const oracleAdapter = await OracleAdapter.deploy();
  await oracleAdapter.waitForDeployment();
  const oracleAdapterAddress = await oracleAdapter.getAddress();
  console.log("OracleAdapter deployed to:", oracleAdapterAddress);

  // Deploy iYieldToken
  console.log("\n3. Deploying iYieldToken...");
  const initialSupply = ethers.parseEther("1000000"); // 1M tokens
  const IYieldToken = await ethers.getContractFactory("iYieldToken");
  const iYieldToken = await IYieldToken.deploy(
    "iYield Token",
    "iYLD",
    initialSupply,
    complianceRegistryAddress
  );
  await iYieldToken.waitForDeployment();
  const iYieldTokenAddress = await iYieldToken.getAddress();
  console.log("iYieldToken deployed to:", iYieldTokenAddress);

  // Deploy Vault
  console.log("\n4. Deploying Vault...");
  const Vault = await ethers.getContractFactory("Vault");
  const vault = await Vault.deploy(
    complianceRegistryAddress,
    oracleAdapterAddress,
    iYieldTokenAddress
  );
  await vault.waitForDeployment();
  const vaultAddress = await vault.getAddress();
  console.log("Vault deployed to:", vaultAddress);

  // Create a mock token for liquidity pool testing
  console.log("\n5. Deploying mock USDC token...");
  const MockToken = await ethers.getContractFactory("iYieldToken");
  const mockUSDC = await MockToken.deploy(
    "Mock USDC",
    "mUSDC",
    ethers.parseEther("1000000"), // 1M tokens
    complianceRegistryAddress
  );
  await mockUSDC.waitForDeployment();
  const mockUSDCAddress = await mockUSDC.getAddress();
  console.log("Mock USDC deployed to:", mockUSDCAddress);

  // Deploy LiquidityPool
  console.log("\n6. Deploying LiquidityPool...");
  const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
  const liquidityPool = await LiquidityPool.deploy(
    complianceRegistryAddress,
    oracleAdapterAddress,
    iYieldTokenAddress,
    mockUSDCAddress,
    30 // 0.3% fee
  );
  await liquidityPool.waitForDeployment();
  const liquidityPoolAddress = await liquidityPool.getAddress();
  console.log("LiquidityPool deployed to:", liquidityPoolAddress);

  console.log("\n✅ All contracts deployed successfully!");

  // Setup initial configuration
  console.log("\n📋 Setting up initial configuration...");

  // Set deployer as compliant in ComplianceRegistry
  console.log("- Setting deployer as compliant...");
  await complianceRegistry.setComplianceStatus(
    deployer.address,
    1, // ComplianceStatus.VERIFIED
    2, // ComplianceLevel.ADVANCED
    "US",
    50 // risk score
  );

  // Add some mock price feeds to OracleAdapter
  console.log("- Adding mock price feeds...");
  await oracleAdapter.addPriceFeed(
    "iYLD",
    deployer.address, // Mock feed address
    18,
    3600, // 1 hour heartbeat
    "iYield Token USD Price Feed"
  );

  await oracleAdapter.addPriceFeed(
    "USDC",
    deployer.address, // Mock feed address
    6,
    3600, // 1 hour heartbeat
    "USDC USD Price Feed"
  );

  // Update mock prices
  const iYLDFeedId = ethers.keccak256(ethers.toUtf8Bytes("iYLD"));
  const USDCFeedId = ethers.keccak256(ethers.toUtf8Bytes("USDC"));
  
  await oracleAdapter.updatePrice(iYLDFeedId, ethers.parseEther("1")); // $1 USD
  await oracleAdapter.updatePrice(USDCFeedId, "1000000"); // $1 USD (6 decimals)

  // Add supported assets to Vault
  console.log("- Adding supported assets to Vault...");
  await vault.addAsset(
    iYieldTokenAddress,
    5000, // 50% max allocation
    deployer.address, // Oracle (placeholder)
    18
  );

  await vault.addAsset(
    mockUSDCAddress,
    5000, // 50% max allocation
    deployer.address, // Oracle (placeholder)
    18
  );

  console.log("\n🎉 iYield Protocol setup complete!");
  
  // Display contract addresses
  console.log("\n📄 Contract Addresses:");
  console.log("======================");
  console.log(`ComplianceRegistry: ${complianceRegistryAddress}`);
  console.log(`OracleAdapter:      ${oracleAdapterAddress}`);
  console.log(`iYieldToken:        ${iYieldTokenAddress}`);
  console.log(`Vault:              ${vaultAddress}`);
  console.log(`LiquidityPool:      ${liquidityPoolAddress}`);
  console.log(`Mock USDC:          ${mockUSDCAddress}`);

  console.log("\n📊 Deployment Summary:");
  console.log("======================");
  console.log(`Total contracts deployed: 6`);
  console.log(`Deployer address: ${deployer.address}`);
  console.log(`Initial iYLD supply: 1,000,000 tokens`);
  console.log(`Initial USDC supply: 1,000,000 tokens`);
  console.log(`Liquidity pool fee: 0.3%`);

  // Save deployment info to file
  const deploymentInfo = {
    network: (await ethers.provider.getNetwork()).name,
    chainId: (await ethers.provider.getNetwork()).chainId.toString(),
    deployer: deployer.address,
    contracts: {
      ComplianceRegistry: complianceRegistryAddress,
      OracleAdapter: oracleAdapterAddress,
      iYieldToken: iYieldTokenAddress,
      Vault: vaultAddress,
      LiquidityPool: liquidityPoolAddress,
      MockUSDC: mockUSDCAddress
    },
    deploymentDate: new Date().toISOString()
  };

  const fs = require('fs');
  fs.writeFileSync(
    'deployment-info.json', 
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("\n💾 Deployment info saved to deployment-info.json");
  console.log("\nDeployment completed successfully! 🚀");
}

// Execute deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });