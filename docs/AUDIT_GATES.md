# BIP4444 Audit and Release Gates

**Policy:** The project is not production-ready until every gate below is completed and evidence is recorded.  
**Last updated:** 2026-10-16

## Gates

- [ ] **Repository and dependency review**  
  Re-run when production dependencies and full implementation are added.

- [x] **Verification of the actual BSC ERC-8004 registry address and deployed bytecode**  
  Evidence: `docs/evidence/ERC8004_BSC_2026-10-16.md`

- [x] **Membership-cap and duplicate-registration tests** *(existing skeleton unit suite — local)*  
  Evidence: `docs/evidence/FOUNDRY_TESTS_2026-10-16.md`. These tests do not audit future relayer functionality.

- [ ] **Membership API implementation and persistent ledger**  
  API contract drafted in `docs/API_REGISTER.md`. No production route, database-backed ledger, or runtime evidence is claimed yet.

- [ ] **x402 facilitator and settlement verification**  
  Design locked (B402, 5 USDT, Safe payTo, path A, refund) — `docs/X402_REQUIREMENTS.md`. Runtime evidence TBD. Verify current official B402 API/SDK documentation before implementing an adapter.

- [ ] **Relayer registration security**  
  `registerFor` + `RELAYER_ROLE` not implemented. Require authorization, pause/cap/duplicate tests, key management, and independent review.

- [ ] **Alert authenticity, reporter authorization, and key-rotation tests**  
  Design: `docs/ALERT_SHIELD.md`. Feed, signing/verifying implementation, public key directory validation, §11 tests, and evidence remain pending.

- [ ] **Authentication, privacy, rate-limit, and phishing-resistance review**  
  Partially addressed in Alert Shield + x402 docs; formal review still open.

- [ ] **Unit, integration, and negative security tests**  
  Existing membership skeleton tests are recorded; relayer, x402, API, and alert tests pending.

- [ ] **CI reproducibility**  
  Foundry GitHub Actions workflow added at `.github/workflows/forge-test.yml` on the implementation branch. Gate remains open until the workflow runs successfully on GitHub and the result is reviewed.

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
