# BIP4444 x402 Payment Design (BSC)

**Status:** Design / pre-implementation  
**Last updated:** 2026-10-16  
**Network:** BNB Smart Chain mainnet — CAIP-2 `eip155:56`  
**Policy:** No production payment flow and no membership grant until verify + settle succeed and negative tests pass.

---

## 1. Goal

Use **x402 (v2)** so an agent (or operator) can pay for **BIP membership registration** (and later paid services) over HTTP, with settlement on BSC, without BIP4444 holding user private keys.

**Hard rule:** Membership must **not** be granted because a client *claims* it paid. Only after the BIP backend has:

1. Validated the payment payload against published requirements, and  
2. Received a successful **facilitator settle** result (or equivalent on-chain confirmation tied to that unique payment),

may `BIPMembershipController.register` (or an authorized relayer path) run.

---

## 2. Protocol flow (x402 v2)

```
Client (agent/wallet)          BIP API (merchant)           Facilitator              BSC
        |                              |                          |                    |
        | 1. POST /register (no pay)   |                          |                    |
        |----------------------------->|                          |                    |
        | 2. 402 + PAYMENT-REQUIRED    |                          |                    |
        |<-----------------------------|                          |                    |
        | 3. Sign EIP-712 auth         |                          |                    |
        |    (Permit2 / EIP-3009)      |                          |                    |
        | 4. POST /register            |                          |                    |
        |    + PAYMENT-SIGNATURE       |                          |                    |
        |----------------------------->|                          |                    |
        |                              | 5. POST /verify          |                    |
        |                              |------------------------->|                    |
        |                              | 6. valid / invalid       |                    |
        |                              |<-------------------------|                    |
        |                              | 7. POST /settle          |                    |
        |                              |------------------------->|                    |
        |                              |                          | 8. submit tx       |
        |                              |                          |------------------->|
        |                              | 9. success + tx hash     |                    |
        |                              |<-------------------------|                    |
        |                              | 10. register(agentId)    |                    |
        |                              |     on-chain (or issue   |                    |
        |                              |     signed permit)       |                    |
        | 11. 200 + membership proof   |                          |                    |
        |<-----------------------------|                          |                    |
```

### HTTP headers (v2)

| Header | Direction | Role |
|--------|-----------|------|
| `PAYMENT-REQUIRED` | Server → Client | Base64 `PaymentRequired` (scheme, network, amount, asset, payTo, timeout, extra) |
| `PAYMENT-SIGNATURE` | Client → Server | Base64 `PaymentPayload` (signed authorization) |
| `PAYMENT-RESPONSE` | Server → Client | Base64 settlement outcome |

Do **not** treat legacy `X-PAYMENT` as authoritative for new BIP endpoints.

---

## 3. What BIP sells (v1 scope)

| Resource | Description | Suggested pricing model |
|----------|-------------|-------------------------|
| `POST /v1/membership/register` | One-time BIP membership for a given ERC-8004 `agentId` (subject to on-chain cap 4,444) | Exact amount, once per agentId |
| Future: Alert Shield premium / API | Optional paid notices | Per-request or subscription (out of v1) |

Registration requirements in the 402 body must bind at least:

- `agentId` (uint / string in resource metadata)
- `network`: `eip155:56`
- `scheme`: `exact` (preferred for membership)
- `asset` + `amount` (atomic units)
- `payTo`: BIP treasury / receiver address (never a user-supplied address)
- `maxTimeoutSeconds`
- Unique payment / resource id for **idempotency and replay protection**

---

## 4. Facilitator options on BSC

BIP4444 should **not** hardcode a single facilitator forever. Config must allow switching after security review.

| Facilitator | Notes | Mainnet posture (as of research 2026-10) |
|-------------|--------|------------------------------------------|
| **B402 (Binance)** | Official Binance x402 stack on BSC; `/supported`, `/verify`, `/settle`; idempotent settle; gas sponsored | Production on `eip155:56`; credentials often required; call **only from trusted backend** |
| **Dexter** | Public endpoint `https://x402.dexter.cash`; network `eip155:56`; Permit2 path; gas sponsored | Claimed production BSC |
| **XPay** | `https://facilitator-xpay.llc/bsc`; USDC Permit2 on BSC | Production path for USDC |
| Self-hosted / other | Full control; higher ops burden | Optional later |

**Recommendation for design phase:**

1. Implement against **x402 v2 message shapes** + a thin `FacilitatorClient` interface (`supported` / `verify` / `settle`).
2. First integration target: **B402** (ecosystem alignment with BSC + Binance Agent OS) *or* Dexter for permissionless testing — **decide before mainnet** and record credentials handling in ops runbook.
3. Always discover live assets/methods via facilitator `supported` (or equivalent); do not hardcode token lists in production binaries without refresh.

### B402-oriented endpoints (illustrative)

| Operation | Typical path | Purpose |
|-----------|--------------|---------|
| Supported | `POST .../supported` | Networks, assets, methods, spender addresses |
| Verify | `POST .../verify` | Validate signature **without** broadcasting |
| Settle | `POST .../settle` | Submit on-chain; idempotent retries |

Secret API keys must live only on the BIP backend (env / secret manager). Never in 402 responses, mobile apps, or agent prompts.

---

## 5. Assets and authorization methods (BSC)

BSC stablecoins are commonly **18 decimals**. Many **lack EIP-3009**, so production paths often use **Permit2**.

| Token | Example contract (BSC) | Decimals | Typical x402 path |
|-------|------------------------|----------|-------------------|
| USDT | `0x55d398326f99059fF775485246999027B3197955` | 18 | Permit2 exact |
| USDC | `0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d` | 18 | Permit2 exact |
| USD1 / U (B402-listed) | See B402 `/supported` | 18 | EIP-3009 and/or Permit2 |

**Canonical Permit2 (BSC):** `0x000000000022D473030F116dDEE9F6B43aC78BA3`  
Payer may need a one-time ERC-20 `approve` to Permit2 before gasless repeats; some facilitators sponsor that approval.

BIP config must pin:

- Accepted `asset` addresses  
- Atomic `amount` for membership  
- `payTo` receiver  
- Allowed `scheme` values (`exact` required for v1 membership)

---

## 6. Server-side rules (BIP merchant)

### 6.1 Before issuing 402

- Resolve `agentId` from the request.
- Check off-chain: not already an active BIP member (optional UX); **on-chain cap remains authoritative**.
- Build `PaymentRequired` with BIP-controlled `payTo`, amount, asset, network `eip155:56`, timeout, and resource id that includes `agentId` + nonce/expiry.

### 6.2 On `PAYMENT-SIGNATURE`

1. Decode and schema-validate payload (x402 v2).
2. Enforce: network, asset, amount, `payTo`, scheme match the **server-issued** requirements (not client-invented).
3. Call facilitator **verify**.
4. On verify success, call facilitator **settle** (or poll idempotent settle until terminal success/failure).
5. Persist settlement record: `paymentId`, `agentId`, `txHash`, `payer`, `amount`, `asset`, timestamp, facilitator id.
6. Only then trigger membership:
   - **Preferred:** backend submits `register(agentId)` via a dedicated relayer key **after** checks, **or**
   - User submits `register` with a short-lived **server-signed registration permit** that the contract checks (design variant — decide before coding).
7. Return 200 + membership status + `PAYMENT-RESPONSE`.

### 6.3 Idempotency & replay

- One successful settlement → at most one membership grant for that payment id.
- Replayed `PAYMENT-SIGNATURE` / same payment id → return previous result; do not double-charge; do not double-register.
- Expired authorization → reject.
- Settled payment for agentId A must not register agentId B.

### 6.4 Failure modes

| Condition | HTTP / behaviour |
|-----------|------------------|
| No / invalid signature | 402 or 400; no register |
| Verify fails | 402/400; no settle |
| Settle fails / pending timeout | 402/503; **no** register; allow safe retry if facilitator idempotent |
| Cap reached on-chain | 409 / 403 after payment? **Prefer** pre-check and avoid taking payment if cap full; if payment already settled, document refund/manual process |
| Already member | 409; do not settle a second time |

**Cap and payment ordering (open decision):** Prefer **check cap before settle** when possible; document residual race if two payments settle near 4444.

---

## 7. Contract interaction options

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **A. Backend relayer** | After settle, BIP server calls `register(agentId)` with a key that is allowed only if payment ledger says OK — *or* server calls only after verifying `msg.sender` is agent owner in a two-step flow | Simple skeleton evolution | Relayer key is sensitive; still need owner binding |
| **B. User registers after receipt** | Settle returns receipt; user (agent owner) calls `register(agentId)` themselves; optional off-chain allowlist | No register key | Race / UX; need on-chain proof of payment or server allowlist |
| **C. Payment-gated register** | Contract verifies a payment attestation (facilitator sig / Merkle / oracle) | Strong binding | More contract complexity; audit surface |

**Design default for skeleton era:** **A or B with explicit payment ledger**, no mainnet until chosen and tested. Option C is post-audit enhancement.

Current skeleton only has `register(agentId)` with ERC-8004 owner check — payment gating is **off-chain** until a permit module is added.

---

## 8. Required negative tests

Must exist and pass before production:

| # | Case | Expected |
|---|------|----------|
| 1 | Expired authorization | Reject; no membership |
| 2 | Wrong chain (`network` ≠ `eip155:56`) | Reject |
| 3 | Wrong asset | Reject |
| 4 | Wrong `payTo` | Reject |
| 5 | Wrong amount (under/over) | Reject |
| 6 | Replayed payment proof / payment id | Reject second settle effect; no double membership |
| 7 | Duplicate registration same agentId | Reject |
| 8 | Verify OK but settle fails | No membership |
| 9 | Client claims paid; no valid settle record | Reject |
| 10 | Signature for agentId X used for agentId Y | Reject |
| 11 | Cap already 4444 | No successful new membership |
| 12 | Facilitator secret missing / wrong | Fail closed |

---

## 9. Privacy & security

- Never request seed phrases or private keys.
- Facilitator secrets and `payTo` hot keys only on server.
- Rate-limit `/register` and 402 issuance.
- Log payment ids and tx hashes; do not log raw secrets or full signed payloads in plaintext longer than needed.
- Phishing: official BIP domain only in any payment UX / QR.

---

## 10. Open decisions (block implementation)

1. **Primary facilitator** for mainnet (B402 vs Dexter vs other) and credential process.  
2. **Membership price** (asset + atomic amount).  
3. **`payTo` address** custody (multisig / treasury).  
4. **Register path** after settle: relayer vs user-submitted vs on-chain attestation (A/B/C above).  
5. **Refund policy** if settle succeeds but `register` fails (cap race, owner change).  
6. Testnet path (`eip155:97`) for QA only — never mix testnet payloads with mainnet keys.

---

## 11. Implementation checklist (when coding starts)

- [ ] `FacilitatorClient` interface + B402 (or chosen) adapter  
- [ ] Config: network, assets, amounts, payTo, timeouts  
- [ ] `POST /v1/membership/register` 402 + signature handling  
- [ ] Payment ledger (DB) with unique constraints  
- [ ] Wire to membership registration policy  
- [ ] Negative test suite (section 8)  
- [ ] Runbook: key rotation, facilitator outage, manual reconcile  

---

## 12. References

- x402 Foundation / v2 HTTP headers (`PAYMENT-REQUIRED`, `PAYMENT-SIGNATURE`, `PAYMENT-RESPONSE`)  
- B402 / Binance Open Platform — BSC facilitator (`eip155:56`)  
- Dexter BSC facilitator — Permit2 exact, gas sponsored  
- Permit2: `0x000000000022D473030F116dDEE9F6B43aC78BA3` on BSC  
- BIP docs: `docs/SECURITY.md`, `docs/MEMBERSHIP_CONTROLLER.md`, `docs/AUDIT_GATES.md`  

**Security-first:** design only. No live payment enablement until this checklist and audit gates pass.
