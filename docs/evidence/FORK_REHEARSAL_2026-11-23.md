# Evidence — Fork rehearsal against live BSC mainnet state

Run on 2026-11-23 with Foundry 1.10.0, forked from
`https://bsc-dataseed.binance.org` at block ≈ 135,260,683.

## What was rehearsed

`BIPAgentIDGate` was deployed on the fork with the **real** mainnet
addresses — Agent ID `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` and the
ERC-8004 registry `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432` — and the
full user flow was executed against the real Agent ID contract code:

| Step | Result |
|---|---|
| `hasAgentID(forged holder)` (balance written into the real contract's storage on the fork only) | `true` |
| `hasAgentID(non-holder)` | `false` |
| `registerOperator()` from a non-holder | reverts `NoAgentID` |
| `registerOperator()` from the holder | succeeds; Founding seat #1 assigned |
| `grantCapability(...)` + `isAuthorized(...)` | succeeds / `true` |

1 fork test passed. The rehearsal test is intentionally not committed
(it needs network access); the deploy script simulation below covers
the deployment itself.

## Deployment cost (simulated on the same fork)

`forge script scripts/DeployAgentIDGate.s.sol --fork-url <BSC RPC>`
(simulation, no broadcast):

- Estimated total gas: **2,180,575**
- Estimated cost: **≈ 0.000109 BNB**

Two latent script bugs were found and fixed by this rehearsal:
a missing `console` import and an address-checksum error on the
Agent ID constant (now `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`).
