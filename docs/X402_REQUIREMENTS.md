# BIP4444 x402 Payment Design (BSC)

**Status:** Design locked + relayer skeleton  
**Last updated:** 2026-10-21  
**Network:** BNB Smart Chain mainnet — CAIP-2 `eip155:56`  
**Policy:** No production payment flow and no membership grant until verify + settle succeed and negative tests pass.

---

## 0. Locked product decisions (2026-10-16)

| Decision | Choice |
|----------|--------|
| **Facilitator** | **B402** (Binance x402 on BSC) |
| **Price** | **5 USDT** exact (`scheme: exact`) |
| **Asset** | Binance-Peg **USDT** on BSC: `0x55d398326f99059fF775485246999027B3197955` (18 decimals) |
| **Atomic amount** | `5000000000000000000` (5 × 10^18) |
| **`payTo` address** | **`0xFf265912c76342c8469cE18aB9DF0B2f37d9373c`** |
| **`payTo` type** | **Safe multisig** (see verification) |
| **Register path** | **A — Backend relayer** after successful settle |
| **Identity** | ERC-8004 `agentId` + live `ownerOf(agentId)` check |
| **Role** | Client supplies a **role** string at registration |
| **Refund if settle OK but register fails** | **Yes** — see §7 |

Still open: B402 API credentials; relayer key deployment; on-chain `role` later.

### payTo — Safe verification (BSC mainnet, 2026-10-16)

| Field | Value |
|-------|--------|
| Address | `0xFf265912c76342c8469cE18aB9DF0B2f37d9373c` |
| Chain ID | 56 |
| Contract code | **Yes** (proxy) |
| Safe VERSION | **1.5.0** |
| Threshold | **2** |
| Owners (2) | `0xfCeAfeC082F9e8b17CDb51f33c3d5c9759A25E03` |
| | `0x6783714167eC1c3519455AfCf2c93f6074624575` |
| Policy | **2-of-2** |

Config: `BIP_PAY_TO=0xFf265912c76342c8469cE18aB9DF0B2f37d9373c`

Explorer: https://bscscan.com/address/0xFf265912c76342c8469cE18aB9DF0B2f37d9373c  
Evidence: `docs/evidence/PAYTO_SAFE_BSC_2026-10-16.md`

---

## 1. Goal

Use **x402 (v2)** + **B402** so an agent operator can pay **5 USDT** to the **Safe** `payTo` for BIP membership bound to ERC-8004 identity + **role**, without BIP holding user private keys.

**Hard rule:** Membership only after B402 verify + settle and relayer registration (or refund).

---

## 2. Protocol flow

```
Client → 402 (5 USDT → Safe 0xFf2659…373c) → B402 verify+settle → relayer registerFor → 200
```

---

## 3. Implementation status

| Component | Status |
|-----------|--------|
| Membership controller + `registerFor` | Implemented (skeleton) |
| Relayer script skeleton | **Added** (`scripts/relayer-x402-example.js`) |
| Real B402 authenticated client | Not yet (needs credentials) |
| Persistent ledger | Not yet |
| Refund execution | Flag only (manual/Safe) |
| HTTP API | Not yet |

See `docs/RELAYER.md` for details.

---

## 4. B402 notes

Two surfaces currently exist:

- `https://facilitatorv3.b402.ai` (docs.b402.ai)
- Binance official authenticated B402 (`/papi/v2/b402/*` — partner onboarding required)

USDT on BSC supports Permit2-style authorizations.

---

## 5. Checklist

- [x] Multisig Safe deployed & verified on BSC
- [x] `BIP_PAY_TO` set to Safe
- [x] Relayer skeleton (verify → settle → registerFor + refund flag)
- [ ] Real B402 credentials + authenticated client
- [ ] Persistent ledger + HTTP API
- [ ] Actual refund path
- [ ] Negative tests + remaining audit gates

---

## 6. References

- payTo Safe: `0xFf265912c76342c8469cE18aB9DF0B2f37d9373c`
- USDT: `0x55d398326f99059fF775485246999027B3197955`
- ERC-8004: `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`
- Relayer docs: `docs/RELAYER.md`
