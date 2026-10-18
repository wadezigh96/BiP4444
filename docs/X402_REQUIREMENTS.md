# BIP4444 x402 Payment Design (BSC)

**Status:** Design locked (pre-implementation)  
**Last updated:** 2026-10-19  
**Network:** BNB Smart Chain mainnet — CAIP-2 `eip155:56`  
**Policy:** No production payment flow and no membership grant until verify + settle succeed and negative tests pass.

---

## 0. Locked product decisions (updated 2026-10-17; current price is 4 USDT)

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

The current approved price is **4 USDT**. Any older draft reference to 5 USDT is obsolete. This document is a design specification; the API scaffold currently fails closed and does not request or process payments.

### payTo — Safe verification (BSC mainnet, 2026-10-16)

| Field | Value |
|-------|-------|
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

Use **x402 (v2)** + **B402** so an agent operator can pay **4 USDT** to the Safe `payTo` for BIP membership bound to ERC-8004 identity + **role**, without BIP holding user private keys.

**Hard rule:** Membership only after B402 verify + settle and relayer registration (or refund).

---

## 2. Protocol flow

```
Client → 402 (4 USDT → Safe 0xFf2659…373c) → B402 settle → relayer registerFor → 200
```

Headers: `PAYMENT-REQUIRED` / `PAYMENT-SIGNATURE` / `PAYMENT-RESPONSE`.

---

## 3. Registration (`agentId` + `role`)

402 binds: `eip155:56`, USDT, `4000000000000000000`, **payTo `0xFf265912c76342c8469cE18aB9DF0B2f37d9373c`**, resource metadata with agentId + role.

---

## 4. B402

Backend-only secrets. Verify current official B402 documentation and pin the actual SDK/API version before implementing `supported` → `verify` → `settle`. USDT on BSC may use Permit2 depending on the supported scheme; confirm from official docs rather than assuming.

---

## 5. Path A — Relayer

| Address / key | Role |
|---------------|------|
| Safe `0xFf2659…373c` | Receive 4 USDT |
| Relayer KMS/EOA | Gas + `registerFor` only |
| B402 secret | Backend only |

---

## 6–8. Rules, refund, tests

Idempotent payment operation; refund exactly 4 USDT to the verified payer if settlement succeeds but registration definitively fails. Refund and settlement retries must reconcile ambiguous provider outcomes and must never produce duplicate operations.

---

## 9. Checklist

- [x] Multisig Safe deployed & verified on BSC (historical evidence recorded)
- [x] Server-side price policy specified as 4 USDT
- [ ] Official B402 docs/SDK version and canonical x402 v2 headers verified
- [ ] B402 credentials safely configured
- [ ] Production API + durable ledger + relayer + refund implemented and tested
- [ ] Negative tests + remaining audit gates passed

---

## 10. References

- payTo Safe: `0xFf265912c76342c8469cE18aB9DF0B2f37d9373c`
- USDT: `0x55d398326f99059fF775485246999027B3197955`
- ERC-8004: `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`
