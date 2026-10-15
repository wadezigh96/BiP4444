# BIP4444 Membership Controller Specification

**Status:** Design / pre-implementation  
**Last updated:** 2026-10-16  
**Related:** ERC-8004 Identity Registry on BSC

## Goal

Provide an on-chain membership layer that:

- References existing ERC-8004 agent identities (no second NFT).
- Enforces a hard cap of **4,444** unique active BIP memberships.
- Prevents duplicate membership for the same agent identity.
- Makes membership status changes explicit and auditable.
- Handles ownership changes of the underlying ERC-8004 agent.
- Protects administrator functions and defines an emergency procedure.

## Key design decisions (to be locked before coding)

| Decision | Current proposal | Notes |
|----------|------------------|-------|
| Membership token | None (registry only) | No extra NFT |
| Cap | 4,444 active | Hard on-chain limit |
| Duplicate | One membership per agentId | Mapping `agentId → membership` |
| Revocation | Supported (admin or self?) | Must be decided |
| Transfer of membership | Not transferable independently | Follows ERC-8004 owner |
| Reactivation after revoke | TBD | Explicit policy required |
| Admin model | Multisig / role-based | Emergency pause recommended |

## Required on-chain invariants

1. `activeMemberCount <= 4444` at all times.
2. No two active memberships share the same ERC-8004 `agentId`.
3. Membership status changes emit clear events.
4. Only the current ERC-8004 owner (or authorized controller) can register / manage the linked membership, subject to final policy.
5. Administrator actions are restricted and logged.

## Suggested interface (Solidity sketch)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC8004Identity {
    function ownerOf(uint256 agentId) external view returns (address);
    // other relevant view functions as needed
}

interface IBIPMembershipController {
    // Views
    function MAX_MEMBERS() external pure returns (uint256); // 4444
    function activeMemberCount() external view returns (uint256);
    function isMember(uint256 agentId) external view returns (bool);
    function membershipOf(uint256 agentId) external view returns (
        uint256 membershipId,
        address registeredBy,
        uint64 registeredAt,
        bool active
    );

    // Registration (payment verification may be off-chain or via separate module)
    function register(uint256 agentId) external;
    // or registerWithPaymentProof(...) depending on x402 design

    // Status management
    function revoke(uint256 agentId) external;          // policy-dependent
    function pause() external;                          // emergency
    function unpause() external;

    // Events
    event MembershipRegistered(uint256 indexed agentId, uint256 indexed membershipId, address indexed registrant);
    event MembershipRevoked(uint256 indexed agentId, uint256 indexed membershipId, address indexed by);
    event Paused(address account);
    event Unpaused(address account);
}
```

## Implementation notes

- Store a mapping `uint256 agentId → MembershipData`.
- Maintain a counter of active members; increment/decrement only on status change.
- On registration: check `ownerOf(agentId) == msg.sender` (or approved operator), check not already member, check `activeMemberCount < 4444`.
- Consider whether membership should automatically become inactive if the ERC-8004 agent is transferred (or require re-attestation).
- Do **not** rely on frontend or off-chain counters for the cap.

## Open questions (must resolve before implementation)

1. Can membership be revoked by the member, by admin only, or both?
2. What happens when the ERC-8004 agent ownership changes?
3. Is reactivation after revocation allowed? Under what conditions?
4. Exact admin model (EOA, multisig, roles, time-lock)?
5. How does x402 payment proof feed into `register`?

## Testing requirements (must pass before mainnet)

- Cap exactly at 4,444 (cannot register 4,445th).
- Duplicate agentId rejected.
- Only legitimate ERC-8004 owner can register (negative cases).
- Revoke / pause behavior.
- Ownership change edge cases.
- Event emission and storage layout review.
