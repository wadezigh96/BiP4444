# BIP4444 Membership Controller Specification

**Status:** Pre-audit implementation; not production-ready  
**Last updated:** 2026-10-17  
**Related:** ERC-8004 Identity Registry on BSC; x402 payment design

## Goal

Provide an on-chain membership layer that:

- References existing ERC-8004 agent identities (no second NFT).
- Enforces a hard cap of **4,444** unique active BIP memberships.
- Prevents duplicate membership for the same agent identity.
- Makes membership status changes explicit and auditable.
- Handles ownership changes of the underlying ERC-8004 agent.
- Protects administrator functions and defines an emergency procedure.
- Supports **payment-gated registration** via backend relayer after B402 settle (path A).

## Locked related product decisions

See `docs/X402_REQUIREMENTS.md` §0:

- Price: **5 USDT** via **B402**
- Register path: **A (backend relayer)** after settle
- Off-chain **role** string at registration (identity = ERC-8004 `agentId`)
- Refund if settle succeeds but register fails

## Key design decisions

| Decision | Current proposal | Notes |
|----------|------------------|-------|
| Membership token | None (registry only) | No extra NFT |
| Cap | 4,444 active | Hard on-chain limit |
| Duplicate | One membership per agentId | Mapping `agentId → membership` |
| Revocation | Admin (skeleton) | Final policy still open |
| Transfer of membership | Not independently transferable | Follows ERC-8004 identity |
| Role | Off-chain ledger in v1 | Optional on-chain field later |
| Relayer register | `registerFor` with EIP-712 owner consent + relayer allowlist | Implemented in the pre-audit branch; CI and independent review still required |
| Admin model | Multisig / role-based | Emergency pause recommended |

## Required on-chain invariants

1. `activeMemberCount <= 4444` at all times.
2. No two active memberships share the same ERC-8004 `agentId`.
3. Membership status changes emit clear events.
4. Registration path must not bypass payment policy off-chain (relayer only after ledger settle).
5. Administrator actions are restricted and logged.

## Interface evolution (path A)

The prior public `register(agentId)` method has been removed because it allowed free registration and bypassed the required 5 USDT payment gate. Registration is now only through `registerFor(agentId, paymentIdHash, roleHash, deadline, ownerSignature)`.

- `registerFor` is relayer-allowlisted and requires a valid EIP-712 signature from the current ERC-8004 owner.
- The typed authorization binds `agentId`, a server-generated payment-operation hash, canonical role hash, per-owner nonce, deadline, chain ID, and controller address.
- Signatures expire and may be valid for at most 24 hours; payment hashes cannot be consumed twice, including after revocation.
- Enforces pause, active membership cap, and duplicate-active-member checks.
- Emits `MembershipRegistered` with the relayer as operator and stores the identity owner as `registeredBy`.
- **Payment is not verified on-chain.** The backend must verify B402 settlement, bind it to the signed operation, use a durable ledger/idempotency constraints, and reconcile refunds. A compromised relayer can still lie about settlement; this remains a critical trust boundary.
- Admin ownership transfer now uses a two-step pending-owner acceptance pattern. Production admin and relayer key custody still require independent review.

This is a pre-audit implementation; successful CI is required before treating the code as test-verified.

## Open questions (remaining)

1. Can membership be revoked by the member, by admin only, or both?
2. What happens when the ERC-8004 agent ownership changes after registration?
3. Is reactivation after revocation allowed?
4. Exact admin / relayer multisig model?
5. Should `role` move on-chain in v2?

## Testing requirements

- Cap exactly at 4,444 (Foundry evidence recorded).
- Duplicate agentId rejected.
- Owner-only register (current skeleton) + future relayer-only `registerFor`.
- Pause / revoke behaviour.
- Combined x402 negative tests in `docs/X402_REQUIREMENTS.md`.
