# BIP4444 x402 Payment Design (BSC)

**Status:** Design locked (pre-implementation)  
**Last updated:** 2026-10-17  
**Network:** BNB Smart Chain mainnet — CAIP-2 `eip155:56`  
**Policy:** No production payment flow and no membership grant until verify + settle succeed and negative tests pass.

---

## 0. Locked product decisions (updated 2026-10-17; supersedes the earlier 5 USDT draft)

| Decision | Choice |
|----------|--------|
| **Facilitator** | **B402** (Binance x402 on BSC) |
| **Price** | **4 USDT** exact (`scheme: exact`) |
| **Asset** | Binance-Peg **USDT** on BSC: `0x55d398326f99059fF775485246999027B3197955` (18 decimals) |
| **Atomic amount** | `4000000000000000000` (4 × 10^18) |
| **`payTo` address** | **`0xFf265912c76342c8469cE18aB9DF0B2f37d9373c`** |
| **`payTo` type** | **Safe multisig** (see verification) |
| **Register path** | **A — Backend relayer** after successful settle |
| **Identity** | ERC-8004 `agentId` + live `ownerOf(agentId)` check |
| **Role** | Client supplies a **role** string at registration |
| **Refund if settle OK but register fails** | **Yes** — see §7 |

Still open: B402 API credentials; relayer key; on-chain `role` later. The approved price is 4 USDT; earlier 5 USDT references in historical evidence are superseded.

### payTo — Safe verification (BSC mainnet, 2026-10-16)

| Field | Value |
|-------|--------|
| Address | `0xFf265912c76342c8469cE18aB9DF0B2f37d9373c` |
| Chain ID | 56 |
| Block | ~127884052 |
| Contract code | **Yes** (proxy ~123 bytes) |
| Safe VERSION | **1.5.0** |
| Threshold | **2** |
| Owners (2) | `0xfCeAfeC082F9e8b17CDb51f33c3d5c9759A25E03` |
| | `0x6783714167eC1c3519455AfCf2c93f6074624575` |
| Policy | **2-of-2** |

Previous interim EOA `0x6783714167eC1c3519455AfCf2c93f6074624575` is now an **owner** of this Safe (not the fee receiver).

Config: `BIP_PAY_TO=0xFf265912c76342c8469cE18aB9DF0B2f37d9373c`

Explorer: https://bscscan.com/address/0xFf265912c76342c8469cE18aB9DF0B2f37d9373c  
Evidence: `docs/evidence/PAYTO_SAFE_BSC_2026-10-16.md`

Relayer key must **not** be required as the only means to move funds; threshold 2 keeps dual control.

---

## 1. Goal

Use **x402 (v2)** + **B402** so an agent operator can pay **4 USDT** to the **Safe** `payTo` for BIP membership bound to ERC-8004 identity + **role**, without BIP holding user private keys.

**Hard rule:** Membership only after B402 verify + settle and relayer registration (or refund).

---

## 2. Protocol flow

```
Client → 402 (5 USDT → Safe 0xFf2659…373c) → B402 settle → relayer registerFor → 200
```

Headers: `PAYMENT-REQUIRED` / `PAYMENT-SIGNATURE` / `PAYMENT-RESPONSE`.

---

## 3. Registration (`agentId` + `role`)

402 binds: `eip155:56`, USDT, `5000000000000000000`, **payTo `0xFf265912c76342c8469cE18aB9DF0B2f37d9373c`**, resource metadata with agentId + role.

---

## 4. B402

Backend-only secrets. `supported` → `verify` → `settle`. USDT on BSC typically Permit2.

---

## 5. Path A — Relayer

| Address / key | Role |
|---------------|------|
| Safe `0xFf2659…373c` | Receive 5 USDT |
| Relayer KMS/EOA | Gas + `registerFor` only |
| B402 secret | Backend only |

---

## 6–8. Rules, refund, tests

Idempotent paymentId; refund 5 USDT to **payer** if settle OK but register fails; reject wrong payTo (must equal Safe above).

---

## 9. Checklist

- [x] Multisig Safe deployed & verified on BSC  
- [x] `BIP_PAY_TO` set to Safe  
- [ ] B402 credentials  
- [ ] API + ledger + relayer + refund  
- [ ] Negative tests + remaining audit gates  

---

## 10. References

- payTo Safe: `0xFf265912c76342c8469cE18aB9DF0B2f37d9373c`  
- USDT: `0x55d398326f99059fF775485246999027B3197955`  
- ERC-8004: `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`  
