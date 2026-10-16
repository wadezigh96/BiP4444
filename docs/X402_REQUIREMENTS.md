# BIP4444 x402 Payment Design (BSC)

**Status:** Design locked (pre-implementation)  
**Last updated:** 2026-10-16  
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
| **`payTo` address** | **`0x6783714167eC1c3519455AfCf2c93f6074624575`** |
| **`payTo` custody target** | **Multisig** (Safe or equivalent). See verification note below. |
| **Register path** | **A — Backend relayer** after successful settle |
| **Identity** | ERC-8004 `agentId` + live `ownerOf(agentId)` check |
| **Role** | Client supplies a **role** string at registration |
| **Refund if settle OK but register fails** | **Yes** — see §7 |

Still open: B402 API credentials (ops); relayer key; whether `role` is on-chain later.

### payTo verification (BSC mainnet, 2026-10-16)

| Check | Result |
|-------|--------|
| Address | `0x6783714167eC1c3519455AfCf2c93f6074624575` |
| Chain ID | 56 |
| Block | ~127882362 |
| Contract code | **None (EOA)** at verification time |
| BNB / USDT balance | 0 / 0 |

**Important:** Policy target remains **multisig**. At lock time this address is an **EOA** (no bytecode). Before accepting real membership payments:

1. Prefer deploying a **Safe (or equivalent multisig)** and updating `BIP_PAY_TO`, **or**
2. If this EOA is intentional interim, document key custody, export risk, and migration plan to multisig.

Do not use the relayer key as `payTo`. Clients never override `payTo`.

Config: `BIP_PAY_TO=0x6783714167eC1c3519455AfCf2c93f6074624575`

---

## 1. Goal

Use **x402 (v2)** + **B402** so an agent operator can pay **5 USDT** for **BIP membership** bound to an ERC-8004 identity and a declared **role**, without BIP holding private keys.

**Hard rule:** Membership is granted only after B402 verify + settle succeed and relayer registration completes (or refund runs).

---

## 2. Protocol flow (B402 + path A)

```
Client → BIP API → 402 (5 USDT → payTo 0x6783…4575)
      → PAYMENT-SIGNATURE → B402 verify/settle → USDT to payTo
      → relayer registerFor(agentId) → 200 membership + role + identity
```

Headers: `PAYMENT-REQUIRED` / `PAYMENT-SIGNATURE` / `PAYMENT-RESPONSE` (x402 v2).

---

## 3. Registration resource (identity + role)

```json
{ "agentId": "1001", "role": "operator" }
```

- `agentId`: ERC-8004 on proxy `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`
- `role`: required, max 64 chars
- 402 binds: network `eip155:56`, USDT, amount `5000000000000000000`, **payTo `0x6783714167eC1c3519455AfCf2c93f6074624575`**

---

## 4. B402 facilitator

Backend-only secrets. Discover `/supported`, then `/verify` + `/settle`. USDT on BSC typically Permit2.

---

## 5. Path A — Backend relayer

After settle → ledger → `registerFor` (future) / policy → success or **refund §7**.

| Address / key | Role |
|---------------|------|
| `0x6783714167eC1c3519455AfCf2c93f6074624575` | Receive 5 USDT (`payTo`) |
| Relayer KMS/EOA | Gas + register only |
| B402 API secret | Backend only |

---

## 6–8. Rules, refund, negative tests

Unchanged in substance: pre-check cap; idempotent paymentId; refund 5 USDT to **payer** if settle OK but register fails; reject wrong payTo / amount / asset / replay.

---

## 9. Implementation checklist

- [x] Set `BIP_PAY_TO` address  
- [ ] Upgrade to multisig **or** document EOA custody  
- [ ] B402 credentials  
- [ ] API register + ledger + relayer + refund  
- [ ] Negative tests + audit gates  

---

## 10. References

- payTo: `0x6783714167eC1c3519455AfCf2c93f6074624575`  
- USDT: `0x55d398326f99059fF775485246999027B3197955`  
- ERC-8004 Identity: `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`  
- Explorer: https://bscscan.com/address/0x6783714167eC1c3519455AfCf2c93f6074624575  

**Security-first:** address locked for config; production receipts should move to multisig when ready.
