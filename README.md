# iYield Protocol 🛡️⚡

**Programmable Fixed Income. Tokenized Insurance-Backed Credit. Compliance-First by Design.**

---

## 🔥 Vision

iYield is the **infrastructure layer** for tokenizing life insurance cash value (CSV) into secure, transparent, and compliant digital assets.

While others pitch vapor, we built the rails:

* **Smart contracts that enforce compliance.**
* **Attestation oracles that prove asset backing.**
* **Transparent disclosures pinned on IPFS.**

We are the **alpha standard** for tokenized insurance-backed RWAs. Anyone who wants to play in this arena has to move through our rails.

---

## 🏛️ Core Principles

1. **Compliance by Design**

   * Reg D / Reg S restrictions built into contracts.
   * On-chain KYC whitelists.
   * Rule 144 lockups enforced.

2. **Transparency First**

   * NAV & collateral values attested and pinned on IPFS.
   * Oracle freshness checks (no stale data).
   * Carrier rating–based collateral factors.

3. **Security & Integrity**

   * Burn-on-redeem: token supply always matches backing.
   * Multi-oracle redundancy: no single point of failure.
   * Automatic LTV ratchets on carrier downgrades.

---

## 🧩 Protocol Components

### 1. Compliance Registry

* Maintains **whitelist of eligible investors**.
* Enforces transfer restrictions (ERC-1400/3643 style).

### 2. iYield Token (`iYIELD`)

* ERC-20 security token with transfer/mint/burn gates.
* Only whitelisted addresses can hold or transfer.
* **MINTER\_ROLE** & **BURNER\_ROLE** → vault-controlled.

### 3. Oracle Adapter

* Records **attested CSV values** with signatures.
* Anchors Merkle root of policy set on-chain.
* Publishes proof bundle on IPFS/Arweave.
* Enforces **max data age** before blocking mint/redeem.

### 4. Vault

* Accepts stablecoin collateral.
* Mints iYIELD tokens up to **collateralFactor × CSV**.
* Enforces burn-on-redeem: supply matches collateral.
* Auto-ratchets LTV if carrier risk changes.

### 5. Liquidity Pool

* **Senior/junior tranching** with target senior yield.
* Waterfall distribution of returns.
* On-chain accruals with claimable balances.

---

## 🖥️ Dashboard & Disclosures

* **Frontend (Next.js)**: live NAV, oracle update age, LTV headroom.
* **IPFS Proofs**: every update pinned & hashed.
* **API hooks** for auditors, regulators, and investors.

---

## ⚔️ IP & Standards

We own the rails:

* **Trademarks**: iYield™, Proof-of-CSV™, Compliance-by-Design™.
* **Patents (provisional filed)**:

  * Tokenized insurance-backed credit with enforceable LTV.
  * Oracle-based CSV attestation proofs.
  * On-chain waterfall tranching of pooled CSV assets.
* **Standards**: Drafted **ERC-RWA\:CSV**, the Ethereum protocol standard for tokenized life insurance assets.

Any serious implementation in this category must reference or interoperate with iYield.

---

## 🚀 Deployment

**Networks Supported**:

* Hardhat local
* Sepolia testnet
* Base Sepolia
* Arbitrum Sepolia

**Setup**:

```bash
npm install
cp .env.example .env
npx hardhat compile
npx hardhat test
npm run deploy:sepolia
```

---

## 📜 Roadmap

* **v0.1.0** → Core contracts + CI/CD (done).
* **v0.2.0** → Dashboard + IPFS disclosures.
* **v0.3.0** → Custodian integrations, attested CSV updates.
* **v1.0.0** → Production launch with carriers & custodians.

---

## 🛡️ Our Position vs Others

Lifesurance/USDIY = **Squarespace flyer + lobbying letter**.
iYield = **working contracts, enforced compliance, proof rails, and IP fortress**.

We are not just first movers—we are the **infrastructure layer** and the **IP gatekeepers** of insurance-backed RWAs.

---

## ⚡ Contribute

Want to help define the standard for insurance-backed tokenization?

* Fork, build, PR.
* Propose EIPs.
* Join the iYield DAO when governance goes live.

---

**iYield Protocol™** — The Future of Fixed Income, Backed by Life.