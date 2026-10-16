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
| **Register path** | **A — Backend relayer** after successful settle |
| **Identity** | ERC-8004 `agentId` + live `ownerOf(agentId)` check |
| **Role** | Client supplies a **role** string at registration (stored off-chain + echoed in membership record; on-chain optional later) |
| **Refund if settle OK but register fails** | **Yes** — see §7 |
| **`payTo`** | BIP treasury address — **TBD before mainnet** (multisig recommended); must be fixed in config, never client-supplied |

Still open: exact B402 API base URL + credentials (ops), treasury multisig address, whether `role` is written on-chain in a later contract revision.

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
  |  (5 USDT, eip155:56,       |                            |                       |
  |   resource binds agentId)  |                            |                       |
  |<---------------------------|                            |                       |
  |  sign Permit2/EIP-712      |                            |                       |
  |  POST + PAYMENT-SIGNATURE  |                            |                       |
  |--------------------------->|                            |                       |
  |                            |  verify                    |                       |
  |                            |--------------------------->|                       |
  |                            |  settle                    |                       |
  |                            |--------------------------->|                       |
  |                            |                            |  transfer USDT        |
  |                            |                            |---------------------->|
  |                            |  success + txHash          |                       |
  |                            |<---------------------------|                       |
  |                            |  relayer: register(agentId)|                       |
  |                            |  (owner checks / policy)   |---------------------->|
  |  200 { membership, role,   |                            |                       |
  |       payment, identity }  |                            |                       |
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
- `payTo`: configured BIP treasury
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

Config keys (names illustrative): `B402_BASE_URL`, `B402_API_KEY`, `BIP_PAY_TO`, `MEMBERSHIP_PRICE_ATOMIC=5000000000000000000`, `MEMBERSHIP_ASSET=0x55d398...`.

Always refresh supported methods from B402 in production rather than assuming a fixed EIP-712 domain forever.

---

## 5. Path A — Backend relayer (locked)

After B402 settle success:

1. Persist ledger row: `paymentId`, `agentId`, `role`, `payer`, `txHash`, `status=settled`.
2. Load ERC-8004 `ownerOf(agentId)`.
3. Policy check (v1):
   - Prefer: payer == agent owner **or** explicit operator allowlist later; **minimum**: registration is for this `agentId` only and agent exists.
   - Document final rule: recommended **payer must be current agent owner** to reduce griefing.
4. Relayer wallet (dedicated key, minimal BNB for gas) submits on-chain membership registration.
   - Skeleton today: only agent owner can `register` — **contract must evolve** to either:
     - `registerFor(agentId, owner)` callable by `RELAYER_ROLE` after off-chain payment proof, **or**
     - temporary off-chain “paid allowlist” + user still calls `register` (not pure A).
   - **Target for path A:** add `registerFor(uint256 agentId)` restricted to relayer role, still verifying `ownerOf` is recorded and events include registrant metadata; **do not deploy** until audited.
5. On success: `status=registered`, return 200.
6. On failure: enter **refund procedure** (§7).

Relayer key: hardware/KMS where possible; no shared use with treasury `payTo`.

---

## 6. Server-side rules

### Before 402

- Validate `agentId` + `role`.
- Optional: reject if already active member.
- **Pre-check** `activeMemberCount < 4444` (best effort); on-chain remains source of truth.
- Issue requirements with fixed 5 USDT and bound `agentId`/`role`.

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

If **USDT settle succeeds** but **membership registration cannot complete**, BIP **must** refund.

### Triggers

- On-chain cap reached (race after pre-check)
- `register` / `registerFor` reverts unexpectedly
- Agent burned / invalid between settle and register
- Relayer outage beyond timeout after settle (ops SLA)

### Procedure

1. Mark ledger `status=refund_pending` with reason code.  
2. **Do not** leave user without either membership or refund.  
3. Refund **5 USDT** to **payer** address from settlement record (not a different address supplied later).  
4. Prefer automated ERC-20 transfer from treasury hot wallet with limits; else manual multisig within published SLA (e.g. 48h).  
5. Mark `status=refunded` + refund `txHash`.  
6. Alert ops.  

### Non-refund cases

- Verify/settle never succeeded  
- User error before settle (wrong signature rejected)  
- Successful membership (no refund)

### Cap race mitigation

- Pre-check count before settle  
- Serialize relayer registrations  
- Refund remaining edge cases per above

---

## 8. Required negative tests

| # | Case | Expected |
|---|------|----------|
| 1 | Expired authorization | Reject; no membership |
| 2 | Wrong network | Reject |
| 3 | Wrong asset (not USDT) | Reject |
| 4 | Wrong payTo | Reject |
| 5 | Amount ≠ 5 USDT atomic | Reject |
| 6 | Replay payment id | No double charge / double membership |
| 7 | Duplicate agentId membership | Reject |
| 8 | Verify OK, settle fails | No membership |
| 9 | Claim paid, no settle record | Reject |
| 10 | Payment bound to agentId X used for Y | Reject |
| 11 | Cap 4444 | No new membership; refund if settled |
| 12 | Missing B402 credentials | Fail closed |
| 13 | Missing/invalid `role` | 400 before 402 |
| 14 | Settle OK, register fails | `refund_pending` → refund 5 USDT |

---

## 9. Privacy & security

- No seed phrases / private keys from operators.  
- B402 secrets + relayer key + treasury controls server-side only.  
- Rate-limit register and 402 issuance.  
- `role` is public metadata, not auth secret.  
- Official domain only in payment UX.

---

## 10. Implementation checklist

- [ ] B402 adapter (`supported` / `verify` / `settle`)  
- [ ] Config: 5 USDT atomic, USDT address, payTo, B402 creds  
- [ ] `POST /v1/membership/register` with `agentId` + `role`  
- [ ] Payment ledger + unique constraints  
- [ ] Relayer path + contract `registerFor` / role (audit before deploy)  
- [ ] Refund worker + runbook  
- [ ] Negative tests §8  
- [ ] Testnet QA on `eip155:97` only with test credentials  

---

## 11. References

- B402 / Binance x402 on BSC  
- USDT BSC: `0x55d398326f99059fF775485246999027B3197955`  
- ERC-8004 Identity proxy: `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`  
- `docs/MEMBERSHIP_CONTROLLER.md`, `docs/SECURITY.md`, `docs/AUDIT_GATES.md`  

**Security-first:** decisions locked for design; no mainnet payments until implementation, tests, and remaining audit gates pass.
