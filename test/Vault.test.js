const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Vault", function () {
  let registry, token, oracle, vault, owner, user;

  beforeEach(async () => {
    [owner, user] = await ethers.getSigners();

    const ComplianceRegistry = await ethers.getContractFactory("ComplianceRegistry");
    registry = await ComplianceRegistry.deploy();

    const iYieldToken = await ethers.getContractFactory("iYieldToken");
    token = await iYieldToken.deploy(await registry.getAddress());

    const OracleAdapter = await ethers.getContractFactory("OracleAdapter");
    oracle = await OracleAdapter.deploy();

    const Vault = await ethers.getContractFactory("Vault");
    vault = await Vault.deploy(await token.getAddress(), await oracle.getAddress());

    // Setup permissions
    await token.addMinter(await vault.getAddress());
    await token.addBurner(await vault.getAddress());
    await registry.setWhitelist(user.address, true);
  });

  it("should mint iYield tokens on deposit", async () => {
    await oracle.updateCSV(1000000); // Mock CSV value

    const depositAmount = ethers.parseEther("1.0");
    await vault.connect(user).deposit(depositAmount, { value: depositAmount });
    
    expect(await token.balanceOf(user.address)).to.be.gt(0);
  });

  it("should calculate correct tokens to mint", async () => {
    const depositAmount = ethers.parseEther("1.0");
    const csvValue = 1000000;
    
    const tokensToMint = await vault.calculateTokensToMint(depositAmount, csvValue);
    expect(tokensToMint).to.be.gt(0);
  });

  it("should allow withdrawal of deposited funds", async () => {
    await oracle.updateCSV(1000000);
    
    const depositAmount = ethers.parseEther("1.0");
    await vault.connect(user).deposit(depositAmount, { value: depositAmount });
    
    const tokenBalance = await token.balanceOf(user.address);
    const userInitialBalance = await ethers.provider.getBalance(user.address);
    
    // Approve vault to burn tokens
    await token.connect(user).approve(await vault.getAddress(), tokenBalance);
    
    const tx = await vault.connect(user).withdraw(tokenBalance);
    const receipt = await tx.wait();
    const gasUsed = receipt.gasUsed * receipt.gasPrice;
    
    const userFinalBalance = await ethers.provider.getBalance(user.address);
    
    // User should have received ETH back (minus gas)
    expect(userFinalBalance).to.be.gt(userInitialBalance - gasUsed - depositAmount / BigInt(10));
  });

  it("should reject deposits from non-whitelisted addresses", async () => {
    const [, , nonWhitelistedUser] = await ethers.getSigners();
    const depositAmount = ethers.parseEther("1.0");
    
    await expect(
      vault.connect(nonWhitelistedUser).deposit(depositAmount, { value: depositAmount })
    ).to.be.revertedWith("User not whitelisted");
  });

  it("should update collateral ratio", async () => {
    const newRatio = 200; // 200%
    await vault.updateCollateralRatio(newRatio);
    
    expect(await vault.collateralRatio()).to.equal(newRatio);
  });

  it("should get user info correctly", async () => {
    await oracle.updateCSV(1000000);
    const depositAmount = ethers.parseEther("1.0");
    
    await vault.connect(user).deposit(depositAmount, { value: depositAmount });
    
    const [userDeposit, userTokens] = await vault.getUserInfo(user.address);
    expect(userDeposit).to.equal(depositAmount);
    expect(userTokens).to.be.gt(0);
  });
});