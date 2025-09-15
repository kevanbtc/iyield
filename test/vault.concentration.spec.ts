import { expect } from "chai";
import { ethers } from "hardhat";

function bps(x: number){ return Math.floor(x * 100); }

describe("CSVVault — carrier concentration caps", () => {
  it("blocks mint if adding exposure breaches cap", async () => {
    const [gov] = await ethers.getSigners();
    const Oracle = await ethers.getContractFactory("CSVOracle");
    const Harness = await ethers.getContractFactory("CSVVaultHarness");

    const oracle = await Oracle.connect(gov).deploy();
    const vault  = await Harness.connect(gov).deploy(await oracle.getAddress());

    await vault.connect(gov).setMaxCarrierBps(3000); // 30%
    // simulate internal state if needed, or assume 0 for test
    const carrier = ethers.keccak256(ethers.toUtf8Bytes("ExampleLife"));
    const now = Math.floor(Date.now()/1000) - 60*60*24*365*3; // 3y ago

    // Should revert if cap would be breached (addBps > maxCarrierBps)
    await expect(
      vault.__test__preMint(carrier, now, 3500 /* 35% */)
    ).to.be.reverted;
  });
});
