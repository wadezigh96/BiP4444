# BIP4444 Path A Relayer (x402 → registerFor)

**Status:** Foundation / skeleton  
**Last updated:** 2026-10-21

## Purpose

Backend relayer that:

1. Receives a client x402 payment authorization (5 USDT to the Safe).
2. Calls B402 `/verify` then `/settle`.
3. On successful settlement, calls `BIPMembershipController.registerFor(agentId)`.
4. If settlement succeeds but registration fails → marks the payment for **refund**.

## Locked parameters

| Item | Value |
|------|--------|
| Network | BSC mainnet (chain ID 56) |
| Price | 5 USDT (`5000000000000000000`) |
| Asset | `0x55d398326f99059fF775485246999027B3197955` |
| payTo (Safe) | `0xFf265912c76342c8469cE18aB9DF0B2f37d9373c` |
| Facilitator | B402 |

## Files

- `scripts/relayer-x402-example.js` — skeleton flow (verify → settle → registerFor + refund flag)

## Required environment variables

| Name | Purpose |
|------|---------|
| `B402_BASE_URL` | Facilitator base URL |
| `B402_API_KEY` / `B402_API_SECRET` | Or Binance RSA client credentials |
| `RELAYER_PRIVATE_KEY` | EOA authorized as `relayer` on the controller |
| `MEMBERSHIP_CONTROLLER_ADDRESS` | Deployed contract |
| `BSC_RPC_URL` | BSC JSON-RPC |

**Never commit these values.**

## B402 surfaces (notes)

There are currently two relevant surfaces:

1. **docs.b402.ai** — `https://facilitatorv3.b402.ai` (public-looking `/verify` + `/settle`)
2. **Binance official B402** — authenticated `/papi/v2/b402/*` (requires partner onboarding, RSA signing, IP whitelist)

Use the one that matches your credentials. The skeleton uses placeholders; replace the `b402Verify` / `b402Settle` functions with the real authenticated client.

## Idempotency & refund

- Each payment gets a `paymentId`.
- Ledger tracks: `pending` → `settled` → `registered` (or `refund_required`).
- If settle succeeds but `registerFor` reverts, status becomes `refund_required`.
- Refund of 5 USDT to the original payer must be executed (Safe or manual process).

## Next steps before production

- [ ] Obtain real B402 credentials
- [ ] Replace placeholder B402 calls with authenticated client
- [ ] Deploy membership controller and `setRelayer`
- [ ] Persist ledger (Postgres / etc.)
- [ ] Add HTTP API (Express / Fastify / Vercel serverless)
- [ ] Implement actual refund path
- [ ] Negative tests (wrong payTo, wrong amount, replay, etc.)
- [ ] Rate limiting & monitoring

## Security

- Relayer key can only call `registerFor` (and pay gas). It cannot move the Safe funds alone (2-of-2).
- Never log full payment signatures or private keys.
- All B402 calls stay server-side.
