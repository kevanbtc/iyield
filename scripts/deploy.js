const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  // Deploy Compliance Registry
  const ComplianceRegistry = await ethers.getContractFactory("ComplianceRegistry");
  const registry = await ComplianceRegistry.deploy();
  await registry.waitForDeployment();
  console.log("ComplianceRegistry deployed at:", await registry.getAddress());

  // Deploy Token
  const iYieldToken = await ethers.getContractFactory("iYieldToken");
  const token = await iYieldToken.deploy(await registry.getAddress());
  await token.waitForDeployment();
  console.log("iYieldToken deployed at:", await token.getAddress());

  // Deploy Oracle
  const OracleAdapter = await ethers.getContractFactory("OracleAdapter");
  const oracle = await OracleAdapter.deploy();
  await oracle.waitForDeployment();
  console.log("OracleAdapter deployed at:", await oracle.getAddress());

  // Deploy Vault
  const Vault = await ethers.getContractFactory("Vault");
  const vault = await Vault.deploy(await token.getAddress(), await oracle.getAddress());
  await vault.waitForDeployment();
  console.log("Vault deployed at:", await vault.getAddress());

  // Deploy Liquidity Pool (using token as placeholder stablecoin for now)
  const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
  const pool = await LiquidityPool.deploy(await token.getAddress(), await vault.getAddress());
  await pool.waitForDeployment();
  console.log("LiquidityPool deployed at:", await pool.getAddress());

  // Setup permissions
  console.log("\nSetting up permissions...");
  
  // Add vault as minter for the token
  await token.addMinter(await vault.getAddress());
  console.log("Added vault as token minter");
  
  // Add vault as burner for the token  
  await token.addBurner(await vault.getAddress());
  console.log("Added vault as token burner");
  
  // Whitelist the deployer for testing
  await registry.setWhitelist(deployer.address, true);
  console.log("Whitelisted deployer address");

  console.log("\nDeployment complete!");
  console.log("=============================");
  console.log("ComplianceRegistry:", await registry.getAddress());
  console.log("iYieldToken:", await token.getAddress());
  console.log("OracleAdapter:", await oracle.getAddress());
  console.log("Vault:", await vault.getAddress());
  console.log("LiquidityPool:", await pool.getAddress());
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});