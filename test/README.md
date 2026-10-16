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
forge test -vv

# Cap test only (slower — registers 4444 members)
forge test --match-test test_Cap_ReachedAt4444 -vv

# Fuzz
forge test --match-test testFuzz -vv

# Gas report
forge test --gas-report
```

## Coverage focus (audit gate)

| Test | What it proves |
|------|----------------|
| `test_MaxMembersIs4444` | Constant is 4444 |
| `test_Cap_ReachedAt4444` | 4445th registration reverts with `CapReached` |
| `test_Register_RevertsOnDuplicate` | Same agentId cannot register twice while active |
| `test_Register_RevertsWhenNotAgentOwner` | Only ERC-8004 owner can register |
| `test_Cap_RevokeFreesSlot` | Revoke decreases active count; re-register allowed (current policy) |
| Pause / revoke / ownership tests | Access control skeleton behaviour |

## Notes

- Uses `MockERC8004Identity` — no mainnet RPC required for unit tests.
- `test_Cap_ReachedAt4444` loops 4444 times; expect higher runtime.
- These tests support the **Membership-cap and duplicate-registration** audit gate; they do not by themselves close the gate until CI/evidence is recorded.
