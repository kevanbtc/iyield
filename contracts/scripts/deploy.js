const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying iYield Protocol contracts...");
  
  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)));

  // Deploy ComplianceRegistry first
  console.log("\n1. Deploying ComplianceRegistry...");
  const ComplianceRegistry = await ethers.getContractFactory("ComplianceRegistry");
  const complianceRegistry = await ComplianceRegistry.deploy(deployer.address);
  await complianceRegistry.waitForDeployment();
  const complianceAddress = await complianceRegistry.getAddress();
  console.log("ComplianceRegistry deployed to:", complianceAddress);

  // Deploy CSVOracle
  console.log("\n2. Deploying CSVOracle...");
  const CSVOracle = await ethers.getContractFactory("CSVOracle");
  // For testing, use deployer as initial attestor
  const csvOracle = await CSVOracle.deploy(deployer.address, [deployer.address]);
  await csvOracle.waitForDeployment();
  const oracleAddress = await csvOracle.getAddress();
  console.log("CSVOracle deployed to:", oracleAddress);

  // Deploy main ERCRWACSV token
  console.log("\n3. Deploying ERCRWACSV Token...");
  const ERCRWACSV = await ethers.getContractFactory("ERCRWACSV");
  const csvToken = await ERCRWACSV.deploy(
    "iYield CSV Token",  // name
    "iCSV",             // symbol
    complianceAddress,   // compliance registry
    oracleAddress,       // CSV oracle
    deployer.address     // admin
  );
  await csvToken.waitForDeployment();
  const tokenAddress = await csvToken.getAddress();
  console.log("ERCRWACSV Token deployed to:", tokenAddress);

  // Set up initial configurations
  console.log("\n4. Setting up initial configurations...");
  
  // Set deployer as KYC verified and accredited for testing
  await complianceRegistry.setKYCStatus(deployer.address, true);
  await complianceRegistry.setAccreditedStatus(deployer.address, true);
  await complianceRegistry.setJurisdiction(deployer.address, "US");
  console.log("✓ Deployer compliance status configured");

  // Grant oracle role to CSV oracle contract
  const ORACLE_ROLE = await csvToken.ORACLE_ROLE();
  await csvToken.grantRole(ORACLE_ROLE, oracleAddress);
  console.log("✓ Oracle role granted to CSVOracle contract");

  // Add a test carrier to the oracle
  const carrierId = ethers.keccak256(ethers.toUtf8Bytes("TEST_CARRIER_001"));
  await csvOracle.addCarrier(carrierId, "Test Insurance Carrier", 950); // AA rating
  console.log("✓ Test carrier added to oracle");

  console.log("\n🎉 Deployment completed successfully!");
  console.log("\nDeployed Contract Addresses:");
  console.log("============================");
  console.log("ComplianceRegistry:", complianceAddress);
  console.log("CSVOracle:         ", oracleAddress);
  console.log("ERCRWACSV Token:   ", tokenAddress);
  
  console.log("\nVerification commands:");
  console.log("===================");
  console.log(`npx hardhat verify --network ${network.name} ${complianceAddress} "${deployer.address}"`);
  console.log(`npx hardhat verify --network ${network.name} ${oracleAddress} "${deployer.address}" "[${deployer.address}]"`);
  console.log(`npx hardhat verify --network ${network.name} ${tokenAddress} "iYield CSV Token" "iCSV" "${complianceAddress}" "${oracleAddress}" "${deployer.address}"`);

  return {
    complianceRegistry: complianceAddress,
    csvOracle: oracleAddress,
    csvToken: tokenAddress
  };
}

// Execute the deployment
main()
  .then((addresses) => {
    console.log("\nDeployment addresses saved:", addresses);
    process.exit(0);
  })
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });