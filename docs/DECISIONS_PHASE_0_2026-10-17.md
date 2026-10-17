# BIP4444 — Phase 0 Policy Decisions

**Date:** 2026-10-17  
**Status:** Approved by project owner in chat  
**Scope:** Contract behavior for Phase 1. These choices do not authorize deployment or production payments.

## Approved decisions

| Topic | Decision | Implementation requirement |
|---|---|---|
| A1 — Revocation authority | Both admin and member | Admin can revoke any active membership; current ERC-8004 owner can self-revoke their own agent membership. |
| A2 — Revoke during pause | Yes | Both admin revoke and current-owner self-revoke remain available while paused. Pause blocks registration, not emergency/voluntary exits. |
| B — ERC-8004 ownership transfer | Membership follows agentId | Membership state stays attached to the agentId; current ownerOf(agentId) is authoritative. New owner can self-revoke; former owner cannot. No automatic re-registration or new payment solely due to transfer. |
| C1 — Reactivation | Allowed with a new payment | A revoked membership cannot be restored for free. A fresh B402 payment, owner authorization, and new operation/payment hash are required. |
| C2 — Membership ID | New ID on reactivation | Membership IDs increase monotonically. The previous registration/revocation remains represented by historical events. |
| C3 — Hard cap | 4,444 active memberships | The on-chain counter limits simultaneous active memberships. Revocation frees a slot; historic registrations do not consume the active cap. |
| D1 — Relayer topology | Multiple allowlisted relayers | Each relayer is individually allowlisted and can be disabled by the contract owner. |
| D2 — Relayer/admin changes | Safe 2-of-2 directly | The contract owner should be the approved Safe. Relayer changes require a Safe-authorized owner call; no timelock in this version. Emergency removal must remain possible. |

## Payment configuration clarified by the project owner

- Network: BSC mainnet, chain ID 56 (production configuration only; no mainnet activity authorized).
- Facilitator: B402, x402 v2.
- Exact price: **4 USDT**.
- Atomic amount: `4000000000000000000` (18 decimals).
- Token: `0x55d398326f99059fF775485246999027B3197955`.
- Fixed recipient: Safe 2-of-2 `0xFf265912c76342c8469cE18aB9DF0B2f37d9373c`.
- Identity: existing ERC-8004 agentId; no second NFT.
- Role remains off-chain for v1.
- Path A: backend verifies B402 settlement before calling the allowlisted relayer. If settlement succeeds but registration definitively fails, refund the verified payer exactly once.

This 4 USDT amount supersedes earlier draft documentation that said 5 USDT. Historical evidence documents are not rewritten to falsify their original timestamps; current specifications must use 4 USDT.

## Security interpretation

1. The contract does not verify B402 settlement on-chain. A compromised or malicious relayer can still attempt to lie about payment; backend settlement verification, durable ledger, Safe governance, and independent review remain release blockers.
2. The EIP-712 authorization is signed by the current ERC-8004 owner and binds agent ID, payment-operation hash, role hash, nonce, deadline, chain ID, and controller address.
3. Membership follows the agent ID, not the historical wallet address. Off-chain services must resolve current ownership when authorizing access.
4. A pause is a registration stop, not a lock-in mechanism: both approved revocation paths remain available.
5. These decisions do not authorize testnet deployment automatically, and never authorize mainnet deployment. Mainnet remains blocked until all gates pass and explicit release approval is given.
