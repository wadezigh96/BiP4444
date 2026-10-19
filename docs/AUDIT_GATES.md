# BIP4444 Audit and Release Gates

**Policy:** The project is not production-ready until every gate below is completed and evidence is recorded. No mainnet deployment, live payment enablement, or mainnet transaction is authorized by this branch.  
**Last updated:** 2026-10-19 (Alert Shield tests passed in CI; Foundry job still running)  
**Deployment target:** BSC Mainnet only (`eip155:56`). No Testnet transactions are requested. Local mock tests and read-only Mainnet checks are allowed; live payment, deployment, and state-changing Mainnet transactions remain disabled until all release gates pass.

## Gates

- [ ] **Repository and dependency review**  
  Re-run when production dependencies and full implementation are added; current contract static scan is recorded separately.

- [x] **Verification of the actual BSC ERC-8004 registry address and deployed bytecode**  
  Evidence: `docs/evidence/ERC8004_BSC_2026-10-16.md`

- [ ] **Slither report review for the current contract source**  
  GitHub Actions run [39180953805](https://github.com/wadezigh96/BiP4444/actions/runs/39180953805) completed Slither for the current Solidity source. Its five informational findings, including the ERC-1271 low-level staticcall detector, are summarized in `docs/evidence/SLITHER_2026-10-19.md`. Review and independent contract assessment are still required before this gate can be closed. The job uses `--fail-none`; success means the scan completed, not that it found zero issues. The existing `docs/evidence/SLITHER_2026-10-17.md` is historical and predates the 15-minute authorization lifetime change. Review and archive the report artifact for the exact release commit before closing this gate.

- [x] **Phase 1 Foundry suite (policy branch)**  
  Evidence: `docs/evidence/PHASE1_FOUNDRY_CI_2026-10-17.md`. CI passed 45 reported tests: 28 controller tests, 15 relayer tests, and the invariant/fork test harnesses. The stateful invariant suite ran 256 sequences / 128,000 handler calls with no reverts. The fork function skipped internally because `BSC_RPC_URL` was not configured; the live-fork gate remains open separately.

- [ ] **Membership API implementation and persistent ledger**  
  A fail-closed scaffold now exists at `api/health.js` and `api/v1/membership/register.js`; `test/api-scaffold.test.js` covers input rejection and confirms valid registration attempts return 503 without payment or chain side effects. GitHub Actions run `39159164438` passed the API scaffold tests and Foundry suite. This is not a production payment API: B402, durable ledger, owner-consent flow, relayer calls, and refunds are not implemented.

- [ ] **x402 facilitator and settlement verification**  
  Design locked (B402, 4 USDT, Safe payTo, path A, refund) — `docs/X402_REQUIREMENTS.md`. Official B402 V2 docs now confirm the seller's `X-PAYMENT-REQUIREMENTS` header, verify JSON schema and `data.isValid`/`data.payer`, and settle response fields. An isolated signed-request adapter exists at `lib/b402-client.js`; mocked adapter tests passed in [run 39180953805](https://github.com/wadezigh96/BiP4444/actions/runs/39180953805). The adapter is not wired into the public API. Buyer request-header transport remains unpinned, production credentials/onboarding remain outstanding, and persistent ledger, settlement reconciliation, refund logic, and full integration tests are not implemented. No Testnet run is requested.

- [ ] **Relayer registration security**  
  The public free `register(uint256)` method has been removed to close the payment bypass. The branch includes an allowlisted relayer path with EIP-712 owner consent bound to agent ID, payment-operation hash, role hash, per-agent nonce, deadline, chain ID, and controller address. Code supports EOA and ERC-1271 signatures, plus `invalidateAuthorization(agentId)` so the current owner can invalidate pending authorizations before transferring the identity; regression tests cover invalidation and ERC-1271. **Residual limitation:** ERC-8004 ownership transfers do not call this controller. If an owner transfers away and then back before a previously signed authorization expires, the controller cannot prove that an intervening transfer occurred. The owner must invalidate before transfer; the contract lifetime is limited to 15 minutes to reduce (not eliminate) the exposure window. Do not claim this edge case is fully eliminated. Run [39180568472](https://github.com/wadezigh96/BiP4444/actions/runs/39180568472) passed API scaffold tests, B402 adapter tests, Foundry tests, and the Slither job. This is CI evidence, not independent security review. The live-fork gate remains open because the BSC_RPC_URL fork test skipped without a configured RPC. B402 settlement is still an off-chain trust boundary; persistent ledger, verified payer/agent binding, key management, and independent review remain required.

- [ ] **Alert authenticity, reporter authorization, and key-rotation tests**  
  Verifier and tests exist in `lib/alert-shield.js` and `test/alert-shield.test.js`; the API test step passed in [run 39180953805](https://github.com/wadezigh96/BiP4444/actions/runs/39180953805), including signature, tampering, expiry, revoked-key, phishing-link, and dual-control cases. The public key directory remains empty, there is no publisher-key ceremony or live signing/feed endpoint, and production URL validation is still open.

- [ ] **Authentication, privacy, rate-limit, and phishing-resistance review**  
  Partially addressed in Alert Shield + x402 docs; formal review still open.

- [x] **Unit and stateful invariant tests (policy branch)**  
  Latest-head GitHub Actions run [39180568472](https://github.com/wadezigh96/BiP4444/actions/runs/39180568472) passed the API scaffold tests, B402 adapter tests, and Foundry test step. Historical detailed invariant counts are recorded in `docs/evidence/PHASE1_FOUNDRY_CI_2026-10-17.md`; the live-fork test still requires a separate RPC-backed run.

- [ ] **Live BSC fork test against the ERC-8004 registry**  
  `test/BIPMembershipFork.t.sol` is implemented, but the CI run did not have `BSC_RPC_URL`; the test emitted a skip event and returned. Run locally with a read-only RPC and save a separate evidence file before closing this gate.

- [ ] **Backend integration and negative payment tests**  
  B402/API settlement, payer-to-agent binding, idempotency, wrong amount/asset/chain/payTo, cap-full, and refund tests remain open. Cover deterministic behavior with local mocks; separately use read-only Mainnet checks for chain/configuration facts. Do not send a Testnet transaction or any state-changing Mainnet transaction during this phase. Alert Shield tests remain open.

- [x] **Foundry CI dependency and reproducibility check (policy branch)**  
  `forge-std` is pinned to v1.9.7 and the compiler to Solidity 0.8.24. Latest-head GitHub Actions run [39180568472](https://github.com/wadezigh96/BiP4444/actions/runs/39180568472) passed API scaffold tests, B402 adapter tests, Foundry tests, and the Slither job. Slither uses `--fail-none`; the report still requires review and a BSC fork run is separate.

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
| Historical Slither scan | `docs/evidence/SLITHER_2026-10-17.md` |\n| Current Slither scan | `docs/evidence/SLITHER_2026-10-19.md` |
| ERC-8004 BSC | `docs/evidence/ERC8004_BSC_2026-10-16.md` |
| payTo Safe | `docs/evidence/PAYTO_SAFE_BSC_2026-10-16.md` |
| x402 | Design `docs/X402_REQUIREMENTS.md`; API contract `docs/API_REGISTER.md` |
| Alert Shield | Design `docs/ALERT_SHIELD.md` |

## Security-first rule

Do not modify production state, deploy contracts, enable live payment, or send mainnet transactions until all applicable implementation, security, testing, and independent-review gates pass and explicit release approval is recorded.
