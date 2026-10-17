# BIP4444 Audit and Release Gates

**Policy:** The project is not production-ready until every gate below is completed and evidence is recorded. No mainnet deployment, live payment enablement, or mainnet transaction is authorized by this branch.  
**Last updated:** 2026-10-17

## Gates

- [ ] **Repository and dependency review**  
  Re-run when production dependencies and full implementation are added; current contract static scan is recorded separately.

- [x] **Verification of the actual BSC ERC-8004 registry address and deployed bytecode**  
  Evidence: `docs/evidence/ERC8004_BSC_2026-10-16.md`

- [x] **Slither static analysis (current contract source)**  
  Evidence: `docs/evidence/SLITHER_2026-10-17.md`. Slither 0.11.3 reported four informational findings: deadline timestamp comparisons (intentional expiry checks), narrowly scoped signature-decoding assembly, and the uppercase `MAX_MEMBERS()` getter naming convention. No high/medium detector finding appeared in the report. Re-run against the exact release commit and retain independent review.

- [ ] **Phase 1 Foundry suite (policy branch)**  
  The previous 39-test run is evidence for an earlier commit only. This branch adds self-revoke, revoke-during-pause, ownership-follow, complete membership events, reactivation, and stateful invariants. Keep open until the new CI run passes and evidence is recorded.

- [ ] **Membership API implementation and persistent ledger**  
  API contract drafted in `docs/API_REGISTER.md`. No production route, database-backed ledger, or runtime evidence is claimed yet.

- [ ] **x402 facilitator and settlement verification**  
  Design locked (B402, 4 USDT, Safe payTo, path A, refund) — `docs/X402_REQUIREMENTS.md`. Runtime evidence TBD. Verify current official B402 API/SDK documentation before implementing an adapter.

- [ ] **Relayer registration security**  
  The public free `register(uint256)` method has been removed to close the payment bypass. The branch includes an allowlisted relayer path with EIP-712 owner consent bound to agent ID, payment-operation hash, role hash, nonce, deadline, chain ID, and controller address; it also enforces payment-hash replay protection and a maximum signature lifetime. The current Solidity unit suite passed 39 tests in the recorded CI run. B402 settlement is still an off-chain trust boundary; persistent ledger, verified payment binding, key management, and independent review remain required.

- [ ] **Alert authenticity, reporter authorization, and key-rotation tests**  
  Design: `docs/ALERT_SHIELD.md`. Feed, signing/verifying implementation, public key directory validation, §11 tests, and evidence remain pending.

- [ ] **Authentication, privacy, rate-limit, and phishing-resistance review**  
  Partially addressed in Alert Shield + x402 docs; formal review still open.

- [ ] **Unit, invariant, fork, integration, and negative security tests**  
  Phase 1 policy tests and stateful invariants added on the policy branch; CI pending. Fork tests against the real registry, B402/API tests, and Alert Shield tests remain open.

- [ ] **Foundry CI dependency and reproducibility check (policy branch)**  
  `forge-std` is pinned to v1.9.7; the compiler is being pinned to Solidity 0.8.24. The gate stays open until the updated workflow passes.

- [ ] **Independent review of contracts and deployment configuration**

- [ ] **Explicit release approval before mainnet deployment**

## Evidence location

| Gate | Evidence |
|------|----------|
| Historical membership tests | `docs/evidence/FOUNDRY_TESTS_2026-10-16.md` |
| Previous-branch Foundry CI (not this policy branch) | `docs/evidence/FOUNDRY_CI_2026-10-17.md` |
| Phase 1 policy decision record | `docs/DECISIONS_PHASE_0_2026-10-17.md` |
| Slither static analysis | `docs/evidence/SLITHER_2026-10-17.md` |
| ERC-8004 BSC | `docs/evidence/ERC8004_BSC_2026-10-16.md` |
| payTo Safe | `docs/evidence/PAYTO_SAFE_BSC_2026-10-16.md` |
| x402 | Design `docs/X402_REQUIREMENTS.md`; API contract `docs/API_REGISTER.md` |
| Alert Shield | Design `docs/ALERT_SHIELD.md` |

## Security-first rule

Do not modify production state, deploy contracts, enable live payment, or send mainnet transactions until all applicable implementation, security, testing, and independent-review gates pass and explicit release approval is recorded.
