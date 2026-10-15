# BIP4444 Alert Shield Specification

**Status:** Planning / pre-implementation  
**Last updated:** 2026-10-16

## Purpose

Alert Shield is a detection and response aid for BIP members. It:

1. Monitors configured, documented risk signals and trusted incident sources.
2. Publishes alerts with verifiable provenance, timestamps, severity, and mitigation guidance.
3. Directs members to official response instructions and verified links.
4. Makes the limits of each alert explicit (uncertainty, possible false positives).

**It does not:**
- Guarantee immunity from attacks
- Prevent every transaction
- Reverse finalized blockchain transactions
- Recover assets automatically

## Required properties

### Authenticity
- Alerts must be signed or otherwise authenticated.
- Trusted reporter list and authorization process must be documented.
- Key rotation process must be defined and tested.

### Content
Each alert should include at minimum:
- Unique alert ID
- Timestamp (and optionally expiry)
- Severity level
- Source / reporter identity (or role)
- Short description of the risk
- Actionable mitigation / rescue guidance
- Explicit statement of uncertainty / false-positive possibility
- Links only to official, verified domains

### Delivery & privacy
- Rate-limit public endpoints.
- Protect against spam, replay, and phishing.
- Minimize personal data in any public record or QR.
- Verification QR (if used) points only to the official HTTPS domain and discloses only necessary information.

## Open design questions

1. Signing scheme (EOA, multisig, hardware, threshold?).
2. How reporters are onboarded and rotated.
3. Storage of historical alerts (on-chain vs off-chain with integrity proofs).
4. Member notification channels (in-app, webhook, etc.).
5. Severity taxonomy and escalation rules.

## Testing requirements before production

- [ ] Alert authenticity verification
- [ ] Reporter authorization checks
- [ ] Key-rotation procedure tested
- [ ] Replay / spoofing resistance
- [ ] Phishing-resistance review of any links or QR codes
