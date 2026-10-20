# Foundry CI Evidence — Phase 1 Policy Branch

**Date:** 2026-10-17  
**Branch:** `audit/relayer-2step-ownership-4usdt`  
**Tested commit:** `42150aa679ca64c5718e294dfd5e2b1d8a5ed729`  
**Workflow:** https://github.com/wadezigh96/BiP4444/actions/runs/38986594680  
**Compiler:** Solidity 0.8.24  
**Result:** CI successful.

## Test result

- `BIPMembershipForkTest`: 1 passed.
- `BIPMembershipRelayerTest`: 15 passed.
- `BIPMembershipControllerTest`: 28 passed.
- `BIPMembershipInvariantTest`: 2 invariant properties passed.
- Total: **45 tests passed, 0 failed, 0 skipped** in the Foundry report.
- Slither CI: successful; 4 informational detector results (timestamp expiry checks, signature-decoding assembly, and naming convention). Details: `SLITHER_2026-10-17.md`.

## Critical limitation: fork test may not have forked

The fork test intentionally returns successfully with a `ForkTestSkipped` event when `BSC_RPC_URL` is not configured. GitHub Actions does not receive that secret/environment variable in this workflow. Therefore the one passing `BIPMembershipForkTest` entry alone does **not** prove the live BSC registry was queried. The dedicated live-registry fork gate remains open until the test is run with `BSC_RPC_URL` set in a trusted environment and the evidence confirms `block.chainid == 56`, deployed bytecode, and `ownerOf(1)`.

## Scope and exclusions

This is evidence for the tested branch commit, not an independent audit. It does not validate B402 settlement, the backend ledger/refund path, relayer key custody, Alert Shield, frontend, or production configuration. No deployment or transaction was performed.
