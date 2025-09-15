const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("iYield Protocol Core Tests", function () {
    let csvOracle, complianceEngine, iYieldToken;
    let owner, attester, investor1, investor2;
    let samplePolicyId;
    
    beforeEach(async function () {
        [owner, attester, investor1, investor2] = await ethers.getSigners();
        
        // Deploy contracts
        const CSVOracle = await ethers.getContractFactory("CSVOracle");
        csvOracle = await CSVOracle.deploy(owner.address);
        
        const ComplianceEngine = await ethers.getContractFactory("ComplianceEngine");
        complianceEngine = await ComplianceEngine.deploy(owner.address);
        
        const IYieldToken = await ethers.getContractFactory("IYieldToken");
        iYieldToken = await IYieldToken.deploy(
            "iYield Test Token",
            "iTEST",
            await csvOracle.getAddress(),
            await complianceEngine.getAddress(),
            owner.address
        );
        
        // Setup permissions
        const ATTESTER_ROLE = await csvOracle.ATTESTER_ROLE();
        const COMPLIANCE_OFFICER_ROLE = await complianceEngine.COMPLIANCE_OFFICER_ROLE();
        
        await csvOracle.grantRole(ATTESTER_ROLE, attester.address);
        await complianceEngine.grantRole(COMPLIANCE_OFFICER_ROLE, owner.address);
        
        samplePolicyId = ethers.id("POLICY_TEST_001");
    });
    
    describe("CSV Oracle Functionality", function () {
        it("Should allow authorized attester to update policy attestation", async function () {
            const csvValue = ethers.parseEther("50000");
            const timestamp = Math.floor(Date.now() / 1000);
            const ipfsHash = "QmTestHash123";
            const merkleRoot = ethers.id("test_merkle");
            
            const messageHash = ethers.solidityPackedKeccak256(
                ["bytes32", "uint256", "uint256", "string", "bytes32"],
                [samplePolicyId, csvValue, timestamp, ipfsHash, merkleRoot]
            );
            const signature = await attester.signMessage(ethers.getBytes(messageHash));
            
            const attestation = {
                policyId: samplePolicyId,
                csvValue: csvValue,
                timestamp: timestamp,
                ipfsHash: ipfsHash,
                merkleRoot: merkleRoot,
                attester: attester.address,
                signature: signature
            };
            
            await expect(csvOracle.connect(attester).updateAttestation(attestation))
                .to.emit(csvOracle, "AttestationUpdated")
                .withArgs(samplePolicyId, csvValue, ipfsHash, merkleRoot);
            
            const storedAttestation = await csvOracle.getAttestation(samplePolicyId);
            expect(storedAttestation.csvValue).to.equal(csvValue);
            expect(storedAttestation.ipfsHash).to.equal(ipfsHash);
        });
        
        it("Should detect stale attestations", async function () {
            // Test with no attestation (should be stale)
            expect(await csvOracle.isStale(samplePolicyId, 3600)).to.be.true;
        });
    });
    
    describe("Compliance Engine Functionality", function () {
        it("Should update and retrieve compliance profiles", async function () {
            const profile = {
                investorType: 1, // ACCREDITED
                kycTimestamp: Math.floor(Date.now() / 1000),
                accreditationExpiry: Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60,
                isWhitelisted: true,
                restriction: 0, // NONE
                restrictionParam: 0
            };
            
            await complianceEngine.updateCompliance(investor1.address, profile);
            
            const storedProfile = await complianceEngine.getCompliance(investor1.address);
            expect(storedProfile.investorType).to.equal(1);
            expect(storedProfile.isWhitelisted).to.be.true;
        });
        
        it("Should enforce transfer restrictions", async function () {
            // Setup compliant profiles for both parties
            const profile = {
                investorType: 1, // ACCREDITED
                kycTimestamp: Math.floor(Date.now() / 1000),
                accreditationExpiry: Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60,
                isWhitelisted: true,
                restriction: 0, // NONE
                restrictionParam: 0
            };
            
            await complianceEngine.updateCompliance(investor1.address, profile);
            await complianceEngine.updateCompliance(investor2.address, profile);
            
            const [canTransfer, reason] = await complianceEngine.canTransfer(
                investor1.address,
                investor2.address,
                ethers.parseEther("1000")
            );
            
            expect(canTransfer).to.be.true;
            expect(reason).to.equal("Transfer allowed");
        });
        
        it("Should reject transfers for non-compliant investors", async function () {
            // Don't set up compliance profiles (default to non-compliant)
            const [canTransfer, reason] = await complianceEngine.canTransfer(
                investor1.address,
                investor2.address,
                ethers.parseEther("1000")
            );
            
            expect(canTransfer).to.be.false;
            expect(reason).to.include("KYC expired");
        });
    });
    
    describe("iYield Token Integration", function () {
        beforeEach(async function () {
            // Setup attestation
            const csvValue = ethers.parseEther("100000");
            const timestamp = Math.floor(Date.now() / 1000);
            const ipfsHash = "QmTestHash123";
            const merkleRoot = ethers.id("test_merkle");
            
            const messageHash = ethers.solidityPackedKeccak256(
                ["bytes32", "uint256", "uint256", "string", "bytes32"],
                [samplePolicyId, csvValue, timestamp, ipfsHash, merkleRoot]
            );
            const signature = await attester.signMessage(ethers.getBytes(messageHash));
            
            const attestation = {
                policyId: samplePolicyId,
                csvValue: csvValue,
                timestamp: timestamp,
                ipfsHash: ipfsHash,
                merkleRoot: merkleRoot,
                attester: attester.address,
                signature: signature
            };
            
            await csvOracle.connect(attester).updateAttestation(attestation);
            
            // Setup compliance for investor
            const profile = {
                investorType: 1, // ACCREDITED
                kycTimestamp: Math.floor(Date.now() / 1000),
                accreditationExpiry: Math.floor(Date.now() / 1000) + 365 * 24 * 60 * 60,
                isWhitelisted: true,
                restriction: 0, // NONE
                restrictionParam: 0
            };
            
            await complianceEngine.updateCompliance(investor1.address, profile);
        });
        
        it("Should add policy backing and issue tokens", async function () {
            const csvValue = ethers.parseEther("100000");
            const tokensToIssue = ethers.parseEther("80000"); // 80% LTV
            
            await expect(
                iYieldToken.addPolicyBacking(
                    samplePolicyId,
                    csvValue,
                    tokensToIssue,
                    investor1.address
                )
            ).to.emit(iYieldToken, "PolicyAdded")
             .withArgs(samplePolicyId, csvValue, tokensToIssue);
            
            expect(await iYieldToken.balanceOf(investor1.address)).to.equal(tokensToIssue);
            
            const systemStatus = await iYieldToken.getSystemStatus();
            expect(systemStatus[0]).to.equal(csvValue); // totalCsvValue
            expect(systemStatus[2]).to.equal(tokensToIssue); // totalSupply
        });
        
        it("Should calculate correct LTV ratios", async function () {
            const csvValue = ethers.parseEther("100000");
            const tokensToIssue = ethers.parseEther("80000"); // 80% LTV
            
            await iYieldToken.addPolicyBacking(
                samplePolicyId,
                csvValue,
                tokensToIssue,
                investor1.address
            );
            
            const ltv = await iYieldToken.getPolicyLTV(samplePolicyId);
            expect(ltv).to.equal(8000); // 80% in basis points
        });
        
        it("Should reject excessive LTV ratios", async function () {
            const csvValue = ethers.parseEther("100000");
            const tokensToIssue = ethers.parseEther("95000"); // 95% LTV (exceeds 90% max)
            
            await expect(
                iYieldToken.addPolicyBacking(
                    samplePolicyId,
                    csvValue,
                    tokensToIssue,
                    investor1.address
                )
            ).to.be.revertedWith("LTV exceeds maximum allowed");
        });
        
        it("Should publish disclosure hashes", async function () {
            const ipfsHash = "QmDisclosureHash123";
            
            await expect(iYieldToken.publishDisclosure(ipfsHash))
                .to.emit(iYieldToken, "DisclosurePublished");
            
            const storedHash = await iYieldToken.disclosureHashes(1);
            expect(storedHash).to.equal(ipfsHash);
        });
        
        it("Should update NAV correctly", async function () {
            const csvValue = ethers.parseEther("100000");
            const tokensToIssue = ethers.parseEther("80000");
            
            await iYieldToken.addPolicyBacking(
                samplePolicyId,
                csvValue,
                tokensToIssue,
                investor1.address
            );
            
            const navPerToken = await iYieldToken.navPerToken();
            const expectedNav = csvValue * ethers.parseEther("1") / tokensToIssue;
            expect(navPerToken).to.equal(expectedNav);
        });
    });
});