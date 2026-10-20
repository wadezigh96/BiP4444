# Phase 1 Foundry CI Evidence — 2026-10-17

**Repository:** `wadezigh96/BiP4444`  
**Branch:** `audit/relayer-2step-ownership-4usdt`  
**Commit tested:** `728fa07411efb67bce3b6beb2099143a88b63373`  
**GitHub Actions run:** https://github.com/wadezigh96/BiP4444/actions/runs/38986382170  
**CI result:** PASS  
**Compiler:** Solidity `0.8.24`  
**Foundry:** stable toolchain; `forge-std@v1.9.7`

## Test results

- `BIPMembershipControllerTest`: **28 passed, 0 failed**
- `BIPMembershipRelayerTest`: **15 passed, 0 failed**
- `BIPMembershipInvariantTest`: **2 invariants passed**, 256 runs, 128,000 handler calls, 0 reverts
  - Active membership count never exceeds 4,444.
  - Active count matches membership flags for the bounded test-agent set.
- Total Foundry reported tests: **45 passed, 0 failed, 0 skipped**.

Coverage added or confirmed in this phase:
- Admin and current-owner self-revocation, including while paused.
- Former ERC-8004 owner cannot self-revoke after ownership changes.
- Membership follows the agentId when its owner changes.
- Reactivation uses a fresh payment hash and a new membership ID.
- Complete registration event includes operator, identity owner, payment hash, and role hash.
- EIP-712 owner consent, replay protection, signature deadline and relayer access tests.
- Hard active-member cap and duplicate active membership protections.

## Important fork-test limitation

The function `testFork_ERC8004RegistryOwnerOfIsReadable` is included in the test run, but CI did not have `BSC_RPC_URL` configured. The function therefore emitted its skip event and returned; this is **not evidence of a successful live-registry fork test**. Run it locally with a read-only RPC endpoint before closing the fork gate:

```bash
export BSC_RPC_URL="YOUR_READ_ONLY_BSC_RPC_URL"
forge test --match-contract BIPMembershipForkTest -vvv
```

Do not paste the RPC URL into chat if it contains a credential. Do not provide a private key. The test only forks and reads the existing ERC-8004 registry; it does not deploy or broadcast transactions.

## Limits

This passing suite does not verify B402 settlement, payer-to-agent ownership binding in the backend, persistent payment ledger, idempotency/refund processing, relayer key custody, Alert Shield, or frontend security. It is not an independent audit and does not authorize any mainnet action.
