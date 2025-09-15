const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());
  
  // Deploy ComplianceRegistry
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
  console.log("\n🏷️  Deploying ERCRWACSV token...");
  const ERCRWACSV = await ethers.getContractFactory("ERCRWACSV");
  const ercrwacsv = await ERCRWACSV.deploy(
    complianceRegistry.address,
    csvOracle.address
  );
  await ercrwacsv.deployed();
  console.log("✅ ERCRWACSV deployed to:", ercrwacsv.address);
  
  // Deploy CSVVault
  console.log("\n🏛️  Deploying CSVVault...");
  const CSVVault = await ethers.getContractFactory("CSVVault");
  const csvVault = await CSVVault.deploy(
    csvOracle.address,
    complianceRegistry.address
  );
  await csvVault.deployed();
  console.log("✅ CSVVault deployed to:", csvVault.address);
  
  // For the pool, we'll use a mock USDC for testing
  console.log("\n💰 Deploying Mock USDC...");
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const mockUSDC = await MockERC20.deploy("Mock USDC", "mUSDC", 6);
  await mockUSDC.deployed();
  console.log("✅ Mock USDC deployed to:", mockUSDC.address);
  
  // Deploy CSVLiquidityPool
  console.log("\n🌊 Deploying CSVLiquidityPool...");
  const CSVLiquidityPool = await ethers.getContractFactory("CSVLiquidityPool");
  const csvLiquidityPool = await CSVLiquidityPool.deploy(
    mockUSDC.address,
    complianceRegistry.address
  );
  await csvLiquidityPool.deployed();
  console.log("✅ CSVLiquidityPool deployed to:", csvLiquidityPool.address);
  
  // Setup initial permissions and configurations
  console.log("\n⚙️  Setting up permissions and configurations...");
  
  // Grant roles
  const MINTER_ROLE = await ercrwacsv.MINTER_ROLE();
  const BURNER_ROLE = await ercrwacsv.BURNER_ROLE();
  const ORACLE_UPDATER_ROLE = await ercrwacsv.ORACLE_UPDATER_ROLE();
  
  await ercrwacsv.grantRole(MINTER_ROLE, csvVault.address);
  await ercrwacsv.grantRole(BURNER_ROLE, csvVault.address);
  console.log("✅ Granted MINTER and BURNER roles to Vault");
  
  // Add deployer as attestor to oracle
  await csvOracle.addAttestor(deployer.address);
  console.log("✅ Added deployer as oracle attestor");
  
  // Set deployer as compliant for testing
  await complianceRegistry.setCompliant(
    deployer.address,
    2, // Standard compliance level
    365 * 24 * 60 * 60 // 1 year
  );
  console.log("✅ Set deployer as compliant");
  
  // Add ETH as supported collateral in vault (using address(0) for ETH)
  await csvVault.addSupportedCollateral(ethers.constants.AddressZero, 8000); // 80% collateral factor
  console.log("✅ Added ETH as supported collateral");
  
  // Mint some mock USDC to deployer for testing
  await mockUSDC.mint(deployer.address, ethers.utils.parseUnits("1000000", 6)); // 1M USDC
  console.log("✅ Minted 1M mock USDC to deployer");
  
  // Save deployment addresses
  const deploymentInfo = {
    network: hre.network.name,
    chainId: (await ethers.provider.getNetwork()).chainId,
    deployer: deployer.address,
    timestamp: new Date().toISOString(),
    contracts: {
      ComplianceRegistry: complianceRegistry.address,
      CSVOracle: csvOracle.address,
      ERCRWACSV: ercrwacsv.address,
      CSVVault: csvVault.address,
      CSVLiquidityPool: csvLiquidityPool.address,
      MockUSDC: mockUSDC.address
    },
    gasUsed: {
      // Add gas tracking if needed
    }
  };
  
  console.log("\n📄 Deployment Summary:");
  console.log("=======================");
  console.log(`Network: ${deploymentInfo.network} (${deploymentInfo.chainId})`);
  console.log(`Deployer: ${deploymentInfo.deployer}`);
  console.log(`Timestamp: ${deploymentInfo.timestamp}`);
  console.log("\n📝 Contract Addresses:");
  Object.entries(deploymentInfo.contracts).forEach(([name, address]) => {
    console.log(`${name}: ${address}`);
  });
  
  // Save to file for frontend integration
  const fs = require('fs');
  const path = require('path');
  
  const deploymentsDir = path.join(__dirname, '../deployments');
  if (!fs.existsSync(deploymentsDir)) {
    fs.mkdirSync(deploymentsDir, { recursive: true });
  }
  
  const deploymentFile = path.join(deploymentsDir, `${deploymentInfo.network}-${deploymentInfo.chainId}.json`);
  fs.writeFileSync(deploymentFile, JSON.stringify(deploymentInfo, null, 2));
  
  console.log(`\n💾 Deployment info saved to: ${deploymentFile}`);
  
  // Verify contracts on Etherscan if not on local network
  if (hre.network.name !== "hardhat" && hre.network.name !== "localhost") {
    console.log("\n🔍 Waiting for block confirmations before verification...");
    await complianceRegistry.deployTransaction.wait(5);
    
    try {
      console.log("Verifying ComplianceRegistry...");
      await hre.run("verify:verify", {
        address: complianceRegistry.address,
        constructorArguments: []
      });
      
      console.log("Verifying CSVOracle...");
      await hre.run("verify:verify", {
        address: csvOracle.address,
        constructorArguments: []
      });
      
      console.log("Verifying ERCRWACSV...");
      await hre.run("verify:verify", {
        address: ercrwacsv.address,
        constructorArguments: [complianceRegistry.address, csvOracle.address]
      });
      
      console.log("Verifying CSVVault...");
      await hre.run("verify:verify", {
        address: csvVault.address,
        constructorArguments: [csvOracle.address, complianceRegistry.address]
      });
      
      console.log("Verifying CSVLiquidityPool...");
      await hre.run("verify:verify", {
        address: csvLiquidityPool.address,
        constructorArguments: [mockUSDC.address, complianceRegistry.address]
      });
      
      console.log("✅ All contracts verified on Etherscan");
    } catch (error) {
      console.log("⚠️  Verification failed:", error.message);
    }
  }
  
  console.log("\n🎉 Deployment completed successfully!");
  console.log("\n🚀 Next steps:");
  console.log("1. Update frontend with new contract addresses");
  console.log("2. Configure oracle attestors for production");
  console.log("3. Set up compliance registry with real KYC providers");
  console.log("4. Deploy to production networks (Mainnet/Base/Arbitrum)");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  });