# Deploy BIPAgentIDGate to BSC Mainnet — Operator Guide

One page, in order. Estimated total time: ~20 minutes.
Estimated cost: **≈ 0.00011 BNB** deployment gas (fork-simulated
2026-11-23, see `docs/evidence/FORK_REHEARSAL_2026-11-23.md`) — keep
~0.005 BNB in the deployer wallet to be safe.

## Roles

- **Deployer EOA** — any wallet you control with a little BNB. It only
  deploys; ownership moves to the Safe right after. Never share its
  private key with anyone, including in chat.
- **BIP4444-Treasury Safe** — `0xFf265912c76342c8469cE18aB9DF0B2f37d9373c`
  (2-of-2 Safe, verified on-chain 2026-11-23). It becomes:
  1. the **owner** of BIPAgentIDGate (pause power only) after step 4,
  2. the **reward receiving address** in the hackathon submission form,
  3. the existing x402 `payTo` for membership payments.
  A Safe cannot deploy contracts by itself — that is what the EOA is for.

## Steps

1. **Merge PR #6** (or check out branch `feat/agent-id-gate-hackathon`),
   then:
   ```bash
   forge install
   forge test        # expect: 67 passed
   ```
2. **Set secrets locally** (your terminal only):
   ```bash
   export DEPLOYER_PRIVATE_KEY=<your EOA private key>
   export BSCSCAN_API_KEY=<your BscScan API key>   # for verification
   ```
3. **Deploy + verify on BscScan:**
   ```bash
   forge script scripts/DeployAgentIDGate.s.sol:DeployAgentIDGate \
     --rpc-url https://bsc-dataseed.binance.org \
     --private-key $DEPLOYER_PRIVATE_KEY \
     --broadcast --verify
   ```
   Save the printed gate address.
4. **Move ownership to the Treasury Safe** (from the deployer EOA):
   ```bash
   cast send <GATE_ADDRESS> "transferOwnership(address)" \
     0xFf265912c76342c8469cE18aB9DF0B2f37d9373c \
     --rpc-url https://bsc-dataseed.binance.org \
     --private-key $DEPLOYER_PRIVATE_KEY
   ```
5. **Activate the demo:** set `GATE_ADDRESS` in
   `public/js/agent-id-gate.js` to the deployed address, commit, push
   (Vercel redeploys bips4444.vercel.app automatically).
6. **Self-test:** claim your Agent ID in the Binance App, open
   `/agent-id-demo.html`, connect, `Register as operator` — you should
   claim Founding seat #1 and see `uniqueAgentIDInteractors() = 1`.
7. **Submit** the hackathon form using `docs/SUBMISSION_PACK.md`
   (reward address = the Treasury Safe above) **before
   2026-12-09 08:00 UTC**.
