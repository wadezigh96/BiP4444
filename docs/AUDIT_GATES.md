# BIP4444 Audit and Release Gates

**Policy:** The project is not production-ready until every gate below is completed and evidence is recorded. No mainnet deployment, live payment enablement, or mainnet transaction is authorized by this branch.  
**Last updated:** 2026-10-17

## Gates

- [ ] **Repository and dependency review**  
  Re-run when production dependencies and full implementation are added.

- [x] **Verification of the actual BSC ERC-8004 registry address and deployed bytecode**  
  Evidence: `docs/evidence/ERC8004_BSC_2026-10-16.md`

- [ ] **Membership-cap and duplicate-registration tests**  
  Historical evidence: `docs/evidence/FOUNDRY_TESTS_2026-10-16.md` records the earlier skeleton suite. The latest GitHub Actions run failed before compiling because `forge-std/Test.sol` was missing; do not treat that historical result as validation of the current branch. A dependency-install step has been added and the updated suite must pass CI.

- [ ] **Membership API implementation and persistent ledger**  
  API contract drafted in `docs/API_REGISTER.md`. No production route, database-backed ledger, or runtime evidence is claimed yet.

- [ ] **x402 facilitator and settlement verification**  
  Design locked (B402, 5 USDT, Safe payTo, path A, refund) — `docs/X402_REQUIREMENTS.md`. Runtime evidence TBD. Verify current official B402 API/SDK documentation before implementing an adapter.

- [ ] **Relayer registration security**  
  The branch now includes an allowlisted relayer path with EIP-712 owner consent bound to agent ID, payment-operation hash, role hash, nonce, deadline, chain ID, and controller address; it also enforces payment-hash replay protection and a maximum signature lifetime. Current tests are not yet CI-verified. B402 settlement is still an off-chain trust boundary; persistent ledger, verified payment binding, key management, and independent review remain required.

- [ ] **Alert authenticity, reporter authorization, and key-rotation tests**  
  Design: `docs/ALERT_SHIELD.md`. Feed, signing/verifying implementation, public key directory validation, §11 tests, and evidence remain pending.

- [ ] **Authentication, privacy, rate-limit, and phishing-resistance review**  
  Partially addressed in Alert Shield + x402 docs; formal review still open.

- [ ] **Unit, integration, and negative security tests**  
  Existing membership skeleton tests are recorded; relayer, x402, API, and alert tests pending.

- [ ] **CI reproducibility**  
  `.github/workflows/forge-test.yml` now installs pinned `forge-std` v1.9.7 explicitly. Gate remains open until a new workflow run succeeds, the full test output is reviewed, and the result is recorded as evidence.

- [ ] **Independent review of contracts and deployment configuration**

- [ ] **Explicit release approval before mainnet deployment**

## Evidence location

| Gate | Evidence |
|------|----------|
| Membership tests | `docs/evidence/FOUNDRY_TESTS_2026-10-16.md` |
| ERC-8004 BSC | `docs/evidence/ERC8004_BSC_2026-10-16.md` |
| payTo Safe | `docs/evidence/PAYTO_SAFE_BSC_2026-10-16.md` |
| x402 | Design `docs/X402_REQUIREMENTS.md`; API contract `docs/API_REGISTER.md` |
| Alert Shield | Design `docs/ALERT_SHIELD.md` |

## Security-first rule

Do not modify production state, deploy contracts, enable live payment, or send mainnet transactions until all applicable implementation, security, testing, and independent-review gates pass and explicit release approval is recorded.
