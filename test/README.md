# BIP4444 Foundry tests

## Prerequisites

```bash
# Install Foundry if needed
curl -L https://foundry.paradigm.xyz | bash
foundryup

# From repo root — install forge-std
forge install foundry-rs/forge-std --no-commit
```

## Run tests

```bash
# All tests
forge test -vvv

# Cap test only (slower — registers 4444 members)
forge test --match-test test_Cap_ReachedAt4444 -vv

# Fuzz
forge test --match-test testFuzz -vv

# Stateful invariants
forge test --match-contract BIPMembershipInvariantTest -vvv

# Read-only ERC-8004 fork smoke test (set BSC_RPC_URL in your local shell first)
BSC_RPC_URL="$BSC_RPC_URL" forge test --match-contract BIPMembershipForkTest -vvv

# Gas report
forge test --gas-report
```

## Coverage focus (audit gate)

| Test | What it proves |
|------|----------------|
| `test_MaxMembersIs4444` | Constant is 4444 |
| `test_Cap_ReachedAt4444` | 4445th registration reverts with `CapReached` |
| `test_RegisterFor_RevertsOnDuplicateActiveMembership` | Same agentId cannot have two active memberships |
| `test_RegisterFor_RevertsWhenSignatureIsNotFromIdentityOwner` | Current ERC-8004 owner must sign authorization |
| `test_RevokeSelf_OnlyCurrentIdentityOwnerCanRevoke` | Membership follows agentId; former owner cannot revoke |
| `test_RevokeSelf_IsAllowedWhilePaused` / `test_AdminRevoke_IsAllowedWhilePaused` | Both approved revocation paths work during pause |
| `test_ReactivationRequiresFreshPaymentAndGetsNewMembershipId` | Reactivation requires a fresh payment hash and receives a new ID |
| `BIPMembershipInvariantTest` | Active count stays under 4,444 and matches membership flags |
| `BIPMembershipForkTest` | Read-only ownerOf probe against the live ERC-8004 registry when BSC_RPC_URL is set |
| Pause / revoke / ownership tests | Access control skeleton behaviour |

## Notes

- Uses `MockERC8004Identity` — no mainnet RPC required for unit tests.
- `test_Cap_ReachedAt4444` loops 4444 times; expect higher runtime.
- The fork smoke test deliberately emits a skip event and returns if BSC_RPC_URL is unset. A CI pass without that environment variable is not evidence that the live-registry fork test ran. Record a separate run with BSC_RPC_URL configured before closing that gate.
