# BIP4444 Audit and Release Gates

**Policy:** The project is not production-ready until every gate below is completed and evidence is recorded.  
**Last updated:** 2026-10-16

## Gates

- [ ] **Repository and dependency review**  
  Current state: repository contains only specification and planning docs. Re-run when code and dependencies are added.

- [ ] **Verification of the actual BSC ERC-8004 registry address and deployed bytecode**  
  See `docs/ERC8004_VERIFICATION.md`. Evidence (bytecode hash, block number, etc.) must be recorded.

- [ ] **Membership-cap and duplicate-registration tests**  
  See `docs/MEMBERSHIP_CONTROLLER.md`. Must prove hard cap of 4,444 and no duplicate agentId.

- [ ] **x402 facilitator and settlement verification**  
  See `docs/X402_REQUIREMENTS.md`. All negative tests must pass.

- [ ] **Alert authenticity, reporter authorization, and key-rotation tests**  
  See `docs/ALERT_SHIELD.md`.

- [ ] **Authentication, privacy, rate-limit, and phishing-resistance review**  
  Covers endpoints, QR codes, and public records.

- [ ] **Unit, integration, and negative security tests**  
  Including local BSC fork testing.

- [ ] **Independent review of contracts and deployment configuration**  
  External or second-pair review of final contracts and deploy scripts.

- [ ] **Explicit release approval before mainnet deployment**  
  Written sign-off that all above gates are complete.

## Evidence location

When a gate is completed, record the evidence (PR link, test output, bytecode hash, review notes, etc.) in this file or in a linked `docs/evidence/` entry.

## Security-first rule

Do not modify production state, deploy contracts, or send mainnet transactions until the implementation has been reviewed and the required tests pass.
