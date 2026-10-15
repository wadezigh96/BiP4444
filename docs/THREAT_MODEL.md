# BIP4444 Initial Threat Model

## Scope and status

This is a preliminary threat model, not an independent security audit. The current static interface remains illustrative. A minimal read-only `GET /api/session` endpoint now verifies Privy access tokens using the official `@privy-io/node` package. It has not yet been verified against a configured key and real test token. No login UI, wallet action, payment, membership issuance, or blockchain transaction is implemented.

## Assets to protect

- Privy verification configuration and any server credentials.
- Binance or other provider API credentials.
- ERC-8004 identity references and membership status.
- x402 payment proofs and settlement decisions.
- Alert reporter keys, incident source provenance, and response links.
- User privacy and the integrity of displayed risk information.

## Trust boundaries

- Browser UI is untrusted; never rely on it to enforce membership limits, authorization, payment success, or alert authenticity.
- The session endpoint must verify the access token cryptographically; never trust decoded JWT claims without verification.
- Vercel environment configuration is separate from runtime usage. A stored variable may be unused, misnamed, incorrectly scoped, or invalid.
- External API responses may be stale, malformed, compromised, or unavailable.
- Public blockchain data is observable and may lag or require confirmation; verify network and contract addresses.
- Alert messages and linked rescue resources can be forged or used for phishing.

## Threats and mitigations

| Threat | Required mitigation / test |
|---|---|
| Secret exposed in frontend bundle or logs | Keep server secrets server-only; inspect built assets and logs; redact values. |
| Forged or expired Privy token | Use the official verifier, require the correct app ID and verification key, reject invalid tokens with 401, and never log bearer tokens. |
| Missing or incorrect auth configuration | Fail closed with 503; never bypass verification to make login appear to work. |
| API key has excessive permissions | Use least privilege, disable withdrawals/trading unless strictly required, use IP restrictions where supported, rotate if exposed. |
| Fake wallet or identity state | Verify session on the server and confirm chain, registry, token/agent identity and ownership from trusted sources. |
| Membership cap bypass | Enforce the 4,444 cap atomically on-chain; test concurrent registration and duplicate identity attempts. |
| Ownership transfer creates stale membership | Define transfer/owner-change behavior and revalidate identity ownership before sensitive actions. |
| Forged or misleading alert | Authenticate reporter/source, include timestamp, provenance, severity and confidence; provide a way to verify the alert independently. |
| Malicious rescue link / phishing | Use a curated allowlist of official links; never ask for seed phrases, private keys, or remote access. |
| x402 replay or false payment confirmation | Bind proof to chain, asset, recipient, amount, expiry and request; reject replay; grant membership only after verified settlement. |
| API abuse / denial of service | Schema validation, rate limiting, quotas, timeouts, bounded retries and monitoring. |
| Sensitive data over-collection | Minimize stored personal data; do not put secrets in QR codes or public identity metadata. |
| Admin or upgrade key compromise | Minimize privileges, use multisig/timelock where appropriate, document emergency response and test access controls. |
| False claim of protection | State that alerts assist response but cannot guarantee immunity, reverse finalized transactions, or guarantee asset recovery. |

## Incident response

1. Publish a verified advisory with timestamp, source and confidence.
2. Confirm response links through a separate trusted channel.
3. Recommend conservative steps and direct users to official wallet/provider support.
4. Never ask users to share recovery phrases or private keys.
5. Rotate/revoke affected service credentials through the provider if compromise is suspected.
6. Preserve non-sensitive incident evidence and update the advisory as facts change.

## Open decisions before production

- Verify the Privy verification key configuration and complete safe endpoint tests.
- Privy login/wallet model and authorization requirements beyond basic authentication.
- Exact provider and documented purpose for each `B_*` and `BX_*` environment variable.
- Production x402 facilitator and BSC-compatible settlement details.
- Membership controller design and how ERC-8004 transfers affect membership.
- Trusted alert publishers, signature/key rotation, severity model and false-positive process.
- Data retention, privacy disclosures, support escalation, and operational ownership.
