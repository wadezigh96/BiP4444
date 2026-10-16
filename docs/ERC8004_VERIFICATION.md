# ERC-8004 Verification on BNB Smart Chain

**Status:** Live verification completed (2026-10-16)  
**Network:** BNB Smart Chain mainnet (chain ID 56)

## CREATE2 proxy addresses (use these in BIP4444)

| Contract | Address |
|----------|---------|
| Identity Registry | `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432` |
| Reputation Registry | `0x8004BAa17C55a88189AE136b182e5fdA19dE9b63` |

## On-chain findings (block ~127880257)

| Item | Result |
|------|--------|
| Code at Identity proxy | Yes (130-byte EIP-1967-style proxy) |
| Identity implementation | `0x7274e874ca62410a93bd8bf61c69d8045e399c02` (~14.5 KB) |
| Reputation implementation | `0x16e0fa7f7c56b9a767e34b192b51f921be31da34` (~10.5 KB) |
| `name()` / `symbol()` | `AgentIdentity` / `AGENT` |
| `supportsInterface(ERC-721)` | `true` |
| `ownerOf(agentId)` | Works for sampled IDs (1, 100, 1000, 2106, 10000) |

Full evidence: **[docs/evidence/ERC8004_BSC_2026-10-16.md](evidence/ERC8004_BSC_2026-10-16.md)**

## Integration rules for BIP4444

- BIP membership **references** the ERC-8004 `agentId`; it does not mint a second identity NFT.
- Pass **proxy** address `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432` into `BIPMembershipController` constructor.
- Membership controller must treat current `ownerOf(agentId)` as authoritative (subject to final transfer policy).
- Do not assume ERC-8004 enforces the 4,444 BIP member limit.
- Upstream registries are **upgradeable proxies** — note as external dependency risk in security review.

## Local script

```bash
npm install ethers
node scripts/verify-erc8004-bsc.js
```

## References

- https://github.com/erc-8004/erc-8004-contracts  
- https://bscscan.com/address/0x8004A169FB4a3325136EB29fA0ceB6D2e539a432
