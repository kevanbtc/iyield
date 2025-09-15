const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LiquidityPool", function () {
  let registry, token, oracle, vault, pool, owner, user1, user2;

  beforeEach(async () => {
    [owner, user1, user2] = await ethers.getSigners();

    const ComplianceRegistry = await ethers.getContractFactory("ComplianceRegistry");
    registry = await ComplianceRegistry.deploy();

    const iYieldToken = await ethers.getContractFactory("iYieldToken");
    token = await iYieldToken.deploy(await registry.getAddress());

    const OracleAdapter = await ethers.getContractFactory("OracleAdapter");
    oracle = await OracleAdapter.deploy();

    const Vault = await ethers.getContractFactory("Vault");
    vault = await Vault.deploy(await token.getAddress(), await oracle.getAddress());

    const LiquidityPool = await ethers.getContractFactory("LiquidityPool");
    pool = await LiquidityPool.deploy(await token.getAddress(), await vault.getAddress());

    // Setup permissions
    await token.addMinter(owner.address);
    await registry.setWhitelist(user1.address, true);
    await registry.setWhitelist(user2.address, true);
  });

  it("should allow liquidity deposits", async () => {
    const depositAmount = ethers.parseEther("1000");
    
    // Mint tokens to user1 and approve pool
    await token.mint(user1.address, depositAmount);
    await token.connect(user1).approve(await pool.getAddress(), depositAmount);
    
    await pool.connect(user1).depositLiquidity(depositAmount);
    
    expect(await pool.liquidityBalance(user1.address)).to.equal(depositAmount);
    expect(await pool.totalLiquidity()).to.equal(depositAmount);
  });

  it("should emit LiquidityDeposited event", async () => {
    const depositAmount = ethers.parseEther("1000");
    
    await token.mint(user1.address, depositAmount);
    await token.connect(user1).approve(await pool.getAddress(), depositAmount);
    
    await expect(pool.connect(user1).depositLiquidity(depositAmount))
      .to.emit(pool, "LiquidityDeposited")
      .withArgs(user1.address, depositAmount);
  });

  it("should allow liquidity withdrawals", async () => {
    const depositAmount = ethers.parseEther("1000");
    const withdrawAmount = ethers.parseEther("500");
    
    // Setup: deposit liquidity
    await token.mint(user1.address, depositAmount);
    await token.connect(user1).approve(await pool.getAddress(), depositAmount);
    await pool.connect(user1).depositLiquidity(depositAmount);
    
    const initialBalance = await token.balanceOf(user1.address);
    
    // Withdraw
    await pool.connect(user1).withdrawLiquidity(withdrawAmount);
    
    expect(await pool.liquidityBalance(user1.address)).to.equal(depositAmount - withdrawAmount);
    expect(await token.balanceOf(user1.address)).to.equal(initialBalance + withdrawAmount);
  });

  it("should not allow withdrawal of more than deposited", async () => {
    const depositAmount = ethers.parseEther("1000");
    const withdrawAmount = ethers.parseEther("1500");
    
    await token.mint(user1.address, depositAmount);
    await token.connect(user1).approve(await pool.getAddress(), depositAmount);
    await pool.connect(user1).depositLiquidity(depositAmount);
    
    await expect(pool.connect(user1).withdrawLiquidity(withdrawAmount))
      .to.be.revertedWith("Insufficient liquidity balance");
  });

  it("should calculate pending yield correctly", async () => {
    const depositAmount = ethers.parseEther("1000");
    
    await token.mint(user1.address, depositAmount);
    await token.connect(user1).approve(await pool.getAddress(), depositAmount);
    await pool.connect(user1).depositLiquidity(depositAmount);
    
    // Advance time by 1 year (simulate)
    await ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");
    
    const [balance, pendingYield] = await pool.getUserLiquidityInfo(user1.address);
    
    expect(balance).to.equal(depositAmount);
    expect(pendingYield).to.be.gt(0);
  });

  it("should allow owner to update yield rate", async () => {
    const newRate = 1000; // 10%
    await pool.updateYieldRate(newRate);
    
    expect(await pool.yieldRate()).to.equal(newRate);
  });

  it("should emit YieldRateUpdated event", async () => {
    const newRate = 1000;
    
    await expect(pool.updateYieldRate(newRate))
      .to.emit(pool, "YieldRateUpdated")
      .withArgs(newRate);
  });

  it("should not allow yield rate above maximum", async () => {
    const tooHighRate = 2500; // 25% - above 20% max
    
    await expect(pool.updateYieldRate(tooHighRate))
      .to.be.revertedWith("Yield rate too high");
  });

  it("should not allow non-owner to update yield rate", async () => {
    const newRate = 1000;
    
    await expect(pool.connect(user1).updateYieldRate(newRate))
      .to.be.revertedWithCustomError(pool, "OwnableUnauthorizedAccount");
  });

  it("should reject zero amount deposits", async () => {
    await expect(pool.connect(user1).depositLiquidity(0))
      .to.be.revertedWith("Amount must be greater than 0");
  });

  it("should reject zero amount withdrawals", async () => {
    await expect(pool.connect(user1).withdrawLiquidity(0))
      .to.be.revertedWith("Amount must be greater than 0");
  });

  it("should handle multiple users correctly", async () => {
    const depositAmount1 = ethers.parseEther("1000");
    const depositAmount2 = ethers.parseEther("2000");
    
    // User1 deposits
    await token.mint(user1.address, depositAmount1);
    await token.connect(user1).approve(await pool.getAddress(), depositAmount1);
    await pool.connect(user1).depositLiquidity(depositAmount1);
    
    // User2 deposits
    await token.mint(user2.address, depositAmount2);
    await token.connect(user2).approve(await pool.getAddress(), depositAmount2);
    await pool.connect(user2).depositLiquidity(depositAmount2);
    
    expect(await pool.liquidityBalance(user1.address)).to.equal(depositAmount1);
    expect(await pool.liquidityBalance(user2.address)).to.equal(depositAmount2);
    expect(await pool.totalLiquidity()).to.equal(depositAmount1 + depositAmount2);
  });
});