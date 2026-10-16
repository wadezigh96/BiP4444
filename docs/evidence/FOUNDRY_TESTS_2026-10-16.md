# Foundry test evidence — 2026-10-16

**Gate:** Membership-cap and duplicate-registration tests  
**Status:** Unit tests passing (local). Gate not fully closed until CI or second-pair confirmation if required.

## Environment

- Platform: Termux (Android / ARM64)
- Solidity compiler used: `0.8.35+commit.47b9dedd.Android.clang` (Termux system solc; foundry.toml requested 0.8.24 but prebuilt binaries unavailable on Termux)
- forge-std: v1.17.0 (`f3dae6e6ee381f25eb6a246f7da9b85c91a68219`)
- Contract under test: `contracts/src/BIPMembershipController.sol` (skeleton)

## Commands

```bash
forge test -vv
forge test --match-test test_Cap_ReachedAt4444 -vv
```

## Results

**Full suite:** `22 passed; 0 failed; 0 skipped`

```
Ran 22 tests for test/BIPMembershipController.t.sol:BIPMembershipControllerTest
[PASS] testFuzz_Register_OnlyAgentOwner(address,uint256) (runs: 256, μ: 41794, ~: 42773)
[PASS] test_Cap_ReachedAt4444() (gas: 322760413)
[PASS] test_Cap_RevokeFreesSlot() (gas: 110534)
[PASS] test_ConstructorRevertsOnZeroRegistry() (gas: 58316)
[PASS] test_ConstructorSetsOwnerAndRegistry() (gas: 15842)
[PASS] test_MaxMembersIs4444() (gas: 5612)
[PASS] test_Pause_OnlyOwner() (gas: 25477)
[PASS] test_Pause_RevertsIfAlreadyPaused() (gas: 18943)
[PASS] test_Register_MultipleDistinctAgents() (gas: 151825)
[PASS] test_Register_RevertsOnDuplicate() (gas: 95172)
[PASS] test_Register_RevertsOnZeroAgentId() (gas: 13146)
[PASS] test_Register_RevertsWhenAgentDoesNotExist() (gas: 18317)
[PASS] test_Register_RevertsWhenNotAgentOwner() (gas: 18671)
[PASS] test_Register_RevertsWhenPaused() (gas: 20778)
[PASS] test_Register_Success() (gas: 98473)
[PASS] test_Revoke_OnlyOwner() (gas: 84629)
[PASS] test_Revoke_RevertsIfNotMember() (gas: 15439)
[PASS] test_Revoke_RevertsWhenPaused() (gas: 101634)
[PASS] test_TransferOwnership() (gas: 22629)
[PASS] test_TransferOwnership_RevertsOnZero() (gas: 13298)
[PASS] test_Unpause_OnlyOwner() (gas: 23352)
[PASS] test_Unpause_RevertsIfNotPaused() (gas: 13244)
Suite result: ok. 22 passed; 0 failed; 0 skipped
```

**Cap-only run:**

```
[PASS] test_Cap_ReachedAt4444() (gas: 322760413)
Suite result: ok. 1 passed; 0 failed; 0 skipped
```

## What this proves (on-chain logic of the skeleton)

| Invariant / behaviour | Covered by |
|----------------------|------------|
| `MAX_MEMBERS == 4444` | `test_MaxMembersIs4444` |
| Cannot register 4445th active member | `test_Cap_ReachedAt4444` |
| Duplicate active registration rejected | `test_Register_RevertsOnDuplicate` |
| Only ERC-8004 `ownerOf(agentId)` may register | `test_Register_RevertsWhenNotAgentOwner`, fuzz |
| Zero agentId rejected | `test_Register_RevertsOnZeroAgentId` |
| Pause blocks register/revoke | related pause tests |
| Admin-only revoke / pause / ownership | revoke & pause & transfer tests |
| Revoke frees a slot (current policy) | `test_Cap_RevokeFreesSlot` |

## Remaining for full gate closure

- [ ] Optional: run same suite in CI (Linux) with solc 0.8.24 for cross-check
- [ ] Resolve open policy questions in `docs/MEMBERSHIP_CONTROLLER.md` before treating contract as final
- [ ] Integration tests against real BSC ERC-8004 (fork) still optional for this gate

## Security note

These tests validate the **skeleton** membership controller only. They do not authorize mainnet deployment. All release gates in `docs/AUDIT_GATES.md` remain in force.
