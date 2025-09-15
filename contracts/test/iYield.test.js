const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("iYield Protocol Core", function () {
  let complianceRegistry, csvOracle, csvToken;
  let owner, user1, user2, attestor1, attestor2;
  let carrierId;

  beforeEach(async function () {
    // Get signers
    [owner, user1, user2, attestor1, attestor2] = await ethers.getSigners();

    // Deploy ComplianceRegistry
    const ComplianceRegistry = await ethers.getContractFactory("ComplianceRegistry");
    complianceRegistry = await ComplianceRegistry.deploy(owner.address);
    await complianceRegistry.waitForDeployment();

    // Deploy CSVOracle
    const CSVOracle = await ethers.getContractFactory("CSVOracle");
    csvOracle = await CSVOracle.deploy(owner.address, [attestor1.address, attestor2.address]);
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

    // Set up test carrier
    carrierId = ethers.keccak256(ethers.toUtf8Bytes("TEST_CARRIER"));
    await csvOracle.addCarrier(carrierId, "Test Carrier", 950);

    // Grant oracle role to CSV oracle contract
    const ORACLE_ROLE = await csvToken.ORACLE_ROLE();
    await csvToken.grantRole(ORACLE_ROLE, await csvOracle.getAddress());
  });

  describe("ComplianceRegistry", function () {
    it("Should set and verify KYC status", async function () {
      await complianceRegistry.setKYCStatus(user1.address, true);
      expect(await complianceRegistry.isKYCVerified(user1.address)).to.be.true;
    });

    it("Should set and verify accredited investor status", async function () {
      await complianceRegistry.setAccreditedStatus(user1.address, true);
      expect(await complianceRegistry.isAccreditedInvestor(user1.address)).to.be.true;
    });

    it("Should set and get jurisdiction", async function () {
      await complianceRegistry.setJurisdiction(user1.address, "US");
      expect(await complianceRegistry.getJurisdiction(user1.address)).to.equal("US");
    });

    it("Should check full compliance", async function () {
      await complianceRegistry.setKYCStatus(user1.address, true);
      await complianceRegistry.setAccreditedStatus(user1.address, true);
      await complianceRegistry.setJurisdiction(user1.address, "US");
      
      expect(await complianceRegistry.isFullyCompliant(user1.address)).to.be.true;
    });
  });

  describe("CSVOracle", function () {
    it("Should add and retrieve carrier data", async function () {
      const carrier = await csvOracle.getCarrierData(carrierId);
      expect(carrier.name).to.equal("Test Carrier");
      expect(carrier.rating).to.equal(950);
      expect(carrier.isActive).to.be.true;
    });

    it("Should verify trusted attestors", async function () {
      expect(await csvOracle.verifyAttestor(attestor1.address)).to.be.true;
      expect(await csvOracle.verifyAttestor(user1.address)).to.be.false;
    });

    it("Should get minimum attestors", async function () {
      expect(await csvOracle.getMinAttestors()).to.equal(2);
    });
  });

  describe("ERCRWACSV Token", function () {
    beforeEach(async function () {
      // Set up compliant users
      await complianceRegistry.setKYCStatus(user1.address, true);
      await complianceRegistry.setAccreditedStatus(user1.address, true);
      await complianceRegistry.setJurisdiction(user1.address, "US");

      await complianceRegistry.setKYCStatus(user2.address, true);
      await complianceRegistry.setAccreditedStatus(user2.address, true);
      await complianceRegistry.setJurisdiction(user2.address, "US");
    });

    it("Should mint tokens to compliant users", async function () {
      const mintAmount = ethers.parseEther("1000");
      await csvToken.mint(user1.address, mintAmount);
      
      expect(await csvToken.balanceOf(user1.address)).to.equal(mintAmount);
    });

    it("Should prevent minting to non-compliant users", async function () {
      const mintAmount = ethers.parseEther("1000");
      
      await expect(
        csvToken.mint(user2.address, mintAmount)
      ).to.be.revertedWith("Recipient not KYC verified");
      
      // Remove KYC status
      await complianceRegistry.setKYCStatus(user2.address, false);
      
      await expect(
        csvToken.mint(user2.address, mintAmount)
      ).to.be.revertedWith("Recipient not KYC verified");
    });

    it("Should allow compliant transfers", async function () {
      const mintAmount = ethers.parseEther("1000");
      const transferAmount = ethers.parseEther("100");
      
      // Mint tokens to user1
      await csvToken.mint(user1.address, mintAmount);
      
      // Submit oracle valuation first (required for transfers)
      const merkleRoot = ethers.keccak256(ethers.toUtf8Bytes("test"));
      const csvValue = ethers.parseEther("10000");
      
      // Mock signature for testing
      const messageHash = ethers.keccak256(
        ethers.solidityPacked(
          ["uint256", "bytes32", "uint256", "address"],
          [csvValue, merkleRoot, (await ethers.provider.getBlock('latest')).timestamp + 1, attestor1.address]
        )
      );
      const signature = await attestor1.signMessage(ethers.getBytes(messageHash));
      
      // Submit valuation
      await csvOracle.connect(attestor1).submitValuation(csvValue, merkleRoot, signature);
      
      // Update token valuation
      await csvToken.updateValuation(merkleRoot, csvValue, "0x");
      
      // Transfer should work now
      await csvToken.connect(user1).transfer(user2.address, transferAmount);
      
      expect(await csvToken.balanceOf(user1.address)).to.equal(mintAmount - transferAmount);
      expect(await csvToken.balanceOf(user2.address)).to.equal(transferAmount);
    });

    it("Should prevent transfers to non-compliant users", async function () {
      const mintAmount = ethers.parseEther("1000");
      const transferAmount = ethers.parseEther("100");
      
      await csvToken.mint(user1.address, mintAmount);
      
      // Remove compliance for user2
      await complianceRegistry.setKYCStatus(user2.address, false);
      
      await expect(
        csvToken.connect(user1).transfer(user2.address, transferAmount)
      ).to.be.revertedWith("Transfer not compliant");
    });

    it("Should burn tokens", async function () {
      const mintAmount = ethers.parseEther("1000");
      const burnAmount = ethers.parseEther("100");
      
      await csvToken.mint(user1.address, mintAmount);
      await csvToken.connect(user1).burn(burnAmount);
      
      expect(await csvToken.balanceOf(user1.address)).to.equal(mintAmount - burnAmount);
    });

    it("Should get current LTV", async function () {
      expect(await csvToken.getCurrentLTV()).to.equal(0);
    });

    it("Should get max LTV", async function () {
      expect(await csvToken.getMaxLTV()).to.equal(8000); // 80%
    });
  });

  describe("Integration Tests", function () {
    it("Should complete full protocol workflow", async function () {
      // 1. Set up compliance
      await complianceRegistry.setKYCStatus(user1.address, true);
      await complianceRegistry.setAccreditedStatus(user1.address, true);
      await complianceRegistry.setJurisdiction(user1.address, "US");

      // 2. Submit oracle valuation
      const merkleRoot = ethers.keccak256(ethers.toUtf8Bytes("integration_test"));
      const csvValue = ethers.parseEther("50000");
      
      const messageHash = ethers.keccak256(
        ethers.solidityPacked(
          ["uint256", "bytes32", "uint256", "address"],
          [csvValue, merkleRoot, (await ethers.provider.getBlock('latest')).timestamp + 1, attestor1.address]
        )
      );
      const signature = await attestor1.signMessage(ethers.getBytes(messageHash));
      
      await csvOracle.connect(attestor1).submitValuation(csvValue, merkleRoot, signature);

      // 3. Update token valuation
      await csvToken.updateValuation(merkleRoot, csvValue, "0x");

      // 4. Mint tokens (respecting LTV)
      const mintAmount = ethers.parseEther("30000"); // 60% LTV
      await csvToken.mint(user1.address, mintAmount);

      // 5. Verify final state
      expect(await csvToken.balanceOf(user1.address)).to.equal(mintAmount);
      expect(await csvToken.getTotalCSVValue()).to.equal(csvValue);
      expect(await csvToken.getCurrentLTV()).to.equal(6000); // 60%
    });
  });
});