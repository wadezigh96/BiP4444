# BIP4444 Audit and Release Gates

**Policy:** The project is not production-ready until every gate below is completed and evidence is recorded.  
**Last updated:** 2026-10-16

## Gates

- [ ] **Repository and dependency review**  
  Current state: specification, planning docs, skeleton contracts, and Foundry tests only. Re-run when production dependencies and full implementation are added.

- [ ] **Verification of the actual BSC ERC-8004 registry address and deployed bytecode**  
  Addresses documented; verification script + evidence stub added.  
  Remaining: live RPC run + bytecode hash comparison.  
  See `docs/ERC8004_VERIFICATION.md` and `docs/evidence/ERC8004_BSC_2026-10-16.md`.

- [x] **Membership-cap and duplicate-registration tests** *(unit suite — local)*  
  Evidence: `docs/evidence/FOUNDRY_TESTS_2026-10-16.md`  
  - 22/22 Foundry tests passed (including `test_Cap_ReachedAt4444`)  
  - Cap 4444, duplicate rejection, ownership checks covered  
  - Still skeleton code; policy open questions remain before production

- [ ] **x402 facilitator and settlement verification**  
  See `docs/X402_REQUIREMENTS.md`. All negative tests must pass.

- [ ] **Alert authenticity, reporter authorization, and key-rotation tests**  
  See `docs/ALERT_SHIELD.md`.

- [ ] **Authentication, privacy, rate-limit, and phishing-resistance review**  
  Covers endpoints, QR codes, and public records.

- [ ] **Unit, integration, and negative security tests**  
  Unit membership tests done; broader integration / payment / alert tests still pending.

- [ ] **Independent review of contracts and deployment configuration**  
  External or second-pair review of final contracts and deploy scripts.

- [ ] **Explicit release approval before mainnet deployment**  
  Written sign-off that all above gates are complete.

## Evidence location

| Gate | Evidence |
|------|----------|
| Membership cap / duplicate | `docs/evidence/FOUNDRY_TESTS_2026-10-16.md` |
| ERC-8004 BSC | `docs/evidence/ERC8004_BSC_2026-10-16.md` (partial) |

## Security-first rule

Do not modify production state, deploy contracts, or send mainnet transactions until the implementation has been reviewed and the required tests pass.
