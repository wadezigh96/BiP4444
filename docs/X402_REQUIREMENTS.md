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
| **`payTo` custody** | **Multisig** on BSC (Gnosis Safe or equivalent). Address **TBD** — create & verify before mainnet; never an EOA hot wallet for production receipts. |
| **Register path** | **A — Backend relayer** after successful settle |
| **Identity** | ERC-8004 `agentId` + live `ownerOf(agentId)` check |
| **Role** | Client supplies a **role** string at registration (stored off-chain + echoed in membership record; on-chain optional later) |
| **Refund if settle OK but register fails** | **Yes** — see §7 |

Still open: exact B402 API base URL + credentials (ops); **multisig address + signer set + threshold**; whether `role` is written on-chain in a later contract revision.

### payTo multisig requirements

- Deployed on **BSC mainnet** (chain ID 56).
- Receives x402 membership payments (5 USDT).
- **Not** the same key as the relayer (path A).
- Signers and threshold documented in ops runbook before go-live.
- Refunds (§7) may use a separate limited hot wallet or the same multisig with dual-control policy — document which in runbook.
- Address is fixed in BIP server config and embedded in every `PAYMENT-REQUIRED`; clients cannot override `payTo`.

---

## 1. Goal

Use **x402 (v2)** + **B402** so an agent operator can pay **5 USDT** for **BIP membership** bound to an ERC-8004 identity and a declared **role**, without BIP holding private keys.

**Hard rule:** Membership is granted only after:

1. Payment payload matches server-issued requirements, and  
2. B402 **verify** + **settle** succeed for that unique payment, and  
3. Relayer successfully completes registration for that `agentId` (or refund path runs).

---

## 2. Protocol flow (locked: B402 + path A)

```
Client                         BIP API                      B402                    BSC
  |  POST /v1/membership/register                           |                       |
  |  { agentId, role } (no payment)                         |                       |
  |--------------------------->|                            |                       |
  |  402 + PAYMENT-REQUIRED    |                            |                       |
  |  (5 USDT → multisig payTo, |                            |                       |
  |   eip155:56, agentId bound)|                            |                       |
  |<---------------------------|                            |                       |
  |  sign Permit2/EIP-712      |                            |                       |
  |  POST + PAYMENT-SIGNATURE  |                            |                       |
  |--------------------------->|                            |                       |
  |                            |  verify                    |                       |
  |                            |--------------------------->|                       |
  |                            |  settle                    |                       |
  |                            |--------------------------->|                       |
  |                            |                            |  USDT → multisig      |
  |                            |                            |---------------------->|
  |                            |  success + txHash          |                       |
  |                            |<---------------------------|                       |
  |                            |  relayer: register(agentId)|                       |
  |                            |----------------------------|---------------------->|
  |  200 { membership, role,   |                            |                       |
  |       identity, payment }  |                            |                       |
  |<---------------------------|                            |                       |
```

### HTTP headers (x402 v2)

| Header | Direction | Role |
|--------|-----------|------|
| `PAYMENT-REQUIRED` | Server → Client | Base64 `PaymentRequired` |
| `PAYMENT-SIGNATURE` | Client → Server | Base64 `PaymentPayload` |
| `PAYMENT-RESPONSE` | Server → Client | Base64 settlement outcome |

---

## 3. Registration resource (identity + role)

### Request (before or with payment)

```json
{
  "agentId": "1001",
  "role": "operator"
}
```

| Field | Rules |
|-------|--------|
| `agentId` | Required. Must exist on ERC-8004 Identity Registry proxy `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`. |
| `role` | Required. Non-empty string; max length **64**; charset `[a-zA-Z0-9_-]` recommended; examples: `operator`, `analyst`, `guardian`, `builder`. Stored in payment/membership ledger. Not a privilege escalation flag on-chain in v1. |

### What 402 must bind

- `network`: `eip155:56`
- `scheme`: `exact`
- `asset`: USDT `0x55d398326f99059fF775485246999027B3197955`
- `amount`: `5000000000000000000`
- `payTo`: **BIP multisig** (configured address)
- Resource metadata: `agentId`, `role`, unique `paymentId` / nonce, expiry

### Success response (illustrative)

```json
{
  "membershipId": "1",
  "agentId": "1001",
  "role": "operator",
  "identity": {
    "registry": "0x8004A169FB4a3325136EB29fA0ceB6D2e539a432",
    "owner": "0x..."
  },
  "payment": {
    "asset": "USDT",
    "amount": "5",
    "payTo": "0x_MULTISIG_TBD",
    "txHash": "0x...",
    "facilitator": "B402"
  },
  "status": "active"
}
```

---

## 4. B402 facilitator

| Item | Value |
|------|--------|
| Facilitator | **B402** |
| Network | `eip155:56` |
| Ops | Call **only from BIP trusted backend**; API secrets in env/secret manager |
| Endpoints | Discover via B402 docs: `supported` / `verify` / `settle` (v2 preferred) |
| Settlement | Idempotent settle; gas sponsored by facilitator |
| Auth method | Prefer path returned by `/supported` for USDT (typically **Permit2** on BSC) |

Config keys (illustrative): `B402_BASE_URL`, `B402_API_KEY`, `BIP_PAY_TO=<multisig>`, `MEMBERSHIP_PRICE_ATOMIC=5000000000000000000`, `MEMBERSHIP_ASSET=0x55d398...`.

Always refresh supported methods from B402 in production rather than assuming a fixed EIP-712 domain forever.

---

## 5. Path A — Backend relayer (locked)

After B402 settle success:

1. Persist ledger row: `paymentId`, `agentId`, `role`, `payer`, `txHash`, `status=settled`.
2. Load ERC-8004 `ownerOf(agentId)`.
3. Policy check (v1): recommended **payer must be current agent owner**; registration only for bound `agentId`.
4. Relayer wallet (dedicated key, **not** a multisig signer required for routine register) submits on-chain registration.
   - Target: `registerFor(uint256 agentId)` with `RELAYER_ROLE` — **audit before deploy**.
5. On success: `status=registered`, return 200.
6. On failure: **refund procedure** (§7).

Key separation:

| Key / address | Role |
|---------------|------|
| Multisig `payTo` | Receive 5 USDT membership fees |
| Relayer EOA/KMS | Gas + `registerFor` only |
| B402 API secret | Backend only |

---

## 6. Server-side rules

### Before 402

- Validate `agentId` + `role`.
- Optional: reject if already active member.
- **Pre-check** `activeMemberCount < 4444`.
- Issue requirements with fixed 5 USDT and **multisig payTo**.

### On PAYMENT-SIGNATURE

1. Schema-validate x402 v2 payload.  
2. Match network, asset, amount, payTo, scheme to **server-issued** requirements.  
3. B402 verify → settle.  
4. Ledger write.  
5. Relayer register.  
6. Respond with membership + identity owner + role + payment.

### Idempotency

- One `paymentId` → one settle effect → one membership grant.  
- Replay returns prior result.  
- Payment for agentId A never registers B.

---

## 7. Refund policy (locked: Yes)

If **USDT settle succeeds** but **membership registration cannot complete**, BIP **must** refund **5 USDT** to the **payer** from the settlement record.

### Triggers

- Cap race, register revert, invalid agent mid-flight, relayer outage past SLA

### Procedure

1. `status=refund_pending` + reason.  
2. Refund from policy-approved wallet (limited hot wallet **or** multisig outbound).  
3. `status=refunded` + refund `txHash`.  
4. Alert ops.

### Non-refund

- Never settled; user error before settle; membership already active

---

## 8. Required negative tests

| # | Case | Expected |
|---|------|----------|
| 1–12 | See prior suite (expiry, wrong chain/asset/amount/payTo, replay, cap, etc.) | Reject / no membership |
| 13 | Missing/invalid `role` | 400 before 402 |
| 14 | Settle OK, register fails | Refund 5 USDT |
| 15 | Client-supplied payTo ≠ multisig | Reject |

---

## 9. Privacy & security

- No seed phrases / private keys from operators.  
- Multisig, relayer, and B402 secrets separated.  
- Rate-limit register and 402 issuance.  
- Official domain only in payment UX.

---

## 10. Implementation checklist

- [ ] Deploy/configure **BSC multisig** → set `BIP_PAY_TO`  
- [ ] B402 adapter + credentials  
- [ ] `POST /v1/membership/register` (`agentId` + `role`)  
- [ ] Payment ledger  
- [ ] Relayer + `registerFor` (audited)  
- [ ] Refund worker + runbook  
- [ ] Negative tests  
- [ ] Testnet QA only on `eip155:97` with test payTo  

---

## 11. References

- B402 / Binance x402 on BSC  
- USDT BSC: `0x55d398326f99059fF775485246999027B3197955`  
- ERC-8004 Identity: `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`  
- `docs/MEMBERSHIP_CONTROLLER.md`, `docs/SECURITY.md`, `docs/AUDIT_GATES.md`  

**Security-first:** design locked including multisig payTo; no mainnet payments until address is set, implementation tested, and audit gates pass.
