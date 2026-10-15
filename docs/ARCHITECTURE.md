# BIP4444 Architecture

## Current implementation state

The repository has a specification README, a static illustrative interface, and a minimal serverless endpoint at `GET /api/session`. The endpoint uses the official `@privy-io/node` package to verify a Privy access token using `PRIVY_APP_ID` and `PRIVY_VERIFICATION_KEY`. It returns only the authenticated Privy user ID and explicitly reports passport issuance, payments, and transactions as disabled.

The endpoint is not considered production-verified yet: the verification key must be configured and the route must be tested with missing, invalid, and valid tokens. The static page does not yet implement a Privy login flow. There is no wallet integration, x402 settlement, live alert monitor, membership contract, or contract deployment.

## Safety boundary

- Work is isolated on `feat/safe-bip4444-foundation`; `main` is not modified by this branch.
- The endpoint reads only the two Privy environment variables it requires; no environment values are committed to source or returned in API responses.
- No blockchain transactions or payment requests are initiated.
- Production credentials must never be sent to browser JavaScript.
- No contract deployment or production integration is approved by this architecture document.

## Proposed layers

1. **Web UI** — passport overview, membership status, alert feed, security instructions. It must label unverified and stale data clearly.
2. **Authentication boundary** — the current endpoint verifies a Privy access token only. Future protected routes must call server-side verification and authorize each action independently. Add rate limits and request validation before public rollout.
3. **Identity adapter** — read ERC-8004 identity data on BSC; verify chain ID, registry address, ownership, and current transfer state against authoritative on-chain data.
4. **Membership controller** — if strict 4,444 cap is required, use audited on-chain enforcement that references ERC-8004 agent IDs. ERC-8004 alone must not be assumed to enforce the BIP membership cap. Avoid minting a second passport NFT unless the product decision changes.
5. **x402 payment adapter** — define facilitator, supported BSC asset, recipient, amount, expiry, settlement and replay handling. Membership must not be granted from a client-side success message.
6. **Alert Shield** — ingest trusted signals, authenticate reporters, preserve provenance and timestamps, score severity/confidence, and publish signed or otherwise verifiable alerts with safe response instructions.
7. **Audit/observability** — redact secrets and personal data; log event IDs and outcome metadata, not tokens, private keys, seed phrases, or full payment credentials.

## Environment variable policy

Known Vercel variable names are deployment configuration, not proof of integration. Before using any variable, document its owner, expected format, scope, least privilege, rotation process, and whether it is required at build or runtime. Do not rename or delete existing variables as part of this foundation.

- `PRIVY_APP_ID`: read by the session endpoint; verify it matches the intended Privy app.
- `PRIVY_VERIFICATION_KEY`: required by the endpoint but not confirmed configured yet; obtain the access-token verification key from the Privy Dashboard and store it as a server-side Vercel environment variable.
- `PRIVY_APP_SECRET`: server-only secret; this endpoint does not use it. Never prefix with `NEXT_PUBLIC_` or embed it in static HTML.
- `B_API`, `B_KEY`, `BX_API_KEY`, `BX_SECRET_KEY`: purpose and provider are not inferred from names alone. Confirm each variable against official provider documentation and actual code before use. Never expose secret values in browser bundles or logs.

## Required release gates

1. Confirm the correct production domain and repository/branch linkage.
2. Test `GET /api/session`: missing token (401), invalid token (401), missing configuration (503), and valid short-lived token (200). Do not expose tokens in test output.
3. Add a real login flow only after the public app ID and chosen frontend SDK configuration are confirmed.
4. Add authorization, rate limits, input validation and secret redaction before any sensitive route.
5. Verify the BSC chain ID and registry contract behavior on-chain; do not rely only on a source repository.
6. Specify the membership cap, duplicate prevention, transfer/owner-change handling, and administrative controls.
7. Test x402 wrong-chain, wrong-asset, wrong-recipient, wrong-amount, expired, replayed, pending and failed settlements.
8. Test forged, stale, duplicate and spam alert scenarios.
9. Run dependency/security checks and independent contract review.
10. Obtain explicit approval before merging to production, using real credentials, enabling payments, or deploying contracts.
