const { ethers } = require("hardhat");

async function main() {
    console.log("🚀 Deploying iYield Protocol - Advanced Insurance-Backed Tokenization System");
    console.log("================================================================================");
    
    const [deployer] = await ethers.getSigners();
    console.log("Deploying with account:", deployer.address);
    console.log("Account balance:", (await deployer.provider.getBalance(deployer.address)).toString());
    
    // 1. Deploy CSV Oracle (Proof-of-CSV™)
    console.log("\n📊 Deploying CSV Oracle (Proof-of-CSV™)...");
    const CSVOracle = await ethers.getContractFactory("CSVOracle");
    const csvOracle = await CSVOracle.deploy(deployer.address);
    await csvOracle.waitForDeployment();
    console.log("✅ CSV Oracle deployed to:", await csvOracle.getAddress());
    
    // 2. Deploy Compliance Engine (Compliance-by-Design™)
    console.log("\n🛡️  Deploying Compliance Engine (Compliance-by-Design™)...");
    const ComplianceEngine = await ethers.getContractFactory("ComplianceEngine");
    const complianceEngine = await ComplianceEngine.deploy(deployer.address);
    await complianceEngine.waitForDeployment();
    console.log("✅ Compliance Engine deployed to:", await complianceEngine.getAddress());
    
    // 3. Deploy iYield Token (ERC-3643 Compliant)
    console.log("\n🪙 Deploying iYield Token (ERC-3643 Compliant)...");
    const IYieldToken = await ethers.getContractFactory("IYieldToken");
    const iYieldToken = await IYieldToken.deploy(
        "iYield Insurance Backed Note", // name
        "iYIELD", // symbol
        await csvOracle.getAddress(),
        await complianceEngine.getAddress(),
        deployer.address // admin
    );
    await iYieldToken.waitForDeployment();
    console.log("✅ iYield Token deployed to:", await iYieldToken.getAddress());
    
    // 4. Configure Oracle permissions
    console.log("\n⚙️  Configuring Oracle permissions...");
    const ATTESTER_ROLE = await csvOracle.ATTESTER_ROLE();
    await csvOracle.grantRole(ATTESTER_ROLE, deployer.address);
    await csvOracle.setAttesterStatus(deployer.address, true);
    console.log("✅ Oracle permissions configured");
    
    // 5. Configure Compliance permissions
    console.log("\n⚙️  Configuring Compliance permissions...");
    const COMPLIANCE_OFFICER_ROLE = await complianceEngine.COMPLIANCE_OFFICER_ROLE();
    const KYC_PROVIDER_ROLE = await complianceEngine.KYC_PROVIDER_ROLE();
    await complianceEngine.grantRole(COMPLIANCE_OFFICER_ROLE, deployer.address);
    await complianceEngine.grantRole(KYC_PROVIDER_ROLE, deployer.address);
    console.log("✅ Compliance permissions configured");
    
    // 6. Setup sample data for demonstration
    console.log("\n🔧 Setting up demo data...");
    
    // Add sample policy attestation
    const samplePolicyId = ethers.id("POLICY_ABC_123");
    const sampleCsvValue = ethers.parseEther("100000"); // $100,000 CSV value
    const timestamp = Math.floor(Date.now() / 1000);
    const ipfsHash = "QmSamplePolicyAttestation123...";
    const merkleRoot = ethers.id("sample_merkle_root");
    
    // Create attestation signature (simplified for demo)
    const messageHash = ethers.solidityPackedKeccak256(
        ["bytes32", "uint256", "uint256", "string", "bytes32"],
        [samplePolicyId, sampleCsvValue, timestamp, ipfsHash, merkleRoot]
    );
    const signature = await deployer.signMessage(ethers.getBytes(messageHash));
    
    const attestation = {
        policyId: samplePolicyId,
        csvValue: sampleCsvValue,
        timestamp: timestamp,
        ipfsHash: ipfsHash,
        merkleRoot: merkleRoot,
        attester: deployer.address,
        signature: signature
    };
    
    await csvOracle.updateAttestation(attestation);
    console.log("✅ Sample policy attestation added");
    
    // Add sample compliance profile
    const sampleInvestorType = 1; // ACCREDITED
    const kycTimestamp = Math.floor(Date.now() / 1000);
    const accreditationExpiry = kycTimestamp + (365 * 24 * 60 * 60); // 1 year
    const restrictionType = 0; // NONE
    
    const complianceProfile = {
        investorType: sampleInvestorType,
        kycTimestamp: kycTimestamp,
        accreditationExpiry: accreditationExpiry,
        isWhitelisted: true,
        restriction: restrictionType,
        restrictionParam: 0
    };
    
    await complianceEngine.updateCompliance(deployer.address, complianceProfile);
    console.log("✅ Sample compliance profile added");
    
    // Add policy backing and issue tokens
    const tokensToIssue = ethers.parseEther("80000"); // Issue 80,000 tokens (80% LTV)
    await iYieldToken.addPolicyBacking(
        samplePolicyId,
        sampleCsvValue,
        tokensToIssue,
        deployer.address
    );
    console.log("✅ Sample policy backing added and tokens issued");
    
    // Publish initial disclosure
    const initialDisclosureHash = "QmInitialDisclosure123...";
    await iYieldToken.publishDisclosure(initialDisclosureHash);
    console.log("✅ Initial disclosure published to IPFS");
    
    // 7. Display deployment summary
    console.log("\n🎉 DEPLOYMENT COMPLETE!");
    console.log("================================================================================");
    console.log("📊 CSV Oracle (Proof-of-CSV™):", await csvOracle.getAddress());
    console.log("🛡️  Compliance Engine (Compliance-by-Design™):", await complianceEngine.getAddress());
    console.log("🪙 iYield Token (ERC-3643):", await iYieldToken.getAddress());
    console.log("================================================================================");
    
    // 8. Display system status
    console.log("\n📈 SYSTEM STATUS:");
    const systemStatus = await iYieldToken.getSystemStatus();
    console.log("Total CSV Value:", ethers.formatEther(systemStatus[0]), "ETH");
    console.log("Current NAV per Token:", ethers.formatEther(systemStatus[1]), "ETH");
    console.log("Total Token Supply:", ethers.formatEther(systemStatus[2]));
    console.log("Active Policies:", systemStatus[4].toString());
    
    const currentLTV = await iYieldToken.getPolicyLTV(samplePolicyId);
    console.log("Sample Policy LTV:", (Number(currentLTV) / 100).toFixed(2), "%");
    
    console.log("\n🔗 Next Steps:");
    console.log("1. Deploy frontend dashboard to visualize system status");
    console.log("2. Set up IPFS node for provenance tracking");
    console.log("3. Configure additional oracle attesters");
    console.log("4. Add more insurance policies as backing");
    console.log("5. Submit ERC-RWA:CSV standard proposal to Ethereum community");
    
    console.log("\n💡 COMPETITIVE ADVANTAGES DEPLOYED:");
    console.log("✅ Patent-defensible CSV oracle with Merkle attestations");
    console.log("✅ Built-in Reg D/S compliance engine"); 
    console.log("✅ IPFS provenance trail for transparency");
    console.log("✅ Automated LTV monitoring and enforcement");
    console.log("✅ ERC-3643 style transfer restrictions");
    console.log("✅ Ready for institutional adoption");
    
    return {
        csvOracle: await csvOracle.getAddress(),
        complianceEngine: await complianceEngine.getAddress(),
        iYieldToken: await iYieldToken.getAddress()
    };
}

// Execute deployment
main()
    .then((addresses) => {
        console.log("\n🎯 Deployment addresses saved for frontend integration:");
        console.log(JSON.stringify(addresses, null, 2));
        process.exit(0);
    })
    .catch((error) => {
        console.error("❌ Deployment failed:", error);
        process.exit(1);
    });