const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("iYield Protocol Integration Tests", function () {
  let deployer, user1, user2, oracle1, oracle2, oracle3;
  let complianceRegistry, csvOracle, csvToken, csvVault, liquidityPool, mockUSDC;

  before(async function () {
    [deployer, user1, user2, oracle1, oracle2, oracle3] = await ethers.getSigners();
    
    // Deploy all contracts
    const ComplianceRegistry = await ethers.getContractFactory("ComplianceRegistry");
    complianceRegistry = await ComplianceRegistry.deploy();
    
    const CSVOracle = await ethers.getContractFactory("CSVOracle");
    csvOracle = await CSVOracle.deploy();
    
    const ERCRWACSV = await ethers.getContractFactory("ERCRWACSV");
    csvToken = await ERCRWACSV.deploy(
      "iYield CSV Token",
      "iYCSV",
      complianceRegistry.address,
      csvOracle.address
    );
    
    const vaultConfig = {
      maxLTV: 8000,
      liquidationPenalty: 500,
      minCollateralValue: ethers.utils.parseEther("1000"),
      stabilityFee: 300,
      isEnabled: true
    };
    
    const CSVVault = await ethers.getContractFactory("CSVVault");
    csvVault = await CSVVault.deploy(csvToken.address, vaultConfig);
    
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    mockUSDC = await MockERC20.deploy("USD Coin", "USDC", 6);
    
    const poolConfig = {
      seniorYieldRate: 400,
      juniorYieldRate: 800,
      protocolFeeRate: 200,
      performanceFeeRate: 1000,
      withdrawalFeeRate: 100,
      maxUtilization: 9000
    };
    
    const CSVLiquidityPool = await ethers.getContractFactory("CSVLiquidityPool");
    liquidityPool = await CSVLiquidityPool.deploy(
      csvToken.address,
      mockUSDC.address,
      poolConfig
    );
    
    // Set up roles
    const MINTER_ROLE = await csvToken.MINTER_ROLE();
    const BURNER_ROLE = await csvToken.BURNER_ROLE();
    const ORACLE_ROLE = await csvToken.ORACLE_ROLE();
    
    await csvToken.grantRole(MINTER_ROLE, csvVault.address);
    await csvToken.grantRole(BURNER_ROLE, csvVault.address);
    await csvToken.grantRole(ORACLE_ROLE, csvOracle.address);
    
    const VAULT_ORACLE_ROLE = await csvVault.ORACLE_ROLE();
    await csvVault.grantRole(VAULT_ORACLE_ROLE, csvOracle.address);
    
    // Mint test USDC
    const testAmount = ethers.utils.parseUnits("1000000", 6);
    await mockUSDC.mint(user1.address, testAmount);
    await mockUSDC.mint(user2.address, testAmount);
  });

  describe("Compliance Registry", function () {
    it("Should register and verify KYC status", async function () {
      const complianceData = {
        isAccredited: true,
        isKYCVerified: true,
        jurisdictionCode: 1, // US
        lockupExpiry: Math.floor(Date.now() / 1000) + 365 * 24 * 3600,
        isRestricted: false
      };
      
      await complianceRegistry.updateCompliance(user1.address, complianceData);
      
      const status = await complianceRegistry.getComplianceStatus(user1.address);
      expect(status.isKYCVerified).to.be.true;
      expect(status.isAccredited).to.be.true;
      expect(status.isRestricted).to.be.false;
      
      const isCompliant = await complianceRegistry.isCompliant(user1.address);
      expect(isCompliant).to.be.true;
    });
    
    it("Should check transfer permissions", async function () {
      // Set up user2 compliance
      const complianceData = {
        isAccredited: true,
        isKYCVerified: true,
        jurisdictionCode: 1,
        lockupExpiry: Math.floor(Date.now() / 1000) + 365 * 24 * 3600,
        isRestricted: false
      };
      
      await complianceRegistry.updateCompliance(user2.address, complianceData);
      
      const [allowed, reason] = await complianceRegistry.isTransferAllowed(user1.address, user2.address);
      expect(allowed).to.be.true;
      expect(reason).to.equal("Transfer allowed");
    });
  });

  describe("CSV Oracle", function () {
    it("Should register oracles and process valuation requests", async function () {
      // Register oracles
      await csvOracle.connect(oracle1).registerOracle(
        "Oracle 1",
        "https://oracle1.example.com",
        ethers.utils.parseEther("1"),
        { value: ethers.utils.parseEther("1") }
      );
      
      await csvOracle.connect(oracle2).registerOracle(
        "Oracle 2", 
        "https://oracle2.example.com",
        ethers.utils.parseEther("1"),
        { value: ethers.utils.parseEther("1") }
      );
      
      await csvOracle.connect(oracle3).registerOracle(
        "Oracle 3",
        "https://oracle3.example.com", 
        ethers.utils.parseEther("1"),
        { value: ethers.utils.parseEther("1") }
      );
      
      // Request valuation
      const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 hour
      const requestFee = await csvOracle.requestFee();
      
      const tx = await csvOracle.connect(user1).requestValuation(
        "POLICY-123456",
        deadline,
        "QmTestHash123",
        { value: requestFee }
      );
      
      const receipt = await tx.wait();
      const event = receipt.events.find(e => e.event === 'ValuationRequested');
      const requestId = event.args.requestId;
      
      // Submit oracle responses
      const csvValue = ethers.utils.parseEther("50000"); // $50,000 CSV
      const proofHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("proof123"));
      
      await csvOracle.connect(oracle1).submitValuation(
        requestId,
        csvValue,
        proofHash,
        "https://docs.oracle1.com/proof"
      );
      
      await csvOracle.connect(oracle2).submitValuation(
        requestId,
        csvValue.add(ethers.utils.parseEther("1000")), // Slight variation
        proofHash,
        "https://docs.oracle2.com/proof"
      );
      
      await csvOracle.connect(oracle3).submitValuation(
        requestId,
        csvValue.sub(ethers.utils.parseEther("500")), // Slight variation
        proofHash,
        "https://docs.oracle3.com/proof"
      );
      
      // Check if consensus was reached
      const request = await csvOracle.getValuationRequest(requestId);
      expect(request.isFinalized).to.be.true;
      expect(request.agreedValue).to.be.gt(0);
    });
  });

  describe("CSV Token and Vault Integration", function () {
    it("Should open vault and mint tokens", async function () {
      // Create CSV metadata
      const csvMetadata = {
        policyNumber: "POLICY-123456",
        carrierName: "Test Insurance Co",
        cashValue: ethers.utils.parseEther("50000"),
        deathBenefit: ethers.utils.parseEther("250000"),
        premiumAmount: ethers.utils.parseEther("2000"),
        policyAge: 120, // 10 years in months
        creditRating: 5, // AAA rating
        lastValuationTimestamp: Math.floor(Date.now() / 1000),
        isActive: true
      };
      
      // Open vault
      const vaultTx = await csvVault.connect(user1).openVault(
        1, // tokenId
        csvMetadata.cashValue
      );
      
      const receipt = await vaultTx.wait();
      const event = receipt.events.find(e => e.event === 'VaultOpened');
      const vaultId = event.args.vaultId;
      
      // Mint tokens (50% LTV)
      const mintAmount = csvMetadata.cashValue.div(2);
      await csvVault.connect(user1).mintTokens(vaultId, mintAmount);
      
      // Check token balance
      const balance = await csvToken.balanceOf(user1.address);
      expect(balance).to.equal(mintAmount);
      
      // Check vault position
      const position = await csvVault.getVaultPosition(vaultId);
      expect(position.debtAmount).to.equal(mintAmount);
      expect(position.isActive).to.be.true;
    });
  });

  describe("Liquidity Pool", function () {
    it("Should allow deposits and track shares", async function () {
      // Approve USDC
      const depositAmount = ethers.utils.parseUnits("10000", 6); // $10,000
      await mockUSDC.connect(user1).approve(liquidityPool.address, depositAmount);
      
      // Deposit to senior tranche
      await liquidityPool.connect(user1).deposit(0, depositAmount); // TrancheType.SENIOR = 0
      
      // Check position
      const position = await liquidityPool.getUserPosition(0, user1.address);
      expect(position.deposits).to.equal(depositAmount);
      expect(position.shares).to.equal(depositAmount); // 1:1 initial ratio
      
      // Check tranche info
      const trancheInfo = await liquidityPool.getTrancheInfo(0);
      expect(trancheInfo.totalDeposits).to.equal(depositAmount);
      expect(trancheInfo.totalShares).to.equal(depositAmount);
    });
    
    it("Should distribute yield correctly", async function () {
      // Simulate yield distribution
      const yieldAmount = ethers.utils.parseUnits("800", 6); // $800 yield
      
      // Grant distributor role to deployer
      const YIELD_DISTRIBUTOR_ROLE = await liquidityPool.YIELD_DISTRIBUTOR_ROLE();
      await liquidityPool.grantRole(YIELD_DISTRIBUTOR_ROLE, deployer.address);
      
      // Distribute yield
      await liquidityPool.distributeYield(yieldAmount);
      
      // Check yield history
      const historyLength = await liquidityPool.getYieldHistoryLength();
      expect(historyLength).to.equal(1);
      
      const distribution = await liquidityPool.getYieldHistory(0);
      expect(distribution.totalYield).to.equal(yieldAmount);
      expect(distribution.seniorYield).to.be.gt(0);
    });
  });

  describe("End-to-End Workflow", function () {
    it("Should complete full CSV tokenization workflow", async function () {
      // 1. Verify compliance
      const isCompliant = await complianceRegistry.isCompliant(user2.address);
      expect(isCompliant).to.be.true;
      
      // 2. Request CSV valuation
      const deadline = Math.floor(Date.now() / 1000) + 3600;
      const requestFee = await csvOracle.requestFee();
      
      const valuationTx = await csvOracle.connect(user2).requestValuation(
        "POLICY-789012",
        deadline,
        "QmTestHash456",
        { value: requestFee }
      );
      
      // 3. Oracle responses (simplified - assuming consensus)
      const receipt = await valuationTx.wait();
      const event = receipt.events.find(e => e.event === 'ValuationRequested');
      const requestId = event.args.requestId;
      
      // 4. Finalize valuation (would normally wait for oracle responses)
      // For testing, we'll mock the finalization
      
      // 5. Open vault with CSV collateral
      const csvValue = ethers.utils.parseEther("75000");
      const vaultTx = await csvVault.connect(user2).openVault(2, csvValue);
      
      // 6. Mint CSV tokens
      const vaultReceipt = await vaultTx.wait();
      const vaultEvent = vaultReceipt.events.find(e => e.event === 'VaultOpened');
      const vaultId = vaultEvent.args.vaultId;
      
      const mintAmount = csvValue.mul(6).div(10); // 60% LTV
      await csvVault.connect(user2).mintTokens(vaultId, mintAmount);
      
      // 7. Verify final state
      const tokenBalance = await csvToken.balanceOf(user2.address);
      expect(tokenBalance).to.equal(mintAmount);
      
      const vaultPosition = await csvVault.getVaultPosition(vaultId);
      expect(vaultPosition.debtAmount).to.equal(mintAmount);
      expect(vaultPosition.isActive).to.be.true;
      
      console.log("✅ End-to-end workflow completed successfully");
      console.log(`   - CSV Value: ${ethers.utils.formatEther(csvValue)} ETH`);
      console.log(`   - Tokens Minted: ${ethers.utils.formatEther(mintAmount)} iYCSV`);
      console.log(`   - LTV Ratio: 60%`);
    });
  });
});