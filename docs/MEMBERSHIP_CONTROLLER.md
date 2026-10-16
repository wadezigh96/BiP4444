# BIP4444 Membership Controller Specification

**Status:** Design / pre-implementation  
**Last updated:** 2026-10-16  
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
| Relayer register | `registerFor` + `RELAYER_ROLE` | Required for path A; not in current skeleton |
| Admin model | Multisig / role-based | Emergency pause recommended |

## Required on-chain invariants

1. `activeMemberCount <= 4444` at all times.
2. No two active memberships share the same ERC-8004 `agentId`.
3. Membership status changes emit clear events.
4. Registration path must not bypass payment policy off-chain (relayer only after ledger settle).
5. Administrator actions are restricted and logged.

## Interface evolution (path A)

Current skeleton: `register(agentId)` only callable by ERC-8004 owner.

**Target addition (before mainnet path A):**

```solidity
function registerFor(uint256 agentId) external onlyRelayer whenNotPaused;
```

- Still requires agent to exist (`ownerOf` does not revert).
- Still enforces cap + no duplicate active membership.
- Emits `MembershipRegistered` with relayer as operator; store `registeredBy` as owner or relayer per final policy.
- **Payment is not verified on-chain in v1** — trust reduced by: relayer key hygiene, ledger audit, refund policy, rate limits.

Optional later: on-chain role `string` or `bytes32` role tag.

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
