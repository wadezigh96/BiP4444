# BIP4444 — Binance Intelligence Passport

**BIP4444** is a security-focused identity and response layer for AI agents on BNB Smart Chain (BSC). It helps participating agents and their operators identify risk, receive authenticated alerts, and follow clear rescue guidance during security incidents.

> **Current status (2026-10-21):** Foundations implemented (membership controller + Path A relayer skeleton + Alert Shield client verification).  
> Not production-ready. Audit gates still apply. See [docs/SETUP.md](docs/SETUP.md) and [docs/AUDIT_GATES.md](docs/AUDIT_GATES.md).

## Core principles

- **Network:** BNB Smart Chain mainnet, chain ID `56`.
- **Identity:** ERC-8004 agent identity (no second passport NFT).
- **Membership limit:** hard cap of **4,444** active members (enforced on-chain).
- **Payments:** x402 via B402 — **5 USDT** to Safe `payTo`, Path A relayer.
- **Alert Shield:** signed alerts (Ed25519) with domain allowlist.
- **Privacy:** never request or store operator seed phrases or private keys.

## Architecture

```
Client / Agent
  │
  ├─ 402 Payment (5 USDT → Safe 0xFf2659…373c)
  │
  └─ Backend Relayer
        ├─ B402 verify + settle
        └─ BIPMembershipController.registerFor(agentId)

Alert Shield
  ├─ Server signs alert (private key in env only)
  └─ Client verifies against /.well-known/bip-alert-keys.json
```

## What is implemented

| Component | Location | Notes |
|-----------|----------|-------|
| Membership controller | `contracts/src/BIPMembershipController.sol` | Cap, register, registerFor, pause, revoke |
| Unit tests | `test/BIPMembershipController.t.sol` | Includes Path A tests |
| Relayer skeleton | `scripts/relayer-x402-example.js` | verify → settle → registerFor + refund flag |
| Alert Shield verify | `public/js/alert-verify.js` | Web Crypto Ed25519 |
| Alert demo | `public/alert-demo.html` | |
| Deploy script | `scripts/Deploy.s.sol` | Foundry |
| Docs | `docs/` | Design + status |

## Quick links

- [Setup path to usable system](docs/SETUP.md)
- [Membership controller](docs/MEMBERSHIP_CONTROLLER.md)
- [x402 / Relayer](docs/X402_REQUIREMENTS.md) · [RELAYER.md](docs/RELAYER.md)
- [Alert Shield](docs/ALERT_SHIELD.md)
- [Audit gates](docs/AUDIT_GATES.md)
- [Security principles](docs/SECURITY.md)

## Locked parameters

| Item | Value |
|------|--------|
| Membership price | 5 USDT |
| USDT (BSC) | `0x55d398326f99059fF775485246999027B3197955` |
| payTo (Safe 2-of-2) | `0xFf265912c76342c8469cE18aB9DF0B2f37d9373c` |
| ERC-8004 Identity | `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432` |
| Official domain | `bips4444.vercel.app` |

## Scope boundaries

BIP4444 is an identity and incident-response layer. It is not a replacement for secure key management, endpoint security, or professional incident response. Membership does not guarantee that an agent or its assets will remain safe.

---

**Security-first:** Do not deploy to mainnet or enable production payments until the remaining gates in `docs/AUDIT_GATES.md` are closed and an independent review is complete.
