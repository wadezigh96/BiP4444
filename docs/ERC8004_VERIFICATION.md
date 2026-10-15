# ERC-8004 Verification on BNB Smart Chain

**Status:** Planning  
**Last updated:** 2026-10-16  
**Network:** BNB Smart Chain mainnet (chain ID 56)

## Known CREATE2 addresses (reference)

These addresses are the widely published deterministic deployments used across multiple chains:

| Contract | Address |
|----------|---------|
| Identity Registry | `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432` |
| Reputation Registry | `0x8004BAa17C55a88189AE136b182e5fdA19dE9b63` |

> **Action required:** Before any production use, verify on BSC:
> 1. Contract code exists at the address.
> 2. Bytecode matches the expected reference implementation.
> 3. Relevant events (`Registered`, ownership, etc.) behave as documented.
> 4. `ownerOf(agentId)` and other view functions used by BIP4444 return correct results.

## Verification steps (to be performed and recorded)

- [ ] Confirm contract code at Identity Registry address on BSCScan / RPC.
- [ ] Compare deployed bytecode (or creation code) with the official reference.
- [ ] Call `ownerOf` / registration views for known agent IDs.
- [ ] Document the exact ABI subset BIP4444 will depend on.
- [ ] Record block number / timestamp of verification for audit trail.

## Integration rules for BIP4444

- BIP membership **references** the ERC-8004 `agentId`; it does not mint a second identity NFT.
- Membership controller must treat the current `ownerOf(agentId)` as the authoritative controller of that identity (subject to final policy on transfers).
- Do not assume ERC-8004 itself enforces the 4,444 BIP member limit — that limit belongs to the BIP membership controller.

## References (external)

- ERC-8004 identity standard documentation and explorer resources.
- Official registry addresses published by the standard maintainers.

Update this document with the actual verification evidence (tx hashes, bytecode hashes, screenshots, or scripts) before marking the corresponding audit gate complete.
