const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Vault", function () {
  let vault, complianceRegistry, oracleAdapter, iYieldToken, mockToken;
  let owner, user1, user2;

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();
    
    // Deploy ComplianceRegistry
    const ComplianceRegistry = await ethers.getContractFactory("ComplianceRegistry");
    complianceRegistry = await ComplianceRegistry.deploy();
    await complianceRegistry.waitForDeployment();

    // Deploy OracleAdapter
    const OracleAdapter = await ethers.getContractFactory("OracleAdapter");
    oracleAdapter = await OracleAdapter.deploy();
    await oracleAdapter.waitForDeployment();

    // Deploy iYieldToken
    const IYieldToken = await ethers.getContractFactory("iYieldToken");
    iYieldToken = await IYieldToken.deploy(
      "iYield Token",
      "iYLD",
      ethers.parseEther("1000000"),
      await complianceRegistry.getAddress()
    );
    await iYieldToken.waitForDeployment();

    // Deploy a mock token for testing
    const MockToken = await ethers.getContractFactory("iYieldToken");
    mockToken = await MockToken.deploy(
      "Mock USDC",
      "mUSDC",
      ethers.parseEther("1000000"),
      await complianceRegistry.getAddress()
    );
    await mockToken.waitForDeployment();

    // Deploy Vault
    const Vault = await ethers.getContractFactory("Vault");
    vault = await Vault.deploy(
      await complianceRegistry.getAddress(),
      await oracleAdapter.getAddress(),
      await iYieldToken.getAddress()
    );
    await vault.waitForDeployment();

    // Set users as compliant
    await complianceRegistry.setComplianceStatus(user1.address, 1, 1, "US", 50);
    await complianceRegistry.setComplianceStatus(user2.address, 1, 2, "US", 30);

    // Add supported assets to vault
    await vault.addAsset(
      await mockToken.getAddress(),
      5000, // 50% max allocation
      owner.address, // Oracle placeholder
      18
    );

    // Transfer tokens to users for testing
    await mockToken.transfer(user1.address, ethers.parseEther("10000"));
    await mockToken.transfer(user2.address, ethers.parseEther("10000"));
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await vault.owner()).to.equal(owner.address);
    });

    it("Should set correct contract references", async function () {
      expect(await vault.complianceRegistry()).to.equal(await complianceRegistry.getAddress());
      expect(await vault.oracleAdapter()).to.equal(await oracleAdapter.getAddress());
      expect(await vault.yieldToken()).to.equal(await iYieldToken.getAddress());
    });

    it("Should initialize vault configuration", async function () {
      const vaultConfig = await vault.vaultConfig();
      expect(vaultConfig.managementFee).to.equal(200); // 2%
      expect(vaultConfig.depositsEnabled).to.be.true;
      expect(vaultConfig.withdrawalsEnabled).to.be.true;
    });
  });

  describe("Asset Management", function () {
    it("Should add supported asset", async function () {
      const assetConfig = await vault.assetConfigs(await mockToken.getAddress());
      expect(assetConfig.isSupported).to.be.true;
      expect(assetConfig.maxAllocation).to.equal(5000);
    });

    it("Should not allow adding asset with invalid parameters", async function () {
      await expect(
        vault.addAsset(ethers.ZeroAddress, 5000, owner.address, 18)
      ).to.be.revertedWith("Invalid asset address");

      await expect(
        vault.addAsset(user1.address, 10001, owner.address, 18) // Over 100%
      ).to.be.revertedWith("Max allocation too high");
    });

    it("Should allow owner to remove asset", async function () {
      const newTokenAddress = user2.address; // Using address as placeholder
      await vault.addAsset(newTokenAddress, 1000, owner.address, 18);
      await vault.removeAsset(newTokenAddress);
      
      const assetConfig = await vault.assetConfigs(newTokenAddress);
      expect(assetConfig.isSupported).to.be.false;
    });

    it("Should get supported assets", async function () {
      const supportedAssets = await vault.getSupportedAssets();
      expect(supportedAssets).to.include(await mockToken.getAddress());
    });
  });

  describe("Deposits", function () {
    beforeEach(async function () {
      // Approve vault to spend user tokens
      await mockToken.connect(user1).approve(await vault.getAddress(), ethers.parseEther("10000"));
    });

    it("Should allow compliant users to deposit", async function () {
      const depositAmount = ethers.parseEther("1000");
      
      await vault.connect(user1).deposit(await mockToken.getAddress(), depositAmount);
      
      const userDeposit = await vault.userDeposits(user1.address);
      expect(userDeposit.shares).to.be.gt(0);
      expect(userDeposit.totalDeposited).to.equal(depositAmount);
    });

    it("Should reject deposits below minimum", async function () {
      const smallAmount = ethers.parseEther("50"); // Below minimum
      
      await expect(
        vault.connect(user1).deposit(await mockToken.getAddress(), smallAmount)
      ).to.be.revertedWith("Amount below minimum");
    });

    it("Should reject deposits from non-compliant users", async function () {
      // Set user as non-compliant
      await complianceRegistry.setComplianceStatus(user1.address, 0, 0, "US", 50);
      
      await expect(
        vault.connect(user1).deposit(await mockToken.getAddress(), ethers.parseEther("1000"))
      ).to.be.revertedWith("User not compliant");
    });

    it("Should reject deposits of unsupported assets", async function () {
      await expect(
        vault.connect(user1).deposit(user2.address, ethers.parseEther("1000")) // Unsupported asset
      ).to.be.revertedWith("Asset not supported");
    });
  });

  describe("Withdrawals", function () {
    beforeEach(async function () {
      // Setup deposit first
      await mockToken.connect(user1).approve(await vault.getAddress(), ethers.parseEther("10000"));
      await vault.connect(user1).deposit(await mockToken.getAddress(), ethers.parseEther("1000"));
    });

    it("Should allow users to withdraw", async function () {
      const userDeposit = await vault.userDeposits(user1.address);
      const sharesToWithdraw = userDeposit.shares / 2n; // Withdraw half
      
      const initialBalance = await mockToken.balanceOf(user1.address);
      
      await vault.connect(user1).withdraw(
        await mockToken.getAddress(),
        sharesToWithdraw
      );
      
      const finalBalance = await mockToken.balanceOf(user1.address);
      expect(finalBalance).to.be.gt(initialBalance);
    });

    it("Should reject withdrawals exceeding user shares", async function () {
      const userDeposit = await vault.userDeposits(user1.address);
      const excessiveShares = userDeposit.shares + 1n;
      
      await expect(
        vault.connect(user1).withdraw(await mockToken.getAddress(), excessiveShares)
      ).to.be.revertedWith("Insufficient shares");
    });

    it("Should apply withdrawal fees", async function () {
      const userDeposit = await vault.userDeposits(user1.address);
      const initialBalance = await mockToken.balanceOf(user1.address);
      
      await vault.connect(user1).withdraw(
        await mockToken.getAddress(),
        userDeposit.shares
      );
      
      const finalBalance = await mockToken.balanceOf(user1.address);
      const received = finalBalance - initialBalance;
      
      // Should receive less than deposited due to fees
      expect(received).to.be.lt(ethers.parseEther("1000"));
    });
  });

  describe("Vault Configuration", function () {
    it("Should allow owner to update vault config", async function () {
      await vault.updateVaultConfig(
        300, // 3% management fee
        1200, // 12% performance fee
        ethers.parseEther("200000000"), // 200M max assets
        ethers.parseEther("200"), // 200 minimum deposit
        75 // 0.75% withdrawal fee
      );
      
      const vaultConfig = await vault.vaultConfig();
      expect(vaultConfig.managementFee).to.equal(300);
      expect(vaultConfig.performanceFee).to.equal(1200);
    });

    it("Should reject excessive fees", async function () {
      await expect(
        vault.updateVaultConfig(501, 1000, ethers.parseEther("1000000"), ethers.parseEther("100"), 50)
      ).to.be.revertedWith("Management fee too high");

      await expect(
        vault.updateVaultConfig(200, 2001, ethers.parseEther("1000000"), ethers.parseEther("100"), 50)
      ).to.be.revertedWith("Performance fee too high");
    });

    it("Should allow owner to disable deposits/withdrawals", async function () {
      await vault.setDepositsEnabled(false);
      await vault.setWithdrawalsEnabled(false);
      
      const vaultConfig = await vault.vaultConfig();
      expect(vaultConfig.depositsEnabled).to.be.false;
      expect(vaultConfig.withdrawalsEnabled).to.be.false;
    });
  });

  describe("Strategy Management", function () {
    it("Should allow owner to add strategy", async function () {
      const strategyAddress = user2.address; // Using address as placeholder
      
      await vault.addStrategy(strategyAddress, 800, "Test Strategy"); // 8% expected yield
      
      const strategy = await vault.yieldStrategies(strategyAddress);
      expect(strategy.isActive).to.be.true;
      expect(strategy.expectedYield).to.equal(800);
      expect(strategy.name).to.equal("Test Strategy");
    });

    it("Should not allow adding invalid strategy", async function () {
      await expect(
        vault.addStrategy(ethers.ZeroAddress, 800, "Invalid Strategy")
      ).to.be.revertedWith("Invalid strategy address");
    });

    it("Should allow owner to remove strategy", async function () {
      const strategyAddress = user2.address;
      await vault.addStrategy(strategyAddress, 800, "Test Strategy");
      await vault.removeStrategy(strategyAddress);
      
      const strategy = await vault.yieldStrategies(strategyAddress);
      expect(strategy.isActive).to.be.false;
    });

    it("Should get active strategies", async function () {
      const strategyAddress = user2.address;
      await vault.addStrategy(strategyAddress, 800, "Test Strategy");
      
      const activeStrategies = await vault.getActiveStrategies();
      expect(activeStrategies).to.include(strategyAddress);
    });
  });

  describe("User Information", function () {
    beforeEach(async function () {
      await mockToken.connect(user1).approve(await vault.getAddress(), ethers.parseEther("10000"));
      await vault.connect(user1).deposit(await mockToken.getAddress(), ethers.parseEther("1000"));
    });

    it("Should calculate user share percentage", async function () {
      const sharePercentage = await vault.getUserSharePercentage(user1.address);
      expect(sharePercentage).to.equal(10000); // 100% (only depositor)
    });

    it("Should calculate user asset value", async function () {
      const assetValue = await vault.getUserAssetValue(user1.address);
      expect(assetValue).to.be.gt(0);
    });
  });

  describe("Pausable Functionality", function () {
    it("Should allow owner to pause", async function () {
      await vault.pause();
      expect(await vault.paused()).to.be.true;
    });

    it("Should prevent deposits when paused", async function () {
      await vault.pause();
      await mockToken.connect(user1).approve(await vault.getAddress(), ethers.parseEther("10000"));
      
      await expect(
        vault.connect(user1).deposit(await mockToken.getAddress(), ethers.parseEther("1000"))
      ).to.be.revertedWithCustomError(vault, "EnforcedPause");
    });

    it("Should allow owner to unpause", async function () {
      await vault.pause();
      await vault.unpause();
      expect(await vault.paused()).to.be.false;
    });
  });

  describe("Events", function () {
    it("Should emit Deposit event", async function () {
      await mockToken.connect(user1).approve(await vault.getAddress(), ethers.parseEther("10000"));
      
      await expect(
        vault.connect(user1).deposit(await mockToken.getAddress(), ethers.parseEther("1000"))
      ).to.emit(vault, "Deposit")
       .withArgs(user1.address, await mockToken.getAddress(), ethers.parseEther("1000"), anyValue);
    });

    it("Should emit AssetAdded event", async function () {
      const newAsset = user2.address;
      
      await expect(
        vault.addAsset(newAsset, 1000, owner.address, 18)
      ).to.emit(vault, "AssetAdded")
       .withArgs(newAsset, 1000);
    });
  });

  describe("Access Control", function () {
    it("Should not allow non-owner to add assets", async function () {
      await expect(
        vault.connect(user1).addAsset(user2.address, 1000, owner.address, 18)
      ).to.be.revertedWithCustomError(vault, "OwnableUnauthorizedAccount");
    });

    it("Should not allow non-owner to add strategies", async function () {
      await expect(
        vault.connect(user1).addStrategy(user2.address, 800, "Test Strategy")
      ).to.be.revertedWithCustomError(vault, "OwnableUnauthorizedAccount");
    });
  });

  describe("Edge Cases", function () {
    it("Should handle zero total shares gracefully", async function () {
      const sharePercentage = await vault.getUserSharePercentage(user1.address);
      expect(sharePercentage).to.equal(0); // No deposits yet
    });

    it("Should handle multiple depositors", async function () {
      // Setup deposits from multiple users
      await mockToken.connect(user1).approve(await vault.getAddress(), ethers.parseEther("10000"));
      await mockToken.connect(user2).approve(await vault.getAddress(), ethers.parseEther("10000"));

      await vault.connect(user1).deposit(await mockToken.getAddress(), ethers.parseEther("1000"));
      await vault.connect(user2).deposit(await mockToken.getAddress(), ethers.parseEther("2000"));

      const user1Percentage = await vault.getUserSharePercentage(user1.address);
      const user2Percentage = await vault.getUserSharePercentage(user2.address);

      // user2 should have roughly double the share percentage
      expect(user2Percentage).to.be.gt(user1Percentage);
      expect(user1Percentage + user2Percentage).to.be.closeTo(10000n, 100n); // Close to 100%
    });
  });
});

// Helper to match any value in event assertions
const anyValue = () => true;