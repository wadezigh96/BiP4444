# ERC-8004 Verification on BNB Smart Chain

**Status:** In progress  
**Last updated:** 2026-10-16  
**Network:** BNB Smart Chain mainnet (chain ID 56)

## Known CREATE2 addresses (reference)

| Contract | Address |
|----------|---------|
| Identity Registry | `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432` |
| Reputation Registry | `0x8004BAa17C55a88189AE136b182e5fdA19dE9b63` |

These are the widely published deterministic deployments used across multiple mainnets (including BSC).

## Verification steps

- [x] Document official addresses and sources  
- [x] Add verification helper script (`scripts/verify-erc8004-bsc.js`)  
- [x] Create evidence stub (`docs/evidence/ERC8004_BSC_2026-10-16.md`)  
- [ ] Run script against live BSC RPC and record full output  
- [ ] Compare deployed bytecode with reference implementation and record hash  
- [ ] Document exact ABI subset used by BIP4444  
- [ ] Record block number / timestamp of final verification

## Integration rules for BIP4444

- BIP membership **references** the ERC-8004 `agentId`; it does not mint a second identity NFT.
- Membership controller must treat the current `ownerOf(agentId)` as the authoritative controller of that identity (subject to final policy on transfers).
- Do not assume ERC-8004 itself enforces the 4,444 BIP member limit — that limit belongs to the BIP membership controller.

## How to run verification

```bash
npm install ethers
node scripts/verify-erc8004-bsc.js
```

Paste the console output into `docs/evidence/` when the run is complete.

## References

- https://github.com/erc-8004/erc-8004-contracts  
- https://erc-8004.quicknode.com/docs/contracts  
- https://bscscan.com/address/0x8004A169FB4a3325136EB29fA0ceB6D2e539a432
