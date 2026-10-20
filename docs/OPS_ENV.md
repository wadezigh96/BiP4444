# BIP4444 operations — environment variables

**Last updated:** 2026-10-16  
**Official app host:** `https://bips4444.vercel.app/`

## Security rules

1. **Never commit** API keys, secrets, or private keys to git.  
2. Store secrets only in **Vercel → Project → Settings → Environment Variables** (Production / Preview as needed).  
3. Prefix **only** browser-safe values with `NEXT_PUBLIC_`.  
4. **Binance / B402 secret**, **Privy secret**, relayer keys, alert **private** keys → **server-only** (no `NEXT_PUBLIC_`).  
5. If a secret was ever pasted into chat, docs, or a public repo, **rotate it**.  
6. Do not paste live secret values into GitHub issues or AI chats.

## Recommended names (values stay on Vercel)

### Official domain / Alert Shield

| Name | Public? | Purpose |
|------|---------|--------|
| `OFFICIAL_DOMAIN` | yes / build-time | `bips4444.vercel.app` |
| `ALERT_KEYS_URL` | yes | `https://bips4444.vercel.app/.well-known/bip-alert-keys.json` |

### x402 / B402 (Binance)

| Name | Public? | Purpose |
|------|---------|--------|
| `B402_BASE_URL` | server | Facilitator API base (from Binance docs) |
| `B402_API_KEY` | **server only** | Facilitator API key |
| `B402_API_SECRET` | **server only** | Facilitator secret |
| `BIP_PAY_TO` | server or build | `0xFf265912c76342c8469cE18aB9DF0B2f37d9373c` |
| `MEMBERSHIP_ASSET` | server | USDT `0x55d398326f99059fF775485246999027B3197955` |
| `MEMBERSHIP_PRICE_ATOMIC` | server | `4000000000000000000` |

### Privy

| Name | Public? | Purpose |
|------|---------|--------|
| `NEXT_PUBLIC_PRIVY_APP_ID` | **public OK** | Privy App ID (client) |
| `PRIVY_APP_SECRET` | **server only** | Privy secret — API routes / server only |

### Settlement safety gates (keep unset/false until every release gate passes)\n\n| Name | Public? | Purpose |\n|------|---------|---------|\n| `BIP_ENABLE_LIVE_SETTLEMENT` | server only | Must remain unset/false during development and audit |\n| `BIP_RELEASE_APPROVED` | server only | Explicit release switch; do not set until independent review and release approval are recorded |\n\n### Chain / membership (when implemented)

| Name | Public? | Purpose |
|------|---------|--------|
| `BSC_RPC_URL` | server | BSC JSON-RPC |
| `ERC8004_IDENTITY` | public OK | `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432` |
| `RELAYER_PRIVATE_KEY` | **server only** | Path A register — never client |

### Alert publisher (when implemented)

| Name | Public? | Purpose |
|------|---------|--------|
| `ALERT_PUBLISHER_PRIVATE_KEY` | **server only** | Sign alerts; prefer KMS later |

## Checklist after setting Vercel env

- [ ] No secrets in git or `NEXT_PUBLIC_*` except intentional public IDs  
- [ ] Production env set (not only Development)  
- [ ] Redeploy after adding env vars  
- [ ] App root no longer 404  
- [ ] `/.well-known/bip-alert-keys.json` returns 200  

## Related

- `docs/X402_REQUIREMENTS.md` — payment design  
- `docs/ALERT_SHIELD.md` — alert design  
- Safe payTo: `0xFf265912c76342c8469cE18aB9DF0B2f37d9373c`  
