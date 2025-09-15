const hre = require("hardhat");

async function main() {
  console.log("Deploying iYield Protocol contracts...");

  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy ComplianceRegistry first
  console.log("Deploying ComplianceRegistry...");
  const ComplianceRegistry = await hre.ethers.getContractFactory("ComplianceRegistry");
  const complianceRegistry = await ComplianceRegistry.deploy(deployer.address);
  await complianceRegistry.waitForDeployment();
  console.log("ComplianceRegistry deployed to:", await complianceRegistry.getAddress());

  // Deploy CSV Oracle
  console.log("Deploying CSVOracle...");
  const CSVOracle = await hre.ethers.getContractFactory("CSVOracle");
  const csvOracle = await CSVOracle.deploy(deployer.address);
  await csvOracle.waitForDeployment();
  console.log("CSVOracle deployed to:", await csvOracle.getAddress());

  // Deploy ERC-RWA:CSV Token
  console.log("Deploying ERCRWACSV...");
  const ERCRWACSV = await hre.ethers.getContractFactory("ERCRWACSV");
  const ercRwacsv = await ERCRWACSV.deploy(
    deployer.address, // admin
    deployer.address, // pauser
    deployer.address  // minter
  );
  await ercRwacsv.waitForDeployment();
  console.log("ERCRWACSV deployed to:", await ercRwacsv.getAddress());

  // Deploy CSV Vault
  console.log("Deploying CSVVault...");
  const CSVVault = await hre.ethers.getContractFactory("CSVVault");
  const csvVault = await CSVVault.deploy(
    await ercRwacsv.getAddress(),
    deployer.address
  );
  await csvVault.waitForDeployment();
  console.log("CSVVault deployed to:", await csvVault.getAddress());

  // Deploy Liquidity Pool
  console.log("Deploying CSVLiquidityPool...");
  const CSVLiquidityPool = await hre.ethers.getContractFactory("CSVLiquidityPool");
  const csvLiquidityPool = await CSVLiquidityPool.deploy(deployer.address);
  await csvLiquidityPool.waitForDeployment();
  console.log("CSVLiquidityPool deployed to:", await csvLiquidityPool.getAddress());

  // Save deployment addresses
  const deploymentInfo = {
    network: hre.network.name,
    deployer: deployer.address,
    contracts: {
      ComplianceRegistry: await complianceRegistry.getAddress(),
      CSVOracle: await csvOracle.getAddress(),
      ERCRWACSV: await ercRwacsv.getAddress(),
      CSVVault: await csvVault.getAddress(),
      CSVLiquidityPool: await csvLiquidityPool.getAddress()
    },
    timestamp: new Date().toISOString()
  };

  console.log("\n=== Deployment Summary ===");
  console.log(JSON.stringify(deploymentInfo, null, 2));
  
  // Save to file
  const fs = require("fs");
  const deploymentPath = `./deployments/${hre.network.name}-deployment.json`;
  fs.mkdirSync("./deployments", { recursive: true });
  fs.writeFileSync(deploymentPath, JSON.stringify(deploymentInfo, null, 2));
  console.log(`\nDeployment info saved to: ${deploymentPath}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });