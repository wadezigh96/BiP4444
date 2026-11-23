# Submission Pack — Binance Agent ID Hackathon

Copy-paste material for the submission form, judge walkthrough, community
posts, and the 30-holder drive. Deadline: **2026-12-09 08:00 UTC**
(15:00 WIB). Placeholders in `[BRACKETS]` are filled after deployment.

---

## 1 · Form fields (copy-paste)

**Project name**
BIP4444 — Binance Intelligence Passport

**Website**
https://bips4444.vercel.app — live demo: https://bips4444.vercel.app/agent-id-demo.html

**Reward receiving address**
`0xFf265912c76342c8469cE18aB9DF0B2f37d9373c` (BIP4444-Treasury, 2-of-2 Safe)

**Contract addresses (BNB Smart Chain)**
- BIPAgentIDGate: `[GATE_ADDRESS after deploy]`
- BIPMembershipController: `[CONTROLLER_ADDRESS if deployed, else "to be deployed"]`
- Agent ID used: `0x60b9262456de011f7d15a54cdd8c48baaa8b022f` (SPACE ID Agent ID)

**Agent ID usage description**
BIP4444 uses Agent ID as the root identity of an agent authorization
layer on BNB Smart Chain. An operator wallet must hold an Agent ID
(`balanceOf > 0` on the canonical SPACE ID Agent ID contract) before it
can bind its ERC-8004 agent identity to the BIPAgentIDGate contract.
Bound operators issue narrowly scoped, expiring delegated capabilities
to sub-agent addresses (scope = keccak256("domain:action"), explicit
expiry, revocable only by the grantor). Every authorization decision
(`isAuthorized`) re-checks Agent ID ownership live and fails closed if
the capability expired, was revoked, the binding was removed, or the
grantor no longer holds an Agent ID. Agent ID therefore gates real
product flows — agent registration, delegation, and authorization for
BIP4444's security alert/response network — not a cosmetic badge check.
The gate holds no user assets, contains no transfer or approval logic,
never collects credentials, and is not a name-to-wallet lookup tool.

**One-liner**
Agent ID, upgraded from a name to an authorization root: bind your agent,
delegate bounded capabilities, and every check fails closed.

---

## 2 · Pitch mapped to the judging criteria

| Criterion (weight) | What judges should see | Evidence |
|---|---|---|
| Agent ID Application Depth (30%) | Agent ID is load-bearing in 3 flows: binding, granting, and live authorization re-checks. Removing Agent ID breaks the product. | `BIPAgentIDGate.sol` (`registerAgent`, `grantCapability`, `isAuthorized`); live contract check in `docs/evidence/AGENT_ID_BSC_2026-11-23.md` |
| Practicality & Feasibility (25%) | Real problem: agents acting with unbounded keys. BIP4444 gives operators bounded, expiring, revocable delegation anchored to a human-claimed identity. | Demo flow §3; Alert Shield + membership layers already in repo |
| Product Completion (25%) | Working contracts + 67 passing tests, live demo page that checks Agent ID on BSC mainnet today, deploy script ready. | `forge test` 67/67; https://bips4444.vercel.app/agent-id-demo.html |
| Innovation (20%) | Delegated capabilities on Agent ID **plus** three rare features: Founding 44 free-mint seats (fee waived, on-chain, non-NFT), panic freeze with guardian rescue + 24h-cooldown unfreeze, and attenuated sub-delegation that can only narrow (depth 1, dies with parent). | Feature sections in `docs/AGENT_ID_HACKATHON.md`; tests `test_Founding_*`, `test_Freeze_*`, `test_GuardianFreeze_*`, `test_SubDelegate_*` |

**Honest limits to state if asked:** pre-audit artifact; privacy layer
(selective disclosure) is design, not implemented in this contract;
owner can only pause/unpause and transfer ownership (disclosed in code).

## 3 · Two-minute judge walkthrough

1. Open the demo → paste any BSC address → it checks Agent ID ownership
   against the live SPACE ID contract (no wallet needed).
2. Connect a wallet holding an Agent ID → register an ERC-8004 agent ID →
   the binding transaction is the hackathon-counted interaction.
3. Grant `bip4444:alerts:receive` to a sub-agent address for 24 hours.
4. Show `isAuthorized` = true; warp/revoke → false. Authorization dies
   with the capability — and would die if the Agent ID left the wallet.
5. Point at `uniqueAgentIDInteractors()` — the on-chain counter of
   Agent ID holders who registered during the submission period.

## 4 · The 30-holder drive (Innovation Award minimum)

Target: ≥ 30 **distinct, genuine** Agent ID holder wallets calling
`registerAgent` before 2026-12-09 08:00 UTC. Progress is publicly
verifiable via `uniqueAgentIDInteractors()`.

Rules of the drive (hackathon red lines):
- Real holders only. No mass account registration, no volume faking —
  that is an explicit disqualification ground.
- No promises of returns or rewards-for-interaction beyond what the
  hackathon itself offers. Invite people to *try the product*.

Schedule (≈16 days left from 2026-11-23; pace = 2–3 registrations/day):
- Days 1–2: deploy + verify gate; register own agent; record demo video.
- Days 3–5: post in Binance Wallet / BNB Chain developer communities
  (Discord hackathon channels, Telegram dev groups) with the demo link
  and the 2-minute walkthrough; ask Agent ID holders to bind an agent.
- Days 6–10: X thread (below) + SPACE ID community; personal outreach to
  agent builders met in those communities; daily counter screenshot.
- Days 11–15: second wave — short demo clip, "N/30 Agent ID holders
  bound" updates; help sessions for anyone stuck claiming an Agent ID.
- Day 16 (Dec 9, before 08:00 UTC): submit the form with final numbers.

The drive uses the low-friction path: `registerOperator()` needs **only**
an Agent ID — one transaction from the demo page, no ERC-8004 agent
required. The ERC-8004 binding (`registerAgent`) is an optional upgrade
for operators who already run an agent identity; do not put it in front
of drive participants.

Recruiting hook (rule-compliant): the first 44 registrants claim a
**Founding 44 seat** — their BIP4444 membership fee (5 USDT) is waived,
verifiable on-chain via `isFounding`. That is a fee waiver, not a reward
or a return: never promote it as earnings, and gas is still the user's.

## 5 · X posts (Community Promotion Award)

Post 1 (project thread, 1/):
> Most Agent ID integrations stop at "do you hold one?"
> BIP4444 makes Agent ID the authorization root for AI agents on BNB Chain:
> bind your agent → delegate scoped, expiring capabilities → every check
> fails closed. Live demo 👇 #BinanceWalletHackathon #AgenticWallet

Post 2 (2/): the safety angle — no assets in the contract, no credential
collection, owner can only pause; your sub-agent's power expires and can
be revoked, and dies with your Agent ID.

Post 3 (3/): the counter — "N Agent ID holders have bound their agents so
far" + demo link + invitation to register.

Community-award mechanics: posts must be original, include
#BinanceWalletHackathon and #AgenticWallet, and the X link must be
submitted through the official campaign survey.
