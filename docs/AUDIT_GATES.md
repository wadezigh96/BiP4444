# BIP4444 Audit and Release Gates

**Policy:** The project is not production-ready until every gate below is completed and evidence is recorded. No mainnet deployment, live payment enablement, or mainnet transaction is authorized by this branch.  
**Last updated:** 2026-10-19  
**Deployment target:** BSC Mainnet only (`eip155:56`). No Testnet transactions are requested. Local mock tests and read-only Mainnet checks are allowed; live payment, deployment, and state-changing Mainnet transactions remain disabled until all release gates pass.

## Gates

- [ ] **Repository and dependency review**  
  Re-run when production dependencies and full implementation are added; current contract static scan is recorded separately.

- [x] **Verification of the actual BSC ERC-8004 registry address and deployed bytecode**  
  Evidence: `docs/evidence/ERC8004_BSC_2026-10-16.md`

- [x] **Slither static analysis (current contract source)**  
  Evidence: `docs/evidence/SLITHER_2026-10-17.md`. Slither 0.11.3 reported four informational findings: deadline timestamp comparisons (intentional expiry checks), narrowly scoped signature-decoding assembly, and the uppercase `MAX_MEMBERS()` getter naming convention. No high/medium detector finding appeared in the report. Re-run against the exact release commit and retain independent review.

- [x] **Phase 1 Foundry suite (policy branch)**  
  Evidence: `docs/evidence/PHASE1_FOUNDRY_CI_2026-10-17.md`. CI passed 45 reported tests: 28 controller tests, 15 relayer tests, and the invariant/fork test harnesses. The stateful invariant suite ran 256 sequences / 128,000 handler calls with no reverts. The fork function skipped internally because `BSC_RPC_URL` was not configured; the live-fork gate remains open separately.

- [ ] **Membership API implementation and persistent ledger**  
  A fail-closed scaffold now exists at `api/health.js` and `api/v1/membership/register.js`; `test/api-scaffold.test.js` covers input rejection and confirms valid registration attempts return 503 without payment or chain side effects. GitHub Actions run `39159164438` passed the API scaffold tests and Foundry suite. This is not a production payment API: B402, durable ledger, owner-consent flow, relayer calls, and refunds are not implemented.

- [ ] **x402 facilitator and settlement verification**  
  Design locked (B402, 4 USDT, Safe payTo, path A, refund) — `docs/X402_REQUIREMENTS.md`. Official Binance B402 V2 Quick Start identifies `X-PAYMENT-REQUIREMENTS` for the seller's HTTP 402 response and the `/papi/v2/b402/verify` → `/papi/v2/b402/settle` flow. Buyer payment and success-response header schemas still require exact V2 API-reference confirmation; do not guess generic x402 header names. Runtime evidence TBD; adapter and production credentials remain unimplemented. No Testnet run is requested.

- [ ] **Relayer registration security**  
  The public free `register(uint256)` method has been removed to close the payment bypass. The branch includes an allowlisted relayer path with EIP-712 owner consent bound to agent ID, payment-operation hash, role hash, owner nonce, deadline, chain ID, and controller address; it enforces payment-hash replay protection and a maximum signature lifetime. Current code supports EOA signatures only; ERC-1271 smart-contract wallets are unsupported. **Additional review gate:** an authorization signed by an address may remain usable if ERC-8004 ownership transfers away and then back to that same address before the deadline, because the controller cannot observe/invalidate every registry transfer. Decide and implement a safe invalidation/short-lifetime policy and add a regression test before release. The Phase 1 Solidity suite passed 45 reported tests in CI; see `docs/evidence/PHASE1_FOUNDRY_CI_2026-10-17.md`. B402 settlement is still an off-chain trust boundary; persistent ledger, verified payer/agent binding, key management, and independent review remain required.

- [ ] **Alert authenticity, reporter authorization, and key-rotation tests**  
  Design: `docs/ALERT_SHIELD.md`. Feed, signing/verifying implementation, public key directory validation, §11 tests, and evidence remain pending.

- [ ] **Authentication, privacy, rate-limit, and phishing-resistance review**  
  Partially addressed in Alert Shield + x402 docs; formal review still open.

- [x] **Unit and stateful invariant tests (policy branch)**  
  Evidence: `docs/evidence/PHASE1_FOUNDRY_CI_2026-10-17.md`. Controller/relayer tests and two stateful invariants pass in CI.

- [ ] **Live BSC fork test against the ERC-8004 registry**  
  `test/BIPMembershipFork.t.sol` is implemented, but the CI run did not have `BSC_RPC_URL`; the test emitted a skip event and returned. Run locally with a read-only RPC and save a separate evidence file before closing this gate.

- [ ] **Backend integration and negative payment tests**  
  B402/API settlement, payer-to-agent binding, idempotency, wrong amount/asset/chain/payTo, cap-full, and refund tests remain open. Cover deterministic behavior with local mocks; separately use read-only Mainnet checks for chain/configuration facts. Do not send a Testnet transaction or any state-changing Mainnet transaction during this phase. Alert Shield tests remain open.

- [x] **Foundry CI dependency and reproducibility check (policy branch)**  
  `forge-std` is pinned to v1.9.7 and the compiler to Solidity 0.8.24. GitHub Actions run `39159164438` passed both API/Foundry tests and Slither on the current policy branch. Slither uses `--fail-none`, so a successful job is not proof of zero findings. Rerun and review the report against the exact release commit.

- [ ] **Independent review of contracts and deployment configuration**

- [ ] **Explicit release approval before mainnet deployment**

## Evidence location

| Gate | Evidence |
|------|----------|
| Historical membership tests | `docs/evidence/FOUNDRY_TESTS_2026-10-16.md` |
| Previous-branch Foundry CI (not this policy branch) | `docs/evidence/FOUNDRY_CI_2026-10-17.md` |
| Phase 1 Foundry CI | `docs/evidence/PHASE1_FOUNDRY_CI_2026-10-17.md` |
| Phase 1 policy decision record | `docs/DECISIONS_PHASE_0_2026-10-17.md` |
| Phase 1 Foundry CI | `docs/evidence/FOUNDRY_PHASE1_CI_2026-10-17.md` |
| Slither static analysis | `docs/evidence/SLITHER_2026-10-17.md` |
| ERC-8004 BSC | `docs/evidence/ERC8004_BSC_2026-10-16.md` |
| payTo Safe | `docs/evidence/PAYTO_SAFE_BSC_2026-10-16.md` |
| x402 | Design `docs/X402_REQUIREMENTS.md`; API contract `docs/API_REGISTER.md` |
| Alert Shield | Design `docs/ALERT_SHIELD.md` |

## Security-first rule

Do not modify production state, deploy contracts, enable live payment, or send mainnet transactions until all applicable implementation, security, testing, and independent-review gates pass and explicit release approval is recorded.
