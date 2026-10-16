# BIP4444 Security Requirements

**Status:** Pre-audit implementation; not production-ready  
**Last updated:** 2026-10-17  
**Policy:** Audit first. Do not deploy contracts, enable production payments, or modify mainnet state until all gates in `docs/AUDIT_GATES.md` pass.

## Core security principles

1. **Never request or store secrets**  
   - No seed phrases, private keys, or recovery secrets of agent operators.  
   - Passwords, passkeys, and signing keys stay off-chain. Never log or expose them.

2. **Identity is ERC-8004 only**  
   - Do not mint a second passport NFT.  
   - Membership controller references ERC-8004 `agentId` and owner.

3. **Membership cap is on-chain**  
   - Hard limit of 4,444 unique active BIP memberships.  
   - Frontend or server-side counters are not sufficient.

4. **Payments require verified settlement and explicit owner consent**  
   - Access or membership must not be granted merely because a client claims it paid.  
   - The public free `register(uint256)` method has been removed; the on-chain registration path requires an allowlisted relayer and an EIP-712 signature from the current ERC-8004 owner.  
   - The contract cannot independently verify B402 settlement, so the backend must fail closed and keep durable payment/registration records.  
   - See `docs/API_REGISTER.md` and `docs/X402_REQUIREMENTS.md`.

5. **Alerts are authenticated**  
   - Signed/authenticated alerts with documented reporter authorization and key rotation.  
   - See `docs/ALERT_SHIELD.md`.

6. **Least privilege & emergency controls**  
   - Protected administrator permissions.  
   - Explicit emergency pause / revoke procedure (multisig or time-lock preferred).

## Threat model (high level)

| Threat | Mitigation direction |
|--------|----------------------|
| Unauthorized membership | EIP-712 owner consent bound to agentId/payment-operation hash/role, relayer allowlist, and current ERC-8004 owner check |
| Cap bypass / duplicate registration | Storage invariants + unique agentId mapping |
| Payment replay / wrong chain / wrong asset | Full x402 settlement verification + negative tests |
| Fake or phishing alerts | Signed alerts, trusted reporter list, key rotation, official domain only |
| Private key leakage | Never request or store operator keys |
| DoS / spam on public endpoints | Rate limiting, authentication where appropriate |
| Reentrancy / accounting bugs | Standard Solidity security patterns + independent review |
| Upgrade / admin key compromise | Multisig, time-lock, or non-upgradeable design decision recorded |

## Required security reviews before production

- Access control and role separation  
- Reentrancy and accounting  
- Membership-cap invariants  
- Upgradeability decision and risks  
- Dependency risk review  
- Rate-limit and phishing-resistance review  
- Independent review of contracts and deployment configuration  

## Testing requirements

- Unit tests for membership logic and invariants  
- Integration tests against a local BSC fork  
- Negative tests for payments, registration, and alerts  
- Explicit test of the 4,444 cap and duplicate prevention  

## Operational rules

- No mainnet deployment or production payment enablement until `docs/AUDIT_GATES.md` is fully checked and evidence recorded.  
- All secrets (deployer keys, admin keys, alert signing keys) managed outside the repository.  
