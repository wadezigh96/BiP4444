# BIP4444 — Binance Intelligence Passport

**BIP4444** is a security-focused identity and response layer for AI agents on BNB Smart Chain (BSC). Its purpose is to help participating agents and their operators identify risk, receive authenticated alerts, and follow clear rescue guidance during security incidents.

> **Current status:** specification and security planning. This repository does not claim that contracts, x402 payments, Alert Shield feeds, or production deployment are implemented or audited.

## Core principles

- **Network:** BNB Smart Chain mainnet, chain ID `56`.
- **Identity:** use ERC-8004 agent identity directly; do not mint a separate BIP passport NFT.
- **Membership limit:** no more than **4,444 BIP members**.
- **Payments:** use x402 for eligible registration and paid services, subject to verification of a supported BSC facilitator, asset, settlement, and replay protections.
- **Emergency Shield mode:** **Alert Shield** — risk detection, authenticated warnings, and rescue instructions.
- **Privacy:** never ask for or store an agent operator's seed phrase or private key.

## Repository structure

```
BiP4444/
├── README.md
├── docs/
│   ├── SECURITY.md                 # Security principles & threat model
│   ├── MEMBERSHIP_CONTROLLER.md    # On-chain membership design
│   ├── X402_REQUIREMENTS.md        # Payment safety requirements
│   ├── ALERT_SHIELD.md             # Alert authenticity & response
│   ├── ERC8004_VERIFICATION.md     # BSC registry verification checklist
│   ├── AUDIT_GATES.md              # Release gates (must all pass)
│   └── evidence/                   # Place for verification evidence
├── contracts/
│   ├── interfaces/
│   │   └── IBIPMembershipController.sol
│   └── src/                        # Implementation (not yet written)
├── test/                           # Tests (not yet written)
└── scripts/                        # Deploy / verification scripts (not yet written)
```

## What Alert Shield does

1. Monitors configured, documented risk signals and trusted incident sources.
2. Publishes alerts with verifiable provenance, timestamps, severity, and mitigation guidance.
3. Directs members to official response instructions and verified links.
4. Makes the limits of each alert explicit, including uncertainty and the possibility of false positives.

Alert Shield is a detection and response aid. It does **not** guarantee immunity from attacks, prevent every transaction, reverse finalized blockchain transactions, or recover assets automatically.

## Identity and the 4,444-member cap

ERC-8004 provides agent identity; it should not be assumed to enforce BIP4444's separate membership limit.

The design must therefore define and audit a membership controller/registry that references ERC-8004 agent IDs without minting a second passport NFT. It must enforce all of the following on-chain before production:

- at most 4,444 unique active BIP memberships;
- no duplicate membership for the same agent identity;
- explicit and auditable membership status changes;
- clear ownership/identity checks and handling for transfers or changed agent owners;
- protected administrator permissions and an emergency procedure.

See **[docs/MEMBERSHIP_CONTROLLER.md](docs/MEMBERSHIP_CONTROLLER.md)** for the current design.

## Technical documentation

| Document | Description |
|----------|-------------|
| [docs/SECURITY.md](docs/SECURITY.md) | Security principles, threat model, operational rules |
| [docs/MEMBERSHIP_CONTROLLER.md](docs/MEMBERSHIP_CONTROLLER.md) | Membership controller specification & interface sketch |
| [docs/X402_REQUIREMENTS.md](docs/X402_REQUIREMENTS.md) | x402 payment safety & negative tests |
| [docs/ALERT_SHIELD.md](docs/ALERT_SHIELD.md) | Alert authenticity and response design |
| [docs/ERC8004_VERIFICATION.md](docs/ERC8004_VERIFICATION.md) | BSC ERC-8004 registry verification checklist |
| [docs/AUDIT_GATES.md](docs/AUDIT_GATES.md) | Full release gate checklist |

## Passport interface concept

The member interface is intended to display:

- BIP membership ID;
- chosen alias;
- ERC-8004 agent identity and current verification status;
- a verification QR linking to the official BIP domain;
- current Alert Shield notices and actionable rescue guidance.

The QR is a verification link, not a secret or authentication credential.

## Audit and release gates

The project should not be considered production-ready until these gates are completed and evidence is recorded. Full list and tracking: **[docs/AUDIT_GATES.md](docs/AUDIT_GATES.md)**.

Summary:

- [ ] Repository and dependency review
- [ ] Verification of the actual BSC ERC-8004 registry address and deployed bytecode
- [ ] Membership-cap and duplicate-registration tests
- [ ] x402 facilitator and settlement verification
- [ ] Alert authenticity, reporter authorization, and key-rotation tests
- [ ] Authentication, privacy, rate-limit, and phishing-resistance review
- [ ] Unit, integration, and negative security tests
- [ ] Independent review of contracts and deployment configuration
- [ ] Explicit release approval before mainnet deployment

## Scope boundaries

BIP4444 is an identity and incident-response concept. It is not a replacement for secure key management, endpoint security, backups, or an incident-response professional. A member may receive earlier or more targeted information, but membership cannot guarantee that an agent or its assets will remain safe.

---

**Security-first policy:** audit first. Do not modify production state, deploy contracts, or send mainnet transactions until the implementation has been reviewed and the required tests pass.
