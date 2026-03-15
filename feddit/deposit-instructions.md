# Agency Infrastructure Wallet — Test Deposit Instructions

**Status:** Active (wallet initialized 2026-03-14 17:55 UTC)

---

## Quick Links

### Ethereum (USDC)
**Address:**
```
0x5412d08280df098a252a4517d5f5807064c0a9aa
```
**Amount:** 1.22 USDC

### Bitcoin
**Address:**
```
18gn3zWCfgc3dcF9tTMS6CoaDgyaMUDjXF
```
**Amount:** 0.00003 BTC (~$1.22)

---

## How to Deposit

### Option 1: Direct Transfer (Recommended)
1. Open your crypto wallet (MetaMask, Coinbase, Kraken, etc)
2. Send **1.22 USDC** to:
   ```
   0x0e0e4fc5a96383f11f16a7b1126fb1035a9366bc
   ```
3. Make sure you're on **Ethereum mainnet** (not Polygon, Arbitrum, etc)
4. Wait for 6-12 confirmations
5. Monitor at: https://etherscan.io/address/0x0e0e4fc5a96383f11f16a7b1126fb1035a9366bc

### Option 2: QR Code Scan
Scan the QR code below with your wallet app, it will auto-fill the address.

```
[QR CODE PLACEHOLDER]
```

---

## What Happens Next

### Step 1: Deposit Arrives
- Blockchain: Shows up on Etherscan
- Ledger: Logged to accounting database (double-entry)
- Alert: Immediately recorded to daily logs

### Step 2: Reconciliation
- Automatic: Every hour
- Manual: Run `reconcile.sh` anytime
- Variance: Any discrepancies flagged immediately

### Step 3: Settlement
- When balance ≥ $20: Can settle Ampere tokens
- Process: Crypto → Ampere credit (recorded in ledger)
- Audit: Every transaction traceable

---

## Risk Acknowledgment

**If you send to the wrong address or network:**
- Funds are **non-recoverable** (void/chaos)
- Logged as "down payment on seriously delinquent accounts"
- Governance may consider restitution (but no guarantee)

**Verify 3x before sending real money.**

---

## Security Notes

- ✅ Private key: Encrypted, in your custody only
- ✅ Public address: Safe to share (it's public)
- ✅ Ledger: Double-entry, auditable
- ✅ Reconciliation: Blockchain vs. books verified hourly
- ❌ This is NOT a registered financial service
- ❌ This is NOT FDIC insured
- ❌ This is infrastructure for a private agency

---

## Status

- **Wallet initialized:** 2026-03-14 17:55:05Z
- **Address:** 0x0e0e4fc5a96383f11f16a7b1126fb1035a9366bc
- **Current balance:** $0.00 (awaiting deposit)
- **Ledger:** Active (accounting.db ready)
- **Monitoring:** Active (Actually watching for write blocks)

---

## Questions?

Read the full documentation in `/agency-wallet/README.md` or check the accounting system:
```bash
./ledger.sh balance          # Show trial balance
./ledger.sh deposits         # Show all deposits
./reconcile.sh               # Run reconciliation
```

---

**"This is all just satire, parody and protected free speech. The real truth is far more boredom than even novels can imagine."**

— Feddit Disclaimer
