# BIP4444 Audit and Release Gates

**Policy:** The project is not production-ready until every gate below is completed and evidence is recorded.  
**Last updated:** 2026-10-16

## Gates

- [ ] **Repository and dependency review**  
  Re-run when production dependencies and full implementation are added.

- [x] **Verification of the actual BSC ERC-8004 registry address and deployed bytecode**  
  Evidence: `docs/evidence/ERC8004_BSC_2026-10-16.md`

- [x] **Membership-cap and duplicate-registration tests** *(unit suite — local)*  
  Evidence: `docs/evidence/FOUNDRY_TESTS_2026-10-16.md`

- [ ] **x402 facilitator and settlement verification**  
  Design locked (B402, 5 USDT, Safe payTo, path A, refund) — `docs/X402_REQUIREMENTS.md`. Runtime evidence TBD.

- [ ] **Alert authenticity, reporter authorization, and key-rotation tests**  
  Design: `docs/ALERT_SHIELD.md`. Remaining: implement feed, keys, §11 tests, evidence.

- [ ] **Authentication, privacy, rate-limit, and phishing-resistance review**  
  Partially addressed in Alert Shield + x402 docs; formal review still open.

- [ ] **Unit, integration, and negative security tests**  
  Membership unit tests done; x402 + alert tests pending.

- [ ] **Independent review of contracts and deployment configuration**

- [ ] **Explicit release approval before mainnet deployment**

## Evidence location

| Gate | Evidence |
|------|----------|
| Membership tests | `docs/evidence/FOUNDRY_TESTS_2026-10-16.md` |
| ERC-8004 BSC | `docs/evidence/ERC8004_BSC_2026-10-16.md` |
| payTo Safe | `docs/evidence/PAYTO_SAFE_BSC_2026-10-16.md` |
| x402 | Design `docs/X402_REQUIREMENTS.md` |
| Alert Shield | Design `docs/ALERT_SHIELD.md` |

## Security-first rule

Do not modify production state, deploy contracts, or send mainnet transactions until the implementation has been reviewed and the required tests pass.
