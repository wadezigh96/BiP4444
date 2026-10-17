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

## Approved policy decisions

See `docs/DECISIONS_PHASE_0_2026-10-17.md` and `docs/X402_REQUIREMENTS.md`:

- Price: **4 USDT** exact via **B402** (atomic amount `4000000000000000000`)
- Register path: **A (backend relayer)** after verified settlement
- Role remains off-chain in v1; identity is the existing ERC-8004 `agentId`
- Refund the verified payer if settlement succeeds but registration definitively fails
- Admin and current identity owner can revoke, including while paused
- Membership follows `agentId`; reactivation requires a new payment and gets a new membership ID
- Cap is 4,444 active memberships
- Multiple allowlisted relayers; administration should be controlled by the Safe 2-of-2

## Key design decisions

| Decision | Current proposal | Notes |
|----------|------------------|-------|
| Membership token | None (registry only) | No extra NFT |
| Cap | 4,444 active | Hard on-chain limit |
| Duplicate | One membership per agentId | Mapping `agentId → membership` |
| Revocation | Admin + current owner self-revoke | Both available, including while paused |
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

The prior public `register(agentId)` method has been removed because it allowed free registration and bypassed the required 4 USDT payment gate. Registration is now only through `registerFor(agentId, paymentIdHash, roleHash, deadline, ownerSignature)`.

- `registerFor` is relayer-allowlisted and requires a valid EIP-712 signature from the current ERC-8004 owner.
- The typed authorization binds `agentId`, a server-generated payment-operation hash, canonical role hash, per-owner nonce, deadline, chain ID, and controller address.
- Signatures expire and may be valid for at most 24 hours; payment hashes cannot be consumed twice, including after revocation.
- Enforces pause, active membership cap, and duplicate-active-member checks.
- Emits a complete `MembershipRegistered` event containing agent ID, new membership ID, operator, current identity owner, payment-operation hash, and role hash. Revocation events preserve the prior membership ID.
- `revoke(agentId)` is admin-only and remains available while paused. `revokeSelf(agentId)` is available to the current ERC-8004 owner and also remains available while paused.
- Membership status follows the `agentId` across ERC-8004 ownership changes. The new current owner can self-revoke; the previous owner cannot.
- Reactivation requires a new payment-operation hash and owner authorization and receives a new monotonically increasing membership ID. The hard cap counts active memberships only; prior episodes remain auditable through events.
- **Payment is not verified on-chain.** The backend must verify B402 settlement, bind it to the signed operation, use a durable ledger/idempotency constraints, and reconcile refunds. A compromised relayer can still lie about settlement; this remains a critical trust boundary.
- Admin ownership transfer now uses a two-step pending-owner acceptance pattern. Production admin and relayer key custody still require independent review.

This is a pre-audit implementation; successful CI is required before treating the code as test-verified.

## Remaining design questions

1. Should `role` move on-chain in v2? (v1 remains off-chain.)
2. Confirm deployment-specific Safe ownership and relayer key custody before any testnet deployment.

## Testing requirements

- Cap exactly at 4,444 active memberships; reject the 4,445th.
- Duplicate active agentId rejected; reactivation requires a fresh payment hash and receives a new membership ID.
- Relayer-only `registerFor` with current-owner EIP-712 authorization; no free registration selector.
- Admin revoke and owner self-revoke, including while paused.
- Ownership-follow behavior and current-owner-only self-revoke.
- Stateful invariants for count bounds and count/status consistency.
- Fork test against the real ERC-8004 registry using `BSC_RPC_URL`; run only read-only against mainnet.
- Combined x402 negative tests in `docs/X402_REQUIREMENTS.md`.
