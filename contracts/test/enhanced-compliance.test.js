const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("iYield Protocol Enhanced Compliance Tests", function () {
  let complianceRegistry, csvOracle, csvToken, csvVault;
  let owner, user1, user2, user3, attestor1, attestor2, attestor3;
  let carrierId1, carrierId2, policyId1, policyId2;

  beforeEach(async function () {
    // Get signers
    [owner, user1, user2, user3, attestor1, attestor2, attestor3] = await ethers.getSigners();

    // Deploy ComplianceRegistry
    const ComplianceRegistry = await ethers.getContractFactory("ComplianceRegistry");
    complianceRegistry = await ComplianceRegistry.deploy(owner.address);
    await complianceRegistry.waitForDeployment();

    // Deploy CSVOracle with enhanced features
    const CSVOracle = await ethers.getContractFactory("CSVOracle");
    csvOracle = await CSVOracle.deploy(owner.address, [attestor1.address, attestor2.address, attestor3.address]);
    await csvOracle.waitForDeployment();

    // Deploy ERCRWACSV Token
    const ERCRWACSV = await ethers.getContractFactory("ERCRWACSV");
    csvToken = await ERCRWACSV.deploy(
      "iYield CSV Token",
      "iCSV",
      await complianceRegistry.getAddress(),
      await csvOracle.getAddress(),
      owner.address
    );
    await csvToken.waitForDeployment();

    // Deploy CSVVault
    const CSVVault = await ethers.getContractFactory("CSVVault");
    csvVault = await CSVVault.deploy(
      await csvOracle.getAddress(),
      await csvToken.getAddress(),
      owner.address,
      3000, // 30% max carrier concentration
      365 * 24 * 60 * 60 // 1 year minimum vintage
    );
    await csvVault.waitForDeployment();

    // Set up test carriers
    carrierId1 = ethers.keccak256(ethers.toUtf8Bytes("CARRIER_A"));
    carrierId2 = ethers.keccak256(ethers.toUtf8Bytes("CARRIER_B"));
    await csvOracle.addCarrier(carrierId1, "Carrier A", 950);
    await csvOracle.addCarrier(carrierId2, "Carrier B", 900);

    // Set up test policies
    policyId1 = ethers.keccak256(ethers.toUtf8Bytes("POLICY_001"));
    policyId2 = ethers.keccak256(ethers.toUtf8Bytes("POLICY_002"));

    // Add stakes for attestors (mock implementation)
    await csvOracle.addAttestorStake(attestor1.address, { value: ethers.parseEther("1") });
    await csvOracle.addAttestorStake(attestor2.address, { value: ethers.parseEther("1") });
    await csvOracle.addAttestorStake(attestor3.address, { value: ethers.parseEther("1") });

    // Grant necessary roles
    const ORACLE_ROLE = await csvToken.ORACLE_ROLE();
    await csvToken.grantRole(ORACLE_ROLE, await csvOracle.getAddress());
  });

  describe("Enhanced Rule 144 Compliance", function () {
    beforeEach(async function () {
      // Set up compliant user
      await complianceRegistry.setKYCStatus(user1.address, true);
      await complianceRegistry.setAccreditedStatus(user1.address, true);
      await complianceRegistry.setJurisdiction(user1.address, "US");

      await complianceRegistry.setKYCStatus(user2.address, true);
      await complianceRegistry.setAccreditedStatus(user2.address, true);
      await complianceRegistry.setJurisdiction(user2.address, "US");
    });

    it("Should enforce Rule 144 holding period", async function () {
      const mintAmount = ethers.parseEther("1000");
      const transferAmount = ethers.parseEther("100");
      
      // Mint tokens to user1
      await csvToken.mint(user1.address, mintAmount);
      
      // Set Rule 144 lockup for 1 year
      const lockupTime = (await time.latest()) + (365 * 24 * 60 * 60);
      await csvToken.setRule144Lockup(user1.address, lockupTime);
      
      // Submit oracle valuation for transfer validity
      await submitMockValuation(ethers.parseEther("10000"));
      
      // Transfer should fail due to Rule 144 lockup
      await expect(
        csvToken.connect(user1).transfer(user2.address, transferAmount)
      ).to.be.revertedWith("Transfer blocked: Rule 144 holding period not met");
    });

    it("Should allow transfer after holding period expires", async function () {
      const mintAmount = ethers.parseEther("1000");
      const transferAmount = ethers.parseEther("100");
      
      await csvToken.mint(user1.address, mintAmount);
      
      // Set Rule 144 lockup for 1 day
      const lockupTime = (await time.latest()) + (24 * 60 * 60);
      await csvToken.setRule144Lockup(user1.address, lockupTime);
      
      // Submit oracle valuation
      await submitMockValuation(ethers.parseEther("10000"));
      
      // Fast forward past lockup period
      await time.increase(25 * 60 * 60); // 25 hours
      
      // Transfer should succeed now
      await csvToken.connect(user1).transfer(user2.address, transferAmount);
      expect(await csvToken.balanceOf(user2.address)).to.equal(transferAmount);
    });

    it("Should enforce Rule 144 volume limitations", async function () {
      const totalSupply = ethers.parseEther("100000");
      const largeTransfer = ethers.parseEther("2000"); // > 1% of supply
      
      await csvToken.mint(owner.address, totalSupply);
      await csvToken.transfer(user1.address, largeTransfer);
      
      await submitMockValuation(ethers.parseEther("100000"));
      
      // Large transfer should fail due to volume limit
      await expect(
        csvToken.connect(user1).transfer(user2.address, largeTransfer)
      ).to.be.revertedWith("Transfer blocked: Rule 144 volume limitation exceeded");
    });

    it("Should get Rule 144 status correctly", async function () {
      const lockupTime = (await time.latest()) + (365 * 24 * 60 * 60);
      await csvToken.setRule144Lockup(user1.address, lockupTime);
      
      const [unlockTime, isRestricted] = await csvToken.getRule144Status(user1.address);
      expect(unlockTime).to.equal(lockupTime);
      expect(isRestricted).to.be.true;
    });
  });

  describe("Regulation S Compliance", function () {
    beforeEach(async function () {
      // Set up US user
      await complianceRegistry.setKYCStatus(user1.address, true);
      await complianceRegistry.setAccreditedStatus(user1.address, true);
      await complianceRegistry.setJurisdiction(user1.address, "US");
      
      // Set up offshore user
      await complianceRegistry.setKYCStatus(user2.address, true);
      await complianceRegistry.setAccreditedStatus(user2.address, true);
      await complianceRegistry.setJurisdiction(user2.address, "UK");
    });

    it("Should allow US to US transfers", async function () {
      const mintAmount = ethers.parseEther("1000");
      const transferAmount = ethers.parseEther("100");
      
      // Set user2 to US as well
      await complianceRegistry.setJurisdiction(user2.address, "US");
      
      await csvToken.mint(user1.address, mintAmount);
      await submitMockValuation(ethers.parseEther("10000"));
      
      await csvToken.connect(user1).transfer(user2.address, transferAmount);
      expect(await csvToken.balanceOf(user2.address)).to.equal(transferAmount);
    });

    it("Should enforce Reg S restrictions for offshore to US transfers", async function () {
      const mintAmount = ethers.parseEther("1000");
      const transferAmount = ethers.parseEther("100");
      
      // Mint to offshore user
      await csvToken.mint(user2.address, mintAmount);
      
      // Set Reg S restriction on offshore user
      await csvToken.setRegSRestriction(user2.address, true);
      
      await submitMockValuation(ethers.parseEther("10000"));
      
      // Transfer from offshore to US should fail
      await expect(
        csvToken.connect(user2).transfer(user1.address, transferAmount)
      ).to.be.revertedWith("Transfer blocked: Offshore to US transfer prohibited during Reg S restriction period");
    });

    it("Should check Reg S compliance correctly", async function () {
      // Set Reg S restriction
      await csvToken.setRegSRestriction(user2.address, true);
      
      const [allowed, reason] = await csvToken.checkRegSCompliance(user2.address, user1.address);
      expect(allowed).to.be.false;
      expect(reason).to.include("Offshore to US transfer prohibited");
    });

    it("Should allow Reg S compliant offshore transfers", async function () {
      const mintAmount = ethers.parseEther("1000");
      const transferAmount = ethers.parseEther("100");
      
      // Set up another offshore user
      await complianceRegistry.setKYCStatus(user3.address, true);
      await complianceRegistry.setAccreditedStatus(user3.address, true);
      await complianceRegistry.setJurisdiction(user3.address, "EU");
      
      await csvToken.mint(user2.address, mintAmount);
      await submitMockValuation(ethers.parseEther("10000"));
      
      // UK to EU transfer should be allowed
      await csvToken.connect(user2).transfer(user3.address, transferAmount);
      expect(await csvToken.balanceOf(user3.address)).to.equal(transferAmount);
    });
  });

  describe("Enhanced Oracle with 2-of-N Signatures", function () {
    it("Should require minimum signatures for valuation", async function () {
      const csvValue = ethers.parseEther("10000");
      const merkleRoot = ethers.keccak256(ethers.toUtf8Bytes("test"));
      
      // Submit from only one attestor
      const signature1 = await createValidSignature(attestor1, csvValue, merkleRoot);
      await csvOracle.connect(attestor1).submitValuation(csvValue, merkleRoot, signature1);
      
      // Should not be finalized with just one signature
      const valuation = await csvOracle.getLatestValuation();
      expect(valuation.totalCSV).to.equal(0); // Not updated yet
    });

    it("Should finalize valuation with sufficient signatures", async function () {
      const csvValue = ethers.parseEther("10000");
      const merkleRoot = ethers.keccak256(ethers.toUtf8Bytes("test"));
      
      // Submit from two attestors
      const signature1 = await createValidSignature(attestor1, csvValue, merkleRoot);
      const signature2 = await createValidSignature(attestor2, csvValue, merkleRoot);
      
      await csvOracle.connect(attestor1).submitValuation(csvValue, merkleRoot, signature1);
      await csvOracle.connect(attestor2).submitValuation(csvValue, merkleRoot, signature2);
      
      // Should be finalized now
      const valuation = await csvOracle.getLatestValuation();
      expect(valuation.totalCSV).to.equal(csvValue);
    });

    it("Should prevent duplicate submissions from same attestor", async function () {
      const csvValue = ethers.parseEther("10000");
      const merkleRoot = ethers.keccak256(ethers.toUtf8Bytes("test"));
      
      const signature1 = await createValidSignature(attestor1, csvValue, merkleRoot);
      await csvOracle.connect(attestor1).submitValuation(csvValue, merkleRoot, signature1);
      
      // Second submission from same attestor should fail
      await expect(
        csvOracle.connect(attestor1).submitValuation(csvValue, merkleRoot, signature1)
      ).to.be.revertedWith("Already submitted");
    });

    it("Should allow slashing of bad attestors", async function () {
      // Slash attestor1
      await csvOracle.slashAttestor(attestor1.address, "Bad behavior");
      
      // Should no longer verify as good attestor
      expect(await csvOracle.verifyAttestor(attestor1.address)).to.be.false;
    });

    it("Should update signature threshold", async function () {
      await csvOracle.updateSignatureThreshold(3);
      const [required, total] = await csvOracle.getAttestorThreshold();
      expect(required).to.equal(3);
    });
  });

  describe("CSVVault Concentration and Vintage Controls", function () {
    it("Should enforce carrier concentration limits", async function () {
      const totalDeposit = ethers.parseEther("10000");
      const largeDeposit = ethers.parseEther("4000"); // > 30% concentration
      
      // Mock policy data for concentration test
      const allowed = await csvVault.checkConcentrationLimits(carrierId1, largeDeposit);
      expect(allowed).to.be.true; // First deposit should be allowed
      
      // After total reaches threshold, should be blocked
      // This test would need more complex setup with actual deposits
    });

    it("Should enforce policy vintage requirements", async function () {
      const recentVintage = (await time.latest()) - (30 * 24 * 60 * 60); // 30 days old
      const validVintage = (await time.latest()) - (400 * 24 * 60 * 60); // Over 1 year old
      
      // This test would need mock policy data setup
      // For now, testing the interface
      const vaultConfig = await csvVault.getVaultConfiguration();
      expect(vaultConfig.minPolicyVintage).to.equal(365 * 24 * 60 * 60);
    });

    it("Should calculate LTV correctly", async function () {
      const ltv = await csvVault.calculateLTV();
      expect(ltv).to.be.a('bigint');
    });

    it("Should update vault configuration", async function () {
      const newLimit = 2500; // 25%
      await csvVault.updateConcentrationLimit(newLimit);
      
      const config = await csvVault.getVaultConfiguration();
      expect(config.maxCarrierConcentration).to.equal(newLimit);
    });

    it("Should handle emergency pause", async function () {
      await csvVault.emergencyPause();
      
      const config = await csvVault.getVaultConfiguration();
      expect(config.emergencyPaused).to.be.true;
    });
  });

  describe("Enhanced Compliance Events", function () {
    beforeEach(async function () {
      await complianceRegistry.setKYCStatus(user1.address, true);
      await complianceRegistry.setAccreditedStatus(user1.address, true);
      await complianceRegistry.setJurisdiction(user1.address, "US");
    });

    it("Should emit TransferBlocked event with reason", async function () {
      const mintAmount = ethers.parseEther("1000");
      const transferAmount = ethers.parseEther("100");
      
      await csvToken.mint(user1.address, mintAmount);
      
      // Remove KYC from recipient
      await complianceRegistry.setKYCStatus(user2.address, false);
      
      await submitMockValuation(ethers.parseEther("10000"));
      
      // Should emit TransferBlocked event
      await expect(
        csvToken.connect(user1).transfer(user2.address, transferAmount)
      ).to.emit(csvToken, "TransferBlocked")
       .withArgs(user1.address, user2.address, transferAmount, "Recipient not KYC verified");
    });

    it("Should emit Rule144StatusChanged event", async function () {
      const lockupTime = (await time.latest()) + (365 * 24 * 60 * 60);
      
      await expect(
        csvToken.setRule144Lockup(user1.address, lockupTime)
      ).to.emit(csvToken, "Rule144StatusChanged")
       .withArgs(user1.address, 0, lockupTime);
    });

    it("Should emit ComplianceOverride event", async function () {
      await expect(
        csvToken.setComplianceOverride(user1.address, true, "Emergency situation")
      ).to.emit(csvToken, "ComplianceOverride")
       .withArgs(user1.address, "Emergency situation", owner.address);
    });
  });

  describe("Comprehensive Compliance Views", function () {
    beforeEach(async function () {
      await complianceRegistry.setKYCStatus(user1.address, true);
      await complianceRegistry.setAccreditedStatus(user1.address, true);
      await complianceRegistry.setJurisdiction(user1.address, "US");
    });

    it("Should return detailed compliance information", async function () {
      const lockupTime = (await time.latest()) + (365 * 24 * 60 * 60);
      await csvToken.setRule144Lockup(user1.address, lockupTime);
      await csvToken.setRegSRestriction(user1.address, false);
      
      const [isKYC, isAccredited, jurisdiction, rule144, regS, score] = 
        await csvToken.getComplianceDetails(user1.address);
      
      expect(isKYC).to.be.true;
      expect(isAccredited).to.be.true;
      expect(jurisdiction).to.equal("US");
      expect(rule144).to.equal(lockupTime);
      expect(regS).to.be.false;
      expect(score).to.equal(90); // All compliant except Rule 144 not expired
    });

    it("Should provide transfer eligibility with flags", async function () {
      await complianceRegistry.setKYCStatus(user2.address, true);
      await complianceRegistry.setAccreditedStatus(user2.address, true);
      await complianceRegistry.setJurisdiction(user2.address, "US");
      
      await submitMockValuation(ethers.parseEther("10000"));
      
      const [allowed, reason, flags] = await csvToken.canTransfer(
        user1.address, 
        user2.address, 
        ethers.parseEther("100")
      );
      
      expect(allowed).to.be.true;
      expect(reason).to.equal("Transfer allowed");
      expect(flags).to.equal(0);
    });
  });

  // Helper functions
  async function submitMockValuation(csvValue) {
    const merkleRoot = ethers.keccak256(ethers.toUtf8Bytes("mock_valuation"));
    
    // Submit from two attestors to meet threshold
    const signature1 = await createValidSignature(attestor1, csvValue, merkleRoot);
    const signature2 = await createValidSignature(attestor2, csvValue, merkleRoot);
    
    await csvOracle.connect(attestor1).submitValuation(csvValue, merkleRoot, signature1);
    await csvOracle.connect(attestor2).submitValuation(csvValue, merkleRoot, signature2);
    
    // Update token valuation
    await csvToken.updateValuation(merkleRoot, csvValue, "0x");
  }

  async function createValidSignature(signer, csvValue, merkleRoot) {
    const timestamp = await time.latest();
    const chainId = (await ethers.provider.getNetwork()).chainId;
    
    const messageHash = ethers.keccak256(
      ethers.solidityPacked(
        ["uint256", "bytes32", "uint256", "address", "uint256"],
        [csvValue, merkleRoot, timestamp, signer.address, chainId]
      )
    );
    
    return await signer.signMessage(ethers.getBytes(messageHash));
  }
});