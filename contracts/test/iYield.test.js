const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("iYield Protocol", function () {
  let owner, user1, user2;
  let complianceRegistry, csvOracle, ercRwacsv, csvVault, csvLiquidityPool;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy contracts
    const ComplianceRegistry = await ethers.getContractFactory("ComplianceRegistry");
    complianceRegistry = await ComplianceRegistry.deploy(owner.address);

    const CSVOracle = await ethers.getContractFactory("CSVOracle");
    csvOracle = await CSVOracle.deploy(owner.address);

    const ERCRWACSV = await ethers.getContractFactory("ERCRWACSV");
    ercRwacsv = await ERCRWACSV.deploy(owner.address, owner.address, owner.address);

    const CSVVault = await ethers.getContractFactory("CSVVault");
    csvVault = await CSVVault.deploy(await ercRwacsv.getAddress(), owner.address);

    const CSVLiquidityPool = await ethers.getContractFactory("CSVLiquidityPool");
    csvLiquidityPool = await CSVLiquidityPool.deploy(owner.address);
  });

  describe("ERCRWACSV Token", function () {
    it("Should deploy with correct name and symbol", async function () {
      expect(await ercRwacsv.name()).to.equal("iYield CSV Token");
      expect(await ercRwacsv.symbol()).to.equal("iCSV");
    });

    it("Should allow minting by minter role", async function () {
      const amount = ethers.parseEther("100");
      await ercRwacsv.mint(user1.address, amount);
      expect(await ercRwacsv.balanceOf(user1.address)).to.equal(amount);
    });

    it("Should allow pausing by pauser role", async function () {
      await ercRwacsv.pause();
      expect(await ercRwacsv.paused()).to.be.true;
      
      await ercRwacsv.unpause();
      expect(await ercRwacsv.paused()).to.be.false;
    });
  });

  describe("ComplianceRegistry", function () {
    it("Should update KYC status", async function () {
      await complianceRegistry.updateKYCStatus(user1.address, 2, 365); // 2 = Verified
      const compliance = await complianceRegistry.userCompliance(user1.address);
      expect(compliance.kycStatus).to.equal(2);
    });

    it("Should check compliance status", async function () {
      // Set up compliance
      await complianceRegistry.updateKYCStatus(user1.address, 2, 365); // Verified
      await complianceRegistry.updateJurisdiction(user1.address, 1); // US
      await complianceRegistry.updateAccreditation(user1.address, true);
      
      expect(await complianceRegistry.isCompliant(user1.address)).to.be.true;
    });
  });

  describe("CSVOracle", function () {
    it("Should allow oracle to submit attestation", async function () {
      // Add oracle role
      await csvOracle.addOracle(user1.address);
      
      // Request valuation
      const valuationId = await csvOracle.requestValuation("POLICY123", 2);
      
      // Submit attestation
      await csvOracle.connect(user1).submitAttestation(
        valuationId,
        ethers.parseEther("1000"),
        ethers.keccak256(ethers.toUtf8Bytes("merkle_proof"))
      );
      
      const valuation = await csvOracle.getValuation(valuationId);
      expect(valuation.policyId).to.equal("POLICY123");
    });
  });

  describe("CSVLiquidityPool", function () {
    it("Should accept senior deposits", async function () {
      const depositAmount = ethers.parseEther("1");
      await csvLiquidityPool.connect(user1).depositSenior({ value: depositAmount });
      
      expect(await csvLiquidityPool.seniorDeposits(user1.address)).to.equal(depositAmount);
    });

    it("Should accept junior deposits", async function () {
      const depositAmount = ethers.parseEther("1");
      await csvLiquidityPool.connect(user1).depositJunior({ value: depositAmount });
      
      expect(await csvLiquidityPool.juniorDeposits(user1.address)).to.equal(depositAmount);
    });
  });
});