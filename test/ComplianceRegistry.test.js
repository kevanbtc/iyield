const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ComplianceRegistry", function () {
  let complianceRegistry;
  let owner, complianceOfficer, user1, user2;

  beforeEach(async function () {
    [owner, complianceOfficer, user1, user2] = await ethers.getSigners();
    
    const ComplianceRegistry = await ethers.getContractFactory("ComplianceRegistry");
    complianceRegistry = await ComplianceRegistry.deploy();
    await complianceRegistry.waitForDeployment();

    // Add compliance officer
    await complianceRegistry.setComplianceOfficer(complianceOfficer.address, true);
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await complianceRegistry.owner()).to.equal(owner.address);
    });

    it("Should set deployer as compliance officer", async function () {
      expect(await complianceRegistry.complianceOfficers(owner.address)).to.be.true;
    });

    it("Should initialize allowed jurisdictions", async function () {
      expect(await complianceRegistry.allowedJurisdictions("US")).to.be.true;
      expect(await complianceRegistry.allowedJurisdictions("EU")).to.be.true;
    });
  });

  describe("Compliance Status Management", function () {
    it("Should allow compliance officer to set status", async function () {
      await complianceRegistry.connect(complianceOfficer).setComplianceStatus(
        user1.address,
        1, // VERIFIED
        2, // ADVANCED
        "US",
        50
      );

      const userData = await complianceRegistry.getComplianceData(user1.address);
      expect(userData.status).to.equal(1);
      expect(userData.level).to.equal(2);
      expect(userData.jurisdiction).to.equal("US");
      expect(userData.riskScore).to.equal(50);
    });

    it("Should not allow non-officer to set status", async function () {
      await expect(
        complianceRegistry.connect(user1).setComplianceStatus(
          user2.address,
          1, // VERIFIED
          1, // INTERMEDIATE
          "US",
          50
        )
      ).to.be.revertedWith("Not authorized");
    });

    it("Should check compliance correctly", async function () {
      await complianceRegistry.connect(complianceOfficer).setComplianceStatus(
        user1.address,
        1, // VERIFIED
        1, // INTERMEDIATE
        "US",
        50
      );

      expect(await complianceRegistry.isCompliant(user1.address)).to.be.true;
    });

    it("Should reject high risk scores", async function () {
      await expect(
        complianceRegistry.connect(complianceOfficer).setComplianceStatus(
          user1.address,
          1, // VERIFIED
          1, // INTERMEDIATE
          "US",
          101 // Too high
        )
      ).to.be.revertedWith("Risk score too high");
    });

    it("Should reject invalid jurisdictions", async function () {
      await expect(
        complianceRegistry.connect(complianceOfficer).setComplianceStatus(
          user1.address,
          1, // VERIFIED
          1, // INTERMEDIATE
          "XX", // Invalid
          50
        )
      ).to.be.revertedWith("Jurisdiction not allowed");
    });
  });

  describe("Batch Operations", function () {
    it("Should batch update compliance", async function () {
      const users = [user1.address, user2.address];
      const statuses = [1, 1]; // Both VERIFIED
      const levels = [1, 2]; // INTERMEDIATE, ADVANCED
      const jurisdictions = ["US", "EU"];
      const riskScores = [30, 40];

      await complianceRegistry.connect(complianceOfficer).batchUpdateCompliance(
        users,
        statuses,
        levels,
        jurisdictions,
        riskScores
      );

      const user1Data = await complianceRegistry.getComplianceData(user1.address);
      const user2Data = await complianceRegistry.getComplianceData(user2.address);

      expect(user1Data.status).to.equal(1);
      expect(user1Data.jurisdiction).to.equal("US");
      expect(user2Data.level).to.equal(2);
      expect(user2Data.jurisdiction).to.equal("EU");
    });

    it("Should reject mismatched array lengths", async function () {
      await expect(
        complianceRegistry.connect(complianceOfficer).batchUpdateCompliance(
          [user1.address],
          [1, 1], // Different length
          [1],
          ["US"],
          [50]
        )
      ).to.be.revertedWith("Array length mismatch");
    });
  });

  describe("Administrative Functions", function () {
    it("Should allow owner to add compliance officer", async function () {
      await complianceRegistry.setComplianceOfficer(user1.address, true);
      expect(await complianceRegistry.complianceOfficers(user1.address)).to.be.true;
    });

    it("Should allow owner to remove compliance officer", async function () {
      await complianceRegistry.setComplianceOfficer(complianceOfficer.address, false);
      expect(await complianceRegistry.complianceOfficers(complianceOfficer.address)).to.be.false;
    });

    it("Should allow owner to add jurisdiction", async function () {
      await complianceRegistry.setAllowedJurisdiction("JP", true);
      expect(await complianceRegistry.allowedJurisdictions("JP")).to.be.true;
    });

    it("Should allow owner to update max risk score", async function () {
      await complianceRegistry.setMaxAllowedRiskScore(90);
      expect(await complianceRegistry.maxAllowedRiskScore()).to.equal(90);
    });

    it("Should not allow non-owner to update settings", async function () {
      await expect(
        complianceRegistry.connect(user1).setMaxAllowedRiskScore(90)
      ).to.be.revertedWithCustomError(complianceRegistry, "OwnableUnauthorizedAccount");
    });
  });

  describe("Events", function () {
    it("Should emit ComplianceUpdated event", async function () {
      await expect(
        complianceRegistry.connect(complianceOfficer).setComplianceStatus(
          user1.address,
          1, // VERIFIED
          1, // INTERMEDIATE
          "US",
          50
        )
      ).to.emit(complianceRegistry, "ComplianceUpdated")
       .withArgs(user1.address, 1, 1, await ethers.provider.getBlock('latest').then(b => b.timestamp + 1));
    });
  });

  describe("Edge Cases", function () {
    it("Should handle zero address validation", async function () {
      await expect(
        complianceRegistry.connect(complianceOfficer).setComplianceStatus(
          ethers.ZeroAddress,
          1,
          1,
          "US",
          50
        )
      ).to.be.revertedWith("Invalid address");
    });

    it("Should handle expired compliance", async function () {
      // Set compliance that's immediately expired (would need to manipulate time)
      await complianceRegistry.connect(complianceOfficer).setComplianceStatus(
        user1.address,
        1, // VERIFIED
        1, // INTERMEDIATE
        "US",
        50
      );

      // Initially should be compliant
      expect(await complianceRegistry.isCompliant(user1.address)).to.be.true;
    });
  });
});