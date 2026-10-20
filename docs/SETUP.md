# BIP4444 — Path to a usable system

**Last updated:** 2026-10-21

This document describes what is already in the repository and the remaining external steps required before user agents can register on BSC according to the concept.

## What is already implemented

| Layer | Status | Location |
|-------|--------|----------|
| Membership controller (cap 4444, register, registerFor, pause, revoke) | Skeleton + unit tests | `contracts/src/BIPMembershipController.sol` |
| Path A relayer skeleton (verify → settle → registerFor + refund flag) | Skeleton | `scripts/relayer-x402-example.js` |
| Alert Shield client verification (Ed25519) | Foundation + demo | `public/js/alert-verify.js`, `public/alert-demo.html` |
| Key directory structure | Demo public key | `public/.well-known/bip-alert-keys.json` |
| Deployment script | Example | `scripts/Deploy.s.sol` |
| Docs & gates | Updated | `docs/` |

## Remaining steps (external)

These cannot be completed inside the repository alone.

### 1. B402 credentials
- Apply for Binance B402 partner access (or use the docs.b402.ai facilitator).
- Obtain API credentials / RSA client keys.
- Replace the placeholder `b402Verify` / `b402Settle` functions in the relayer script.

### 2. Deploy membership controller
```bash
# Example (testnet first recommended)
export DEPLOYER_PRIVATE_KEY=0x...
export RELAYER_ADDRESS=0x...
forge script scripts/Deploy.s.sol:Deploy \
  --rpc-url $BSC_RPC_URL \
  --broadcast
```
Then call `setRelayer` if not done in the script, and (recommended) transfer ownership to a multisig.

### 3. Relayer setup
- Generate a dedicated relayer EOA and fund it with a small amount of BNB for gas.
- Set environment variables (see `docs/RELAYER.md` and `docs/OPS_ENV.md`).
- Run or deploy the relayer (the skeleton can be wrapped in an HTTP server).

### 4. Alert Shield production keys
- Generate Ed25519 key pair offline.
- Put only the public key in the key directory (`status: active`).
- Store the private key in Vercel env / KMS only.
- Revoke the demo key.

### 5. Frontend deploy
- Connect the repo to Vercel (project already referenced as `bips4444.vercel.app`).
- Ensure `public/.well-known/bip-alert-keys.json` is served.
- Optional: expand the static page into a member passport UI.

### 6. Independent review & remaining gates
- See `docs/AUDIT_GATES.md`.
- Do not enable production payments until the remaining gates are closed.

## Architecture (current)

```
User / Agent
    │
    ├── Pays 5 USDT via x402 (B402) ──► Safe payTo
    │
    └── Backend Relayer
            ├── B402 verify + settle
            └── BIPMembershipController.registerFor(agentId)

Alert Shield
    ├── Publisher signs alert (server, private key in env)
    └── Client verifies against /.well-known/bip-alert-keys.json
```

## Security reminders

- Never commit private keys, B402 secrets, or relayer keys.
- The current contracts and scripts are pre-audit.
- Membership does not guarantee asset safety.
