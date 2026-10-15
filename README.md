# BIP4444 — Binance Intelligence Passport

**BIP4444** is a security-focused identity and response layer for AI agents on BNB Smart Chain (BSC). Its purpose is to help participating agents and their operators identify risk, receive authenticated alerts, and follow clear rescue guidance during security incidents.

> **Current status:** specification and security planning. This README does not claim that contracts, x402 payments, Alert Shield feeds, or production deployment are implemented or audited.

## Core principles

- **Network:** BNB Smart Chain mainnet, chain ID `56`.
- **Identity:** use ERC-8004 agent identity directly; do not mint a separate BIP passport NFT.
- **Membership limit:** no more than **4,444 BIP members**.
- **Payments:** use x402 for eligible registration and paid services, subject to verification of a supported BSC facilitator, asset, settlement, and replay protections.
- **Emergency Shield mode:** **Alert Shield** — risk detection, authenticated warnings, and rescue instructions.
- **Privacy:** never ask for or store an agent operator's seed phrase or private key.

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

Whether membership can be revoked, transferred, or reactivated must be specified before implementation. The cap must not rely only on frontend checks or a server-side counter.

## x402 payment safety

Before any production payment flow is enabled, verify the exact facilitator, supported BSC network and asset, payment recipient, amount, expiry, and settlement result. Access or membership must not be granted merely because a client claims it paid.

Required negative tests include expired payments, wrong chain, wrong asset, wrong recipient, wrong amount, replayed payment proofs, duplicate registration, and failed or delayed settlement. No live payment is implied by this specification.

## Security requirements

- Keep passwords, passkeys, signing keys, and recovery secrets off-chain; never log or expose secrets.
- Use signed/authenticated alerts and a documented process for trusted reporters and key rotation.
- Rate-limit public endpoints and protect against spam, replay, phishing, and denial-of-service attempts.
- Minimize personal data in QR codes and public records. A verification QR should point to an official HTTPS domain and disclose only necessary information.
- Review contract access control, reentrancy, accounting, membership-cap invariants, upgradeability, and dependency risks.
- Test against a local fork or test environment before any mainnet deployment.
- Do not deploy or enable production payments until the security review and tests pass.

## Passport interface concept

The member interface is intended to display:

- BIP membership ID;
- chosen alias;
- ERC-8004 agent identity and current verification status;
- a verification QR linking to the official BIP domain;
- current Alert Shield notices and actionable rescue guidance.

The QR is a verification link, not a secret or authentication credential.

## Audit and release gates

The project should not be considered production-ready until these gates are completed and evidence is recorded:

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
