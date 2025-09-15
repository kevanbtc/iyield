const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ComplianceRegistry", function () {
  let registry, owner, user1, user2;

  beforeEach(async () => {
    [owner, user1, user2] = await ethers.getSigners();

    const ComplianceRegistry = await ethers.getContractFactory("ComplianceRegistry");
    registry = await ComplianceRegistry.deploy();
  });

  it("should deploy with correct owner", async () => {
    expect(await registry.owner()).to.equal(owner.address);
  });

  it("should allow owner to whitelist addresses", async () => {
    await registry.setWhitelist(user1.address, true);
    expect(await registry.isWhitelisted(user1.address)).to.be.true;
    expect(await registry.whitelist(user1.address)).to.be.true;
  });

  it("should allow owner to remove addresses from whitelist", async () => {
    await registry.setWhitelist(user1.address, true);
    await registry.setWhitelist(user1.address, false);
    expect(await registry.isWhitelisted(user1.address)).to.be.false;
  });

  it("should emit AddressWhitelisted event", async () => {
    await expect(registry.setWhitelist(user1.address, true))
      .to.emit(registry, "AddressWhitelisted")
      .withArgs(user1.address, true);
  });

  it("should not allow non-owner to whitelist addresses", async () => {
    await expect(registry.connect(user1).setWhitelist(user2.address, true))
      .to.be.revertedWithCustomError(registry, "OwnableUnauthorizedAccount");
  });

  it("should set and get KYC levels", async () => {
    await registry.setKycLevel(user1.address, 2);
    expect(await registry.getKycLevel(user1.address)).to.equal(2);
    expect(await registry.kycLevel(user1.address)).to.equal(2);
  });

  it("should emit KycLevelUpdated event", async () => {
    await expect(registry.setKycLevel(user1.address, 1))
      .to.emit(registry, "KycLevelUpdated")
      .withArgs(user1.address, 1);
  });

  it("should not allow non-owner to set KYC levels", async () => {
    await expect(registry.connect(user1).setKycLevel(user2.address, 1))
      .to.be.revertedWithCustomError(registry, "OwnableUnauthorizedAccount");
  });

  it("should return false for non-whitelisted addresses", async () => {
    expect(await registry.isWhitelisted(user1.address)).to.be.false;
  });

  it("should return 0 for addresses with no KYC level", async () => {
    expect(await registry.getKycLevel(user1.address)).to.equal(0);
  });
});