# Agent ID Integration — Binance Agent ID Hackathon

BIP4444 entry for the **Agent ID Hackathon** (Binance Wallet x BNB Chain).
Submission period: 2026-11-18 08:00 UTC – 2026-12-09 08:00 UTC.
Total prize pool: 60,000 USDC (Project Awards + Community Promotion).

## What was added

| Component | Location |
|---|---|
| Agent ID interface (minimal, `balanceOf`) | `contracts/interfaces/IAgentID.sol` |
| Agent ID gate + delegated capabilities | `contracts/src/BIPAgentIDGate.sol` |
| Unit tests (23) | `test/BIPAgentIDGate.t.sol` |
| Mock Agent ID for tests | `test/mocks/MockAgentID.sol` |
| Deploy script (BSC mainnet constants) | `scripts/DeployAgentIDGate.s.sol` |

Existing components are untouched in behaviour; the gate is a new contract
that composes with the existing ERC-8004 identity and membership layers.

## How Agent ID is used (core flow)

Agent ID (SPACE ID, `name.ai`, non-transferable ERC-721) at
`0x60b9262456de011f7d15a54cdd8c48baaa8b022f` on BNB Smart Chain is the
**root identity** of the system:

1. **Binding** — `registerAgent(erc8004AgentId)` requires the caller to
   (a) own the ERC-8004 agent (`0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`)
   and (b) hold an Agent ID (`balanceOf(caller) > 0`, the check prescribed
   by the hackathon rules). One active binding per wallet and per agent.
2. **Delegated capabilities** — a bound operator grants narrowly scoped,
   expiring capabilities to delegate addresses (sub-agents) with
   `grantCapability(delegate, scope, expiresAt)`. Scopes are `bytes32`,
   convention `keccak256("domain:action")`, e.g.
   `keccak256("bip4444:alerts:receive")`. This carries BIP4444's
   delegated-authority design (bounded by audience, action and expiry)
   on-chain.
3. **Live authorization** — `isAuthorized(grantor, delegate, scope, id)`
   fails closed if the capability is unknown, revoked or expired, the
   grantor unbound, **or the grantor no longer holds an Agent ID**
   (re-checked at call time, not only at grant time).

On-chain metrics exposed for the hackathon's growth measurement:
`uniqueAgentIDInteractors()` (distinct Agent ID wallets that registered)
and `totalCapabilityGrants()`.

## Red-line compliance (hackathon rules)

- No QR-code / pairing-code web login for Agentic Wallet; no session storage.
- No bypass of user transaction confirmation: granting a capability is an
  explicit transaction by the grantor's own wallet. The gate moves no
  assets and contains no transfer/approval logic at all.
- No unauthorized transfers, no scheduled collection, no bundled transfers.
- No collection of seed phrases, private keys, API secrets or pairing codes.
- No promise of returns; no trading functionality (no risk warning needed).
- Agent ID is **not** packaged as a wallet-lookup-by-name tool: the gate
  stores no name→address directory and exposes no name lookup.
- Owner permissions are disclosed in the contract: the owner can only
  pause/unpause and transfer ownership. The owner **cannot** grant or
  revoke user capabilities, unbind users, or move assets (there are none).

## What is NOT claimed

- The gate is a pre-audit artifact, consistent with the rest of BIP4444
  (see `docs/AUDIT_GATES.md`). It is not production-ready.
- Privacy properties of BIP4444's wider design (selective disclosure etc.)
  are not implemented by this contract; the gate is an on-chain
  authorization layer only.

## Test evidence

`forge test` — 54 passed, 0 failed (23 new gate tests + 31 existing
membership tests), Foundry 1.10.0 / solc 0.8.39, 2026-11-23.

Note: two placeholder address literals in the pre-existing membership test
(`0xR3L4Y3R`, `0xNEWR`) were not valid hex and prevented compilation with
current solc; they were replaced with `0x1234` / `0x1235` (values are
symbolic in those tests; no assertion changed).

## Submission checklist

- [ ] Deploy `BIPAgentIDGate` to BNB Smart Chain mainnet (chain ID 56)
      via `scripts/DeployAgentIDGate.s.sol`
- [ ] Verify contract source on BscScan; repo is public / open-source
- [ ] Claim an Agent ID in the Binance App (Wallet → banner → Agent ID)
- [ ] Register at least one ERC-8004 agent through the gate (self-test)
- [ ] Drive ≥ 30 distinct Agent ID holder wallets to call `registerAgent`
      before 2026-12-09 08:00 UTC (Innovation Award minimum eligibility)
- [ ] Submit: project name, website (bips4444.vercel.app), contract
      address(es) — membership controller + Agent ID gate — and the
      Agent ID usage description (this document, §"How Agent ID is used")
- [ ] Optional: community posts on X with #BinanceWalletHackathon and
      #AgenticWallet
