# BIP4444 Membership Controller Specification

**Status:** Skeleton + Path A relayer support (pre-audit)  
**Last updated:** 2026-10-21  
**Related:** ERC-8004 Identity Registry on BSC; x402 payment design

## Goal

Provide an on-chain membership layer that:

- References existing ERC-8004 agent identities (no second NFT).
- Enforces a hard cap of **4,444** unique active BIP memberships.
- Prevents duplicate membership for the same agent identity.
- Makes membership status changes explicit and auditable.
- Handles ownership changes of the underlying ERC-8004 agent (open question).
- Protects administrator functions and defines an emergency procedure.
- Supports **payment-gated registration** via backend relayer after B402 settle (path A).

## Current implementation status

| Feature | Status |
|---------|--------|
| Cap 4,444 + uniqueness | Implemented + unit tested |
| `register(agentId)` by ERC-8004 owner | Implemented |
| `registerFor(agentId)` by relayer (Path A) | **Implemented** (this update) |
| `setRelayer` | Implemented |
| On-chain payment verification | Not implemented (by design in v1) |
| Multisig / AccessControl | Not yet (simple owner) |
| Ownership change handling | Open question |

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
| Relayer register | `registerFor` + single relayer address | Implemented; set via `setRelayer` |
| Admin model | Simple owner (placeholder) | Emergency pause exists; replace with multisig later |

## Required on-chain invariants

1. `activeMemberCount <= 4444` at all times.
2. No two active memberships share the same ERC-8004 `agentId`.
3. Membership status changes emit clear events.
4. Registration path must not bypass payment policy off-chain (relayer only after ledger settle).
5. Administrator actions are restricted and logged.

## Interface (current)

```solidity
function register(uint256 agentId) external;
function registerFor(uint256 agentId) external; // onlyRelayer
function setRelayer(address newRelayer) external; // onlyOwner
```

- `registerFor` still requires agent to exist (`ownerOf` does not revert).
- Still enforces cap + no duplicate active membership.
- Emits `MembershipRegistered` with **relayer** as registrant.
- Stores `registeredBy` = current ERC-8004 owner (for auditability).
- **Payment is not verified on-chain** — trust reduced by: relayer key hygiene, ledger audit, refund policy, rate limits.

## Open questions (remaining)

1. Can membership be revoked by the member, by admin only, or both?
2. What happens when the ERC-8004 agent ownership changes after registration?
3. Is reactivation after revocation allowed? (currently yes)
4. Exact admin / relayer multisig model? (currently single owner + single relayer)
5. Should `role` move on-chain in v2?

## Testing requirements

- Cap exactly at 4,444 (Foundry evidence recorded).
- Duplicate agentId rejected.
- Owner-only `register` + relayer-only `registerFor`.
- Pause / revoke behaviour.
- Combined x402 negative tests in `docs/X402_REQUIREMENTS.md` (still pending implementation).

---

**Security-first:** This contract remains a pre-audit artifact. Do not deploy to mainnet or enable production payments until remaining gates pass.
