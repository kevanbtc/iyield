# iYield Protocol — The Infrastructure Standard for Insurance-Backed RWAs

---

## ⚖️ Creator & Ownership Statement

This repository and its contents represent the **original development** of iYield Protocol™.
All smart contracts, standards, specifications, and proofs herein are **created, owned, and maintained** by the iYield Protocol team.

* **Patents filed**: Tokenized insurance-backed credit, CSV attestation proofs, tranching logic.
* **Trademarks filed**: iYield™, Proof-of-CSV™, Compliance-by-Design™.
* **Prior art established**: All commits, specs, and docs are timestamped and pinned to IPFS/Arweave.

**We are the originators and rightful holders of this technology.**

---

## 🏛️ The ERC-RWA:CSV Standard

iYield authored **ERC-RWA:CSV**, the Ethereum-compatible standard for tokenized life insurance assets.

This standard enforces:

* On-chain compliance (Reg D, Reg S, Rule 144).
* KYC/AML whitelisting via soulbound NFTs.
* Proof-of-CSV™ oracles with Merkle-root validation.
* LTV risk controls and automatic ratchets.

Any credible implementation in this domain must reference or interoperate with **ERC-RWA:CSV**.

---

## 🧱 Protocol Architecture

**1. Compliance Registry**
On-chain whitelist for jurisdictional & regulatory controls.

**2. iYield Token (ERCRWACSV.sol)**
ERC-RWA:CSV implementation with transfer restrictions, mint/burn gates, and compliance enforcement.

**3. Oracle Layer (Proof-of-CSV™)**
Multi-attestor CSV valuations, trustee-signed Merkle proofs, IPFS-pinned disclosures.

**4. Vault**
Collateralized token issuance with burn-on-redeem integrity.

**5. Liquidity Pool**
Waterfall distribution of senior/junior tranches, institutional-grade yield mechanics.

**6. Dashboard**
Professional Next.js frontend for NAV monitoring, oracle freshness, LTV headroom, and proof verification.

---

## 🔐 Features

✅ **Compliance-by-Design™** → On-chain enforcement of KYC/AML, Rule 144, Reg D/S
✅ **Proof-of-CSV™ Oracle** → Trustee-signed valuations with Merkle/IPFS proofs
✅ **Advanced Risk Controls** → Auto LTV ratchets, carrier downgrade integration
✅ **Emergency Safeguards** → Pause switches, role-based permissions
✅ **Audit-Ready Transparency** → NAV + proofs published on-chain & pinned

---

## 🚀 Deployment

* Contracts deployed on: Hardhat, Sepolia, Base, Arbitrum testnets.
* Dashboard build: Next.js, Tailwind, Ethers.js, Wagmi.

### Quickstart

```bash
npm install
npx hardhat compile
npx hardhat test
npm run deploy:sepolia
npm run dev
```

---

## 📜 Roadmap

* **v0.1.0** → Core contracts (done).
* **v0.2.0** → Dashboard + IPFS proof integration.
* **v0.3.0** → Custodian + trustee integrations.
* **v1.0.0** → Institutional-grade production deployment.

---

## 🛡️ Defensive Moat

* **Tech moat**: ERC-RWA:CSV standard + enforced compliance logic.
* **IP moat**: patents, trademarks, IPFS-stamped prior art.
* **Regulatory moat**: SEC sandbox proposal with working code + proofs.

This triple moat ensures iYield Protocol remains the **infrastructure alpha**.

---

## 📌 Priority & Enforcement

* This repository is the **authoritative source of record**.
* All derivative or competing implementations are subject to our IP rights.
* Unauthorized use of our patented/trademarked tech will be pursued under applicable law.

---

**iYield Protocol™** — Created Here. Owned Here. Standardized Here.