const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LiquidityPool", function () {
  let liquidityPool, complianceRegistry, oracleAdapter, tokenA, tokenB;
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

    // Deploy test tokens
    const IYieldToken = await ethers.getContractFactory("iYieldToken");
    tokenA = await IYieldToken.deploy(
      "Token A",
      "TKA",
      ethers.parseEther("1000000"),
      await complianceRegistry.getAddress()
    );
    await tokenA.waitForDeployment();

    tokenB = await IYieldToken.deploy(
      "Token B",
      "TKB",
      ethers.parseEther("1000000"),
      await complianceRegistry.getAddress()
    );
    await tokenB.waitForDeployment();

    // Deploy LiquidityPool
    const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
    liquidityPool = await LiquidityPool.deploy(
      await complianceRegistry.getAddress(),
      await oracleAdapter.getAddress(),
      await tokenA.getAddress(),
      await tokenB.getAddress(),
      30 // 0.3% fee
    );
    await liquidityPool.waitForDeployment();

    // Set users as compliant
    await complianceRegistry.setComplianceStatus(user1.address, 1, 1, "US", 50);
    await complianceRegistry.setComplianceStatus(user2.address, 1, 2, "US", 30);

    // Transfer tokens to users
    await tokenA.transfer(user1.address, ethers.parseEther("50000"));
    await tokenA.transfer(user2.address, ethers.parseEther("50000"));
    await tokenB.transfer(user1.address, ethers.parseEther("50000"));
    await tokenB.transfer(user2.address, ethers.parseEther("50000"));
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await liquidityPool.owner()).to.equal(owner.address);
    });

    it("Should set correct token addresses", async function () {
      const poolConfig = await liquidityPool.poolConfig();
      expect(poolConfig.tokenA).to.equal(await tokenA.getAddress());
      expect(poolConfig.tokenB).to.equal(await tokenB.getAddress());
    });

    it("Should set correct fee rate", async function () {
      const poolConfig = await liquidityPool.poolConfig();
      expect(poolConfig.feeRate).to.equal(30);
    });

    it("Should reject invalid deployment parameters", async function () {
      const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
      
      // Same token addresses
      await expect(
        LiquidityPool.deploy(
          await complianceRegistry.getAddress(),
          await oracleAdapter.getAddress(),
          await tokenA.getAddress(),
          await tokenA.getAddress(), // Same token
          30
        )
      ).to.be.revertedWith("Tokens must be different");

      // Fee too high
      await expect(
        LiquidityPool.deploy(
          await complianceRegistry.getAddress(),
          await oracleAdapter.getAddress(),
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          1001 // Over 10%
        )
      ).to.be.revertedWith("Fee rate too high");
    });
  });

  describe("Liquidity Provision", function () {
    beforeEach(async function () {
      // Approve tokens for liquidity pool
      await tokenA.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      await tokenB.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
    });

    it("Should allow initial liquidity provision", async function () {
      const amountA = ethers.parseEther("1000");
      const amountB = ethers.parseEther("2000");
      
      await liquidityPool.connect(user1).addLiquidity(
        amountA,
        amountB,
        amountA,
        amountB
      );
      
      const poolConfig = await liquidityPool.poolConfig();
      expect(poolConfig.reserveA).to.equal(amountA);
      expect(poolConfig.reserveB).to.equal(amountB);
      expect(poolConfig.totalLiquidity).to.be.gt(0);
      
      const provider = await liquidityPool.liquidityProviders(user1.address);
      expect(provider.liquidityTokens).to.be.gt(0);
    });

    it("Should calculate correct liquidity tokens for subsequent deposits", async function () {
      // Initial liquidity
      await liquidityPool.connect(user1).addLiquidity(
        ethers.parseEther("1000"),
        ethers.parseEther("2000"),
        ethers.parseEther("1000"),
        ethers.parseEther("2000")
      );
      
      // Second deposit
      await tokenA.connect(user2).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      await tokenB.connect(user2).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      
      await liquidityPool.connect(user2).addLiquidity(
        ethers.parseEther("500"),
        ethers.parseEther("1000"),
        ethers.parseEther("500"),
        ethers.parseEther("1000")
      );
      
      const provider2 = await liquidityPool.liquidityProviders(user2.address);
      expect(provider2.liquidityTokens).to.be.gt(0);
    });

    it("Should enforce minimum amounts", async function () {
      // Initial liquidity
      await liquidityPool.connect(user1).addLiquidity(
        ethers.parseEther("1000"),
        ethers.parseEther("2000"),
        ethers.parseEther("1000"),
        ethers.parseEther("2000")
      );
      
      await tokenA.connect(user2).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      await tokenB.connect(user2).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      
      // Should fail due to insufficient minimum
      await expect(
        liquidityPool.connect(user2).addLiquidity(
          ethers.parseEther("500"),
          ethers.parseEther("1000"),
          ethers.parseEther("600"), // Higher than optimal
          ethers.parseEther("1000")
        )
      ).to.be.revertedWith("Insufficient A amount");
    });

    it("Should reject non-compliant users", async function () {
      // Set user as non-compliant
      await complianceRegistry.setComplianceStatus(user1.address, 0, 0, "US", 50);
      
      await expect(
        liquidityPool.connect(user1).addLiquidity(
          ethers.parseEther("1000"),
          ethers.parseEther("2000"),
          ethers.parseEther("1000"),
          ethers.parseEther("2000")
        )
      ).to.be.revertedWith("User not compliant");
    });
  });

  describe("Liquidity Removal", function () {
    beforeEach(async function () {
      // Setup initial liquidity
      await tokenA.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      await tokenB.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      
      await liquidityPool.connect(user1).addLiquidity(
        ethers.parseEther("1000"),
        ethers.parseEther("2000"),
        ethers.parseEther("1000"),
        ethers.parseEther("2000")
      );
    });

    it("Should allow users to remove liquidity", async function () {
      const provider = await liquidityPool.liquidityProviders(user1.address);
      const liquidityToRemove = provider.liquidityTokens / 2n; // Remove half
      
      const initialBalanceA = await tokenA.balanceOf(user1.address);
      const initialBalanceB = await tokenB.balanceOf(user1.address);
      
      await liquidityPool.connect(user1).removeLiquidity(
        liquidityToRemove,
        0, // Min amounts (for simplicity)
        0
      );
      
      const finalBalanceA = await tokenA.balanceOf(user1.address);
      const finalBalanceB = await tokenB.balanceOf(user1.address);
      
      expect(finalBalanceA).to.be.gt(initialBalanceA);
      expect(finalBalanceB).to.be.gt(initialBalanceB);
    });

    it("Should enforce minimum output amounts", async function () {
      const provider = await liquidityPool.liquidityProviders(user1.address);
      
      await expect(
        liquidityPool.connect(user1).removeLiquidity(
          provider.liquidityTokens,
          ethers.parseEther("2000"), // Too high minimum
          ethers.parseEther("4000")  // Too high minimum
        )
      ).to.be.revertedWith("Insufficient output amounts");
    });

    it("Should reject excessive withdrawal amounts", async function () {
      const provider = await liquidityPool.liquidityProviders(user1.address);
      const excessiveAmount = provider.liquidityTokens + 1n;
      
      await expect(
        liquidityPool.connect(user1).removeLiquidity(excessiveAmount, 0, 0)
      ).to.be.revertedWith("Insufficient liquidity tokens");
    });
  });

  describe("Token Swaps", function () {
    beforeEach(async function () {
      // Setup liquidity first
      await tokenA.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      await tokenB.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      
      await liquidityPool.connect(user1).addLiquidity(
        ethers.parseEther("10000"),
        ethers.parseEther("20000"),
        ethers.parseEther("10000"),
        ethers.parseEther("20000")
      );
    });

    it("Should allow token swaps", async function () {
      await tokenA.connect(user2).approve(await liquidityPool.getAddress(), ethers.parseEther("1000"));
      
      const initialBalanceA = await tokenA.balanceOf(user2.address);
      const initialBalanceB = await tokenB.balanceOf(user2.address);
      
      const swapAmount = ethers.parseEther("100");
      
      await liquidityPool.connect(user2).swap(
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        swapAmount,
        0 // Min out for simplicity
      );
      
      const finalBalanceA = await tokenA.balanceOf(user2.address);
      const finalBalanceB = await tokenB.balanceOf(user2.address);
      
      expect(finalBalanceA).to.equal(initialBalanceA - swapAmount);
      expect(finalBalanceB).to.be.gt(initialBalanceB);
    });

    it("Should get amount out correctly", async function () {
      const swapAmount = ethers.parseEther("100");
      const amountOut = await liquidityPool.getAmountOut(
        swapAmount,
        await tokenA.getAddress()
      );
      
      expect(amountOut).to.be.gt(0);
    });

    it("Should enforce slippage protection", async function () {
      await tokenA.connect(user2).approve(await liquidityPool.getAddress(), ethers.parseEther("1000"));
      
      const swapAmount = ethers.parseEther("100");
      const expectedOut = await liquidityPool.getAmountOut(swapAmount, await tokenA.getAddress());
      
      await expect(
        liquidityPool.connect(user2).swap(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          swapAmount,
          expectedOut + 1n // Slightly higher than possible
        )
      ).to.be.revertedWith("Excessive slippage");
    });

    it("Should reject swaps with invalid token pairs", async function () {
      await expect(
        liquidityPool.connect(user2).swap(
          user1.address, // Invalid token
          await tokenB.getAddress(),
          ethers.parseEther("100"),
          0
        )
      ).to.be.revertedWith("Invalid token pair");
    });

    it("Should calculate price ratio correctly", async function () {
      const priceRatio = await liquidityPool.getPriceRatio();
      expect(priceRatio).to.be.gt(0);
      
      // With 10k tokenA and 20k tokenB, ratio should be 2:1
      expect(priceRatio).to.be.closeTo(ethers.parseEther("2"), ethers.parseEther("0.01"));
    });
  });

  describe("Fee Management", function () {
    beforeEach(async function () {
      // Setup liquidity and perform a swap to generate fees
      await tokenA.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      await tokenB.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      
      await liquidityPool.connect(user1).addLiquidity(
        ethers.parseEther("10000"),
        ethers.parseEther("20000"),
        ethers.parseEther("10000"),
        ethers.parseEther("20000")
      );
      
      // Perform swap to generate fees
      await tokenA.connect(user2).approve(await liquidityPool.getAddress(), ethers.parseEther("1000"));
      await liquidityPool.connect(user2).swap(
        await tokenA.getAddress(),
        await tokenB.getAddress(),
        ethers.parseEther("100"),
        0
      );
    });

    it("Should collect trading fees", async function () {
      const totalFees = await liquidityPool.totalFeesCollected();
      expect(totalFees).to.be.gt(0);
    });

    it("Should allow owner to set fee rate", async function () {
      await liquidityPool.setFeeRate(50); // 0.5%
      
      const poolConfig = await liquidityPool.poolConfig();
      expect(poolConfig.feeRate).to.equal(50);
    });

    it("Should reject excessive fee rates", async function () {
      await expect(
        liquidityPool.setFeeRate(1001) // Over 10%
      ).to.be.revertedWith("Fee rate too high");
    });

    it("Should allow reward distribution", async function () {
      await expect(liquidityPool.distributeRewards())
        .to.emit(liquidityPool, "RewardsDistributed");
    });
  });

  describe("Pool Statistics", function () {
    beforeEach(async function () {
      await tokenA.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      await tokenB.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      
      await liquidityPool.connect(user1).addLiquidity(
        ethers.parseEther("1000"),
        ethers.parseEther("2000"),
        ethers.parseEther("1000"),
        ethers.parseEther("2000")
      );
    });

    it("Should return pool statistics", async function () {
      const stats = await liquidityPool.getPoolStats();
      
      expect(stats.reserveA).to.equal(ethers.parseEther("1000"));
      expect(stats.reserveB).to.equal(ethers.parseEther("2000"));
      expect(stats.totalLiquidity).to.be.gt(0);
      expect(stats.totalProviders).to.equal(1);
    });

    it("Should return liquidity provider info", async function () {
      const providerInfo = await liquidityPool.getLiquidityProviderInfo(user1.address);
      
      expect(providerInfo.liquidityTokens).to.be.gt(0);
      expect(providerInfo.totalProvided).to.be.gt(0);
    });

    it("Should return all providers", async function () {
      const providers = await liquidityPool.getAllProviders();
      expect(providers).to.include(user1.address);
    });
  });

  describe("Pausable Functionality", function () {
    it("Should allow owner to pause", async function () {
      await liquidityPool.pause();
      expect(await liquidityPool.paused()).to.be.true;
    });

    it("Should prevent operations when paused", async function () {
      await liquidityPool.pause();
      
      await tokenA.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      await tokenB.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      
      await expect(
        liquidityPool.connect(user1).addLiquidity(
          ethers.parseEther("1000"),
          ethers.parseEther("2000"),
          ethers.parseEther("1000"),
          ethers.parseEther("2000")
        )
      ).to.be.revertedWithCustomError(liquidityPool, "EnforcedPause");
    });

    it("Should allow emergency withdrawal when paused", async function () {
      // First add liquidity
      await tokenA.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      await tokenB.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      
      await liquidityPool.connect(user1).addLiquidity(
        ethers.parseEther("1000"),
        ethers.parseEther("2000"),
        ethers.parseEther("1000"),
        ethers.parseEther("2000")
      );
      
      await liquidityPool.pause();
      
      const poolBalanceA = await tokenA.balanceOf(await liquidityPool.getAddress());
      
      await liquidityPool.emergencyWithdraw(await tokenA.getAddress(), poolBalanceA);
      
      const finalPoolBalance = await tokenA.balanceOf(await liquidityPool.getAddress());
      expect(finalPoolBalance).to.equal(0);
    });
  });

  describe("Events", function () {
    it("Should emit PoolCreated event on deployment", async function () {
      const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
      
      await expect(
        LiquidityPool.deploy(
          await complianceRegistry.getAddress(),
          await oracleAdapter.getAddress(),
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          30
        )
      ).to.emit(LiquidityPool.prototype, "PoolCreated")
       .withArgs(await tokenA.getAddress(), await tokenB.getAddress(), 30);
    });

    it("Should emit LiquidityAdded event", async function () {
      await tokenA.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      await tokenB.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      
      await expect(
        liquidityPool.connect(user1).addLiquidity(
          ethers.parseEther("1000"),
          ethers.parseEther("2000"),
          ethers.parseEther("1000"),
          ethers.parseEther("2000")
        )
      ).to.emit(liquidityPool, "LiquidityAdded");
    });

    it("Should emit Swap event", async function () {
      // Setup liquidity first
      await tokenA.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      await tokenB.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("10000"));
      
      await liquidityPool.connect(user1).addLiquidity(
        ethers.parseEther("1000"),
        ethers.parseEther("2000"),
        ethers.parseEther("1000"),
        ethers.parseEther("2000")
      );
      
      await tokenA.connect(user2).approve(await liquidityPool.getAddress(), ethers.parseEther("1000"));
      
      await expect(
        liquidityPool.connect(user2).swap(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          ethers.parseEther("100"),
          0
        )
      ).to.emit(liquidityPool, "Swap");
    });
  });

  describe("Access Control", function () {
    it("Should not allow non-owner to set fee rate", async function () {
      await expect(
        liquidityPool.connect(user1).setFeeRate(50)
      ).to.be.revertedWithCustomError(liquidityPool, "OwnableUnauthorizedAccount");
    });

    it("Should not allow non-owner to pause", async function () {
      await expect(
        liquidityPool.connect(user1).pause()
      ).to.be.revertedWithCustomError(liquidityPool, "OwnableUnauthorizedAccount");
    });
  });

  describe("Edge Cases", function () {
    it("Should handle zero liquidity gracefully", async function () {
      await expect(
        liquidityPool.getPriceRatio()
      ).to.be.revertedWith("No liquidity");
    });

    it("Should reject zero swap amounts", async function () {
      await expect(
        liquidityPool.connect(user1).swap(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          0,
          0
        )
      ).to.be.revertedWith("Invalid input amount");
    });

    it("Should handle insufficient liquidity for swaps", async function () {
      // Try to swap without any liquidity in pool
      await tokenA.connect(user1).approve(await liquidityPool.getAddress(), ethers.parseEther("1000"));
      
      await expect(
        liquidityPool.connect(user1).swap(
          await tokenA.getAddress(),
          await tokenB.getAddress(),
          ethers.parseEther("100"),
          0
        )
      ).to.be.revertedWith("Insufficient liquidity");
    });
  });
});