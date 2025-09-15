const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("iYieldToken", function () {
  let iYieldToken, complianceRegistry;
  let owner, user1, user2;
  const initialSupply = ethers.parseEther("1000000");

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();
    
    // Deploy ComplianceRegistry first
    const ComplianceRegistry = await ethers.getContractFactory("ComplianceRegistry");
    complianceRegistry = await ComplianceRegistry.deploy();
    await complianceRegistry.waitForDeployment();

    // Deploy iYieldToken
    const IYieldToken = await ethers.getContractFactory("iYieldToken");
    iYieldToken = await IYieldToken.deploy(
      "iYield Token",
      "iYLD",
      initialSupply,
      await complianceRegistry.getAddress()
    );
    await iYieldToken.waitForDeployment();

    // Set users as compliant
    await complianceRegistry.setComplianceStatus(user1.address, 1, 1, "US", 50);
    await complianceRegistry.setComplianceStatus(user2.address, 1, 2, "US", 30);
  });

  describe("Deployment", function () {
    it("Should set the right name and symbol", async function () {
      expect(await iYieldToken.name()).to.equal("iYield Token");
      expect(await iYieldToken.symbol()).to.equal("iYLD");
    });

    it("Should mint initial supply to owner", async function () {
      expect(await iYieldToken.balanceOf(owner.address)).to.equal(initialSupply);
    });

    it("Should set compliance registry", async function () {
      expect(await iYieldToken.complianceRegistry()).to.equal(await complianceRegistry.getAddress());
    });

    it("Should initialize yield configuration", async function () {
      const yieldConfig = await iYieldToken.yieldConfig();
      expect(yieldConfig.baseRate).to.equal(500); // 5%
      expect(yieldConfig.enabled).to.be.true;
    });
  });

  describe("Compliance Integration", function () {
    it("Should allow compliant users to transfer", async function () {
      await iYieldToken.transfer(user1.address, ethers.parseEther("1000"));
      expect(await iYieldToken.balanceOf(user1.address)).to.equal(ethers.parseEther("1000"));
    });

    it("Should prevent non-compliant users from transferring", async function () {
      // Set user as non-compliant
      await complianceRegistry.setComplianceStatus(user1.address, 0, 0, "US", 50); // NOT_VERIFIED

      await expect(
        iYieldToken.transfer(user1.address, ethers.parseEther("1000"))
      ).to.be.revertedWith("User not compliant");
    });

    it("Should prevent transfers to non-compliant users", async function () {
      await iYieldToken.transfer(user1.address, ethers.parseEther("1000"));
      
      // Set user2 as non-compliant
      await complianceRegistry.setComplianceStatus(user2.address, 0, 0, "US", 50);

      await expect(
        iYieldToken.connect(user1).transfer(user2.address, ethers.parseEther("100"))
      ).to.be.revertedWith("User not compliant");
    });
  });

  describe("Yield Generation", function () {
    beforeEach(async function () {
      // Transfer tokens to user1 for testing
      await iYieldToken.transfer(user1.address, ethers.parseEther("1000"));
    });

    it("Should calculate claimable yield", async function () {
      // Fast forward time by simulating block timestamps
      await ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]); // 1 year
      await ethers.provider.send("evm_mine");

      const claimableYield = await iYieldToken.getClaimableYield(user1.address);
      expect(claimableYield).to.be.gt(0);
    });

    it("Should allow users to claim yield", async function () {
      await ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]); // 1 year
      await ethers.provider.send("evm_mine");

      const initialBalance = await iYieldToken.balanceOf(user1.address);
      const claimableYield = await iYieldToken.getClaimableYield(user1.address);
      
      await iYieldToken.connect(user1).claimYield();
      
      const finalBalance = await iYieldToken.balanceOf(user1.address);
      expect(finalBalance).to.equal(initialBalance + claimableYield);
    });

    it("Should not generate yield for balances below minimum", async function () {
      // Transfer small amount
      await iYieldToken.transfer(user2.address, ethers.parseEther("50")); // Below minimum

      await ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine");

      const claimableYield = await iYieldToken.getClaimableYield(user2.address);
      expect(claimableYield).to.equal(0);
    });

    it("Should apply compliance level multipliers", async function () {
      // user1 has INTERMEDIATE level (1.1x multiplier)
      // user2 has ADVANCED level (1.2x multiplier)
      
      await iYieldToken.transfer(user2.address, ethers.parseEther("1000"));

      await ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine");

      const yield1 = await iYieldToken.getClaimableYield(user1.address);
      const yield2 = await iYieldToken.getClaimableYield(user2.address);

      // user2 should have higher yield due to better compliance level
      expect(yield2).to.be.gt(yield1);
    });
  });

  describe("Yield Configuration", function () {
    it("Should allow owner to update yield config", async function () {
      await iYieldToken.updateYieldConfig(600, 300, true); // 6% base, 3% bonus

      const yieldConfig = await iYieldToken.yieldConfig();
      expect(yieldConfig.baseRate).to.equal(600);
      expect(yieldConfig.bonusRate).to.equal(300);
      expect(yieldConfig.enabled).to.be.true;
    });

    it("Should not allow excessive yield rates", async function () {
      await expect(
        iYieldToken.updateYieldConfig(2001, 300, true) // Over 20%
      ).to.be.revertedWith("Base rate too high");
    });

    it("Should allow disabling yield generation", async function () {
      await iYieldToken.updateYieldConfig(500, 200, false);

      const yieldConfig = await iYieldToken.yieldConfig();
      expect(yieldConfig.enabled).to.be.false;
    });
  });

  describe("Administrative Functions", function () {
    it("Should allow owner to update compliance registry", async function () {
      const newRegistry = await (await ethers.getContractFactory("ComplianceRegistry")).deploy();
      await newRegistry.waitForDeployment();
      
      await iYieldToken.updateComplianceRegistry(await newRegistry.getAddress());
      expect(await iYieldToken.complianceRegistry()).to.equal(await newRegistry.getAddress());
    });

    it("Should allow owner to update minimum balance", async function () {
      await iYieldToken.updateMinimumBalanceForYield(ethers.parseEther("200"));
      expect(await iYieldToken.minimumBalanceForYield()).to.equal(ethers.parseEther("200"));
    });

    it("Should allow owner to update level multipliers", async function () {
      await iYieldToken.updateLevelMultiplier(2, 13000); // 1.3x for ADVANCED
      expect(await iYieldToken.levelMultipliers(2)).to.equal(13000);
    });

    it("Should not allow non-owner to update settings", async function () {
      await expect(
        iYieldToken.connect(user1).updateYieldConfig(600, 300, true)
      ).to.be.revertedWithCustomError(iYieldToken, "OwnableUnauthorizedAccount");
    });
  });

  describe("Pausable Functionality", function () {
    it("Should allow owner to pause", async function () {
      await iYieldToken.pause();
      expect(await iYieldToken.paused()).to.be.true;
    });

    it("Should prevent transfers when paused", async function () {
      await iYieldToken.pause();
      
      await expect(
        iYieldToken.transfer(user1.address, ethers.parseEther("100"))
      ).to.be.revertedWithCustomError(iYieldToken, "EnforcedPause");
    });

    it("Should allow owner to unpause", async function () {
      await iYieldToken.pause();
      await iYieldToken.unpause();
      expect(await iYieldToken.paused()).to.be.false;
    });
  });

  describe("Yield Information", function () {
    it("Should return user yield info", async function () {
      await iYieldToken.transfer(user1.address, ethers.parseEther("1000"));
      
      const yieldInfo = await iYieldToken.getUserYieldInfo(user1.address);
      expect(yieldInfo.lastClaimTime).to.be.gt(0);
      expect(yieldInfo.accruedYield).to.equal(0); // Initially zero
    });

    it("Should track total yield distributed", async function () {
      await iYieldToken.transfer(user1.address, ethers.parseEther("1000"));
      
      await ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine");

      const initialTotal = await iYieldToken.totalYieldDistributed();
      await iYieldToken.connect(user1).claimYield();
      const finalTotal = await iYieldToken.totalYieldDistributed();
      
      expect(finalTotal).to.be.gt(initialTotal);
    });
  });

  describe("Events", function () {
    it("Should emit YieldClaimed event", async function () {
      await iYieldToken.transfer(user1.address, ethers.parseEther("1000"));
      
      await ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine");

      await expect(iYieldToken.connect(user1).claimYield())
        .to.emit(iYieldToken, "YieldClaimed");
    });

    it("Should emit YieldConfigUpdated event", async function () {
      await expect(iYieldToken.updateYieldConfig(600, 300, true))
        .to.emit(iYieldToken, "YieldConfigUpdated")
        .withArgs(600, 300, true);
    });
  });

  describe("Edge Cases", function () {
    it("Should handle zero yield claims gracefully", async function () {
      await iYieldToken.transfer(user1.address, ethers.parseEther("1000"));
      
      // Try to claim immediately (should be zero)
      await expect(
        iYieldToken.connect(user1).claimYield()
      ).to.be.revertedWith("No yield to claim");
    });

    it("Should handle multiple consecutive claims", async function () {
      await iYieldToken.transfer(user1.address, ethers.parseEther("1000"));
      
      await ethers.provider.send("evm_increaseTime", [30 * 24 * 60 * 60]); // 30 days
      await ethers.provider.send("evm_mine");

      await iYieldToken.connect(user1).claimYield();
      
      // Second claim should fail with no yield
      await expect(
        iYieldToken.connect(user1).claimYield()
      ).to.be.revertedWith("No yield to claim");
    });
  });
});