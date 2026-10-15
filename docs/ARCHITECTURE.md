# BIP4444 Architecture (Proposed)

## Current state

The repository currently contains a specification README and a static, dependency-free interface foundation. The interface is illustrative only. There is no wallet integration, API client, x402 settlement, live alert monitor, membership contract, or contract deployment in this change.

## Safety boundary

- This change is additive and is isolated on `feat/safe-bip4444-foundation`.
- No existing README is replaced.
- No environment variable values are read by application code.
- No blockchain transactions or payment requests are initiated.
- Production credentials must never be sent to browser JavaScript.
- No contract deployment or production integration is approved by this architecture document.

## Proposed layers

1. **Web UI** — passport overview, membership status, alert feed, security instructions. It must label unverified and stale data clearly.
2. **Server-side integration boundary** — only after a backend is added, validate sessions and request schemas, apply rate limits, and call external services without exposing server secrets.
3. **Identity adapter** — read ERC-8004 identity data on BSC; verify chain ID, registry address, ownership, and current transfer state against authoritative on-chain data.
4. **Membership controller** — if strict 4,444 cap is required, use audited on-chain enforcement that references ERC-8004 agent IDs. ERC-8004 alone must not be assumed to enforce the BIP membership cap. Avoid minting a second passport NFT unless the product decision changes.
5. **x402 payment adapter** — define facilitator, supported BSC asset, recipient, amount, expiry, settlement and replay handling. Membership must not be granted from a client-side success message.
6. **Alert Shield** — ingest trusted signals, authenticate reporters, preserve provenance and timestamps, score severity/confidence, and publish signed or otherwise verifiable alerts with safe response instructions.
7. **Audit/observability** — redact secrets and personal data; log event IDs and outcome metadata, not tokens, private keys, seed phrases, or full payment credentials.

## Environment variable policy

Known Vercel variable names are deployment configuration, not proof of integration. Before using any variable, document its owner, expected format, scope, least privilege, rotation process, and whether it is required at build or runtime. Do not rename or delete existing variables as part of this foundation.

- `PRIVY_APP_ID`: public application identifier if required by the selected Privy flow; confirm exact SDK configuration before use.
- `PRIVY_APP_SECRET`: server-only secret; never prefix with `NEXT_PUBLIC_` or embed in static HTML.
- `B_API`, `B_KEY`, `BX_API_KEY`, `BX_SECRET_KEY`: purpose and provider are not inferred from names alone. Confirm each variable against official provider documentation and actual code before use. Never expose secret values in browser bundles or logs.

## Required release gates

1. Confirm the correct production domain and repository/branch linkage.
2. Add a server framework only when the selected integration requires it.
3. Implement and test authentication, authorization, rate limits, input validation and secret redaction.
4. Verify the BSC chain ID and registry contract behavior on-chain; do not rely only on a source repository.
5. Specify the membership cap, duplicate prevention, transfer/owner-change handling, and administrative controls.
6. Test x402 wrong-chain, wrong-asset, wrong-recipient, wrong-amount, expired, replayed, pending and failed settlements.
7. Test forged, stale, duplicate and spam alert scenarios.
8. Run dependency/security checks and independent contract review.
9. Obtain explicit approval before merging to production, using real credentials, enabling payments, or deploying contracts.
