# Official domain lock — 2026-10-16

| Field | Value |
|-------|--------|
| Host | `bips4444.vercel.app` |
| URL | `https://bips4444.vercel.app/` |
| TLS | Vercel (HSTS present on responses) |
| Key directory (target) | `https://bips4444.vercel.app/.well-known/bip-alert-keys.json` |

## Probe (2026-10-16)

- `GET https://bips4444.vercel.app/` → **404 NOT_FOUND** (no deployment / empty project root)  
- `GET .../.well-known/bip-alert-keys.json` → **404**  

Domain name is reserved on Vercel and suitable as official host once an app is deployed.

## Operator note

User reported Binance (x402) and Privy credentials configured in Vercel Environment Variables. Values were **not** recorded in this repo (correct). Ensure secrets are server-only and rotated if exposed outside Vercel.
