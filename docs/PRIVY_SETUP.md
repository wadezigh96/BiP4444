# Privy session endpoint setup

This is a read-only authentication milestone. It verifies an existing Privy access token; it does not implement login UI, create users, create wallets, issue passports, or submit transactions.

## Endpoint

- `GET /api/session`
- Header: `Authorization: Bearer <Privy access token>`
- Valid token: returns `authenticated: true` and the minimal Privy user ID.
- Missing/invalid token: returns HTTP 401.
- Unsupported method: returns HTTP 405.
- Missing server configuration: returns HTTP 503.

The endpoint uses the official `@privy-io/node` package to verify the token signature and claims. It does not decode a JWT and trust its contents without verification.

## Required Vercel environment variables

Set these only in the Vercel project for BIP4444:

- `PRIVY_APP_ID` — the existing app ID.
- `PRIVY_VERIFICATION_KEY` — the app's access-token verification public key from the Privy Dashboard.

The current project has `PRIVY_APP_ID` and `PRIVY_APP_SECRET` configured according to the earlier environment-name audit. The new endpoint does not need or read `PRIVY_APP_SECRET`. Do not paste any secret or token into GitHub, chat, or frontend code. Keep the verification key server-side in the environment configuration and use the exact key format provided by Privy.

Environment variable names alone do not prove that values are correct. Until the key is configured and a real token is tested safely, the endpoint should be treated as not configured.

## Safe manual test

1. Deploy only this branch to a non-production Preview deployment after reviewing the diff.
2. Request `GET /api/session` without an Authorization header; expected result is HTTP 401 with `missing_bearer_token`.
3. Request it with a deliberately invalid placeholder bearer token; expected result is HTTP 401 with `invalid_access_token`.
4. After configuring the verification key, test with a real short-lived access token in a secure local client. Never commit or share the token.
5. Confirm the response does not include email, phone number, wallet details, or the token itself.

A 503 response means the required environment configuration is absent. Do not “fix” it by weakening verification or accepting unverified JWT claims.

## Current limitations

- The static page does not yet provide a Privy login button or request an access token.
- This endpoint is not a membership gate and does not prove ownership of an ERC-8004 identity.
- It does not enforce the 4,444-member cap.
- Passport issuance, x402 payment verification, wallet operations, Binance APIs, and Alert Shield live monitoring remain disabled.
