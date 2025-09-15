const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("iYieldToken", function () {
  let registry, token, owner, user1, user2;

  beforeEach(async () => {
    [owner, user1, user2] = await ethers.getSigners();

    const ComplianceRegistry = await ethers.getContractFactory("ComplianceRegistry");
    registry = await ComplianceRegistry.deploy();

    const iYieldToken = await ethers.getContractFactory("iYieldToken");
    token = await iYieldToken.deploy(await registry.getAddress());

    // Whitelist users for testing
    await registry.setWhitelist(user1.address, true);
    await registry.setWhitelist(user2.address, true);
  });

  it("should deploy with correct name and symbol", async () => {
    expect(await token.name()).to.equal("iYield Token");
    expect(await token.symbol()).to.equal("iYLD");
  });

  it("should allow owner to add minters", async () => {
    await token.addMinter(user1.address);
    expect(await token.minters(user1.address)).to.be.true;
  });

  it("should emit MinterAdded event", async () => {
    await expect(token.addMinter(user1.address))
      .to.emit(token, "MinterAdded")
      .withArgs(user1.address);
  });

  it("should allow minters to mint tokens to whitelisted addresses", async () => {
    await token.addMinter(user1.address);
    const mintAmount = ethers.parseEther("100");
    
    await token.connect(user1).mint(user2.address, mintAmount);
    expect(await token.balanceOf(user2.address)).to.equal(mintAmount);
  });

  it("should not allow minting to non-whitelisted addresses", async () => {
    const [, , , nonWhitelistedUser] = await ethers.getSigners();
    await token.addMinter(user1.address);
    const mintAmount = ethers.parseEther("100");
    
    await expect(token.connect(user1).mint(nonWhitelistedUser.address, mintAmount))
      .to.be.revertedWith("User not whitelisted");
  });

  it("should not allow non-minters to mint", async () => {
    const mintAmount = ethers.parseEther("100");
    
    await expect(token.connect(user1).mint(user2.address, mintAmount))
      .to.be.revertedWith("Not authorized to mint");
  });

  it("should allow owner to remove minters", async () => {
    await token.addMinter(user1.address);
    await token.removeMinter(user1.address);
    expect(await token.minters(user1.address)).to.be.false;
  });

  it("should allow owner to add burners", async () => {
    await token.addBurner(user1.address);
    expect(await token.burners(user1.address)).to.be.true;
  });

  it("should allow burners to burn tokens", async () => {
    // Setup: mint tokens first
    await token.addMinter(owner.address);
    const mintAmount = ethers.parseEther("100");
    await token.mint(user1.address, mintAmount);
    
    // Add burner and burn
    await token.addBurner(user2.address);
    const burnAmount = ethers.parseEther("50");
    
    await token.connect(user2).burnFrom(user1.address, burnAmount);
    expect(await token.balanceOf(user1.address)).to.equal(mintAmount - burnAmount);
  });

  it("should not allow transfers to non-whitelisted addresses", async () => {
    const [, , , nonWhitelistedUser] = await ethers.getSigners();
    
    // Setup: mint tokens to user1
    await token.addMinter(owner.address);
    const mintAmount = ethers.parseEther("100");
    await token.mint(user1.address, mintAmount);
    
    // Try to transfer to non-whitelisted user
    const transferAmount = ethers.parseEther("10");
    await expect(token.connect(user1).transfer(nonWhitelistedUser.address, transferAmount))
      .to.be.revertedWith("User not whitelisted");
  });

  it("should allow transfers to whitelisted addresses", async () => {
    // Setup: mint tokens to user1
    await token.addMinter(owner.address);
    const mintAmount = ethers.parseEther("100");
    await token.mint(user1.address, mintAmount);
    
    // Transfer to whitelisted user
    const transferAmount = ethers.parseEther("10");
    await token.connect(user1).transfer(user2.address, transferAmount);
    
    expect(await token.balanceOf(user1.address)).to.equal(mintAmount - transferAmount);
    expect(await token.balanceOf(user2.address)).to.equal(transferAmount);
  });

  it("should not allow non-owner to add minters", async () => {
    await expect(token.connect(user1).addMinter(user2.address))
      .to.be.revertedWithCustomError(token, "OwnableUnauthorizedAccount");
  });

  it("should not allow non-owner to add burners", async () => {
    await expect(token.connect(user1).addBurner(user2.address))
      .to.be.revertedWithCustomError(token, "OwnableUnauthorizedAccount");
  });
});