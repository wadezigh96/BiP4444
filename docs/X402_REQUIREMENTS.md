# BIP4444 x402 Payment Safety Requirements

**Status:** Planning / pre-implementation  
**Last updated:** 2026-10-16  
**Policy:** No production payment flow until every item below is verified and negative tests pass.

## Goal

Use x402 for eligible registration and paid services on BNB Smart Chain (chain ID 56) while ensuring:

- Settlement is actually verified on-chain or via a trusted facilitator.
- Access or membership is never granted merely because a client claims it paid.
- Replay, wrong-chain, wrong-asset, and amount mismatches are rejected.

## Pre-production verification checklist

Before any live payment is enabled:

- [ ] Exact facilitator identity and endpoint documented
- [ ] Supported BSC network and asset confirmed
- [ ] Payment recipient address confirmed
- [ ] Amount and currency confirmed
- [ ] Expiry / validity window defined
- [ ] Settlement result verification method defined (on-chain tx, facilitator callback, etc.)
- [ ] Replay protection mechanism defined (nonce, unique payment ID, etc.)

## Required negative tests

These must exist and pass before production:

| Test case | Expected result |
|-----------|-----------------|
| Expired payment | Rejected |
| Wrong chain ID | Rejected |
| Wrong asset / token | Rejected |
| Wrong recipient | Rejected |
| Wrong amount | Rejected |
| Replayed payment proof | Rejected |
| Duplicate registration attempt with same proof | Rejected |
| Failed or delayed settlement | No membership granted |
| Client claims payment but no valid settlement | Rejected |

## Integration principles

1. Membership controller (or registration endpoint) must receive a verifiable settlement proof, not a client-side assertion.
2. Prefer atomic or tightly coupled “verify then register” flows.
3. Log sufficient data for audit without storing secrets.
4. Rate-limit registration and payment-related endpoints.

## Out of scope for this document

- Exact facilitator choice (to be filled after research).
- Concrete Solidity or backend code (to be written after this checklist is complete).

## Next steps

1. Research and document supported x402 facilitators on BSC.
2. Define the exact proof format expected by the registration flow.
3. Write the negative test suite.
4. Only then implement the payment-gated registration path.
