# BIP4444 Audit and Release Gates

**Policy:** The project is not production-ready until every gate below is completed and evidence is recorded.  
**Last updated:** 2026-10-21

## Gates

- [ ] **Repository and dependency review**  
  Re-run when production dependencies (ethers, etc.) and full implementation are finalized.

- [x] **Verification of the actual BSC ERC-8004 registry address and deployed bytecode**  
  Evidence: `docs/evidence/ERC8004_BSC_2026-10-16.md`

- [x] **Membership-cap and duplicate-registration tests** *(unit suite)*  
  Evidence: `docs/evidence/FOUNDRY_TESTS_2026-10-16.md`  
  Note: tests updated for `registerFor` path; re-run recommended after any contract change.

- [ ] **x402 facilitator and settlement verification**  
  Design locked + relayer skeleton present (`scripts/relayer-x402-example.js`, `docs/RELAYER.md`).  
  Runtime evidence still required (real B402 credentials + successful settle + registerFor).

- [ ] **Alert authenticity, reporter authorization, and key-rotation tests**  
  Client verification foundation done (`public/js/alert-verify.js`, demo page).  
  Remaining: production keys, live feed, rotation/revoke tests, dual-control enforcement if desired.

- [ ] **Authentication, privacy, rate-limit, and phishing-resistance review**  
  Partially addressed in docs; formal review still open.

- [ ] **Unit, integration, and negative security tests**  
  Membership unit tests done.  
  x402 negative tests and BSC fork integration tests still pending.

- [ ] **Independent review of contracts and deployment configuration**

- [ ] **Explicit release approval before mainnet deployment**

## Evidence location

| Gate | Evidence |
|------|----------|
| Membership tests | `docs/evidence/FOUNDRY_TESTS_2026-10-16.md` |
| ERC-8004 BSC | `docs/evidence/ERC8004_BSC_2026-10-16.md` |
| payTo Safe | `docs/evidence/PAYTO_SAFE_BSC_2026-10-16.md` |
| x402 design + skeleton | `docs/X402_REQUIREMENTS.md`, `docs/RELAYER.md` |
| Alert Shield foundation | `docs/ALERT_SHIELD.md`, `public/js/alert-verify.js` |
| Setup path | `docs/SETUP.md` |

## Security-first rule

Do not modify production state, deploy contracts, or send mainnet transactions until the implementation has been reviewed and the required tests pass.
